//! Persistent Ed25519 device identity and one-time pairing tokens.

use anyhow::{Context, Result, bail};
use iroh::{EndpointAddr, SecretKey};
use serde::{Deserialize, Serialize};
use std::path::Path;

const IDENTITY_FILENAME: &str = "identity.key";

/// Loads an existing 32-byte Ed25519 `SecretKey` from `data_dir/identity.key`,
/// or generates and persists a fresh key on first launch.
pub fn load_or_create_secret_key(data_dir: &Path) -> Result<SecretKey> {
    std::fs::create_dir_all(data_dir)?;
    let key_path = data_dir.join(IDENTITY_FILENAME);

    if key_path.exists() {
        let bytes = std::fs::read(&key_path)
            .with_context(|| format!("failed to read identity key at {}", key_path.display()))?;
        let arr: [u8; 32] = bytes
            .try_into()
            .map_err(|_| anyhow::anyhow!("corrupted identity.key (expected 32 bytes)"))?;
        return Ok(SecretKey::from_bytes(&arr));
    }

    let key = SecretKey::generate();
    std::fs::write(&key_path, key.to_bytes())
        .with_context(|| format!("failed to persist identity key at {}", key_path.display()))?;
    Ok(key)
}

/// Payload encoded into the QR code (or manual pairing string) during initial device binding.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairingTicket {
    pub version: u8,
    pub device_name: String,
    pub endpoint_addr: EndpointAddr,
    pub lan_addrs: Vec<String>,
    /// One-time 16-byte pre-shared secret hex to prevent unauthorized pairing hijacks.
    pub one_time_psk_hex: String,
}

impl PairingTicket {
    /// Encodes the pairing ticket into a compact UTF-8 JSON string suitable for QR codes.
    pub fn to_qr_string(&self) -> Result<String> {
        Ok(serde_json::to_string(self)?)
    }

    /// Decodes a scanned QR string back into a `PairingTicket`.
    pub fn from_qr_string(raw: &str) -> Result<Self> {
        let ticket: Self = serde_json::from_str(raw.trim()).context("invalid pairing QR ticket")?;
        if ticket.version != 1 {
            bail!("unsupported pairing ticket version: {}", ticket.version);
        }
        Ok(ticket)
    }
}

/// Generates a random 6-digit pairing PIN (`000000`..`999999`) for manual code pairing.
pub fn generate_6digit_pin() -> String {
    let random_key = SecretKey::generate();
    let bytes = random_key.to_bytes();
    let val = u32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]) % 1_000_000;
    format!("{val:06}")
}

/// Member descriptor included in a `RoomInviteTicket` so a new device can connect to all room devices immediately.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomMemberTicketEntry {
    pub node_id: String,
    pub display_name: String,
    /// `"owner"` | `"member"` | `"home_node"`
    pub role: String,
    pub endpoint_addr: Option<EndpointAddr>,
    pub lan_addrs: Vec<String>,
}

/// Phase 2 multi-room invite ticket (supports regular members with `room_key` and blind `home_node`s without `room_key`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomInviteTicket {
    pub version: u8,
    pub room_id: String,
    pub room_name: String,
    pub room_type: String,
    /// `"member"` or `"home_node"`
    pub invite_role: String,
    /// Present ONLY when `invite_role != "home_node"`; omitted (`None`) for zero-knowledge blind locker nodes.
    pub room_key_hex: Option<String>,
    pub inviter_id: String,
    pub inviter_name: String,
    pub inviter_endpoint: EndpointAddr,
    pub inviter_lan_addrs: Vec<String>,
    pub members: Vec<RoomMemberTicketEntry>,
    pub one_time_psk_hex: String,
}

impl RoomInviteTicket {
    /// Encodes the room invite ticket into a compact JSON string for QR or clipboard sharing.
    pub fn to_qr_string(&self) -> Result<String> {
        Ok(serde_json::to_string(self)?)
    }

    /// Decodes a scanned or pasted `RoomInviteTicket`.
    pub fn from_qr_string(raw: &str) -> Result<Self> {
        let ticket: Self = serde_json::from_str(raw.trim()).context("invalid room invite ticket")?;
        if ticket.version != 2 {
            bail!("unsupported room invite ticket version: {}", ticket.version);
        }
        Ok(ticket)
    }
}
