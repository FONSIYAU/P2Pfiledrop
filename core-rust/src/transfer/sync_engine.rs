//! Resumable stream transfer protocol, multi-room E2EE sync, and blind-locker delivery engine.
//!
//! Operates identically over any bidirectional QUIC stream (`AsyncRead + AsyncWrite`),
//! whether carried by USB tethering, physical-NIC LAN, or Iroh WAN/Relay.

use crate::config::EngineConfig;
use crate::crypto::room_cipher::{
    EncryptedEnvelope, PlainEnvelopePayload, RoomKey, open_envelope, room_key_from_hex,
    seal_envelope,
};
use crate::db::store::{
    BlindLockerItem, ChatMessageRecord, DEFAULT_PERSONAL_ROOM_ID, LocalStore, MessageDirection,
    MessageKind, MessageStatus, PendingRoomOutboxJob, PendingRoomRevoke, RoomRecord,
    UnforwardedLockerAck, now_millis,
};
use crate::transfer::chunker::{
    finalize_blind_locker_file, finalize_part_file, index_encrypted_file, index_file, read_chunk,
    read_encrypted_chunk, validate_safe_id, verify_and_write_chunk, verify_decrypt_and_write_chunk,
};
use crate::transfer::protocol::{
    ChunkBitmap, WireMessage, sign_recipient_ack, verify_recipient_ack, verify_room_revoke,
};
use anyhow::{Context, Result, bail};
use iroh::SecretKey;
use std::path::{Path, PathBuf};
use std::time::Duration;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};
use tokio::sync::broadcast;

/// Maximum serialized control/chunk frame size (32 MiB).
const MAX_FRAME_BYTES: usize = 32 * 1024 * 1024;
const MS_PER_DAY: i64 = 86_400_000;
/// Timeout for control/ACK frames so a half-dead WAN/Relay stream fails fast and retries.
const WIRE_CTRL_TIMEOUT: Duration = Duration::from_secs(25);
/// Timeout for a single chunk frame read/write over slow WAN/Relay links.
const WIRE_CHUNK_TIMEOUT: Duration = Duration::from_secs(60);
/// Timeout for final delivery/locker ACK after writing chunks (allows <=2 MiB buffered QUIC send
/// window to drain over slow 5G/Relay links and large-file BLAKE3 verification, while dead peers
/// still fail fast via QUIC idle timeout).
const WIRE_FINAL_ACK_TIMEOUT: Duration = Duration::from_secs(120);
/// Incoming files at or below 512 KiB are written and verified on disk before
/// inserting a chat bubble, preventing ghost `paused_reconnecting` records if the
/// sender drops mid-transfer. Larger files persist chunk bitmaps for resumable transfer.
pub const DEFERRED_SMALL_FILE_BUBBLE_THRESHOLD_BYTES: u64 = 512 * 1024;

/// High-level events pushed from the Rust core to the UI / CLI.
#[derive(Debug, Clone)]
pub enum EngineEvent {
    PeerConnected {
        peer_id: String,
        transport: TransportKind,
    },
    PeerDisconnected {
        peer_id: String,
    },
    MessageAdded(ChatMessageRecord),
    MessageUpdated(ChatMessageRecord),
    MessageDeleted {
        room_id: String,
        msg_id: String,
    },
    TransferProgress {
        msg_id: String,
        completed_chunks: usize,
        total_chunks: usize,
        status: MessageStatus,
        local_path: Option<String>,
    },
    RoomUpdated {
        room_id: String,
    },
    HomeNodeStatsUpdated,
    LockerItemReady {
        room_id: String,
        msg_id: String,
        target_peers: Vec<String>,
    },
    UsbHomeNodeDiscovered {
        node_id: String,
        bootstrap_url: String,
    },
    OutboxRetryRequested {
        peer_id: String,
    },
    PeerProfileUpdated {
        peer_id: String,
        display_name: String,
        avatar_path: Option<String>,
    },
}

/// Active transport path used for a peer session (ordered highest -> lowest priority).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransportKind {
    UsbTetherDirect,
    LanDirectPhysicalNic,
    WanDirectP2p,
    WanRelay,
}

impl TransportKind {
    pub fn priority_rank(self) -> u8 {
        match self {
            Self::UsbTetherDirect => 4,
            Self::LanDirectPhysicalNic => 3,
            Self::WanDirectP2p => 2,
            Self::WanRelay => 1,
        }
    }
}

#[cfg(test)]
mod transport_tests {
    use super::TransportKind;

    #[test]
    fn transport_priority_order_is_strict() {
        assert!(
            TransportKind::UsbTetherDirect.priority_rank()
                > TransportKind::LanDirectPhysicalNic.priority_rank()
        );
        assert!(
            TransportKind::LanDirectPhysicalNic.priority_rank()
                > TransportKind::WanDirectP2p.priority_rank()
        );
        assert!(
            TransportKind::WanDirectP2p.priority_rank() > TransportKind::WanRelay.priority_rank()
        );
    }
}

/// Writes a length-prefixed JSON/wire frame onto an async stream.
pub async fn write_wire_message<W: AsyncWrite + Unpin>(
    writer: &mut W,
    msg: &WireMessage,
) -> Result<()> {
    let payload = serde_json::to_vec(msg)?;
    if payload.len() > MAX_FRAME_BYTES {
        bail!(
            "wire message exceeds max frame size: {} bytes",
            payload.len()
        );
    }
    let len_be = (payload.len() as u32).to_be_bytes();
    writer.write_all(&len_be).await?;
    writer.write_all(&payload).await?;
    writer.flush().await?;
    Ok(())
}

/// Reads a length-prefixed wire frame from an async stream. Returns `None` on clean EOF.
pub async fn read_wire_message<R: AsyncRead + Unpin>(reader: &mut R) -> Result<Option<WireMessage>> {
    let mut len_buf = [0u8; 4];
    match reader.read_exact(&mut len_buf).await {
        Ok(_) => {}
        Err(e) if e.kind() == std::io::ErrorKind::UnexpectedEof => return Ok(None),
        Err(e) => return Err(e.into()),
    }

    let len = u32::from_be_bytes(len_buf) as usize;
    if len > MAX_FRAME_BYTES {
        bail!("incoming frame too large: {len} bytes");
    }

    let mut buf = vec![0u8; len];
    reader.read_exact(&mut buf).await?;
    let msg = serde_json::from_slice(&buf).context("failed to decode WireMessage")?;
    Ok(Some(msg))
}

/// Handles a single bidirectional transfer stream initiated by `peer_id`.
#[allow(clippy::too_many_arguments)]
pub async fn handle_incoming_bidi_stream<R, W>(
    peer_id: &str,
    local_key: &SecretKey,
    reader: &mut R,
    writer: &mut W,
    store: &LocalStore,
    config: &EngineConfig,
    auto_receive_dir: &Path,
    events: &broadcast::Sender<EngineEvent>,
    local_lan_addrs: &[String],
) -> Result<()>
where
    R: AsyncRead + Unpin,
    W: AsyncWrite + Unpin,
{
    let Some(first_msg) = read_wire_message(reader).await? else {
        return Ok(());
    };

    match first_msg {
        WireMessage::TextMessage {
            msg_id,
            created_at_ms,
            text,
        } => {
            let record = ChatMessageRecord {
                msg_id: msg_id.clone(),
                room_id: DEFAULT_PERSONAL_ROOM_ID.to_string(),
                peer_id: peer_id.to_string(),
                sender_id: peer_id.to_string(),
                direction: MessageDirection::Incoming,
                kind: MessageKind::Text,
                body_text: Some(text),
                file_name: None,
                file_size: None,
                local_path: None,
                root_blake3: None,
                chunk_size: None,
                total_chunks: None,
                received_bitmap: None,
                status: MessageStatus::Delivered,
                delivery_scope: "delivered_all".to_string(),
                acked_peers: vec![local_key.public().to_string()],
                batch_id: None,
                created_at_ms,
                updated_at_ms: now_millis(),
            };
            store.insert_message(&record)?;
            let _ = events.send(EngineEvent::MessageAdded(record));
            write_wire_message(
                writer,
                &WireMessage::DeliveryAck {
                    msg_id,
                    saved_path: None,
                },
            )
            .await?;
        }
        WireMessage::FileOffer {
            msg_id,
            created_at_ms,
            file_name,
            file_size,
            chunk_size,
            chunk_hashes,
            root_blake3,
            mime_type: _,
            thumbnail_webp: _,
        } => {
            receive_legacy_file_stream(
                peer_id,
                msg_id,
                created_at_ms,
                file_name,
                file_size,
                chunk_size,
                chunk_hashes,
                root_blake3,
                reader,
                writer,
                store,
                config,
                auto_receive_dir,
                events,
            )
            .await?;
        }
        WireMessage::RoomSyncAnnounce {
            room_id,
            room_name,
            room_type,
            retention_days,
            members,
            room_key_hex,
        } => {
            let my_id = local_key.public().to_string();
            // Privacy guard: ignore room announcements that don't include both the sender and us.
            if !members.iter().any(|m| m.node_id == my_id)
                || !members.iter().any(|m| m.node_id == peer_id)
            {
                tracing::warn!(
                    "ignoring RoomSyncAnnounce for {room_id} from {peer_id}: membership check failed"
                );
                return Ok(());
            }

            let effective_room_id = if room_type == "dm" {
                crate::db::store::dm_room_id(&my_id, peer_id)
            } else {
                room_id
            };
            let existing = store.get_room(&effective_room_id)?;
            let existing_ids: std::collections::HashSet<String> = store
                .list_room_members(&effective_room_id)
                .unwrap_or_default()
                .into_iter()
                .map(|m| m.node_id)
                .collect();
            let is_home_node = store.is_home_node_mode();
            let existing_key = existing.as_ref().and_then(|r| r.room_key_hex.clone());
            let existing_name = existing.as_ref().map(|r| r.name.clone());
            let effective_name = if room_type == "dm" {
                let announced = members
                    .iter()
                    .find(|m| m.node_id == peer_id)
                    .map(|m| m.display_name.clone())
                    .filter(|s| !s.trim().is_empty() && s.trim() != "本机设备" && s.trim() != "Paired Device");
                announced
                    .or_else(|| {
                        existing_name.filter(|s| {
                            !s.trim().is_empty() && s.trim() != "本机设备" && s.trim() != "Paired Device"
                        })
                    })
                    .unwrap_or(room_name)
            } else {
                room_name
            };
            let incoming_key = room_key_hex.filter(|k| !k.trim().is_empty());
            let effective_key = if is_home_node {
                None
            } else if room_type == "dm" {
                match (existing_key, incoming_key) {
                    (Some(cur), Some(inc)) if cur != inc && peer_id < my_id.as_str() => Some(inc),
                    (Some(cur), _) => Some(cur),
                    (None, inc) => inc,
                }
            } else {
                existing_key.or(incoming_key)
            };
            let room = RoomRecord {
                room_id: effective_room_id.clone(),
                name: effective_name,
                room_type: room_type.clone(),
                room_key_hex: effective_key,
                is_pinned: room_type == "dm",
                retention_days: retention_days.max(1),
                created_at_ms: now_millis(),
            };
            store.upsert_room(&room)?;
            for m in members {
                store.upsert_room_member(
                    &effective_room_id,
                    &m.node_id,
                    &m.display_name,
                    &m.role,
                )?;
                // Contacts privacy: only add to `peers` for 1v1 DM or if already paired;
                // un-paired third-party group members stay room-scoped only.
                if m.node_id != my_id && (room_type == "dm" || store.has_peer(&m.node_id)) {
                    let _ = store.upsert_peer(&m.node_id, &m.display_name);
                }
                if m.node_id != my_id {
                    store.merge_peer_hints(&m.node_id, &m.lan_addrs, m.endpoint_addr.as_ref());
                    if !existing_ids.contains(&m.node_id) && m.role != "home_node" {
                        let _ = store.backfill_room_outbox_for_member(
                            &effective_room_id,
                            &m.node_id,
                            &my_id,
                        );
                    }
                }
            }
            let _ = events.send(EngineEvent::RoomUpdated {
                room_id: effective_room_id,
            });
            let _ = events.send(EngineEvent::HomeNodeStatsUpdated);
        }
        WireMessage::RoomEnvelopeOffer {
            room_id,
            msg_id,
            sender_id,
            target_peers,
            store_in_locker,
            envelope,
            cipher_file_size,
            chunk_size,
            cipher_chunk_hashes,
            cipher_root_blake3,
            retention_days,
            offer_only,
        } => {
            handle_room_envelope_offer(
                peer_id,
                local_key,
                room_id,
                msg_id,
                sender_id,
                target_peers,
                store_in_locker,
                offer_only,
                envelope,
                cipher_file_size,
                chunk_size,
                cipher_chunk_hashes,
                cipher_root_blake3,
                retention_days,
                reader,
                writer,
                store,
                config,
                auto_receive_dir,
                events,
            )
            .await?;
        }
        WireMessage::FilePullRequest { room_id, msg_id } => {
            if store.is_authorized_room_member(&room_id, peer_id)? {
                let _ = store.mark_outbox_target_pull_requested(&room_id, &msg_id, peer_id)?;
                let _ = events.send(EngineEvent::OutboxRetryRequested {
                    peer_id: peer_id.to_string(),
                });
            }
        }
        WireMessage::RecipientDeliveryAck {
            room_id,
            msg_id,
            recipient_id,
            signature_bytes,
        } => {
            process_recipient_delivery_ack(
                &room_id,
                &msg_id,
                &recipient_id,
                &signature_bytes,
                store,
                events,
            )
            .await?;
        }
        WireMessage::PeerCapabilities {
            lan_probe_addrs, ..
        } => {
            if !lan_probe_addrs.is_empty() {
                store.merge_peer_hints(peer_id, &lan_probe_addrs, None);
            }
            let reply = WireMessage::PeerCapabilities {
                device_name: "local-device".to_string(),
                lan_probe_addrs: local_lan_addrs.to_vec(),
            };
            write_wire_message(writer, &reply).await?;
        }
        WireMessage::ProfileAnnounce {
            display_name,
            avatar_hash,
            known_peer_avatar_hash,
        } => {
            let need_your_avatar = handle_profile_announce(
                peer_id,
                local_key,
                &display_name,
                avatar_hash,
                known_peer_avatar_hash,
                writer,
                store,
                &config.data_dir,
                events,
            )
            .await?;

            if need_your_avatar
                && let Ok(Some(WireMessage::ProfilePush {
                    display_name: push_name,
                    avatar_hash: push_hash,
                    avatar_png: push_png,
                    clear_avatar,
                })) = read_wire_message(reader).await
            {
                let _ = apply_remote_profile_update(
                    store,
                    &config.data_dir,
                    events,
                    peer_id,
                    &push_name,
                    push_hash,
                    push_png,
                    clear_avatar,
                );
            }
        }
        WireMessage::ProfilePush {
            display_name,
            avatar_hash,
            avatar_png,
            clear_avatar,
        } => {
            apply_remote_profile_update(
                store,
                &config.data_dir,
                events,
                peer_id,
                &display_name,
                avatar_hash,
                avatar_png,
                clear_avatar,
            )?;
        }
        WireMessage::RoomMessageRevoke {
            room_id,
            msg_id,
            sender_id,
            target_peers,
            store_in_locker,
            signature_bytes,
        } => {
            handle_room_message_revoke(
                peer_id,
                local_key,
                room_id,
                msg_id,
                sender_id,
                target_peers,
                store_in_locker,
                signature_bytes,
                writer,
                store,
                events,
            )
            .await?;
        }
        other => {
            tracing::warn!("unexpected initial message on transfer stream: {other:?}");
        }
    }

    Ok(())
}

#[allow(clippy::too_many_arguments)]
async fn handle_room_envelope_offer<R, W>(
    peer_id: &str,
    local_key: &SecretKey,
    room_id: String,
    msg_id: String,
    sender_id: String,
    target_peers: Vec<String>,
    store_in_locker: bool,
    offer_only: bool,
    envelope: EncryptedEnvelope,
    cipher_file_size: u64,
    chunk_size: usize,
    cipher_chunk_hashes: Vec<[u8; 32]>,
    cipher_root_blake3: [u8; 32],
    retention_days: u32,
    reader: &mut R,
    writer: &mut W,
    store: &LocalStore,
    config: &EngineConfig,
    auto_receive_dir: &Path,
    events: &broadcast::Sender<EngineEvent>,
) -> Result<()>
where
    R: AsyncRead + Unpin,
    W: AsyncWrite + Unpin,
{
    validate_safe_id(&msg_id)?;
    let my_id = local_key.public().to_string();
    let room_opt = match store.get_room(&room_id)? {
        Some(r) => Some(r),
        None => store.get_room(&crate::db::store::dm_room_id(&my_id, peer_id))?,
    };
    let effective_room_id = room_opt
        .as_ref()
        .map(|r| r.room_id.clone())
        .unwrap_or_else(|| room_id.clone());
    let room_key_opt = room_opt
        .as_ref()
        .and_then(|r| r.room_key_hex.as_deref())
        .and_then(|hex| room_key_from_hex(hex).ok());

    let act_as_blind_locker = store_in_locker || store.is_home_node_mode() || room_key_opt.is_none();

    if store
        .is_message_revoked_by(&msg_id)?
        .is_some_and(|revoker| revoker == sender_id)
    {
        let full = vec![0xFFu8; cipher_chunk_hashes.len().div_ceil(8)];
        write_wire_message(
            writer,
            &WireMessage::ChunkBitmapAck {
                msg_id: msg_id.clone(),
                received_bitmap: full,
                already_complete: true,
            },
        )
        .await?;
        if act_as_blind_locker {
            write_wire_message(
                writer,
                &WireMessage::LockerStoredAck {
                    room_id: room_id.clone(),
                    msg_id: msg_id.clone(),
                    home_node_id: my_id,
                },
            )
            .await?;
        } else {
            let ack = sign_recipient_ack(local_key, &room_id, &msg_id);
            write_wire_message(writer, &ack).await?;
        }
        return Ok(());
    }

    if act_as_blind_locker {
        // Pure zero-knowledge blind locker path (Home Node).
        if room_opt.is_none() {
            store.upsert_room(&RoomRecord {
                room_id: room_id.clone(),
                name: format!("加密房间 {}", &room_id[..room_id.len().min(8)]),
                room_type: "group".to_string(),
                room_key_hex: None,
                is_pinned: false,
                retention_days: retention_days.max(1),
                created_at_ms: now_millis(),
            })?;
        }
        let authorized = store.is_authorized_room_member(&room_id, peer_id)?
            || store.is_authorized_room_member(&room_id, &sender_id)?;
        if !authorized {
            tracing::warn!("blind locker auto-authorizing paired peer={peer_id} room={room_id}");
            store.upsert_room_member(&room_id, peer_id, "Paired Device", "member")?;
        }

        receive_blind_locker_stream(
            local_key,
            room_id,
            msg_id,
            sender_id,
            target_peers,
            envelope,
            cipher_file_size,
            chunk_size,
            cipher_chunk_hashes,
            cipher_root_blake3,
            retention_days,
            reader,
            writer,
            store,
            config,
            events,
        )
        .await
    } else {
        let room_key = room_key_opt.expect("checked Some above");
        let payload = open_envelope(&room_key, &room_id, &sender_id, &msg_id, &envelope)
            .context("failed to decrypt RoomEnvelopeOffer")?;

        if payload.kind == "text" {
            let record = ChatMessageRecord {
                msg_id: msg_id.clone(),
                room_id: effective_room_id.clone(),
                peer_id: sender_id.clone(),
                sender_id: sender_id.clone(),
                direction: MessageDirection::Incoming,
                kind: MessageKind::Text,
                body_text: payload.text,
                file_name: None,
                file_size: None,
                local_path: None,
                root_blake3: None,
                chunk_size: None,
                total_chunks: None,
                received_bitmap: None,
                status: MessageStatus::Delivered,
                delivery_scope: "delivered_all".to_string(),
                acked_peers: vec![local_key.public().to_string()],
                batch_id: payload.batch_id,
                created_at_ms: payload.created_at_ms,
                updated_at_ms: now_millis(),
            };
            store.insert_message(&record)?;
            let _ = events.send(EngineEvent::MessageAdded(record));
            let ack = sign_recipient_ack(local_key, &room_id, &msg_id);
            write_wire_message(writer, &ack).await?;
            return Ok(());
        }

        receive_encrypted_file_stream(
            local_key,
            &room_key,
            effective_room_id,
            msg_id,
            sender_id,
            offer_only,
            payload,
            chunk_size,
            cipher_chunk_hashes,
            reader,
            writer,
            store,
            config,
            auto_receive_dir,
            events,
        )
        .await
    }
}

#[allow(clippy::too_many_arguments)]
async fn receive_blind_locker_stream<R, W>(
    local_key: &SecretKey,
    room_id: String,
    msg_id: String,
    sender_id: String,
    target_peers: Vec<String>,
    envelope: EncryptedEnvelope,
    cipher_file_size: u64,
    chunk_size: usize,
    cipher_chunk_hashes: Vec<[u8; 32]>,
    cipher_root_blake3: [u8; 32],
    retention_days: u32,
    reader: &mut R,
    writer: &mut W,
    store: &LocalStore,
    config: &EngineConfig,
    events: &broadcast::Sender<EngineEvent>,
) -> Result<()>
where
    R: AsyncRead + Unpin,
    W: AsyncWrite + Unpin,
{
    validate_safe_id(&msg_id)?;
    let my_id = local_key.public().to_string();
    let effective_targets: Vec<String> = target_peers
        .into_iter()
        .filter(|t| t != &sender_id && t != &my_id)
        .collect();

    let total_chunks = cipher_chunk_hashes.len();
    let now = now_millis();
    let ttl_days = retention_days.max(1) as i64;
    let envelope_json = serde_json::to_string(&envelope)?;
    let hashes_json = serde_json::to_string(&cipher_chunk_hashes)?;

    let new_item = BlindLockerItem {
        msg_id: msg_id.clone(),
        room_id: room_id.clone(),
        sender_id: sender_id.clone(),
        envelope_json,
        cipher_file_path: None,
        cipher_file_size,
        cipher_root_blake3: Some(cipher_root_blake3.to_vec()),
        chunk_size,
        total_chunks,
        cipher_chunk_hashes_json: Some(hashes_json),
        received_bitmap: Some(ChunkBitmap::empty(total_chunks)),
        status: if total_chunks == 0 {
            "ready".to_string()
        } else {
            "receiving".to_string()
        },
        created_at_ms: now,
        expires_at_ms: now + ttl_days * MS_PER_DAY,
    };

    let (mut bitmap, status) = store.upsert_blind_locker_offer(&new_item, &effective_targets)?;

    if status == "purged" || status == "expired" || (total_chunks == 0 && status == "ready") {
        let full = vec![0xFFu8; total_chunks.div_ceil(8)];
        write_wire_message(
            writer,
            &WireMessage::ChunkBitmapAck {
                msg_id: msg_id.clone(),
                received_bitmap: full,
                already_complete: true,
            },
        )
        .await?;
        write_wire_message(
            writer,
            &WireMessage::LockerStoredAck {
                room_id: room_id.clone(),
                msg_id: msg_id.clone(),
                home_node_id: my_id,
            },
        )
        .await?;
        let _ = events.send(EngineEvent::HomeNodeStatsUpdated);
        if !effective_targets.is_empty() {
            let _ = events.send(EngineEvent::LockerItemReady {
                room_id,
                msg_id,
                target_peers: effective_targets,
            });
        }
        return Ok(());
    }

    if let Some(existing) = store.get_blind_locker_item(&msg_id)?
        && existing.status == "ready"
        && existing
            .cipher_file_path
            .as_ref()
            .is_some_and(|p| Path::new(p).exists())
    {
        let full = vec![0xFFu8; total_chunks.div_ceil(8)];
        write_wire_message(
            writer,
            &WireMessage::ChunkBitmapAck {
                msg_id: msg_id.clone(),
                received_bitmap: full,
                already_complete: true,
            },
        )
        .await?;
        write_wire_message(
            writer,
            &WireMessage::LockerStoredAck {
                room_id: room_id.clone(),
                msg_id: msg_id.clone(),
                home_node_id: my_id,
            },
        )
        .await?;
        return Ok(());
    }

    if bitmap.len() != total_chunks.div_ceil(8) {
        bitmap = ChunkBitmap::empty(total_chunks);
    }

    let already_complete = ChunkBitmap::is_all_set(&bitmap, total_chunks);
    write_wire_message(
        writer,
        &WireMessage::ChunkBitmapAck {
            msg_id: msg_id.clone(),
            received_bitmap: bitmap.clone(),
            already_complete,
        },
    )
    .await?;

    let locker_part_path = config
        .data_dir
        .join("locker_parts")
        .join(format!("{msg_id}.enc.part"));

    while !ChunkBitmap::is_all_set(&bitmap, total_chunks) {
        let Some(frame) = read_wire_message(reader).await? else {
            store.update_blind_locker_bitmap(&msg_id, &bitmap, "receiving", None)?;
            return Ok(());
        };
        if let WireMessage::FileChunk {
            msg_id: chunk_msg_id,
            chunk_index,
            data,
        } = frame
        {
            if chunk_msg_id != msg_id {
                bail!("mismatched msg_id in blind locker FileChunk stream");
            }
            let idx = chunk_index as usize;
            let expected_hash = cipher_chunk_hashes
                .get(idx)
                .context("cipher chunk_index out of bounds")?;
            verify_and_write_chunk(&locker_part_path, idx, chunk_size, expected_hash, &data)
                .await?;
            ChunkBitmap::set(&mut bitmap, idx);
            store.update_blind_locker_bitmap(&msg_id, &bitmap, "receiving", None)?;
        }
    }

    let locker_dir = config.data_dir.join("locker");
    let enc_path = finalize_blind_locker_file(
        &locker_part_path,
        &locker_dir,
        &msg_id,
        cipher_file_size,
        &cipher_root_blake3,
        chunk_size,
    )
    .await?;
    let enc_str = enc_path.to_string_lossy().to_string();
    store.update_blind_locker_bitmap(&msg_id, &bitmap, "ready", Some(&enc_str))?;

    let _ = events.send(EngineEvent::HomeNodeStatsUpdated);
    if !effective_targets.is_empty() {
        let _ = events.send(EngineEvent::LockerItemReady {
            room_id: room_id.clone(),
            msg_id: msg_id.clone(),
            target_peers: effective_targets,
        });
    }

    write_wire_message(
        writer,
        &WireMessage::LockerStoredAck {
            room_id,
            msg_id,
            home_node_id: my_id,
        },
    )
    .await?;
    Ok(())
}

#[allow(clippy::too_many_arguments)]
async fn receive_encrypted_file_stream<R, W>(
    local_key: &SecretKey,
    room_key: &RoomKey,
    room_id: String,
    msg_id: String,
    sender_id: String,
    offer_only: bool,
    payload: PlainEnvelopePayload,
    chunk_size: usize,
    cipher_chunk_hashes: Vec<[u8; 32]>,
    reader: &mut R,
    writer: &mut W,
    store: &LocalStore,
    config: &EngineConfig,
    auto_receive_dir: &Path,
    events: &broadcast::Sender<EngineEvent>,
) -> Result<()>
where
    R: AsyncRead + Unpin,
    W: AsyncWrite + Unpin,
{
    validate_safe_id(&msg_id)?;
    let file_name = payload
        .file_name
        .unwrap_or_else(|| "received_file.bin".to_string());
    let file_size = payload.file_size.unwrap_or(0);
    let plain_root = payload
        .plain_root_blake3
        .context("missing plain_root_blake3 in encrypted file envelope")?;
    let batch_id = payload.batch_id;
    let total_chunks = cipher_chunk_hashes.len();

    let existing = store.get_message(&msg_id)?;
    if let Some(ref rec) = existing
        && rec.status == MessageStatus::Delivered
        && rec
            .local_path
            .as_ref()
            .is_some_and(|p| PathBuf::from(p).exists())
    {
        let full_bitmap = vec![0xFFu8; total_chunks.div_ceil(8)];
        write_wire_message(
            writer,
            &WireMessage::ChunkBitmapAck {
                msg_id: msg_id.clone(),
                received_bitmap: full_bitmap,
                already_complete: true,
            },
        )
        .await?;
        let ack = sign_recipient_ack(local_key, &room_id, &msg_id);
        write_wire_message(writer, &ack).await?;
        return Ok(());
    }

    let mut bitmap = existing
        .as_ref()
        .and_then(|r| r.received_bitmap.clone())
        .filter(|b| b.len() == total_chunks.div_ceil(8))
        .unwrap_or_else(|| ChunkBitmap::empty(total_chunks));

    if offer_only {
        if existing.is_none() {
            let record = ChatMessageRecord {
                msg_id: msg_id.clone(),
                room_id: room_id.clone(),
                peer_id: sender_id.clone(),
                sender_id: sender_id.clone(),
                direction: MessageDirection::Incoming,
                kind: MessageKind::File,
                body_text: None,
                file_name: Some(file_name),
                file_size: Some(file_size),
                local_path: None,
                root_blake3: Some(plain_root.to_vec()),
                chunk_size: Some(chunk_size),
                total_chunks: Some(total_chunks),
                received_bitmap: Some(bitmap.clone()),
                status: MessageStatus::AwaitingDownload,
                delivery_scope: "group_offer".to_string(),
                acked_peers: Vec::new(),
                batch_id: batch_id.clone(),
                created_at_ms: payload.created_at_ms,
                updated_at_ms: now_millis(),
            };
            store.insert_message(&record)?;
            let _ = events.send(EngineEvent::MessageAdded(record));
            let _ = events.send(EngineEvent::RoomUpdated { room_id });
        }
        write_wire_message(
            writer,
            &WireMessage::ChunkBitmapAck {
                msg_id,
                received_bitmap: bitmap,
                already_complete: false,
            },
        )
        .await?;
        return Ok(());
    }

    let defer_bubble =
        existing.is_none() && file_size <= DEFERRED_SMALL_FILE_BUBBLE_THRESHOLD_BYTES;

    if !defer_bubble {
        if existing.is_none() {
            let record = ChatMessageRecord {
                msg_id: msg_id.clone(),
                room_id: room_id.clone(),
                peer_id: sender_id.clone(),
                sender_id: sender_id.clone(),
                direction: MessageDirection::Incoming,
                kind: MessageKind::File,
                body_text: None,
                file_name: Some(file_name.clone()),
                file_size: Some(file_size),
                local_path: None,
                root_blake3: Some(plain_root.to_vec()),
                chunk_size: Some(chunk_size),
                total_chunks: Some(total_chunks),
                received_bitmap: Some(bitmap.clone()),
                status: MessageStatus::Transferring,
                delivery_scope: "direct".to_string(),
                acked_peers: Vec::new(),
                batch_id: batch_id.clone(),
                created_at_ms: payload.created_at_ms,
                updated_at_ms: now_millis(),
            };
            store.insert_message(&record)?;
            let _ = events.send(EngineEvent::MessageAdded(record));
        } else {
            store.update_transfer_progress(
                &msg_id,
                MessageStatus::Transferring,
                Some(&bitmap),
                None,
            )?;
        }
    }

    let already_complete = ChunkBitmap::is_all_set(&bitmap, total_chunks);
    write_wire_message(
        writer,
        &WireMessage::ChunkBitmapAck {
            msg_id: msg_id.clone(),
            received_bitmap: bitmap.clone(),
            already_complete,
        },
    )
    .await?;

    let part_path = config.data_dir.join("parts").join(format!("{msg_id}.part"));

    while !ChunkBitmap::is_all_set(&bitmap, total_chunks) {
        let frame_res = match tokio::time::timeout(WIRE_CHUNK_TIMEOUT, read_wire_message(reader)).await {
            Ok(Ok(res)) => res,
            Ok(Err(e)) => {
                if defer_bubble {
                    let _ = tokio::fs::remove_file(&part_path).await;
                } else {
                    let _ = store.update_transfer_progress(
                        &msg_id,
                        MessageStatus::PausedReconnecting,
                        Some(&bitmap),
                        None,
                    );
                }
                return Err(e);
            }
            Err(_) => {
                if defer_bubble {
                    let _ = tokio::fs::remove_file(&part_path).await;
                } else {
                    store.update_transfer_progress(
                        &msg_id,
                        MessageStatus::PausedReconnecting,
                        Some(&bitmap),
                        None,
                    )?;
                }
                bail!("timed out waiting for FileChunk on {msg_id}");
            }
        };
        let Some(frame) = frame_res else {
            if defer_bubble {
                let _ = tokio::fs::remove_file(&part_path).await;
            } else {
                store.update_transfer_progress(
                    &msg_id,
                    MessageStatus::PausedReconnecting,
                    Some(&bitmap),
                    None,
                )?;
            }
            return Ok(());
        };

        if let WireMessage::FileChunk {
            msg_id: chunk_msg_id,
            chunk_index,
            data,
        } = frame
        {
            if chunk_msg_id != msg_id {
                if defer_bubble {
                    let _ = tokio::fs::remove_file(&part_path).await;
                }
                bail!("mismatched msg_id in encrypted FileChunk stream");
            }
            let idx = chunk_index as usize;
            let expected_cipher = cipher_chunk_hashes
                .get(idx)
                .context("cipher chunk_index out of bounds")?;
            let expected_plain = payload
                .plain_chunk_hashes
                .get(idx)
                .context("plain chunk_index out of bounds")?;

            if let Err(e) = verify_decrypt_and_write_chunk(
                &part_path,
                idx,
                chunk_size,
                expected_cipher,
                expected_plain,
                room_key,
                &room_id,
                &msg_id,
                &data,
            )
            .await
            {
                if defer_bubble {
                    let _ = tokio::fs::remove_file(&part_path).await;
                }
                return Err(e);
            }

            ChunkBitmap::set(&mut bitmap, idx);
            if !defer_bubble {
                let completed_chunks = (0..total_chunks)
                    .filter(|&i| ChunkBitmap::is_set(&bitmap, i))
                    .count();
                if completed_chunks % 4 == 0 || completed_chunks == total_chunks {
                    store.update_transfer_progress(
                        &msg_id,
                        MessageStatus::Transferring,
                        Some(&bitmap),
                        None,
                    )?;
                }

                if completed_chunks % 16 == 0 || completed_chunks == total_chunks {
                    let _ = events.send(EngineEvent::TransferProgress {
                        msg_id: msg_id.clone(),
                        completed_chunks,
                        total_chunks,
                        status: MessageStatus::Transferring,
                        local_path: None,
                    });
                }
            }
        }
    }

    let monthly_receive_dir = auto_receive_dir.join(store.local_year_month());
    let final_path = match finalize_part_file(
        &part_path,
        &monthly_receive_dir,
        &file_name,
        file_size,
        &plain_root,
        chunk_size,
    )
    .await
    {
        Ok(p) => p,
        Err(e) => {
            if defer_bubble {
                let _ = tokio::fs::remove_file(&part_path).await;
            }
            return Err(e);
        }
    };
    let saved_str = final_path.to_string_lossy().to_string();

    if defer_bubble {
        let record = ChatMessageRecord {
            msg_id: msg_id.clone(),
            room_id: room_id.clone(),
            peer_id: sender_id.clone(),
            sender_id,
            direction: MessageDirection::Incoming,
            kind: MessageKind::File,
            body_text: None,
            file_name: Some(file_name),
            file_size: Some(file_size),
            local_path: Some(saved_str.clone()),
            root_blake3: Some(plain_root.to_vec()),
            chunk_size: Some(chunk_size),
            total_chunks: Some(total_chunks),
            received_bitmap: Some(bitmap),
            status: MessageStatus::Delivered,
            delivery_scope: "direct".to_string(),
            acked_peers: Vec::new(),
            batch_id,
            created_at_ms: payload.created_at_ms,
            updated_at_ms: now_millis(),
        };
        store.insert_message(&record)?;
        let _ = events.send(EngineEvent::MessageAdded(record));
    } else {
        store.update_transfer_progress(
            &msg_id,
            MessageStatus::Delivered,
            Some(&bitmap),
            Some(&saved_str),
        )?;
        if let Ok(Some(updated)) = store.get_message(&msg_id) {
            let _ = events.send(EngineEvent::MessageAdded(updated));
        }
    }
    let _ = events.send(EngineEvent::RoomUpdated {
        room_id: room_id.clone(),
    });
    let _ = events.send(EngineEvent::TransferProgress {
        msg_id: msg_id.clone(),
        completed_chunks: total_chunks,
        total_chunks,
        status: MessageStatus::Delivered,
        local_path: Some(saved_str),
    });

    let ack = sign_recipient_ack(local_key, &room_id, &msg_id);
    write_wire_message(writer, &ack).await?;
    Ok(())
}

/// Processes a `RecipientDeliveryAck`, verifies Ed25519 signature, updates sender outbox,
/// and if this device is a blind locker and all targets ACKed, **immediately removes `.enc` from disk**.
pub async fn process_recipient_delivery_ack(
    room_id: &str,
    msg_id: &str,
    recipient_id: &str,
    signature_bytes: &[u8],
    store: &LocalStore,
    events: &broadcast::Sender<EngineEvent>,
) -> Result<()> {
    verify_recipient_ack(room_id, msg_id, recipient_id, signature_bytes)?;

    // 1. Update local Home Node blind locker checklist and purge `.enc` if all targets ACKed.
    let (purged, path_to_delete) =
        store.ack_blind_locker_recipient(msg_id, recipient_id, Some(signature_bytes))?;
    if purged {
        if let Some(ref p) = path_to_delete {
            match tokio::fs::remove_file(p).await {
                Ok(_) => tracing::info!("blind locker purged cached payload after full ACK: {p}"),
                Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
                Err(e) => tracing::warn!("failed to remove purged blind locker file {p}: {e}"),
            }
        }
        let _ = events.send(EngineEvent::HomeNodeStatsUpdated);
    }

    // 2. If local device is the original sender (or tracks this outbox message), update delivery status.
    let all_delivered = store.mark_outbox_target_status(msg_id, recipient_id, "delivered")?;
    if let Some(rec) = store.get_message(msg_id)? {
        if all_delivered {
            let total = rec.total_chunks.unwrap_or(1);
            let _ = events.send(EngineEvent::TransferProgress {
                msg_id: msg_id.to_string(),
                completed_chunks: total,
                total_chunks: total,
                status: MessageStatus::Delivered,
                local_path: rec.local_path.clone(),
            });
        }
        let _ = events.send(EngineEvent::MessageAdded(rec));
    }
    let _ = events.send(EngineEvent::RoomUpdated {
        room_id: room_id.to_string(),
    });
    Ok(())
}

/// Sends an encrypted room outbox job to either a direct recipient or a blind Home Node.
pub async fn send_room_outbox_job<R, W>(
    job: &PendingRoomOutboxJob,
    peer_id: &str,
    local_key: &SecretKey,
    reader: &mut R,
    writer: &mut W,
    store: &LocalStore,
    config: &EngineConfig,
    events: &broadcast::Sender<EngineEvent>,
) -> Result<()>
where
    R: AsyncRead + Unpin,
    W: AsyncWrite + Unpin,
{
    let record = &job.message;
    let room = store
        .get_room(&record.room_id)?
        .context("missing room for outgoing message")?;
    let room_key_hex = room
        .room_key_hex
        .as_deref()
        .context("cannot send room message without room_key")?;
    let room_key = room_key_from_hex(room_key_hex)?;
    let sender_id = local_key.public().to_string();

    match record.kind {
        MessageKind::Text => {
            let text = record.body_text.clone().unwrap_or_default();
            let plain = PlainEnvelopePayload {
                kind: "text".to_string(),
                text: Some(text),
                file_name: None,
                file_size: None,
                plain_root_blake3: None,
                plain_chunk_hashes: Vec::new(),
                created_at_ms: record.created_at_ms,
                batch_id: record.batch_id.clone(),
            };
            let envelope =
                seal_envelope(&room_key, &record.room_id, &sender_id, &record.msg_id, &plain)?;

            store.update_transfer_progress(&record.msg_id, MessageStatus::Transferring, None, None)?;
            write_wire_message(
                writer,
                &WireMessage::RoomEnvelopeOffer {
                    room_id: record.room_id.clone(),
                    msg_id: record.msg_id.clone(),
                    sender_id,
                    target_peers: job.target_peers.clone(),
                    store_in_locker: job.store_in_locker,
                    envelope,
                    cipher_file_size: 0,
                    chunk_size: config.chunk_size_bytes,
                    cipher_chunk_hashes: Vec::new(),
                    cipher_root_blake3: [0u8; 32],
                    retention_days: room.retention_days,
                    offer_only: false,
                },
            )
            .await?;

            if job.store_in_locker {
                // Blind locker replies with ChunkBitmapAck(already_complete=true) then LockerStoredAck.
                let first = tokio::time::timeout(WIRE_CTRL_TIMEOUT, read_wire_message(reader))
                    .await
                    .context("timed out waiting for locker text bitmap ACK")??;
                let second = match first {
                    Some(WireMessage::ChunkBitmapAck { .. }) => {
                        tokio::time::timeout(WIRE_CTRL_TIMEOUT, read_wire_message(reader))
                            .await
                            .context("timed out waiting for LockerStoredAck on text message")??
                    }
                    other => other,
                };
                match second {
                    Some(WireMessage::LockerStoredAck { .. }) => {
                        store.mark_locker_upload_stored(
                            &record.msg_id,
                            peer_id,
                            &job.target_peers,
                        )?;
                        if let Ok(Some(updated)) = store.get_message(&record.msg_id) {
                            let _ = events.send(EngineEvent::MessageAdded(updated));
                        }
                        let _ = events.send(EngineEvent::RoomUpdated {
                            room_id: record.room_id.clone(),
                        });
                    }
                    _ => bail!("expected LockerStoredAck for locker text message"),
                }
            } else {
                match tokio::time::timeout(WIRE_CTRL_TIMEOUT, read_wire_message(reader))
                    .await
                    .context("timed out waiting for RecipientDeliveryAck on text message")??
                {
                    Some(WireMessage::RecipientDeliveryAck {
                        room_id,
                        msg_id,
                        recipient_id,
                        signature_bytes,
                    }) => {
                        process_recipient_delivery_ack(
                            &room_id,
                            &msg_id,
                            &recipient_id,
                            &signature_bytes,
                            store,
                            events,
                        )
                        .await?;
                    }
                    _ => bail!("expected RecipientDeliveryAck for room text message"),
                }
            }
        }
        MessageKind::File => {
            let Some(local_path_str) = record.local_path.as_ref() else {
                store.update_transfer_progress(
                    &record.msg_id,
                    MessageStatus::FailedSourceMissing,
                    None,
                    None,
                )?;
                bail!("missing local_path for outgoing room file {}", record.msg_id);
            };
            let src_path = PathBuf::from(local_path_str);
            if !src_path.exists() {
                store.update_transfer_progress(
                    &record.msg_id,
                    MessageStatus::FailedSourceMissing,
                    None,
                    None,
                )?;
                let _ = events.send(EngineEvent::TransferProgress {
                    msg_id: record.msg_id.clone(),
                    completed_chunks: 0,
                    total_chunks: record.total_chunks.unwrap_or(0),
                    status: MessageStatus::FailedSourceMissing,
                    local_path: None,
                });
                return Ok(());
            }

            let chunk_size = record.chunk_size.unwrap_or(config.chunk_size_bytes);
            let indexed = index_encrypted_file(
                &src_path,
                chunk_size,
                &room_key,
                &record.room_id,
                &record.msg_id,
            )
            .await?;
            let total_chunks = indexed.cipher_chunk_hashes.len();
            let file_name = record
                .file_name
                .clone()
                .unwrap_or_else(|| "file.bin".to_string());

            let plain = PlainEnvelopePayload {
                kind: "file".to_string(),
                text: None,
                file_name: Some(file_name),
                file_size: Some(indexed.file_size),
                plain_root_blake3: Some(indexed.plain_root_blake3),
                plain_chunk_hashes: indexed.plain_chunk_hashes,
                created_at_ms: record.created_at_ms,
                batch_id: record.batch_id.clone(),
            };
            let envelope =
                seal_envelope(&room_key, &record.room_id, &sender_id, &record.msg_id, &plain)?;

            if !job.offer_only {
                store.update_transfer_progress(&record.msg_id, MessageStatus::Handshaking, None, None)?;
                let _ = events.send(EngineEvent::TransferProgress {
                    msg_id: record.msg_id.clone(),
                    completed_chunks: 0,
                    total_chunks,
                    status: MessageStatus::Handshaking,
                    local_path: None,
                });
            }

            write_wire_message(
                writer,
                &WireMessage::RoomEnvelopeOffer {
                    room_id: record.room_id.clone(),
                    msg_id: record.msg_id.clone(),
                    sender_id,
                    target_peers: job.target_peers.clone(),
                    store_in_locker: job.store_in_locker,
                    envelope,
                    cipher_file_size: indexed.file_size,
                    chunk_size,
                    cipher_chunk_hashes: indexed.cipher_chunk_hashes,
                    cipher_root_blake3: indexed.cipher_root_blake3,
                    retention_days: room.retention_days,
                    offer_only: job.offer_only,
                },
            )
            .await?;

            let Some(WireMessage::ChunkBitmapAck {
                received_bitmap,
                already_complete,
                ..
            }) = tokio::time::timeout(WIRE_CTRL_TIMEOUT, read_wire_message(reader))
                .await
                .context("timed out waiting for ChunkBitmapAck")??
            else {
                bail!("expected ChunkBitmapAck after RoomEnvelopeOffer");
            };

            if job.offer_only {
                let target_status = if already_complete {
                    "delivered"
                } else {
                    "awaiting_pull"
                };
                store.mark_outbox_target_status(&record.msg_id, peer_id, target_status)?;
                if let Some(updated) = store.get_message(&record.msg_id)? {
                    let _ = events.send(EngineEvent::MessageAdded(updated));
                }
                let _ = events.send(EngineEvent::RoomUpdated {
                    room_id: record.room_id.clone(),
                });
                return Ok(());
            }

            if !already_complete {
                store.update_transfer_progress(
                    &record.msg_id,
                    MessageStatus::Transferring,
                    Some(&received_bitmap),
                    None,
                )?;
                let missing = ChunkBitmap::missing_indices(&received_bitmap, total_chunks);
                let mut completed = total_chunks.saturating_sub(missing.len());

                for idx in missing {
                    let cipher_chunk = read_encrypted_chunk(
                        &src_path,
                        idx,
                        chunk_size,
                        &room_key,
                        &record.room_id,
                        &record.msg_id,
                    )
                    .await?;
                    tokio::time::timeout(
                        WIRE_CHUNK_TIMEOUT,
                        write_wire_message(
                            writer,
                            &WireMessage::FileChunk {
                                msg_id: record.msg_id.clone(),
                                chunk_index: idx as u32,
                                data: cipher_chunk,
                            },
                        ),
                    )
                    .await
                    .context("timed out writing FileChunk")??;
                    completed += 1;
                    if completed % 16 == 0 || completed == total_chunks {
                        let _ = events.send(EngineEvent::TransferProgress {
                            msg_id: record.msg_id.clone(),
                            completed_chunks: completed,
                            total_chunks,
                            status: MessageStatus::Transferring,
                            local_path: None,
                        });
                    }
                }
            }

            if job.store_in_locker {
                match tokio::time::timeout(WIRE_FINAL_ACK_TIMEOUT, read_wire_message(reader))
                    .await
                    .context("timed out waiting for LockerStoredAck")??
                {
                    Some(WireMessage::LockerStoredAck { .. }) => {
                        store.mark_locker_upload_stored(
                            &record.msg_id,
                            peer_id,
                            &job.target_peers,
                        )?;
                        if let Ok(Some(updated)) = store.get_message(&record.msg_id) {
                            let _ = events.send(EngineEvent::MessageAdded(updated));
                        }
                        let _ = events.send(EngineEvent::RoomUpdated {
                            room_id: record.room_id.clone(),
                        });
                    }
                    _ => bail!("expected LockerStoredAck after sending encrypted chunks"),
                }
            } else {
                match tokio::time::timeout(WIRE_FINAL_ACK_TIMEOUT, read_wire_message(reader))
                    .await
                    .context("timed out waiting for RecipientDeliveryAck")??
                {
                    Some(WireMessage::RecipientDeliveryAck {
                        room_id,
                        msg_id,
                        recipient_id,
                        signature_bytes,
                    }) => {
                        process_recipient_delivery_ack(
                            &room_id,
                            &msg_id,
                            &recipient_id,
                            &signature_bytes,
                            store,
                            events,
                        )
                        .await?;
                    }
                    _ => bail!("expected RecipientDeliveryAck after sending encrypted chunks"),
                }
            }
        }
    }

    Ok(())
}

/// Pushes a cached blind locker item from the Home Node to an online `target_peer_id`
/// without ever decrypting the envelope or file chunks.
pub async fn deliver_blind_locker_item_to_peer<R, W>(
    item: &BlindLockerItem,
    pending_targets: &[String],
    target_peer_id: &str,
    reader: &mut R,
    writer: &mut W,
    store: &LocalStore,
    events: &broadcast::Sender<EngineEvent>,
) -> Result<()>
where
    R: AsyncRead + Unpin,
    W: AsyncWrite + Unpin,
{
    let envelope: EncryptedEnvelope =
        serde_json::from_str(&item.envelope_json).context("corrupted blind locker envelope")?;
    let cipher_chunk_hashes: Vec<[u8; 32]> = item
        .cipher_chunk_hashes_json
        .as_deref()
        .map(serde_json::from_str)
        .transpose()?
        .unwrap_or_default();
    let mut cipher_root_blake3 = [0u8; 32];
    if let Some(ref root) = item.cipher_root_blake3
        && root.len() == 32
    {
        cipher_root_blake3.copy_from_slice(root);
    }

    write_wire_message(
        writer,
        &WireMessage::RoomEnvelopeOffer {
            room_id: item.room_id.clone(),
            msg_id: item.msg_id.clone(),
            sender_id: item.sender_id.clone(),
            target_peers: pending_targets.to_vec(),
            store_in_locker: false,
            envelope,
            cipher_file_size: item.cipher_file_size,
            chunk_size: item.chunk_size,
            cipher_chunk_hashes: cipher_chunk_hashes.clone(),
            cipher_root_blake3,
            retention_days: 7,
            offer_only: false,
        },
    )
    .await?;

    if item.total_chunks > 0 {
        let Some(enc_path_str) = item.cipher_file_path.as_ref() else {
            bail!("blind locker item {} missing cipher_file_path", item.msg_id);
        };
        let enc_path = Path::new(enc_path_str);
        if !enc_path.exists() {
            bail!("blind locker cached file missing on disk: {enc_path_str}");
        }

        let Some(WireMessage::ChunkBitmapAck {
            received_bitmap,
            already_complete,
            ..
        }) = tokio::time::timeout(WIRE_CTRL_TIMEOUT, read_wire_message(reader))
            .await
            .context("timed out waiting for blind locker ChunkBitmapAck")??
        else {
            bail!("expected ChunkBitmapAck from recipient {target_peer_id}");
        };

        if !already_complete {
            let missing = ChunkBitmap::missing_indices(&received_bitmap, item.total_chunks);
            for idx in missing {
                let data = read_chunk(enc_path, idx, item.chunk_size).await?;
                write_wire_message(
                    writer,
                    &WireMessage::FileChunk {
                        msg_id: item.msg_id.clone(),
                        chunk_index: idx as u32,
                        data,
                    },
                )
                .await?;
            }
        }
    }

    match tokio::time::timeout(WIRE_FINAL_ACK_TIMEOUT, read_wire_message(reader))
        .await
        .context("timed out waiting for blind locker RecipientDeliveryAck")??
    {
        Some(WireMessage::RecipientDeliveryAck {
            room_id,
            msg_id,
            recipient_id,
            signature_bytes,
        }) => {
            if recipient_id != target_peer_id {
                tracing::warn!(
                    "RecipientDeliveryAck signer {recipient_id} differed from target {target_peer_id}"
                );
            }
            process_recipient_delivery_ack(
                &room_id,
                &msg_id,
                &recipient_id,
                &signature_bytes,
                store,
                events,
            )
            .await?;
            let _ = events.send(EngineEvent::LockerItemReady {
                room_id: item.room_id.clone(),
                msg_id: item.msg_id.clone(),
                target_peers: vec![item.sender_id.clone()],
            });
        }
        other => bail!("expected RecipientDeliveryAck from {target_peer_id}, got {other:?}"),
    }

    Ok(())
}

/// Forwards a previously recorded `RecipientDeliveryAck` from the Home Node back to the original sender.
pub async fn forward_locker_ack_to_sender<W: AsyncWrite + Unpin>(
    ack: &UnforwardedLockerAck,
    writer: &mut W,
    store: &LocalStore,
) -> Result<()> {
    write_wire_message(
        writer,
        &WireMessage::RecipientDeliveryAck {
            room_id: ack.room_id.clone(),
            msg_id: ack.msg_id.clone(),
            recipient_id: ack.target_peer_id.clone(),
            signature_bytes: ack.signature_bytes.clone(),
        },
    )
    .await?;
    store.mark_locker_ack_forwarded(&ack.msg_id, &ack.target_peer_id)?;
    Ok(())
}

// -----------------------------------------------------------------------------
// Phase 1 Legacy Direct Transfer Handlers (kept intact for compatibility)
// -----------------------------------------------------------------------------

#[allow(clippy::too_many_arguments)]
async fn receive_legacy_file_stream<R, W>(
    peer_id: &str,
    msg_id: String,
    created_at_ms: i64,
    file_name: String,
    file_size: u64,
    chunk_size: usize,
    chunk_hashes: Vec<[u8; 32]>,
    root_blake3: [u8; 32],
    reader: &mut R,
    writer: &mut W,
    store: &LocalStore,
    config: &EngineConfig,
    auto_receive_dir: &Path,
    events: &broadcast::Sender<EngineEvent>,
) -> Result<()>
where
    R: AsyncRead + Unpin,
    W: AsyncWrite + Unpin,
{
    validate_safe_id(&msg_id)?;
    let total_chunks = chunk_hashes.len();
    let existing = store.get_message(&msg_id)?;

    if let Some(ref rec) = existing
        && rec.status == MessageStatus::Delivered
        && rec
            .local_path
            .as_ref()
            .is_some_and(|p| PathBuf::from(p).exists())
    {
        let full_bitmap = vec![0xFFu8; total_chunks.div_ceil(8)];
        write_wire_message(
            writer,
            &WireMessage::ChunkBitmapAck {
                msg_id: msg_id.clone(),
                received_bitmap: full_bitmap,
                already_complete: true,
            },
        )
        .await?;
        write_wire_message(
            writer,
            &WireMessage::DeliveryAck {
                msg_id,
                saved_path: rec.local_path.clone(),
            },
        )
        .await?;
        return Ok(());
    }

    let mut bitmap = existing
        .as_ref()
        .and_then(|r| r.received_bitmap.clone())
        .filter(|b| b.len() == total_chunks.div_ceil(8))
        .unwrap_or_else(|| ChunkBitmap::empty(total_chunks));

    let defer_bubble =
        existing.is_none() && file_size <= DEFERRED_SMALL_FILE_BUBBLE_THRESHOLD_BYTES;

    if !defer_bubble {
        if existing.is_none() {
            let record = ChatMessageRecord {
                msg_id: msg_id.clone(),
                room_id: DEFAULT_PERSONAL_ROOM_ID.to_string(),
                peer_id: peer_id.to_string(),
                sender_id: peer_id.to_string(),
                direction: MessageDirection::Incoming,
                kind: MessageKind::File,
                body_text: None,
                file_name: Some(file_name.clone()),
                file_size: Some(file_size),
                local_path: None,
                root_blake3: Some(root_blake3.to_vec()),
                chunk_size: Some(chunk_size),
                total_chunks: Some(total_chunks),
                received_bitmap: Some(bitmap.clone()),
                status: MessageStatus::Transferring,
                delivery_scope: "direct".to_string(),
                acked_peers: Vec::new(),
                batch_id: None,
                created_at_ms,
                updated_at_ms: now_millis(),
            };
            store.insert_message(&record)?;
            let _ = events.send(EngineEvent::MessageAdded(record));
        } else {
            store.update_transfer_progress(
                &msg_id,
                MessageStatus::Transferring,
                Some(&bitmap),
                None,
            )?;
        }
    }

    let already_complete = ChunkBitmap::is_all_set(&bitmap, total_chunks);
    write_wire_message(
        writer,
        &WireMessage::ChunkBitmapAck {
            msg_id: msg_id.clone(),
            received_bitmap: bitmap.clone(),
            already_complete,
        },
    )
    .await?;

    let part_path = config.data_dir.join("parts").join(format!("{msg_id}.part"));

    while !ChunkBitmap::is_all_set(&bitmap, total_chunks) {
        let frame_res = match tokio::time::timeout(WIRE_CHUNK_TIMEOUT, read_wire_message(reader)).await {
            Ok(Ok(res)) => res,
            Ok(Err(e)) => {
                if defer_bubble {
                    let _ = tokio::fs::remove_file(&part_path).await;
                } else {
                    let _ = store.update_transfer_progress(
                        &msg_id,
                        MessageStatus::PausedReconnecting,
                        Some(&bitmap),
                        None,
                    );
                }
                return Err(e);
            }
            Err(_) => {
                if defer_bubble {
                    let _ = tokio::fs::remove_file(&part_path).await;
                } else {
                    store.update_transfer_progress(
                        &msg_id,
                        MessageStatus::PausedReconnecting,
                        Some(&bitmap),
                        None,
                    )?;
                }
                bail!("timed out waiting for FileChunk on {msg_id}");
            }
        };
        let Some(frame) = frame_res else {
            if defer_bubble {
                let _ = tokio::fs::remove_file(&part_path).await;
            } else {
                store.update_transfer_progress(
                    &msg_id,
                    MessageStatus::PausedReconnecting,
                    Some(&bitmap),
                    None,
                )?;
            }
            return Ok(());
        };

        if let WireMessage::FileChunk {
            msg_id: chunk_msg_id,
            chunk_index,
            data,
        } = frame
        {
            if chunk_msg_id != msg_id {
                if defer_bubble {
                    let _ = tokio::fs::remove_file(&part_path).await;
                }
                bail!("mismatched msg_id in FileChunk stream");
            }
            let idx = chunk_index as usize;
            let expected_hash = chunk_hashes
                .get(idx)
                .context("chunk_index out of bounds")?;
            if let Err(e) =
                verify_and_write_chunk(&part_path, idx, chunk_size, expected_hash, &data).await
            {
                if defer_bubble {
                    let _ = tokio::fs::remove_file(&part_path).await;
                }
                return Err(e);
            }
            ChunkBitmap::set(&mut bitmap, idx);

            if !defer_bubble {
                store.update_transfer_progress(
                    &msg_id,
                    MessageStatus::Transferring,
                    Some(&bitmap),
                    None,
                )?;

                let completed_chunks = (0..total_chunks)
                    .filter(|&i| ChunkBitmap::is_set(&bitmap, i))
                    .count();
                if completed_chunks % 16 == 0 || completed_chunks == total_chunks {
                    let _ = events.send(EngineEvent::TransferProgress {
                        msg_id: msg_id.clone(),
                        completed_chunks,
                        total_chunks,
                        status: MessageStatus::Transferring,
                        local_path: None,
                    });
                }
            }
        }
    }

    let monthly_receive_dir = auto_receive_dir.join(store.local_year_month());
    let final_path = match finalize_part_file(
        &part_path,
        &monthly_receive_dir,
        &file_name,
        file_size,
        &root_blake3,
        chunk_size,
    )
    .await
    {
        Ok(p) => p,
        Err(e) => {
            if defer_bubble {
                let _ = tokio::fs::remove_file(&part_path).await;
            }
            return Err(e);
        }
    };
    let saved_str = final_path.to_string_lossy().to_string();

    if defer_bubble {
        let record = ChatMessageRecord {
            msg_id: msg_id.clone(),
            room_id: DEFAULT_PERSONAL_ROOM_ID.to_string(),
            peer_id: peer_id.to_string(),
            sender_id: peer_id.to_string(),
            direction: MessageDirection::Incoming,
            kind: MessageKind::File,
            body_text: None,
            file_name: Some(file_name),
            file_size: Some(file_size),
            local_path: Some(saved_str.clone()),
            root_blake3: Some(root_blake3.to_vec()),
            chunk_size: Some(chunk_size),
            total_chunks: Some(total_chunks),
            received_bitmap: Some(bitmap),
            status: MessageStatus::Delivered,
            delivery_scope: "direct".to_string(),
            acked_peers: Vec::new(),
            batch_id: None,
            created_at_ms,
            updated_at_ms: now_millis(),
        };
        store.insert_message(&record)?;
        let _ = events.send(EngineEvent::MessageAdded(record));
    } else {
        store.update_transfer_progress(
            &msg_id,
            MessageStatus::Delivered,
            Some(&bitmap),
            Some(&saved_str),
        )?;
        if let Ok(Some(updated)) = store.get_message(&msg_id) {
            let _ = events.send(EngineEvent::MessageAdded(updated));
        }
    }
    let _ = events.send(EngineEvent::RoomUpdated {
        room_id: DEFAULT_PERSONAL_ROOM_ID.to_string(),
    });
    let _ = events.send(EngineEvent::TransferProgress {
        msg_id: msg_id.clone(),
        completed_chunks: total_chunks,
        total_chunks,
        status: MessageStatus::Delivered,
        local_path: Some(saved_str.clone()),
    });

    write_wire_message(
        writer,
        &WireMessage::DeliveryAck {
            msg_id,
            saved_path: Some(saved_str),
        },
    )
    .await?;

    Ok(())
}

/// Sends a single legacy queued record (`Text` or `File`) over a newly opened bidirectional stream.
pub async fn send_queued_record<R, W>(
    record: &ChatMessageRecord,
    reader: &mut R,
    writer: &mut W,
    store: &LocalStore,
    config: &EngineConfig,
    events: &broadcast::Sender<EngineEvent>,
) -> Result<()>
where
    R: AsyncRead + Unpin,
    W: AsyncWrite + Unpin,
{
    match record.kind {
        MessageKind::Text => {
            let text = record.body_text.clone().unwrap_or_default();
            store.update_transfer_progress(&record.msg_id, MessageStatus::Transferring, None, None)?;
            write_wire_message(
                writer,
                &WireMessage::TextMessage {
                    msg_id: record.msg_id.clone(),
                    created_at_ms: record.created_at_ms,
                    text,
                },
            )
            .await?;

            match read_wire_message(reader).await? {
                Some(WireMessage::DeliveryAck { .. }) => {
                    store.update_transfer_progress(
                        &record.msg_id,
                        MessageStatus::Delivered,
                        None,
                        None,
                    )?;
                    let _ = events.send(EngineEvent::TransferProgress {
                        msg_id: record.msg_id.clone(),
                        completed_chunks: 1,
                        total_chunks: 1,
                        status: MessageStatus::Delivered,
                        local_path: None,
                    });
                }
                _ => bail!("expected DeliveryAck for text message"),
            }
        }
        MessageKind::File => {
            let Some(local_path_str) = record.local_path.as_ref() else {
                store.update_transfer_progress(
                    &record.msg_id,
                    MessageStatus::FailedSourceMissing,
                    None,
                    None,
                )?;
                bail!("missing local_path for outgoing file {}", record.msg_id);
            };
            let src_path = PathBuf::from(local_path_str);
            if !src_path.exists() {
                store.update_transfer_progress(
                    &record.msg_id,
                    MessageStatus::FailedSourceMissing,
                    None,
                    None,
                )?;
                let _ = events.send(EngineEvent::TransferProgress {
                    msg_id: record.msg_id.clone(),
                    completed_chunks: 0,
                    total_chunks: record.total_chunks.unwrap_or(0),
                    status: MessageStatus::FailedSourceMissing,
                    local_path: None,
                });
                return Ok(());
            }

            let chunk_size = record.chunk_size.unwrap_or(config.chunk_size_bytes);
            let indexed = index_file(&src_path, chunk_size).await?;
            let total_chunks = indexed.chunk_hashes.len();
            let file_name = record
                .file_name
                .clone()
                .unwrap_or_else(|| "file.bin".to_string());

            store.update_transfer_progress(&record.msg_id, MessageStatus::Handshaking, None, None)?;
            let _ = events.send(EngineEvent::TransferProgress {
                msg_id: record.msg_id.clone(),
                completed_chunks: 0,
                total_chunks,
                status: MessageStatus::Handshaking,
                local_path: None,
            });
            write_wire_message(
                writer,
                &WireMessage::FileOffer {
                    msg_id: record.msg_id.clone(),
                    created_at_ms: record.created_at_ms,
                    file_name,
                    file_size: indexed.file_size,
                    chunk_size,
                    chunk_hashes: indexed.chunk_hashes,
                    root_blake3: indexed.root_blake3,
                    mime_type: None,
                    thumbnail_webp: None,
                },
            )
            .await?;

            let Some(WireMessage::ChunkBitmapAck {
                received_bitmap,
                already_complete,
                ..
            }) = read_wire_message(reader).await?
            else {
                bail!("expected ChunkBitmapAck after FileOffer");
            };

            if !already_complete {
                store.update_transfer_progress(
                    &record.msg_id,
                    MessageStatus::Transferring,
                    Some(&received_bitmap),
                    None,
                )?;

                let missing = ChunkBitmap::missing_indices(&received_bitmap, total_chunks);
                let mut completed = total_chunks.saturating_sub(missing.len());

                for idx in missing {
                    let data = read_chunk(&src_path, idx, chunk_size).await?;
                    write_wire_message(
                        writer,
                        &WireMessage::FileChunk {
                            msg_id: record.msg_id.clone(),
                            chunk_index: idx as u32,
                            data,
                        },
                    )
                    .await?;
                    completed += 1;
                    if completed % 16 == 0 || completed == total_chunks {
                        let _ = events.send(EngineEvent::TransferProgress {
                            msg_id: record.msg_id.clone(),
                            completed_chunks: completed,
                            total_chunks,
                            status: MessageStatus::Transferring,
                            local_path: None,
                        });
                    }
                }
            }

            match read_wire_message(reader).await? {
                Some(WireMessage::DeliveryAck { .. }) => {
                    store.update_transfer_progress(
                        &record.msg_id,
                        MessageStatus::Delivered,
                        None,
                        None,
                    )?;
                    let _ = events.send(EngineEvent::TransferProgress {
                        msg_id: record.msg_id.clone(),
                        completed_chunks: total_chunks,
                        total_chunks,
                        status: MessageStatus::Delivered,
                        local_path: None,
                    });
                }
                _ => bail!("expected DeliveryAck after sending file chunks"),
            }
        }
    }

    Ok(())
}

/// Maximum size of a single compressed profile avatar payload (512 KiB).
pub(crate) const MAX_AVATAR_BYTES: usize = 512 * 1024;

pub(crate) fn compute_avatar_hash(bytes: &[u8]) -> String {
    let hex = blake3::hash(bytes).to_hex().to_string();
    hex.chars().take(16).collect()
}

fn sanitize_node_prefix(node_id: &str) -> String {
    let cleaned: String = node_id
        .chars()
        .filter(|c| c.is_ascii_alphanumeric() || *c == '-' || *c == '_')
        .take(24)
        .collect();
    if cleaned.is_empty() {
        "node".to_string()
    } else {
        cleaned
    }
}

fn avatars_dir(data_dir: &Path) -> PathBuf {
    data_dir.join("avatars")
}

pub(crate) fn avatar_file_path_for_hash(data_dir: &Path, node_id: &str, hash: &str) -> PathBuf {
    let prefix = sanitize_node_prefix(node_id);
    let safe_hash: String = hash
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .take(16)
        .collect();
    avatars_dir(data_dir).join(format!("avatar_{prefix}_{safe_hash}.png"))
}

pub(crate) fn remove_avatar_files(data_dir: &Path, node_id: &str) {
    let dir = avatars_dir(data_dir);
    let prefix = format!("avatar_{}_", sanitize_node_prefix(node_id));
    if let Ok(entries) = std::fs::read_dir(&dir) {
        for entry in entries.flatten() {
            let name = entry.file_name();
            if name.to_string_lossy().starts_with(&prefix) {
                let _ = std::fs::remove_file(entry.path());
            }
        }
    }
}

pub(crate) fn write_avatar_file(
    data_dir: &Path,
    node_id: &str,
    hash: &str,
    png_bytes: &[u8],
) -> Result<String> {
    if png_bytes.is_empty() || png_bytes.len() > MAX_AVATAR_BYTES {
        bail!("invalid avatar size: {} bytes", png_bytes.len());
    }
    let dir = avatars_dir(data_dir);
    std::fs::create_dir_all(&dir)?;
    remove_avatar_files(data_dir, node_id);
    let target = avatar_file_path_for_hash(data_dir, node_id, hash);
    std::fs::write(&target, png_bytes)?;
    Ok(target.to_string_lossy().to_string())
}

pub(crate) fn resolve_self_avatar_path(
    store: &LocalStore,
    data_dir: &Path,
    my_node_id: &str,
) -> Option<String> {
    let (_, hash_opt) = store.get_self_profile();
    let hash = hash_opt?;
    let path = avatar_file_path_for_hash(data_dir, my_node_id, &hash);
    if path.exists() {
        Some(path.to_string_lossy().to_string())
    } else {
        None
    }
}

pub(crate) fn local_profile_snapshot(
    store: &LocalStore,
    data_dir: &Path,
    my_node_id: &str,
) -> (String, Option<String>, Option<Vec<u8>>) {
    let (name_opt, hash_opt) = store.get_self_profile();
    let display_name = name_opt.unwrap_or_default();
    if let Some(hash) = hash_opt {
        let path = avatar_file_path_for_hash(data_dir, my_node_id, &hash);
        if let Ok(bytes) = std::fs::read(&path)
            && !bytes.is_empty()
            && bytes.len() <= MAX_AVATAR_BYTES
        {
            return (display_name, Some(hash), Some(bytes));
        }
    }
    (display_name, None, None)
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn apply_remote_profile_update(
    store: &LocalStore,
    data_dir: &Path,
    events: &broadcast::Sender<EngineEvent>,
    peer_id: &str,
    display_name: &str,
    avatar_hash: Option<String>,
    avatar_png: Option<Vec<u8>>,
    clear_avatar: bool,
) -> Result<()> {
    let existing = store.get_peer_profile(peer_id).ok().flatten();
    let prev_name = existing.as_ref().map(|e| e.0.clone()).unwrap_or_default();
    let prev_hash = existing.as_ref().and_then(|e| e.1.clone());
    let prev_path = existing.as_ref().and_then(|e| e.2.clone());

    let mut next_hash_update: Option<Option<&str>> = None;
    let mut next_path_owned: Option<String> = prev_path.clone();
    let mut next_path_update: Option<Option<String>> = None;

    if clear_avatar || avatar_hash.is_none() {
        if prev_hash.is_some() || prev_path.is_some() {
            remove_avatar_files(data_dir, peer_id);
            next_hash_update = Some(None);
            next_path_owned = None;
            next_path_update = Some(None);
        }
    } else if let (Some(hash), Some(bytes)) = (avatar_hash.as_deref(), avatar_png.as_deref()) {
        if bytes.len() <= MAX_AVATAR_BYTES && compute_avatar_hash(bytes) == hash {
            let written = write_avatar_file(data_dir, peer_id, hash, bytes)?;
            next_hash_update = Some(Some(hash));
            next_path_owned = Some(written.clone());
            next_path_update = Some(Some(written));
        }
    }

    let trimmed_name = display_name.trim();
    let name_opt = (!trimmed_name.is_empty()).then_some(trimmed_name);
    let path_ref_update: Option<Option<&str>> = match &next_path_update {
        Some(Some(s)) => Some(Some(s.as_str())),
        Some(None) => Some(None),
        None => None,
    };
    store.update_peer_profile(peer_id, name_opt, next_hash_update, path_ref_update)?;

    let effective_name = name_opt.unwrap_or(prev_name.as_str()).to_string();
    let changed = name_opt.is_some_and(|n| n != prev_name) || next_path_update.is_some();
    if changed {
        let _ = events.send(EngineEvent::PeerProfileUpdated {
            peer_id: peer_id.to_string(),
            display_name: effective_name,
            avatar_path: next_path_owned,
        });
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
async fn handle_profile_announce<W: AsyncWrite + Unpin>(
    peer_id: &str,
    local_key: &SecretKey,
    remote_name: &str,
    remote_avatar_hash: Option<String>,
    known_peer_avatar_hash: Option<String>,
    writer: &mut W,
    store: &LocalStore,
    data_dir: &Path,
    events: &broadcast::Sender<EngineEvent>,
) -> Result<bool> {
    let existing = store.get_peer_profile(peer_id).ok().flatten();
    let local_cached_hash = existing.as_ref().and_then(|e| e.1.clone());
    let local_cached_exists = existing
        .as_ref()
        .and_then(|e| e.2.as_ref())
        .is_some_and(|p| Path::new(p).exists());

    let need_your_avatar = match remote_avatar_hash.as_deref() {
        Some(h) if !h.is_empty() => {
            local_cached_hash.as_deref() != Some(h) || !local_cached_exists
        }
        _ => false,
    };

    // Update name immediately and clear our local cache if remote removed its photo.
    let _ = apply_remote_profile_update(
        store,
        data_dir,
        events,
        peer_id,
        remote_name,
        remote_avatar_hash.clone(),
        None,
        remote_avatar_hash.is_none(),
    );

    let my_id = local_key.public().to_string();
    let (my_name, my_hash, my_bytes) = local_profile_snapshot(store, data_dir, &my_id);
    let send_my_bytes = match my_hash.as_deref() {
        Some(h) if known_peer_avatar_hash.as_deref() != Some(h) => my_bytes,
        _ => None,
    };

    write_wire_message(
        writer,
        &WireMessage::ProfileResponse {
            display_name: my_name,
            avatar_hash: my_hash,
            avatar_png: send_my_bytes,
            need_your_avatar,
        },
    )
    .await?;

    Ok(need_your_avatar)
}

#[allow(clippy::too_many_arguments)]
async fn handle_room_message_revoke<W: AsyncWrite + Unpin>(
    peer_id: &str,
    local_key: &SecretKey,
    room_id: String,
    msg_id: String,
    sender_id: String,
    target_peers: Vec<String>,
    store_in_locker: bool,
    signature_bytes: Vec<u8>,
    writer: &mut W,
    store: &LocalStore,
    events: &broadcast::Sender<EngineEvent>,
) -> Result<()> {
    verify_room_revoke(&room_id, &msg_id, &sender_id, &signature_bytes)?;

    let my_id = local_key.public().to_string();
    let dm_id = crate::db::store::dm_room_id(&my_id, &sender_id);
    let effective_room_id = if store.get_room(&room_id)?.is_some() {
        room_id.clone()
    } else if store.get_room(&dm_id)?.is_some() {
        dm_id
    } else {
        room_id.clone()
    };

    // Only accept revokes from an authenticated sender directly or via an authorized room Home Node.
    let authorized = sender_id == peer_id
        || store
            .is_authorized_room_member(&effective_room_id, &sender_id)
            .unwrap_or(false)
        || store
            .is_authorized_room_member(&room_id, &sender_id)
            .unwrap_or(false);
    if !authorized {
        bail!("ignoring RoomMessageRevoke for {msg_id}: sender {sender_id} is not authorized");
    }

    if store.is_home_node_mode() || store_in_locker {
        let mut forward_targets: Vec<String> = store
            .purge_blind_locker_by_revoke(&effective_room_id, &msg_id, &sender_id)
            .unwrap_or_default();
        if forward_targets.is_empty() {
            forward_targets = target_peers;
        }
        if forward_targets.is_empty() {
            if let Ok(members) = store.list_room_members(&effective_room_id) {
                forward_targets = members
                    .into_iter()
                    .filter(|m| m.role != "home_node" && m.node_id != sender_id && m.node_id != my_id)
                    .map(|m| m.node_id)
                    .collect();
            }
        }
        forward_targets.retain(|t| t != &sender_id && t != &my_id);
        forward_targets.sort();
        forward_targets.dedup();
        for target in &forward_targets {
            store.enqueue_pending_room_revoke(
                &room_id,
                &msg_id,
                &sender_id,
                target,
                false,
                &[],
                &signature_bytes,
            )?;
            let _ = events.send(EngineEvent::OutboxRetryRequested {
                peer_id: target.clone(),
            });
        }
        let _ = events.send(EngineEvent::HomeNodeStatsUpdated);
    } else if let Some(updated) = store.apply_revoke_to_local_message(
        &msg_id,
        &sender_id,
        Some(&effective_room_id),
        true,
    )? {
        let _ = events.send(EngineEvent::MessageUpdated(updated));
    }

    write_wire_message(
        writer,
        &WireMessage::RoomRevokeAck {
            room_id,
            msg_id,
        },
    )
    .await?;
    Ok(())
}

/// Sends a queued signed `RoomMessageRevoke` frame to a peer or Home Node and awaits `RoomRevokeAck`.
pub async fn send_pending_room_revoke<R, W>(
    revoke: &PendingRoomRevoke,
    reader: &mut R,
    writer: &mut W,
    store: &LocalStore,
) -> Result<()>
where
    R: AsyncRead + Unpin,
    W: AsyncWrite + Unpin,
{
    let frame = WireMessage::RoomMessageRevoke {
        room_id: revoke.room_id.clone(),
        msg_id: revoke.msg_id.clone(),
        sender_id: revoke.sender_id.clone(),
        target_peers: revoke.target_peers.clone(),
        store_in_locker: revoke.store_in_locker,
        signature_bytes: revoke.signature_bytes.clone(),
    };
    tokio::time::timeout(WIRE_CTRL_TIMEOUT, write_wire_message(writer, &frame))
        .await
        .context("timed out writing RoomMessageRevoke")??;

    let ack = tokio::time::timeout(WIRE_CTRL_TIMEOUT, read_wire_message(reader))
        .await
        .context("timed out waiting for RoomRevokeAck")??;
    match ack {
        Some(WireMessage::RoomRevokeAck { .. }) => {
            store.mark_pending_room_revoke_delivered(&revoke.revoke_id)?;
            Ok(())
        }
        other => bail!("expected RoomRevokeAck, got {other:?}"),
    }
}

#[cfg(test)]
mod deferred_bubble_tests {
    use super::*;
    use crate::crypto::room_cipher::{generate_room_key, transform_chunk_in_place};
    use tokio::io::split;

    #[tokio::test]
    async fn small_file_aborted_before_completion_leaves_no_ghost_message() -> Result<()> {
        let base = std::env::temp_dir().join(format!("p2p_defer_bubble_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);
        let data_dir = base.join("data");
        let recv_dir = base.join("recv");
        std::fs::create_dir_all(&data_dir)?;
        std::fs::create_dir_all(&recv_dir)?;

        let cfg = EngineConfig::with_dirs(data_dir.clone(), recv_dir.clone());
        let store = LocalStore::open(&data_dir.join("db.sqlite"))?;
        let my_key = SecretKey::generate();
        let peer_key = SecretKey::generate();
        let room_key = generate_room_key();
        let room_id = "room-test-defer";
        store.upsert_room(&RoomRecord {
            room_id: room_id.to_string(),
            name: "Test".to_string(),
            room_type: "group".to_string(),
            room_key_hex: Some(crate::crypto::room_cipher::room_key_to_hex(&room_key)),
            is_pinned: false,
            retention_days: 7,
            created_at_ms: now_millis(),
        })?;
        store.upsert_room_member(room_id, &my_key.public().to_string(), "Me", "owner")?;

        let msg_id = "msg-small-abort-1".to_string();
        let plain_bytes = vec![0x5Au8; 1024];
        let plain_hash = *blake3::hash(&plain_bytes).as_bytes();
        let plain_root = *blake3::hash(&plain_hash).as_bytes();
        let mut cipher_bytes = plain_bytes.clone();
        transform_chunk_in_place(&room_key, room_id, &msg_id, 0, &mut cipher_bytes);
        let cipher_hash = *blake3::hash(&cipher_bytes).as_bytes();

        let payload = PlainEnvelopePayload {
            kind: "file".to_string(),
            text: None,
            file_name: Some("tiny_pic.jpg".to_string()),
            file_size: Some(plain_bytes.len() as u64),
            plain_root_blake3: Some(plain_root),
            plain_chunk_hashes: vec![plain_hash],
            batch_id: None,
            created_at_ms: now_millis(),
        };

        let (events_tx, _) = broadcast::channel(16);

        // Case 1: Sender drops stream right after ChunkBitmapAck without sending FileChunk.
        {
            let (client_io, server_io) = tokio::io::duplex(64 * 1024);
            let (mut c_r, c_w) = split(client_io);
            let (mut s_r, mut s_w) = split(server_io);

            let recv_fut = receive_encrypted_file_stream(
                &my_key,
                &room_key,
                room_id.to_string(),
                msg_id.clone(),
                peer_key.public().to_string(),
                false,
                payload.clone(),
                512 * 1024,
                vec![cipher_hash],
                &mut s_r,
                &mut s_w,
                &store,
                &cfg,
                &recv_dir,
                &events_tx,
            );
            let send_fut = async move {
                let _ack = read_wire_message(&mut c_r).await?;
                drop(c_w);
                drop(c_r);
                Ok::<_, anyhow::Error>(())
            };
            tokio::time::timeout(
                Duration::from_secs(5),
                async { tokio::try_join!(recv_fut, send_fut) },
            )
            .await
            .context("case1 timed out")??;
        }

        assert!(
            store.get_message(&msg_id)?.is_none(),
            "aborted small file must not insert ghost paused_reconnecting message"
        );
        assert!(
            !data_dir.join("parts").join(format!("{msg_id}.part")).exists(),
            "aborted small file must not leave .part debris"
        );

        // Case 2: Full transfer commits directly as Delivered.
        {
            let (client_io, server_io) = tokio::io::duplex(64 * 1024);
            let (mut c_r, mut c_w) = split(client_io);
            let (mut s_r, mut s_w) = split(server_io);

            let msg_id_ok = msg_id.clone();
            let recv_fut = receive_encrypted_file_stream(
                &my_key,
                &room_key,
                room_id.to_string(),
                msg_id_ok.clone(),
                peer_key.public().to_string(),
                false,
                payload,
                512 * 1024,
                vec![cipher_hash],
                &mut s_r,
                &mut s_w,
                &store,
                &cfg,
                &recv_dir,
                &events_tx,
            );
            let send_fut = async move {
                let _bitmap_ack = read_wire_message(&mut c_r).await?;
                write_wire_message(
                    &mut c_w,
                    &WireMessage::FileChunk {
                        msg_id: msg_id_ok,
                        chunk_index: 0,
                        data: cipher_bytes,
                    },
                )
                .await?;
                let _rec_ack = read_wire_message(&mut c_r).await?;
                Ok::<_, anyhow::Error>(())
            };
            tokio::time::timeout(
                Duration::from_secs(5),
                async { tokio::try_join!(recv_fut, send_fut) },
            )
            .await
            .context("case2 timed out")??;
        }

        let rec = store
            .get_message(&msg_id)?
            .expect("completed small file should be persisted");
        assert_eq!(rec.status, MessageStatus::Delivered);
        assert!(rec.local_path.as_deref().is_some_and(|p| Path::new(p).exists()));

        let _ = std::fs::remove_dir_all(&base);
        Ok(())
    }
}
