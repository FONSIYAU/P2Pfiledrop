//! WAN P2P hole-punching and encrypted Relay fallback built on `iroh`.
//!
//! This channel runs strictly on ordinary user-space UDP/HTTPS sockets (zero TUN adapters),
//! ensuring full compatibility with existing VPNs on both Windows and Android.

use crate::config::RelayPolicy;
use anyhow::{Context, Result};
use iroh::endpoint::presets;
use iroh::{Endpoint, EndpointAddr, RelayMap, RelayMode, RelayUrl, SecretKey};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;

/// Application-Layer Protocol Negotiation identifier for our P2P chat transfer protocol.
pub const CHAT_TRANSFER_ALPN: &[u8] = b"p2p-chat-transfer/1";

/// Compact connection ticket exchanged during pairing or out-of-band handshake.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerHandshakeTicket {
    pub endpoint_addr: EndpointAddr,
    pub lan_probe_addrs: Vec<SocketAddr>,
}

/// Manages the `iroh::Endpoint` for WAN P2P hole-punching and relay fallback.
pub struct WanIrohEndpoint {
    endpoint: Endpoint,
}

impl WanIrohEndpoint {
    /// Binds an Iroh endpoint with a persistent `SecretKey` and configured `RelayPolicy`.
    pub async fn bind_with_key(secret_key: SecretKey, relay_policy: &RelayPolicy) -> Result<Self> {
        let relay_mode = match relay_policy {
            RelayPolicy::DefaultPublic => RelayMode::Default,
            RelayPolicy::Custom(url) => {
                let parsed: RelayUrl = url
                    .parse()
                    .with_context(|| format!("invalid custom relay URL: {url}"))?;
                RelayMode::Custom(RelayMap::from_iter([parsed]))
            }
        };

        let endpoint = Endpoint::builder(presets::N0)
            .secret_key(secret_key)
            .relay_mode(relay_mode)
            .alpns(vec![CHAT_TRANSFER_ALPN.to_vec()])
            .bind()
            .await
            .context("failed to bind Iroh WAN endpoint")?;

        Ok(Self { endpoint })
    }

    /// Binds an ephemeral Iroh endpoint (convenience wrapper for probes/tests).
    pub async fn bind(relay_policy: &RelayPolicy) -> Result<Self> {
        Self::bind_with_key(SecretKey::generate(), relay_policy).await
    }

    /// Waits until the endpoint connects to its home relay and learns public candidates.
    pub async fn wait_online(&self) {
        self.endpoint.online().await;
    }

    /// Notifies the underlying Iroh endpoint that OS network interfaces changed (e.g. Wi-Fi -> 5G).
    pub async fn network_change(&self) {
        self.endpoint.network_change().await;
    }

    /// Returns a reference to the underlying `iroh::Endpoint`.
    pub fn inner(&self) -> &Endpoint {
        &self.endpoint
    }

    /// Returns the local `EndpointAddr` (EndpointId + RelayUrl + direct addresses).
    pub fn addr(&self) -> EndpointAddr {
        self.endpoint.addr()
    }

    /// Connects to a peer over Iroh (starts with relay if needed, upgrades to P2P hole punch).
    pub async fn connect(&self, peer_addr: EndpointAddr) -> Result<iroh::endpoint::Connection> {
        self.endpoint
            .connect(peer_addr, CHAT_TRANSFER_ALPN)
            .await
            .context("failed to connect to peer via Iroh")
    }

    /// Gracefully shuts down the endpoint.
    pub async fn close(self) {
        self.endpoint.close().await;
    }
}
