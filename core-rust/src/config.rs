//! Core configuration types for P2P Chat Transfer.

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Relay fallback policy (Option A: out-of-the-box public encrypted relay with optional override).
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum RelayPolicy {
    /// Use built-in public encrypted Iroh relay nodes for instant startup and NAT hole-punch signaling.
    DefaultPublic,
    /// Override with a user-supplied private relay URL (e.g. `https://relay.example.com`).
    Custom(String),
}

impl Default for RelayPolicy {
    fn default() -> Self {
        Self::DefaultPublic
    }
}

/// Top-level engine configuration shared across Windows and Android.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EngineConfig {
    /// Local storage directory for SQLite metadata, identity keys, and `.part` temp files.
    pub data_dir: PathBuf,
    /// Target directory where incoming files are automatically saved upon arrival.
    pub auto_receive_dir: PathBuf,
    /// Relay fallback mode (defaults to Option A: `DefaultPublic`).
    pub relay_policy: RelayPolicy,
    /// Fixed chunk size in bytes for BLAKE3 hashing and resumable transfers (default: 64 KiB).
    pub chunk_size_bytes: usize,
    /// Whether incoming files are automatically accepted and written to `auto_receive_dir`.
    pub auto_accept_files: bool,
    /// Whether to start the built-in USB HTTP bootstrap server on port 42420.
    pub enable_usb_bootstrap_http: bool,
}

impl EngineConfig {
    /// Creates a default configuration with direct auto-receive enabled.
    pub fn with_dirs(data_dir: PathBuf, auto_receive_dir: PathBuf) -> Self {
        Self {
            data_dir,
            auto_receive_dir,
            relay_policy: RelayPolicy::DefaultPublic,
            chunk_size_bytes: 64 * 1024,
            auto_accept_files: true,
            enable_usb_bootstrap_http: false,
        }
    }
}
