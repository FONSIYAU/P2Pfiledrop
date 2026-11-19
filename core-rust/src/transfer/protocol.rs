//! Wire protocol messages shared across USB tethering, LAN physical-NIC QUIC,
//! and Iroh WAN/Relay channels.

use crate::crypto::room_cipher::EncryptedEnvelope;
use anyhow::{Context, Result};
use iroh::{EndpointAddr, PublicKey, SecretKey, Signature};
use serde::{Deserialize, Serialize};

const LOCKER_ACK_DOMAIN: &[u8] = b"p2p-locker-ack-v2:";
const MSG_REVOKE_DOMAIN: &[u8] = b"p2p-msg-revoke-v1:";

/// Wire representation of a room member for membership sync.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomMemberWire {
    pub node_id: String,
    pub display_name: String,
    /// `"owner"` | `"member"` | `"home_node"`
    pub role: String,
    #[serde(default)]
    pub endpoint_addr: Option<EndpointAddr>,
    #[serde(default)]
    pub lan_addrs: Vec<String>,
}

/// High-level envelope transmitted over QUIC streams between paired devices.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum WireMessage {
    /// Exchanged immediately after handshake to advertise local physical LAN/USB probe addresses.
    PeerCapabilities {
        device_name: String,
        lan_probe_addrs: Vec<String>,
    },
    /// Plain-text chat message (Phase 1 compatibility).
    TextMessage {
        msg_id: String,
        created_at_ms: i64,
        text: String,
    },
    /// Announces a file or media item (Phase 1 compatibility).
    FileOffer {
        msg_id: String,
        created_at_ms: i64,
        file_name: String,
        file_size: u64,
        chunk_size: usize,
        chunk_hashes: Vec<[u8; 32]>,
        root_blake3: [u8; 32],
        mime_type: Option<String>,
        thumbnail_webp: Option<Vec<u8>>,
    },
    /// Receiver's response to `FileOffer` / `RoomEnvelopeOffer`, indicating verified chunks on disk.
    ChunkBitmapAck {
        msg_id: String,
        /// One bit per chunk (LSB-first per byte): `1` means verified and written on disk.
        received_bitmap: Vec<u8>,
        already_complete: bool,
    },
    /// Individual 512 KiB file chunk payload (plaintext in Phase 1, ciphertext in Phase 2).
    FileChunk {
        msg_id: String,
        chunk_index: u32,
        #[serde(with = "base64_or_bytes")]
        data: Vec<u8>,
    },
    /// Phase 1 delivery confirmation once all chunks pass BLAKE3 verification.
    DeliveryAck {
        msg_id: String,
        saved_path: Option<String>,
    },

    // -------------------------------------------------------------------------
    // Phase 2: Multi-Room E2EE & Zero-Knowledge Blind Locker Protocol
    // -------------------------------------------------------------------------
    /// Synchronizes room metadata and authorized public keys (`room_key_hex` is sent only to authorized members, never to blind nodes).
    RoomSyncAnnounce {
        room_id: String,
        room_name: String,
        room_type: String,
        retention_days: u32,
        members: Vec<RoomMemberWire>,
        #[serde(default)]
        room_key_hex: Option<String>,
    },
    /// End-to-end encrypted message or file offer bound to a `room_id`.
    /// Sent both from sender -> Home Node (`store_in_locker = true`) and
    /// from sender / Home Node -> target recipient (`store_in_locker = false`).
    RoomEnvelopeOffer {
        room_id: String,
        msg_id: String,
        sender_id: String,
        target_peers: Vec<String>,
        store_in_locker: bool,
        envelope: EncryptedEnvelope,
        cipher_file_size: u64,
        chunk_size: usize,
        cipher_chunk_hashes: Vec<[u8; 32]>,
        cipher_root_blake3: [u8; 32],
        retention_days: u32,
        #[serde(default)]
        offer_only: bool,
    },
    /// Returned by the Home Node once the encrypted envelope and `.enc` chunks are persisted in the blind locker.
    LockerStoredAck {
        room_id: String,
        msg_id: String,
        home_node_id: String,
    },
    /// Ed25519-signed delivery receipt returned by a terminal recipient after decrypting and verifying.
    RecipientDeliveryAck {
        room_id: String,
        msg_id: String,
        recipient_id: String,
        signature_bytes: Vec<u8>,
    },
    /// Sent by a group member when clicking "Download" on an `offer_only` large file card.
    FilePullRequest {
        room_id: String,
        msg_id: String,
    },
    /// Lightweight profile & avatar hash exchange initiated upon peer connect.
    ProfileAnnounce {
        display_name: String,
        #[serde(default)]
        avatar_hash: Option<String>,
        /// Hash of the recipient's avatar currently cached on the initiator's disk.
        #[serde(default)]
        known_peer_avatar_hash: Option<String>,
    },
    /// Reply to `ProfileAnnounce` carrying responder's display name and avatar when stale/missing.
    ProfileResponse {
        display_name: String,
        #[serde(default)]
        avatar_hash: Option<String>,
        #[serde(default, with = "base64_or_bytes_opt")]
        avatar_png: Option<Vec<u8>>,
        #[serde(default)]
        need_your_avatar: bool,
    },
    /// Direct push carrying a peer's updated display name and/or avatar image bytes.
    ProfilePush {
        display_name: String,
        #[serde(default)]
        avatar_hash: Option<String>,
        #[serde(default, with = "base64_or_bytes_opt")]
        avatar_png: Option<Vec<u8>>,
        #[serde(default)]
        clear_avatar: bool,
    },
    /// Signed request from the original message sender to revoke a message across devices & blind lockers.
    RoomMessageRevoke {
        room_id: String,
        msg_id: String,
        sender_id: String,
        #[serde(default)]
        target_peers: Vec<String>,
        #[serde(default)]
        store_in_locker: bool,
        signature_bytes: Vec<u8>,
    },
    /// Acknowledgment that `RoomMessageRevoke` was applied or stored.
    RoomRevokeAck {
        room_id: String,
        msg_id: String,
    },
}

/// Canonical transcript signed by `recipient_id` for `RecipientDeliveryAck`.
pub fn locker_ack_transcript(room_id: &str, msg_id: &str, recipient_id: &str) -> Vec<u8> {
    let mut out = Vec::with_capacity(
        LOCKER_ACK_DOMAIN.len() + room_id.len() + msg_id.len() + recipient_id.len() + 2,
    );
    out.extend_from_slice(LOCKER_ACK_DOMAIN);
    out.extend_from_slice(room_id.as_bytes());
    out.push(b':');
    out.extend_from_slice(msg_id.as_bytes());
    out.push(b':');
    out.extend_from_slice(recipient_id.as_bytes());
    out
}

/// Signs a `RecipientDeliveryAck` using the local device's Ed25519 `SecretKey`.
pub fn sign_recipient_ack(local_key: &SecretKey, room_id: &str, msg_id: &str) -> WireMessage {
    let recipient_id = local_key.public().to_string();
    let transcript = locker_ack_transcript(room_id, msg_id, &recipient_id);
    let sig = local_key.sign(&transcript);
    WireMessage::RecipientDeliveryAck {
        room_id: room_id.to_string(),
        msg_id: msg_id.to_string(),
        recipient_id,
        signature_bytes: sig.to_bytes().to_vec(),
    }
}

/// Verifies the Ed25519 signature inside a `RecipientDeliveryAck`.
pub fn verify_recipient_ack(
    room_id: &str,
    msg_id: &str,
    recipient_id: &str,
    signature_bytes: &[u8],
) -> Result<()> {
    let pub_key: PublicKey = recipient_id
        .parse()
        .context("invalid recipient EndpointId in RecipientDeliveryAck")?;
    let sig_arr: [u8; 64] = signature_bytes
        .try_into()
        .map_err(|_| anyhow::anyhow!("invalid Ed25519 signature length in RecipientDeliveryAck"))?;
    let sig = Signature::from_bytes(&sig_arr);
    let transcript = locker_ack_transcript(room_id, msg_id, recipient_id);
    pub_key
        .verify(&transcript, &sig)
        .context("RecipientDeliveryAck Ed25519 signature verification failed")?;
    Ok(())
}

/// Canonical transcript signed by `sender_id` for `RoomMessageRevoke`.
pub fn msg_revoke_transcript(room_id: &str, msg_id: &str, sender_id: &str) -> Vec<u8> {
    let mut out = Vec::with_capacity(
        MSG_REVOKE_DOMAIN.len() + room_id.len() + msg_id.len() + sender_id.len() + 2,
    );
    out.extend_from_slice(MSG_REVOKE_DOMAIN);
    out.extend_from_slice(room_id.as_bytes());
    out.push(b':');
    out.extend_from_slice(msg_id.as_bytes());
    out.push(b':');
    out.extend_from_slice(sender_id.as_bytes());
    out
}

/// Signs a `RoomMessageRevoke` frame using the original sender's Ed25519 `SecretKey`.
pub fn sign_room_revoke(
    local_key: &SecretKey,
    room_id: &str,
    msg_id: &str,
    target_peers: Vec<String>,
    store_in_locker: bool,
) -> WireMessage {
    let sender_id = local_key.public().to_string();
    let transcript = msg_revoke_transcript(room_id, msg_id, &sender_id);
    let sig = local_key.sign(&transcript);
    WireMessage::RoomMessageRevoke {
        room_id: room_id.to_string(),
        msg_id: msg_id.to_string(),
        sender_id,
        target_peers,
        store_in_locker,
        signature_bytes: sig.to_bytes().to_vec(),
    }
}

/// Verifies the Ed25519 signature inside a `RoomMessageRevoke`.
pub fn verify_room_revoke(
    room_id: &str,
    msg_id: &str,
    sender_id: &str,
    signature_bytes: &[u8],
) -> Result<()> {
    let pub_key: PublicKey = sender_id
        .parse()
        .context("invalid sender EndpointId in RoomMessageRevoke")?;
    let sig_arr: [u8; 64] = signature_bytes
        .try_into()
        .map_err(|_| anyhow::anyhow!("invalid Ed25519 signature length in RoomMessageRevoke"))?;
    let sig = Signature::from_bytes(&sig_arr);
    let transcript = msg_revoke_transcript(room_id, msg_id, sender_id);
    pub_key
        .verify(&transcript, &sig)
        .context("RoomMessageRevoke Ed25519 signature verification failed")?;
    Ok(())
}

/// Helper for manipulating compact LSB-first chunk bitmaps.
pub struct ChunkBitmap;

impl ChunkBitmap {
    /// Allocates a zeroed bitmap covering `total_chunks`.
    pub fn empty(total_chunks: usize) -> Vec<u8> {
        vec![0u8; total_chunks.div_ceil(8)]
    }

    /// Marks `chunk_index` as received.
    pub fn set(bitmap: &mut [u8], chunk_index: usize) {
        let byte_idx = chunk_index / 8;
        let bit_idx = chunk_index % 8;
        if let Some(b) = bitmap.get_mut(byte_idx) {
            *b |= 1u8 << bit_idx;
        }
    }

    /// Returns `true` if `chunk_index` is marked received.
    pub fn is_set(bitmap: &[u8], chunk_index: usize) -> bool {
        let byte_idx = chunk_index / 8;
        let bit_idx = chunk_index % 8;
        bitmap
            .get(byte_idx)
            .is_some_and(|b| (b & (1u8 << bit_idx)) != 0)
    }

    /// Returns `true` if every chunk in `0..total_chunks` is marked received.
    pub fn is_all_set(bitmap: &[u8], total_chunks: usize) -> bool {
        (0..total_chunks).all(|idx| Self::is_set(bitmap, idx))
    }

    /// Lists missing chunk indices in ascending order.
    pub fn missing_indices(bitmap: &[u8], total_chunks: usize) -> Vec<usize> {
        (0..total_chunks)
            .filter(|&idx| !Self::is_set(bitmap, idx))
            .collect()
    }
}

/// Compact base64 serializer with backward-compatible deserialization from either
/// a base64 string or a legacy JSON byte array (`[u8, ...]`).
mod base64_or_bytes {
    use serde::{Deserializer, Serializer, de};
    use std::fmt;

    const TABLE: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    pub fn serialize<S>(bytes: &[u8], serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut out = String::with_capacity(bytes.len().div_ceil(3) * 4);
        for chunk in bytes.chunks(3) {
            let b0 = chunk[0] as u32;
            let b1 = if chunk.len() > 1 { chunk[1] as u32 } else { 0 };
            let b2 = if chunk.len() > 2 { chunk[2] as u32 } else { 0 };
            let triple = (b0 << 16) | (b1 << 8) | b2;
            out.push(TABLE[((triple >> 18) & 0x3F) as usize] as char);
            out.push(TABLE[((triple >> 12) & 0x3F) as usize] as char);
            out.push(if chunk.len() > 1 {
                TABLE[((triple >> 6) & 0x3F) as usize] as char
            } else {
                '='
            });
            out.push(if chunk.len() > 2 {
                TABLE[(triple & 0x3F) as usize] as char
            } else {
                '='
            });
        }
        serializer.serialize_str(&out)
    }

    fn decode_base64(input: &str) -> Result<Vec<u8>, &'static str> {
        let bytes = input.as_bytes();
        if bytes.len() % 4 != 0 {
            return Err("invalid base64 length");
        }
        let mut out = Vec::with_capacity((bytes.len() / 4) * 3);
        for quad in bytes.chunks_exact(4) {
            let mut vals = [0u8; 4];
            let mut pad = 0usize;
            for (i, &c) in quad.iter().enumerate() {
                if c == b'=' {
                    pad += 1;
                    vals[i] = 0;
                } else {
                    vals[i] = match c {
                        b'A'..=b'Z' => c - b'A',
                        b'a'..=b'z' => c - b'a' + 26,
                        b'0'..=b'9' => c - b'0' + 52,
                        b'+' => 62,
                        b'/' => 63,
                        _ => return Err("invalid base64 character"),
                    };
                }
            }
            if pad > 2 {
                return Err("invalid base64 padding");
            }
            let triple = ((vals[0] as u32) << 18)
                | ((vals[1] as u32) << 12)
                | ((vals[2] as u32) << 6)
                | (vals[3] as u32);
            out.push(((triple >> 16) & 0xFF) as u8);
            if pad < 2 {
                out.push(((triple >> 8) & 0xFF) as u8);
            }
            if pad < 1 {
                out.push((triple & 0xFF) as u8);
            }
        }
        Ok(out)
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
    where
        D: Deserializer<'de>,
    {
        struct Visitor;
        impl<'de> de::Visitor<'de> for Visitor {
            type Value = Vec<u8>;

            fn expecting(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                f.write_str("a base64 string or byte array")
            }

            fn visit_str<E>(self, v: &str) -> Result<Self::Value, E>
            where
                E: de::Error,
            {
                decode_base64(v).map_err(E::custom)
            }

            fn visit_seq<A>(self, mut seq: A) -> Result<Self::Value, A::Error>
            where
                A: de::SeqAccess<'de>,
            {
                let mut out = Vec::with_capacity(seq.size_hint().unwrap_or(0));
                while let Some(b) = seq.next_element::<u8>()? {
                    out.push(b);
                }
                Ok(out)
            }
        }
        deserializer.deserialize_any(Visitor)
    }
}

/// Optional base64 serializer delegating directly to `base64_or_bytes`.
mod base64_or_bytes_opt {
    use super::base64_or_bytes;
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S>(opt: &Option<Vec<u8>>, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        match opt {
            Some(bytes) => base64_or_bytes::serialize(bytes, serializer),
            None => serializer.serialize_none(),
        }
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Option<Vec<u8>>, D::Error>
    where
        D: Deserializer<'de>,
    {
        struct Wrapper(Vec<u8>);
        impl<'de> Deserialize<'de> for Wrapper {
            fn deserialize<D2>(d: D2) -> Result<Self, D2::Error>
            where
                D2: Deserializer<'de>,
            {
                base64_or_bytes::deserialize(d).map(Wrapper)
            }
        }
        Option::<Wrapper>::deserialize(deserializer).map(|o| o.map(|w| w.0))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn profile_push_serializes_optional_avatar_cleanly() {
        let with_bytes = WireMessage::ProfilePush {
            display_name: "📱 OnePlus".to_string(),
            avatar_hash: Some("abcd1234".to_string()),
            avatar_png: Some(vec![137, 80, 78, 71]),
            clear_avatar: false,
        };
        let j1 = serde_json::to_string(&with_bytes).unwrap();
        let d1: WireMessage = serde_json::from_str(&j1).unwrap();
        match d1 {
            WireMessage::ProfilePush {
                display_name,
                avatar_hash,
                avatar_png,
                clear_avatar,
            } => {
                assert_eq!(display_name, "📱 OnePlus");
                assert_eq!(avatar_hash.as_deref(), Some("abcd1234"));
                assert_eq!(avatar_png.as_deref(), Some(&[137, 80, 78, 71][..]));
                assert!(!clear_avatar);
            }
            other => panic!("unexpected: {other:?}"),
        }

        let cleared = WireMessage::ProfilePush {
            display_name: "💻 PC".to_string(),
            avatar_hash: None,
            avatar_png: None,
            clear_avatar: true,
        };
        let j2 = serde_json::to_string(&cleared).unwrap();
        let d2: WireMessage = serde_json::from_str(&j2).unwrap();
        match d2 {
            WireMessage::ProfilePush {
                avatar_png,
                clear_avatar,
                ..
            } => {
                assert!(avatar_png.is_none());
                assert!(clear_avatar);
            }
            other => panic!("unexpected: {other:?}"),
        }
    }

    #[test]
    fn file_chunk_serializes_as_compact_base64_and_reads_legacy_array() {
        let payload = vec![0u8, 1, 2, 127, 128, 254, 255];
        let msg = WireMessage::FileChunk {
            msg_id: "m1".to_string(),
            chunk_index: 0,
            data: payload.clone(),
        };
        let json = serde_json::to_string(&msg).unwrap();
        assert!(json.contains("\"AAECf4D+/w==\""), "got: {json}");
        let decoded: WireMessage = serde_json::from_str(&json).unwrap();
        match decoded {
            WireMessage::FileChunk { data, .. } => assert_eq!(data, payload),
            other => panic!("unexpected: {other:?}"),
        }

        let legacy = r#"{"FileChunk":{"msg_id":"m1","chunk_index":0,"data":[0,1,2,127,128,254,255]}}"#;
        let legacy_decoded: WireMessage = serde_json::from_str(legacy).unwrap();
        match legacy_decoded {
            WireMessage::FileChunk { data, .. } => assert_eq!(data, payload),
            other => panic!("unexpected: {other:?}"),
        }
    }
}
