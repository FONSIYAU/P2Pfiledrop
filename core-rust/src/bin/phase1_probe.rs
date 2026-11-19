//! Phase 1 CLI verification tool:
//! 1. Discovers physical LAN interfaces (excluding Clash/Mihomo/sing-tun/Hyper-V virtual NICs).
//! 2. Binds pinned UDP sockets on each physical NIC (`IP_UNICAST_IF` on Windows).
//! 3. Tests Iroh WAN/Relay connection + direct LAN physical-NIC UDP echo probe.

use anyhow::Result;
use p2p_chat_core::config::RelayPolicy;
use p2p_chat_core::net::lan_bypass::{
    create_pinned_lan_udp_socket, discover_physical_lan_interfaces,
};
use p2p_chat_core::net::wan_iroh::{PeerHandshakeTicket, WanIrohEndpoint};
use std::net::SocketAddr;
use tokio::net::UdpSocket as TokioUdpSocket;

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter("info")
        .init();

    let args: Vec<String> = std::env::args().collect();
    let mode = args.get(1).map(String::as_str).unwrap_or("inspect");

    let interfaces = discover_physical_lan_interfaces()?;
    println!("=== Discovered Physical LAN Interfaces ({}) ===", interfaces.len());
    for (idx, iface) in interfaces.iter().enumerate() {
        println!(
            "  [{}] if_index={} ip={} name={}",
            idx, iface.os_index, iface.local_ip, iface.name
        );
    }

    match mode {
        "inspect" => {
            println!("\n=== Binding Pinned LAN Sockets (TUN Bypass Check) ===");
            for iface in &interfaces {
                match create_pinned_lan_udp_socket(iface, 0) {
                    Ok(sock) => {
                        let local = sock.local_addr()?;
                        println!("  [OK] Pinned {} -> {}", iface.name, local);
                    }
                    Err(e) => {
                        println!("  [ERR] Failed to pin {}: {e:#}", iface.name);
                    }
                }
            }

            println!("\n=== Testing Iroh Relay Online Handshake (Option A) ===");
            let wan = WanIrohEndpoint::bind(&RelayPolicy::DefaultPublic).await?;
            wan.wait_online().await;
            let addr = wan.addr();
            println!("  [OK] Iroh EndpointId: {}", addr.id);
            println!("  [OK] Iroh Relay/Addr: {:?}", addr);
            wan.close().await;
        }
        "listen" => {
            let mut lan_addrs = Vec::new();
            for iface in &interfaces {
                let std_sock = create_pinned_lan_udp_socket(iface, 0)?;
                let local = std_sock.local_addr()?;
                lan_addrs.push(local);
                let tokio_sock = TokioUdpSocket::from_std(std_sock)?;
                tokio::spawn(async move {
                    let mut buf = [0u8; 2048];
                    loop {
                        if let Ok((len, peer)) = tokio_sock.recv_from(&mut buf).await {
                            let msg = String::from_utf8_lossy(&buf[..len]);
                            println!("[LAN BYPASS RECV from {peer}] {msg}");
                            let _ = tokio_sock.send_to(b"PONG_LAN_BYPASS", peer).await;
                        }
                    }
                });
            }

            let wan = WanIrohEndpoint::bind(&RelayPolicy::DefaultPublic).await?;
            wan.wait_online().await;
            let ticket = PeerHandshakeTicket {
                endpoint_addr: wan.addr(),
                lan_probe_addrs: lan_addrs,
            };
            println!("\n=== SHARE THIS TICKET WITH PEER ===");
            println!("{}", serde_json::to_string(&ticket)?);
            println!("====================================\n");

            while let Some(incoming) = wan.inner().accept().await {
                tokio::spawn(async move {
                    if let Ok(conn) = incoming.await {
                        println!("[IROH ACCEPT] connected from {}", conn.remote_id());
                        if let Ok(mut recv) = conn.accept_uni().await {
                            let mut buf = Vec::new();
                            let _ = tokio::io::AsyncReadExt::read_to_end(&mut recv, &mut buf).await;
                            println!(
                                "[IROH RECV] {}",
                                String::from_utf8_lossy(&buf)
                            );
                        }
                    }
                });
            }
        }
        "dial" => {
            let ticket_json = args
                .get(2)
                .expect("usage: phase1_probe dial '<ticket_json>'");
            let ticket: PeerHandshakeTicket = serde_json::from_str(ticket_json)?;

            // 1. Test Iroh WAN/Relay path
            let wan = WanIrohEndpoint::bind(&RelayPolicy::DefaultPublic).await?;
            wan.wait_online().await;
            let conn = wan.connect(ticket.endpoint_addr).await?;
            let mut send = conn.open_uni().await?;
            send.write_all(b"Hello via Iroh WAN/Relay!").await?;
            send.finish()?;
            println!("[OK] Sent Iroh greeting");

            // 2. Test Physical-NIC Pinned LAN probe
            for iface in &interfaces {
                let std_sock = create_pinned_lan_udp_socket(iface, 0)?;
                let tokio_sock = TokioUdpSocket::from_std(std_sock)?;
                for target in &ticket.lan_probe_addrs {
                    if same_ip_family(iface.local_ip, *target) {
                        let _ = tokio_sock.send_to(b"PING_LAN_BYPASS", *target).await;
                        let mut buf = [0u8; 512];
                        if let Ok(Ok((n, from))) = tokio::time::timeout(
                            std::time::Duration::from_millis(800),
                            tokio_sock.recv_from(&mut buf),
                        )
                        .await
                        {
                            println!(
                                "[OK] Physical-NIC LAN bypass reply from {from} via {}: {}",
                                iface.name,
                                String::from_utf8_lossy(&buf[..n])
                            );
                        }
                    }
                }
            }

            wan.close().await;
        }
        _ => {
            println!("Usage: phase1_probe [inspect | listen | dial '<ticket_json>']");
        }
    }

    Ok(())
}

fn same_ip_family(local: std::net::IpAddr, remote: SocketAddr) -> bool {
    matches!(
        (local, remote),
        (std::net::IpAddr::V4(_), SocketAddr::V4(_))
            | (std::net::IpAddr::V6(_), SocketAddr::V6(_))
    )
}
