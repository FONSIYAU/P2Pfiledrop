//! Encrypted QUIC transport pinned to physical LAN and USB tethering interfaces
//! (`IP_UNICAST_IF` / `android_setsocknetwork`).
//!
//! Each physical NIC gets a `noq::Endpoint` bound to its pinned UDP socket, guaranteeing
//! that USB/LAN file transfers flow directly across hardware and never get hijacked by TUNs.

use crate::net::lan_bypass::{
    PhysicalLanInterface, create_pinned_lan_udp_socket, discover_physical_lan_interfaces,
    is_usb_tether_adapter,
};
use anyhow::{Context, Result, bail};
use iroh::{EndpointId, PublicKey, SecretKey};
use noq::crypto::rustls::{QuicClientConfig, QuicServerConfig};
use rustls::DigitallySignedStruct;
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer, ServerName, UnixTime};
use serde::{Deserialize, Serialize};
use std::net::{IpAddr, SocketAddr};
use std::sync::{Arc, Mutex, RwLock};
use tokio::io::AsyncWriteExt;

const LAN_AUTH_DOMAIN: &[u8] = b"p2p-chat-lan-auth-v1";
pub const PREFERRED_LAN_QUIC_PORT: u16 = 42425;

/// One physical-NIC-pinned QUIC listener/dialer endpoint.
#[derive(Clone)]
pub struct PinnedLanEndpoint {
    pub interface: PhysicalLanInterface,
    pub local_addr: SocketAddr,
    pub endpoint: noq::Endpoint,
}

/// Mutual Ed25519 challenge-response message exchanged immediately upon LAN QUIC connection.
#[derive(Debug, Serialize, Deserialize)]
struct LanAuthHello {
    endpoint_id: String,
    nonce: [u8; 32],
    /// Signature over `(LAN_AUTH_DOMAIN || nonce_challenged || my_endpoint_id)`.
    signature_bytes: Option<Vec<u8>>,
}

/// Manages all physical-NIC-pinned QUIC endpoints on the current device (supports live hot-plugging).
pub struct LanQuicManager {
    pub endpoints: RwLock<Vec<PinnedLanEndpoint>>,
    configs: Mutex<Option<(noq::ServerConfig, noq::ClientConfig)>>,
}

impl LanQuicManager {
    /// Creates an empty manager without performing NIC discovery or TLS cert generation yet.
    pub fn empty() -> Self {
        Self {
            endpoints: RwLock::new(Vec::new()),
            configs: Mutex::new(None),
        }
    }

    fn ensure_configs(&self) -> Result<(noq::ServerConfig, noq::ClientConfig)> {
        let mut guard = self.configs.lock().expect("lan configs lock poisoned");
        if let Some(cfg) = guard.as_ref() {
            return Ok(cfg.clone());
        }
        let built = build_lan_quic_configs()?;
        *guard = Some(built.clone());
        Ok(built)
    }

    /// Discovers physical LAN/USB adapters and binds an encrypted QUIC endpoint to each.
    pub fn bind_discovered(extra_interfaces: Vec<PhysicalLanInterface>) -> Result<Self> {
        let manager = Self::empty();
        let _ = manager.bind_missing_interfaces(extra_interfaces)?;
        Ok(manager)
    }

    /// Dynamically binds any newly plugged-in physical NICs (e.g., USB tether cable connected after startup)
    /// and returns only the newly created `PinnedLanEndpoint`s so accept loops can be spawned for them.
    pub fn bind_missing_interfaces(
        &self,
        extra_interfaces: Vec<PhysicalLanInterface>,
    ) -> Result<Vec<PinnedLanEndpoint>> {
        let mut ifaces = discover_physical_lan_interfaces()?;
        for extra in extra_interfaces {
            if !ifaces.iter().any(|i| i.local_ip == extra.local_ip) {
                ifaces.push(extra);
            }
        }
        ifaces.sort_by_key(|i| (!i.is_usb_tether, !i.local_ip.is_ipv4()));
        if ifaces.is_empty() {
            return Ok(Vec::new());
        }

        let (server_config, client_config) = self.ensure_configs()?;
        let runtime = noq::default_runtime().context("no tokio runtime for noq")?;
        let mut guard = self.endpoints.write().expect("lan endpoints lock poisoned");
        let mut newly_added = Vec::new();

        for iface in ifaces {
            if guard.iter().any(|e| e.local_addr.ip() == iface.local_ip) {
                continue;
            }
            match create_pinned_lan_udp_socket(&iface, PREFERRED_LAN_QUIC_PORT)
                .or_else(|_| create_pinned_lan_udp_socket(&iface, 0))
            {
                Ok(std_sock) => {
                    let local_addr = std_sock.local_addr()?;
                    let ep = noq::Endpoint::new(
                        noq::EndpointConfig::default(),
                        Some(server_config.clone()),
                        std_sock,
                        runtime.clone(),
                    )?;
                    ep.set_default_client_config(client_config.clone());
                    tracing::info!(
                        "LAN QUIC pinned listener {} on {} (usb_tether={})",
                        local_addr,
                        iface.name,
                        iface.is_usb_tether
                    );
                    let pinned = PinnedLanEndpoint {
                        interface: iface,
                        local_addr,
                        endpoint: ep,
                    };
                    guard.push(pinned.clone());
                    newly_added.push(pinned);
                }
                Err(e) => {
                    tracing::warn!("skipping LAN interface {}: {e:#}", iface.name);
                }
            }
        }

        Ok(newly_added)
    }

    /// Reconciles active bound endpoints against currently live OS + Android physical interfaces,
    /// closing any vanished non-loopback NIC endpoints so stale LAN connections fail fast.
    pub fn reconcile_interfaces(
        &self,
        extra_interfaces: Vec<PhysicalLanInterface>,
    ) -> Result<(Vec<PinnedLanEndpoint>, Vec<IpAddr>)> {
        let mut live_ifaces = discover_physical_lan_interfaces()?;
        for extra in &extra_interfaces {
            if !live_ifaces.iter().any(|i| i.local_ip == extra.local_ip) {
                live_ifaces.push(extra.clone());
            }
        }
        let live_ips: std::collections::HashSet<IpAddr> =
            live_ifaces.iter().map(|i| i.local_ip).collect();

        let removed_ips: Vec<IpAddr> = {
            let mut guard = self.endpoints.write().expect("lan endpoints lock poisoned");
            let mut removed = Vec::new();
            let mut kept = Vec::with_capacity(guard.len());
            for ep in guard.drain(..) {
                let ip = ep.local_addr.ip();
                if ip.is_loopback() || live_ips.contains(&ip) {
                    kept.push(ep);
                } else {
                    tracing::info!(
                        "closing stale LAN QUIC endpoint {} on vanished interface {}",
                        ep.local_addr,
                        ep.interface.name
                    );
                    ep.endpoint.close(0u32.into(), b"interface down");
                    removed.push(ip);
                }
            }
            *guard = kept;
            removed
        };

        let added = self.bind_missing_interfaces(extra_interfaces)?;
        Ok((added, removed_ips))
    }

    /// Returns a snapshot of all bound `PinnedLanEndpoint`s.
    pub fn snapshot_endpoints(&self) -> Vec<PinnedLanEndpoint> {
        self.endpoints
            .read()
            .expect("lan endpoints lock poisoned")
            .clone()
    }

    /// Returns all bound physical-NIC socket addresses (USB tether addresses sorted first).
    pub fn advertise_addrs(&self) -> Vec<SocketAddr> {
        let mut eps = self.snapshot_endpoints();
        eps.sort_by_key(|e| (!e.interface.is_usb_tether, !e.local_addr.is_ipv4()));
        eps.into_iter().map(|e| e.local_addr).collect()
    }

    /// Returns bound USB tethering IP addresses (used to construct bootstrap HTTP URLs).
    pub fn usb_tether_ips(&self) -> Vec<IpAddr> {
        self.snapshot_endpoints()
            .into_iter()
            .filter(|e| e.interface.is_usb_tether)
            .map(|e| e.local_addr.ip())
            .collect()
    }

    /// Returns `true` if this host has a local USB tethering interface on the same subnet as `remote_addr`.
    pub fn can_reach_via_usb(&self, remote_addr: SocketAddr) -> bool {
        let IpAddr::V4(remote_v4) = remote_addr.ip() else {
            return false;
        };
        let r_oct = remote_v4.octets();
        self.snapshot_endpoints().iter().any(|ep| {
            ep.interface.is_usb_tether
                && matches!(ep.local_addr.ip(), IpAddr::V4(lv4) if
                    (remote_v4.is_loopback() && lv4.is_loopback())
                    || lv4.octets()[0..3] == r_oct[0..3]
                )
        })
    }

    /// Dials `remote_addr` from the best matching physical-NIC endpoint (preferring same-subnet / USB)
    /// and verifies the peer's Ed25519 `expected_peer_id`. Returns `(connection, is_usb_tether)`.
    pub async fn connect_and_auth(
        &self,
        remote_addr: SocketAddr,
        local_key: &SecretKey,
        expected_peer_id: EndpointId,
    ) -> Result<(noq::Connection, bool)> {
        let endpoints = self.snapshot_endpoints();
        let endpoint = pick_best_endpoint_for_remote(&endpoints, remote_addr)
            .context("no matching physical LAN interface for target IP family")?;

        let is_usb = endpoint.interface.is_usb_tether
            || is_usb_tether_adapter("", &remote_addr.ip());
        let connecting = endpoint.endpoint.connect(remote_addr, "p2p-lan.local")?;
        let conn = connecting.await.context("LAN QUIC handshake failed")?;

        authenticate_initiator(&conn, local_key, expected_peer_id).await?;
        Ok((conn, is_usb))
    }

    /// Returns `true` if `remote_ip` belongs to a local LAN segment (private IPv4, loopback/ULA/link-local,
    /// or a non-cellular interface sharing the same `/64` global IPv6 prefix).
    pub fn is_local_lan_address(&self, remote_ip: IpAddr) -> bool {
        let ifaces: Vec<PhysicalLanInterface> = self
            .snapshot_endpoints()
            .into_iter()
            .map(|ep| ep.interface)
            .collect();
        is_same_lan_ip(remote_ip, &ifaces)
    }
}

/// Returns `true` when `name` refers to an Android/embedded cellular network interface.
pub fn is_cellular_interface_name(name: &str) -> bool {
    let lower = name.trim().to_ascii_lowercase();
    ["rmnet", "ccmni", "pdp", "wwan", "clat"]
        .iter()
        .any(|prefix| lower.starts_with(prefix))
}

/// Distinguishes same-LAN peers from direct global-IPv6 cellular/WAN peers.
pub fn is_same_lan_ip(remote_ip: IpAddr, local_ifaces: &[PhysicalLanInterface]) -> bool {
    if remote_ip.is_loopback() {
        return true;
    }
    match remote_ip {
        IpAddr::V4(v4) => v4.is_private() || v4.is_link_local(),
        IpAddr::V6(v6) => {
            let seg0 = v6.segments()[0];
            if (seg0 & 0xfe00) == 0xfc00 || (seg0 & 0xffc0) == 0xfe80 {
                return true;
            }
            let remote_prefix = &v6.segments()[0..4];
            local_ifaces.iter().any(|iface| {
                !is_cellular_interface_name(&iface.name)
                    && matches!(iface.local_ip, IpAddr::V6(lv6) if &lv6.segments()[0..4] == remote_prefix)
            })
        }
    }
}

fn pick_best_endpoint_for_remote(
    endpoints: &[PinnedLanEndpoint],
    remote_addr: SocketAddr,
) -> Option<PinnedLanEndpoint> {
    let same_family: Vec<&PinnedLanEndpoint> = endpoints
        .iter()
        .filter(|ep| ep.local_addr.is_ipv4() == remote_addr.is_ipv4())
        .collect();
    if same_family.is_empty() {
        return None;
    }

    if let IpAddr::V4(remote_v4) = remote_addr.ip() {
        if remote_v4.is_loopback() {
            return same_family
                .iter()
                .find(|ep| ep.local_addr.ip().is_loopback())
                .or_else(|| same_family.first())
                .map(|ep| (*ep).clone());
        }

        let r_oct = remote_v4.octets();
        // 1. Exact /24 subnet match (e.g., USB tether 192.168.42.x -> 192.168.42.y or same Wi-Fi LAN)
        if let Some(matched) = same_family.iter().find(|ep| {
            matches!(ep.local_addr.ip(), IpAddr::V4(lv4) if lv4.octets()[0..3] == r_oct[0..3])
        }) {
            return Some((*matched).clone());
        }

        // 2. Non-USB /16 subnet match (e.g., larger office/campus LANs)
        if let Some(matched) = same_family.iter().find(|ep| {
            !ep.interface.is_usb_tether
                && matches!(ep.local_addr.ip(), IpAddr::V4(lv4) if lv4.octets()[0..2] == r_oct[0..2])
        }) {
            return Some((*matched).clone());
        }

        // Never dial an unrelated private IPv4 subnet (such as 192.168.x.x when on cellular)
        return None;
    }

    // For global IPv6 targets, prefer a non-USB physical interface (Wi-Fi/Ethernet/Cellular)
    same_family
        .iter()
        .find(|ep| !ep.interface.is_usb_tether)
        .or_else(|| same_family.first())
        .map(|ep| (*ep).clone())
}

/// Performs initiator-side Ed25519 mutual authentication on the first bidirectional control stream.
pub async fn authenticate_initiator(
    conn: &noq::Connection,
    local_key: &SecretKey,
    expected_peer_id: EndpointId,
) -> Result<()> {
    let (mut send, mut recv) = conn.open_bi().await?;
    let my_nonce = SecretKey::generate().to_bytes();
    let hello = LanAuthHello {
        endpoint_id: local_key.public().to_string(),
        nonce: my_nonce,
        signature_bytes: None,
    };
    write_auth_msg(&mut send, &hello).await?;

    let peer_hello = read_auth_msg(&mut recv).await?;
    let peer_pub: PublicKey = peer_hello.endpoint_id.parse()?;
    if peer_pub != expected_peer_id {
        bail!("LAN peer EndpointId mismatch: expected {expected_peer_id}, got {peer_pub}");
    }

    let sig_bytes = peer_hello
        .signature_bytes
        .context("missing peer signature in LAN auth")?;
    let sig_arr: [u8; 64] = sig_bytes
        .try_into()
        .map_err(|_| anyhow::anyhow!("invalid Ed25519 signature length"))?;
    let sig = iroh::Signature::from_bytes(&sig_arr);
    let challenge_payload = auth_transcript(&my_nonce, &peer_pub);
    peer_pub
        .verify(&challenge_payload, &sig)
        .context("LAN peer Ed25519 signature verification failed")?;

    let my_sig = local_key.sign(&auth_transcript(&peer_hello.nonce, &local_key.public()));
    let proof = LanAuthHello {
        endpoint_id: local_key.public().to_string(),
        nonce: [0u8; 32],
        signature_bytes: Some(my_sig.to_bytes().to_vec()),
    };
    write_auth_msg(&mut send, &proof).await?;
    send.finish()?;
    Ok(())
}

/// Performs responder-side Ed25519 mutual authentication and returns the verified peer `EndpointId`.
pub async fn authenticate_responder(
    conn: &noq::Connection,
    local_key: &SecretKey,
) -> Result<EndpointId> {
    let (mut send, mut recv) = conn.accept_bi().await?;
    let peer_hello = read_auth_msg(&mut recv).await?;
    let peer_pub: PublicKey = peer_hello.endpoint_id.parse()?;

    let my_nonce = SecretKey::generate().to_bytes();
    let my_sig = local_key.sign(&auth_transcript(&peer_hello.nonce, &local_key.public()));
    let reply = LanAuthHello {
        endpoint_id: local_key.public().to_string(),
        nonce: my_nonce,
        signature_bytes: Some(my_sig.to_bytes().to_vec()),
    };
    write_auth_msg(&mut send, &reply).await?;
    send.finish()?;

    let peer_proof = read_auth_msg(&mut recv).await?;
    let sig_bytes = peer_proof
        .signature_bytes
        .context("missing initiator signature in LAN auth")?;
    let sig_arr: [u8; 64] = sig_bytes
        .try_into()
        .map_err(|_| anyhow::anyhow!("invalid Ed25519 signature length"))?;
    let sig = iroh::Signature::from_bytes(&sig_arr);
    peer_pub
        .verify(&auth_transcript(&my_nonce, &peer_pub), &sig)
        .context("initiator Ed25519 signature verification failed")?;

    Ok(peer_pub)
}

fn auth_transcript(nonce: &[u8; 32], signer: &PublicKey) -> Vec<u8> {
    let mut out = Vec::with_capacity(LAN_AUTH_DOMAIN.len() + 32 + 32);
    out.extend_from_slice(LAN_AUTH_DOMAIN);
    out.extend_from_slice(nonce);
    out.extend_from_slice(signer.as_bytes());
    out
}

async fn write_auth_msg(send: &mut noq::SendStream, msg: &LanAuthHello) -> Result<()> {
    let bytes = serde_json::to_vec(msg)?;
    let len = (bytes.len() as u32).to_be_bytes();
    send.write_all(&len).await?;
    send.write_all(&bytes).await?;
    send.flush().await?;
    Ok(())
}

async fn read_auth_msg(recv: &mut noq::RecvStream) -> Result<LanAuthHello> {
    let mut len_buf = [0u8; 4];
    recv.read_exact(&mut len_buf).await?;
    let len = u32::from_be_bytes(len_buf) as usize;
    if len > 16 * 1024 {
        bail!("LAN auth message too large: {len}");
    }
    let mut buf = vec![0u8; len];
    recv.read_exact(&mut buf).await?;
    Ok(serde_json::from_slice(&buf)?)
}

fn build_lan_quic_configs() -> Result<(noq::ServerConfig, noq::ClientConfig)> {
    let cert = rcgen::generate_simple_self_signed(vec!["p2p-lan.local".to_string()])?;
    let cert_der = CertificateDer::from(cert.cert);
    let key_der = PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(cert.key_pair.serialize_der()));

    let provider = Arc::new(rustls::crypto::ring::default_provider());

    let mut transport = noq::TransportConfig::default();
    transport.keep_alive_interval(Some(std::time::Duration::from_secs(3)));
    transport.max_idle_timeout(Some(
        std::time::Duration::from_secs(10)
            .try_into()
            .expect("valid idle timeout"),
    ));
    transport.stream_receive_window(noq::VarInt::from_u32(2 * 1024 * 1024));
    transport.receive_window(noq::VarInt::from_u32(4 * 1024 * 1024));
    transport.send_window(2 * 1024 * 1024);
    let mut mtu = noq::MtuDiscoveryConfig::default();
    mtu.upper_bound(1350);
    transport.mtu_discovery_config(Some(mtu));
    transport.enable_segmentation_offload(false);
    let transport_cfg = Arc::new(transport);

    let server_crypto = rustls::ServerConfig::builder_with_provider(provider.clone())
        .with_safe_default_protocol_versions()?
        .with_no_client_auth()
        .with_single_cert(vec![cert_der], key_der)?;
    let mut server_config =
        noq::ServerConfig::with_crypto(Arc::new(QuicServerConfig::try_from(server_crypto)?));
    server_config.transport_config(transport_cfg.clone());

    let client_crypto = rustls::ClientConfig::builder_with_provider(provider)
        .with_safe_default_protocol_versions()?
        .dangerous()
        .with_custom_certificate_verifier(Arc::new(AcceptAnySelfSignedTlsCert))
        .with_no_client_auth();
    let mut client_config =
        noq::ClientConfig::new(Arc::new(QuicClientConfig::try_from(client_crypto)?));
    client_config.transport_config(transport_cfg);

    Ok((server_config, client_config))
}

#[derive(Debug)]
struct AcceptAnySelfSignedTlsCert;

impl ServerCertVerifier for AcceptAnySelfSignedTlsCert {
    fn verify_server_cert(
        &self,
        _end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> std::result::Result<ServerCertVerified, rustls::Error> {
        Ok(ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, rustls::Error> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn verify_tls13_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, rustls::Error> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<rustls::SignatureScheme> {
        vec![
            rustls::SignatureScheme::ECDSA_NISTP256_SHA256,
            rustls::SignatureScheme::ED25519,
            rustls::SignatureScheme::RSA_PSS_SHA256,
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn iface(name: &str, ip: &str) -> PhysicalLanInterface {
        PhysicalLanInterface {
            os_index: 1,
            name: name.to_string(),
            local_ip: ip.parse().unwrap(),
            android_network_handle: None,
            is_usb_tether: false,
        }
    }

    #[test]
    fn classifies_private_v4_as_local_lan() {
        let local = vec![iface("WLAN", "192.168.1.14")];
        assert!(is_same_lan_ip("192.168.1.2".parse().unwrap(), &local));
        assert!(is_same_lan_ip("127.0.0.1".parse().unwrap(), &local));
        assert!(!is_same_lan_ip("8.8.8.8".parse().unwrap(), &local));
    }

    #[test]
    fn classifies_same_slash64_non_cellular_v6_as_lan_and_cross_carrier_as_wan() {
        let pc_ifaces = vec![iface(
            "以太网 4",
            "2409:8a55:292:7ce0:71fc:a622:5d63:d706",
        )];
        // Same home broadband /64 on phone Wi-Fi -> local LAN
        assert!(is_same_lan_ip(
            "2409:8a55:292:7ce0:54b5:38ff:fe65:db02".parse().unwrap(),
            &pc_ifaces
        ));
        // Different /64 on 5G cellular (China Broadcast 5G) -> WAN
        assert!(!is_same_lan_ip(
            "240a:42cc:403:17d7:eccd:6cff:fe5e:8f8d".parse().unwrap(),
            &pc_ifaces
        ));
    }

    #[test]
    fn cellular_interface_v6_never_treated_as_local_lan_even_on_same_prefix() {
        let cell_ifaces = vec![iface(
            "rmnet_data3",
            "240a:42cc:403:17d7:eccd:6cff:fe5e:8f8d",
        )];
        assert!(!is_same_lan_ip(
            "240a:42cc:403:17d7:1111:2222:3333:4444".parse().unwrap(),
            &cell_ifaces
        ));
    }
}
