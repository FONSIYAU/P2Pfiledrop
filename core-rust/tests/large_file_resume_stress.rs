use anyhow::{Context, Result, bail};
use iroh::SecretKey;
use p2p_chat_core::config::EngineConfig;
use p2p_chat_core::crypto::room_cipher::{generate_room_key, room_key_to_hex};
use p2p_chat_core::db::store::{LocalStore, MessageStatus, RoomRecord, now_millis};
use p2p_chat_core::transfer::chunker::index_file;
use p2p_chat_core::transfer::protocol::ChunkBitmap;
use p2p_chat_core::transfer::sync_engine::{
    EngineEvent, handle_incoming_bidi_stream, send_room_outbox_job,
};
use std::path::Path;
use std::time::{Duration, Instant};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::broadcast;

const TARGET_FILE_BYTES: u64 = 1_127_428_915; // ~1.05 GiB (non-aligned byte length)

async fn write_deterministic_file(path: &Path, total_bytes: u64) -> Result<[u8; 32]> {
    if let Some(parent) = path.parent() {
        tokio::fs::create_dir_all(parent).await?;
    }
    let mut file = tokio::fs::File::create(path).await?;
    let mut block = vec![0u8; 4 * 1024 * 1024];
    let mut hasher = blake3::Hasher::new();

    // Pre-fill non-zero pseudo-random 4 MiB block and mutate 64-byte header per iteration.
    let mut seed: u64 = 0x9E37_79B9_7F4A_7C15;
    for chunk8 in block.chunks_exact_mut(8) {
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        chunk8.copy_from_slice(&seed.to_le_bytes());
    }

    let mut written: u64 = 0;
    let mut block_idx: u64 = 0;
    while written < total_bytes {
        let to_write = ((total_bytes - written) as usize).min(block.len());
        block[0..8].copy_from_slice(&block_idx.to_le_bytes());
        hasher.update(&block[..to_write]);
        file.write_all(&block[..to_write]).await?;
        written += to_write as u64;
        block_idx += 1;
    }
    file.flush().await?;
    Ok(*hasher.finalize().as_bytes())
}

async fn hash_file_blake3(path: &Path) -> Result<[u8; 32]> {
    let mut file = tokio::fs::File::open(path).await?;
    let mut hasher = blake3::Hasher::new();
    let mut buf = vec![0u8; 4 * 1024 * 1024];
    loop {
        let n = file.read(&mut buf).await?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(*hasher.finalize().as_bytes())
}

fn count_bitmap_bits(bitmap: &[u8], total_chunks: usize) -> usize {
    (0..total_chunks)
        .filter(|&i| ChunkBitmap::is_set(bitmap, i))
        .count()
}

async fn run_attempt_until_cutoff(
    listener: &TcpListener,
    sender_store: LocalStore,
    sender_cfg: EngineConfig,
    sender_key: SecretKey,
    sender_events: broadcast::Sender<EngineEvent>,
    receiver_store: LocalStore,
    receiver_cfg: EngineConfig,
    receiver_key: SecretKey,
    receiver_events: broadcast::Sender<EngineEvent>,
    peer_id_on_sender: String,
    sender_id_on_receiver: String,
    msg_id: String,
    cutoff_chunks: Option<usize>,
) -> Result<(usize, usize, Duration)> {
    let addr = listener.local_addr()?;
    let mut rx = receiver_events.subscribe();

    let jobs = sender_store.list_pending_room_outbox_for_peer(&peer_id_on_sender)?;
    let job = jobs
        .into_iter()
        .find(|j| j.message.msg_id == msg_id)
        .context("missing pending outbox job for target message")?;

    let accept_fut = listener.accept();
    let connect_fut = TcpStream::connect(addr);
    let (accept_res, connect_res) = tokio::join!(accept_fut, connect_fut);
    let (recv_stream, _) = accept_res?;
    let send_stream = connect_res?;
    recv_stream.set_nodelay(true)?;
    send_stream.set_nodelay(true)?;

    let attempt_start = Instant::now();
    let recv_store_task = receiver_store.clone();
    let recv_cfg_task = receiver_cfg.clone();
    let recv_handle = tokio::spawn(async move {
        let (mut r, mut w) = recv_stream.into_split();
        handle_incoming_bidi_stream(
            &sender_id_on_receiver,
            &receiver_key,
            &mut r,
            &mut w,
            &recv_store_task,
            &recv_cfg_task,
            &recv_cfg_task.auto_receive_dir,
            &receiver_events,
            &[],
        )
        .await
    });

    let send_store_task = sender_store.clone();
    let send_cfg_task = sender_cfg.clone();
    let send_handle = tokio::spawn(async move {
        let (mut r, mut w) = send_stream.into_split();
        send_room_outbox_job(
            &job,
            &peer_id_on_sender,
            &sender_key,
            &mut r,
            &mut w,
            &send_store_task,
            &send_cfg_task,
            &sender_events,
        )
        .await
    });

    let mut latest_completed = 0usize;
    let mut total_chunks = 0usize;

    if let Some(target_chunks) = cutoff_chunks {
        loop {
            match tokio::time::timeout(Duration::from_secs(60), rx.recv()).await {
                Ok(Ok(EngineEvent::TransferProgress {
                    msg_id: ev_msg,
                    completed_chunks,
                    total_chunks: ev_total,
                    ..
                })) if ev_msg == msg_id => {
                    latest_completed = completed_chunks;
                    total_chunks = ev_total;
                    if completed_chunks >= target_chunks {
                        // Simulate sudden connection drop by aborting sender stream mid-flight.
                        send_handle.abort();
                        break;
                    }
                }
                Ok(Ok(_)) => {}
                Ok(Err(broadcast::error::RecvError::Lagged(_))) => continue,
                Ok(Err(e)) => bail!("receiver event channel closed prematurely: {e}"),
                Err(_) => bail!("timed out waiting for TransferProgress cutoff ({target_chunks})"),
            }
        }
        let _ = send_handle.await;
        let _ = tokio::time::timeout(Duration::from_secs(10), recv_handle)
            .await
            .context("receiver task did not settle cleanly after simulated disconnect")?;
    } else {
        let (send_res, recv_res) = tokio::join!(send_handle, recv_handle);
        send_res.context("sender task panicked")??;
        recv_res.context("receiver task panicked")??;
    }

    Ok((latest_completed, total_chunks, attempt_start.elapsed()))
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
#[ignore = "1.05 GiB disk/network stress test; run explicitly in release mode"]
async fn large_file_1gb_double_disconnect_and_resume() -> Result<()> {
    let base = std::env::temp_dir().join(format!("p2p_stress_1gb_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&base);
    std::fs::create_dir_all(&base)?;

    let src_file = base.join("src_1gb_payload.bin");
    let sender_data = base.join("sender_data");
    let sender_recv = base.join("sender_recv");
    let recv_data = base.join("recv_data");
    let recv_out = base.join("recv_out");

    let gen_start = Instant::now();
    println!("[STRESS] Generating {TARGET_FILE_BYTES} bytes (~1.05 GiB) test file...");
    let expected_full_blake3 = write_deterministic_file(&src_file, TARGET_FILE_BYTES).await?;
    println!(
        "[STRESS] File generated & BLAKE3 hashed in {:.2}s (hash={})",
        gen_start.elapsed().as_secs_f64(),
        blake3::Hash::from_bytes(expected_full_blake3)
    );

    let sender_cfg = EngineConfig::with_dirs(sender_data.clone(), sender_recv.clone());
    let receiver_cfg = EngineConfig::with_dirs(recv_data.clone(), recv_out.clone());
    assert_eq!(sender_cfg.chunk_size_bytes, 64 * 1024);

    let sender_store = LocalStore::open(&sender_data.join("store.sqlite"))?;
    let receiver_store = LocalStore::open(&recv_data.join("store.sqlite"))?;

    let sender_key = SecretKey::generate();
    let receiver_key = SecretKey::generate();
    let sender_id = sender_key.public().to_string();
    let receiver_id = receiver_key.public().to_string();

    let room_key = generate_room_key();
    let room_key_hex = room_key_to_hex(&room_key);
    let room_id = "dm-stress-1gb";

    for (store, peer_id, peer_name) in [
        (&sender_store, &receiver_id, "ReceiverPhone"),
        (&receiver_store, &sender_id, "SenderPC"),
    ] {
        store.upsert_peer(peer_id, peer_name)?;
        store.upsert_room(&RoomRecord {
            room_id: room_id.to_string(),
            name: "Stress DM".to_string(),
            room_type: "dm".to_string(),
            room_key_hex: Some(room_key_hex.clone()),
            is_pinned: false,
            retention_days: 7,
            created_at_ms: now_millis(),
        })?;
        store.upsert_room_member(room_id, &sender_id, "SenderPC", "owner")?;
        store.upsert_room_member(room_id, &receiver_id, "ReceiverPhone", "member")?;
    }

    let idx_start = Instant::now();
    let indexed = index_file(&src_file, sender_cfg.chunk_size_bytes).await?;
    let total_chunks = indexed.chunk_hashes.len();
    println!(
        "[STRESS] Production chunk indexing ({total_chunks} chunks @ 64 KiB) completed in {:.2}s",
        idx_start.elapsed().as_secs_f64()
    );

    let msg_id = "msg-stress-1gb-resume-01".to_string();
    sender_store.enqueue_room_outgoing_file(
        &msg_id,
        room_id,
        &sender_id,
        &receiver_id,
        "stress_1gb_archive.bin",
        indexed.file_size,
        src_file.to_string_lossy().as_ref(),
        &indexed.root_blake3,
        indexed.chunk_size,
        total_chunks,
        &[receiver_id.clone()],
        None,
    )?;

    let (sender_events, _) = broadcast::channel(256);
    let (receiver_events, _) = broadcast::channel(256);
    let listener = TcpListener::bind("127.0.0.1:0").await?;
    let part_path = recv_data.join("parts").join(format!("{msg_id}.part"));

    // --- Attempt 1: 0% -> ~30% then abrupt disconnect ---
    let cutoff_1 = total_chunks * 30 / 100;
    let (_, _, dur1) = run_attempt_until_cutoff(
        &listener,
        sender_store.clone(),
        sender_cfg.clone(),
        sender_key.clone(),
        sender_events.clone(),
        receiver_store.clone(),
        receiver_cfg.clone(),
        receiver_key.clone(),
        receiver_events.clone(),
        receiver_id.clone(),
        sender_id.clone(),
        msg_id.clone(),
        Some(cutoff_1),
    )
    .await?;

    let rec_after_1 = receiver_store
        .get_message(&msg_id)?
        .context("receiver message record missing after attempt 1")?;
    let bits_1 = rec_after_1
        .received_bitmap
        .as_deref()
        .map(|bm| count_bitmap_bits(bm, total_chunks))
        .unwrap_or(0);
    println!(
        "[STRESS] Attempt 1 interrupted at {bits_1}/{total_chunks} chunks ({:.1}%) in {:.2}s | status={:?}",
        (bits_1 as f64 / total_chunks as f64) * 100.0,
        dur1.as_secs_f64(),
        rec_after_1.status
    );
    assert_eq!(rec_after_1.status, MessageStatus::PausedReconnecting);
    assert!(bits_1 >= cutoff_1);
    assert!(bits_1 < total_chunks);
    assert!(part_path.exists(), ".part file must persist after disconnect 1");

    // --- Attempt 2: ~30% -> ~70% then second abrupt disconnect ---
    let cutoff_2 = total_chunks * 70 / 100;
    let (_, _, dur2) = run_attempt_until_cutoff(
        &listener,
        sender_store.clone(),
        sender_cfg.clone(),
        sender_key.clone(),
        sender_events.clone(),
        receiver_store.clone(),
        receiver_cfg.clone(),
        receiver_key.clone(),
        receiver_events.clone(),
        receiver_id.clone(),
        sender_id.clone(),
        msg_id.clone(),
        Some(cutoff_2),
    )
    .await?;

    let rec_after_2 = receiver_store
        .get_message(&msg_id)?
        .context("receiver message record missing after attempt 2")?;
    let bits_2 = rec_after_2
        .received_bitmap
        .as_deref()
        .map(|bm| count_bitmap_bits(bm, total_chunks))
        .unwrap_or(0);
    println!(
        "[STRESS] Attempt 2 resumed & interrupted at {bits_2}/{total_chunks} chunks ({:.1}%) in {:.2}s | status={:?}",
        (bits_2 as f64 / total_chunks as f64) * 100.0,
        dur2.as_secs_f64(),
        rec_after_2.status
    );
    assert_eq!(rec_after_2.status, MessageStatus::PausedReconnecting);
    assert!(bits_2 >= cutoff_2);
    assert!(bits_2 > bits_1);
    assert!(bits_2 < total_chunks);
    assert!(part_path.exists(), ".part file must persist after disconnect 2");

    // --- Attempt 3: ~70% -> 100% completion + finalize + ACK ---
    let (_, _, dur3) = run_attempt_until_cutoff(
        &listener,
        sender_store.clone(),
        sender_cfg.clone(),
        sender_key.clone(),
        sender_events.clone(),
        receiver_store.clone(),
        receiver_cfg.clone(),
        receiver_key.clone(),
        receiver_events.clone(),
        receiver_id.clone(),
        sender_id.clone(),
        msg_id.clone(),
        None,
    )
    .await?;

    let sender_final = sender_store
        .get_message(&msg_id)?
        .context("sender final record missing")?;
    let recv_final = receiver_store
        .get_message(&msg_id)?
        .context("receiver final record missing")?;
    println!(
        "[STRESS] Attempt 3 resumed & finished remaining {} chunks + finalize/ACK in {:.2}s | sender={:?}, receiver={:?}",
        total_chunks - bits_2,
        dur3.as_secs_f64(),
        sender_final.status,
        recv_final.status
    );

    assert_eq!(sender_final.status, MessageStatus::Delivered);
    assert_eq!(recv_final.status, MessageStatus::Delivered);
    assert!(
        !part_path.exists(),
        ".part temp file must be removed after finalization"
    );

    let saved_path_str = recv_final
        .local_path
        .as_deref()
        .context("receiver record missing final local_path")?;
    let saved_path = Path::new(saved_path_str);
    assert!(saved_path.exists(), "received 1.05 GiB file must exist on disk");
    let saved_len = std::fs::metadata(saved_path)?.len();
    assert_eq!(saved_len, TARGET_FILE_BYTES, "exact byte length mismatch");

    let actual_full_blake3 = hash_file_blake3(saved_path).await?;
    assert_eq!(
        actual_full_blake3, expected_full_blake3,
        "1.05 GiB resumed file BLAKE3 digest mismatch"
    );

    let total_transfer_s = dur1.as_secs_f64() + dur2.as_secs_f64() + dur3.as_secs_f64();
    let effective_mbps = (TARGET_FILE_BYTES as f64 / (1024.0 * 1024.0)) / total_transfer_s;
    println!(
        "[STRESS] PASSED: Bit-identical 1.05 GiB delivery across 2 abrupt disconnects! Active transfer+finalize={total_transfer_s:.2}s ({effective_mbps:.1} MiB/s)"
    );

    let _ = std::fs::remove_dir_all(&base);
    Ok(())
}
