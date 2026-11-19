//! Streaming 512 KiB file chunker, dual-layer BLAKE3 verifier, stream-encrypted chunk reader/writer,
//! and `.part` resumable writer for both direct delivery and zero-knowledge blind locker storage.

use crate::crypto::room_cipher::{RoomKey, transform_chunk_in_place};
use anyhow::{Context, Result, bail};
use std::path::{Path, PathBuf};
use tokio::fs::{self, File, OpenOptions};
use tokio::io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt, SeekFrom};

/// Result of indexing a local file before queueing/sending.
#[derive(Debug, Clone)]
pub struct IndexedFile {
    pub file_size: u64,
    pub chunk_size: usize,
    pub chunk_hashes: Vec<[u8; 32]>,
    pub root_blake3: [u8; 32],
}

/// Result of indexing a local file with both plaintext and room-encrypted BLAKE3 trees.
#[derive(Debug, Clone)]
pub struct EncryptedIndexedFile {
    pub file_size: u64,
    pub chunk_size: usize,
    pub plain_chunk_hashes: Vec<[u8; 32]>,
    pub plain_root_blake3: [u8; 32],
    pub cipher_chunk_hashes: Vec<[u8; 32]>,
    pub cipher_root_blake3: [u8; 32],
}

/// Streams `path` in `chunk_size` slices to compute per-chunk BLAKE3 hashes and root hash
/// without loading the entire file into memory.
pub async fn index_file(path: &Path, chunk_size: usize) -> Result<IndexedFile> {
    if chunk_size == 0 {
        bail!("chunk_size must be > 0");
    }

    let mut file = File::open(path)
        .await
        .with_context(|| format!("failed to open file for indexing: {}", path.display()))?;
    let file_size = file.metadata().await?.len();

    let mut chunk_hashes = Vec::new();
    let mut root_hasher = blake3::Hasher::new();
    let mut buf = vec![0u8; chunk_size];

    loop {
        let n = read_full_chunk(&mut file, &mut buf).await?;
        if n == 0 {
            break;
        }
        let chunk_hash = *blake3::hash(&buf[..n]).as_bytes();
        root_hasher.update(&chunk_hash);
        chunk_hashes.push(chunk_hash);
    }

    let root_blake3 = *root_hasher.finalize().as_bytes();
    Ok(IndexedFile {
        file_size,
        chunk_size,
        chunk_hashes,
        root_blake3,
    })
}

/// Streams `path` once to compute both plaintext BLAKE3 hashes (for recipient verification)
/// and ciphertext BLAKE3 hashes (for zero-knowledge blind locker chunk verification).
pub async fn index_encrypted_file(
    path: &Path,
    chunk_size: usize,
    room_key: &RoomKey,
    room_id: &str,
    msg_id: &str,
) -> Result<EncryptedIndexedFile> {
    if chunk_size == 0 {
        bail!("chunk_size must be > 0");
    }

    let mut file = File::open(path)
        .await
        .with_context(|| format!("failed to open file for encrypted indexing: {}", path.display()))?;
    let file_size = file.metadata().await?.len();

    let mut plain_chunk_hashes = Vec::new();
    let mut cipher_chunk_hashes = Vec::new();
    let mut plain_root_hasher = blake3::Hasher::new();
    let mut cipher_root_hasher = blake3::Hasher::new();
    let mut buf = vec![0u8; chunk_size];
    let mut chunk_idx: u32 = 0;

    loop {
        let n = read_full_chunk(&mut file, &mut buf).await?;
        if n == 0 {
            break;
        }
        let plain_hash = *blake3::hash(&buf[..n]).as_bytes();
        plain_root_hasher.update(&plain_hash);
        plain_chunk_hashes.push(plain_hash);

        transform_chunk_in_place(room_key, room_id, msg_id, chunk_idx, &mut buf[..n]);
        let cipher_hash = *blake3::hash(&buf[..n]).as_bytes();
        cipher_root_hasher.update(&cipher_hash);
        cipher_chunk_hashes.push(cipher_hash);

        chunk_idx += 1;
    }

    Ok(EncryptedIndexedFile {
        file_size,
        chunk_size,
        plain_chunk_hashes,
        plain_root_blake3: *plain_root_hasher.finalize().as_bytes(),
        cipher_chunk_hashes,
        cipher_root_blake3: *cipher_root_hasher.finalize().as_bytes(),
    })
}

/// Reads a single chunk slice from `path` at `chunk_index * chunk_size`.
pub async fn read_chunk(path: &Path, chunk_index: usize, chunk_size: usize) -> Result<Vec<u8>> {
    let mut file = File::open(path)
        .await
        .with_context(|| format!("failed to open file for chunk read: {}", path.display()))?;
    let offset = (chunk_index as u64)
        .checked_mul(chunk_size as u64)
        .context("chunk offset overflow")?;
    file.seek(SeekFrom::Start(offset)).await?;

    let mut buf = vec![0u8; chunk_size];
    let n = read_full_chunk(&mut file, &mut buf).await?;
    buf.truncate(n);
    Ok(buf)
}

/// Reads a plaintext chunk from `path` and encrypts it on-the-fly for transmission.
pub async fn read_encrypted_chunk(
    path: &Path,
    chunk_index: usize,
    chunk_size: usize,
    room_key: &RoomKey,
    room_id: &str,
    msg_id: &str,
) -> Result<Vec<u8>> {
    let mut data = read_chunk(path, chunk_index, chunk_size).await?;
    transform_chunk_in_place(room_key, room_id, msg_id, chunk_index as u32, &mut data);
    Ok(data)
}

/// Verifies `data` against `expected_hash` and writes it at `chunk_index * chunk_size` in `.part`.
pub async fn verify_and_write_chunk(
    part_path: &Path,
    chunk_index: usize,
    chunk_size: usize,
    expected_hash: &[u8; 32],
    data: &[u8],
) -> Result<()> {
    let actual_hash = *blake3::hash(data).as_bytes();
    if &actual_hash != expected_hash {
        bail!(
            "BLAKE3 mismatch on chunk {chunk_index}: expected {}, got {}",
            blake3::Hash::from_bytes(*expected_hash),
            blake3::Hash::from_bytes(actual_hash)
        );
    }

    write_verified_bytes_at(part_path, chunk_index, chunk_size, data).await
}

/// Verifies outer ciphertext hash, decrypts chunk with `room_key`, verifies inner plaintext hash,
/// and writes plaintext bytes to `part_path`.
#[allow(clippy::too_many_arguments)]
pub async fn verify_decrypt_and_write_chunk(
    part_path: &Path,
    chunk_index: usize,
    chunk_size: usize,
    expected_cipher_hash: &[u8; 32],
    expected_plain_hash: &[u8; 32],
    room_key: &RoomKey,
    room_id: &str,
    msg_id: &str,
    cipher_data: &[u8],
) -> Result<()> {
    let actual_cipher_hash = *blake3::hash(cipher_data).as_bytes();
    if &actual_cipher_hash != expected_cipher_hash {
        bail!("cipher BLAKE3 mismatch on chunk {chunk_index}");
    }

    let mut plain = cipher_data.to_vec();
    transform_chunk_in_place(room_key, room_id, msg_id, chunk_index as u32, &mut plain);

    let actual_plain_hash = *blake3::hash(&plain).as_bytes();
    if &actual_plain_hash != expected_plain_hash {
        bail!("decrypted plain BLAKE3 mismatch on chunk {chunk_index}");
    }

    write_verified_bytes_at(part_path, chunk_index, chunk_size, &plain).await
}

async fn write_verified_bytes_at(
    part_path: &Path,
    chunk_index: usize,
    chunk_size: usize,
    data: &[u8],
) -> Result<()> {
    if let Some(parent) = part_path.parent() {
        fs::create_dir_all(parent).await?;
    }

    let mut file = OpenOptions::new()
        .create(true)
        .write(true)
        .read(true)
        .open(part_path)
        .await
        .with_context(|| format!("failed to open part file: {}", part_path.display()))?;

    let offset = (chunk_index as u64)
        .checked_mul(chunk_size as u64)
        .context("chunk offset overflow")?;
    file.seek(SeekFrom::Start(offset)).await?;
    file.write_all(data).await?;
    file.flush().await?;
    Ok(())
}

/// Truncates `.part` to exact `file_size`, verifies root hash across chunks, and moves it
/// into `dest_dir` under a collision-safe filename (for direct auto-receive).
pub async fn finalize_part_file(
    part_path: &Path,
    dest_dir: &Path,
    original_name: &str,
    expected_file_size: u64,
    expected_root_blake3: &[u8; 32],
    chunk_size: usize,
) -> Result<PathBuf> {
    if !part_path.exists() {
        if expected_file_size == 0 {
            if let Some(parent) = part_path.parent() {
                fs::create_dir_all(parent).await?;
            }
            File::create(part_path).await?;
        } else {
            bail!("part file missing: {}", part_path.display());
        }
    }

    let file = OpenOptions::new().write(true).open(part_path).await?;
    file.set_len(expected_file_size).await?;
    drop(file);

    let verified = index_file(part_path, chunk_size).await?;
    if &verified.root_blake3 != expected_root_blake3 {
        bail!("final root BLAKE3 verification failed for {}", original_name);
    }

    fs::create_dir_all(dest_dir).await?;
    let target_path = unique_destination_path(dest_dir, original_name);
    fs::rename(part_path, &target_path).await.or_else(|_| {
        std::fs::copy(part_path, &target_path)?;
        std::fs::remove_file(part_path)
    })?;

    Ok(target_path)
}

/// Truncates blind locker `.enc.part`, verifies outer `expected_cipher_root`, and moves it
/// into `locker_dir/{msg_id}.enc`.
pub async fn finalize_blind_locker_file(
    part_path: &Path,
    locker_dir: &Path,
    msg_id: &str,
    expected_file_size: u64,
    expected_cipher_root: &[u8; 32],
    chunk_size: usize,
) -> Result<PathBuf> {
    validate_safe_id(msg_id)?;
    if !part_path.exists() {
        if expected_file_size == 0 {
            if let Some(parent) = part_path.parent() {
                fs::create_dir_all(parent).await?;
            }
            File::create(part_path).await?;
        } else {
            bail!("blind locker part file missing: {}", part_path.display());
        }
    }

    let file = OpenOptions::new().write(true).open(part_path).await?;
    file.set_len(expected_file_size).await?;
    drop(file);

    let verified = index_file(part_path, chunk_size).await?;
    if &verified.root_blake3 != expected_cipher_root {
        bail!("blind locker cipher root BLAKE3 mismatch for {msg_id}");
    }

    fs::create_dir_all(locker_dir).await?;
    let target_path = locker_dir.join(format!("{msg_id}.enc"));
    fs::rename(part_path, &target_path).await.or_else(|_| {
        std::fs::copy(part_path, &target_path)?;
        std::fs::remove_file(part_path)
    })?;

    Ok(target_path)
}

fn truncate_utf8(s: &str, max_bytes: usize) -> &str {
    if s.len() <= max_bytes {
        return s;
    }
    let mut end = 0;
    for (idx, ch) in s.char_indices() {
        let next = idx + ch.len_utf8();
        if next > max_bytes {
            break;
        }
        end = next;
    }
    &s[..end]
}

fn is_windows_reserved_name(stem: &str) -> bool {
    matches!(
        stem.to_ascii_uppercase().as_str(),
        "CON"
            | "PRN"
            | "AUX"
            | "NUL"
            | "COM1"
            | "COM2"
            | "COM3"
            | "COM4"
            | "COM5"
            | "COM6"
            | "COM7"
            | "COM8"
            | "COM9"
            | "LPT1"
            | "LPT2"
            | "LPT3"
            | "LPT4"
            | "LPT5"
            | "LPT6"
            | "LPT7"
            | "LPT8"
            | "LPT9"
    )
}

/// Validates a peer-supplied storage identifier (e.g. `msg_id`) to prevent path traversal.
pub fn validate_safe_id(id: &str) -> Result<()> {
    if id.is_empty()
        || id.len() > 128
        || !id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
    {
        bail!("invalid identifier for storage path");
    }
    Ok(())
}

/// Sanitizes an untrusted filename for cross-platform NTFS/POSIX storage while preserving extensions.
pub fn sanitize_file_name(raw_name: &str) -> String {
    let base = raw_name.rsplit(['/', '\\']).next().unwrap_or("");
    let cleaned: String = base
        .chars()
        .map(|c| match c {
            '<' | '>' | ':' | '"' | '/' | '\\' | '|' | '?' | '*' => '_',
            c if c < ' ' || c == '\x7f' => '_',
            c => c,
        })
        .collect();
    let trimmed = cleaned.trim().trim_end_matches('.');
    if trimmed.is_empty() || trimmed == "." || trimmed == ".." {
        return "received_file".to_string();
    }

    let stem_before_dot = trimmed.split('.').next().unwrap_or(trimmed);
    let guarded = if is_windows_reserved_name(stem_before_dot) {
        format!("_{trimmed}")
    } else {
        trimmed.to_string()
    };

    const MAX_FILE_NAME_BYTES: usize = 200;
    if guarded.len() <= MAX_FILE_NAME_BYTES {
        return guarded;
    }

    let shortened = if let Some((stem, ext)) = guarded.rsplit_once('.')
        && !stem.is_empty()
        && !ext.is_empty()
        && ext.len() <= 32
    {
        let max_stem = MAX_FILE_NAME_BYTES.saturating_sub(ext.len() + 1);
        let t_stem = truncate_utf8(stem, max_stem).trim_end_matches('.');
        if t_stem.is_empty() {
            truncate_utf8(&guarded, MAX_FILE_NAME_BYTES)
                .trim()
                .trim_end_matches('.')
                .to_string()
        } else {
            format!("{t_stem}.{ext}")
        }
    } else {
        truncate_utf8(&guarded, MAX_FILE_NAME_BYTES)
            .trim()
            .trim_end_matches('.')
            .to_string()
    };

    if shortened.is_empty() {
        "received_file".to_string()
    } else {
        shortened
    }
}

/// Generates a non-colliding path in `dest_dir`, e.g. `photo.jpg` -> `photo (1).jpg`.
pub fn unique_destination_path(dest_dir: &Path, raw_name: &str) -> PathBuf {
    let safe_name = sanitize_file_name(raw_name);

    let candidate = dest_dir.join(&safe_name);
    if !candidate.exists() {
        return candidate;
    }

    let path = Path::new(&safe_name);
    let stem = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("received_file");
    let ext = path.extension().and_then(|e| e.to_str());

    for n in 1..10_000 {
        let name = match ext {
            Some(e) if !e.is_empty() => format!("{stem} ({n}).{e}"),
            _ => format!("{stem} ({n})"),
        };
        let next = dest_dir.join(name);
        if !next.exists() {
            return next;
        }
    }
    dest_dir.join(format!("{stem}_{}", std::process::id()))
}

async fn read_full_chunk(file: &mut File, buf: &mut [u8]) -> Result<usize> {
    let mut total = 0;
    while total < buf.len() {
        let n = file.read(&mut buf[total..]).await?;
        if n == 0 {
            break;
        }
        total += n;
    }
    Ok(total)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::room_cipher::generate_room_key;
    use crate::transfer::protocol::ChunkBitmap;

    #[tokio::test]
    async fn chunk_and_resume_roundtrip() -> Result<()> {
        let temp_root = std::env::temp_dir().join(format!("p2p_chunk_test_{}", std::process::id()));
        let _ = fs::remove_dir_all(&temp_root).await;
        fs::create_dir_all(&temp_root).await?;

        let src = temp_root.join("sample.bin");
        let payload: Vec<u8> = (0..5_000_000u32).map(|i| (i % 251) as u8).collect();
        fs::write(&src, &payload).await?;

        let chunk_size = 2 * 1024 * 1024;
        let indexed = index_file(&src, chunk_size).await?;
        assert_eq!(indexed.file_size, payload.len() as u64);
        assert_eq!(indexed.chunk_hashes.len(), 3);

        let part = temp_root.join("incoming.part");
        let mut bitmap = ChunkBitmap::empty(indexed.chunk_hashes.len());

        for idx in [0usize, 2usize] {
            let chunk_data = read_chunk(&src, idx, chunk_size).await?;
            verify_and_write_chunk(&part, idx, chunk_size, &indexed.chunk_hashes[idx], &chunk_data)
                .await?;
            ChunkBitmap::set(&mut bitmap, idx);
        }
        assert_eq!(ChunkBitmap::missing_indices(&bitmap, 3), vec![1]);

        for idx in ChunkBitmap::missing_indices(&bitmap, 3) {
            let chunk_data = read_chunk(&src, idx, chunk_size).await?;
            verify_and_write_chunk(&part, idx, chunk_size, &indexed.chunk_hashes[idx], &chunk_data)
                .await?;
            ChunkBitmap::set(&mut bitmap, idx);
        }
        assert!(ChunkBitmap::is_all_set(&bitmap, 3));

        let recv_dir = temp_root.join("received");
        let final_path = finalize_part_file(
            &part,
            &recv_dir,
            "sample.bin",
            indexed.file_size,
            &indexed.root_blake3,
            chunk_size,
        )
        .await?;

        let restored = fs::read(&final_path).await?;
        assert_eq!(restored, payload);

        let _ = fs::remove_dir_all(&temp_root).await;
        Ok(())
    }

    #[tokio::test]
    async fn encrypted_blind_locker_roundtrip() -> Result<()> {
        let temp_root =
            std::env::temp_dir().join(format!("p2p_enc_chunk_test_{}", std::process::id()));
        let _ = fs::remove_dir_all(&temp_root).await;
        fs::create_dir_all(&temp_root).await?;

        let room_key = generate_room_key();
        let room_id = "room-abc";
        let msg_id = "msg-xyz";
        let src = temp_root.join("secret.bin");
        let payload: Vec<u8> = (0..1_200_000u32).map(|i| (i % 199) as u8).collect();
        fs::write(&src, &payload).await?;

        let chunk_size = 512 * 1024;
        let enc_idx = index_encrypted_file(&src, chunk_size, &room_key, room_id, msg_id).await?;
        assert_ne!(enc_idx.plain_root_blake3, enc_idx.cipher_root_blake3);

        // Blind locker verifies and stores ciphertext without room_key.
        let locker_part = temp_root.join("locker.enc.part");
        for idx in 0..enc_idx.cipher_chunk_hashes.len() {
            let cipher_chunk =
                read_encrypted_chunk(&src, idx, chunk_size, &room_key, room_id, msg_id).await?;
            verify_and_write_chunk(
                &locker_part,
                idx,
                chunk_size,
                &enc_idx.cipher_chunk_hashes[idx],
                &cipher_chunk,
            )
            .await?;
        }
        let enc_final = finalize_blind_locker_file(
            &locker_part,
            &temp_root.join("locker"),
            msg_id,
            enc_idx.file_size,
            &enc_idx.cipher_root_blake3,
            chunk_size,
        )
        .await?;

        // Recipient pulls ciphertext from blind locker and decrypts with room_key.
        let recv_part = temp_root.join("recv.part");
        for idx in 0..enc_idx.cipher_chunk_hashes.len() {
            let cipher_chunk = read_chunk(&enc_final, idx, chunk_size).await?;
            verify_decrypt_and_write_chunk(
                &recv_part,
                idx,
                chunk_size,
                &enc_idx.cipher_chunk_hashes[idx],
                &enc_idx.plain_chunk_hashes[idx],
                &room_key,
                room_id,
                msg_id,
                &cipher_chunk,
            )
            .await?;
        }
        let plain_final = finalize_part_file(
            &recv_part,
            &temp_root.join("recv"),
            "secret.bin",
            enc_idx.file_size,
            &enc_idx.plain_root_blake3,
            chunk_size,
        )
        .await?;
        assert_eq!(fs::read(&plain_final).await?, payload);

        let _ = fs::remove_dir_all(&temp_root).await;
        Ok(())
    }

    #[test]
    fn sanitize_file_name_handles_illegal_reserved_and_traversal() {
        assert_eq!(
            sanitize_file_name("2026-11-19 14:30:05.png"),
            "2026-11-19 14_30_05.png"
        );
        assert_eq!(sanitize_file_name("../../evil/payload?.exe"), "payload_.exe");
        assert_eq!(sanitize_file_name(r"C:\tmp\CON.txt"), "_CON.txt");
        assert_eq!(sanitize_file_name("nul"), "_nul");
        assert_eq!(sanitize_file_name("  ..   "), "received_file");
        assert_eq!(sanitize_file_name("report... "), "report");
        assert_eq!(sanitize_file_name("a<b:c>d\"e|f*g.pdf"), "a_b_c_d_e_f_g.pdf");

        let long_stem = "中".repeat(90);
        let long_name = format!("{long_stem}.mp4");
        let sanitized = sanitize_file_name(&long_name);
        assert!(sanitized.len() <= 200);
        assert!(sanitized.ends_with(".mp4"));
    }

    #[test]
    fn validate_safe_id_rejects_traversal() {
        assert!(validate_safe_id("msg-big-1").is_ok());
        assert!(validate_safe_id("01933e1b_7a2c_7abc_8def_0123456789ab").is_ok());
        assert!(validate_safe_id("").is_err());
        assert!(validate_safe_id("../escape").is_err());
        assert!(validate_safe_id("a/b").is_err());
        assert!(validate_safe_id(r"a\b").is_err());
        assert!(validate_safe_id("bad id").is_err());
        assert!(validate_safe_id(&"a".repeat(129)).is_err());
    }
}
