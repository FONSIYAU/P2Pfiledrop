//! SQLite local persistence for multi-room chat timelines, trusted peers,
//! per-recipient Outbox queues, chunk bitmaps, and zero-knowledge blind locker state.

use crate::crypto::room_cipher::{generate_room_key, room_key_to_hex};
use anyhow::{Context, Result};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use std::path::Path;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

pub const DEFAULT_PERSONAL_ROOM_ID: &str = "personal-default";
pub const DEFAULT_PERSONAL_ROOM_NAME: &str = "个人设备群 (Personal)";
pub const LARGE_FILE_CONFIRM_THRESHOLD_BYTES: u64 = 50 * 1024 * 1024;

/// Computes the deterministic 1v1 DM room ID for a pair of device EndpointIds.
pub fn dm_room_id(node_a: &str, node_b: &str) -> String {
    let a = node_a.trim();
    let b = node_b.trim();
    if a <= b {
        format!("dm-{a}-{b}")
    } else {
        format!("dm-{b}-{a}")
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PeerEndpointHints {
    pub lan_addrs: Vec<String>,
    pub endpoint_addr: Option<iroh::EndpointAddr>,
}

/// Message direction relative to the local device.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MessageDirection {
    Outgoing,
    Incoming,
}

impl MessageDirection {
    fn as_str(self) -> &'static str {
        match self {
            Self::Outgoing => "outgoing",
            Self::Incoming => "incoming",
        }
    }

    fn from_str(s: &str) -> Result<Self> {
        match s {
            "outgoing" => Ok(Self::Outgoing),
            "incoming" => Ok(Self::Incoming),
            _ => anyhow::bail!("unknown message direction: {s}"),
        }
    }
}

/// Message payload kind.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MessageKind {
    Text,
    File,
}

impl MessageKind {
    fn as_str(self) -> &'static str {
        match self {
            Self::Text => "text",
            Self::File => "file",
        }
    }

    fn from_str(s: &str) -> Result<Self> {
        match s {
            "text" => Ok(Self::Text),
            "file" => Ok(Self::File),
            _ => anyhow::bail!("unknown message kind: {s}"),
        }
    }
}

/// Transfer & offline-queue lifecycle state.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MessageStatus {
    QueuedOffline,
    AwaitingDownload,
    Handshaking,
    Transferring,
    PausedReconnecting,
    Delivered,
    FailedSourceMissing,
    Revoked,
}

impl MessageStatus {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::QueuedOffline => "queued_offline",
            Self::AwaitingDownload => "awaiting_download",
            Self::Handshaking => "handshaking",
            Self::Transferring => "transferring",
            Self::PausedReconnecting => "paused_reconnecting",
            Self::Delivered => "delivered",
            Self::FailedSourceMissing => "failed_source_missing",
            Self::Revoked => "revoked",
        }
    }

    fn from_str(s: &str) -> Result<Self> {
        match s {
            "queued_offline" => Ok(Self::QueuedOffline),
            "awaiting_download" => Ok(Self::AwaitingDownload),
            "handshaking" => Ok(Self::Handshaking),
            "transferring" => Ok(Self::Transferring),
            "paused_reconnecting" => Ok(Self::PausedReconnecting),
            "delivered" => Ok(Self::Delivered),
            "failed_source_missing" => Ok(Self::FailedSourceMissing),
            "revoked" => Ok(Self::Revoked),
            _ => anyhow::bail!("unknown message status: {s}"),
        }
    }
}

/// Pending signed message-revoke job queued for a direct recipient or blind Home Node.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PendingRoomRevoke {
    pub revoke_id: String,
    pub room_id: String,
    pub msg_id: String,
    pub sender_id: String,
    pub target_peer_id: String,
    pub store_in_locker: bool,
    pub target_peers: Vec<String>,
    pub signature_bytes: Vec<u8>,
    pub created_at_ms: i64,
}

/// Trusted paired peer record.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrustedPeer {
    pub node_id: String,
    pub display_name: String,
    pub created_at_ms: i64,
    pub last_seen_ms: Option<i64>,
    #[serde(default)]
    pub avatar_hash: Option<String>,
    #[serde(default)]
    pub avatar_path: Option<String>,
}

/// Multi-room descriptor.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomRecord {
    pub room_id: String,
    pub name: String,
    /// `"personal"` | `"group"`
    pub room_type: String,
    /// `None` when this device is strictly a blind `home_node` for the room.
    pub room_key_hex: Option<String>,
    pub is_pinned: bool,
    pub retention_days: u32,
    pub created_at_ms: i64,
}

/// Device membership inside a room.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomMemberRecord {
    pub room_id: String,
    pub node_id: String,
    pub display_name: String,
    /// `"owner"` | `"member"` | `"home_node"`
    pub role: String,
    pub joined_at_ms: i64,
}

/// Persisted chat message / file transfer record.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessageRecord {
    pub msg_id: String,
    pub room_id: String,
    pub peer_id: String,
    pub sender_id: String,
    pub direction: MessageDirection,
    pub kind: MessageKind,
    pub body_text: Option<String>,
    pub file_name: Option<String>,
    pub file_size: Option<u64>,
    pub local_path: Option<String>,
    pub root_blake3: Option<Vec<u8>>,
    pub chunk_size: Option<usize>,
    pub total_chunks: Option<usize>,
    pub received_bitmap: Option<Vec<u8>>,
    pub status: MessageStatus,
    /// `"direct"` | `"cached_on_home_node"` | `"delivered_all"`
    pub delivery_scope: String,
    pub acked_peers: Vec<String>,
    pub batch_id: Option<String>,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
}

/// Opaque encrypted payload stored in the Home Node blind locker.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BlindLockerItem {
    pub msg_id: String,
    pub room_id: String,
    pub sender_id: String,
    pub envelope_json: String,
    pub cipher_file_path: Option<String>,
    pub cipher_file_size: u64,
    pub cipher_root_blake3: Option<Vec<u8>>,
    pub chunk_size: usize,
    pub total_chunks: usize,
    pub cipher_chunk_hashes_json: Option<String>,
    pub received_bitmap: Option<Vec<u8>>,
    /// `"receiving"` | `"ready"` | `"purged"` | `"expired"`
    pub status: String,
    pub created_at_ms: i64,
    pub expires_at_ms: i64,
}

/// Aggregate statistics for the Home Node blind locker (zero plaintext metadata).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct HomeNodeStats {
    pub active_cached_count: u32,
    pub active_cached_bytes: u64,
    pub total_purged_count: u32,
    pub registered_rooms_count: u32,
    pub pending_ack_links: u32,
}

/// Pending outgoing delivery job bound for a specific peer (either a direct recipient or a blind Home Node).
#[derive(Debug, Clone)]
pub struct PendingRoomOutboxJob {
    pub message: ChatMessageRecord,
    pub target_peers: Vec<String>,
    pub store_in_locker: bool,
    pub offer_only: bool,
}

/// Signed delivery receipt stored on Home Node to notify the original sender once cached items are picked up.
#[derive(Debug, Clone)]
pub struct UnforwardedLockerAck {
    pub msg_id: String,
    pub room_id: String,
    pub sender_id: String,
    pub target_peer_id: String,
    pub signature_bytes: Vec<u8>,
}

/// Thread-safe SQLite store wrapper.
#[derive(Clone)]
pub struct LocalStore {
    conn: Arc<Mutex<Connection>>,
}

impl LocalStore {
    /// Opens or creates the SQLite database at `db_path` and runs schema migrations.
    pub fn open(db_path: &Path) -> Result<Self> {
        if let Some(parent) = db_path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let conn = Connection::open(db_path)
            .with_context(|| format!("failed to open sqlite db at {}", db_path.display()))?;
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        let store = Self {
            conn: Arc::new(Mutex::new(conn)),
        };
        store.migrate()?;
        Ok(store)
    }

    fn migrate(&self) -> Result<()> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS peers (
                node_id TEXT PRIMARY KEY,
                display_name TEXT NOT NULL,
                created_at_ms INTEGER NOT NULL,
                last_seen_ms INTEGER,
                last_endpoint_json TEXT
            );

            CREATE TABLE IF NOT EXISTS messages (
                msg_id TEXT PRIMARY KEY,
                peer_id TEXT NOT NULL,
                direction TEXT NOT NULL,
                kind TEXT NOT NULL,
                body_text TEXT,
                file_name TEXT,
                file_size INTEGER,
                local_path TEXT,
                root_blake3 BLOB,
                chunk_size INTEGER,
                total_chunks INTEGER,
                received_bitmap BLOB,
                status TEXT NOT NULL,
                created_at_ms INTEGER NOT NULL,
                updated_at_ms INTEGER NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_messages_peer_time
                ON messages(peer_id, created_at_ms ASC);

            CREATE INDEX IF NOT EXISTS idx_messages_outbox
                ON messages(peer_id, direction, status, created_at_ms ASC);

            CREATE TABLE IF NOT EXISTS rooms (
                room_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                room_type TEXT NOT NULL,
                room_key_hex TEXT,
                is_pinned INTEGER NOT NULL DEFAULT 0,
                retention_days INTEGER NOT NULL DEFAULT 7,
                created_at_ms INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS room_members (
                room_id TEXT NOT NULL,
                node_id TEXT NOT NULL,
                display_name TEXT NOT NULL,
                role TEXT NOT NULL,
                joined_at_ms INTEGER NOT NULL,
                PRIMARY KEY (room_id, node_id)
            );

            CREATE TABLE IF NOT EXISTS room_outbox_targets (
                msg_id TEXT NOT NULL,
                room_id TEXT NOT NULL,
                target_peer_id TEXT NOT NULL,
                status TEXT NOT NULL,
                updated_at_ms INTEGER NOT NULL,
                PRIMARY KEY (msg_id, target_peer_id)
            );

            CREATE TABLE IF NOT EXISTS room_locker_uploads (
                msg_id TEXT NOT NULL,
                home_node_id TEXT NOT NULL,
                status TEXT NOT NULL,
                updated_at_ms INTEGER NOT NULL,
                PRIMARY KEY (msg_id, home_node_id)
            );

            CREATE TABLE IF NOT EXISTS blind_locker_items (
                msg_id TEXT PRIMARY KEY,
                room_id TEXT NOT NULL,
                sender_id TEXT NOT NULL,
                envelope_json TEXT NOT NULL,
                cipher_file_path TEXT,
                cipher_file_size INTEGER NOT NULL DEFAULT 0,
                cipher_root_blake3 BLOB,
                chunk_size INTEGER NOT NULL DEFAULT 0,
                total_chunks INTEGER NOT NULL DEFAULT 0,
                cipher_chunk_hashes_json TEXT,
                received_bitmap BLOB,
                status TEXT NOT NULL,
                created_at_ms INTEGER NOT NULL,
                expires_at_ms INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS blind_locker_acks (
                msg_id TEXT NOT NULL,
                room_id TEXT NOT NULL,
                target_peer_id TEXT NOT NULL,
                acked_at_ms INTEGER,
                signature_bytes BLOB,
                forwarded_to_sender INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (msg_id, target_peer_id)
            );

            CREATE TABLE IF NOT EXISTS engine_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            ",
        )?;

        // Idempotent schema upgrades for Phase 1 databases.
        let _ = conn.execute("ALTER TABLE peers ADD COLUMN last_endpoint_json TEXT", []);
        let _ = conn.execute(
            "ALTER TABLE messages ADD COLUMN room_id TEXT NOT NULL DEFAULT 'personal-default'",
            [],
        );
        let _ = conn.execute(
            "ALTER TABLE messages ADD COLUMN sender_id TEXT NOT NULL DEFAULT ''",
            [],
        );
        let _ = conn.execute(
            "ALTER TABLE messages ADD COLUMN delivery_scope TEXT NOT NULL DEFAULT 'direct'",
            [],
        );
        let _ = conn.execute(
            "ALTER TABLE messages ADD COLUMN acked_peers_json TEXT NOT NULL DEFAULT '[]'",
            [],
        );
        let _ = conn.execute(
            "ALTER TABLE blind_locker_acks ADD COLUMN signature_bytes BLOB",
            [],
        );
        let _ = conn.execute(
            "ALTER TABLE blind_locker_acks ADD COLUMN forwarded_to_sender INTEGER NOT NULL DEFAULT 0",
            [],
        );
        let _ = conn.execute("ALTER TABLE peers ADD COLUMN avatar_hash TEXT", []);
        let _ = conn.execute("ALTER TABLE peers ADD COLUMN avatar_path TEXT", []);
        let _ = conn.execute("ALTER TABLE messages ADD COLUMN batch_id TEXT", []);

        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_messages_room_time ON messages(room_id, created_at_ms ASC)",
            [],
        )?;
        conn.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS pending_room_revokes (
                revoke_id TEXT PRIMARY KEY,
                room_id TEXT NOT NULL,
                msg_id TEXT NOT NULL,
                sender_id TEXT NOT NULL,
                target_peer_id TEXT NOT NULL,
                store_in_locker INTEGER NOT NULL DEFAULT 0,
                target_peers_json TEXT NOT NULL,
                signature_bytes BLOB NOT NULL,
                delivered INTEGER NOT NULL DEFAULT 0,
                created_at_ms INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS revoked_message_tombstones (
                msg_id TEXT PRIMARY KEY,
                room_id TEXT NOT NULL,
                sender_id TEXT NOT NULL,
                revoked_at_ms INTEGER NOT NULL
            );
            ",
        )?;
        Ok(())
    }

    // -------------------------------------------------------------------------
    // Engine Settings
    // -------------------------------------------------------------------------

    pub fn get_setting(&self, key: &str) -> Result<Option<String>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let val = conn
            .query_row(
                "SELECT value FROM engine_settings WHERE key = ?1",
                params![key],
                |row| row.get(0),
            )
            .optional()?;
        Ok(val)
    }

    pub fn set_setting(&self, key: &str, value: &str) -> Result<()> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "INSERT INTO engine_settings (key, value) VALUES (?1, ?2)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            params![key, value],
        )?;
        Ok(())
    }

    pub fn is_home_node_mode(&self) -> bool {
        self.get_setting("home_node_mode")
            .ok()
            .flatten()
            .is_some_and(|v| v == "true")
    }

    pub fn set_home_node_mode_setting(&self, enabled: bool) -> Result<()> {
        self.set_setting("home_node_mode", if enabled { "true" } else { "false" })
    }

    pub fn get_retention_days(&self) -> u32 {
        self.get_setting("retention_days")
            .ok()
            .flatten()
            .and_then(|v| v.parse::<u32>().ok())
            .filter(|&d| d > 0)
            .unwrap_or(7)
    }

    pub fn set_retention_days_setting(&self, days: u32) -> Result<()> {
        self.set_setting("retention_days", &days.max(1).to_string())
    }

    pub fn get_usb_installer_path(&self) -> Option<String> {
        self.get_setting("usb_installer_path")
            .ok()
            .flatten()
            .filter(|s| !s.trim().is_empty())
    }

    pub fn set_usb_installer_path_setting(&self, path: Option<&str>) -> Result<()> {
        self.set_setting("usb_installer_path", path.unwrap_or("").trim())
    }

    pub fn set_self_profile(&self, display_name: Option<&str>, avatar_hash: Option<Option<&str>>) -> Result<()> {
        if let Some(name) = display_name {
            let trimmed = name.trim();
            if !trimmed.is_empty() {
                self.set_setting("self_display_name", trimmed)?;
            }
        }
        if let Some(hash_opt) = avatar_hash {
            self.set_setting("self_avatar_hash", hash_opt.unwrap_or("").trim())?;
        }
        Ok(())
    }

    pub fn get_self_profile(&self) -> (Option<String>, Option<String>) {
        let name = self
            .get_setting("self_display_name")
            .ok()
            .flatten()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());
        let hash = self
            .get_setting("self_avatar_hash")
            .ok()
            .flatten()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());
        (name, hash)
    }

    // -------------------------------------------------------------------------
    // Trusted Peers
    // -------------------------------------------------------------------------

    /// Inserts or updates a paired peer.
    pub fn upsert_peer(&self, node_id: &str, display_name: &str) -> Result<()> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "
            INSERT INTO peers (node_id, display_name, created_at_ms, last_seen_ms)
            VALUES (?1, ?2, ?3, ?3)
            ON CONFLICT(node_id) DO UPDATE SET
                display_name = CASE
                    WHEN trim(excluded.display_name) NOT IN ('', 'Paired Device', '本机设备')
                         OR trim(peers.display_name) IN ('', 'Paired Device', '本机设备')
                    THEN excluded.display_name
                    ELSE peers.display_name
                END,
                last_seen_ms = excluded.last_seen_ms
            ",
            params![node_id, display_name, now],
        )?;
        Ok(())
    }

    /// Returns `true` if `node_id` is in the local trusted contacts (`peers`).
    pub fn has_peer(&self, node_id: &str) -> bool {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.query_row(
            "SELECT 1 FROM peers WHERE node_id = ?1 LIMIT 1",
            params![node_id],
            |_| Ok(()),
        )
        .optional()
        .ok()
        .flatten()
        .is_some()
    }

    /// Lists all paired peers.
    pub fn list_peers(&self) -> Result<Vec<TrustedPeer>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT node_id, display_name, created_at_ms, last_seen_ms, avatar_hash, avatar_path FROM peers ORDER BY created_at_ms ASC",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(TrustedPeer {
                node_id: row.get(0)?,
                display_name: row.get(1)?,
                created_at_ms: row.get(2)?,
                last_seen_ms: row.get(3)?,
                avatar_hash: row.get(4)?,
                avatar_path: row.get(5)?,
            })
        })?;
        Ok(rows.collect::<std::result::Result<Vec<_>, _>>()?)
    }

    /// Reads the cached avatar hash & local file path for a paired peer.
    pub fn get_peer_profile(&self, node_id: &str) -> Result<Option<(String, Option<String>, Option<String>)>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.query_row(
            "SELECT display_name, avatar_hash, avatar_path FROM peers WHERE node_id = ?1",
            params![node_id],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
        )
        .optional()
        .map_err(Into::into)
    }

    /// Updates a paired peer's synced display name and/or avatar hash + local cache path.
    pub fn update_peer_profile(
        &self,
        node_id: &str,
        display_name: Option<&str>,
        avatar_hash: Option<Option<&str>>,
        avatar_path: Option<Option<&str>>,
    ) -> Result<()> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        if let Some(name) = display_name {
            let trimmed = name.trim();
            if !trimmed.is_empty() && !matches!(trimmed, "Paired Device" | "本机设备" | "local-device" | "ping") {
                conn.execute(
                    "UPDATE peers SET display_name = ?2, last_seen_ms = ?3 WHERE node_id = ?1",
                    params![node_id, trimmed, now],
                )?;
                conn.execute(
                    "UPDATE room_members SET display_name = ?2 WHERE node_id = ?1",
                    params![node_id, trimmed],
                )?;
            }
        }
        if let Some(hash_opt) = avatar_hash {
            conn.execute(
                "UPDATE peers SET avatar_hash = ?2, last_seen_ms = ?3 WHERE node_id = ?1",
                params![node_id, hash_opt, now],
            )?;
        }
        if let Some(path_opt) = avatar_path {
            conn.execute(
                "UPDATE peers SET avatar_path = ?2, last_seen_ms = ?3 WHERE node_id = ?1",
                params![node_id, path_opt, now],
            )?;
        }
        Ok(())
    }

    /// Saves serialized connection hints (LAN addrs + Iroh relay/direct addrs) for `node_id`.
    pub fn save_peer_hints(&self, node_id: &str, hints_json: &str) -> Result<()> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "UPDATE peers SET last_endpoint_json = ?2, last_seen_ms = ?3 WHERE node_id = ?1",
            params![node_id, hints_json, now],
        )?;
        Ok(())
    }

    /// Loads serialized connection hints for `node_id`, if any.
    pub fn get_peer_hints(&self, node_id: &str) -> Result<Option<String>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let val: Option<Option<String>> = conn
            .query_row(
                "SELECT last_endpoint_json FROM peers WHERE node_id = ?1",
                params![node_id],
                |row| row.get(0),
            )
            .optional()?;
        Ok(val.flatten())
    }

    /// Merges LAN/USB socket hints and optional `EndpointAddr` for `peer_id`.
    pub fn merge_peer_hints(
        &self,
        peer_id: &str,
        new_lan_addrs: &[String],
        new_endpoint_addr: Option<&iroh::EndpointAddr>,
    ) {
        let mut hints: PeerEndpointHints = self
            .get_peer_hints(peer_id)
            .ok()
            .flatten()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default();

        for a in new_lan_addrs.iter().rev() {
            if !a.is_empty() {
                hints.lan_addrs.retain(|existing| existing != a);
                hints.lan_addrs.insert(0, a.clone());
            }
        }
        hints.lan_addrs.sort_by_key(|s| {
            let parsed = s.parse::<std::net::SocketAddr>().ok();
            let is_usb = parsed.is_some_and(|sa| {
                crate::net::lan_bypass::is_usb_tether_adapter("", &sa.ip())
            });
            let is_ipv4 = parsed.is_some_and(|sa| sa.is_ipv4());
            (!is_usb, !is_ipv4)
        });
        hints.lan_addrs.truncate(8);
        if let Some(ep) = new_endpoint_addr {
            hints.endpoint_addr = Some(ep.clone());
        }
        if let Ok(json) = serde_json::to_string(&hints) {
            let _ = self.save_peer_hints(peer_id, &json);
        }
    }

    /// Loads persisted `EndpointAddr` and sorted LAN/USB socket hints for `peer_id`.
    pub fn load_peer_hints(
        &self,
        peer_id: &str,
    ) -> (Option<iroh::EndpointAddr>, Vec<std::net::SocketAddr>) {
        let Some(json) = self.get_peer_hints(peer_id).ok().flatten() else {
            return (None, Vec::new());
        };
        let Ok(hints) = serde_json::from_str::<PeerEndpointHints>(&json) else {
            return (None, Vec::new());
        };
        let mut addrs: Vec<std::net::SocketAddr> = hints
            .lan_addrs
            .iter()
            .filter_map(|s| s.parse().ok())
            .collect();
        addrs.sort_by_key(|a| !crate::net::lan_bypass::is_usb_tether_adapter("", &a.ip()));
        (hints.endpoint_addr, addrs)
    }

    // -------------------------------------------------------------------------
    // Multi-Room Management
    // -------------------------------------------------------------------------

    /// Migrates legacy `personal-default` room & peers into dedicated 1v1 `"dm"` rooms
    /// and purges any retired `home_node` entries.
    pub fn ensure_default_personal_room(
        &self,
        my_node_id: &str,
        my_name: &str,
    ) -> Result<Option<RoomRecord>> {
        if self.is_home_node_mode() {
            return Ok(None);
        }

        // 1. Purge retired `home_node` entries from room_members / peers / outbox.
        {
            let conn = self.conn.lock().expect("sqlite mutex poisoned");
            let mut hstmt = conn.prepare(
                "SELECT DISTINCT node_id FROM room_members WHERE role = 'home_node'",
            )?;
            let home_ids = hstmt
                .query_map([], |r| r.get::<_, String>(0))?
                .collect::<std::result::Result<Vec<_>, _>>()?;
            drop(hstmt);
            conn.execute("DELETE FROM room_members WHERE role = 'home_node'", [])?;
            for hid in home_ids {
                let still_member: bool = conn
                    .query_row(
                        "SELECT 1 FROM room_members WHERE node_id = ?1 LIMIT 1",
                        params![hid],
                        |_| Ok(()),
                    )
                    .optional()?
                    .is_some();
                if !still_member {
                    conn.execute("DELETE FROM peers WHERE node_id = ?1", params![hid])?;
                }
                conn.execute(
                    "DELETE FROM room_outbox_targets WHERE target_peer_id = ?1",
                    params![hid],
                )?;
            }
        }

        // 2. Migrate paired peers and legacy `personal-default` history into 1v1 DM rooms.
        let legacy_personal = self.get_room(DEFAULT_PERSONAL_ROOM_ID)?;
        let legacy_key = legacy_personal
            .as_ref()
            .and_then(|r| r.room_key_hex.clone());
        let legacy_members = if legacy_personal.is_some() {
            self.list_room_members(DEFAULT_PERSONAL_ROOM_ID)?
        } else {
            Vec::new()
        };

        let mut peer_map: std::collections::BTreeMap<String, String> =
            std::collections::BTreeMap::new();
        for p in self.list_peers()? {
            if p.node_id != my_node_id {
                peer_map.insert(p.node_id, p.display_name);
            }
        }
        for m in legacy_members {
            if m.node_id != my_node_id && m.role != "home_node" {
                peer_map.entry(m.node_id).or_insert(m.display_name);
            }
        }

        for (peer_id, peer_name) in &peer_map {
            let dm_room = self.ensure_dm_room(
                my_node_id,
                my_name,
                peer_id,
                peer_name,
                legacy_key.clone(),
            )?;
            let conn = self.conn.lock().expect("sqlite mutex poisoned");
            conn.execute(
                "UPDATE messages
                 SET room_id = ?1
                 WHERE room_id = ?2 AND (peer_id = ?3 OR sender_id = ?3)",
                params![dm_room.room_id, DEFAULT_PERSONAL_ROOM_ID, peer_id],
            )?;
            conn.execute(
                "UPDATE room_outbox_targets
                 SET room_id = ?1
                 WHERE room_id = ?2 AND target_peer_id = ?3",
                params![dm_room.room_id, DEFAULT_PERSONAL_ROOM_ID, peer_id],
            )?;
        }

        if peer_map.len() == 1
            && let Some((only_peer_id, _)) = peer_map.iter().next()
        {
            let dm_id = dm_room_id(my_node_id, only_peer_id);
            let conn = self.conn.lock().expect("sqlite mutex poisoned");
            conn.execute(
                "UPDATE messages SET room_id = ?1 WHERE room_id = ?2",
                params![dm_id, DEFAULT_PERSONAL_ROOM_ID],
            )?;
            conn.execute(
                "UPDATE room_outbox_targets SET room_id = ?1 WHERE room_id = ?2",
                params![dm_id, DEFAULT_PERSONAL_ROOM_ID],
            )?;
        }

        if legacy_personal.is_some() {
            let conn = self.conn.lock().expect("sqlite mutex poisoned");
            conn.execute(
                "DELETE FROM room_members WHERE room_id = ?1",
                params![DEFAULT_PERSONAL_ROOM_ID],
            )?;
            conn.execute(
                "DELETE FROM room_outbox_targets WHERE room_id = ?1",
                params![DEFAULT_PERSONAL_ROOM_ID],
            )?;
            conn.execute(
                "DELETE FROM rooms WHERE room_id = ?1",
                params![DEFAULT_PERSONAL_ROOM_ID],
            )?;
        }

        Ok(self.list_rooms()?.into_iter().next())
    }

    /// Creates or retrieves the canonical 1v1 `"dm"` room between `my_node_id` and `peer_id`.
    pub fn ensure_dm_room(
        &self,
        my_node_id: &str,
        my_name: &str,
        peer_id: &str,
        peer_name: &str,
        preferred_key_hex: Option<String>,
    ) -> Result<RoomRecord> {
        let clean_peer_name = if peer_name.trim().is_empty() {
            "对端设备".to_string()
        } else {
            peer_name.trim().to_string()
        };
        self.upsert_peer(peer_id, &clean_peer_name)?;

        let dm_id = dm_room_id(my_node_id, peer_id);
        let existing = self.get_room(&dm_id)?;
        let room = match existing {
            Some(mut r) => {
                if !clean_peer_name.is_empty() && clean_peer_name != "Paired Device" {
                    r.name = clean_peer_name.clone();
                }
                if r.room_key_hex.is_none() {
                    r.room_key_hex = preferred_key_hex
                        .or_else(|| Some(room_key_to_hex(&generate_room_key())));
                }
                r.room_type = "dm".to_string();
                r.is_pinned = true;
                self.upsert_room(&r)?;
                r
            }
            None => {
                let key_hex = preferred_key_hex
                    .filter(|k| !k.trim().is_empty())
                    .unwrap_or_else(|| room_key_to_hex(&generate_room_key()));
                let r = RoomRecord {
                    room_id: dm_id.clone(),
                    name: clean_peer_name.clone(),
                    room_type: "dm".to_string(),
                    room_key_hex: Some(key_hex),
                    is_pinned: true,
                    retention_days: self.get_retention_days(),
                    created_at_ms: now_millis(),
                };
                self.upsert_room(&r)?;
                r
            }
        };

        self.upsert_room_member(&dm_id, my_node_id, my_name, "member")?;
        self.upsert_room_member(&dm_id, peer_id, &clean_peer_name, "member")?;
        Ok(room)
    }

    /// Removes a paired device from Contacts, deletes its 1v1 DM room/history, and cleans all outbox rows.
    pub fn delete_peer_and_dm(&self, my_node_id: &str, peer_id: &str) -> Result<String> {
        let dm_id = dm_room_id(my_node_id, peer_id);
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "DELETE FROM room_outbox_targets WHERE target_peer_id = ?1 OR room_id = ?2",
            params![peer_id, dm_id],
        )?;
        conn.execute(
            "DELETE FROM room_members WHERE node_id = ?1 OR room_id = ?2",
            params![peer_id, dm_id],
        )?;
        conn.execute("DELETE FROM messages WHERE room_id = ?1", params![dm_id])?;
        conn.execute("DELETE FROM rooms WHERE room_id = ?1", params![dm_id])?;
        conn.execute("DELETE FROM peers WHERE node_id = ?1", params![peer_id])?;
        Ok(dm_id)
    }

    /// Deletes a room and all of its local messages, members, and outbox targets.
    pub fn delete_room(&self, room_id: &str) -> Result<()> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "DELETE FROM room_outbox_targets WHERE room_id = ?1",
            params![room_id],
        )?;
        conn.execute(
            "DELETE FROM room_members WHERE room_id = ?1",
            params![room_id],
        )?;
        conn.execute("DELETE FROM messages WHERE room_id = ?1", params![room_id])?;
        conn.execute("DELETE FROM rooms WHERE room_id = ?1", params![room_id])?;
        Ok(())
    }

    /// Removes `peer_id` from `room_id` and deletes its pending outbox targets in that room.
    pub fn remove_room_member(&self, room_id: &str, peer_id: &str) -> Result<()> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "DELETE FROM room_outbox_targets WHERE room_id = ?1 AND target_peer_id = ?2",
            params![room_id, peer_id],
        )?;
        conn.execute(
            "DELETE FROM room_members WHERE room_id = ?1 AND node_id = ?2",
            params![room_id, peer_id],
        )?;
        Ok(())
    }

    pub fn upsert_room(&self, room: &RoomRecord) -> Result<()> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "INSERT INTO rooms (room_id, name, room_type, room_key_hex, is_pinned, retention_days, created_at_ms)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
             ON CONFLICT(room_id) DO UPDATE SET
                 name = excluded.name,
                 room_type = excluded.room_type,
                 room_key_hex = COALESCE(excluded.room_key_hex, rooms.room_key_hex),
                 is_pinned = excluded.is_pinned,
                 retention_days = excluded.retention_days",
            params![
                room.room_id,
                room.name,
                room.room_type,
                room.room_key_hex,
                if room.is_pinned { 1i64 } else { 0i64 },
                room.retention_days as i64,
                room.created_at_ms,
            ],
        )?;
        Ok(())
    }

    pub fn get_room(&self, room_id: &str) -> Result<Option<RoomRecord>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let row = conn
            .query_row(
                "SELECT room_id, name, room_type, room_key_hex, is_pinned, retention_days, created_at_ms
                 FROM rooms WHERE room_id = ?1",
                params![room_id],
                map_room_row,
            )
            .optional()?;
        Ok(row)
    }

    /// Lists chat-capable rooms (excludes pure blind-locker rooms where `room_key_hex IS NULL`).
    pub fn list_rooms(&self) -> Result<Vec<RoomRecord>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT room_id, name, room_type, room_key_hex, is_pinned, retention_days, created_at_ms
             FROM rooms
             WHERE room_key_hex IS NOT NULL
             ORDER BY is_pinned DESC, created_at_ms ASC",
        )?;
        let rows = stmt.query_map([], map_room_row)?;
        Ok(rows.collect::<std::result::Result<Vec<_>, _>>()?)
    }

    /// Lists all rooms registered on this device (including blind-locker-only rooms).
    pub fn list_all_rooms(&self) -> Result<Vec<RoomRecord>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT room_id, name, room_type, room_key_hex, is_pinned, retention_days, created_at_ms
             FROM rooms
             ORDER BY is_pinned DESC, created_at_ms ASC",
        )?;
        let rows = stmt.query_map([], map_room_row)?;
        Ok(rows.collect::<std::result::Result<Vec<_>, _>>()?)
    }

    pub fn upsert_room_member(
        &self,
        room_id: &str,
        node_id: &str,
        display_name: &str,
        role: &str,
    ) -> Result<()> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "INSERT INTO room_members (room_id, node_id, display_name, role, joined_at_ms)
             VALUES (?1, ?2, ?3, ?4, ?5)
             ON CONFLICT(room_id, node_id) DO UPDATE SET
                 display_name = CASE
                     WHEN excluded.display_name != 'Paired Device' THEN excluded.display_name
                     ELSE room_members.display_name
                 END,
                 role = excluded.role",
            params![room_id, node_id, display_name, role, now],
        )?;
        Ok(())
    }

    pub fn list_room_members(&self, room_id: &str) -> Result<Vec<RoomMemberRecord>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT room_id, node_id, display_name, role, joined_at_ms
             FROM room_members
             WHERE room_id = ?1
             ORDER BY joined_at_ms ASC",
        )?;
        let rows = stmt.query_map(params![room_id], |row| {
            Ok(RoomMemberRecord {
                room_id: row.get(0)?,
                node_id: row.get(1)?,
                display_name: row.get(2)?,
                role: row.get(3)?,
                joined_at_ms: row.get(4)?,
            })
        })?;
        Ok(rows.collect::<std::result::Result<Vec<_>, _>>()?)
    }

    pub fn list_rooms_with_member(&self, peer_id: &str) -> Result<Vec<(RoomRecord, String)>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT r.room_id, r.name, r.room_type, r.room_key_hex, r.is_pinned, r.retention_days, r.created_at_ms, m.role
             FROM rooms r
             INNER JOIN room_members m ON r.room_id = m.room_id
             WHERE m.node_id = ?1
             ORDER BY r.is_pinned DESC, r.created_at_ms ASC",
        )?;
        let rows = stmt.query_map(params![peer_id], |row| {
            let room = map_room_row(row)?;
            let role: String = row.get(7)?;
            Ok((room, role))
        })?;
        Ok(rows.collect::<std::result::Result<Vec<_>, _>>()?)
    }

    pub fn is_authorized_room_member(&self, room_id: &str, node_id: &str) -> Result<bool> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let exists: Option<i64> = conn
            .query_row(
                "SELECT 1 FROM room_members WHERE room_id = ?1 AND node_id = ?2",
                params![room_id, node_id],
                |row| row.get(0),
            )
            .optional()?;
        Ok(exists.is_some())
    }

    // -------------------------------------------------------------------------
    // Messages & Per-Room Outbox
    // -------------------------------------------------------------------------

    /// Enqueues an outgoing text message (Phase 1 compatibility wrapper using `DEFAULT_PERSONAL_ROOM_ID`).
    pub fn enqueue_outgoing_text(
        &self,
        msg_id: &str,
        peer_id: &str,
        text: &str,
    ) -> Result<ChatMessageRecord> {
        self.enqueue_room_outgoing_text(
            msg_id,
            DEFAULT_PERSONAL_ROOM_ID,
            "",
            peer_id,
            text,
            &[peer_id.to_string()],
        )
    }

    /// Enqueues an outgoing file transfer (Phase 1 compatibility wrapper using `DEFAULT_PERSONAL_ROOM_ID`).
    #[allow(clippy::too_many_arguments)]
    pub fn enqueue_outgoing_file(
        &self,
        msg_id: &str,
        peer_id: &str,
        file_name: &str,
        file_size: u64,
        local_path: &str,
        root_blake3: &[u8; 32],
        chunk_size: usize,
        total_chunks: usize,
    ) -> Result<ChatMessageRecord> {
        self.enqueue_room_outgoing_file(
            msg_id,
            DEFAULT_PERSONAL_ROOM_ID,
            "",
            peer_id,
            file_name,
            file_size,
            local_path,
            root_blake3,
            chunk_size,
            total_chunks,
            &[peer_id.to_string()],
            None,
        )
    }

    /// Enqueues an outgoing encrypted room text message and its target recipients.
    pub fn enqueue_room_outgoing_text(
        &self,
        msg_id: &str,
        room_id: &str,
        sender_id: &str,
        primary_peer_id: &str,
        text: &str,
        target_peers: &[String],
    ) -> Result<ChatMessageRecord> {
        let now = now_millis();
        let record = ChatMessageRecord {
            msg_id: msg_id.to_string(),
            room_id: room_id.to_string(),
            peer_id: primary_peer_id.to_string(),
            sender_id: sender_id.to_string(),
            direction: MessageDirection::Outgoing,
            kind: MessageKind::Text,
            body_text: Some(text.to_string()),
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
            created_at_ms: now,
            updated_at_ms: now,
        };
        self.insert_message(&record)?;
        self.enqueue_room_outbox_targets(msg_id, room_id, target_peers)?;
        Ok(record)
    }

    /// Enqueues an outgoing encrypted room file transfer and its target recipients.
    #[allow(clippy::too_many_arguments)]
    pub fn enqueue_room_outgoing_file(
        &self,
        msg_id: &str,
        room_id: &str,
        sender_id: &str,
        primary_peer_id: &str,
        file_name: &str,
        file_size: u64,
        local_path: &str,
        root_blake3: &[u8; 32],
        chunk_size: usize,
        total_chunks: usize,
        target_peers: &[String],
        batch_id: Option<&str>,
    ) -> Result<ChatMessageRecord> {
        self.enqueue_room_outgoing_file_split_targets(
            msg_id,
            room_id,
            sender_id,
            primary_peer_id,
            file_name,
            file_size,
            local_path,
            root_blake3,
            chunk_size,
            total_chunks,
            target_peers,
            &[],
            batch_id,
        )
    }

    /// Enqueues an outgoing encrypted room file transfer, splitting online immediate targets
    /// from offline large-file targets that require explicit user confirmation before draining.
    #[allow(clippy::too_many_arguments)]
    pub fn enqueue_room_outgoing_file_split_targets(
        &self,
        msg_id: &str,
        room_id: &str,
        sender_id: &str,
        primary_peer_id: &str,
        file_name: &str,
        file_size: u64,
        local_path: &str,
        root_blake3: &[u8; 32],
        chunk_size: usize,
        total_chunks: usize,
        immediate_targets: &[String],
        awaiting_confirm_targets: &[String],
        batch_id: Option<&str>,
    ) -> Result<ChatMessageRecord> {
        let now = now_millis();
        let needs_confirm = !awaiting_confirm_targets.is_empty()
            || (immediate_targets.is_empty()
                && file_size >= LARGE_FILE_CONFIRM_THRESHOLD_BYTES);
        let delivery_scope = if needs_confirm {
            "awaiting_confirm".to_string()
        } else {
            "direct".to_string()
        };
        let record = ChatMessageRecord {
            msg_id: msg_id.to_string(),
            room_id: room_id.to_string(),
            peer_id: primary_peer_id.to_string(),
            sender_id: sender_id.to_string(),
            direction: MessageDirection::Outgoing,
            kind: MessageKind::File,
            body_text: None,
            file_name: Some(file_name.to_string()),
            file_size: Some(file_size),
            local_path: Some(local_path.to_string()),
            root_blake3: Some(root_blake3.to_vec()),
            chunk_size: Some(chunk_size),
            total_chunks: Some(total_chunks),
            received_bitmap: None,
            status: MessageStatus::QueuedOffline,
            delivery_scope,
            acked_peers: Vec::new(),
            batch_id: batch_id.map(str::to_string),
            created_at_ms: now,
            updated_at_ms: now,
        };
        self.insert_message(&record)?;
        self.enqueue_room_outbox_targets_with_status(msg_id, room_id, immediate_targets, "pending")?;
        self.enqueue_room_outbox_targets_with_status(
            msg_id,
            room_id,
            awaiting_confirm_targets,
            "awaiting_confirm",
        )?;
        Ok(record)
    }

    /// Enqueues a large group-chat file as a lightweight metadata offer (`offer_pending` -> `awaiting_pull`)
    /// so members see the file card and pull chunks only if they click Download.
    #[allow(clippy::too_many_arguments)]
    pub fn enqueue_room_outgoing_file_offer_only(
        &self,
        msg_id: &str,
        room_id: &str,
        sender_id: &str,
        primary_peer_id: &str,
        file_name: &str,
        file_size: u64,
        local_path: &str,
        root_blake3: &[u8; 32],
        chunk_size: usize,
        total_chunks: usize,
        target_peers: &[String],
        batch_id: Option<&str>,
    ) -> Result<ChatMessageRecord> {
        let now = now_millis();
        let record = ChatMessageRecord {
            msg_id: msg_id.to_string(),
            room_id: room_id.to_string(),
            peer_id: primary_peer_id.to_string(),
            sender_id: sender_id.to_string(),
            direction: MessageDirection::Outgoing,
            kind: MessageKind::File,
            body_text: None,
            file_name: Some(file_name.to_string()),
            file_size: Some(file_size),
            local_path: Some(local_path.to_string()),
            root_blake3: Some(root_blake3.to_vec()),
            chunk_size: Some(chunk_size),
            total_chunks: Some(total_chunks),
            received_bitmap: None,
            status: MessageStatus::QueuedOffline,
            delivery_scope: "group_offer".to_string(),
            acked_peers: Vec::new(),
            batch_id: batch_id.map(str::to_string),
            created_at_ms: now,
            updated_at_ms: now,
        };
        self.insert_message(&record)?;
        self.enqueue_room_outbox_targets_with_status(msg_id, room_id, target_peers, "offer_pending")?;
        Ok(record)
    }

    pub fn enqueue_room_outbox_targets(
        &self,
        msg_id: &str,
        room_id: &str,
        target_peers: &[String],
    ) -> Result<()> {
        self.enqueue_room_outbox_targets_with_status(msg_id, room_id, target_peers, "pending")
    }

    fn enqueue_room_outbox_targets_with_status(
        &self,
        msg_id: &str,
        room_id: &str,
        target_peers: &[String],
        initial_status: &str,
    ) -> Result<()> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        for target in target_peers {
            if target.trim().is_empty() {
                continue;
            }
            conn.execute(
                "INSERT OR IGNORE INTO room_outbox_targets (msg_id, room_id, target_peer_id, status, updated_at_ms)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                params![msg_id, room_id, target, initial_status, now],
            )?;
        }
        Ok(())
    }

    /// Promotes any `awaiting_confirm` targets of `msg_id` to `pending` so outbox drain starts.
    pub fn confirm_deferred_file_transfer(
        &self,
        msg_id: &str,
    ) -> Result<(ChatMessageRecord, Vec<String>)> {
        let now = now_millis();
        let existing = self.get_message(msg_id)?.context("message not found")?;
        {
            let conn = self.conn.lock().expect("sqlite mutex poisoned");
            conn.execute(
                "UPDATE room_outbox_targets
                 SET status = 'pending', updated_at_ms = ?2
                 WHERE msg_id = ?1 AND status = 'awaiting_confirm'",
                params![msg_id, now],
            )?;

            let target_count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM room_outbox_targets WHERE msg_id = ?1",
                params![msg_id],
                |r| r.get(0),
            )?;
            if target_count == 0 {
                let mut mstmt = conn.prepare(
                    "SELECT node_id FROM room_members
                     WHERE room_id = ?1 AND role != 'home_node' AND node_id != ?2",
                )?;
                let member_ids = mstmt
                    .query_map(params![existing.room_id, existing.sender_id], |r| {
                        r.get::<_, String>(0)
                    })?
                    .collect::<std::result::Result<Vec<_>, _>>()?;
                for peer_id in member_ids {
                    conn.execute(
                        "INSERT OR IGNORE INTO room_outbox_targets (msg_id, room_id, target_peer_id, status, updated_at_ms)
                         VALUES (?1, ?2, ?3, 'pending', ?4)",
                        params![msg_id, existing.room_id, peer_id, now],
                    )?;
                }
            }

            conn.execute(
                "UPDATE messages
                 SET delivery_scope = 'direct', updated_at_ms = ?2
                 WHERE msg_id = ?1 AND delivery_scope = 'awaiting_confirm'",
                params![msg_id, now],
            )?;
        }

        let pending_peers = {
            let conn = self.conn.lock().expect("sqlite mutex poisoned");
            let mut stmt = conn.prepare(
                "SELECT target_peer_id FROM room_outbox_targets
                 WHERE msg_id = ?1 AND status = 'pending'",
            )?;
            stmt.query_map(params![msg_id], |r| r.get::<_, String>(0))?
                .collect::<std::result::Result<Vec<_>, _>>()?
        };

        let updated = self.get_message(msg_id)?.context("message not found")?;
        Ok((updated, pending_peers))
    }

    /// Backfills outbox targets when a new member is discovered in an existing room.
    pub fn backfill_room_outbox_for_member(
        &self,
        room_id: &str,
        new_member_id: &str,
        local_node_id: &str,
    ) -> Result<()> {
        if new_member_id.trim().is_empty() || new_member_id == local_node_id {
            return Ok(());
        }
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT msg_id, kind, file_size FROM messages
             WHERE room_id = ?1
               AND direction = 'outgoing'
               AND status NOT IN ('delivered', 'failed_source_missing')",
        )?;
        let rows = stmt
            .query_map(params![room_id], |r| {
                Ok((
                    r.get::<_, String>(0)?,
                    r.get::<_, String>(1)?,
                    r.get::<_, Option<i64>>(2)?,
                ))
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        for (msg_id, kind, file_size_opt) in rows {
            let status = if kind == "file"
                && file_size_opt.unwrap_or(0).max(0) as u64 >= LARGE_FILE_CONFIRM_THRESHOLD_BYTES
            {
                "awaiting_confirm"
            } else {
                "pending"
            };
            conn.execute(
                "INSERT OR IGNORE INTO room_outbox_targets (msg_id, room_id, target_peer_id, status, updated_at_ms)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                params![msg_id, room_id, new_member_id, status, now],
            )?;
            if status == "awaiting_confirm" {
                conn.execute(
                    "UPDATE messages
                     SET delivery_scope = 'awaiting_confirm', updated_at_ms = ?2
                     WHERE msg_id = ?1 AND status != 'delivered'",
                    params![msg_id, now],
                )?;
            }
        }
        Ok(())
    }

    /// Updates a specific recipient's outbox status (`"pending"` | `"stored_on_home_node"` | `"delivered"`).
    /// Returns `true` if ALL targets for `msg_id` have now reached `'delivered'`.
    pub fn mark_outbox_target_status(
        &self,
        msg_id: &str,
        target_peer_id: &str,
        target_status: &str,
    ) -> Result<bool> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "UPDATE room_outbox_targets
             SET status = CASE
                 WHEN status = 'delivered' THEN 'delivered'
                 ELSE ?3
             END,
             updated_at_ms = ?4
             WHERE msg_id = ?1 AND target_peer_id = ?2",
            params![msg_id, target_peer_id, target_status, now],
        )?;

        let mut stmt = conn.prepare(
            "SELECT target_peer_id, status FROM room_outbox_targets WHERE msg_id = ?1",
        )?;
        let rows = stmt
            .query_map(params![msg_id], |r| {
                Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?))
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;

        if rows.is_empty() {
            return Ok(false);
        }

        let acked: Vec<String> = rows
            .iter()
            .filter(|(_, s)| s == "delivered")
            .map(|(p, _)| p.clone())
            .collect();
        let all_delivered = acked.len() == rows.len();
        let any_awaiting_confirm = rows.iter().any(|(_, s)| s == "awaiting_confirm");
        let any_group_offer = rows
            .iter()
            .any(|(_, s)| s == "offer_pending" || s == "awaiting_pull");
        let any_cached = rows.iter().any(|(_, s)| s == "stored_on_home_node");
        let acked_json = serde_json::to_string(&acked)?;

        let delivery_scope = if all_delivered {
            "delivered_all"
        } else if any_awaiting_confirm {
            "awaiting_confirm"
        } else if any_group_offer {
            "group_offer"
        } else if any_cached {
            "cached_on_home_node"
        } else {
            "direct"
        };

        if all_delivered {
            conn.execute(
                "UPDATE messages
                 SET status = 'delivered', delivery_scope = ?2, acked_peers_json = ?3, updated_at_ms = ?4
                 WHERE msg_id = ?1",
                params![msg_id, delivery_scope, acked_json, now],
            )?;
        } else {
            conn.execute(
                "UPDATE messages
                 SET delivery_scope = ?2, acked_peers_json = ?3, updated_at_ms = ?4
                 WHERE msg_id = ?1",
                params![msg_id, delivery_scope, acked_json, now],
            )?;
        }

        Ok(all_delivered)
    }

    /// Promotes a single requesting peer's outbox target (`offer_pending` / `awaiting_pull`)
    /// to `pending` when that peer clicks Download on a group large-file card.
    pub fn mark_outbox_target_pull_requested(
        &self,
        room_id: &str,
        msg_id: &str,
        peer_id: &str,
    ) -> Result<bool> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let changed = conn.execute(
            "UPDATE room_outbox_targets
             SET status = 'pending', updated_at_ms = ?4
             WHERE room_id = ?1 AND msg_id = ?2 AND target_peer_id = ?3 AND status != 'delivered'",
            params![room_id, msg_id, peer_id, now],
        )?;
        Ok(changed > 0)
    }

    pub fn mark_locker_upload_stored(
        &self,
        msg_id: &str,
        home_node_id: &str,
        target_peers: &[String],
    ) -> Result<()> {
        let now = now_millis();
        {
            let conn = self.conn.lock().expect("sqlite mutex poisoned");
            conn.execute(
                "INSERT INTO room_locker_uploads (msg_id, home_node_id, status, updated_at_ms)
                 VALUES (?1, ?2, 'stored', ?3)
                 ON CONFLICT(msg_id, home_node_id) DO UPDATE SET
                     status = 'stored',
                     updated_at_ms = excluded.updated_at_ms",
                params![msg_id, home_node_id, now],
            )?;
        }
        for target in target_peers {
            let _ = self.mark_outbox_target_status(msg_id, target, "stored_on_home_node");
        }
        Ok(())
    }

    /// Lists pending outgoing jobs for `peer_id` across all rooms (direct deliveries + Home Node locker uploads).
    pub fn list_pending_room_outbox_for_peer(&self, peer_id: &str) -> Result<Vec<PendingRoomOutboxJob>> {
        let rooms_for_peer = self.list_rooms_with_member(peer_id)?;
        let mut jobs = Vec::new();
        let mut seen_msg_ids = std::collections::HashSet::new();

        let conn = self.conn.lock().expect("sqlite mutex poisoned");

        // 1. Direct deliveries where `peer_id` is an intended recipient (`role` != `home_node`).
        for (room, role) in &rooms_for_peer {
            if role == "home_node" {
                continue;
            }
            let mut stmt = conn.prepare(
                "SELECT m.msg_id, m.peer_id, m.direction, m.kind, m.body_text, m.file_name, m.file_size,
                        m.local_path, m.root_blake3, m.chunk_size, m.total_chunks, m.received_bitmap,
                        m.status, m.created_at_ms, m.updated_at_ms, m.room_id, m.sender_id,
                        m.delivery_scope, m.acked_peers_json, m.batch_id, t.status
                 FROM messages m
                 INNER JOIN room_outbox_targets t ON m.msg_id = t.msg_id
                 WHERE m.room_id = ?1
                   AND m.direction = 'outgoing'
                   AND m.status NOT IN ('failed_source_missing', 'revoked')
                   AND t.target_peer_id = ?2
                   AND t.status IN ('pending', 'offer_pending')
                 ORDER BY m.created_at_ms ASC",
            )?;
            let rows = stmt.query_map(params![room.room_id, peer_id], |row| {
                let target_status: String = row.get(20)?;
                let msg = map_message_row(row)?;
                Ok(msg.map(|m| (m, target_status)))
            })?;
            for row in rows {
                let (msg, target_status) = row??;
                if seen_msg_ids.insert((msg.msg_id.clone(), false)) {
                    jobs.push(PendingRoomOutboxJob {
                        message: msg,
                        target_peers: vec![peer_id.to_string()],
                        store_in_locker: false,
                        offer_only: target_status == "offer_pending",
                    });
                }
            }
        }

        // 2. Blind locker uploads where `peer_id` acts as `home_node` for a room.
        for (room, role) in &rooms_for_peer {
            if role != "home_node" {
                continue;
            }
            let mut stmt = conn.prepare(
                "SELECT DISTINCT m.msg_id, m.peer_id, m.direction, m.kind, m.body_text, m.file_name, m.file_size,
                        m.local_path, m.root_blake3, m.chunk_size, m.total_chunks, m.received_bitmap,
                        m.status, m.created_at_ms, m.updated_at_ms, m.room_id, m.sender_id,
                        m.delivery_scope, m.acked_peers_json, m.batch_id
                 FROM messages m
                 INNER JOIN room_outbox_targets t ON m.msg_id = t.msg_id
                 LEFT JOIN room_locker_uploads u
                     ON m.msg_id = u.msg_id AND u.home_node_id = ?2
                 WHERE m.room_id = ?1
                   AND m.direction = 'outgoing'
                   AND m.status NOT IN ('failed_source_missing', 'revoked')
                   AND t.status = 'pending'
                   AND (u.status IS NULL OR u.status != 'stored')
                 ORDER BY m.created_at_ms ASC",
            )?;
            let rows = stmt.query_map(params![room.room_id, peer_id], map_message_row)?;
            for row in rows {
                let msg = row??;
                let mut tstmt = conn.prepare(
                    "SELECT target_peer_id FROM room_outbox_targets
                     WHERE msg_id = ?1 AND status != 'delivered'",
                )?;
                let target_peers = tstmt
                    .query_map(params![msg.msg_id], |r| r.get::<_, String>(0))?
                    .collect::<std::result::Result<Vec<_>, _>>()?;
                if !target_peers.is_empty() && seen_msg_ids.insert((msg.msg_id.clone(), true)) {
                    jobs.push(PendingRoomOutboxJob {
                        message: msg,
                        target_peers,
                        store_in_locker: true,
                        offer_only: false,
                    });
                }
            }
        }

        Ok(jobs)
    }

    /// Inserts or ignores an incoming message/file record (idempotent by `msg_id`).
    pub fn insert_message(&self, record: &ChatMessageRecord) -> Result<()> {
        let acked_json = serde_json::to_string(&record.acked_peers)?;
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "
            INSERT OR IGNORE INTO messages (
                msg_id, peer_id, direction, kind, body_text, file_name, file_size,
                local_path, root_blake3, chunk_size, total_chunks, received_bitmap,
                status, created_at_ms, updated_at_ms, room_id, sender_id, delivery_scope, acked_peers_json, batch_id
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20)
            ",
            params![
                record.msg_id,
                record.peer_id,
                record.direction.as_str(),
                record.kind.as_str(),
                record.body_text,
                record.file_name,
                record.file_size.map(|v| v as i64),
                record.local_path,
                record.root_blake3,
                record.chunk_size.map(|v| v as i64),
                record.total_chunks.map(|v| v as i64),
                record.received_bitmap,
                record.status.as_str(),
                record.created_at_ms,
                record.updated_at_ms,
                record.room_id,
                record.sender_id,
                record.delivery_scope,
                acked_json,
                record.batch_id,
            ],
        )?;
        Ok(())
    }

    /// Updates message status and optional local path / chunk bitmap.
    pub fn update_transfer_progress(
        &self,
        msg_id: &str,
        status: MessageStatus,
        received_bitmap: Option<&[u8]>,
        local_path: Option<&str>,
    ) -> Result<()> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "
            UPDATE messages SET
                status = ?2,
                received_bitmap = COALESCE(?3, received_bitmap),
                local_path = COALESCE(?4, local_path),
                updated_at_ms = ?5
            WHERE msg_id = ?1
            ",
            params![msg_id, status.as_str(), received_bitmap, local_path, now],
        )?;
        Ok(())
    }

    /// Updates only the `local_path` of a persisted message (e.g., after Android
    /// MediaStore export moves a file from app-private staging to `Download/P2PChat`).
    pub fn update_message_local_path(&self, msg_id: &str, local_path: &str) -> Result<bool> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let affected = conn.execute(
            "UPDATE messages SET local_path = ?2, updated_at_ms = ?3 WHERE msg_id = ?1",
            params![msg_id, local_path, now],
        )?;
        Ok(affected > 0)
    }

    /// Fetches a single message by `msg_id`.
    pub fn get_message(&self, msg_id: &str) -> Result<Option<ChatMessageRecord>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT msg_id, peer_id, direction, kind, body_text, file_name, file_size,
                    local_path, root_blake3, chunk_size, total_chunks, received_bitmap,
                    status, created_at_ms, updated_at_ms, room_id, sender_id,
                    delivery_scope, acked_peers_json, batch_id
             FROM messages WHERE msg_id = ?1",
        )?;
        let row = stmt.query_row(params![msg_id], map_message_row).optional()?;
        match row {
            Some(res) => Ok(Some(res?)),
            None => Ok(None),
        }
    }

    /// Returns all pending outgoing messages for `peer_id` in chronological order (Phase 1 compat).
    pub fn list_pending_outbox(&self, peer_id: &str) -> Result<Vec<ChatMessageRecord>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT msg_id, peer_id, direction, kind, body_text, file_name, file_size,
                    local_path, root_blake3, chunk_size, total_chunks, received_bitmap,
                    status, created_at_ms, updated_at_ms, room_id, sender_id,
                    delivery_scope, acked_peers_json, batch_id
             FROM messages
             WHERE peer_id = ?1
               AND direction = 'outgoing'
               AND status NOT IN ('delivered', 'failed_source_missing', 'revoked')
             ORDER BY created_at_ms ASC",
        )?;
        let rows = stmt.query_map(params![peer_id], map_message_row)?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row??);
        }
        Ok(out)
    }

    /// Returns the chat timeline for `peer_id` (Phase 1 compatibility).
    pub fn list_timeline(&self, peer_id: &str, limit: usize) -> Result<Vec<ChatMessageRecord>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT msg_id, peer_id, direction, kind, body_text, file_name, file_size,
                    local_path, root_blake3, chunk_size, total_chunks, received_bitmap,
                    status, created_at_ms, updated_at_ms, room_id, sender_id,
                    delivery_scope, acked_peers_json, batch_id
             FROM messages
             WHERE peer_id = ?1
             ORDER BY created_at_ms ASC
             LIMIT ?2",
        )?;
        let rows = stmt.query_map(params![peer_id, limit as i64], map_message_row)?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row??);
        }
        Ok(out)
    }

    /// Returns the newest `limit` decrypted messages for `room_id` in chronological ascending order.
    pub fn list_room_timeline(&self, room_id: &str, limit: usize) -> Result<Vec<ChatMessageRecord>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT msg_id, peer_id, direction, kind, body_text, file_name, file_size,
                    local_path, root_blake3, chunk_size, total_chunks, received_bitmap,
                    status, created_at_ms, updated_at_ms, room_id, sender_id,
                    delivery_scope, acked_peers_json, batch_id
             FROM (
                 SELECT msg_id, peer_id, direction, kind, body_text, file_name, file_size,
                        local_path, root_blake3, chunk_size, total_chunks, received_bitmap,
                        status, created_at_ms, updated_at_ms, room_id, sender_id,
                        delivery_scope, acked_peers_json, batch_id, rowid AS _ord_rowid
                 FROM messages
                 WHERE room_id = ?1
                 ORDER BY created_at_ms DESC, rowid DESC
                 LIMIT ?2
             )
             ORDER BY created_at_ms ASC, _ord_rowid ASC",
        )?;
        let rows = stmt.query_map(params![room_id, limit as i64], map_message_row)?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row??);
        }
        Ok(out)
    }

    /// Returns the newest `limit` file/image messages (optionally filtered by `room_id`) in descending order.
    pub fn list_media_messages(
        &self,
        room_id: Option<&str>,
        limit: usize,
    ) -> Result<Vec<ChatMessageRecord>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT msg_id, peer_id, direction, kind, body_text, file_name, file_size,
                    local_path, root_blake3, chunk_size, total_chunks, received_bitmap,
                    status, created_at_ms, updated_at_ms, room_id, sender_id,
                    delivery_scope, acked_peers_json, batch_id
             FROM messages
             WHERE kind = 'file'
               AND status != 'revoked'
               AND (?1 IS NULL OR room_id = ?1)
             ORDER BY created_at_ms DESC, rowid DESC
             LIMIT ?2",
        )?;
        let rows = stmt.query_map(params![room_id, limit as i64], map_message_row)?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row??);
        }
        Ok(out)
    }

    // -------------------------------------------------------------------------
    // Blind Locker State Machine (Zero-Knowledge Home Node Cache & ACK Purge)
    // -------------------------------------------------------------------------

    /// Inserts or resumes a blind locker cache item and populates the per-recipient ACK checklist.
    /// Returns the current `received_bitmap` and status (`"receiving"` | `"ready"` | `"purged"`).
    pub fn upsert_blind_locker_offer(
        &self,
        item: &BlindLockerItem,
        target_peers: &[String],
    ) -> Result<(Vec<u8>, String)> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let existing: Option<(Option<Vec<u8>>, String)> = conn
            .query_row(
                "SELECT received_bitmap, status FROM blind_locker_items WHERE msg_id = ?1",
                params![item.msg_id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()?;

        if let Some((bitmap_opt, status)) = existing {
            for target in target_peers {
                conn.execute(
                    "INSERT OR IGNORE INTO blind_locker_acks (msg_id, room_id, target_peer_id, acked_at_ms)
                     VALUES (?1, ?2, ?3, NULL)",
                    params![item.msg_id, item.room_id, target],
                )?;
            }
            return Ok((bitmap_opt.unwrap_or_default(), status));
        }

        conn.execute(
            "INSERT INTO blind_locker_items (
                msg_id, room_id, sender_id, envelope_json, cipher_file_path,
                cipher_file_size, cipher_root_blake3, chunk_size, total_chunks,
                cipher_chunk_hashes_json, received_bitmap, status, created_at_ms, expires_at_ms
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)",
            params![
                item.msg_id,
                item.room_id,
                item.sender_id,
                item.envelope_json,
                item.cipher_file_path,
                item.cipher_file_size as i64,
                item.cipher_root_blake3,
                item.chunk_size as i64,
                item.total_chunks as i64,
                item.cipher_chunk_hashes_json,
                item.received_bitmap,
                item.status,
                item.created_at_ms,
                item.expires_at_ms,
            ],
        )?;

        for target in target_peers {
            conn.execute(
                "INSERT OR IGNORE INTO blind_locker_acks (msg_id, room_id, target_peer_id, acked_at_ms)
                 VALUES (?1, ?2, ?3, NULL)",
                params![item.msg_id, item.room_id, target],
            )?;
        }

        Ok((
            item.received_bitmap.clone().unwrap_or_default(),
            item.status.clone(),
        ))
    }

    pub fn update_blind_locker_bitmap(
        &self,
        msg_id: &str,
        bitmap: &[u8],
        status: &str,
        cipher_file_path: Option<&str>,
    ) -> Result<()> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "UPDATE blind_locker_items
             SET received_bitmap = ?2,
                 status = ?3,
                 cipher_file_path = COALESCE(?4, cipher_file_path)
             WHERE msg_id = ?1",
            params![msg_id, bitmap, status, cipher_file_path],
        )?;
        Ok(())
    }

    pub fn get_blind_locker_item(&self, msg_id: &str) -> Result<Option<BlindLockerItem>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let item = conn
            .query_row(
                "SELECT msg_id, room_id, sender_id, envelope_json, cipher_file_path,
                        cipher_file_size, cipher_root_blake3, chunk_size, total_chunks,
                        cipher_chunk_hashes_json, received_bitmap, status, created_at_ms, expires_at_ms
                 FROM blind_locker_items WHERE msg_id = ?1",
                params![msg_id],
                map_blind_locker_row,
            )
            .optional()?;
        Ok(item)
    }

    /// Lists all `ready` blind locker packages waiting to be picked up by `target_peer_id`.
    pub fn list_ready_locker_items_for_peer(
        &self,
        target_peer_id: &str,
    ) -> Result<Vec<(BlindLockerItem, Vec<String>)>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT i.msg_id, i.room_id, i.sender_id, i.envelope_json, i.cipher_file_path,
                    i.cipher_file_size, i.cipher_root_blake3, i.chunk_size, i.total_chunks,
                    i.cipher_chunk_hashes_json, i.received_bitmap, i.status, i.created_at_ms, i.expires_at_ms
             FROM blind_locker_items i
             INNER JOIN blind_locker_acks a ON i.msg_id = a.msg_id
             WHERE a.target_peer_id = ?1
               AND a.acked_at_ms IS NULL
               AND i.status = 'ready'
             ORDER BY i.created_at_ms ASC",
        )?;
        let items = stmt
            .query_map(params![target_peer_id], map_blind_locker_row)?
            .collect::<std::result::Result<Vec<_>, _>>()?;

        let mut out = Vec::with_capacity(items.len());
        for item in items {
            let mut pstmt = conn.prepare(
                "SELECT target_peer_id FROM blind_locker_acks WHERE msg_id = ?1 AND acked_at_ms IS NULL",
            )?;
            let pending_targets = pstmt
                .query_map(params![item.msg_id], |r| r.get::<_, String>(0))?
                .collect::<std::result::Result<Vec<_>, _>>()?;
            out.push((item, pending_targets));
        }
        Ok(out)
    }

    /// Records a signed `RecipientDeliveryAck` for `(msg_id, recipient_peer_id)`.
    /// When the remaining un-ACKed target count reaches **0**, immediately transitions the item
    /// to `'purged'` and returns `Some(cipher_file_path)` so the caller deletes the `.enc` file from disk.
    pub fn ack_blind_locker_recipient(
        &self,
        msg_id: &str,
        recipient_peer_id: &str,
        signature_bytes: Option<&[u8]>,
    ) -> Result<(bool, Option<String>)> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "UPDATE blind_locker_acks
             SET acked_at_ms = COALESCE(acked_at_ms, ?3),
                 signature_bytes = COALESCE(?4, signature_bytes)
             WHERE msg_id = ?1 AND target_peer_id = ?2",
            params![msg_id, recipient_peer_id, now, signature_bytes],
        )?;

        let remaining: i64 = conn.query_row(
            "SELECT COUNT(*) FROM blind_locker_acks WHERE msg_id = ?1 AND acked_at_ms IS NULL",
            params![msg_id],
            |row| row.get(0),
        )?;

        if remaining == 0 {
            let path_opt: Option<Option<String>> = conn
                .query_row(
                    "SELECT cipher_file_path FROM blind_locker_items WHERE msg_id = ?1 AND status != 'purged'",
                    params![msg_id],
                    |row| row.get(0),
                )
                .optional()?;

            conn.execute(
                "UPDATE blind_locker_items SET status = 'purged', cipher_file_path = NULL WHERE msg_id = ?1",
                params![msg_id],
            )?;
            return Ok((true, path_opt.flatten()));
        }

        Ok((false, None))
    }

    /// Lists signed delivery ACKs that have not yet been forwarded back to `sender_id`.
    pub fn list_unforwarded_locker_acks_for_sender(
        &self,
        sender_id: &str,
    ) -> Result<Vec<UnforwardedLockerAck>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT a.msg_id, a.room_id, i.sender_id, a.target_peer_id, a.signature_bytes
             FROM blind_locker_acks a
             INNER JOIN blind_locker_items i ON a.msg_id = i.msg_id
             WHERE i.sender_id = ?1
               AND a.acked_at_ms IS NOT NULL
               AND a.forwarded_to_sender = 0
               AND a.signature_bytes IS NOT NULL",
        )?;
        let rows = stmt.query_map(params![sender_id], |row| {
            Ok(UnforwardedLockerAck {
                msg_id: row.get(0)?,
                room_id: row.get(1)?,
                sender_id: row.get(2)?,
                target_peer_id: row.get(3)?,
                signature_bytes: row.get(4)?,
            })
        })?;
        Ok(rows.collect::<std::result::Result<Vec<_>, _>>()?)
    }

    pub fn mark_locker_ack_forwarded(&self, msg_id: &str, target_peer_id: &str) -> Result<()> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "UPDATE blind_locker_acks SET forwarded_to_sender = 1
             WHERE msg_id = ?1 AND target_peer_id = ?2",
            params![msg_id, target_peer_id],
        )?;
        Ok(())
    }

    /// Finds expired blind locker items (`expires_at_ms <= now`), marks them `'expired'`,
    /// and returns all `.enc` file paths to delete from disk.
    pub fn purge_expired_locker_items(&self) -> Result<Vec<String>> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT msg_id, cipher_file_path FROM blind_locker_items
             WHERE status IN ('receiving', 'ready') AND expires_at_ms <= ?1",
        )?;
        let expired: Vec<(String, Option<String>)> = stmt
            .query_map(params![now], |row| Ok((row.get(0)?, row.get(1)?)))?
            .collect::<std::result::Result<Vec<_>, _>>()?;

        let mut paths = Vec::new();
        for (msg_id, path_opt) in expired {
            if let Some(p) = path_opt {
                paths.push(p);
            }
            conn.execute(
                "UPDATE blind_locker_items SET status = 'expired', cipher_file_path = NULL WHERE msg_id = ?1",
                params![msg_id],
            )?;
        }
        Ok(paths)
    }

    /// Returns zero-knowledge aggregate statistics for the Home Node blind locker.
    pub fn get_home_node_stats(&self) -> Result<HomeNodeStats> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let (active_count, active_bytes): (i64, i64) = conn.query_row(
            "SELECT COUNT(*), COALESCE(SUM(cipher_file_size), 0)
             FROM blind_locker_items
             WHERE status IN ('receiving', 'ready')",
            [],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )?;
        let purged_count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM blind_locker_items WHERE status IN ('purged', 'expired')",
            [],
            |row| row.get(0),
        )?;
        let rooms_count: i64 = conn.query_row(
            "SELECT COUNT(DISTINCT room_id) FROM rooms",
            [],
            |row| row.get(0),
        )?;
        let pending_ack_links: i64 = conn.query_row(
            "SELECT COUNT(*) FROM blind_locker_acks WHERE acked_at_ms IS NULL",
            [],
            |row| row.get(0),
        )?;

        Ok(HomeNodeStats {
            active_cached_count: active_count.max(0) as u32,
            active_cached_bytes: active_bytes.max(0) as u64,
            total_purged_count: purged_count.max(0) as u32,
            registered_rooms_count: rooms_count.max(0) as u32,
            pending_ack_links: pending_ack_links.max(0) as u32,
        })
    }

    /// Returns the current local `YYYY-MM` folder name (e.g. `"2026-11"`).
    pub fn local_year_month(&self) -> String {
        let conn = self.conn.lock().expect("sqlite lock poisoned");
        conn.query_row("SELECT strftime('%Y-%m', 'now', 'localtime')", [], |row| {
            row.get::<_, String>(0)
        })
        .ok()
        .filter(|s| s.len() == 7 && s.as_bytes()[4] == b'-')
        .unwrap_or_else(|| "unknown-month".to_string())
    }

    // -------------------------------------------------------------------------
    // Local Delete & WhatsApp-Style Signed Revoke / Recall
    // -------------------------------------------------------------------------

    /// Deletes a single message from local SQLite history (`Delete for me`).
    ///
    /// Safety invariant: when `record.direction == Outgoing`, this NEVER touches
    /// the local source file at `record.local_path` regardless of `delete_received_file`.
    /// Only incoming received copies inside the receive directory may be unlinked.
    pub fn delete_message_for_me(
        &self,
        msg_id: &str,
        delete_received_file: bool,
    ) -> Result<Option<String>> {
        let Some(record) = self.get_message(msg_id)? else {
            return Ok(None);
        };

        if delete_received_file && record.direction == MessageDirection::Incoming {
            if let Some(ref raw_path) = record.local_path {
                let trimmed = raw_path.trim();
                if !trimmed.is_empty() {
                    let p = std::path::Path::new(trimmed);
                    if p.exists() && p.is_file() {
                        let _ = std::fs::remove_file(p);
                    }
                }
            }
        }

        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute("DELETE FROM room_outbox_targets WHERE msg_id = ?1", params![msg_id])?;
        conn.execute("DELETE FROM pending_room_revokes WHERE msg_id = ?1", params![msg_id])?;
        conn.execute("DELETE FROM messages WHERE msg_id = ?1", params![msg_id])?;
        Ok(Some(record.room_id))
    }

    /// Applies an authorized WhatsApp-style revoke tombstone (`status = 'revoked'`).
    ///
    /// - For incoming messages (receiver side): deletes the downloaded local file if
    ///   `allow_delete_received_file` is true and scrubs message payload columns.
    /// - For outgoing messages (sender side): NEVER touches the sender's source file on disk;
    ///   scrubs DB metadata into a revoked tombstone and clears pending outbox sends.
    pub fn apply_revoke_to_local_message(
        &self,
        msg_id: &str,
        revoker_id: &str,
        expected_room_id: Option<&str>,
        allow_delete_received_file: bool,
    ) -> Result<Option<ChatMessageRecord>> {
        let now = now_millis();
        let existing = self.get_message(msg_id)?;

        if let Some(ref record) = existing {
            if let Some(expected_rid) = expected_room_id
                && record.room_id != expected_rid
            {
                anyhow::bail!(
                    "room_id mismatch in revoke for {msg_id}: expected {}, got {}",
                    record.room_id,
                    expected_rid
                );
            }
            let authorized = match record.direction {
                MessageDirection::Outgoing => {
                    record.sender_id == revoker_id || record.sender_id.is_empty()
                }
                MessageDirection::Incoming => {
                    record.sender_id == revoker_id
                        || (record.sender_id.is_empty() && record.peer_id == revoker_id)
                }
            };
            if !authorized {
                anyhow::bail!("unauthorized revoke sender {revoker_id} for message {msg_id}");
            }

            if allow_delete_received_file && record.direction == MessageDirection::Incoming {
                if let Some(ref raw_path) = record.local_path {
                    let trimmed = raw_path.trim();
                    if !trimmed.is_empty() {
                        let p = std::path::Path::new(trimmed);
                        if p.exists() && p.is_file() {
                            let _ = std::fs::remove_file(p);
                        }
                    }
                }
            }

            {
                let conn = self.conn.lock().expect("sqlite mutex poisoned");
                conn.execute(
                    "UPDATE messages
                     SET body_text = NULL,
                         file_name = NULL,
                         file_size = NULL,
                         local_path = NULL,
                         root_blake3 = NULL,
                         chunk_size = NULL,
                         total_chunks = NULL,
                         received_bitmap = NULL,
                         status = 'revoked',
                         delivery_scope = 'revoked',
                         updated_at_ms = ?2
                     WHERE msg_id = ?1",
                    params![msg_id, now],
                )?;
                conn.execute(
                    "DELETE FROM room_outbox_targets WHERE msg_id = ?1",
                    params![msg_id],
                )?;
                conn.execute(
                    "INSERT OR IGNORE INTO revoked_message_tombstones (msg_id, room_id, sender_id, revoked_at_ms)
                     VALUES (?1, ?2, ?3, ?4)",
                    params![msg_id, record.room_id, revoker_id, now],
                )?;
            }
            return self.get_message(msg_id);
        }

        if let Some(rid) = expected_room_id {
            let conn = self.conn.lock().expect("sqlite mutex poisoned");
            conn.execute(
                "INSERT OR IGNORE INTO revoked_message_tombstones (msg_id, room_id, sender_id, revoked_at_ms)
                 VALUES (?1, ?2, ?3, ?4)",
                params![msg_id, rid, revoker_id, now],
            )?;
        }
        Ok(None)
    }

    pub fn is_message_revoked_by(&self, msg_id: &str) -> Result<Option<String>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let sender: Option<String> = conn
            .query_row(
                "SELECT sender_id FROM revoked_message_tombstones WHERE msg_id = ?1",
                params![msg_id],
                |row| row.get(0),
            )
            .optional()?;
        Ok(sender)
    }

    /// Purges a Home Node blind-locker ciphertext item upon receiving a signed `RoomMessageRevoke`.
    /// Returns the list of un-ACKed target peers that still had a pending entry (if any).
    pub fn purge_blind_locker_by_revoke(
        &self,
        room_id: &str,
        msg_id: &str,
        sender_id: &str,
    ) -> Result<Vec<String>> {
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "INSERT OR IGNORE INTO revoked_message_tombstones (msg_id, room_id, sender_id, revoked_at_ms)
             VALUES (?1, ?2, ?3, ?4)",
            params![msg_id, room_id, sender_id, now],
        )?;

        let existing: Option<(String, Option<String>)> = conn
            .query_row(
                "SELECT sender_id, cipher_file_path FROM blind_locker_items WHERE msg_id = ?1",
                params![msg_id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()?;

        let mut remaining_targets = Vec::new();
        if let Some((stored_sender, path_opt)) = existing {
            if stored_sender != sender_id {
                anyhow::bail!("unauthorized blind locker revoke by {sender_id} for {msg_id}");
            }
            if let Some(path) = path_opt {
                let p = std::path::Path::new(path.trim());
                if p.exists() {
                    let _ = std::fs::remove_file(p);
                }
            }
            let mut stmt = conn.prepare(
                "SELECT target_peer_id FROM blind_locker_acks WHERE msg_id = ?1",
            )?;
            let rows = stmt.query_map(params![msg_id], |r| r.get::<_, String>(0))?;
            for row in rows {
                remaining_targets.push(row?);
            }
            conn.execute(
                "UPDATE blind_locker_items
                 SET status = 'purged',
                     envelope_json = '{}',
                     cipher_file_path = NULL
                 WHERE msg_id = ?1",
                params![msg_id],
            )?;
            conn.execute(
                "DELETE FROM blind_locker_acks WHERE msg_id = ?1",
                params![msg_id],
            )?;
        }

        Ok(remaining_targets)
    }

    pub fn enqueue_pending_room_revoke(
        &self,
        room_id: &str,
        msg_id: &str,
        sender_id: &str,
        target_peer_id: &str,
        store_in_locker: bool,
        target_peers: &[String],
        signature_bytes: &[u8],
    ) -> Result<()> {
        let revoke_id = format!("{msg_id}:{target_peer_id}:{}", if store_in_locker { 1 } else { 0 });
        let target_peers_json = serde_json::to_string(target_peers)?;
        let now = now_millis();
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "INSERT OR REPLACE INTO pending_room_revokes (
                revoke_id, room_id, msg_id, sender_id, target_peer_id,
                store_in_locker, target_peers_json, signature_bytes, delivered, created_at_ms
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 0, ?9)",
            params![
                revoke_id,
                room_id,
                msg_id,
                sender_id,
                target_peer_id,
                if store_in_locker { 1i64 } else { 0i64 },
                target_peers_json,
                signature_bytes,
                now,
            ],
        )?;
        Ok(())
    }

    pub fn list_pending_room_revokes_for_peer(&self, peer_id: &str) -> Result<Vec<PendingRoomRevoke>> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        let mut stmt = conn.prepare(
            "SELECT revoke_id, room_id, msg_id, sender_id, target_peer_id,
                    store_in_locker, target_peers_json, signature_bytes, created_at_ms
             FROM pending_room_revokes
             WHERE target_peer_id = ?1 AND delivered = 0
             ORDER BY created_at_ms ASC",
        )?;
        let rows = stmt.query_map(params![peer_id], |row| {
            let locker_int: i64 = row.get(5)?;
            let targets_json: String = row.get(6)?;
            let target_peers: Vec<String> = serde_json::from_str(&targets_json).unwrap_or_default();
            Ok(PendingRoomRevoke {
                revoke_id: row.get(0)?,
                room_id: row.get(1)?,
                msg_id: row.get(2)?,
                sender_id: row.get(3)?,
                target_peer_id: row.get(4)?,
                store_in_locker: locker_int != 0,
                target_peers,
                signature_bytes: row.get(7)?,
                created_at_ms: row.get(8)?,
            })
        })?;
        let mut out = Vec::new();
        for r in rows {
            out.push(r?);
        }
        Ok(out)
    }

    pub fn mark_pending_room_revoke_delivered(&self, revoke_id: &str) -> Result<()> {
        let conn = self.conn.lock().expect("sqlite mutex poisoned");
        conn.execute(
            "UPDATE pending_room_revokes SET delivered = 1 WHERE revoke_id = ?1",
            params![revoke_id],
        )?;
        Ok(())
    }
}

fn map_room_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<RoomRecord> {
    Ok(RoomRecord {
        room_id: row.get(0)?,
        name: row.get(1)?,
        room_type: row.get(2)?,
        room_key_hex: row.get(3)?,
        is_pinned: row.get::<_, i64>(4)? != 0,
        retention_days: (row.get::<_, i64>(5)?).max(1) as u32,
        created_at_ms: row.get(6)?,
    })
}

fn map_blind_locker_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<BlindLockerItem> {
    Ok(BlindLockerItem {
        msg_id: row.get(0)?,
        room_id: row.get(1)?,
        sender_id: row.get(2)?,
        envelope_json: row.get(3)?,
        cipher_file_path: row.get(4)?,
        cipher_file_size: row.get::<_, i64>(5)?.max(0) as u64,
        cipher_root_blake3: row.get(6)?,
        chunk_size: row.get::<_, i64>(7)?.max(0) as usize,
        total_chunks: row.get::<_, i64>(8)?.max(0) as usize,
        cipher_chunk_hashes_json: row.get(9)?,
        received_bitmap: row.get(10)?,
        status: row.get(11)?,
        created_at_ms: row.get(12)?,
        expires_at_ms: row.get(13)?,
    })
}

fn map_message_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<Result<ChatMessageRecord>> {
    let dir_str: String = row.get(2)?;
    let kind_str: String = row.get(3)?;
    let status_str: String = row.get(12)?;
    let room_id: String = row.get(15)?;
    let sender_id: String = row.get(16)?;
    let delivery_scope: String = row.get(17)?;
    let acked_json: String = row.get(18)?;
    let acked_peers: Vec<String> = serde_json::from_str(&acked_json).unwrap_or_default();
    let batch_id: Option<String> = row.get(19)?;

    let parsed = (|| -> Result<ChatMessageRecord> {
        Ok(ChatMessageRecord {
            msg_id: row.get(0)?,
            peer_id: row.get(1)?,
            room_id,
            sender_id,
            direction: MessageDirection::from_str(&dir_str)?,
            kind: MessageKind::from_str(&kind_str)?,
            body_text: row.get(4)?,
            file_name: row.get(5)?,
            file_size: row.get::<_, Option<i64>>(6)?.map(|v| v as u64),
            local_path: row.get(7)?,
            root_blake3: row.get(8)?,
            chunk_size: row.get::<_, Option<i64>>(9)?.map(|v| v as usize),
            total_chunks: row.get::<_, Option<i64>>(10)?.map(|v| v as usize),
            received_bitmap: row.get(11)?,
            status: MessageStatus::from_str(&status_str)?,
            delivery_scope,
            acked_peers,
            batch_id,
            created_at_ms: row.get(13)?,
            updated_at_ms: row.get(14)?,
        })
    })();

    Ok(parsed)
}

/// Current UNIX epoch timestamp in milliseconds.
pub fn now_millis() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn outbox_and_timeline_persistence() -> Result<()> {
        let db_path = std::env::temp_dir().join(format!("p2p_store_test_{}.db", std::process::id()));
        let _ = std::fs::remove_file(&db_path);

        let store = LocalStore::open(&db_path)?;
        store.upsert_peer("peer-abc", "Windows Desktop")?;
        assert_eq!(store.list_peers()?.len(), 1);

        let room = store.ensure_default_personal_room("me-123", "My Phone")?;
        assert!(room.is_some());
        assert_eq!(store.list_rooms()?.len(), 1);

        store.enqueue_outgoing_text("msg-1", "peer-abc", "hello offline")?;
        assert_eq!(store.list_pending_outbox("peer-abc")?.len(), 1);

        store.update_transfer_progress("msg-1", MessageStatus::Delivered, None, None)?;
        assert_eq!(store.list_pending_outbox("peer-abc")?.len(), 0);
        assert_eq!(store.list_timeline("peer-abc", 50)?.len(), 1);

        drop(store);
        let _ = std::fs::remove_file(&db_path);
        Ok(())
    }

    #[test]
    fn blind_locker_reference_counted_ack_triggers_purge() -> Result<()> {
        let db_path =
            std::env::temp_dir().join(format!("p2p_locker_store_test_{}.db", std::process::id()));
        let _ = std::fs::remove_file(&db_path);

        let store = LocalStore::open(&db_path)?;
        let item = BlindLockerItem {
            msg_id: "msg-blind-1".to_string(),
            room_id: "room-friends".to_string(),
            sender_id: "alice".to_string(),
            envelope_json: "{}".to_string(),
            cipher_file_path: Some("/tmp/locker/msg-blind-1.enc".to_string()),
            cipher_file_size: 4096,
            cipher_root_blake3: Some(vec![7u8; 32]),
            chunk_size: 512 * 1024,
            total_chunks: 1,
            cipher_chunk_hashes_json: None,
            received_bitmap: Some(vec![0x01]),
            status: "ready".to_string(),
            created_at_ms: now_millis(),
            expires_at_ms: now_millis() + 86_400_000,
        };

        store.upsert_blind_locker_offer(&item, &["bob".to_string(), "carol".to_string()])?;
        assert_eq!(store.list_ready_locker_items_for_peer("bob")?.len(), 1);
        assert_eq!(store.list_ready_locker_items_for_peer("carol")?.len(), 1);

        // First recipient ACKs -> still 1 pending, MUST NOT purge yet.
        let (purged_1, path_1) = store.ack_blind_locker_recipient("msg-blind-1", "bob", Some(b"sig1"))?;
        assert!(!purged_1);
        assert!(path_1.is_none());
        assert_eq!(store.list_ready_locker_items_for_peer("bob")?.len(), 0);
        assert_eq!(store.list_ready_locker_items_for_peer("carol")?.len(), 1);

        // Last recipient ACKs -> count reaches 0 -> MUST immediately purge and return file path!
        let (purged_2, path_2) =
            store.ack_blind_locker_recipient("msg-blind-1", "carol", Some(b"sig2"))?;
        assert!(purged_2);
        assert_eq!(path_2.as_deref(), Some("/tmp/locker/msg-blind-1.enc"));

        let stats = store.get_home_node_stats()?;
        assert_eq!(stats.active_cached_count, 0);
        assert_eq!(stats.total_purged_count, 1);

        drop(store);
        let _ = std::fs::remove_file(&db_path);
        Ok(())
    }

    #[test]
    fn large_file_deferred_transfer_requires_confirmation() -> Result<()> {
        let db_path = std::env::temp_dir().join(format!(
            "p2p_large_confirm_test_{}.db",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&db_path);

        let store = LocalStore::open(&db_path)?;
        store.upsert_peer("peer-online", "PC")?;
        store.upsert_peer("peer-offline", "Phone")?;
        let test_room = "room-large-test";
        store.upsert_room(&RoomRecord {
            room_id: test_room.to_string(),
            name: "Test".to_string(),
            room_type: "group".to_string(),
            room_key_hex: Some(room_key_to_hex(&generate_room_key())),
            is_pinned: false,
            retention_days: 7,
            created_at_ms: now_millis(),
        })?;
        store.upsert_room_member(test_room, "me-node", "Me", "owner")?;
        store.upsert_room_member(test_room, "peer-online", "PC", "member")?;
        store.upsert_room_member(test_room, "peer-offline", "Phone", "member")?;

        let root = [9u8; 32];
        let rec = store.enqueue_room_outgoing_file_split_targets(
            "msg-big-1",
            test_room,
            "me-node",
            "peer-online",
            "movie.mp4",
            LARGE_FILE_CONFIRM_THRESHOLD_BYTES + 1024,
            "/tmp/movie.mp4",
            &root,
            512 * 1024,
            105,
            &["peer-online".to_string()],
            &["peer-offline".to_string()],
            Some("batch-movie-test"),
        )?;
        assert_eq!(rec.delivery_scope, "awaiting_confirm");
        assert_eq!(rec.batch_id.as_deref(), Some("batch-movie-test"));

        // Online peer receives immediately; offline peer does NOT auto-drain until confirmed.
        assert_eq!(
            store.list_pending_room_outbox_for_peer("peer-online")?.len(),
            1
        );
        assert_eq!(
            store.list_pending_room_outbox_for_peer("peer-offline")?.len(),
            0
        );

        // Once online peer finishes delivery, message still remains awaiting_confirm for offline peer.
        let all_done = store.mark_outbox_target_status("msg-big-1", "peer-online", "delivered")?;
        assert!(!all_done);
        let after_partial = store.get_message("msg-big-1")?.unwrap();
        assert_eq!(after_partial.delivery_scope, "awaiting_confirm");
        assert_eq!(after_partial.acked_peers, vec!["peer-online".to_string()]);
        assert_eq!(after_partial.batch_id.as_deref(), Some("batch-movie-test"));

        // User taps confirm button -> offline peer transitions to pending and outbox drains it.
        let (confirmed, pending_peers) = store.confirm_deferred_file_transfer("msg-big-1")?;
        assert_eq!(confirmed.delivery_scope, "direct");
        assert_eq!(pending_peers, vec!["peer-offline".to_string()]);
        assert_eq!(
            store.list_pending_room_outbox_for_peer("peer-offline")?.len(),
            1
        );

        drop(store);
        let _ = std::fs::remove_file(&db_path);
        Ok(())
    }

    #[test]
    fn merge_and_load_peer_hints_prioritizes_usb_and_preserves_endpoint_addr() -> Result<()> {
        let db_path =
            std::env::temp_dir().join(format!("p2p_hints_test_{}.db", std::process::id()));
        let _ = std::fs::remove_file(&db_path);

        let store = LocalStore::open(&db_path)?;
        let secret = iroh::SecretKey::generate();
        let ep = iroh::EndpointAddr::new(secret.public());
        let peer_id = secret.public().to_string();
        store.upsert_peer(&peer_id, "iPad")?;

        store.merge_peer_hints(
            &peer_id,
            &[
                "192.168.1.50:42425".to_string(),
                "192.168.42.129:42425".to_string(),
            ],
            Some(&ep),
        );

        let (loaded_ep, loaded_lan) = store.load_peer_hints(&peer_id);
        assert_eq!(loaded_ep.map(|e| e.id), Some(ep.id));
        assert_eq!(loaded_lan.len(), 2);
        // USB tether address should be prioritized first.
        assert_eq!(loaded_lan[0].to_string(), "192.168.42.129:42425");

        drop(store);
        let _ = std::fs::remove_file(&db_path);
        Ok(())
    }

    #[test]
    fn merge_peer_hints_promotes_fresh_ipv4_over_stale_ipv6_and_caps_at_8() -> Result<()> {
        let db_path =
            std::env::temp_dir().join(format!("p2p_hints_promote_test_{}.db", std::process::id()));
        let _ = std::fs::remove_file(&db_path);

        let store = LocalStore::open(&db_path)?;
        let secret = iroh::SecretKey::generate();
        let peer_id = secret.public().to_string();
        store.upsert_peer(&peer_id, "Phone")?;

        let stale_ipv6s: Vec<String> = (1..=8)
            .map(|i| format!("[2409:8a55:291:22d0::{i}]:42425"))
            .collect();
        store.merge_peer_hints(&peer_id, &stale_ipv6s, None);
        store.merge_peer_hints(
            &peer_id,
            &[
                "192.168.1.7:42425".to_string(),
                "[2409:8a55:291:22d0::99]:42425".to_string(),
            ],
            None,
        );

        let (_, loaded_lan) = store.load_peer_hints(&peer_id);
        assert_eq!(loaded_lan.len(), 8);
        assert_eq!(loaded_lan[0].to_string(), "192.168.1.7:42425");
        assert_eq!(loaded_lan[1].to_string(), "[2409:8a55:291:22d0::99]:42425");

        // Re-reporting an existing IPv4 promoted from deeper position still stays first.
        store.merge_peer_hints(&peer_id, &["192.168.1.8:42425".to_string()], None);
        store.merge_peer_hints(&peer_id, &["192.168.1.7:42425".to_string()], None);
        let (_, loaded_lan2) = store.load_peer_hints(&peer_id);
        assert_eq!(loaded_lan2[0].to_string(), "192.168.1.7:42425");

        drop(store);
        let _ = std::fs::remove_file(&db_path);
        Ok(())
    }

    #[test]
    fn personal_default_migrates_to_dm_and_purges_home_nodes() -> Result<()> {
        let db_path = std::env::temp_dir().join(format!(
            "p2p_dm_migrate_test_{}.db",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&db_path);

        let store = LocalStore::open(&db_path)?;
        let legacy_key = room_key_to_hex(&generate_room_key());
        store.upsert_room(&RoomRecord {
            room_id: DEFAULT_PERSONAL_ROOM_ID.to_string(),
            name: DEFAULT_PERSONAL_ROOM_NAME.to_string(),
            room_type: "personal".to_string(),
            room_key_hex: Some(legacy_key),
            is_pinned: true,
            retention_days: 7,
            created_at_ms: now_millis(),
        })?;
        store.upsert_peer("peer-phone", "OnePlus")?;
        store.upsert_peer("peer-old-locker", "Meizu 16th")?;
        store.upsert_room_member(DEFAULT_PERSONAL_ROOM_ID, "me-pc", "My PC", "owner")?;
        store.upsert_room_member(DEFAULT_PERSONAL_ROOM_ID, "peer-phone", "OnePlus", "member")?;
        store.upsert_room_member(
            DEFAULT_PERSONAL_ROOM_ID,
            "peer-old-locker",
            "Meizu 16th",
            "home_node",
        )?;
        store.enqueue_room_outgoing_text(
            "msg-legacy-1",
            DEFAULT_PERSONAL_ROOM_ID,
            "me-pc",
            "peer-phone",
            "legacy hello",
            &["peer-phone".to_string(), "peer-old-locker".to_string()],
        )?;

        store.ensure_default_personal_room("me-pc", "My PC")?;

        // Legacy `personal-default` and `home_node` should be purged.
        assert!(store.get_room(DEFAULT_PERSONAL_ROOM_ID)?.is_none());
        assert!(!store.has_peer("peer-old-locker"));
        assert!(store.has_peer("peer-phone"));

        let rooms = store.list_rooms()?;
        assert_eq!(rooms.len(), 1);
        assert_eq!(rooms[0].room_type, "dm");
        assert_eq!(rooms[0].room_id, dm_room_id("me-pc", "peer-phone"));
        let timeline = store.list_room_timeline(&rooms[0].room_id, 20)?;
        assert_eq!(timeline.len(), 1);
        assert_eq!(timeline[0].body_text.as_deref(), Some("legacy hello"));

        // Deleting peer removes its contact entry and DM room.
        store.delete_peer_and_dm("me-pc", "peer-phone")?;
        assert!(!store.has_peer("peer-phone"));
        assert!(store.list_rooms()?.is_empty());

        drop(store);
        let _ = std::fs::remove_file(&db_path);
        Ok(())
    }

    #[test]
    fn group_large_file_offer_and_pull_on_demand() -> Result<()> {
        let db_path = std::env::temp_dir().join(format!(
            "p2p_group_pull_test_{}.db",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&db_path);

        let store = LocalStore::open(&db_path)?;
        store.upsert_room(&RoomRecord {
            room_id: "room-g1".to_string(),
            name: "Group 1".to_string(),
            room_type: "group".to_string(),
            room_key_hex: Some(room_key_to_hex(&generate_room_key())),
            is_pinned: false,
            retention_days: 7,
            created_at_ms: now_millis(),
        })?;
        store.upsert_room_member("room-g1", "me", "Me", "owner")?;
        store.upsert_room_member("room-g1", "peer-a", "Peer A", "member")?;
        store.upsert_room_member("room-g1", "peer-b", "Peer B", "member")?;

        let root = [5u8; 32];
        let rec = store.enqueue_room_outgoing_file_offer_only(
            "msg-g-big",
            "room-g1",
            "me",
            "peer-a",
            "iso.zip",
            LARGE_FILE_CONFIRM_THRESHOLD_BYTES + 100,
            "/tmp/iso.zip",
            &root,
            512 * 1024,
            110,
            &["peer-a".to_string(), "peer-b".to_string()],
            None,
        )?;
        assert_eq!(rec.delivery_scope, "group_offer");

        let jobs_a = store.list_pending_room_outbox_for_peer("peer-a")?;
        assert_eq!(jobs_a.len(), 1);
        assert!(jobs_a[0].offer_only);

        // Once offer is sent, target moves to awaiting_pull so no chunks are pushed yet.
        store.mark_outbox_target_status("msg-g-big", "peer-a", "awaiting_pull")?;
        assert!(store.list_pending_room_outbox_for_peer("peer-a")?.is_empty());

        // When Peer A clicks download -> pull request promotes only peer-a to pending (offer_only = false).
        assert!(store.mark_outbox_target_pull_requested("room-g1", "msg-g-big", "peer-a")?);
        let jobs_a2 = store.list_pending_room_outbox_for_peer("peer-a")?;
        assert_eq!(jobs_a2.len(), 1);
        assert!(!jobs_a2[0].offer_only);

        drop(store);
        let _ = std::fs::remove_file(&db_path);
        Ok(())
    }

    #[test]
    fn list_room_timeline_returns_newest_messages_in_chronological_order() -> Result<()> {
        let db_path = std::env::temp_dir().join(format!(
            "p2p_timeline_limit_test_{}.db",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&db_path);

        let store = LocalStore::open(&db_path)?;
        store.upsert_room(&RoomRecord {
            room_id: "room-tl".to_string(),
            name: "Timeline".to_string(),
            room_type: "dm".to_string(),
            room_key_hex: Some(room_key_to_hex(&generate_room_key())),
            is_pinned: false,
            retention_days: 7,
            created_at_ms: 1000,
        })?;
        store.upsert_room_member("room-tl", "me", "Me", "owner")?;
        store.upsert_room_member("room-tl", "peer-a", "Peer A", "member")?;

        for i in 1..=5 {
            store.enqueue_room_outgoing_text(
                &format!("msg-{i}"),
                "room-tl",
                "me",
                "peer-a",
                &format!("body-{i}"),
                &["peer-a".to_string()],
            )?;
            let conn = store.conn.lock().expect("sqlite mutex poisoned");
            conn.execute(
                "UPDATE messages SET created_at_ms = ?1 WHERE msg_id = ?2",
                params![1000 + i as i64, format!("msg-{i}")],
            )?;
        }

        let latest = store.list_room_timeline("room-tl", 3)?;
        let ids: Vec<&str> = latest.iter().map(|m| m.msg_id.as_str()).collect();
        assert_eq!(ids, vec!["msg-3", "msg-4", "msg-5"]);

        drop(store);
        let _ = std::fs::remove_file(&db_path);
        Ok(())
    }

    #[test]
    fn delete_and_revoke_never_touch_sender_source_file_while_cleaning_receiver() -> Result<()> {
        let dir = std::env::temp_dir().join(format!("p2p_revoke_store_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir)?;
        let db_path = dir.join("test.db");

        let sender_source = dir.join("important_source.jpg");
        std::fs::write(&sender_source, b"source-bytes")?;

        let receiver_copy = dir.join("received_copy.jpg");
        std::fs::write(&receiver_copy, b"received-bytes")?;

        let store = LocalStore::open(&db_path)?;
        store.upsert_room(&RoomRecord {
            room_id: "dm-room".to_string(),
            name: "DM".to_string(),
            room_type: "dm".to_string(),
            room_key_hex: Some(room_key_to_hex(&generate_room_key())),
            is_pinned: true,
            retention_days: 7,
            created_at_ms: 1000,
        })?;

        // 1. Outgoing message pointing to sender_source: delete_for_me & revoke MUST keep sender_source intact.
        store.enqueue_room_outgoing_file(
            "m-out-1",
            "dm-room",
            "me",
            "peer-a",
            "important_source.jpg",
            12,
            &sender_source.to_string_lossy(),
            &[1u8; 32],
            1024,
            1,
            &["peer-a".to_string()],
            None,
        )?;
        let revoked = store
            .apply_revoke_to_local_message("m-out-1", "me", Some("dm-room"), true)?
            .unwrap();
        assert_eq!(revoked.status, MessageStatus::Revoked);
        assert!(revoked.local_path.is_none());
        assert!(sender_source.exists(), "sender source MUST NOT be touched on revoke");

        store.enqueue_room_outgoing_file(
            "m-out-2",
            "dm-room",
            "me",
            "peer-a",
            "important_source.jpg",
            12,
            &sender_source.to_string_lossy(),
            &[1u8; 32],
            1024,
            1,
            &["peer-a".to_string()],
            None,
        )?;
        assert!(store.delete_message_for_me("m-out-2", true)?.is_some());
        assert!(store.get_message("m-out-2")?.is_none());
        assert!(sender_source.exists(), "sender source MUST NOT be touched on delete_for_me");

        // 2. Incoming message: unauthorized revoker is rejected; authorized revoker deletes receiver_copy.
        let in_rec = ChatMessageRecord {
            msg_id: "m-in-1".to_string(),
            room_id: "dm-room".to_string(),
            peer_id: "peer-a".to_string(),
            sender_id: "peer-a".to_string(),
            direction: MessageDirection::Incoming,
            kind: MessageKind::File,
            body_text: None,
            file_name: Some("received_copy.jpg".to_string()),
            file_size: Some(14),
            local_path: Some(receiver_copy.to_string_lossy().to_string()),
            root_blake3: Some(vec![2u8; 32]),
            chunk_size: Some(1024),
            total_chunks: Some(1),
            received_bitmap: None,
            status: MessageStatus::Delivered,
            delivery_scope: "direct".to_string(),
            acked_peers: vec!["me".to_string()],
            batch_id: None,
            created_at_ms: 2000,
            updated_at_ms: 2000,
        };
        store.insert_message(&in_rec)?;

        assert!(
            store
                .apply_revoke_to_local_message("m-in-1", "attacker", Some("dm-room"), true)
                .is_err()
        );
        assert!(receiver_copy.exists());

        let in_revoked = store
            .apply_revoke_to_local_message("m-in-1", "peer-a", Some("dm-room"), true)?
            .unwrap();
        assert_eq!(in_revoked.status, MessageStatus::Revoked);
        assert!(!receiver_copy.exists(), "receiver copy should be deleted on revoke");
        assert!(store.list_media_messages(Some("dm-room"), 50)?.is_empty());

        drop(store);
        let _ = std::fs::remove_dir_all(&dir);
        Ok(())
    }

    #[test]
    fn update_message_local_path_updates_existing_record() -> Result<()> {
        let dir = std::env::temp_dir().join(format!("p2p-chat-localpath-test-{}", now_millis()));
        std::fs::create_dir_all(&dir)?;
        let db_path = dir.join("store.db");
        let store = LocalStore::open(&db_path)?;

        store.upsert_room(&RoomRecord {
            room_id: "dm-room".to_string(),
            name: "DM".to_string(),
            room_type: "dm".to_string(),
            room_key_hex: Some(room_key_to_hex(&generate_room_key())),
            is_pinned: true,
            retention_days: 7,
            created_at_ms: 1000,
        })?;

        store.insert_message(&ChatMessageRecord {
            msg_id: "m-export-1".to_string(),
            room_id: "dm-room".to_string(),
            peer_id: "peer-a".to_string(),
            sender_id: "peer-a".to_string(),
            direction: MessageDirection::Incoming,
            kind: MessageKind::File,
            body_text: None,
            file_name: Some("photo.jpg".to_string()),
            file_size: Some(128),
            local_path: Some("/app/staging/photo.jpg".to_string()),
            root_blake3: Some(vec![3u8; 32]),
            chunk_size: Some(1024),
            total_chunks: Some(1),
            received_bitmap: None,
            status: MessageStatus::Delivered,
            delivery_scope: "direct".to_string(),
            acked_peers: vec!["me".to_string()],
            batch_id: None,
            created_at_ms: 2000,
            updated_at_ms: 2000,
        })?;

        assert!(store.update_message_local_path("m-export-1", "/sdcard/Download/P2PChat/photo.jpg")?);
        assert!(!store.update_message_local_path("non-existent", "/tmp/x")?);

        let updated = store.get_message("m-export-1")?.unwrap();
        assert_eq!(
            updated.local_path.as_deref(),
            Some("/sdcard/Download/P2PChat/photo.jpg")
        );

        drop(store);
        let _ = std::fs::remove_dir_all(&dir);
        Ok(())
    }
}
