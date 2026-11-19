//! Room-scoped authenticated encryption (Encrypt-then-MAC using BLAKE3 keyed XOF + MAC)
//! and deterministic per-chunk stream encryption for zero-knowledge blind locker storage.

use anyhow::{Context, Result, bail};
use iroh::SecretKey;
use serde::{Deserialize, Serialize};

/// 256-bit symmetric room master key shared only among terminal room members (never held by pure Home Nodes).
pub type RoomKey = [u8; 32];

const ENV_ENC_CTX: &str = "p2p-chat-v2-env-enc";
const ENV_MAC_CTX: &str = "p2p-chat-v2-env-mac";
const CHUNK_STREAM_CTX: &str = "p2p-chat-v2-chunk-stream";

/// Generates a fresh cryptographically random 32-byte `RoomKey`.
pub fn generate_room_key() -> RoomKey {
    SecretKey::generate().to_bytes()
}

/// Encodes a 32-byte `RoomKey` as a lowercase 64-character hex string.
pub fn room_key_to_hex(key: &RoomKey) -> String {
    let mut out = String::with_capacity(64);
    for b in key {
        use std::fmt::Write;
        let _ = write!(&mut out, "{b:02x}");
    }
    out
}

/// Decodes a 64-character hex string into a 32-byte `RoomKey`.
pub fn room_key_from_hex(s: &str) -> Result<RoomKey> {
    let trimmed = s.trim();
    if trimmed.len() != 64 {
        bail!("invalid room key hex length: expected 64, got {}", trimmed.len());
    }
    let mut out = [0u8; 32];
    for (i, slot) in out.iter_mut().enumerate() {
        let byte_str = &trimmed[i * 2..i * 2 + 2];
        *slot = u8::from_str_radix(byte_str, 16)
            .with_context(|| format!("invalid hex byte in room key at index {i}"))?;
    }
    Ok(out)
}

/// Plaintext payload sealed inside `EncryptedEnvelope` so blind Home Nodes cannot inspect text or file names.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PlainEnvelopePayload {
    pub kind: String,
    pub text: Option<String>,
    pub file_name: Option<String>,
    pub file_size: Option<u64>,
    pub plain_root_blake3: Option<[u8; 32]>,
    pub plain_chunk_hashes: Vec<[u8; 32]>,
    pub created_at_ms: i64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub batch_id: Option<String>,
}

/// Authenticated encrypted message/metadata envelope.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct EncryptedEnvelope {
    pub nonce: [u8; 24],
    pub ciphertext: Vec<u8>,
    pub mac_tag: [u8; 32],
}

fn compute_envelope_mac(
    mac_key: &[u8; 32],
    room_id: &str,
    sender_id: &str,
    msg_id: &str,
    nonce: &[u8; 24],
    ciphertext: &[u8],
) -> [u8; 32] {
    let mut mac = blake3::Hasher::new_keyed(mac_key);
    mac.update(room_id.as_bytes());
    mac.update(&[0u8]);
    mac.update(sender_id.as_bytes());
    mac.update(&[0u8]);
    mac.update(msg_id.as_bytes());
    mac.update(&[0u8]);
    mac.update(nonce);
    mac.update(ciphertext);
    *mac.finalize().as_bytes()
}

fn xor_envelope_stream(
    enc_key: &[u8; 32],
    nonce: &[u8; 24],
    room_id: &str,
    msg_id: &str,
    buf: &mut [u8],
) {
    let mut xof = blake3::Hasher::new_keyed(enc_key);
    xof.update(nonce);
    xof.update(room_id.as_bytes());
    xof.update(&[0u8]);
    xof.update(msg_id.as_bytes());
    let mut reader = xof.finalize_xof();

    let mut scratch = [0u8; 4096];
    for chunk in buf.chunks_mut(scratch.len()) {
        let n = chunk.len();
        reader.fill(&mut scratch[..n]);
        for (b, k) in chunk.iter_mut().zip(&scratch[..n]) {
            *b ^= *k;
        }
    }
}

/// Seals `payload` with Encrypt-then-MAC bound to `(room_id, sender_id, msg_id)`.
pub fn seal_envelope(
    room_key: &RoomKey,
    room_id: &str,
    sender_id: &str,
    msg_id: &str,
    payload: &PlainEnvelopePayload,
) -> Result<EncryptedEnvelope> {
    let enc_key = blake3::derive_key(ENV_ENC_CTX, room_key);
    let mac_key = blake3::derive_key(ENV_MAC_CTX, room_key);

    let rand_bytes = SecretKey::generate().to_bytes();
    let mut nonce = [0u8; 24];
    nonce.copy_from_slice(&rand_bytes[..24]);

    let mut ciphertext = serde_json::to_vec(payload)?;
    xor_envelope_stream(&enc_key, &nonce, room_id, msg_id, &mut ciphertext);
    let mac_tag = compute_envelope_mac(&mac_key, room_id, sender_id, msg_id, &nonce, &ciphertext);

    Ok(EncryptedEnvelope {
        nonce,
        ciphertext,
        mac_tag,
    })
}

/// Verifies MAC in constant time and decrypts `EncryptedEnvelope` using `room_key`.
pub fn open_envelope(
    room_key: &RoomKey,
    room_id: &str,
    sender_id: &str,
    msg_id: &str,
    env: &EncryptedEnvelope,
) -> Result<PlainEnvelopePayload> {
    let enc_key = blake3::derive_key(ENV_ENC_CTX, room_key);
    let mac_key = blake3::derive_key(ENV_MAC_CTX, room_key);

    let expected_mac = compute_envelope_mac(
        &mac_key,
        room_id,
        sender_id,
        msg_id,
        &env.nonce,
        &env.ciphertext,
    );
    // blake3::Hash::eq uses constant-time comparison.
    if blake3::Hash::from_bytes(expected_mac) != blake3::Hash::from_bytes(env.mac_tag) {
        bail!("room envelope MAC verification failed (wrong room key or tampered ciphertext)");
    }

    let mut plain_bytes = env.ciphertext.clone();
    xor_envelope_stream(&enc_key, &env.nonce, room_id, msg_id, &mut plain_bytes);
    let payload: PlainEnvelopePayload =
        serde_json::from_slice(&plain_bytes).context("failed to deserialize decrypted envelope")?;
    Ok(payload)
}

/// Symmetrically encrypts or decrypts a file chunk in-place (preserving exact byte length and offsets).
pub fn transform_chunk_in_place(
    room_key: &RoomKey,
    room_id: &str,
    msg_id: &str,
    chunk_index: u32,
    data: &mut [u8],
) {
    let chunk_key = blake3::derive_key(CHUNK_STREAM_CTX, room_key);
    let mut hasher = blake3::Hasher::new_keyed(&chunk_key);
    hasher.update(room_id.as_bytes());
    hasher.update(b":");
    hasher.update(msg_id.as_bytes());
    hasher.update(&chunk_index.to_le_bytes());
    let mut reader = hasher.finalize_xof();

    let mut scratch = [0u8; 16 * 1024];
    for slice in data.chunks_mut(scratch.len()) {
        let n = slice.len();
        reader.fill(&mut scratch[..n]);
        for (b, k) in slice.iter_mut().zip(&scratch[..n]) {
            *b ^= *k;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn room_key_hex_roundtrip() -> Result<()> {
        let key = generate_room_key();
        let hex = room_key_to_hex(&key);
        assert_eq!(hex.len(), 64);
        assert_eq!(room_key_from_hex(&hex)?, key);
        Ok(())
    }

    #[test]
    fn envelope_seal_open_and_tamper_rejection() -> Result<()> {
        let key = generate_room_key();
        let wrong_key = generate_room_key();
        let payload = PlainEnvelopePayload {
            kind: "text".to_string(),
            text: Some("Secret blind-locker message!".to_string()),
            file_name: None,
            file_size: None,
            plain_root_blake3: None,
            plain_chunk_hashes: Vec::new(),
            created_at_ms: 1700000000,
            batch_id: None,
        };

        let mut env = seal_envelope(&key, "room-1", "sender-a", "msg-1", &payload)?;
        let opened = open_envelope(&key, "room-1", "sender-a", "msg-1", &env)?;
        assert_eq!(opened, payload);

        // Wrong room key or wrong sender_id must fail MAC verification.
        assert!(open_envelope(&wrong_key, "room-1", "sender-a", "msg-1", &env).is_err());
        assert!(open_envelope(&key, "room-1", "sender-b", "msg-1", &env).is_err());

        // Tampering ciphertext must fail MAC verification.
        env.ciphertext[0] ^= 0xFF;
        assert!(open_envelope(&key, "room-1", "sender-a", "msg-1", &env).is_err());
        Ok(())
    }

    #[test]
    fn chunk_stream_transform_is_symmetric() {
        let key = generate_room_key();
        let original: Vec<u8> = (0..120_000u32).map(|i| (i % 251) as u8).collect();
        let mut buf = original.clone();

        transform_chunk_in_place(&key, "room-x", "msg-9", 3, &mut buf);
        assert_ne!(buf, original);
        assert_eq!(buf.len(), original.len());

        transform_chunk_in_place(&key, "room-x", "msg-9", 3, &mut buf);
        assert_eq!(buf, original);
    }

    #[test]
    fn envelope_payload_preserves_batch_id_and_decodes_legacy_json() -> Result<()> {
        let key = generate_room_key();
        let with_batch = PlainEnvelopePayload {
            kind: "file".to_string(),
            text: None,
            file_name: Some("photo_1.jpg".to_string()),
            file_size: Some(42),
            plain_root_blake3: Some([7u8; 32]),
            plain_chunk_hashes: vec![[8u8; 32]],
            created_at_ms: 1700000100,
            batch_id: Some("batch-abc-123".to_string()),
        };
        let env = seal_envelope(&key, "room-1", "sender-a", "msg-2", &with_batch)?;
        let opened = open_envelope(&key, "room-1", "sender-a", "msg-2", &env)?;
        assert_eq!(opened.batch_id.as_deref(), Some("batch-abc-123"));

        // Legacy payloads serialized without `batch_id` deserialize with `batch_id: None`.
        let legacy_json = br#"{"kind":"file","text":null,"file_name":"old.jpg","file_size":10,"plain_root_blake3":null,"plain_chunk_hashes":[],"created_at_ms":1700000000}"#;
        let legacy: PlainEnvelopePayload = serde_json::from_slice(legacy_json)?;
        assert_eq!(legacy.batch_id, None);
        Ok(())
    }
}
