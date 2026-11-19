//! Unified P2P Chat Transfer Engine orchestrating identity, multi-room E2EE,
//! SQLite Outbox, blind-locker Home Node caching & auto-purge, USB tethering priority,
//! physical-NIC LAN bypass QUIC, and Iroh WAN/Relay fallback.

use crate::config::EngineConfig;
use crate::crypto::identity::{
    PairingTicket, RoomInviteTicket, RoomMemberTicketEntry, load_or_create_secret_key,
};
use crate::crypto::room_cipher::{generate_room_key, room_key_to_hex};
use crate::db::store::{
    ChatMessageRecord, DEFAULT_PERSONAL_ROOM_ID, HomeNodeStats, LocalStore, MessageDirection,
    MessageKind, MessageStatus, RoomMemberRecord, RoomRecord,
};
use crate::net::lan_bypass::{
    PhysicalLanInterface, UsbRouteProtectionStatus, create_pinned_lan_udp_socket,
    ensure_usb_tether_metric_safe, is_usb_tether_adapter,
};
use crate::net::lan_quic::{
    LanQuicManager, PREFERRED_LAN_QUIC_PORT, PinnedLanEndpoint, authenticate_responder,
};
use crate::net::usb_bootstrap::{
    LocalControlHandler, UsbBootstrapPayload, probe_usb_bootstrap_candidates,
    start_usb_bootstrap_server,
};
use crate::net::wan_iroh::WanIrohEndpoint;
use crate::transfer::chunker::index_file;
use crate::transfer::protocol::{RoomMemberWire, WireMessage, sign_room_revoke};
use crate::transfer::sync_engine::{
    EngineEvent, TransportKind, apply_remote_profile_update, compute_avatar_hash,
    deliver_blind_locker_item_to_peer, forward_locker_ack_to_sender,
    handle_incoming_bidi_stream, local_profile_snapshot, read_wire_message, remove_avatar_files,
    resolve_self_avatar_path, send_pending_room_revoke, send_queued_record, send_room_outbox_job,
    write_avatar_file, write_wire_message,
};
use anyhow::{Context, Result, bail};
use iroh::{EndpointAddr, EndpointId, SecretKey};
use serde::{Deserialize, Serialize};
use socket2::{Domain, Protocol, Socket, Type};
use std::collections::{HashMap, HashSet};
use std::net::{IpAddr, Ipv4Addr, SocketAddr, SocketAddrV4};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use tokio::sync::{Notify, OnceCell, RwLock, broadcast};
use uuid::Uuid;

const LAN_BEACON_PORT: u16 = 42426;
const LAN_MULTICAST_V4: Ipv4Addr = Ipv4Addr::new(239, 255, 42, 99);

#[derive(Debug, Clone, Serialize, Deserialize)]
struct LanBeacon {
    node_id: String,
    lan_addrs: Vec<String>,
    endpoint_addr: EndpointAddr,
    #[serde(default)]
    is_home_node: bool,
    #[serde(default)]
    is_reply: bool,
}

/// Home Node runtime configuration and blind-locker cache statistics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HomeNodeStatus {
    pub enabled: bool,
    pub retention_days: u32,
    pub usb_installer_path: Option<String>,
    pub usb_bootstrap_urls: Vec<String>,
    pub stats: HomeNodeStats,
}

/// Active authenticated transport connection to a peer.
#[derive(Clone)]
pub enum ActiveConnection {
    UsbLan(noq::Connection),
    Lan(noq::Connection),
    /// Direct hardware-NIC QUIC over a non-LAN address (e.g. cellular/broadband global IPv6).
    WanDirectNoq(noq::Connection),
    Wan(iroh::endpoint::Connection),
}

impl ActiveConnection {
    pub fn transport_kind(&self) -> TransportKind {
        match self {
            Self::UsbLan(_) => TransportKind::UsbTetherDirect,
            Self::Lan(_) => TransportKind::LanDirectPhysicalNic,
            Self::WanDirectNoq(_) => TransportKind::WanDirectP2p,
            Self::Wan(c) => classify_iroh_connection(c),
        }
    }

    pub fn is_closed(&self) -> bool {
        match self {
            Self::UsbLan(c) | Self::Lan(c) | Self::WanDirectNoq(c) => c.close_reason().is_some(),
            Self::Wan(c) => c.close_reason().is_some(),
        }
    }

    pub fn close(&self) {
        match self {
            Self::UsbLan(c) | Self::Lan(c) | Self::WanDirectNoq(c) => {
                c.close(0u32.into(), b"peer removed")
            }
            Self::Wan(c) => c.close(0u32.into(), b"peer removed"),
        }
    }
}

/// Inspects an active Iroh connection's live selected path to distinguish direct UDP P2P
/// from Relay-mediated fallback without modifying any routing or transfer state.
fn classify_iroh_connection(conn: &iroh::endpoint::Connection) -> TransportKind {
    let paths = conn.paths();
    if let Some(selected) = paths.iter().find(|p| p.is_selected()) {
        return if selected.is_ip() {
            TransportKind::WanDirectP2p
        } else {
            TransportKind::WanRelay
        };
    }
    if paths.iter().any(|p| p.is_ip()) {
        TransportKind::WanDirectP2p
    } else {
        TransportKind::WanRelay
    }
}

#[derive(Clone)]
struct ActiveEntry {
    id: u64,
    conn: ActiveConnection,
}

/// Top-level runtime engine shared between CLI tests and Flutter FFI.
pub struct ChatTransferEngine {
    pub config: EngineConfig,
    pub store: LocalStore,
    pub secret_key: SecretKey,
    wan_cell: Arc<OnceCell<WanIrohEndpoint>>,
    lan_boot_done: AtomicBool,
    lan_boot_notify: Notify,
    pub lan: Arc<LanQuicManager>,
    events_tx: broadcast::Sender<EngineEvent>,
    auto_receive_dir: Arc<std::sync::RwLock<PathBuf>>,
    usb_installer_path: Arc<std::sync::RwLock<Option<PathBuf>>>,
    active_peers: Arc<RwLock<HashMap<String, ActiveEntry>>>,
    next_conn_id: AtomicU64,
    wan_accept_started: AtomicBool,
    lan_discovery_started: AtomicBool,
    aux_loops_started: AtomicBool,
    draining_peers: Arc<Mutex<HashMap<String, bool>>>,
    locker_draining_peers: Arc<Mutex<HashMap<String, bool>>>,
    outbox_fail_streak: Arc<Mutex<HashMap<String, u32>>>,
}

impl ChatTransferEngine {
    fn create_local_core(config: EngineConfig) -> Result<Arc<Self>> {
        std::fs::create_dir_all(&config.data_dir)?;
        std::fs::create_dir_all(&config.auto_receive_dir)?;

        let secret_key = load_or_create_secret_key(&config.data_dir)?;
        let db_path = config.data_dir.join("chat_transfer.db");
        let store = LocalStore::open(&db_path)?;
        let my_id = secret_key.public().to_string();
        let _ = store.ensure_default_personal_room(&my_id, "本机设备");

        let saved_installer = store.get_usb_installer_path().map(PathBuf::from);
        let lan = Arc::new(LanQuicManager::empty());
        let (events_tx, _) = broadcast::channel(2048);

        let initial_receive_dir = config.auto_receive_dir.clone();
        Ok(Arc::new(Self {
            config,
            store,
            secret_key,
            wan_cell: Arc::new(OnceCell::new()),
            lan_boot_done: AtomicBool::new(false),
            lan_boot_notify: Notify::new(),
            lan,
            events_tx,
            auto_receive_dir: Arc::new(std::sync::RwLock::new(initial_receive_dir)),
            usb_installer_path: Arc::new(std::sync::RwLock::new(saved_installer)),
            active_peers: Arc::new(RwLock::new(HashMap::new())),
            next_conn_id: AtomicU64::new(1),
            wan_accept_started: AtomicBool::new(false),
            lan_discovery_started: AtomicBool::new(false),
            aux_loops_started: AtomicBool::new(false),
            draining_peers: Arc::new(Mutex::new(HashMap::new())),
            locker_draining_peers: Arc::new(Mutex::new(HashMap::new())),
            outbox_fail_streak: Arc::new(Mutex::new(HashMap::new())),
        }))
    }

    fn classify_noq_connection(
        &self,
        conn: noq::Connection,
        remote_ip: IpAddr,
        is_usb: bool,
    ) -> ActiveConnection {
        if is_usb {
            ActiveConnection::UsbLan(conn)
        } else if self.lan.is_local_lan_address(remote_ip) {
            ActiveConnection::Lan(conn)
        } else {
            ActiveConnection::WanDirectNoq(conn)
        }
    }

    fn reset_outbox_fail_streak(&self, peer_id: &str) {
        let mut guard = self
            .outbox_fail_streak
            .lock()
            .expect("outbox_fail_streak mutex poisoned");
        guard.remove(peer_id);
    }

    fn next_outbox_backoff(&self, peer_id: &str) -> std::time::Duration {
        let mut guard = self
            .outbox_fail_streak
            .lock()
            .expect("outbox_fail_streak mutex poisoned");
        let streak = guard
            .entry(peer_id.to_string())
            .and_modify(|s| *s = (*s + 1).min(7))
            .or_insert(1);
        let shift = (*streak).saturating_sub(1);
        let ms = 500u64.saturating_mul(1u64 << shift).min(30_000);
        std::time::Duration::from_millis(ms)
    }

    /// Starts the engine, binds WAN (Iroh) + physical/USB LAN QUIC endpoints,
    /// ensures default personal room, runs Windows USB anti-route-hijack check,
    /// and starts accept/discovery/GC/bootstrap loops.
    pub async fn start(
        config: EngineConfig,
        extra_lan_interfaces: Vec<PhysicalLanInterface>,
    ) -> Result<Arc<Self>> {
        let engine = Self::create_local_core(config)?;
        engine.boot_network_stack(extra_lan_interfaces, true).await?;
        Ok(engine)
    }

    /// Instant-boot variant for interactive UI startup: initializes local keys & SQLite
    /// synchronously (~5-15ms), then binds WAN/LAN QUIC stacks and OS USB metric checks
    /// concurrently in the background without blocking first-frame rendering.
    pub fn start_fast(
        config: EngineConfig,
        extra_lan_interfaces: Vec<PhysicalLanInterface>,
    ) -> Result<Arc<Self>> {
        let engine = Self::create_local_core(config)?;
        let bg = Arc::clone(&engine);
        tokio::spawn(async move {
            if let Err(e) = bg.boot_network_stack(extra_lan_interfaces, false).await {
                tracing::error!("background network stack boot failed: {e:#}");
            }
        });
        Ok(engine)
    }

    async fn ensure_wan(&self) -> Result<&WanIrohEndpoint> {
        self.wan_cell
            .get_or_try_init(|| async {
                WanIrohEndpoint::bind_with_key(
                    self.secret_key.clone(),
                    &self.config.relay_policy,
                )
                .await
            })
            .await
    }

    fn wan_if_ready(&self) -> Option<&WanIrohEndpoint> {
        self.wan_cell.get()
    }

    fn wan_addr_or_fallback(&self) -> EndpointAddr {
        self.wan_cell
            .get()
            .map(|w| w.addr())
            .unwrap_or_else(|| EndpointAddr::from(self.secret_key.public()))
    }

    /// Waits for initial background LAN socket binding to finish before dialing LAN candidates.
    pub async fn wait_lan_ready(&self) {
        while !self.lan_boot_done.load(Ordering::Acquire) {
            let notified = self.lan_boot_notify.notified();
            if self.lan_boot_done.load(Ordering::Acquire) {
                return;
            }
            notified.await;
        }
    }

    async fn boot_network_stack(
        self: &Arc<Self>,
        extra_lan_interfaces: Vec<PhysicalLanInterface>,
        sync_usb_metric: bool,
    ) -> Result<()> {
        if !self.aux_loops_started.swap(true, Ordering::SeqCst) {
            if self.store.is_home_node_mode() {
                self.spawn_locker_ttl_gc_loop();
            }
            self.spawn_locker_ready_listener();
            if self.config.enable_usb_bootstrap_http {
                self.start_usb_bootstrap_http();
            }
        }

        if sync_usb_metric {
            let _ = ensure_usb_tether_metric_safe();
        } else {
            tokio::task::spawn_blocking(|| {
                let _ = ensure_usb_tether_metric_safe();
            });
        }

        let lan_engine = Arc::clone(self);
        let lan_fut = async move {
            let lan_mgr = Arc::clone(&lan_engine.lan);
            let added = tokio::task::spawn_blocking(move || {
                lan_mgr.bind_missing_interfaces(extra_lan_interfaces)
            })
            .await
            .context("LAN bind task panicked")??;
            lan_engine.lan_boot_done.store(true, Ordering::Release);
            lan_engine.lan_boot_notify.notify_waiters();
            for pinned in added {
                lan_engine.spawn_pinned_accept_loop(pinned);
            }
            lan_engine.spawn_lan_discovery();
            Ok::<_, anyhow::Error>(())
        };

        let wan_engine = Arc::clone(self);
        let wan_fut = async move {
            wan_engine.ensure_wan().await?;
            wan_engine.spawn_wan_accept_loop();
            let online_eng = Arc::clone(&wan_engine);
            tokio::spawn(async move {
                if let Ok(wan) = online_eng.ensure_wan().await {
                    wan.wait_online().await;
                    online_eng.broadcast_lan_beacon_once();
                }
            });
            Ok::<_, anyhow::Error>(())
        };

        let (lan_res, wan_res) = tokio::join!(lan_fut, wan_fut);
        lan_res?;
        wan_res?;
        Ok(())
    }

    /// Returns the current directory where incoming files are automatically saved.
    pub fn auto_receive_dir(&self) -> PathBuf {
        self.auto_receive_dir
            .read()
            .expect("auto_receive_dir lock poisoned")
            .clone()
    }

    /// Validates writeability and switches the live auto-receive directory immediately.
    pub fn set_auto_receive_dir(&self, new_dir: PathBuf) -> Result<PathBuf> {
        std::fs::create_dir_all(&new_dir)
            .with_context(|| format!("无法创建目标目录: {}", new_dir.display()))?;
        let probe = new_dir.join(format!(".p2p_write_probe_{}", std::process::id()));
        std::fs::write(&probe, b"ok")
            .with_context(|| format!("目标目录没有写入权限: {}", new_dir.display()))?;
        let _ = std::fs::remove_file(&probe);

        *self
            .auto_receive_dir
            .write()
            .expect("auto_receive_dir lock poisoned") = new_dir.clone();
        tracing::info!("updated auto_receive_dir={}", new_dir.display());
        Ok(new_dir)
    }

    /// Returns this device's cryptographic `EndpointId`.
    pub fn my_endpoint_id(&self) -> EndpointId {
        self.secret_key.public()
    }

    /// Waits for the WAN Iroh endpoint to connect to its home relay.
    pub async fn wait_online(&self) {
        if let Ok(wan) = self.ensure_wan().await {
            wan.wait_online().await;
        }
    }

    /// Subscribes to live engine events (messages, transfer progress, room/node state).
    pub fn subscribe_events(&self) -> broadcast::Receiver<EngineEvent> {
        self.events_tx.subscribe()
    }

    /// Dynamically binds newly connected physical/USB interfaces and launches accept loops for them.
    pub fn refresh_network_interfaces(
        self: &Arc<Self>,
        extra_lan_interfaces: Vec<PhysicalLanInterface>,
    ) -> Result<()> {
        let added = self.lan.bind_missing_interfaces(extra_lan_interfaces)?;
        let has_added = !added.is_empty();
        for pinned in added {
            self.spawn_pinned_accept_loop(pinned);
        }
        let _ = ensure_usb_tether_metric_safe();
        if has_added {
            self.spawn_lan_discovery();
            self.broadcast_lan_beacon_once();
        }
        Ok(())
    }

    /// Reconciles live physical LAN/USB interfaces (binding new ones, closing vanished ones),
    /// evicts dead LAN peer entries, and notifies Iroh of OS network transitions (e.g. Wi-Fi -> 5G).
    pub async fn reconcile_network_interfaces(
        self: &Arc<Self>,
        extra_lan_interfaces: Vec<PhysicalLanInterface>,
    ) -> Result<()> {
        let (added, removed_ips) = self.lan.reconcile_interfaces(extra_lan_interfaces)?;
        let has_added = !added.is_empty();
        for pinned in added {
            self.spawn_pinned_accept_loop(pinned);
        }
        let _ = ensure_usb_tether_metric_safe();

        if !removed_ips.is_empty() {
            let no_non_usb_lan_left = self
                .lan
                .snapshot_endpoints()
                .iter()
                .all(|ep| ep.interface.is_usb_tether || ep.local_addr.ip().is_loopback());
            let mut evicted = Vec::new();
            {
                let mut map = self.active_peers.write().await;
                let closed_peers: Vec<String> = map
                    .iter()
                    .filter(|(_, e)| {
                        e.conn.is_closed()
                            || (no_non_usb_lan_left
                                && e.conn.transport_kind() == TransportKind::LanDirectPhysicalNic)
                    })
                    .map(|(k, _)| k.clone())
                    .collect();
                for pid in closed_peers {
                    if let Some(entry) = map.remove(&pid) {
                        entry.conn.close();
                        evicted.push(pid);
                    }
                }
            }
            for pid in evicted {
                let _ = self
                    .events_tx
                    .send(EngineEvent::PeerDisconnected { peer_id: pid });
            }
        }

        // Notify Iroh so magicsock & relay connections migrate onto the active OS interface (5G/Wi-Fi).
        if let Some(wan) = self.wan_if_ready() {
            wan.network_change().await;
        }

        if has_added {
            self.spawn_lan_discovery();
            self.broadcast_lan_beacon_once();
        }
        Ok(())
    }

    /// Generates a QR-ready Phase 1 pairing ticket containing this device's identity, relay addr, and LAN addrs.
    pub fn create_pairing_ticket(&self, device_name: &str) -> Result<PairingTicket> {
        let trimmed_name = device_name.trim();
        if !trimmed_name.is_empty() && trimmed_name != "家庭常驻盲盒节点" {
            let _ = self.store.set_setting("self_device_name", trimmed_name);
        }
        let one_time_psk_hex: String = SecretKey::generate().to_bytes()[..16]
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect();

        Ok(PairingTicket {
            version: 1,
            device_name: device_name.to_string(),
            endpoint_addr: self.wan_addr_or_fallback(),
            lan_addrs: self
                .lan
                .advertise_addrs()
                .into_iter()
                .map(|a| a.to_string())
                .collect(),
            one_time_psk_hex,
        })
    }

    /// Pairs with a remote device from its `PairingTicket`, saves it as trusted,
    /// and attempts immediate connection.
    pub async fn pair_with_ticket(self: &Arc<Self>, ticket: PairingTicket) -> Result<TrustedPeerAlias> {
        let peer_id = ticket.endpoint_addr.id.to_string();
        if peer_id == self.my_endpoint_id().to_string() {
            anyhow::bail!("不能将本机设备添加为联系人");
        }
        self.store.upsert_peer(&peer_id, &ticket.device_name)?;
        self.persist_peer_hints(&peer_id, &ticket.lan_addrs, Some(&ticket.endpoint_addr));

        let lan_addrs: Vec<SocketAddr> = ticket
            .lan_addrs
            .iter()
            .filter_map(|s| s.parse().ok())
            .collect();

        if !self.store.is_home_node_mode() {
            let hash = blake3::hash(ticket.one_time_psk_hex.as_bytes());
            let dm_key_hex = room_key_to_hex(hash.as_bytes());
            let my_id = self.my_endpoint_id().to_string();
            let my_name = self
                .store
                .get_setting("self_device_name")
                .ok()
                .flatten()
                .filter(|s| !s.trim().is_empty())
                .unwrap_or_else(|| "本机设备".to_string());
            let dm_room = self.store.ensure_dm_room(
                &my_id,
                &my_name,
                &peer_id,
                &ticket.device_name,
                Some(dm_key_hex),
            )?;
            if self.connect_peer(ticket.endpoint_addr, lan_addrs).await.is_ok() {
                let _ = self.send_room_sync_to_peer(&dm_room.room_id, &peer_id).await;
            }
            let _ = self.events_tx.send(EngineEvent::RoomUpdated {
                room_id: dm_room.room_id,
            });
        } else {
            let _ = self.connect_peer(ticket.endpoint_addr, lan_addrs).await;
        }

        Ok(TrustedPeerAlias {
            node_id: peer_id,
            display_name: ticket.device_name,
            created_at_ms: crate::db::store::now_millis(),
            last_seen_ms: Some(crate::db::store::now_millis()),
            avatar_hash: None,
            avatar_path: None,
        })
    }

    // -------------------------------------------------------------------------
    // Phase 2 Multi-Room & Home Node Blind Locker API
    // -------------------------------------------------------------------------

    /// Lists chat-capable rooms (excludes zero-knowledge blind locker rooms).
    pub fn list_rooms(&self) -> Result<Vec<RoomRecord>> {
        if self.store.is_home_node_mode() {
            return Ok(Vec::new());
        }
        self.store.list_rooms()
    }

    /// Lists members in `room_id`.
    pub fn list_room_members(&self, room_id: &str) -> Result<Vec<RoomMemberRecord>> {
        self.store.list_room_members(room_id)
    }

    /// Creates a new isolated end-to-end encrypted group room, or handles `__dm__:` / `__group__:` commands.
    pub fn create_room(self: &Arc<Self>, name: &str, my_device_name: &str) -> Result<RoomRecord> {
        if self.store.is_home_node_mode() {
            bail!("当前设备处于纯盲盒常驻节点模式，不能创建明文聊天房间");
        }
        if !my_device_name.trim().is_empty() {
            let _ = self
                .store
                .set_setting("self_device_name", my_device_name.trim());
        }
        let my_id = self.my_endpoint_id().to_string();

        if let Some(raw_peer_id) = name.strip_prefix("__dm__:") {
            let peer_id = raw_peer_id.trim();
            if peer_id.is_empty() || peer_id == my_id {
                bail!("无效的私聊对端设备 ID");
            }
            let peer_name = self
                .store
                .list_peers()?
                .into_iter()
                .find(|p| p.node_id == peer_id)
                .map(|p| p.display_name)
                .unwrap_or_else(|| "Paired Device".to_string());
            let preferred_key_hex = room_key_to_hex(&generate_room_key());
            let room = self.store.ensure_dm_room(
                &my_id,
                my_device_name,
                peer_id,
                &peer_name,
                Some(preferred_key_hex),
            )?;
            let _ = self.events_tx.send(EngineEvent::RoomUpdated {
                room_id: room.room_id.clone(),
            });
            let eng = Arc::clone(self);
            let rid = room.room_id.clone();
            let pid = peer_id.to_string();
            tokio::spawn(async move {
                if eng.active_transport(&pid).await.is_none() {
                    let _ = eng.connect_peer_by_id(&pid).await;
                }
                let _ = eng.send_room_sync_to_peer(&rid, &pid).await;
            });
            return Ok(room);
        }

        if let Some(raw_json) = name.strip_prefix("__group__:") {
            #[derive(serde::Deserialize)]
            struct CreateGroupPayload {
                name: String,
                #[serde(default)]
                member_ids: Vec<String>,
            }
            let payload: CreateGroupPayload =
                serde_json::from_str(raw_json).context("invalid __group__ JSON payload")?;
            let room_id = format!("room-{}", Uuid::now_v7());
            let key_hex = room_key_to_hex(&generate_room_key());
            let room = RoomRecord {
                room_id: room_id.clone(),
                name: if payload.name.trim().is_empty() {
                    "新建加密群聊".to_string()
                } else {
                    payload.name.trim().to_string()
                },
                room_type: "group".to_string(),
                room_key_hex: Some(key_hex),
                is_pinned: false,
                retention_days: self.store.get_retention_days(),
                created_at_ms: crate::db::store::now_millis(),
            };
            self.store.upsert_room(&room)?;
            self.store
                .upsert_room_member(&room_id, &my_id, my_device_name, "owner")?;

            let known_peers = self.store.list_peers()?;
            let mut sync_targets = Vec::new();
            for raw_member in payload.member_ids {
                let member_id = raw_member.trim();
                if member_id.is_empty() || member_id == my_id {
                    continue;
                }
                if let Some(peer) = known_peers.iter().find(|p| p.node_id == member_id) {
                    self.store.upsert_room_member(
                        &room_id,
                        member_id,
                        &peer.display_name,
                        "member",
                    )?;
                    sync_targets.push(member_id.to_string());
                }
            }
            let _ = self.events_tx.send(EngineEvent::RoomUpdated {
                room_id: room_id.clone(),
            });
            if !sync_targets.is_empty() {
                let eng = Arc::clone(self);
                let rid = room_id.clone();
                tokio::spawn(async move {
                    for pid in sync_targets {
                        if eng.active_transport(&pid).await.is_none() {
                            let _ = eng.connect_peer_by_id(&pid).await;
                        }
                        let _ = eng.send_room_sync_to_peer(&rid, &pid).await;
                    }
                });
            }
            return Ok(room);
        }

        let room_id = format!("room-{}", Uuid::now_v7());
        let key_hex = room_key_to_hex(&generate_room_key());
        let room = RoomRecord {
            room_id: room_id.clone(),
            name: if name.trim().is_empty() {
                "新建私密加密房间".to_string()
            } else {
                name.trim().to_string()
            },
            room_type: "group".to_string(),
            room_key_hex: Some(key_hex),
            is_pinned: false,
            retention_days: self.store.get_retention_days(),
            created_at_ms: crate::db::store::now_millis(),
        };
        self.store.upsert_room(&room)?;
        self.store
            .upsert_room_member(&room_id, &my_id, my_device_name, "owner")?;
        let _ = self.events_tx.send(EngineEvent::RoomUpdated { room_id });
        Ok(room)
    }

    /// Creates a `RoomInviteTicket` for either a regular room member (`invite_as_home_node = false`)
    /// or a zero-knowledge blind locker Home Node (`invite_as_home_node = true`, omits `room_key_hex`).
    pub fn create_room_invite(
        &self,
        room_id: &str,
        my_device_name: &str,
        invite_as_home_node: bool,
    ) -> Result<RoomInviteTicket> {
        let room = self
            .store
            .get_room(room_id)?
            .context("room not found")?;
        let my_id = self.my_endpoint_id().to_string();
        let db_members = self.store.list_room_members(room_id)?;

        let mut member_entries = Vec::with_capacity(db_members.len());
        for m in db_members {
            let (ep, lan) = if m.node_id == my_id {
                (
                    Some(self.wan_addr_or_fallback()),
                    self.lan
                        .advertise_addrs()
                        .into_iter()
                        .map(|a| a.to_string())
                        .collect(),
                )
            } else {
                let (ep_opt, lan_socks) = self.load_peer_hints(&m.node_id);
                (ep_opt, lan_socks.into_iter().map(|s| s.to_string()).collect())
            };
            member_entries.push(RoomMemberTicketEntry {
                node_id: m.node_id,
                display_name: m.display_name,
                role: m.role,
                endpoint_addr: ep,
                lan_addrs: lan,
            });
        }

        let one_time_psk_hex: String = SecretKey::generate().to_bytes()[..16]
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect();

        Ok(RoomInviteTicket {
            version: 2,
            room_id: room.room_id,
            room_name: room.name,
            room_type: room.room_type,
            invite_role: if invite_as_home_node {
                "home_node".to_string()
            } else {
                "member".to_string()
            },
            // CRITICAL: Never leak room_key_hex when inviting a blind Home Node.
            room_key_hex: if invite_as_home_node {
                None
            } else {
                room.room_key_hex
            },
            inviter_id: my_id,
            inviter_name: my_device_name.to_string(),
            inviter_endpoint: self.wan_addr_or_fallback(),
            inviter_lan_addrs: self
                .lan
                .advertise_addrs()
                .into_iter()
                .map(|a| a.to_string())
                .collect(),
            members: member_entries,
            one_time_psk_hex,
        })
    }

    /// Joins an encrypted room using a `RoomInviteTicket` (supports both member & blind Home Node roles).
    pub async fn join_room_with_invite(
        self: &Arc<Self>,
        ticket: RoomInviteTicket,
        my_device_name: &str,
    ) -> Result<RoomRecord> {
        if !my_device_name.trim().is_empty() {
            let _ = self
                .store
                .set_setting("self_device_name", my_device_name.trim());
        }
        let my_id = self.my_endpoint_id().to_string();
        let is_blind_role = ticket.invite_role == "home_node" || self.store.is_home_node_mode();
        let is_legacy_dm = ticket.room_type == "dm"
            || ticket.room_type == "personal"
            || ticket.room_id == DEFAULT_PERSONAL_ROOM_ID;

        if is_legacy_dm && !is_blind_role {
            self.store
                .upsert_peer(&ticket.inviter_id, &ticket.inviter_name)?;
            self.persist_peer_hints(
                &ticket.inviter_id,
                &ticket.inviter_lan_addrs,
                Some(&ticket.inviter_endpoint),
            );
            let room = self.store.ensure_dm_room(
                &my_id,
                my_device_name,
                &ticket.inviter_id,
                &ticket.inviter_name,
                ticket.room_key_hex.clone(),
            )?;
            let inviter_lan: Vec<SocketAddr> = ticket
                .inviter_lan_addrs
                .iter()
                .filter_map(|s| s.parse().ok())
                .collect();
            if self
                .connect_peer(ticket.inviter_endpoint, inviter_lan)
                .await
                .is_ok()
            {
                let _ = self
                    .send_room_sync_to_peer(&room.room_id, &ticket.inviter_id)
                    .await;
            }
            let _ = self.events_tx.send(EngineEvent::RoomUpdated {
                room_id: room.room_id.clone(),
            });
            let _ = self.events_tx.send(EngineEvent::HomeNodeStatsUpdated);
            return Ok(room);
        }

        let room = RoomRecord {
            room_id: ticket.room_id.clone(),
            name: ticket.room_name.clone(),
            room_type: ticket.room_type.clone(),
            room_key_hex: if is_blind_role {
                None
            } else {
                ticket.room_key_hex.clone()
            },
            is_pinned: false,
            retention_days: self.store.get_retention_days(),
            created_at_ms: crate::db::store::now_millis(),
        };
        self.store.upsert_room(&room)?;

        let my_role = if is_blind_role {
            "home_node"
        } else {
            &ticket.invite_role
        };
        self.store
            .upsert_room_member(&ticket.room_id, &my_id, my_device_name, my_role)?;

        // Register inviter as a paired peer & room owner; keep non-paired group members out of Contacts.
        self.store
            .upsert_peer(&ticket.inviter_id, &ticket.inviter_name)?;
        self.persist_peer_hints(
            &ticket.inviter_id,
            &ticket.inviter_lan_addrs,
            Some(&ticket.inviter_endpoint),
        );
        self.store
            .upsert_room_member(&ticket.room_id, &ticket.inviter_id, &ticket.inviter_name, "owner")?;

        for m in &ticket.members {
            if m.node_id != my_id && (is_blind_role || self.store.has_peer(&m.node_id)) {
                self.store.upsert_peer(&m.node_id, &m.display_name)?;
            }
            self.persist_peer_hints(&m.node_id, &m.lan_addrs, m.endpoint_addr.as_ref());
            self.store
                .upsert_room_member(&ticket.room_id, &m.node_id, &m.display_name, &m.role)?;
        }

        // Connect to inviter and announce our membership in the room.
        let inviter_lan: Vec<SocketAddr> = ticket
            .inviter_lan_addrs
            .iter()
            .filter_map(|s| s.parse().ok())
            .collect();
        if self
            .connect_peer(ticket.inviter_endpoint, inviter_lan)
            .await
            .is_ok()
        {
            let _ = self
                .send_room_sync_to_peer(&ticket.room_id, &ticket.inviter_id)
                .await;
        }

        // Also opportunistically dial any other members (such as a Home Node included in the ticket).
        for m in &ticket.members {
            if m.node_id != my_id && m.node_id != ticket.inviter_id {
                if let Some(ep) = m.endpoint_addr.clone() {
                    let laddrs: Vec<SocketAddr> =
                        m.lan_addrs.iter().filter_map(|s| s.parse().ok()).collect();
                    let eng = Arc::clone(self);
                    let rid = ticket.room_id.clone();
                    let mid = m.node_id.clone();
                    tokio::spawn(async move {
                        if eng.connect_peer(ep, laddrs).await.is_ok() {
                            let _ = eng.send_room_sync_to_peer(&rid, &mid).await;
                        }
                    });
                }
            }
        }

        let _ = self.events_tx.send(EngineEvent::RoomUpdated {
            room_id: ticket.room_id.clone(),
        });
        let _ = self.events_tx.send(EngineEvent::HomeNodeStatsUpdated);
        Ok(room)
    }

    async fn send_wire_to_active_peer(&self, peer_id: &str, msg: &WireMessage) -> Result<()> {
        let entry_opt = self.active_peers.read().await.get(peer_id).cloned();
        let Some(entry) = entry_opt else {
            return Ok(());
        };
        match &entry.conn {
            ActiveConnection::UsbLan(c)
            | ActiveConnection::Lan(c)
            | ActiveConnection::WanDirectNoq(c) => {
                if let Ok((mut s, _r)) = c.open_bi().await {
                    let _ = write_wire_message(&mut s, msg).await;
                    let _ = s.finish();
                }
            }
            ActiveConnection::Wan(c) => {
                if let Ok((mut s, _r)) = c.open_bi().await {
                    let _ = write_wire_message(&mut s, msg).await;
                    let _ = s.finish();
                }
            }
        }
        Ok(())
    }

    /// Sends `RoomSyncAnnounce` to `peer_id` so it learns updated room membership and (for non-blind members) the `room_key`.
    pub async fn send_room_sync_to_peer(&self, room_id: &str, peer_id: &str) -> Result<()> {
        let Some(room) = self.store.get_room(room_id)? else {
            return Ok(());
        };
        let members = self.store.list_room_members(room_id)?;
        let is_home_node = self.store.is_home_node_mode();
        let recipient_is_home_node = members
            .iter()
            .any(|m| m.node_id == peer_id && m.role == "home_node");
        let my_id = self.my_endpoint_id().to_string();
        let my_lan: Vec<String> = self
            .lan
            .advertise_addrs()
            .into_iter()
            .map(|a| a.to_string())
            .collect();
        let my_ep = self.wan_addr_or_fallback();
        let announce = WireMessage::RoomSyncAnnounce {
            room_id: room.room_id,
            room_name: room.name,
            room_type: room.room_type,
            retention_days: room.retention_days,
            room_key_hex: if !is_home_node && !recipient_is_home_node {
                room.room_key_hex
            } else {
                None
            },
            members: members
                .into_iter()
                .map(|m| {
                    let (endpoint_addr, lan_addrs) = if m.node_id == my_id {
                        (Some(my_ep.clone()), my_lan.clone())
                    } else {
                        let (ep, socks) = self.load_peer_hints(&m.node_id);
                        (ep, socks.into_iter().map(|s| s.to_string()).collect())
                    };
                    RoomMemberWire {
                        node_id: m.node_id,
                        display_name: m.display_name,
                        role: m.role,
                        endpoint_addr,
                        lan_addrs,
                    }
                })
                .collect(),
        };

        self.send_wire_to_active_peer(peer_id, &announce).await
    }

    /// Sends an E2EE text message inside `room_id` to all room members (or via Home Node blind locker when offline).
    pub fn send_room_text(
        self: &Arc<Self>,
        room_id: &str,
        text: &str,
    ) -> Result<ChatMessageRecord> {
        if self.store.is_home_node_mode() {
            bail!("常驻盲盒节点模式下不启用明文聊天发送");
        }
        let room = self
            .store
            .get_room(room_id)?
            .context("room not found")?;
        if room.room_key_hex.is_none() {
            bail!("当前设备未持有该房间的密钥，不能在盲盒房间发送明文");
        }

        let my_id = self.my_endpoint_id().to_string();
        let members = self.store.list_room_members(room_id)?;
        let target_peers: Vec<String> = members
            .iter()
            .filter(|m| m.role != "home_node" && m.node_id != my_id)
            .map(|m| m.node_id.clone())
            .collect();
        let home_nodes: Vec<String> = members
            .iter()
            .filter(|m| m.role == "home_node" && m.node_id != my_id)
            .map(|m| m.node_id.clone())
            .collect();

        let primary_peer = target_peers
            .first()
            .or_else(|| home_nodes.first())
            .cloned()
            .unwrap_or_else(|| my_id.clone());

        let msg_id = Uuid::now_v7().to_string();
        let record = self.store.enqueue_room_outgoing_text(
            &msg_id,
            room_id,
            &my_id,
            &primary_peer,
            text,
            &target_peers,
        )?;
        let _ = self.events_tx.send(EngineEvent::MessageAdded(record.clone()));

        self.schedule_room_dispatch(target_peers, home_nodes);
        Ok(record)
    }

    /// Confirms and dispatches a deferred large-file transfer (`>= 50 MiB`).
    pub async fn confirm_deferred_room_file(
        self: &Arc<Self>,
        room_id: &str,
        msg_id: &str,
    ) -> Result<ChatMessageRecord> {
        let (record, pending_peers) = self.store.confirm_deferred_file_transfer(msg_id)?;
        let _ = self.events_tx.send(EngineEvent::MessageAdded(record.clone()));
        let eng = Arc::clone(self);
        let rid = room_id.to_string();
        tokio::spawn(async move {
            for peer_id in &pending_peers {
                if eng.active_transport(peer_id).await.is_none() {
                    let _ = eng.connect_peer_by_id(peer_id).await;
                }
                let _ = eng.send_room_sync_to_peer(&rid, peer_id).await;
            }
            eng.schedule_room_dispatch(pending_peers, Vec::new());
        });
        Ok(record)
    }

    fn control_ok_record(room_id: &str, sender_id: &str, action_tag: &str) -> ChatMessageRecord {
        ChatMessageRecord {
            msg_id: format!("ctrl-{action_tag}-{}", Uuid::now_v7()),
            room_id: room_id.to_string(),
            peer_id: sender_id.to_string(),
            sender_id: sender_id.to_string(),
            direction: MessageDirection::Outgoing,
            kind: MessageKind::Text,
            body_text: Some(action_tag.to_string()),
            file_name: None,
            file_size: None,
            local_path: None,
            root_blake3: None,
            chunk_size: None,
            total_chunks: None,
            received_bitmap: None,
            status: MessageStatus::Delivered,
            delivery_scope: "control".to_string(),
            acked_peers: Vec::new(),
            batch_id: None,
            created_at_ms: crate::db::store::now_millis(),
            updated_at_ms: crate::db::store::now_millis(),
        }
    }

    /// Indexes and sends an E2EE file inside `room_id`, or dispatches control commands
    /// (`__confirm_msg__:`, `__pull_file__:`, `__delete_peer__:`, `__delete_room__:`, `__remove_member__:`, `__add_members__:`).
    pub async fn send_room_file(
        self: &Arc<Self>,
        room_id: &str,
        file_path: PathBuf,
    ) -> Result<ChatMessageRecord> {
        self.send_room_file_with_batch(room_id, file_path, None)
            .await
    }

    /// Indexes and sends an E2EE file inside `room_id` with an optional sender `batch_id`.
    pub async fn send_room_file_with_batch(
        self: &Arc<Self>,
        room_id: &str,
        file_path: PathBuf,
        batch_id: Option<String>,
    ) -> Result<ChatMessageRecord> {
        let my_id = self.my_endpoint_id().to_string();
        if let Some(cmd_str) = file_path.to_str() {
            if let Some(confirm_msg_id) = cmd_str.strip_prefix("__confirm_msg__:") {
                return self
                    .confirm_deferred_room_file(room_id, confirm_msg_id.trim())
                    .await;
            }
            if let Some(pull_msg_id) = cmd_str.strip_prefix("__pull_file__:") {
                let msg_id = pull_msg_id.trim();
                let record = self
                    .store
                    .get_message(msg_id)?
                    .context("message not found")?;
                let sender_peer_id = if record.sender_id.trim().is_empty() {
                    record.peer_id.clone()
                } else {
                    record.sender_id.clone()
                };
                if self.active_transport(&sender_peer_id).await.is_none() {
                    self.connect_peer_by_id(&sender_peer_id).await?;
                }
                self.store.update_transfer_progress(
                    msg_id,
                    MessageStatus::Handshaking,
                    None,
                    None,
                )?;
                let total_chunks = record.total_chunks.unwrap_or(0);
                let _ = self.events_tx.send(EngineEvent::TransferProgress {
                    msg_id: msg_id.to_string(),
                    completed_chunks: 0,
                    total_chunks,
                    status: MessageStatus::Handshaking,
                    local_path: None,
                });
                self.send_wire_to_active_peer(
                    &sender_peer_id,
                    &WireMessage::FilePullRequest {
                        room_id: room_id.to_string(),
                        msg_id: msg_id.to_string(),
                    },
                )
                .await?;
                return Ok(self.store.get_message(msg_id)?.unwrap_or(record));
            }
            if let Some(raw_peer) = cmd_str.strip_prefix("__delete_peer__:") {
                let target_peer = raw_peer.trim();
                let dm_rid = self.store.delete_peer_and_dm(&my_id, target_peer)?;
                remove_avatar_files(&self.config.data_dir, target_peer);
                if let Some(entry) = self.active_peers.write().await.remove(target_peer) {
                    entry.conn.close();
                }
                let _ = self.events_tx.send(EngineEvent::RoomUpdated { room_id: dm_rid });
                return Ok(Self::control_ok_record(room_id, &my_id, "deleted_peer"));
            }
            if let Some(raw_rid) = cmd_str.strip_prefix("__delete_room__:") {
                let target_rid = if raw_rid.trim().is_empty() {
                    room_id
                } else {
                    raw_rid.trim()
                };
                self.store.delete_room(target_rid)?;
                let _ = self.events_tx.send(EngineEvent::RoomUpdated {
                    room_id: target_rid.to_string(),
                });
                return Ok(Self::control_ok_record(target_rid, &my_id, "deleted_room"));
            }
            if let Some(raw_peer) = cmd_str.strip_prefix("__remove_member__:") {
                let target_peer = raw_peer.trim();
                self.store.remove_room_member(room_id, target_peer)?;
                let _ = self.events_tx.send(EngineEvent::RoomUpdated {
                    room_id: room_id.to_string(),
                });
                let remaining = self.store.list_room_members(room_id)?;
                let eng = Arc::clone(self);
                let rid = room_id.to_string();
                let my_id_bg = my_id.clone();
                tokio::spawn(async move {
                    for m in remaining {
                        if m.node_id != my_id_bg && m.role != "home_node" {
                            let _ = eng.send_room_sync_to_peer(&rid, &m.node_id).await;
                        }
                    }
                });
                return Ok(Self::control_ok_record(room_id, &my_id, "removed_member"));
            }
            if let Some(raw_csv) = cmd_str.strip_prefix("__add_members__:") {
                let peers = self.store.list_peers()?;
                for raw_id in raw_csv.split(',') {
                    let member_id = raw_id.trim();
                    if member_id.is_empty() || member_id == my_id {
                        continue;
                    }
                    if let Some(peer) = peers.iter().find(|p| p.node_id == member_id) {
                        self.store.upsert_room_member(
                            room_id,
                            member_id,
                            &peer.display_name,
                            "member",
                        )?;
                    }
                }
                let members = self.store.list_room_members(room_id)?;
                let _ = self.events_tx.send(EngineEvent::RoomUpdated {
                    room_id: room_id.to_string(),
                });
                let eng = Arc::clone(self);
                let rid = room_id.to_string();
                let my_id_bg = my_id.clone();
                tokio::spawn(async move {
                    for m in members {
                        if m.node_id != my_id_bg && m.role != "home_node" {
                            if eng.active_transport(&m.node_id).await.is_none() {
                                let _ = eng.connect_peer_by_id(&m.node_id).await;
                            }
                            let _ = eng.send_room_sync_to_peer(&rid, &m.node_id).await;
                        }
                    }
                });
                return Ok(Self::control_ok_record(room_id, &my_id, "added_members"));
            }
        }

        if self.store.is_home_node_mode() {
            bail!("常驻盲盒节点模式下不启用文件明文发送");
        }
        let room = self
            .store
            .get_room(room_id)?
            .context("room not found")?;
        if room.room_key_hex.is_none() {
            bail!("当前设备未持有该房间的密钥");
        }

        let indexed = index_file(&file_path, self.config.chunk_size_bytes).await?;
        let file_name = file_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("file.bin")
            .to_string();
        let members = self.store.list_room_members(room_id)?;
        let target_peers: Vec<String> = members
            .iter()
            .filter(|m| m.role != "home_node" && m.node_id != my_id)
            .map(|m| m.node_id.clone())
            .collect();
        let home_nodes: Vec<String> = members
            .iter()
            .filter(|m| m.role == "home_node" && m.node_id != my_id)
            .map(|m| m.node_id.clone())
            .collect();

        let primary_peer = target_peers
            .first()
            .or_else(|| home_nodes.first())
            .cloned()
            .unwrap_or_else(|| my_id.clone());

        let msg_id = Uuid::now_v7().to_string();
        let batch_ref = batch_id
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty());
        if indexed.file_size >= crate::db::store::LARGE_FILE_CONFIRM_THRESHOLD_BYTES {
            if room.room_type == "group" {
                let record = self.store.enqueue_room_outgoing_file_offer_only(
                    &msg_id,
                    room_id,
                    &my_id,
                    &primary_peer,
                    &file_name,
                    indexed.file_size,
                    &file_path.to_string_lossy(),
                    &indexed.root_blake3,
                    indexed.chunk_size,
                    indexed.chunk_hashes.len(),
                    &target_peers,
                    batch_ref,
                )?;
                let _ = self.events_tx.send(EngineEvent::MessageAdded(record.clone()));
                self.schedule_room_dispatch(target_peers, home_nodes);
                return Ok(record);
            }

            // On-demand wakeup mode keeps `active_peers` cold when idle; probe disconnected
            // targets briefly so large DM files still send immediately to reachable peers.
            let need_probe: Vec<String> = {
                let active = self.active_peers.read().await;
                target_peers
                    .iter()
                    .filter(|peer| !active.get(*peer).is_some_and(|e| !e.conn.is_closed()))
                    .cloned()
                    .collect()
            };
            if !need_probe.is_empty() {
                let mut probes = Vec::with_capacity(need_probe.len());
                for peer in need_probe {
                    let eng = Arc::clone(self);
                    probes.push(tokio::spawn(async move {
                        let _ = tokio::time::timeout(
                            std::time::Duration::from_secs(3),
                            eng.connect_peer_by_id(&peer),
                        )
                        .await;
                    }));
                }
                for h in probes {
                    let _ = h.await;
                }
            }

            let mut online_targets = Vec::new();
            let mut offline_targets = Vec::new();
            {
                let active = self.active_peers.read().await;
                for peer in &target_peers {
                    if active.get(peer).is_some_and(|e| !e.conn.is_closed()) {
                        online_targets.push(peer.clone());
                    } else {
                        offline_targets.push(peer.clone());
                    }
                }
            }
            let record = self.store.enqueue_room_outgoing_file_split_targets(
                &msg_id,
                room_id,
                &my_id,
                &primary_peer,
                &file_name,
                indexed.file_size,
                &file_path.to_string_lossy(),
                &indexed.root_blake3,
                indexed.chunk_size,
                indexed.chunk_hashes.len(),
                &online_targets,
                &offline_targets,
                batch_ref,
            )?;
            let _ = self.events_tx.send(EngineEvent::MessageAdded(record.clone()));
            if !online_targets.is_empty() {
                self.schedule_room_dispatch(online_targets, Vec::new());
            }
            return Ok(record);
        }

        let record = self.store.enqueue_room_outgoing_file(
            &msg_id,
            room_id,
            &my_id,
            &primary_peer,
            &file_name,
            indexed.file_size,
            &file_path.to_string_lossy(),
            &indexed.root_blake3,
            indexed.chunk_size,
            indexed.chunk_hashes.len(),
            &target_peers,
            batch_ref,
        )?;
        let _ = self.events_tx.send(EngineEvent::MessageAdded(record.clone()));

        self.schedule_room_dispatch(target_peers, home_nodes);
        Ok(record)
    }

    fn schedule_room_dispatch(
        self: &Arc<Self>,
        target_peers: Vec<String>,
        home_nodes: Vec<String>,
    ) {
        for t in &target_peers {
            self.reset_outbox_fail_streak(t);
        }
        for hn in &home_nodes {
            self.reset_outbox_fail_streak(hn);
        }
        let engine = Arc::clone(self);
        tokio::spawn(async move {
            let mut any_target_offline = false;
            let mut offline_targets = Vec::new();
            {
                let active = engine.active_peers.read().await;
                for t in &target_peers {
                    let is_online = active.get(t).is_some_and(|e| !e.conn.is_closed());
                    if is_online {
                        engine.spawn_outbox_drain(t.clone());
                    } else {
                        any_target_offline = true;
                        offline_targets.push(t.clone());
                    }
                }
            }

            for peer_id in offline_targets {
                let eng = Arc::clone(&engine);
                tokio::spawn(async move {
                    if eng.connect_peer_by_id(&peer_id).await.is_ok() {
                        eng.spawn_outbox_drain(peer_id);
                    }
                });
            }

            if any_target_offline || target_peers.is_empty() {
                for hn in home_nodes {
                    engine.spawn_outbox_drain(hn);
                }
            }
        });
    }

    /// Lists decrypted timeline messages for `room_id`.
    pub fn list_room_timeline(&self, room_id: &str, limit: usize) -> Result<Vec<ChatMessageRecord>> {
        if self.store.is_home_node_mode() {
            return Ok(Vec::new());
        }
        self.store.list_room_timeline(room_id, limit)
    }

    /// Lists file/image messages across all rooms or for a single `room_id`, newest first.
    pub fn list_media_messages(
        &self,
        room_id: Option<&str>,
        limit: usize,
    ) -> Result<Vec<ChatMessageRecord>> {
        if self.store.is_home_node_mode() {
            return Ok(Vec::new());
        }
        self.store.list_media_messages(room_id, limit)
    }

    /// Deletes a message locally (`Delete for me`).
    /// For outgoing messages, `delete_received_file` is always ignored so sender source files are untouched.
    pub fn delete_message_local(&self, msg_id: &str, delete_received_file: bool) -> Result<bool> {
        let Some(room_id) = self
            .store
            .delete_message_for_me(msg_id, delete_received_file)?
        else {
            return Ok(false);
        };
        let _ = self.events_tx.send(EngineEvent::MessageDeleted {
            room_id,
            msg_id: msg_id.to_string(),
        });
        Ok(true)
    }

    /// WhatsApp-style "Delete for everyone" initiated by the original sender:
    /// converts the message into a revoked tombstone locally (WITHOUT touching sender source files)
    /// and signs + dispatches `RoomMessageRevoke` to all regular members and Home Nodes.
    pub fn revoke_message_for_everyone(self: &Arc<Self>, msg_id: &str) -> Result<ChatMessageRecord> {
        let record = self
            .store
            .get_message(msg_id)?
            .context("message not found")?;
        if record.direction != MessageDirection::Outgoing {
            bail!("仅允许消息发送方发起从对方设备撤回删除");
        }
        let my_id = self.my_endpoint_id().to_string();
        let members = self.store.list_room_members(&record.room_id)?;
        let target_peers: Vec<String> = members
            .iter()
            .filter(|m| m.role != "home_node" && m.node_id != my_id)
            .map(|m| m.node_id.clone())
            .collect();
        let home_nodes: Vec<String> = members
            .iter()
            .filter(|m| m.role == "home_node" && m.node_id != my_id)
            .map(|m| m.node_id.clone())
            .collect();

        let signed = sign_room_revoke(
            &self.secret_key,
            &record.room_id,
            msg_id,
            target_peers.clone(),
            false,
        );
        let signature_bytes = match signed {
            WireMessage::RoomMessageRevoke {
                signature_bytes, ..
            } => signature_bytes,
            _ => unreachable!(),
        };

        let updated = self
            .store
            .apply_revoke_to_local_message(msg_id, &my_id, Some(&record.room_id), false)?
            .context("message disappeared during revoke")?;

        for target in &target_peers {
            self.store.enqueue_pending_room_revoke(
                &record.room_id,
                msg_id,
                &my_id,
                target,
                false,
                &[],
                &signature_bytes,
            )?;
        }
        for hn in &home_nodes {
            self.store.enqueue_pending_room_revoke(
                &record.room_id,
                msg_id,
                &my_id,
                hn,
                true,
                &target_peers,
                &signature_bytes,
            )?;
        }

        let _ = self
            .events_tx
            .send(EngineEvent::MessageUpdated(updated.clone()));
        self.schedule_room_dispatch(target_peers, home_nodes);
        Ok(updated)
    }

    /// Toggles 24h Home Node blind-locker mode and updates retention TTL & optional USB installer path.
    pub fn set_home_node_mode(
        self: &Arc<Self>,
        enabled: bool,
        retention_days: u32,
        usb_installer_path: Option<String>,
    ) -> Result<HomeNodeStatus> {
        self.store.set_home_node_mode_setting(enabled)?;
        self.store.set_retention_days_setting(retention_days)?;
        self.store
            .set_usb_installer_path_setting(usb_installer_path.as_deref())?;

        *self
            .usb_installer_path
            .write()
            .expect("usb_installer_path lock poisoned") = usb_installer_path
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(PathBuf::from);

        if !enabled {
            let my_id = self.my_endpoint_id().to_string();
            let _ = self.store.ensure_default_personal_room(&my_id, "本机设备");
        }
        let _ = self.events_tx.send(EngineEvent::HomeNodeStatsUpdated);
        self.get_home_node_status()
    }

    /// Returns current Home Node mode configuration, USB bootstrap URLs, and blind locker cache statistics.
    pub fn get_home_node_status(&self) -> Result<HomeNodeStatus> {
        let enabled = self.store.is_home_node_mode();
        let retention_days = self.store.get_retention_days();
        let usb_installer_path = self.store.get_usb_installer_path();
        let stats = self.store.get_home_node_stats()?;

        let usb_bootstrap_urls: Vec<String> = self
            .lan
            .usb_tether_ips()
            .into_iter()
            .filter(|ip| ip.is_ipv4())
            .map(|ip| {
                format!(
                    "http://{}:{}",
                    ip,
                    crate::net::usb_bootstrap::USB_BOOTSTRAP_HTTP_PORT
                )
            })
            .collect();

        Ok(HomeNodeStatus {
            enabled,
            retention_days,
            usb_installer_path,
            usb_bootstrap_urls,
            stats,
        })
    }

    /// Immediately scans and removes expired blind locker `.enc` caches from disk.
    pub async fn purge_expired_locker_now(&self) -> Result<usize> {
        let paths = self.store.purge_expired_locker_items()?;
        let mut deleted = 0usize;
        for p in paths {
            match tokio::fs::remove_file(&p).await {
                Ok(_) => deleted += 1,
                Err(e) if e.kind() == std::io::ErrorKind::NotFound => deleted += 1,
                Err(e) => tracing::warn!("failed to purge expired locker file {p}: {e}"),
            }
        }
        if deleted > 0 {
            let _ = self.events_tx.send(EngineEvent::HomeNodeStatsUpdated);
        }
        Ok(deleted)
    }

    /// Probes USB tethering neighbors on `:42420` to auto-discover an attached Home Node.
    pub async fn probe_usb_home_node(self: &Arc<Self>) -> Option<(String, UsbBootstrapPayload)> {
        let mut candidates: Vec<IpAddr> = Vec::new();
        for ep in self.lan.snapshot_endpoints() {
            if let IpAddr::V4(v4) = ep.local_addr.ip()
                && (ep.interface.is_usb_tether || is_usb_tether_adapter(&ep.interface.name, &IpAddr::V4(v4)))
            {
                let oct = v4.octets();
                for host in [129u8, 1u8, 2u8, 42u8] {
                    let cand = IpAddr::V4(Ipv4Addr::new(oct[0], oct[1], oct[2], host));
                    if cand != IpAddr::V4(v4) && !candidates.contains(&cand) {
                        candidates.push(cand);
                    }
                }
            }
        }
        let default_usb_gw = IpAddr::V4(Ipv4Addr::new(192, 168, 42, 129));
        if !candidates.contains(&default_usb_gw) {
            candidates.push(default_usb_gw);
        }

        let found = probe_usb_bootstrap_candidates(candidates).await;
        if let Some((ref url, ref payload)) = found {
            let _ = self.events_tx.send(EngineEvent::UsbHomeNodeDiscovered {
                node_id: payload.node_id.clone(),
                bootstrap_url: url.clone(),
            });
        }
        found
    }

    /// One-click pairs with a USB-discovered Home Node and registers it as `home_node` in `room_id`.
    pub async fn bind_usb_home_node(
        self: &Arc<Self>,
        room_id: &str,
        payload: UsbBootstrapPayload,
    ) -> Result<TrustedPeerAlias> {
        let ticket = PairingTicket::from_qr_string(&payload.pairing_ticket_json)?;
        let node_id = ticket.endpoint_addr.id.to_string();
        let display_name = if payload.device_name.trim().is_empty() {
            "家庭常驻节点 (USB)".to_string()
        } else {
            payload.device_name.clone()
        };

        self.store.upsert_peer(&node_id, &display_name)?;
        self.persist_peer_hints(&node_id, &ticket.lan_addrs, Some(&ticket.endpoint_addr));
        self.store
            .upsert_room_member(room_id, &node_id, &display_name, "home_node")?;

        let lan_addrs: Vec<SocketAddr> = ticket
            .lan_addrs
            .iter()
            .filter_map(|s| s.parse().ok())
            .collect();
        let _ = self.connect_peer(ticket.endpoint_addr, lan_addrs).await;
        let _ = self.send_room_sync_to_peer(room_id, &node_id).await;
        let _ = self.events_tx.send(EngineEvent::RoomUpdated {
            room_id: room_id.to_string(),
        });

        Ok(TrustedPeerAlias {
            node_id,
            display_name,
            created_at_ms: crate::db::store::now_millis(),
            last_seen_ms: Some(crate::db::store::now_millis()),
            avatar_hash: None,
            avatar_path: None,
        })
    }

    /// Checks Windows USB tethering route metric protection status.
    pub fn usb_route_protection_status(&self) -> Result<UsbRouteProtectionStatus> {
        ensure_usb_tether_metric_safe()
    }

    // -------------------------------------------------------------------------
    // Hints, Connection Management, and Phase 1 Compat
    // -------------------------------------------------------------------------

    fn persist_peer_hints(
        &self,
        peer_id: &str,
        new_lan_addrs: &[String],
        new_endpoint_addr: Option<&EndpointAddr>,
    ) {
        self.store
            .merge_peer_hints(peer_id, new_lan_addrs, new_endpoint_addr);
    }

    fn load_peer_hints(&self, peer_id: &str) -> (Option<EndpointAddr>, Vec<SocketAddr>) {
        self.store.load_peer_hints(peer_id)
    }

    /// Connects to a paired peer using its persisted `EndpointAddr` and LAN/USB hints,
    /// sending an on-demand NIC refresh + single LAN wakeup beacon if not yet active.
    pub async fn connect_peer_by_id(self: &Arc<Self>, peer_id: &str) -> Result<TransportKind> {
        let endpoint_id: EndpointId = peer_id.parse().context("invalid peer EndpointId")?;
        if self.active_transport(peer_id).await.is_none() {
            let _ = self.refresh_network_interfaces(Vec::new());
            self.broadcast_lan_beacon_once();
        }
        let (saved_addr, saved_lan) = self.load_peer_hints(peer_id);
        let addr = saved_addr.unwrap_or_else(|| EndpointAddr::new(endpoint_id));
        self.connect_peer(addr, saved_lan).await
    }

    /// Returns the active transport kind for `peer_id` if a non-closed connection exists.
    pub async fn active_transport(&self, peer_id: &str) -> Option<TransportKind> {
        let map = self.active_peers.read().await;
        map.get(peer_id)
            .filter(|e| !e.conn.is_closed())
            .map(|e| e.conn.transport_kind())
    }

    /// Snapshots all currently active `(peer_id, transport_kind)` connections.
    pub async fn snapshot_active_transports(&self) -> Vec<(String, TransportKind)> {
        let map = self.active_peers.read().await;
        map.iter()
            .filter(|(_, e)| !e.conn.is_closed())
            .map(|(k, e)| (k.clone(), e.conn.transport_kind()))
            .collect()
    }

    /// Dials all paired peers that do not currently have an open connection,
    /// without blocking the caller.
    pub fn spawn_connect_all_paired_peers(self: &Arc<Self>) {
        let engine = Arc::clone(self);
        tokio::spawn(async move {
            let Ok(peers) = engine.store.list_peers() else {
                return;
            };
            let my_id = engine.my_endpoint_id().to_string();
            let mut to_dial = Vec::new();
            let active = engine.active_peers.read().await;
            for p in peers {
                if p.node_id == my_id {
                    continue;
                }
                if !active.get(&p.node_id).is_some_and(|e| !e.conn.is_closed()) {
                    to_dial.push(p.node_id);
                }
            }
            drop(active);

            if !to_dial.is_empty() {
                engine.wait_lan_ready().await;
                engine.broadcast_lan_beacon_once();
                for peer_id in to_dial {
                    let eng = Arc::clone(&engine);
                    tokio::spawn(async move {
                        let _ = tokio::time::timeout(
                            std::time::Duration::from_secs(6),
                            eng.connect_peer_by_id(&peer_id),
                        )
                        .await;
                    });
                }
            }
        });
    }

    /// Connects to `peer_addr`, prioritizing USB tethering -> LAN physical NIC -> Iroh WAN/Relay.
    pub async fn connect_peer(
        self: &Arc<Self>,
        peer_addr: EndpointAddr,
        lan_addrs: Vec<SocketAddr>,
    ) -> Result<TransportKind> {
        let peer_id_typed = peer_addr.id;
        let peer_id = peer_id_typed.to_string();

        if peer_id != self.my_endpoint_id().to_string() && !self.is_trusted_peer(&peer_id)? {
            self.store.upsert_peer(&peer_id, "Paired Device")?;
        }

        let (_, saved_lan) = self.load_peer_hints(&peer_id);
        let mut effective_lan = lan_addrs;
        for addr in saved_lan {
            if !effective_lan.contains(&addr) {
                effective_lan.push(addr);
            }
        }
        effective_lan.sort_by_key(|a| {
            (
                !self.lan.can_reach_via_usb(*a),
                !is_usb_tether_adapter("", &a.ip()),
            )
        });

        let has_usb_candidate = effective_lan.iter().any(|a| self.lan.can_reach_via_usb(*a));
        let mut only_try_usb_upgrade = false;
        let mut existing_open_transport: Option<TransportKind> = None;

        // Reuse an already-open connection only if it passes a quick liveness probe
        // (avoids hanging onto zombie Wi-Fi/WAN sockets when network switches).
        // Explicitly drop the read lock BEFORE awaiting `probe_connection_alive` or
        // acquiring `.write().await` (in Rust 2024 `if let` chains still extend temporaries!).
        let existing_opt = {
            let map = self.active_peers.read().await;
            map.get(&peer_id)
                .cloned()
                .filter(|e| !e.conn.is_closed())
        };
        if let Some(existing) = existing_opt {
            let transport = existing.conn.transport_kind();
            let alive = Self::probe_connection_alive(&existing.conn).await;
            if !alive {
                let removed = {
                    let mut map = self.active_peers.write().await;
                    if map.get(&peer_id).is_some_and(|e| e.id == existing.id) {
                        map.remove(&peer_id);
                        true
                    } else {
                        false
                    }
                };
                if removed {
                    existing.conn.close();
                }
            } else {
                existing_open_transport = Some(transport);
                if transport == TransportKind::UsbTetherDirect
                    || (transport == TransportKind::LanDirectPhysicalNic && !has_usb_candidate)
                    || effective_lan.is_empty()
                {
                    let _ = self.events_tx.send(EngineEvent::PeerConnected {
                        peer_id: peer_id.clone(),
                        transport,
                    });
                    self.spawn_outbox_drain(peer_id.clone());
                    self.spawn_blind_locker_drain(peer_id);
                    return Ok(transport);
                }
                if transport == TransportKind::LanDirectPhysicalNic && has_usb_candidate {
                    only_try_usb_upgrade = true;
                }
            }
        }

        // 1. Fast USB/LAN physical-NIC direct attempt first (concurrent probe)
        self.wait_lan_ready().await;
        let lan_candidates: Vec<SocketAddr> = effective_lan
            .iter()
            .copied()
            .filter(|addr| !only_try_usb_upgrade || self.lan.can_reach_via_usb(*addr))
            .collect();
        if let Some((active_remote, lan_conn, is_usb)) = self
            .try_connect_best_lan_addr(&lan_candidates, peer_id_typed)
            .await
        {
            self.persist_peer_hints(&peer_id, &[active_remote.to_string()], Some(&peer_addr));
            let active = self.classify_noq_connection(lan_conn, active_remote.ip(), is_usb);
            let kind = active.transport_kind();
            self.register_active_connection(peer_id.clone(), active)
                .await;
            return Ok(kind);
        }

        if let Some(transport) = existing_open_transport.or(self.active_transport(&peer_id).await) {
            let _ = self.events_tx.send(EngineEvent::PeerConnected {
                peer_id: peer_id.clone(),
                transport,
            });
            self.spawn_outbox_drain(peer_id.clone());
            self.spawn_blind_locker_drain(peer_id);
            return Ok(transport);
        }

        // 2. Fallback / WAN P2P + Relay via Iroh
        tracing::info!("dialing peer {peer_id} over Iroh WAN/Relay");
        let wan = self.ensure_wan().await?;
        let wan_conn = tokio::time::timeout(
            std::time::Duration::from_secs(10),
            wan.connect(peer_addr.clone()),
        )
        .await
        .context("Iroh WAN connect timed out")??;
        self.persist_peer_hints(&peer_id, &[], Some(&peer_addr));
        let active_wan = ActiveConnection::Wan(wan_conn);
        let initial_kind = active_wan.transport_kind();
        self.register_active_connection(peer_id.clone(), active_wan)
            .await;

        Ok(initial_kind)
    }

    /// Probes candidate LAN/USB socket addresses concurrently, returning the first authenticated
    /// connection (with USB-tether and IPv4 candidates prioritized).
    async fn try_connect_best_lan_addr(
        &self,
        addrs: &[SocketAddr],
        peer_id_typed: EndpointId,
    ) -> Option<(SocketAddr, noq::Connection, bool)> {
        if addrs.is_empty() {
            return None;
        }
        let mut sorted = addrs.to_vec();
        sorted.sort_by_key(|a| (!self.lan.can_reach_via_usb(*a), !a.is_ipv4()));
        let has_fast_v4_or_usb = sorted
            .iter()
            .any(|a| self.lan.can_reach_via_usb(*a) || a.is_ipv4());

        let mut join_set = tokio::task::JoinSet::new();
        for addr in sorted {
            let lan = Arc::clone(&self.lan);
            let key = self.secret_key.clone();
            let is_fast_tier = self.lan.can_reach_via_usb(addr) || addr.is_ipv4();
            let stagger_ms = if has_fast_v4_or_usb && !is_fast_tier {
                120
            } else {
                0
            };
            join_set.spawn(async move {
                if stagger_ms > 0 {
                    tokio::time::sleep(std::time::Duration::from_millis(stagger_ms)).await;
                }
                let res = tokio::time::timeout(
                    std::time::Duration::from_millis(1200),
                    lan.connect_and_auth(addr, &key, peer_id_typed),
                )
                .await;
                res.map(|inner| inner.map(|(conn, is_usb)| (addr, conn, is_usb)))
            });
        }

        while let Some(res) = join_set.join_next().await {
            if let Ok(Ok(Ok((addr, conn, is_usb)))) = res {
                join_set.abort_all();
                while let Some(extra) = join_set.try_join_next() {
                    if let Ok(Ok(Ok((_, extra_conn, _)))) = extra {
                        extra_conn.close(0u32.into(), b"superseded");
                    }
                }
                return Some((addr, conn, is_usb));
            }
        }
        None
    }

    /// Queues a legacy Phase 1 text message in SQLite timeline/Outbox and immediately sends if peer is online.
    pub fn send_text(self: &Arc<Self>, peer_id: &str, text: &str) -> Result<ChatMessageRecord> {
        let msg_id = Uuid::now_v7().to_string();
        let record = self.store.enqueue_outgoing_text(&msg_id, peer_id, text)?;
        let _ = self.events_tx.send(EngineEvent::MessageAdded(record.clone()));
        self.spawn_outbox_drain(peer_id.to_string());
        Ok(record)
    }

    /// Indexes a local file, queues it in SQLite Outbox, and sends if online (Phase 1 compatibility).
    pub async fn send_file(
        self: &Arc<Self>,
        peer_id: &str,
        file_path: PathBuf,
    ) -> Result<ChatMessageRecord> {
        let indexed = index_file(&file_path, self.config.chunk_size_bytes).await?;
        let file_name = file_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("file.bin")
            .to_string();
        let msg_id = Uuid::now_v7().to_string();

        let record = self.store.enqueue_outgoing_file(
            &msg_id,
            peer_id,
            &file_name,
            indexed.file_size,
            &file_path.to_string_lossy(),
            &indexed.root_blake3,
            indexed.chunk_size,
            indexed.chunk_hashes.len(),
        )?;
        let _ = self.events_tx.send(EngineEvent::MessageAdded(record.clone()));
        self.spawn_outbox_drain(peer_id.to_string());
        Ok(record)
    }

    /// Lists chat messages for `peer_id` (Phase 1 compat).
    pub fn list_timeline(&self, peer_id: &str, limit: usize) -> Result<Vec<ChatMessageRecord>> {
        self.store.list_timeline(peer_id, limit)
    }

    /// Lists paired peers (excluding the local device itself).
    pub fn list_peers(&self) -> Result<Vec<TrustedPeerAlias>> {
        let my_id = self.my_endpoint_id().to_string();
        Ok(self
            .store
            .list_peers()?
            .into_iter()
            .filter(|p| p.node_id != my_id)
            .collect())
    }

    fn is_trusted_peer(&self, peer_id: &str) -> Result<bool> {
        Ok(self
            .store
            .list_peers()?
            .iter()
            .any(|p| p.node_id == peer_id))
    }

    async fn probe_connection_alive(conn: &ActiveConnection) -> bool {
        if conn.is_closed() {
            return false;
        }
        let timeout_ms = if matches!(
            conn,
            ActiveConnection::Wan(_) | ActiveConnection::WanDirectNoq(_)
        ) {
            1200
        } else {
            500
        };
        let probe = async {
            let (mut send, mut recv) = match conn {
                ActiveConnection::UsbLan(c)
                | ActiveConnection::Lan(c)
                | ActiveConnection::WanDirectNoq(c) => c.open_bi().await?,
                ActiveConnection::Wan(c) => c.open_bi().await?,
            };
            let ping = WireMessage::PeerCapabilities {
                device_name: "ping".to_string(),
                lan_probe_addrs: Vec::new(),
            };
            write_wire_message(&mut send, &ping).await?;
            let _ = send.finish();
            let _ = read_wire_message(&mut recv).await?;
            Ok::<(), anyhow::Error>(())
        };
        tokio::time::timeout(std::time::Duration::from_millis(timeout_ms), probe)
            .await
            .is_ok_and(|res| res.is_ok())
    }

    fn spawn_wan_capabilities_upgrade(
        self: &Arc<Self>,
        peer_id: String,
        wan_conn: iroh::endpoint::Connection,
    ) {
        let Ok(peer_id_typed) = peer_id.parse::<EndpointId>() else {
            return;
        };
        let engine_upgrade = Arc::clone(self);
        tokio::spawn(async move {
            let Ok(Ok((mut send, mut recv))) = tokio::time::timeout(
                std::time::Duration::from_secs(2),
                wan_conn.open_bi(),
            )
            .await
            else {
                return;
            };
            let my_caps = WireMessage::PeerCapabilities {
                device_name: "local-device".to_string(),
                lan_probe_addrs: engine_upgrade
                    .lan
                    .advertise_addrs()
                    .into_iter()
                    .map(|a| a.to_string())
                    .collect(),
            };
            let _ = write_wire_message(&mut send, &my_caps).await;
            let _ = send.finish();
            if let Ok(Ok(Some(WireMessage::PeerCapabilities {
                lan_probe_addrs, ..
            }))) = tokio::time::timeout(
                std::time::Duration::from_secs(2),
                read_wire_message(&mut recv),
            )
            .await
            {
                engine_upgrade.persist_peer_hints(&peer_id, &lan_probe_addrs, None);
                let parsed: Vec<SocketAddr> = lan_probe_addrs
                    .iter()
                    .filter_map(|s| s.parse::<SocketAddr>().ok())
                    .collect();
                if let Some((active_remote, lan_conn, is_usb)) = engine_upgrade
                    .try_connect_best_lan_addr(&parsed, peer_id_typed)
                    .await
                {
                    engine_upgrade.persist_peer_hints(
                        &peer_id,
                        &[active_remote.to_string()],
                        None,
                    );
                    let active =
                        engine_upgrade.classify_noq_connection(lan_conn, active_remote.ip(), is_usb);
                    engine_upgrade
                        .register_active_connection(peer_id, active)
                        .await;
                }
            }
        });
    }

    async fn emit_wan_path_change_if_primary(
        &self,
        peer_id: &str,
        conn_id: u64,
        wan_conn: &iroh::endpoint::Connection,
        last_kind: &mut TransportKind,
    ) -> bool {
        let current_kind = classify_iroh_connection(wan_conn);
        if current_kind == *last_kind {
            return true;
        }
        let is_still_primary = {
            let map = self.active_peers.read().await;
            map.get(peer_id).is_some_and(|e| e.id == conn_id)
        };
        if !is_still_primary {
            return false;
        }
        *last_kind = current_kind;
        tracing::info!(
            "peer WAN path updated peer_id={} conn_id={} transport={:?}",
            peer_id,
            conn_id,
            current_kind
        );
        let _ = self.events_tx.send(EngineEvent::PeerConnected {
            peer_id: peer_id.to_string(),
            transport: current_kind,
        });
        true
    }

    fn spawn_wan_path_observer(
        self: &Arc<Self>,
        peer_id: String,
        conn_id: u64,
        wan_conn: iroh::endpoint::Connection,
        initial_kind: TransportKind,
    ) {
        let engine = Arc::clone(self);
        tokio::spawn(async move {
            use tokio_stream::StreamExt;

            let mut events = wan_conn.path_events();
            let mut last_kind = initial_kind;

            // Check immediately after subscribing in case Iroh switched paths right before
            // `path_events()` was created.
            if !engine
                .emit_wan_path_change_if_primary(&peer_id, conn_id, &wan_conn, &mut last_kind)
                .await
            {
                return;
            }

            while let Some(_ev) = events.next().await {
                if !engine
                    .emit_wan_path_change_if_primary(&peer_id, conn_id, &wan_conn, &mut last_kind)
                    .await
                {
                    break;
                }
            }
        });
    }

    async fn register_active_connection(
        self: &Arc<Self>,
        peer_id: String,
        conn: ActiveConnection,
    ) {
        let conn_id = self.next_conn_id.fetch_add(1, Ordering::Relaxed);
        let transport = conn.transport_kind();
        let existing_same_or_higher = {
            let map = self.active_peers.read().await;
            map.get(&peer_id).cloned().filter(|e| {
                !e.conn.is_closed()
                    && e.conn.transport_kind().priority_rank() >= transport.priority_rank()
            })
        };
        if let Some(existing) = existing_same_or_higher {
            let alive = Self::probe_connection_alive(&existing.conn).await;
            if alive {
                // Keep existing primary link intact while still accepting streams on `conn`,
                // and re-emit PeerConnected so UI listeners never miss inbound connections.
                let _ = self.events_tx.send(EngineEvent::PeerConnected {
                    peer_id: peer_id.clone(),
                    transport: existing.conn.transport_kind(),
                });
                self.spawn_incoming_stream_reader(peer_id, conn_id, conn);
                return;
            }
            existing.conn.close();
        }
        let superseded = {
            let mut map = self.active_peers.write().await;
            if let Some(existing) = map.get(&peer_id)
                && !existing.conn.is_closed()
                && existing.conn.transport_kind().priority_rank() >= transport.priority_rank()
            {
                drop(map);
                self.spawn_incoming_stream_reader(peer_id, conn_id, conn);
                return;
            }
            map.insert(
                peer_id.clone(),
                ActiveEntry {
                    id: conn_id,
                    conn: conn.clone(),
                },
            )
        };
        if let Some(old) = superseded
            && transport.priority_rank() > old.conn.transport_kind().priority_rank()
        {
            old.conn.close();
        }

        let wan_for_upgrade = match &conn {
            ActiveConnection::Wan(w) => Some(w.clone()),
            _ => None,
        };

        tracing::info!(
            "peer connected peer_id={} conn_id={} transport={:?}",
            peer_id,
            conn_id,
            transport
        );
        let _ = self.events_tx.send(EngineEvent::PeerConnected {
            peer_id: peer_id.clone(),
            transport,
        });

        self.spawn_incoming_stream_reader(peer_id.clone(), conn_id, conn);
        self.spawn_outbox_drain(peer_id.clone());
        self.spawn_blind_locker_drain(peer_id.clone());
        self.spawn_profile_sync(peer_id.clone());

        if let Some(wan_conn) = wan_for_upgrade {
            self.spawn_wan_capabilities_upgrade(peer_id.clone(), wan_conn.clone());
            self.spawn_wan_path_observer(peer_id.clone(), conn_id, wan_conn, transport);
        }

        let eng_sync = Arc::clone(self);
        let peer_sync = peer_id;
        tokio::spawn(async move {
            if let Ok(rooms) = eng_sync.store.list_rooms_with_member(&peer_sync) {
                for (room, _) in rooms {
                    let _ = eng_sync.send_room_sync_to_peer(&room.room_id, &peer_sync).await;
                }
            }
        });
    }

    pub fn get_my_avatar_path(&self) -> Option<String> {
        let my_id = self.my_endpoint_id().to_string();
        resolve_self_avatar_path(&self.store, &self.config.data_dir, &my_id)
    }

    pub async fn update_my_profile(
        self: &Arc<Self>,
        display_name: Option<String>,
        avatar_png: Option<Vec<u8>>,
        clear_avatar: bool,
    ) -> Result<Option<String>> {
        let my_id = self.my_endpoint_id().to_string();
        let clean_name = display_name
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty());

        let new_hash_owned: String;
        let mut next_path: Option<String> = self.get_my_avatar_path();
        let mut hash_update: Option<Option<&str>> = None;

        if clear_avatar {
            remove_avatar_files(&self.config.data_dir, &my_id);
            hash_update = Some(None);
            next_path = None;
        } else if let Some(ref bytes) = avatar_png {
            let hash = compute_avatar_hash(bytes);
            let path = write_avatar_file(&self.config.data_dir, &my_id, &hash, bytes)?;
            new_hash_owned = hash;
            hash_update = Some(Some(new_hash_owned.as_str()));
            next_path = Some(path);
        }

        self.store.set_self_profile(clean_name, hash_update)?;

        let (snapshot_name, snapshot_hash, snapshot_bytes) =
            local_profile_snapshot(&self.store, &self.config.data_dir, &my_id);
        let push = WireMessage::ProfilePush {
            display_name: snapshot_name,
            avatar_hash: snapshot_hash,
            avatar_png: snapshot_bytes,
            clear_avatar,
        };

        let peers: Vec<(String, ActiveConnection)> = {
            let guard = self.active_peers.read().await;
            guard
                .iter()
                .filter(|(_, e)| !e.conn.is_closed())
                .map(|(pid, e)| (pid.clone(), e.conn.clone()))
                .collect()
        };
        for (_, conn) in peers {
            let msg = push.clone();
            tokio::spawn(async move {
                let _ = Self::send_oneway_wire(&conn, &msg).await;
            });
        }

        Ok(next_path)
    }

    async fn send_oneway_wire(conn: &ActiveConnection, msg: &WireMessage) -> Result<()> {
        match conn {
            ActiveConnection::UsbLan(c)
            | ActiveConnection::Lan(c)
            | ActiveConnection::WanDirectNoq(c) => {
                let (mut s, _r) = c.open_bi().await?;
                write_wire_message(&mut s, msg).await?;
                let _ = s.finish();
                Ok(())
            }
            ActiveConnection::Wan(c) => {
                let (mut s, _r) = c.open_bi().await?;
                write_wire_message(&mut s, msg).await?;
                let _ = s.finish();
                Ok(())
            }
        }
    }

    async fn exchange_profile_on_stream<W, R>(
        mut send: W,
        mut recv: R,
        announce: &WireMessage,
        my_name: String,
        my_hash: Option<String>,
        my_bytes: Option<Vec<u8>>,
    ) -> Result<Option<WireMessage>>
    where
        W: tokio::io::AsyncWrite + Unpin,
        R: tokio::io::AsyncRead + Unpin,
    {
        write_wire_message(&mut send, announce).await?;
        let resp = read_wire_message(&mut recv).await?;
        if let Some(WireMessage::ProfileResponse {
            ref need_your_avatar,
            ..
        }) = resp
            && *need_your_avatar
            && my_bytes.is_some()
        {
            let push = WireMessage::ProfilePush {
                display_name: my_name,
                avatar_hash: my_hash,
                avatar_png: my_bytes,
                clear_avatar: false,
            };
            let _ = write_wire_message(&mut send, &push).await;
        }
        Ok(resp)
    }

    fn spawn_profile_sync(self: &Arc<Self>, peer_id: String) {
        let engine = Arc::clone(self);
        tokio::spawn(async move {
            let conn = {
                let guard = engine.active_peers.read().await;
                guard.get(&peer_id).map(|e| e.conn.clone())
            };
            let Some(conn) = conn else {
                return;
            };
            let my_id = engine.my_endpoint_id().to_string();
            let (my_name, my_hash, my_bytes) =
                local_profile_snapshot(&engine.store, &engine.config.data_dir, &my_id);
            let known_peer_hash = engine
                .store
                .get_peer_profile(&peer_id)
                .ok()
                .flatten()
                .and_then(|(_, h, p)| {
                    if p.as_deref().is_some_and(|path| std::path::Path::new(path).exists()) {
                        h
                    } else {
                        None
                    }
                });

            let announce = WireMessage::ProfileAnnounce {
                display_name: my_name.clone(),
                avatar_hash: my_hash.clone(),
                known_peer_avatar_hash: known_peer_hash,
            };

            let exchanged = tokio::time::timeout(std::time::Duration::from_secs(10), async {
                match &conn {
                    ActiveConnection::UsbLan(c)
                    | ActiveConnection::Lan(c)
                    | ActiveConnection::WanDirectNoq(c) => {
                        let (mut s, r) = c.open_bi().await?;
                        let resp = Self::exchange_profile_on_stream(
                            &mut s, r, &announce, my_name, my_hash, my_bytes,
                        )
                        .await?;
                        let _ = s.finish();
                        Ok::<Option<WireMessage>, anyhow::Error>(resp)
                    }
                    ActiveConnection::Wan(c) => {
                        let (mut s, r) = c.open_bi().await?;
                        let resp = Self::exchange_profile_on_stream(
                            &mut s, r, &announce, my_name, my_hash, my_bytes,
                        )
                        .await?;
                        let _ = s.finish();
                        Ok::<Option<WireMessage>, anyhow::Error>(resp)
                    }
                }
            })
            .await;

            if let Ok(Ok(Some(WireMessage::ProfileResponse {
                display_name,
                avatar_hash,
                avatar_png,
                ..
            }))) = exchanged
            {
                let clear = avatar_hash.is_none();
                let _ = apply_remote_profile_update(
                    &engine.store,
                    &engine.config.data_dir,
                    &engine.events_tx,
                    &peer_id,
                    &display_name,
                    avatar_hash,
                    avatar_png,
                    clear,
                );
            }
        });
    }

    fn spawn_wan_accept_loop(self: &Arc<Self>) {
        if self.wan_accept_started.swap(true, Ordering::SeqCst) {
            return;
        }
        // Accept incoming Iroh WAN/Relay connections
        let engine_wan = Arc::clone(self);
        tokio::spawn(async move {
            let Ok(wan) = engine_wan.ensure_wan().await else {
                return;
            };
            while let Some(incoming) = wan.inner().accept().await {
                let engine = Arc::clone(&engine_wan);
                tokio::spawn(async move {
                    match incoming.await {
                        Ok(conn) => {
                            let peer_id = conn.remote_id().to_string();
                            let _ = engine.store.upsert_peer(&peer_id, "Paired Device");
                            engine
                                .register_active_connection(peer_id, ActiveConnection::Wan(conn))
                                .await;
                        }
                        Err(e) => tracing::warn!("Iroh incoming handshake failed: {e:#}"),
                    }
                });
            }
        });
    }

    fn spawn_pinned_accept_loop(self: &Arc<Self>, pinned: PinnedLanEndpoint) {
        let noq_ep = pinned.endpoint;
        let is_usb_ep = pinned.interface.is_usb_tether;
        let engine_lan = Arc::clone(self);
        tokio::spawn(async move {
            while let Some(incoming) = noq_ep.accept().await {
                let engine = Arc::clone(&engine_lan);
                let incoming_remote_ip = incoming.remote_address().ip();
                tokio::spawn(async move {
                    match incoming.await {
                        Ok(conn) => match authenticate_responder(&conn, &engine.secret_key).await {
                            Ok(peer_pub) => {
                                let peer_id = peer_pub.to_string();
                                let _ = engine.store.upsert_peer(&peer_id, "Paired Device");
                                let remote_usb =
                                    is_usb_ep || is_usb_tether_adapter("", &incoming_remote_ip);
                                let active =
                                    engine.classify_noq_connection(conn, incoming_remote_ip, remote_usb);
                                engine.register_active_connection(peer_id, active).await;
                            }
                            Err(e) => {
                                tracing::warn!("LAN peer auth rejected: {e:#}");
                                conn.close(1u32.into(), b"auth failed");
                            }
                        },
                        Err(e) => tracing::warn!("LAN QUIC incoming handshake failed: {e:#}"),
                    }
                });
            }
        });
    }

    fn spawn_lan_discovery(self: &Arc<Self>) {
        let endpoints_init = self.lan.snapshot_endpoints();
        let has_real_ipv4 = endpoints_init
            .iter()
            .any(|ep| matches!(ep.local_addr.ip(), IpAddr::V4(v4) if !v4.is_loopback()));
        if !has_real_ipv4 || self.lan_discovery_started.swap(true, Ordering::SeqCst) {
            return;
        }

        let my_id = self.my_endpoint_id().to_string();

        // 1. Receiver loop on 0.0.0.0:42426 (SO_REUSEADDR)
        let engine_rx = Arc::clone(self);
        let my_id_rx = my_id.clone();
        tokio::spawn(async move {
            let sock = match Socket::new(Domain::IPV4, Type::DGRAM, Some(Protocol::UDP)) {
                Ok(s) => s,
                Err(e) => {
                    tracing::warn!("LAN beacon socket create failed: {e}");
                    return;
                }
            };
            let _ = sock.set_reuse_address(true);
            let _ = sock.set_broadcast(true);
            let _ = sock.set_nonblocking(true);
            let bind_addr: SocketAddrV4 = SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, LAN_BEACON_PORT);
            if let Err(e) = sock.bind(&bind_addr.into()) {
                tracing::warn!("LAN beacon bind 0.0.0.0:{LAN_BEACON_PORT} failed: {e}");
                return;
            }
            for ep in &endpoints_init {
                if let IpAddr::V4(v4) = ep.local_addr.ip()
                    && !v4.is_loopback()
                {
                    let _ = sock.join_multicast_v4(&LAN_MULTICAST_V4, &v4);
                }
            }
            let std_sock: std::net::UdpSocket = sock.into();
            let Ok(udp) = tokio::net::UdpSocket::from_std(std_sock) else {
                return;
            };
            tracing::info!("LAN discovery listening on 0.0.0.0:{LAN_BEACON_PORT}");

            let mut buf = [0u8; 4096];
            let mut last_attempt: HashMap<String, std::time::Instant> = HashMap::new();
            while let Ok((len, src)) = udp.recv_from(&mut buf).await {
                let Ok(beacon) = serde_json::from_slice::<LanBeacon>(&buf[..len]) else {
                    continue;
                };
                if beacon.node_id == my_id_rx {
                    continue;
                }

                // Auto-probe USB Home Nodes even before pairing!
                if beacon.is_home_node && is_usb_tether_adapter("", &src.ip()) {
                    let eng_probe = Arc::clone(&engine_rx);
                    let src_ip = src.ip();
                    tokio::spawn(async move {
                        if let Some((url, payload)) =
                            probe_usb_bootstrap_candidates(vec![src_ip]).await
                        {
                            let _ = eng_probe.events_tx.send(EngineEvent::UsbHomeNodeDiscovered {
                                node_id: payload.node_id,
                                bootstrap_url: url,
                            });
                        }
                    });
                }

                if !engine_rx.is_trusted_peer(&beacon.node_id).unwrap_or(false) {
                    continue;
                }

                let mut candidate_strs = beacon.lan_addrs.clone();
                let fallback = format!("{}:{}", src.ip(), PREFERRED_LAN_QUIC_PORT);
                if !candidate_strs.contains(&fallback) {
                    candidate_strs.push(fallback);
                }
                engine_rx.persist_peer_hints(
                    &beacon.node_id,
                    &candidate_strs,
                    Some(&beacon.endpoint_addr),
                );

                // Unicast reply back on matching physical NIC (only to non-reply broadcasts)
                if !beacon.is_reply {
                    let my_addrs: Vec<String> = engine_rx
                        .lan
                        .advertise_addrs()
                        .into_iter()
                        .map(|a| a.to_string())
                        .collect();
                    let reply = LanBeacon {
                        node_id: my_id_rx.clone(),
                        lan_addrs: my_addrs,
                        endpoint_addr: engine_rx.wan_addr_or_fallback(),
                        is_home_node: engine_rx.store.is_home_node_mode(),
                        is_reply: true,
                    };
                    if let Ok(payload) = serde_json::to_vec(&reply) {
                        let target = SocketAddr::new(src.ip(), LAN_BEACON_PORT);
                        for ep in engine_rx.lan.snapshot_endpoints() {
                            if ep.local_addr.is_ipv4()
                                && let Ok(tx_sock) = create_pinned_lan_udp_socket(&ep.interface, 0)
                            {
                                let _ = tx_sock.send_to(&payload, target);
                            }
                        }
                    }
                }

                let current_transport = engine_rx.active_transport(&beacon.node_id).await;
                let has_reachable_usb = engine_rx.lan.can_reach_via_usb(src)
                    || candidate_strs
                        .iter()
                        .filter_map(|s| s.parse::<SocketAddr>().ok())
                        .any(|a| engine_rx.lan.can_reach_via_usb(a));
                if current_transport == Some(TransportKind::UsbTetherDirect)
                    || (current_transport == Some(TransportKind::LanDirectPhysicalNic)
                        && !has_reachable_usb)
                {
                    continue;
                }

                let now = std::time::Instant::now();
                if let Some(prev) = last_attempt.get(&beacon.node_id)
                    && now.duration_since(*prev) < std::time::Duration::from_secs(2)
                {
                    continue;
                }
                last_attempt.insert(beacon.node_id.clone(), now);

                let lan_addrs: Vec<SocketAddr> = candidate_strs
                    .iter()
                    .filter_map(|s| s.parse().ok())
                    .collect();
                let eng = Arc::clone(&engine_rx);
                let peer_ep = beacon.endpoint_addr;
                let peer_id = beacon.node_id;
                tokio::spawn(async move {
                    if let Err(e) = eng.connect_peer(peer_ep, lan_addrs).await {
                        tracing::debug!("LAN beacon dial {} failed: {e:#}", peer_id);
                    }
                });
            }
        });

        // 2. Send a single initial wakeup beacon; further beacons are triggered on-demand or on NIC addition.
        self.broadcast_lan_beacon_once();
    }

    /// Sends a single on-demand LAN/USB wakeup UDP beacon on every physical/USB IPv4 NIC.
    pub fn broadcast_lan_beacon_once(&self) {
        let my_id = self.my_endpoint_id().to_string();
        let lan_addrs: Vec<String> = self
            .lan
            .advertise_addrs()
            .into_iter()
            .map(|a| a.to_string())
            .collect();
        let beacon = LanBeacon {
            node_id: my_id,
            lan_addrs,
            endpoint_addr: self.wan_addr_or_fallback(),
            is_home_node: self.store.is_home_node_mode(),
            is_reply: false,
        };
        let Ok(payload) = serde_json::to_vec(&beacon) else {
            return;
        };

        let mut peer_ips: Vec<SocketAddr> = Vec::new();
        if let Ok(peers) = self.store.list_peers() {
            for p in peers {
                let (_, saved) = self.load_peer_hints(&p.node_id);
                for a in saved {
                    if a.is_ipv4() {
                        let t = SocketAddr::new(a.ip(), LAN_BEACON_PORT);
                        if !peer_ips.contains(&t) {
                            peer_ips.push(t);
                        }
                    }
                }
            }
        }

        for ep in self.lan.snapshot_endpoints() {
            if let IpAddr::V4(v4) = ep.local_addr.ip()
                && !v4.is_loopback()
                && let Ok(tx_sock) = create_pinned_lan_udp_socket(&ep.interface, 0)
            {
                let _ = tx_sock.set_broadcast(true);
                let octets = v4.octets();
                let subnet_bcast = SocketAddr::new(
                    IpAddr::V4(Ipv4Addr::new(octets[0], octets[1], octets[2], 255)),
                    LAN_BEACON_PORT,
                );
                let global_bcast = SocketAddr::new(
                    IpAddr::V4(Ipv4Addr::BROADCAST),
                    LAN_BEACON_PORT,
                );
                let mcast = SocketAddr::new(
                    IpAddr::V4(LAN_MULTICAST_V4),
                    LAN_BEACON_PORT,
                );
                let _ = tx_sock.send_to(&payload, subnet_bcast);
                let _ = tx_sock.send_to(&payload, global_bcast);
                let _ = tx_sock.send_to(&payload, mcast);
                for target in &peer_ips {
                    let _ = tx_sock.send_to(&payload, *target);
                }
            }
        }
    }

    fn spawn_locker_ttl_gc_loop(self: &Arc<Self>) {
        let engine = Arc::clone(self);
        tokio::spawn(async move {
            loop {
                let _ = engine.purge_expired_locker_now().await;
                tokio::time::sleep(std::time::Duration::from_secs(1800)).await;
            }
        });
    }

    fn spawn_locker_ready_listener(self: &Arc<Self>) {
        let engine = Arc::clone(self);
        let mut rx = self.subscribe_events();
        tokio::spawn(async move {
            loop {
                match rx.recv().await {
                    Ok(EngineEvent::LockerItemReady { target_peers, .. }) => {
                        for target in target_peers {
                            engine.spawn_blind_locker_drain(target);
                        }
                    }
                    Ok(EngineEvent::OutboxRetryRequested { peer_id }) => {
                        if engine.active_transport(&peer_id).await.is_some() {
                            engine.spawn_outbox_drain(peer_id);
                        } else {
                            let eng = Arc::clone(&engine);
                            tokio::spawn(async move {
                                let _ = eng.connect_peer_by_id(&peer_id).await;
                            });
                        }
                    }
                    Ok(_) => {}
                    Err(broadcast::error::RecvError::Lagged(_)) => continue,
                    Err(broadcast::error::RecvError::Closed) => break,
                }
            }
        });
    }

    fn start_usb_bootstrap_http(self: &Arc<Self>) {
        let engine = Arc::clone(self);
        let installer = Arc::clone(&self.usb_installer_path);
        let provider = Arc::new(move || {
            let installer_opt = engine
                .usb_installer_path
                .read()
                .expect("usb_installer_path lock poisoned")
                .clone();
            let (installer_filename, installer_size_bytes) = match installer_opt {
                Some(ref p) => (
                    p.file_name().and_then(|n| n.to_str()).map(String::from),
                    std::fs::metadata(p).ok().map(|m| m.len()),
                ),
                None => (None, None),
            };
            let ticket_json = engine
                .create_pairing_ticket("家庭常驻盲盒节点")
                .and_then(|t| t.to_qr_string())
                .unwrap_or_default();
            let lan_addrs: Vec<String> = engine
                .lan
                .advertise_addrs()
                .into_iter()
                .map(|a| a.to_string())
                .collect();
            let usb_addrs: Vec<String> = engine
                .lan
                .usb_tether_ips()
                .into_iter()
                .map(|ip| ip.to_string())
                .collect();

            UsbBootstrapPayload {
                node_id: engine.my_endpoint_id().to_string(),
                device_name: "家庭常驻盲盒节点".to_string(),
                home_node_mode: engine.store.is_home_node_mode(),
                pairing_ticket_json: ticket_json,
                room_invite_json: None,
                installer_filename,
                installer_size_bytes,
                lan_addrs,
                usb_addrs,
            }
        });

        let ctrl_engine = Arc::clone(self);
        let local_ctrl: LocalControlHandler = Arc::new(move |method, path, body| {
            let eng = Arc::clone(&ctrl_engine);
            Box::pin(async move { eng.handle_local_control(&method, &path, &body).await })
        });

        start_usb_bootstrap_server(provider, installer, Some(local_ctrl));
    }

    async fn handle_local_control(
        self: &Arc<Self>,
        method: &str,
        path: &str,
        body: &[u8],
    ) -> (u16, Vec<u8>) {
        match (method, path) {
            ("GET", "/api/local/status") => match self.build_local_status_json().await {
                Ok(v) => (200, serde_json::to_vec(&v).unwrap_or_default()),
                Err(e) => (
                    500,
                    serde_json::to_vec(&serde_json::json!({"error": e.to_string()}))
                        .unwrap_or_default(),
                ),
            },
            ("POST", "/api/local/set-home-node") => {
                #[derive(serde::Deserialize)]
                struct Req {
                    enabled: bool,
                    retention_days: Option<u32>,
                    usb_installer_path: Option<String>,
                }
                let Ok(req) = serde_json::from_slice::<Req>(body) else {
                    return (400, br#"{"error":"invalid_json"}"#.to_vec());
                };
                match self.set_home_node_mode(
                    req.enabled,
                    req.retention_days.unwrap_or_else(|| self.store.get_retention_days()),
                    req.usb_installer_path,
                ) {
                    Ok(st) => (
                        200,
                        serde_json::to_vec(&serde_json::json!({
                            "enabled": st.enabled,
                            "retention_days": st.retention_days,
                            "usb_installer_path": st.usb_installer_path,
                            "usb_bootstrap_urls": st.usb_bootstrap_urls,
                            "active_cached_count": st.stats.active_cached_count,
                            "total_purged_count": st.stats.total_purged_count,
                            "registered_rooms_count": st.stats.registered_rooms_count,
                        }))
                        .unwrap_or_default(),
                    ),
                    Err(e) => (
                        400,
                        serde_json::to_vec(&serde_json::json!({"error": e.to_string()}))
                            .unwrap_or_default(),
                    ),
                }
            }
            ("POST", "/api/local/create-invite") => {
                #[derive(serde::Deserialize)]
                struct Req {
                    room_id: Option<String>,
                    device_name: String,
                    #[serde(default)]
                    invite_as_home_node: bool,
                }
                let Ok(req) = serde_json::from_slice::<Req>(body) else {
                    return (400, br#"{"error":"invalid_json"}"#.to_vec());
                };
                let rid = req
                    .room_id
                    .as_deref()
                    .filter(|s| !s.is_empty())
                    .unwrap_or(DEFAULT_PERSONAL_ROOM_ID);
                match self
                    .create_room_invite(rid, &req.device_name, req.invite_as_home_node)
                    .and_then(|t| t.to_qr_string())
                {
                    Ok(ticket_json) => (
                        200,
                        serde_json::to_vec(&serde_json::json!({ "ticket_json": ticket_json }))
                            .unwrap_or_default(),
                    ),
                    Err(e) => (
                        400,
                        serde_json::to_vec(&serde_json::json!({"error": e.to_string()}))
                            .unwrap_or_default(),
                    ),
                }
            }
            ("POST", "/api/local/join-room") => {
                #[derive(serde::Deserialize)]
                struct Req {
                    device_name: String,
                    ticket_json: String,
                }
                let Ok(req) = serde_json::from_slice::<Req>(body) else {
                    return (400, br#"{"error":"invalid_json"}"#.to_vec());
                };
                let Ok(ticket) = RoomInviteTicket::from_qr_string(&req.ticket_json) else {
                    return (400, br#"{"error":"invalid_room_invite_ticket"}"#.to_vec());
                };
                match self.join_room_with_invite(ticket, &req.device_name).await {
                    Ok(room) => (
                        200,
                        serde_json::to_vec(&serde_json::json!({
                            "room_id": room.room_id,
                            "name": room.name,
                            "room_type": room.room_type,
                            "home_node_mode": self.store.is_home_node_mode(),
                        }))
                        .unwrap_or_default(),
                    ),
                    Err(e) => (
                        400,
                        serde_json::to_vec(&serde_json::json!({"error": e.to_string()}))
                            .unwrap_or_default(),
                    ),
                }
            }
            ("POST", "/api/local/send-text") => {
                #[derive(serde::Deserialize)]
                struct Req {
                    room_id: Option<String>,
                    text: String,
                }
                let Ok(req) = serde_json::from_slice::<Req>(body) else {
                    return (400, br#"{"error":"invalid_json"}"#.to_vec());
                };
                let rid = req
                    .room_id
                    .as_deref()
                    .filter(|s| !s.is_empty())
                    .unwrap_or(DEFAULT_PERSONAL_ROOM_ID);
                match self.send_room_text(rid, &req.text) {
                    Ok(msg) => (
                        200,
                        serde_json::to_vec(&serde_json::json!({
                            "msg_id": msg.msg_id,
                            "room_id": msg.room_id,
                            "status": format!("{:?}", msg.status),
                        }))
                        .unwrap_or_default(),
                    ),
                    Err(e) => (
                        400,
                        serde_json::to_vec(&serde_json::json!({"error": e.to_string()}))
                            .unwrap_or_default(),
                    ),
                }
            }
            ("POST", "/api/local/connect-room") => {
                #[derive(serde::Deserialize)]
                struct Req {
                    room_id: Option<String>,
                }
                let req: Req = serde_json::from_slice(body).unwrap_or(Req { room_id: None });
                let rid = req
                    .room_id
                    .as_deref()
                    .filter(|s| !s.is_empty())
                    .unwrap_or(DEFAULT_PERSONAL_ROOM_ID);
                let my_id = self.my_endpoint_id().to_string();
                let members = self.list_room_members(rid).unwrap_or_default();
                let mut transports = Vec::new();
                for m in members {
                    if m.node_id == my_id {
                        continue;
                    }
                    if let Ok(t) = self.connect_peer_by_id(&m.node_id).await {
                        let _ = self.send_room_sync_to_peer(rid, &m.node_id).await;
                        transports.push(format!("{}:{:?}", m.display_name, t));
                    }
                }
                (
                    200,
                    serde_json::to_vec(&serde_json::json!({ "connected": transports }))
                        .unwrap_or_default(),
                )
            }
            ("POST", "/api/local/send-file") => {
                #[derive(serde::Deserialize)]
                struct Req {
                    room_id: Option<String>,
                    file_path: String,
                }
                let Ok(req) = serde_json::from_slice::<Req>(body) else {
                    return (400, br#"{"error":"invalid_json"}"#.to_vec());
                };
                let rid = req
                    .room_id
                    .as_deref()
                    .filter(|s| !s.is_empty())
                    .unwrap_or(DEFAULT_PERSONAL_ROOM_ID);
                match self.send_room_file(rid, PathBuf::from(&req.file_path)).await {
                    Ok(msg) => (
                        200,
                        serde_json::to_vec(&serde_json::json!({
                            "msg_id": msg.msg_id,
                            "room_id": msg.room_id,
                            "file_name": msg.file_name,
                            "file_size": msg.file_size,
                            "status": format!("{:?}", msg.status),
                        }))
                        .unwrap_or_default(),
                    ),
                    Err(e) => (
                        400,
                        serde_json::to_vec(&serde_json::json!({"error": e.to_string()}))
                            .unwrap_or_default(),
                    ),
                }
            }
            ("POST", "/api/local/fix-usb-metric") => {
                #[derive(serde::Deserialize, Default)]
                struct Req {
                    os_index: Option<u32>,
                    #[serde(default)]
                    elevate: bool,
                }
                let req: Req = serde_json::from_slice(body).unwrap_or_default();
                let _ = self.refresh_network_interfaces(Vec::new());
                let res = if req.elevate
                    && let Some(idx) = req.os_index
                {
                    crate::net::lan_bypass::elevate_and_fix_usb_metric(idx)
                } else {
                    ensure_usb_tether_metric_safe()
                };
                match res {
                    Ok(st) => (200, serde_json::to_vec(&st).unwrap_or_default()),
                    Err(e) => (
                        500,
                        serde_json::to_vec(&serde_json::json!({"error": e.to_string()}))
                            .unwrap_or_default(),
                    ),
                }
            }
            ("POST", "/api/local/purge-now") => match self.purge_expired_locker_now().await {
                Ok(deleted) => (
                    200,
                    serde_json::to_vec(&serde_json::json!({ "deleted": deleted }))
                        .unwrap_or_default(),
                ),
                Err(e) => (
                    500,
                    serde_json::to_vec(&serde_json::json!({"error": e.to_string()}))
                        .unwrap_or_default(),
                ),
            },
            _ => (404, br#"{"error":"not_found"}"#.to_vec()),
        }
    }

    async fn build_local_status_json(self: &Arc<Self>) -> Result<serde_json::Value> {
        let st = self.get_home_node_status()?;
        let rooms = self.list_rooms()?;
        let members = self.list_room_members(DEFAULT_PERSONAL_ROOM_ID)?;
        let timeline = if st.enabled {
            Vec::new()
        } else {
            self.list_room_timeline(DEFAULT_PERSONAL_ROOM_ID, 50)?
        };
        let active_guard = self.active_peers.read().await;
        let active_peer_ids: Vec<String> = active_guard.keys().cloned().collect();
        let active_transports: serde_json::Map<String, serde_json::Value> = active_guard
            .iter()
            .filter(|(_, e)| !e.conn.is_closed())
            .map(|(k, e)| {
                (
                    k.clone(),
                    serde_json::Value::String(format!("{:?}", e.conn.transport_kind())),
                )
            })
            .collect();
        drop(active_guard);
        let usb_protection = ensure_usb_tether_metric_safe().ok();
        let lan_addrs: Vec<String> = self
            .lan
            .advertise_addrs()
            .into_iter()
            .map(|a| a.to_string())
            .collect();

        Ok(serde_json::json!({
            "node_id": self.my_endpoint_id().to_string(),
            "home_node_mode": st.enabled,
            "retention_days": st.retention_days,
            "usb_installer_path": st.usb_installer_path,
            "usb_bootstrap_urls": st.usb_bootstrap_urls,
            "lan_addrs": lan_addrs,
            "active_connected_peers": active_peer_ids,
            "active_transports": active_transports,
            "usb_protection": usb_protection,
            "stats": {
                "active_cached_count": st.stats.active_cached_count,
                "active_cached_bytes": st.stats.active_cached_bytes,
                "total_purged_count": st.stats.total_purged_count,
                "registered_rooms_count": st.stats.registered_rooms_count,
                "pending_ack_links": st.stats.pending_ack_links,
            },
            "rooms": rooms.into_iter().map(|r| serde_json::json!({
                "room_id": r.room_id,
                "name": r.name,
                "room_type": r.room_type,
                "is_pinned": r.is_pinned,
            })).collect::<Vec<_>>(),
            "personal_members": members.into_iter().map(|m| serde_json::json!({
                "node_id": m.node_id,
                "display_name": m.display_name,
                "role": m.role,
            })).collect::<Vec<_>>(),
            "personal_timeline_count": timeline.len(),
            "personal_messages": timeline.iter().rev().take(10).map(|m| serde_json::json!({
                "msg_id": m.msg_id,
                "sender_id": m.sender_id,
                "is_outgoing": m.direction == crate::db::store::MessageDirection::Outgoing,
                "is_file": m.kind == crate::db::store::MessageKind::File,
                "body_text": m.body_text,
                "file_name": m.file_name,
                "file_size": m.file_size,
                "local_path": m.local_path,
                "status": format!("{:?}", m.status),
                "acked_peers": m.acked_peers,
            })).collect::<Vec<_>>(),
        }))
    }

    fn spawn_incoming_stream_reader(
        self: &Arc<Self>,
        peer_id: String,
        conn_id: u64,
        conn: ActiveConnection,
    ) {
        let engine = Arc::clone(self);
        tokio::spawn(async move {
            loop {
                match &conn {
                    ActiveConnection::UsbLan(c)
                    | ActiveConnection::Lan(c)
                    | ActiveConnection::WanDirectNoq(c) => match c.accept_bi().await {
                        Ok((mut send, mut recv)) => {
                            let eng = Arc::clone(&engine);
                            let pid = peer_id.clone();
                            let lan_addrs: Vec<String> = eng
                                .lan
                                .advertise_addrs()
                                .into_iter()
                                .map(|a| a.to_string())
                                .collect();
                            tokio::spawn(async move {
                                let recv_dir = eng.auto_receive_dir();
                                if let Err(e) = handle_incoming_bidi_stream(
                                    &pid,
                                    &eng.secret_key,
                                    &mut recv,
                                    &mut send,
                                    &eng.store,
                                    &eng.config,
                                    &recv_dir,
                                    &eng.events_tx,
                                    &lan_addrs,
                                )
                                .await
                                {
                                    tracing::warn!("LAN/USB incoming stream error: {e:#}");
                                }
                                let _ = send.finish();
                            });
                        }
                        Err(e) => {
                            tracing::info!("LAN/USB conn_id={conn_id} peer={peer_id} closed: {e}");
                            break;
                        }
                    },
                    ActiveConnection::Wan(c) => match c.accept_bi().await {
                        Ok((mut send, mut recv)) => {
                            let eng = Arc::clone(&engine);
                            let pid = peer_id.clone();
                            let lan_addrs: Vec<String> = eng
                                .lan
                                .advertise_addrs()
                                .into_iter()
                                .map(|a| a.to_string())
                                .collect();
                            tokio::spawn(async move {
                                let recv_dir = eng.auto_receive_dir();
                                if let Err(e) = handle_incoming_bidi_stream(
                                    &pid,
                                    &eng.secret_key,
                                    &mut recv,
                                    &mut send,
                                    &eng.store,
                                    &eng.config,
                                    &recv_dir,
                                    &eng.events_tx,
                                    &lan_addrs,
                                )
                                .await
                                {
                                    tracing::warn!("WAN incoming stream error: {e:#}");
                                }
                                let _ = send.finish();
                            });
                        }
                        Err(e) => {
                            tracing::info!("WAN conn_id={conn_id} peer={peer_id} closed: {e}");
                            break;
                        }
                    },
                }
            }

            let removed = {
                let mut map = engine.active_peers.write().await;
                if map.get(&peer_id).is_some_and(|e| e.id == conn_id) {
                    map.remove(&peer_id);
                    true
                } else {
                    false
                }
            };
            if removed {
                let _ = engine.events_tx.send(EngineEvent::PeerDisconnected {
                    peer_id: peer_id.clone(),
                });
                engine.trigger_home_node_fallback_drains();
                // If a hardware LAN/USB link dropped (e.g. phone disconnected Wi-Fi -> 5G),
                // stagger one on-demand WAN fallback dial so both sides don't race simultaneously.
                if !matches!(conn, ActiveConnection::Wan(_))
                    && engine.is_trusted_peer(&peer_id).unwrap_or(false)
                {
                    let eng = Arc::clone(&engine);
                    let pid = peer_id.clone();
                    let my_id = engine.my_endpoint_id().to_string();
                    let delay_ms = if my_id < peer_id { 200 } else { 1500 };
                    tokio::spawn(async move {
                        tokio::time::sleep(std::time::Duration::from_millis(delay_ms)).await;
                        if eng.active_transport(&pid).await.is_none() {
                            let _ = eng.connect_peer_by_id(&pid).await;
                        }
                    });
                }
            }
        });
    }

    fn trigger_home_node_fallback_drains(self: &Arc<Self>) {
        let my_id = self.my_endpoint_id().to_string();
        let Ok(rooms) = self.store.list_all_rooms() else {
            return;
        };
        let mut home_nodes = HashSet::new();
        for room in rooms {
            if let Ok(members) = self.store.list_room_members(&room.room_id) {
                for m in members {
                    if m.role == "home_node" && m.node_id != my_id {
                        home_nodes.insert(m.node_id);
                    }
                }
            }
        }
        for hn in home_nodes {
            self.spawn_outbox_drain(hn);
        }
    }

    fn spawn_outbox_drain(self: &Arc<Self>, peer_id: String) {
        if !try_claim_drain_slot(&self.draining_peers, &peer_id) {
            return;
        }

        let engine = Arc::clone(self);
        tokio::spawn(async move {
            loop {
                clear_drain_rescan_flag(&engine.draining_peers, &peer_id);

                let entry_opt = engine.active_peers.read().await.get(&peer_id).cloned();
                let Some(entry) = entry_opt else {
                    if should_rescan_before_exit(&engine.draining_peers, &peer_id) {
                        continue;
                    }
                    return;
                };
                let conn_id = entry.id;
                let conn = entry.conn;

                let legacy_pending = match engine.store.list_pending_outbox(&peer_id) {
                    Ok(list) => list
                        .into_iter()
                        .filter(|rec| {
                            // Keep legacy messages separated from Phase 2 room_outbox_targets
                            rec.sender_id.is_empty()
                        })
                        .collect::<Vec<_>>(),
                    Err(e) => {
                        tracing::error!("failed to query legacy outbox: {e:#}");
                        release_drain_slot(&engine.draining_peers, &peer_id);
                        return;
                    }
                };
                let room_jobs = match engine.store.list_pending_room_outbox_for_peer(&peer_id) {
                    Ok(list) => list,
                    Err(e) => {
                        tracing::error!("failed to query room outbox: {e:#}");
                        release_drain_slot(&engine.draining_peers, &peer_id);
                        return;
                    }
                };
                let pending_revokes = match engine.store.list_pending_room_revokes_for_peer(&peer_id)
                {
                    Ok(list) => list,
                    Err(e) => {
                        tracing::error!("failed to query pending revokes: {e:#}");
                        release_drain_slot(&engine.draining_peers, &peer_id);
                        return;
                    }
                };

                if pending_revokes.is_empty() && legacy_pending.is_empty() && room_jobs.is_empty()
                {
                    if should_rescan_before_exit(&engine.draining_peers, &peer_id) {
                        continue;
                    }
                    return;
                }

                let mut room_jobs = room_jobs;
                prioritize_room_outbox_jobs(&mut room_jobs);

                let mut any_failed = false;
                let mut failed_stream_only = false;
                let mut processed_any = false;

                // 0. Drain signed message-revoke requests first so cancelled transfers stop promptly.
                for revoke in pending_revokes {
                    processed_any = true;
                    let res = match &conn {
                        ActiveConnection::UsbLan(c)
                        | ActiveConnection::Lan(c)
                        | ActiveConnection::WanDirectNoq(c) => {
                            match c.open_bi().await {
                                Ok((mut s, mut r)) => {
                                    let out = send_pending_room_revoke(
                                        &revoke,
                                        &mut r,
                                        &mut s,
                                        &engine.store,
                                    )
                                    .await;
                                    let _ = s.finish();
                                    out
                                }
                                Err(e) => Err(e.into()),
                            }
                        }
                        ActiveConnection::Wan(c) => match c.open_bi().await {
                            Ok((mut s, mut r)) => {
                                let out = send_pending_room_revoke(
                                    &revoke,
                                    &mut r,
                                    &mut s,
                                    &engine.store,
                                )
                                .await;
                                let _ = s.finish();
                                out
                            }
                            Err(e) => Err(e.into()),
                        },
                    };
                    if let Err(e) = res {
                        tracing::warn!(
                            "pending revoke send error for {} on conn_id={}: {e:#}",
                            revoke.msg_id,
                            conn_id
                        );
                        any_failed = true;
                        break;
                    }
                }

                // 1. Drain Phase 1 legacy queue
                if !any_failed {
                for record in legacy_pending {
                    processed_any = true;
                    let res = match &conn {
                        ActiveConnection::UsbLan(c)
                        | ActiveConnection::Lan(c)
                        | ActiveConnection::WanDirectNoq(c) => {
                            match c.open_bi().await {
                                Ok((mut s, mut r)) => {
                                    let out = send_queued_record(
                                        &record,
                                        &mut r,
                                        &mut s,
                                        &engine.store,
                                        &engine.config,
                                        &engine.events_tx,
                                    )
                                    .await;
                                    let _ = s.finish();
                                    out
                                }
                                Err(e) => Err(e.into()),
                            }
                        }
                        ActiveConnection::Wan(c) => match c.open_bi().await {
                            Ok((mut s, mut r)) => {
                                let out = send_queued_record(
                                    &record,
                                    &mut r,
                                    &mut s,
                                    &engine.store,
                                    &engine.config,
                                    &engine.events_tx,
                                )
                                .await;
                                let _ = s.finish();
                                out
                            }
                            Err(e) => Err(e.into()),
                        },
                    };
                    if let Err(e) = res {
                        tracing::warn!(
                            "legacy outbox send error for {} on conn_id={}: {e:#}",
                            record.msg_id,
                            conn_id
                        );
                        any_failed = true;
                        break;
                    }
                }
                }

                // 2. Drain Phase 2 Multi-Room E2EE & Blind Locker jobs
                if !any_failed {
                    let active_snapshot = engine.active_peers.read().await;
                    let online_peers: HashSet<String> = active_snapshot
                        .iter()
                        .filter(|(_, e)| !e.conn.is_closed())
                        .map(|(k, _)| k.clone())
                        .collect();
                    drop(active_snapshot);

                    for job in room_jobs {
                        // If a faster transport (e.g. LAN/USB) or replacement connection arrived
                        // while draining, switch to it immediately instead of staying on the old link.
                        let latest_opt = {
                            let map = engine.active_peers.read().await;
                            map.get(&peer_id).cloned()
                        };
                        if let Some(latest) = latest_opt
                            && (latest.conn.transport_kind().priority_rank()
                                > conn.transport_kind().priority_rank()
                                || (conn.is_closed() && latest.id != conn_id))
                        {
                            processed_any = true;
                            break;
                        }

                        // Skip uploading to Home Node if ALL target peers are already online directly.
                        if job.store_in_locker
                            && !job.target_peers.is_empty()
                            && job.target_peers.iter().all(|t| online_peers.contains(t))
                        {
                            continue;
                        }

                        processed_any = true;
                        let res = match &conn {
                            ActiveConnection::UsbLan(c)
                            | ActiveConnection::Lan(c)
                            | ActiveConnection::WanDirectNoq(c) => {
                                match c.open_bi().await {
                                    Ok((mut s, mut r)) => {
                                        let out = send_room_outbox_job(
                                            &job,
                                            &peer_id,
                                            &engine.secret_key,
                                            &mut r,
                                            &mut s,
                                            &engine.store,
                                            &engine.config,
                                            &engine.events_tx,
                                        )
                                        .await;
                                        let _ = s.finish();
                                        out
                                    }
                                    Err(e) => Err(e.into()),
                                }
                            }
                            ActiveConnection::Wan(c) => match c.open_bi().await {
                                Ok((mut s, mut r)) => {
                                    let out = send_room_outbox_job(
                                        &job,
                                        &peer_id,
                                        &engine.secret_key,
                                        &mut r,
                                        &mut s,
                                        &engine.store,
                                        &engine.config,
                                        &engine.events_tx,
                                    )
                                    .await;
                                    let _ = s.finish();
                                    out
                                }
                                Err(e) => Err(e.into()),
                            },
                        };

                        match res {
                            Ok(()) => {
                                engine.reset_outbox_fail_streak(&peer_id);
                            }
                            Err(e) => {
                                tracing::warn!(
                                    "room outbox send error for {} on conn_id={}: {e:#}",
                                    job.message.msg_id,
                                    conn_id
                                );
                                let conn_dead =
                                    conn.is_closed() || !Self::probe_connection_alive(&conn).await;
                                if conn_dead {
                                    any_failed = true;
                                    break;
                                }
                                // Keep the healthy transport alive so subsequent messages still drain.
                                failed_stream_only = true;
                            }
                        }
                    }
                }

                if any_failed {
                    conn.close();
                    let removed = {
                        let mut map = engine.active_peers.write().await;
                        if map.get(&peer_id).is_some_and(|e| e.id == conn_id) {
                            map.remove(&peer_id);
                            true
                        } else {
                            false
                        }
                    };
                    if removed {
                        let _ = engine.events_tx.send(EngineEvent::PeerDisconnected {
                            peer_id: peer_id.clone(),
                        });
                        engine.trigger_home_node_fallback_drains();
                        release_drain_slot(&engine.draining_peers, &peer_id);
                        let has_more_room_jobs = !engine
                            .store
                            .list_pending_room_outbox_for_peer(&peer_id)
                            .unwrap_or_default()
                            .is_empty();
                        if has_more_room_jobs && engine.is_trusted_peer(&peer_id).unwrap_or(false)
                        {
                            let backoff = engine.next_outbox_backoff(&peer_id);
                            let eng = Arc::clone(&engine);
                            let pid = peer_id.clone();
                            tokio::spawn(async move {
                                tokio::time::sleep(backoff).await;
                                if eng.active_transport(&pid).await.is_none()
                                    && eng.connect_peer_by_id(&pid).await.is_ok()
                                {
                                    eng.spawn_outbox_drain(pid);
                                }
                            });
                        }
                        return;
                    }
                } else if failed_stream_only {
                    if should_rescan_before_exit(&engine.draining_peers, &peer_id) {
                        continue;
                    }
                    let has_more_room_jobs = !engine
                        .store
                        .list_pending_room_outbox_for_peer(&peer_id)
                        .unwrap_or_default()
                        .is_empty();
                    if has_more_room_jobs && engine.is_trusted_peer(&peer_id).unwrap_or(false) {
                        let backoff = engine
                            .next_outbox_backoff(&peer_id)
                            .max(std::time::Duration::from_secs(1));
                        let eng = Arc::clone(&engine);
                        let pid = peer_id.clone();
                        tokio::spawn(async move {
                            tokio::time::sleep(backoff).await;
                            if eng.active_transport(&pid).await.is_some()
                                || eng.connect_peer_by_id(&pid).await.is_ok()
                            {
                                eng.spawn_outbox_drain(pid);
                            }
                        });
                    }
                    return;
                } else if !processed_any {
                    if should_rescan_before_exit(&engine.draining_peers, &peer_id) {
                        continue;
                    }
                    return;
                }
            }
        });
    }

    fn spawn_blind_locker_drain(self: &Arc<Self>, peer_id: String) {
        if !try_claim_drain_slot(&self.locker_draining_peers, &peer_id) {
            return;
        }

        let engine = Arc::clone(self);
        tokio::spawn(async move {
            loop {
                clear_drain_rescan_flag(&engine.locker_draining_peers, &peer_id);

                let entry_opt = engine.active_peers.read().await.get(&peer_id).cloned();
                let Some(entry) = entry_opt else {
                    if should_rescan_before_exit(&engine.locker_draining_peers, &peer_id) {
                        continue;
                    }
                    return;
                };
                let conn_id = entry.id;
                let conn = entry.conn;

                let ready_items = match engine.store.list_ready_locker_items_for_peer(&peer_id) {
                    Ok(list) => list,
                    Err(e) => {
                        tracing::error!("failed to query ready blind locker items: {e:#}");
                        release_drain_slot(&engine.locker_draining_peers, &peer_id);
                        return;
                    }
                };
                let unforwarded_acks = match engine
                    .store
                    .list_unforwarded_locker_acks_for_sender(&peer_id)
                {
                    Ok(list) => list,
                    Err(e) => {
                        tracing::error!("failed to query unforwarded locker ACKs: {e:#}");
                        release_drain_slot(&engine.locker_draining_peers, &peer_id);
                        return;
                    }
                };

                if ready_items.is_empty() && unforwarded_acks.is_empty() {
                    if should_rescan_before_exit(&engine.locker_draining_peers, &peer_id) {
                        continue;
                    }
                    return;
                }

                let mut any_failed = false;

                for (item, pending_targets) in ready_items {
                    let res = match &conn {
                        ActiveConnection::UsbLan(c)
                        | ActiveConnection::Lan(c)
                        | ActiveConnection::WanDirectNoq(c) => {
                            match c.open_bi().await {
                                Ok((mut s, mut r)) => {
                                    let out = deliver_blind_locker_item_to_peer(
                                        &item,
                                        &pending_targets,
                                        &peer_id,
                                        &mut r,
                                        &mut s,
                                        &engine.store,
                                        &engine.events_tx,
                                    )
                                    .await;
                                    let _ = s.finish();
                                    out
                                }
                                Err(e) => Err(e.into()),
                            }
                        }
                        ActiveConnection::Wan(c) => match c.open_bi().await {
                            Ok((mut s, mut r)) => {
                                let out = deliver_blind_locker_item_to_peer(
                                    &item,
                                    &pending_targets,
                                    &peer_id,
                                    &mut r,
                                    &mut s,
                                    &engine.store,
                                    &engine.events_tx,
                                )
                                .await;
                                let _ = s.finish();
                                out
                            }
                            Err(e) => Err(e.into()),
                        },
                    };
                    if let Err(e) = res {
                        tracing::warn!(
                            "blind locker drain error for {} to {} on conn_id={}: {e:#}",
                            item.msg_id,
                            peer_id,
                            conn_id
                        );
                        any_failed = true;
                        break;
                    }
                }

                if !any_failed {
                    for ack in unforwarded_acks {
                        let res = match &conn {
                            ActiveConnection::UsbLan(c)
                            | ActiveConnection::Lan(c)
                            | ActiveConnection::WanDirectNoq(c) => {
                                match c.open_bi().await {
                                    Ok((mut s, _r)) => {
                                        let out = forward_locker_ack_to_sender(
                                            &ack,
                                            &mut s,
                                            &engine.store,
                                        )
                                        .await;
                                        let _ = s.finish();
                                        out
                                    }
                                    Err(e) => Err(e.into()),
                                }
                            }
                            ActiveConnection::Wan(c) => match c.open_bi().await {
                                Ok((mut s, _r)) => {
                                    let out = forward_locker_ack_to_sender(
                                        &ack,
                                        &mut s,
                                        &engine.store,
                                    )
                                    .await;
                                    let _ = s.finish();
                                    out
                                }
                                Err(e) => Err(e.into()),
                            },
                        };
                        if let Err(e) = res {
                            tracing::debug!("forward locker ack error: {e:#}");
                            any_failed = true;
                            break;
                        }
                    }
                }

                if any_failed {
                    conn.close();
                    let removed = {
                        let mut map = engine.active_peers.write().await;
                        if map.get(&peer_id).is_some_and(|e| e.id == conn_id) {
                            map.remove(&peer_id);
                            true
                        } else {
                            false
                        }
                    };
                    if removed {
                        let _ = engine.events_tx.send(EngineEvent::PeerDisconnected {
                            peer_id: peer_id.clone(),
                        });
                        release_drain_slot(&engine.locker_draining_peers, &peer_id);
                        return;
                    }
                }
            }
        });
    }
}

fn prioritize_room_outbox_jobs(jobs: &mut [crate::db::store::PendingRoomOutboxJob]) {
    jobs.sort_by_key(|j| matches!(j.message.kind, MessageKind::File) && !j.offer_only);
}

fn try_claim_drain_slot(map: &Mutex<HashMap<String, bool>>, peer_id: &str) -> bool {
    let mut guard = map.lock().expect("draining mutex poisoned");
    if let Some(needs_rescan) = guard.get_mut(peer_id) {
        *needs_rescan = true;
        return false;
    }
    guard.insert(peer_id.to_string(), false);
    true
}

fn clear_drain_rescan_flag(map: &Mutex<HashMap<String, bool>>, peer_id: &str) {
    let mut guard = map.lock().expect("draining mutex poisoned");
    if let Some(needs_rescan) = guard.get_mut(peer_id) {
        *needs_rescan = false;
    }
}

fn release_drain_slot(map: &Mutex<HashMap<String, bool>>, peer_id: &str) {
    let mut guard = map.lock().expect("draining mutex poisoned");
    guard.remove(peer_id);
}

fn should_rescan_before_exit(map: &Mutex<HashMap<String, bool>>, peer_id: &str) -> bool {
    let mut guard = map.lock().expect("draining mutex poisoned");
    if guard.get(peer_id).copied().unwrap_or(false) {
        guard.insert(peer_id.to_string(), false);
        true
    } else {
        guard.remove(peer_id);
        false
    }
}

pub type TrustedPeerAlias = crate::db::store::TrustedPeer;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::RelayPolicy;
    use crate::db::store::MessageStatus;

    fn loopback_iface(is_usb_tether: bool) -> PhysicalLanInterface {
        PhysicalLanInterface {
            os_index: 1,
            name: if is_usb_tether {
                "rndis0 USB Tether".to_string()
            } else {
                "Loopback Test".to_string()
            },
            local_ip: "127.0.0.1".parse().unwrap(),
            android_network_handle: None,
            is_usb_tether,
        }
    }

    #[tokio::test]
    async fn offline_queue_drains_over_physical_lan_when_peer_comes_online() -> Result<()> {
        let base = std::env::temp_dir().join(format!("p2p_e2e_test_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);

        let phone_cfg = EngineConfig {
            data_dir: base.join("phone_data"),
            auto_receive_dir: base.join("phone_recv"),
            relay_policy: RelayPolicy::DefaultPublic,
            chunk_size_bytes: 1024 * 1024,
            auto_accept_files: true,
            enable_usb_bootstrap_http: false,
        };
        let pc_cfg = EngineConfig {
            data_dir: base.join("pc_data"),
            auto_receive_dir: base.join("pc_recv"),
            relay_policy: RelayPolicy::DefaultPublic,
            chunk_size_bytes: 1024 * 1024,
            auto_accept_files: true,
            enable_usb_bootstrap_http: false,
        };

        let phone = ChatTransferEngine::start(phone_cfg.clone(), vec![loopback_iface(false)]).await?;
        let pc_key = load_or_create_secret_key(&pc_cfg.data_dir)?;
        let pc_id = pc_key.public().to_string();
        phone.store.upsert_peer(&pc_id, "Home PC")?;

        let text_rec = phone.send_text(&pc_id, "Offline hello from 5G!")?;
        assert_eq!(text_rec.status, MessageStatus::QueuedOffline);

        let sample_file = base.join("holiday_raw.bin");
        let payload: Vec<u8> = (0..2_600_000u32).map(|i| (i % 247) as u8).collect();
        std::fs::write(&sample_file, &payload)?;
        let file_rec = phone.send_file(&pc_id, sample_file).await?;
        assert_eq!(file_rec.status, MessageStatus::QueuedOffline);

        let pc = ChatTransferEngine::start(pc_cfg.clone(), vec![loopback_iface(false)]).await?;
        let pc_ticket = pc.create_pairing_ticket("Home PC")?;

        let transport = phone
            .connect_peer(
                pc_ticket.endpoint_addr,
                pc_ticket
                    .lan_addrs
                    .iter()
                    .filter_map(|s| s.parse().ok())
                    .collect(),
            )
            .await?;
        assert_eq!(transport, TransportKind::LanDirectPhysicalNic);

        let phone_id = phone.my_endpoint_id().to_string();
        let mut delivered = false;
        for _ in 0..50 {
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            let pc_msgs = pc.list_timeline(&phone_id, 20)?;
            let phone_msgs = phone.list_timeline(&pc_id, 20)?;
            if pc_msgs.len() == 2
                && pc_msgs.iter().all(|m| m.status == MessageStatus::Delivered)
                && phone_msgs.iter().all(|m| m.status == MessageStatus::Delivered)
            {
                delivered = true;
                break;
            }
        }
        assert!(delivered, "expected both text and file to auto-deliver upon PC coming online");

        let received_file = pc_cfg
            .auto_receive_dir
            .join(pc.store.local_year_month())
            .join("holiday_raw.bin");
        assert!(received_file.exists(), "auto-received file must exist on disk");
        assert_eq!(std::fs::read(&received_file)?, payload);

        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }

    #[tokio::test]
    async fn large_high_byte_chunk_and_idempotent_reconnect_succeed() -> Result<()> {
        let base = std::env::temp_dir().join(format!("p2p_maxframe_test_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);

        let phone_cfg = EngineConfig {
            data_dir: base.join("phone_data"),
            auto_receive_dir: base.join("phone_recv"),
            relay_policy: RelayPolicy::DefaultPublic,
            chunk_size_bytes: 2 * 1024 * 1024,
            auto_accept_files: true,
            enable_usb_bootstrap_http: false,
        };
        let pc_cfg = EngineConfig {
            data_dir: base.join("pc_data"),
            auto_receive_dir: base.join("pc_recv"),
            relay_policy: RelayPolicy::DefaultPublic,
            chunk_size_bytes: 2 * 1024 * 1024,
            auto_accept_files: true,
            enable_usb_bootstrap_http: false,
        };

        let phone = ChatTransferEngine::start(phone_cfg.clone(), vec![loopback_iface(false)]).await?;
        let pc = ChatTransferEngine::start(pc_cfg.clone(), vec![loopback_iface(false)]).await?;

        let pc_ticket = pc.create_pairing_ticket("PC")?;
        let pc_id = pc_ticket.endpoint_addr.id.to_string();
        let phone_id = phone.my_endpoint_id().to_string();
        phone.store.upsert_peer(&pc_id, "PC")?;
        pc.store.upsert_peer(&phone_id, "Phone")?;

        let mut events_rx = phone.subscribe_events();
        let lan_addrs: Vec<SocketAddr> = pc_ticket
            .lan_addrs
            .iter()
            .filter_map(|s| s.parse().ok())
            .collect();

        let t1 = phone
            .connect_peer(pc_ticket.endpoint_addr.clone(), lan_addrs.clone())
            .await?;
        assert_eq!(t1, TransportKind::LanDirectPhysicalNic);

        let t2 = phone.connect_peer(pc_ticket.endpoint_addr, Vec::new()).await?;
        assert_eq!(t2, TransportKind::LanDirectPhysicalNic);
        assert_eq!(
            phone.active_transport(&pc_id).await,
            Some(TransportKind::LanDirectPhysicalNic)
        );

        let sample_file = base.join("high_entropy_ff.mp4");
        let payload = vec![0xFFu8; 2_200_000];
        std::fs::write(&sample_file, &payload)?;
        phone.send_file(&pc_id, sample_file).await?;

        let mut delivered = false;
        for _ in 0..50 {
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            let pc_msgs = pc.list_timeline(&phone_id, 10)?;
            if pc_msgs.len() == 1 && pc_msgs[0].status == MessageStatus::Delivered {
                delivered = true;
                break;
            }
        }
        assert!(delivered, "2 MiB 0xFF chunk file must deliver without overflowing frame limit");

        while let Ok(ev) = events_rx.try_recv() {
            if let EngineEvent::PeerDisconnected { peer_id } = ev {
                panic!("unexpected PeerDisconnected for {peer_id}");
            }
        }

        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }

    #[tokio::test]
    async fn connect_peer_by_id_reuses_persisted_lan_hints() -> Result<()> {
        let base = std::env::temp_dir().join(format!("p2p_hints_test_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);

        let mut cfg1 = EngineConfig::with_dirs(base.join("p1_data"), base.join("p1_recv"));
        cfg1.enable_usb_bootstrap_http = false;
        let mut cfg2 = EngineConfig::with_dirs(base.join("p2_data"), base.join("p2_recv"));
        cfg2.enable_usb_bootstrap_http = false;

        let phone = ChatTransferEngine::start(cfg1, vec![loopback_iface(false)]).await?;
        let pc = ChatTransferEngine::start(cfg2, vec![loopback_iface(false)]).await?;

        let pc_ticket = pc.create_pairing_ticket("PC")?;
        let pc_id = pc_ticket.endpoint_addr.id.to_string();
        let peer = phone.pair_with_ticket(pc_ticket).await?;
        assert_eq!(peer.node_id, pc_id);

        phone.active_peers.write().await.clear();
        let t = phone.connect_peer_by_id(&pc_id).await?;
        assert_eq!(t, TransportKind::LanDirectPhysicalNic);

        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }

    #[tokio::test]
    async fn set_auto_receive_dir_updates_live_destination() -> Result<()> {
        let base = std::env::temp_dir().join(format!("p2p_savedir_test_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);

        let mut cfg1 = EngineConfig::with_dirs(base.join("p1_data"), base.join("p1_recv"));
        cfg1.enable_usb_bootstrap_http = false;
        let mut cfg2 = EngineConfig::with_dirs(base.join("p2_data"), base.join("p2_recv"));
        cfg2.enable_usb_bootstrap_http = false;

        let sender = ChatTransferEngine::start(cfg1, vec![loopback_iface(false)]).await?;
        let receiver = ChatTransferEngine::start(cfg2, vec![loopback_iface(false)]).await?;

        let custom_dir = base.join("custom_destination");
        receiver.set_auto_receive_dir(custom_dir.clone())?;
        assert_eq!(receiver.auto_receive_dir(), custom_dir);

        let recv_ticket = receiver.create_pairing_ticket("Receiver")?;
        let recv_id = recv_ticket.endpoint_addr.id.to_string();
        sender.pair_with_ticket(recv_ticket).await?;

        let src_file = base.join("chosen_folder_test.txt");
        std::fs::write(&src_file, b"hello custom save location!")?;
        sender.send_file(&recv_id, src_file).await?;

        let sender_id = sender.my_endpoint_id().to_string();
        let mut delivered = false;
        for _ in 0..50 {
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            let msgs = receiver.list_timeline(&sender_id, 10)?;
            if msgs.len() == 1 && msgs[0].status == MessageStatus::Delivered {
                delivered = true;
                break;
            }
        }
        assert!(delivered, "file must deliver to newly configured custom directory");
        let saved = custom_dir
            .join(receiver.store.local_year_month())
            .join("chosen_folder_test.txt");
        assert!(saved.exists(), "file must be saved inside custom_dir/YYYY-MM");
        assert_eq!(std::fs::read(&saved)?, b"hello custom save location!");

        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }

    #[tokio::test]
    async fn home_node_blind_locker_stores_ciphertext_delivers_on_pc_online_and_immediately_purges_cache() -> Result<()> {
        let base = std::env::temp_dir().join(format!("p2p_locker_e2e_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);

        let mut new_phone_cfg =
            EngineConfig::with_dirs(base.join("new_phone_data"), base.join("new_phone_recv"));
        new_phone_cfg.enable_usb_bootstrap_http = false;
        let mut old_phone_cfg =
            EngineConfig::with_dirs(base.join("old_phone_data"), base.join("old_phone_recv"));
        old_phone_cfg.enable_usb_bootstrap_http = false;
        let mut pc_cfg = EngineConfig::with_dirs(base.join("pc_data"), base.join("pc_recv"));
        pc_cfg.enable_usb_bootstrap_http = false;

        // 1. Start New Phone + Old Phone (Home Node Mode enabled) while Home PC is OFFLINE.
        let new_phone =
            ChatTransferEngine::start(new_phone_cfg.clone(), vec![loopback_iface(false)]).await?;
        let old_phone =
            ChatTransferEngine::start(old_phone_cfg.clone(), vec![loopback_iface(true)]).await?;
        old_phone.set_home_node_mode(true, 7, None)?;

        let room = new_phone.create_room("个人设备群", "New Phone")?;
        let room_id = room.room_id.clone();

        // Pre-generate PC's identity so New Phone knows PC is a room member (PC is offline right now).
        let pc_key = load_or_create_secret_key(&pc_cfg.data_dir)?;
        let pc_id = pc_key.public().to_string();
        let member_invite = new_phone.create_room_invite(&room_id, "New Phone", false)?;
        new_phone
            .store
            .upsert_room_member(&room_id, &pc_id, "Home PC", "member")?;

        // Bind Old Phone as pure blind Home Node (invite_as_home_node = true -> NO room_key!).
        let home_node_invite = new_phone.create_room_invite(&room_id, "New Phone", true)?;
        assert!(home_node_invite.room_key_hex.is_none());
        old_phone
            .join_room_with_invite(home_node_invite, "Old Phone Home Node")
            .await?;

        // Verify Old Phone strictly has NO room_key and NO chat rooms exposed.
        assert!(
            old_phone
                .store
                .get_room(&room_id)?
                .and_then(|r| r.room_key_hex)
                .is_none(),
            "blind Home Node must NEVER hold room_key"
        );
        assert!(old_phone.list_rooms()?.is_empty());

        // 2. While Home PC is offline, New Phone sends a 1.5 MiB E2EE file into the room.
        let sample_file = base.join("vacation_4k.bin");
        let payload: Vec<u8> = (0..1_550_000u32).map(|i| (i % 233) as u8).collect();
        std::fs::write(&sample_file, &payload)?;
        let sent_rec = new_phone.send_room_file(&room_id, sample_file).await?;

        // Wait until Old Phone blind locker caches the encrypted `.enc` file!
        let expected_enc_path = old_phone_cfg
            .data_dir
            .join("locker")
            .join(format!("{}.enc", sent_rec.msg_id));
        let mut cached_on_locker = false;
        for _ in 0..60 {
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            let stats = old_phone.get_home_node_status()?.stats;
            if stats.active_cached_count == 1 && expected_enc_path.exists() {
                cached_on_locker = true;
                break;
            }
        }
        assert!(
            cached_on_locker,
            "Old Phone Home Node must cache encrypted .enc payload while PC is offline"
        );
        assert!(
            old_phone.list_room_timeline(&room_id, 20)?.is_empty(),
            "Home Node must never store or expose plaintext timeline messages"
        );
        // Verify stored .enc file is NOT plaintext!
        assert_ne!(std::fs::read(&expected_enc_path)?, payload);

        // 3. Now Home PC boots up, joins the room with member_invite, and connects to Old Phone over USB!
        let pc = ChatTransferEngine::start(pc_cfg.clone(), vec![loopback_iface(true)]).await?;
        pc.join_room_with_invite(member_invite, "Home PC").await?;
        let old_ticket = old_phone.create_pairing_ticket("Old Phone Home Node")?;
        let transport = pc
            .connect_peer(
                old_ticket.endpoint_addr,
                old_ticket
                    .lan_addrs
                    .iter()
                    .filter_map(|s| s.parse().ok())
                    .collect(),
            )
            .await?;
        assert_eq!(transport, TransportKind::UsbTetherDirect);

        // 4. Verify PC pulls & decrypts the file AND Old Phone immediately deletes `.enc` upon ACK!
        let mut completed_and_purged = false;
        for _ in 0..80 {
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            let pc_msgs = pc.list_room_timeline(&room_id, 20)?;
            let stats = old_phone.get_home_node_status()?.stats;
            if pc_msgs.len() == 1
                && pc_msgs[0].status == MessageStatus::Delivered
                && stats.active_cached_count == 0
                && stats.total_purged_count == 1
                && !expected_enc_path.exists()
            {
                completed_and_purged = true;
                break;
            }
        }
        assert!(
            completed_and_purged,
            "PC must receive/decrypt file AND Home Node must immediately purge .enc cache after ACK"
        );

        let received = pc_cfg
            .auto_receive_dir
            .join(pc.store.local_year_month())
            .join("vacation_4k.bin");
        assert!(received.exists());
        assert_eq!(std::fs::read(&received)?, payload);

        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }

    #[test]
    fn drain_slot_rescan_flag_never_drops_concurrent_wakeup() {
        let map: Mutex<HashMap<String, bool>> = Mutex::new(HashMap::new());
        assert!(try_claim_drain_slot(&map, "peer-a"));
        // Concurrent enqueue arrives while drain is already active.
        assert!(!try_claim_drain_slot(&map, "peer-a"));
        assert!(should_rescan_before_exit(&map, "peer-a"));
        // Second loop clears flag before querying DB; no further enqueue -> exits cleanly.
        clear_drain_rescan_flag(&map, "peer-a");
        assert!(!should_rescan_before_exit(&map, "peer-a"));
        // Subsequent enqueue cleanly claims a fresh worker.
        assert!(try_claim_drain_slot(&map, "peer-a"));
    }

    #[tokio::test]
    async fn batch_send_multiple_room_files_all_deliver_cleanly() -> Result<()> {
        let base = std::env::temp_dir().join(format!("p2p_batch_room_files_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);

        let mut cfg_phone = EngineConfig::with_dirs(base.join("phone_data"), base.join("phone_recv"));
        cfg_phone.enable_usb_bootstrap_http = false;
        let mut cfg_pc = EngineConfig::with_dirs(base.join("pc_data"), base.join("pc_recv"));
        cfg_pc.enable_usb_bootstrap_http = false;

        let phone = ChatTransferEngine::start(cfg_phone, vec![loopback_iface(false)]).await?;
        let pc = ChatTransferEngine::start(cfg_pc.clone(), vec![loopback_iface(false)]).await?;

        let pc_ticket = pc.create_pairing_ticket("Home PC")?;
        let pc_id = pc_ticket.endpoint_addr.id.to_string();
        phone.pair_with_ticket(pc_ticket).await?;

        let dm = phone
            .create_room(&format!("__dm__:{pc_id}"), "Phone")?;

        let mut src_paths = Vec::new();
        let mut expected_bytes = Vec::new();
        for idx in 0..6usize {
            let file_path = base.join(format!("photo_{idx}.jpg"));
            let data: Vec<u8> = (0..(120_000 + idx * 55_000))
                .map(|b| ((b + idx * 17) % 251) as u8)
                .collect();
            std::fs::write(&file_path, &data)?;
            src_paths.push(file_path);
            expected_bytes.push((format!("photo_{idx}.jpg"), data));
        }

        // Mimic Flutter `sendFiles` sequential loop + short stagger that triggers drain exit/re-entry.
        for (i, path) in src_paths.into_iter().enumerate() {
            if i == 2 {
                tokio::time::sleep(std::time::Duration::from_millis(15)).await;
            }
            phone.send_room_file(&dm.room_id, path).await?;
        }

        let mut all_ok = false;
        for _ in 0..100 {
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            let sent = phone.list_room_timeline(&dm.room_id, 20)?;
            let recv = pc.list_room_timeline(&dm.room_id, 20)?;
            if sent.len() == 6
                && recv.len() == 6
                && sent.iter().all(|m| m.status == MessageStatus::Delivered)
                && recv.iter().all(|m| m.status == MessageStatus::Delivered)
            {
                all_ok = true;
                break;
            }
        }
        assert!(
            all_ok,
            "all 6 batch images must deliver cleanly without remaining stuck in QueuedOffline"
        );

        let month_dir = cfg_pc.auto_receive_dir.join(pc.store.local_year_month());
        for (name, bytes) in expected_bytes {
            let dst = month_dir.join(name);
            assert!(dst.exists());
            assert_eq!(std::fs::read(&dst)?, bytes);
        }

        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }

    #[tokio::test]
    async fn failed_liveness_probe_does_not_deadlock_active_peers_lock() -> Result<()> {
        let base =
            std::env::temp_dir().join(format!("p2p_probe_deadlock_test_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);

        let mut cfg_a = EngineConfig::with_dirs(base.join("a_data"), base.join("a_recv"));
        cfg_a.enable_usb_bootstrap_http = false;
        let mut cfg_b = EngineConfig::with_dirs(base.join("b_data"), base.join("b_recv"));
        cfg_b.enable_usb_bootstrap_http = false;

        let engine_a = ChatTransferEngine::start(cfg_a, vec![loopback_iface(false)]).await?;
        let engine_b = ChatTransferEngine::start(cfg_b, vec![loopback_iface(false)]).await?;

        let b_ticket = engine_b.create_pairing_ticket("Peer B")?;
        let b_id = b_ticket.endpoint_addr.id.to_string();
        engine_a.pair_with_ticket(b_ticket).await?;

        // Replace `engine_a`'s active connection to `b_id` with an unclosed QUIC connection to a
        // silent local endpoint (completes TLS only, never answers `probe_connection_alive`).
        let silent_mgr = crate::net::lan_quic::LanQuicManager::bind_discovered(vec![
            loopback_iface(false),
        ])?;
        let silent_addr = silent_mgr.advertise_addrs()[0];
        let silent_server_ep = silent_mgr
            .endpoints
            .read()
            .expect("lock")
            .first()
            .expect("endpoint")
            .endpoint
            .clone();
        let accept_task = tokio::spawn(async move {
            if let Some(inc) = silent_server_ep.accept().await
                && let Ok(conn) = inc.await
            {
                tokio::time::sleep(std::time::Duration::from_secs(5)).await;
                drop(conn);
            }
        });
        let client_ep = engine_a
            .lan
            .endpoints
            .read()
            .expect("lock")
            .first()
            .expect("client endpoint")
            .endpoint
            .clone();
        let stalled_conn = client_ep
            .connect(silent_addr, "p2p-lan.local")?
            .await?;
        assert!(!stalled_conn.close_reason().is_some());

        {
            let mut map = engine_a.active_peers.write().await;
            map.insert(
                b_id.clone(),
                ActiveEntry {
                    id: 99_999,
                    conn: ActiveConnection::Lan(stalled_conn),
                },
            );
        }

        // Before the fix, `connect_peer` held the `active_peers` read guard across `.await`
        // and self-deadlocked when trying `.write().await` after the 500ms probe failed.
        let reconnect_res = tokio::time::timeout(
            std::time::Duration::from_secs(4),
            engine_a.connect_peer_by_id(&b_id),
        )
        .await
        .expect("connect_peer_by_id must not deadlock active_peers");
        assert!(reconnect_res.is_ok(), "expected reconnect: {reconnect_res:?}");

        let status_res = tokio::time::timeout(
            std::time::Duration::from_secs(1),
            engine_a.build_local_status_json(),
        )
        .await
        .expect("build_local_status_json must remain non-blocking");
        assert!(status_res.is_ok());

        accept_task.abort();
        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }

    #[tokio::test]
    async fn revoke_message_cleans_receiver_and_keeps_sender_source_intact() -> Result<()> {
        let base = std::env::temp_dir().join(format!("p2p_revoke_e2e_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);

        let mut cfg_phone = EngineConfig::with_dirs(base.join("phone_data"), base.join("phone_recv"));
        cfg_phone.enable_usb_bootstrap_http = false;
        let mut cfg_pc = EngineConfig::with_dirs(base.join("pc_data"), base.join("pc_recv"));
        cfg_pc.enable_usb_bootstrap_http = false;

        let phone = ChatTransferEngine::start(cfg_phone, vec![loopback_iface(false)]).await?;
        let pc = ChatTransferEngine::start(cfg_pc.clone(), vec![loopback_iface(false)]).await?;

        let pc_ticket = pc.create_pairing_ticket("Home PC")?;
        let pc_id = pc_ticket.endpoint_addr.id.to_string();
        phone.pair_with_ticket(pc_ticket).await?;
        let dm = phone.create_room(&format!("__dm__:{pc_id}"), "Phone")?;

        let src_path = base.join("original_camera_pic.jpg");
        std::fs::write(&src_path, vec![0x42u8; 4096])?;
        let sent = phone.send_room_file(&dm.room_id, src_path.clone()).await?;

        let mut delivered = false;
        for _ in 0..80 {
            tokio::time::sleep(std::time::Duration::from_millis(50)).await;
            let recv_list = pc.list_room_timeline(&dm.room_id, 10)?;
            if recv_list
                .iter()
                .any(|m| m.msg_id == sent.msg_id && m.status == MessageStatus::Delivered)
            {
                delivered = true;
                break;
            }
        }
        assert!(delivered, "initial file must deliver cleanly");
        let pc_recv_path = cfg_pc
            .auto_receive_dir
            .join(pc.store.local_year_month())
            .join("original_camera_pic.jpg");
        assert!(pc_recv_path.exists());

        // Receiver MUST NOT be allowed to revoke sender's message.
        assert!(pc.revoke_message_for_everyone(&sent.msg_id).is_err());

        // Sender revokes -> sender tombstone set, sender source untouched, receiver deleted + unlinked.
        let sender_after = phone.revoke_message_for_everyone(&sent.msg_id)?;
        assert_eq!(sender_after.status, MessageStatus::Revoked);
        assert!(src_path.exists(), "sender source file must never be removed");

        let mut remote_revoked = false;
        for _ in 0..80 {
            tokio::time::sleep(std::time::Duration::from_millis(50)).await;
            let recv_list = pc.list_room_timeline(&dm.room_id, 10)?;
            if let Some(m) = recv_list.iter().find(|m| m.msg_id == sent.msg_id)
                && m.status == MessageStatus::Revoked
            {
                remote_revoked = true;
                break;
            }
        }
        assert!(remote_revoked, "receiver timeline must transition to Revoked");
        assert!(!pc_recv_path.exists(), "receiver copy should be removed");
        assert!(src_path.exists(), "sender source file still intact after remote revoke");

        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }

    #[tokio::test]
    async fn start_fast_returns_immediately_and_connects_in_background() -> Result<()> {
        let base = std::env::temp_dir().join(format!("p2p_start_fast_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);

        let mut cfg_a = EngineConfig::with_dirs(base.join("a_data"), base.join("a_recv"));
        cfg_a.enable_usb_bootstrap_http = false;
        let mut cfg_b = EngineConfig::with_dirs(base.join("b_data"), base.join("b_recv"));
        cfg_b.enable_usb_bootstrap_http = false;

        let t0 = std::time::Instant::now();
        let eng_a = ChatTransferEngine::start_fast(cfg_a, vec![loopback_iface(false)])?;
        let eng_b = ChatTransferEngine::start_fast(cfg_b, vec![loopback_iface(false)])?;
        let local_boot_elapsed = t0.elapsed();
        assert!(
            local_boot_elapsed < std::time::Duration::from_millis(500),
            "start_fast should return immediately without waiting for network, took {:?}",
            local_boot_elapsed
        );

        // Local SQLite store is usable immediately after start_fast.
        let _ = eng_a.list_rooms()?;
        assert!(eng_a.list_peers()?.is_empty());

        // Wait for background LAN socket binding before creating pairing ticket with LAN addrs.
        tokio::join!(eng_a.wait_lan_ready(), eng_b.wait_lan_ready());
        let ticket_b = eng_b.create_pairing_ticket("Fast Node B")?;
        let peer_b_id = ticket_b.endpoint_addr.id.to_string();
        eng_a.pair_with_ticket(ticket_b).await?;

        let dm = eng_a.create_room(&format!("__dm__:{peer_b_id}"), "Fast Node A")?;
        let sent = eng_a.send_room_text(&dm.room_id, "hello fast boot")?;

        let mut received = false;
        for _ in 0..80 {
            tokio::time::sleep(std::time::Duration::from_millis(50)).await;
            if eng_b
                .list_room_timeline(&dm.room_id, 10)?
                .iter()
                .any(|m| m.msg_id == sent.msg_id && m.body_text.as_deref() == Some("hello fast boot"))
            {
                received = true;
                break;
            }
        }
        assert!(received, "background-booted engines should deliver E2EE text cleanly");

        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }

    #[tokio::test]
    async fn snapshot_active_transports_reflects_inbound_and_outbound_peers() -> Result<()> {
        let base = std::env::temp_dir().join(format!("p2p_snap_transports_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);

        let mut cfg_a = EngineConfig::with_dirs(base.join("a_data"), base.join("a_recv"));
        cfg_a.enable_usb_bootstrap_http = false;
        let mut cfg_b = EngineConfig::with_dirs(base.join("b_data"), base.join("b_recv"));
        cfg_b.enable_usb_bootstrap_http = false;

        let eng_a = ChatTransferEngine::start(cfg_a, vec![loopback_iface(false)]).await?;
        let eng_b = ChatTransferEngine::start(cfg_b, vec![loopback_iface(false)]).await?;

        let peer_a_id = eng_a.my_endpoint_id().to_string();
        let ticket_b = eng_b.create_pairing_ticket("Snap Node B")?;
        let peer_b_id = ticket_b.endpoint_addr.id.to_string();
        eng_a.pair_with_ticket(ticket_b).await?;

        let snap_a = eng_a.snapshot_active_transports().await;
        assert!(
            snap_a
                .iter()
                .any(|(id, kind)| id == &peer_b_id && *kind == TransportKind::LanDirectPhysicalNic),
            "outbound initiator must report peer B active transport, got {snap_a:?}"
        );

        let mut inbound_recorded = false;
        for _ in 0..40 {
            let snap_b = eng_b.snapshot_active_transports().await;
            if snap_b
                .iter()
                .any(|(id, kind)| id == &peer_a_id && *kind == TransportKind::LanDirectPhysicalNic)
            {
                inbound_recorded = true;
                break;
            }
            tokio::time::sleep(std::time::Duration::from_millis(25)).await;
        }
        assert!(
            inbound_recorded,
            "inbound responder must report peer A in snapshot_active_transports"
        );

        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }

    #[test]
    fn outbox_prioritizes_text_before_bulk_files_and_backs_off_exponentially() -> Result<()> {
        let base = std::env::temp_dir().join(format!("p2p_outbox_prio_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);
        let cfg = EngineConfig::with_dirs(base.join("data"), base.join("recv"));
        let engine = ChatTransferEngine::create_local_core(cfg)?;

        let make_job = |id: &str, kind: MessageKind, offer_only: bool| {
            crate::db::store::PendingRoomOutboxJob {
                message: ChatMessageRecord {
                    msg_id: id.to_string(),
                    room_id: DEFAULT_PERSONAL_ROOM_ID.to_string(),
                    peer_id: "peer-1".to_string(),
                    sender_id: "me".to_string(),
                    direction: MessageDirection::Outgoing,
                    kind,
                    body_text: Some("hi".to_string()),
                    file_name: None,
                    file_size: None,
                    local_path: None,
                    root_blake3: None,
                    chunk_size: None,
                    total_chunks: None,
                    received_bitmap: None,
                    status: MessageStatus::QueuedOffline,
                    delivery_scope: "direct".to_string(),
                    acked_peers: Vec::new(),
                    batch_id: None,
                    created_at_ms: 0,
                    updated_at_ms: 0,
                },
                target_peers: vec!["peer-1".to_string()],
                store_in_locker: false,
                offer_only,
            }
        };

        let mut jobs = vec![
            make_job("file-bulk", MessageKind::File, false),
            make_job("text-1", MessageKind::Text, false),
            make_job("file-offer", MessageKind::File, true),
            make_job("text-2", MessageKind::Text, false),
        ];
        prioritize_room_outbox_jobs(&mut jobs);
        let ordered_ids: Vec<&str> = jobs.iter().map(|j| j.message.msg_id.as_str()).collect();
        assert_eq!(ordered_ids, vec!["text-1", "file-offer", "text-2", "file-bulk"]);

        assert_eq!(
            engine.next_outbox_backoff("peer-1"),
            std::time::Duration::from_millis(500)
        );
        assert_eq!(
            engine.next_outbox_backoff("peer-1"),
            std::time::Duration::from_millis(1000)
        );
        assert_eq!(
            engine.next_outbox_backoff("peer-1"),
            std::time::Duration::from_millis(2000)
        );
        assert_eq!(
            engine.next_outbox_backoff("peer-1"),
            std::time::Duration::from_millis(4000)
        );
        assert_eq!(
            engine.next_outbox_backoff("peer-1"),
            std::time::Duration::from_millis(8000)
        );
        assert_eq!(
            engine.next_outbox_backoff("peer-1"),
            std::time::Duration::from_millis(16000)
        );
        assert_eq!(
            engine.next_outbox_backoff("peer-1"),
            std::time::Duration::from_millis(30000)
        );
        engine.reset_outbox_fail_streak("peer-1");
        assert_eq!(
            engine.next_outbox_backoff("peer-1"),
            std::time::Duration::from_millis(500)
        );

        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }
}
