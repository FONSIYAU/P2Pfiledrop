//! Flutter-facing API exposed via `flutter_rust_bridge` v2.

use crate::config::{EngineConfig, RelayPolicy};
use crate::crypto::identity::{PairingTicket, RoomInviteTicket, generate_6digit_pin};
use crate::db::store::{
    ChatMessageRecord, MessageDirection, MessageKind, MessageStatus, RoomMemberRecord, RoomRecord,
    TrustedPeer,
};
use crate::engine::{ChatTransferEngine, HomeNodeStatus};
use crate::net::lan_bypass::{
    PhysicalLanInterface, UsbRouteProtectionStatus, discover_physical_lan_interfaces,
    elevate_and_fix_usb_metric, is_usb_tether_adapter,
};
use crate::net::usb_bootstrap::UsbBootstrapPayload;
use crate::transfer::sync_engine::{EngineEvent, TransportKind};
use anyhow::{Context, Result};
use flutter_rust_bridge::frb;
use std::net::IpAddr;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, Once, OnceLock, RwLock};
use tokio::runtime::Runtime;

static RUNTIME: OnceLock<Runtime> = OnceLock::new();
static ENGINE: OnceLock<RwLock<Option<Arc<ChatTransferEngine>>>> = OnceLock::new();
static LOG_INIT: Once = Once::new();

fn init_file_logging(data_dir: &Path) {
    let _ = std::fs::create_dir_all(data_dir);
    let log_path = data_dir.join("engine.log");
    LOG_INIT.call_once(|| {
        const MAX_LOG_BYTES: u64 = 5 * 1024 * 1024;
        if let Ok(meta) = std::fs::metadata(&log_path)
            && meta.len() > MAX_LOG_BYTES
        {
            let old_path = data_dir.join("engine.log.old");
            let _ = std::fs::remove_file(&old_path);
            let _ = std::fs::rename(&log_path, &old_path);
        }
        if let Ok(file) = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&log_path)
        {
            let filter = tracing_subscriber::EnvFilter::try_new(
                "p2p_chat_core=info,iroh=warn,noq=warn",
            )
            .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info"));
            let _ = tracing_subscriber::fmt()
                .with_env_filter(filter)
                .with_ansi(false)
                .with_writer(Mutex::new(file))
                .try_init();
        }
    });
}

fn runtime() -> &'static Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("failed to build Tokio runtime")
    })
}

fn engine_slot() -> &'static RwLock<Option<Arc<ChatTransferEngine>>> {
    ENGINE.get_or_init(|| RwLock::new(None))
}

fn current_engine() -> Result<Arc<ChatTransferEngine>> {
    engine_slot()
        .read()
        .expect("engine lock poisoned")
        .clone()
        .context("engine not initialized; call init_engine first")
}

fn map_android_nics(android_nics: Vec<AndroidNicInfo>) -> Vec<PhysicalLanInterface> {
    android_nics
        .into_iter()
        .filter_map(|n| {
            let ip: IpAddr = n.local_ip.parse().ok()?;
            let is_usb = is_usb_tether_adapter(&n.name, &ip);
            Some(PhysicalLanInterface {
                os_index: n.os_index,
                name: n.name,
                local_ip: ip,
                android_network_handle: Some(n.network_handle),
                is_usb_tether: is_usb,
            })
        })
        .collect()
}

/// Physical Wi-Fi/Ethernet/USB interface metadata passed from Android Kotlin.
#[derive(Debug, Clone)]
pub struct AndroidNicInfo {
    pub os_index: u32,
    pub name: String,
    pub local_ip: String,
    pub network_handle: i64,
}

/// Paired peer DTO for Flutter UI.
#[derive(Debug, Clone)]
pub struct PeerDto {
    pub node_id: String,
    pub display_name: String,
    pub created_at_ms: i64,
    pub last_seen_ms: Option<i64>,
    pub avatar_path: Option<String>,
}

impl From<TrustedPeer> for PeerDto {
    fn from(p: TrustedPeer) -> Self {
        Self {
            node_id: p.node_id,
            display_name: p.display_name,
            created_at_ms: p.created_at_ms,
            last_seen_ms: p.last_seen_ms,
            avatar_path: p.avatar_path,
        }
    }
}

/// Active live transport status for a connected peer.
#[derive(Debug, Clone)]
pub struct PeerTransportDto {
    pub peer_id: String,
    pub transport: String,
}

/// Multi-room DTO for Flutter UI.
#[derive(Debug, Clone)]
pub struct RoomDto {
    pub room_id: String,
    pub name: String,
    pub room_type: String,
    pub is_pinned: bool,
    pub retention_days: u32,
    pub created_at_ms: i64,
    pub member_count: u32,
}

/// Room member DTO for Flutter UI.
#[derive(Debug, Clone)]
pub struct RoomMemberDto {
    pub room_id: String,
    pub node_id: String,
    pub display_name: String,
    pub role: String,
    pub joined_at_ms: i64,
}

impl From<RoomMemberRecord> for RoomMemberDto {
    fn from(m: RoomMemberRecord) -> Self {
        Self {
            room_id: m.room_id,
            node_id: m.node_id,
            display_name: m.display_name,
            role: m.role,
            joined_at_ms: m.joined_at_ms,
        }
    }
}

/// Home Node blind locker status & statistics DTO.
#[derive(Debug, Clone)]
pub struct HomeNodeStatusDto {
    pub enabled: bool,
    pub retention_days: u32,
    pub usb_installer_path: Option<String>,
    pub usb_bootstrap_urls: Vec<String>,
    pub active_cached_count: u32,
    pub active_cached_bytes: u64,
    pub total_purged_count: u32,
    pub registered_rooms_count: u32,
    pub pending_ack_links: u32,
}

impl From<HomeNodeStatus> for HomeNodeStatusDto {
    fn from(s: HomeNodeStatus) -> Self {
        Self {
            enabled: s.enabled,
            retention_days: s.retention_days,
            usb_installer_path: s.usb_installer_path,
            usb_bootstrap_urls: s.usb_bootstrap_urls,
            active_cached_count: s.stats.active_cached_count,
            active_cached_bytes: s.stats.active_cached_bytes,
            total_purged_count: s.stats.total_purged_count,
            registered_rooms_count: s.stats.registered_rooms_count,
            pending_ack_links: s.stats.pending_ack_links,
        }
    }
}

/// Windows USB anti-route-hijack status DTO.
#[derive(Debug, Clone)]
pub struct UsbRouteStatusDto {
    pub usb_tether_detected: bool,
    pub usb_if_index: Option<u32>,
    pub usb_if_name: Option<String>,
    pub usb_local_ip: Option<String>,
    pub metric_protected: bool,
    pub needs_elevation: bool,
    pub message: String,
}

impl From<UsbRouteProtectionStatus> for UsbRouteStatusDto {
    fn from(u: UsbRouteProtectionStatus) -> Self {
        Self {
            usb_tether_detected: u.usb_tether_detected,
            usb_if_index: u.usb_if_index,
            usb_if_name: u.usb_if_name,
            usb_local_ip: u.usb_local_ip,
            metric_protected: u.metric_protected,
            needs_elevation: u.needs_elevation,
            message: u.message,
        }
    }
}

/// Discovered USB Home Node bootstrap info DTO.
#[derive(Debug, Clone)]
pub struct UsbDiscoveredNodeDto {
    pub bootstrap_url: String,
    pub node_id: String,
    pub device_name: String,
    pub home_node_mode: bool,
    pub pairing_ticket_json: String,
    pub installer_filename: Option<String>,
    pub installer_size_bytes: Option<u64>,
}

/// Chat timeline message/file DTO for Flutter UI.
#[derive(Debug, Clone)]
pub struct MessageDto {
    pub msg_id: String,
    pub room_id: String,
    pub peer_id: String,
    pub sender_id: String,
    pub is_outgoing: bool,
    pub is_file: bool,
    pub body_text: Option<String>,
    pub file_name: Option<String>,
    pub file_size: Option<u64>,
    pub local_path: Option<String>,
    pub total_chunks: Option<u32>,
    pub completed_chunks: u32,
    pub status: String,
    pub delivery_scope: String,
    pub acked_peers: Vec<String>,
    pub batch_id: Option<String>,
    pub created_at_ms: i64,
}

impl From<ChatMessageRecord> for MessageDto {
    fn from(r: ChatMessageRecord) -> Self {
        let total = r.total_chunks.unwrap_or(0);
        let completed = match (&r.received_bitmap, total) {
            (Some(bm), t) if t > 0 => (0..t)
                .filter(|&i| crate::transfer::protocol::ChunkBitmap::is_set(bm, i))
                .count() as u32,
            _ if r.status == MessageStatus::Delivered => total as u32,
            _ => 0,
        };
        Self {
            msg_id: r.msg_id,
            room_id: r.room_id,
            peer_id: r.peer_id,
            sender_id: r.sender_id,
            is_outgoing: r.direction == MessageDirection::Outgoing,
            is_file: r.kind == MessageKind::File,
            body_text: r.body_text,
            file_name: r.file_name,
            file_size: r.file_size,
            local_path: r.local_path,
            total_chunks: r.total_chunks.map(|t| t as u32),
            completed_chunks: completed,
            status: status_to_string(r.status),
            delivery_scope: r.delivery_scope,
            acked_peers: r.acked_peers,
            batch_id: r.batch_id,
            created_at_ms: r.created_at_ms,
        }
    }
}

/// Live UI event pushed via stream to Flutter.
#[derive(Debug, Clone)]
pub struct UiEventDto {
    pub kind: String,
    pub room_id: Option<String>,
    pub peer_id: Option<String>,
    pub transport: Option<String>,
    pub msg_id: Option<String>,
    pub message: Option<MessageDto>,
    pub completed_chunks: Option<u32>,
    pub total_chunks: Option<u32>,
    pub status: Option<String>,
    pub local_path: Option<String>,
    pub bootstrap_url: Option<String>,
    pub display_name: Option<String>,
    pub avatar_path: Option<String>,
}

/// Initializes the Rust P2P engine and returns this device's `EndpointId`.
#[frb]
pub fn init_engine(
    data_dir: String,
    auto_receive_dir: String,
    custom_relay_url: Option<String>,
    android_nics: Vec<AndroidNicInfo>,
) -> Result<String> {
    init_file_logging(Path::new(&data_dir));
    tracing::info!(
        "init_engine starting data_dir={} android_nics={}",
        data_dir,
        android_nics.len()
    );
    let relay_policy = match custom_relay_url {
        Some(url) if !url.trim().is_empty() => RelayPolicy::Custom(url.trim().to_string()),
        _ => RelayPolicy::DefaultPublic,
    };

    let mut config =
        EngineConfig::with_dirs(PathBuf::from(data_dir), PathBuf::from(auto_receive_dir));
    config.relay_policy = relay_policy;

    let extra_ifaces = map_android_nics(android_nics);

    let engine = runtime().block_on(async move {
        ChatTransferEngine::start_fast(config, extra_ifaces)
    })?;

    let my_id = engine.my_endpoint_id().to_string();
    *engine_slot().write().expect("engine lock poisoned") = Some(engine);
    Ok(my_id)
}

/// Hot-reloads physical/USB network interfaces (e.g. when a USB cable is plugged in while running).
#[frb]
pub fn refresh_network_interfaces(android_nics: Vec<AndroidNicInfo>) -> Result<()> {
    let engine = current_engine()?;
    let extra = map_android_nics(android_nics);
    runtime().block_on(async move { engine.reconcile_network_interfaces(extra).await })?;
    Ok(())
}

/// Returns this device's QR pairing ticket JSON string (Phase 1 compatibility).
#[frb]
pub fn create_pairing_qr(device_name: String) -> Result<String> {
    let engine = current_engine()?;
    runtime().block_on(async {
        let _ = tokio::time::timeout(std::time::Duration::from_millis(1200), async {
            tokio::join!(engine.wait_lan_ready(), engine.wait_online())
        })
        .await;
    });
    let ticket = engine.create_pairing_ticket(&device_name)?;
    ticket.to_qr_string()
}

/// Generates a 6-digit pairing PIN (for display in the UI).
#[frb(sync)]
pub fn generate_pairing_pin() -> String {
    generate_6digit_pin()
}

/// Pairs with a remote device using a scanned QR string or pasted pairing ticket.
#[frb]
pub fn pair_with_qr(qr_json: String) -> Result<PeerDto> {
    let engine = current_engine()?;
    let ticket = PairingTicket::from_qr_string(&qr_json)?;
    let peer = runtime().block_on(async move { engine.pair_with_ticket(ticket).await })?;
    Ok(peer.into())
}

/// Lists all paired peers.
#[frb]
pub fn list_peers() -> Result<Vec<PeerDto>> {
    let engine = current_engine()?;
    Ok(engine.list_peers()?.into_iter().map(Into::into).collect())
}

/// Connects to an already-paired peer by its `node_id`.
#[frb]
pub fn connect_peer_by_id(peer_id: String) -> Result<String> {
    let engine = current_engine()?;
    let transport =
        runtime().block_on(async move { engine.connect_peer_by_id(&peer_id).await })?;
    Ok(transport_to_string(transport))
}

/// Lists chat timeline messages for `peer_id` (Phase 1 compat).
#[frb]
pub fn list_timeline(peer_id: String, limit: u32) -> Result<Vec<MessageDto>> {
    let engine = current_engine()?;
    Ok(engine
        .list_timeline(&peer_id, limit as usize)?
        .into_iter()
        .map(Into::into)
        .collect())
}

/// Sends a text message (Phase 1 compat).
#[frb]
pub fn send_text(peer_id: String, text: String) -> Result<MessageDto> {
    let engine = current_engine()?;
    let record = runtime().block_on(async move { engine.send_text(&peer_id, &text) })?;
    Ok(record.into())
}

/// Sends a file (Phase 1 compat).
#[frb]
pub fn send_file(peer_id: String, file_path: String) -> Result<MessageDto> {
    let engine = current_engine()?;
    let record = runtime()
        .block_on(async move { engine.send_file(&peer_id, PathBuf::from(file_path)).await })?;
    Ok(record.into())
}

// -----------------------------------------------------------------------------
// Phase 2 Multi-Room & Home Node Blind Locker FFI
// -----------------------------------------------------------------------------

fn room_to_dto(engine: &ChatTransferEngine, r: RoomRecord) -> RoomDto {
    let member_count = engine
        .list_room_members(&r.room_id)
        .map(|m| m.len() as u32)
        .unwrap_or(0);
    RoomDto {
        room_id: r.room_id,
        name: r.name,
        room_type: r.room_type,
        is_pinned: r.is_pinned,
        retention_days: r.retention_days,
        created_at_ms: r.created_at_ms,
        member_count,
    }
}

/// Lists all chat-capable rooms (excluding blind-locker-only rooms).
#[frb]
pub fn list_rooms() -> Result<Vec<RoomDto>> {
    let engine = current_engine()?;
    let rooms = engine.list_rooms()?;
    Ok(rooms
        .into_iter()
        .map(|r| room_to_dto(&engine, r))
        .collect())
}

/// Lists all members and roles inside `room_id`.
#[frb]
pub fn list_room_members(room_id: String) -> Result<Vec<RoomMemberDto>> {
    let engine = current_engine()?;
    Ok(engine
        .list_room_members(&room_id)?
        .into_iter()
        .map(Into::into)
        .collect())
}

/// Creates a new isolated E2EE group room.
#[frb]
pub fn create_room(name: String, my_device_name: String) -> Result<RoomDto> {
    let engine = current_engine()?;
    let room = runtime().block_on(async { engine.create_room(&name, &my_device_name) })?;
    Ok(room_to_dto(&engine, room))
}

/// Generates a QR invite ticket for a room (either for a regular member or a zero-knowledge Home Node).
#[frb]
pub fn create_room_invite_qr(
    room_id: String,
    device_name: String,
    invite_as_home_node: bool,
) -> Result<String> {
    let engine = current_engine()?;
    runtime().block_on(async {
        let _ = tokio::time::timeout(std::time::Duration::from_millis(1200), async {
            tokio::join!(engine.wait_lan_ready(), engine.wait_online())
        })
        .await;
    });
    let ticket = engine.create_room_invite(&room_id, &device_name, invite_as_home_node)?;
    ticket.to_qr_string()
}

/// Joins an encrypted room using a `RoomInviteTicket` JSON string.
#[frb]
pub fn join_room_with_qr(qr_json: String, my_device_name: String) -> Result<RoomDto> {
    let engine = current_engine()?;
    let ticket = RoomInviteTicket::from_qr_string(&qr_json)?;
    let room = runtime()
        .block_on(async move { engine.join_room_with_invite(ticket, &my_device_name).await })?;
    let engine_ref = current_engine()?;
    Ok(room_to_dto(&engine_ref, room))
}

/// Lists decrypted timeline messages for `room_id`.
#[frb]
pub fn list_room_timeline(room_id: String, limit: u32) -> Result<Vec<MessageDto>> {
    let engine = current_engine()?;
    Ok(engine
        .list_room_timeline(&room_id, limit as usize)?
        .into_iter()
        .map(Into::into)
        .collect())
}

/// Lists file/image messages across all rooms or for a single `room_id`, newest first.
#[frb]
pub fn list_room_files(room_id: Option<String>, limit: u32) -> Result<Vec<MessageDto>> {
    let engine = current_engine()?;
    Ok(engine
        .list_media_messages(room_id.as_deref(), limit as usize)?
        .into_iter()
        .map(Into::into)
        .collect())
}

/// Sends an E2EE text message inside `room_id`.
#[frb]
pub fn send_room_text(room_id: String, text: String) -> Result<MessageDto> {
    let engine = current_engine()?;
    let rec = runtime().block_on(async move { engine.send_room_text(&room_id, &text) })?;
    Ok(rec.into())
}

/// Sends an E2EE file inside `room_id`.
#[frb]
pub fn send_room_file(room_id: String, file_path: String) -> Result<MessageDto> {
    let engine = current_engine()?;
    let rec = runtime()
        .block_on(async move { engine.send_room_file(&room_id, PathBuf::from(file_path)).await })?;
    Ok(rec.into())
}

/// Sends an E2EE file inside `room_id` tagged with an explicit client `batch_id`.
#[frb]
pub fn send_room_file_in_batch(
    room_id: String,
    file_path: String,
    batch_id: Option<String>,
) -> Result<MessageDto> {
    let engine = current_engine()?;
    let rec = runtime().block_on(async move {
        engine
            .send_room_file_with_batch(&room_id, PathBuf::from(file_path), batch_id)
            .await
    })?;
    Ok(rec.into())
}

/// Deletes a single message locally (`Delete for me`). Never removes sender source files.
#[frb]
pub fn delete_message_local(msg_id: String, delete_local_file: bool) -> Result<bool> {
    let engine = current_engine()?;
    engine.delete_message_local(&msg_id, delete_local_file)
}

/// Revokes an outgoing message across all room devices & Home Nodes (`Delete for everyone`).
#[frb]
pub fn revoke_message_for_everyone(msg_id: String) -> Result<MessageDto> {
    let engine = current_engine()?;
    let _guard = runtime().enter();
    let updated = engine.revoke_message_for_everyone(&msg_id)?;
    Ok(updated.into())
}

/// Connects to members of `room_id` and returns the highest-priority active transport in that room.
#[frb]
pub fn connect_room_peers(room_id: String) -> Result<String> {
    let engine = current_engine()?;
    let my_id = engine.my_endpoint_id().to_string();
    let members = engine.list_room_members(&room_id)?;
    let transport_opt = runtime().block_on(async move {
        let mut best: Option<TransportKind> = None;
        for m in members {
            if m.node_id == my_id {
                continue;
            }
            if let Ok(t) = engine.connect_peer_by_id(&m.node_id).await {
                if best.is_none_or(|b| t.priority_rank() > b.priority_rank()) {
                    best = Some(t);
                }
            } else if let Some(t) = engine.active_transport(&m.node_id).await {
                if best.is_none_or(|b| t.priority_rank() > b.priority_rank()) {
                    best = Some(t);
                }
            }
        }
        best
    });
    Ok(transport_opt
        .map(transport_to_string)
        .unwrap_or_else(|| "offline".to_string()))
}

/// Toggles 24h Home Node blind-locker mode and updates retention TTL & optional USB installer path.
#[frb]
pub fn set_home_node_mode(
    enabled: bool,
    retention_days: u32,
    usb_installer_path: Option<String>,
) -> Result<HomeNodeStatusDto> {
    let engine = current_engine()?;
    let status = engine.set_home_node_mode(enabled, retention_days, usb_installer_path)?;
    Ok(status.into())
}

/// Returns current Home Node blind-locker statistics and USB bootstrap URLs.
#[frb]
pub fn get_home_node_status() -> Result<HomeNodeStatusDto> {
    let engine = current_engine()?;
    Ok(engine.get_home_node_status()?.into())
}

/// Triggers an immediate purge of expired blind locker items.
#[frb]
pub fn purge_expired_locker_now() -> Result<u32> {
    let engine = current_engine()?;
    let count = runtime().block_on(async move { engine.purge_expired_locker_now().await })?;
    Ok(count as u32)
}

/// Probes USB tethering neighbors on `:42420` for an attached Home Node.
#[frb]
pub fn probe_usb_home_node() -> Result<Option<UsbDiscoveredNodeDto>> {
    let engine = current_engine()?;
    let res = runtime().block_on(async move { engine.probe_usb_home_node().await });
    Ok(res.map(
        |(url, p): (String, UsbBootstrapPayload)| UsbDiscoveredNodeDto {
            bootstrap_url: url,
            node_id: p.node_id,
            device_name: p.device_name,
            home_node_mode: p.home_node_mode,
            pairing_ticket_json: p.pairing_ticket_json,
            installer_filename: p.installer_filename,
            installer_size_bytes: p.installer_size_bytes,
        },
    ))
}

/// One-click binds a USB-discovered Home Node into `room_id`.
#[frb]
pub fn bind_usb_home_node(
    room_id: String,
    pairing_ticket_json: String,
    device_name: String,
) -> Result<PeerDto> {
    let engine = current_engine()?;
    let payload = UsbBootstrapPayload {
        node_id: String::new(),
        device_name,
        home_node_mode: true,
        pairing_ticket_json,
        room_invite_json: None,
        installer_filename: None,
        installer_size_bytes: None,
        lan_addrs: Vec::new(),
        usb_addrs: Vec::new(),
    };
    let peer = runtime()
        .block_on(async move { engine.bind_usb_home_node(&room_id, payload).await })?;
    Ok(peer.into())
}

/// Returns Windows USB anti-route-hijack status.
#[frb]
pub fn get_usb_route_protection_status() -> Result<UsbRouteStatusDto> {
    let engine = current_engine()?;
    Ok(engine.usb_route_protection_status()?.into())
}

/// Requests UAC elevation once on Windows to set the USB adapter metric to `5000`.
#[frb]
pub fn fix_windows_usb_metric(os_index: u32) -> Result<UsbRouteStatusDto> {
    Ok(elevate_and_fix_usb_metric(os_index)?.into())
}

/// Updates the live auto-receive directory after validating write permissions.
#[frb]
pub fn set_auto_receive_dir(dir_path: String) -> Result<String> {
    let engine = current_engine()?;
    let updated = engine.set_auto_receive_dir(PathBuf::from(dir_path))?;
    Ok(updated.to_string_lossy().to_string())
}

/// Updates a delivered message's `local_path` after platform MediaStore export.
#[frb]
pub fn update_message_local_path(msg_id: String, local_path: String) -> Result<bool> {
    let engine = current_engine()?;
    engine.store.update_message_local_path(&msg_id, &local_path)
}

/// Lists discovered physical LAN & USB interfaces (for diagnostics/status verification).
#[frb]
pub fn list_physical_lan_interfaces() -> Result<Vec<String>> {
    let ifaces = discover_physical_lan_interfaces()?;
    Ok(ifaces
        .into_iter()
        .map(|i| {
            let tag = if i.is_usb_tether { "[USB专线] " } else { "" };
            format!("{}{} [if={}] {}", tag, i.local_ip, i.os_index, i.name)
        })
        .collect())
}

/// Updates this device's synced display name and/or avatar image bytes (and broadcasts to connected peers).
#[frb]
pub fn update_my_profile(
    display_name: Option<String>,
    avatar_png: Option<Vec<u8>>,
    clear_avatar: bool,
) -> Result<Option<String>> {
    let engine = current_engine()?;
    runtime().block_on(async move {
        engine
            .update_my_profile(display_name, avatar_png, clear_avatar)
            .await
    })
}

/// Returns the local cached file path of this device's uploaded avatar image, if any.
#[frb]
pub fn get_my_avatar_path() -> Result<Option<String>> {
    let engine = current_engine()?;
    Ok(engine.get_my_avatar_path())
}

/// Returns all currently active `(peer_id, transport)` links.
#[frb]
pub fn list_active_peer_transports() -> Result<Vec<PeerTransportDto>> {
    let engine = current_engine()?;
    let active = runtime().block_on(async { engine.snapshot_active_transports().await });
    Ok(active
        .into_iter()
        .map(|(peer_id, kind)| PeerTransportDto {
            peer_id,
            transport: transport_to_string(kind).to_string(),
        })
        .collect())
}

/// Triggers non-blocking background dials to all paired peers not yet active.
#[frb]
pub fn connect_all_paired_peers() -> Result<()> {
    let engine = current_engine()?;
    let _guard = runtime().enter();
    engine.spawn_connect_all_paired_peers();
    Ok(())
}

/// Subscribes to real-time engine events.
#[frb]
pub fn subscribe_events(sink: crate::frb_generated::StreamSink<UiEventDto>) -> Result<()> {
    let engine = current_engine()?;
    let mut rx = engine.subscribe_events();
    runtime().spawn(async move {
        // Replay currently active connections so late subscribers never show connected peers as offline.
        for (peer_id, kind) in engine.snapshot_active_transports().await {
            let dto = UiEventDto {
                peer_id: Some(peer_id),
                transport: Some(transport_to_string(kind)),
                ..base_ui_event("peer_connected")
            };
            if sink.add(dto).is_err() {
                return;
            }
        }

        loop {
            match rx.recv().await {
                Ok(ev) => {
                    let dto = map_event(ev);
                    if sink.add(dto).is_err() {
                        break;
                    }
                }
                Err(tokio::sync::broadcast::error::RecvError::Lagged(skipped)) => {
                    tracing::warn!("UI event subscriber lagged behind by {skipped} events; requesting resync");
                    for (peer_id, kind) in engine.snapshot_active_transports().await {
                        let dto = UiEventDto {
                            peer_id: Some(peer_id),
                            transport: Some(transport_to_string(kind)),
                            ..base_ui_event("peer_connected")
                        };
                        if sink.add(dto).is_err() {
                            return;
                        }
                    }
                    let resync = UiEventDto {
                        room_id: Some(String::new()),
                        ..base_ui_event("room_updated")
                    };
                    if sink.add(resync).is_err() {
                        break;
                    }
                }
                Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
            }
        }
    });
    Ok(())
}

fn base_ui_event(kind: &str) -> UiEventDto {
    UiEventDto {
        kind: kind.to_string(),
        room_id: None,
        peer_id: None,
        transport: None,
        msg_id: None,
        message: None,
        completed_chunks: None,
        total_chunks: None,
        status: None,
        local_path: None,
        bootstrap_url: None,
        display_name: None,
        avatar_path: None,
    }
}

fn map_event(ev: EngineEvent) -> UiEventDto {
    match ev {
        EngineEvent::PeerConnected { peer_id, transport } => UiEventDto {
            peer_id: Some(peer_id),
            transport: Some(transport_to_string(transport)),
            ..base_ui_event("peer_connected")
        },
        EngineEvent::PeerDisconnected { peer_id } => UiEventDto {
            peer_id: Some(peer_id),
            ..base_ui_event("peer_disconnected")
        },
        EngineEvent::MessageAdded(record) => UiEventDto {
            room_id: Some(record.room_id.clone()),
            peer_id: Some(record.peer_id.clone()),
            msg_id: Some(record.msg_id.clone()),
            message: Some(record.into()),
            ..base_ui_event("message_added")
        },
        EngineEvent::MessageUpdated(record) => UiEventDto {
            room_id: Some(record.room_id.clone()),
            peer_id: Some(record.peer_id.clone()),
            msg_id: Some(record.msg_id.clone()),
            message: Some(record.into()),
            ..base_ui_event("message_updated")
        },
        EngineEvent::MessageDeleted { room_id, msg_id } => UiEventDto {
            room_id: Some(room_id),
            msg_id: Some(msg_id),
            ..base_ui_event("message_deleted")
        },
        EngineEvent::TransferProgress {
            msg_id,
            completed_chunks,
            total_chunks,
            status,
            local_path,
        } => UiEventDto {
            msg_id: Some(msg_id),
            completed_chunks: Some(completed_chunks as u32),
            total_chunks: Some(total_chunks as u32),
            status: Some(status_to_string(status)),
            local_path,
            ..base_ui_event("transfer_progress")
        },
        EngineEvent::RoomUpdated { room_id } => UiEventDto {
            room_id: Some(room_id),
            ..base_ui_event("room_updated")
        },
        EngineEvent::HomeNodeStatsUpdated | EngineEvent::LockerItemReady { .. } => {
            base_ui_event("home_node_stats_updated")
        }
        EngineEvent::UsbHomeNodeDiscovered {
            node_id,
            bootstrap_url,
        } => UiEventDto {
            peer_id: Some(node_id),
            bootstrap_url: Some(bootstrap_url),
            ..base_ui_event("usb_home_node_discovered")
        },
        EngineEvent::OutboxRetryRequested { peer_id } => UiEventDto {
            peer_id: Some(peer_id),
            ..base_ui_event("outbox_retry")
        },
        EngineEvent::PeerProfileUpdated {
            peer_id,
            display_name,
            avatar_path,
        } => UiEventDto {
            peer_id: Some(peer_id),
            display_name: Some(display_name),
            avatar_path,
            ..base_ui_event("peer_profile_updated")
        },
    }
}

fn status_to_string(status: MessageStatus) -> String {
    status.as_str().to_string()
}

fn transport_to_string(t: TransportKind) -> String {
    match t {
        TransportKind::UsbTetherDirect => "usb_tether",
        TransportKind::LanDirectPhysicalNic => "lan_direct",
        TransportKind::WanDirectP2p => "wan_p2p",
        TransportKind::WanRelay => "wan_relay",
    }
    .to_string()
}
