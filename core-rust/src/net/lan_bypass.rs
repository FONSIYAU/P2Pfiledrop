//! Physical-NIC discovery, USB tethering detection, anti-route-hijack metric protection,
//! and socket pinning to bypass proxy TUN virtual adapters.
//!
//! Why this exists:
//! 1. When proxy tools (Clash/Mihomo, Sing-box, etc.) run in TUN global mode, they inject
//!    high-priority routes that hijack ordinary UDP sockets bound to `0.0.0.0`.
//! 2. When a user connects an Android Home Node over USB Tethering (RNDIS/NCM), Windows may
//!    assign a low default route metric to the USB NIC and route normal internet traffic
//!    through the phone. We pin our QUIC sockets explicitly to physical NICs AND raise the
//!    USB NIC's OS route metric to `5000` so normal internet traffic keeps using broadband/Wi-Fi.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use socket2::{Domain, Protocol, Socket, Type};
use std::net::{IpAddr, SocketAddr};

/// Known virtual / TUN adapter keywords excluded from LAN physical-NIC selection.
pub const VIRTUAL_ADAPTER_KEYWORDS: &[&str] = &[
    "mihomo",
    "clash",
    "sing-tun",
    "singbox",
    "wintun",
    "wireguard",
    "tailscale",
    "zerotier",
    "tap-",
    "tun",
    "hyper-v",
    "vethernet",
    "vmware",
    "virtualbox",
    "vbox",
    "loopback",
    "pseudo",
    "npcap",
    "vnic",
];

/// Keywords identifying USB tethering adapters (RNDIS / NCM / Android USB share).
pub const USB_TETHER_KEYWORDS: &[&str] = &[
    "rndis",
    "remote ndis",
    "usbncm",
    "usb ethernet",
    "android",
    "usb0",
    "ncm0",
    "tether",
];

/// Represents a physical LAN or USB tether network interface eligible for direct peer-to-peer traffic.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PhysicalLanInterface {
    /// OS interface index (`IfIndex` / `Ipv6IfIndex` on Windows, `ifindex` on Android).
    pub os_index: u32,
    /// Human-readable adapter name or description.
    pub name: String,
    /// Local IPv4/IPv6 address assigned to this physical interface.
    pub local_ip: IpAddr,
    /// Android `Network.getNetworkHandle()` value when supplied by the Android host layer.
    pub android_network_handle: Option<i64>,
    /// True if this adapter is a USB tethering dedicated-line interface (RNDIS / NCM / rndis0).
    pub is_usb_tether: bool,
}

/// Status of Windows anti-route-hijack metric protection for USB tethering.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct UsbRouteProtectionStatus {
    pub usb_tether_detected: bool,
    pub usb_if_index: Option<u32>,
    pub usb_if_name: Option<String>,
    pub usb_local_ip: Option<String>,
    pub metric_protected: bool,
    pub needs_elevation: bool,
    pub message: String,
}

/// Returns `true` if an adapter name/description looks like a virtual or TUN adapter.
pub fn is_virtual_adapter_name(name_or_desc: &str) -> bool {
    let lower = name_or_desc.to_ascii_lowercase();
    VIRTUAL_ADAPTER_KEYWORDS
        .iter()
        .any(|kw| lower.contains(kw))
}

/// Returns `true` if an adapter name/description or IP belongs to Android/Windows USB tethering.
pub fn is_usb_tether_adapter(name_or_desc: &str, ip: &IpAddr) -> bool {
    let lower = name_or_desc.to_ascii_lowercase();
    if USB_TETHER_KEYWORDS.iter().any(|kw| lower.contains(kw)) {
        return true;
    }
    if let IpAddr::V4(v4) = ip {
        let oct = v4.octets();
        // Android standard USB tethering subnet (192.168.42.0/24)
        if oct[0] == 192 && oct[1] == 168 && oct[2] == 42 {
            return true;
        }
    }
    false
}

/// Filters out loopback, unspecified, multicast, and link-local addresses not useful for LAN peers.
pub fn is_usable_lan_ip(ip: &IpAddr) -> bool {
    match ip {
        IpAddr::V4(v4) => {
            !v4.is_loopback()
                && !v4.is_unspecified()
                && !v4.is_link_local()
                && !v4.is_multicast()
        }
        IpAddr::V6(v6) => {
            !v6.is_loopback()
                && !v6.is_unspecified()
                && !v6.is_multicast()
                && !v6.is_unicast_link_local()
        }
    }
}

/// Discovers active physical Ethernet/Wi-Fi/USB-tether interfaces on the current host.
#[cfg(all(windows, not(test)))]
pub fn discover_physical_lan_interfaces() -> Result<Vec<PhysicalLanInterface>> {
    use std::net::{Ipv4Addr, Ipv6Addr};
    use windows_sys::Win32::Foundation::{ERROR_BUFFER_OVERFLOW, ERROR_SUCCESS};
    use windows_sys::Win32::NetworkManagement::IpHelper::{
        GAA_FLAG_SKIP_ANYCAST, GAA_FLAG_SKIP_DNS_SERVER, GAA_FLAG_SKIP_MULTICAST,
        GetAdaptersAddresses, IP_ADAPTER_ADDRESSES_LH,
    };
    use windows_sys::Win32::NetworkManagement::Ndis::IfOperStatusUp;
    use windows_sys::Win32::Networking::WinSock::{
        AF_INET, AF_INET6, AF_UNSPEC, SOCKADDR_IN, SOCKADDR_IN6,
    };

    const IF_TYPE_OTHER: u32 = 1;
    const IF_TYPE_ETHERNET_CSMACD: u32 = 6;
    const IF_TYPE_IEEE80211: u32 = 71;

    let flags = GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER;
    let mut size: u32 = 16 * 1024;
    let mut buffer = vec![0u8; size as usize];

    let mut ret = unsafe {
        GetAdaptersAddresses(
            AF_UNSPEC as u32,
            flags,
            std::ptr::null_mut(),
            buffer.as_mut_ptr() as *mut IP_ADAPTER_ADDRESSES_LH,
            &mut size,
        )
    };

    if ret == ERROR_BUFFER_OVERFLOW {
        buffer.resize(size as usize, 0);
        ret = unsafe {
            GetAdaptersAddresses(
                AF_UNSPEC as u32,
                flags,
                std::ptr::null_mut(),
                buffer.as_mut_ptr() as *mut IP_ADAPTER_ADDRESSES_LH,
                &mut size,
            )
        };
    }

    if ret != ERROR_SUCCESS {
        anyhow::bail!("GetAdaptersAddresses failed with Win32 error code {ret}");
    }

    let mut result = Vec::new();
    let mut curr = buffer.as_ptr() as *const IP_ADAPTER_ADDRESSES_LH;

    while !curr.is_null() {
        let adapter = unsafe { &*curr };
        let if_type = adapter.IfType;
        let is_up = adapter.OperStatus == IfOperStatusUp;

        if is_up
            && (if_type == IF_TYPE_ETHERNET_CSMACD
                || if_type == IF_TYPE_IEEE80211
                || if_type == IF_TYPE_OTHER)
        {
            let friendly = unsafe { pwstr_to_string(adapter.FriendlyName) };
            let desc = unsafe { pwstr_to_string(adapter.Description) };
            let combined = format!("{friendly} ({desc})");

            let allow_type = if_type != IF_TYPE_OTHER
                || is_usb_tether_adapter(&combined, &IpAddr::V4(Ipv4Addr::UNSPECIFIED));

            if allow_type && !is_virtual_adapter_name(&friendly) && !is_virtual_adapter_name(&desc)
            {
                let ipv4_idx = unsafe { adapter.Anonymous1.Anonymous.IfIndex };
                let ipv6_idx = adapter.Ipv6IfIndex;

                let mut unicast = adapter.FirstUnicastAddress;
                while !unicast.is_null() {
                    let ua = unsafe { &*unicast };
                    let sockaddr_ptr = ua.Address.lpSockaddr;
                    if !sockaddr_ptr.is_null() {
                        let family = unsafe { (*sockaddr_ptr).sa_family };
                        if family == AF_INET as u16 && ipv4_idx != 0 {
                            let sin = unsafe { &*(sockaddr_ptr as *const SOCKADDR_IN) };
                            let octets = unsafe { sin.sin_addr.S_un.S_addr.to_ne_bytes() };
                            let ip = IpAddr::V4(Ipv4Addr::from(octets));
                            if is_usable_lan_ip(&ip) {
                                result.push(PhysicalLanInterface {
                                    os_index: ipv4_idx,
                                    name: combined.clone(),
                                    local_ip: ip,
                                    android_network_handle: None,
                                    is_usb_tether: is_usb_tether_adapter(&combined, &ip),
                                });
                            }
                        } else if family == AF_INET6 as u16 && ipv6_idx != 0 {
                            let sin6 = unsafe { &*(sockaddr_ptr as *const SOCKADDR_IN6) };
                            let octets = unsafe { sin6.sin6_addr.u.Byte };
                            let ip = IpAddr::V6(Ipv6Addr::from(octets));
                            if is_usable_lan_ip(&ip) {
                                result.push(PhysicalLanInterface {
                                    os_index: ipv6_idx,
                                    name: combined.clone(),
                                    local_ip: ip,
                                    android_network_handle: None,
                                    is_usb_tether: is_usb_tether_adapter(&combined, &ip),
                                });
                            }
                        }
                    }
                    unicast = ua.Next;
                }
            }
        }

        curr = adapter.Next;
    }

    // Prioritize USB tethering dedicated-line interfaces ahead of Wi-Fi/Ethernet.
    result.sort_by_key(|i| (!i.is_usb_tether, !i.local_ip.is_ipv4()));
    Ok(result)
}

#[cfg(all(windows, not(test)))]
unsafe fn pwstr_to_string(ptr: *const u16) -> String {
    if ptr.is_null() {
        return String::new();
    }
    let mut len = 0usize;
    unsafe {
        while *ptr.add(len) != 0 {
            len += 1;
        }
        let slice = std::slice::from_raw_parts(ptr, len);
        String::from_utf16_lossy(slice)
    }
}

#[cfg(any(not(windows), test))]
pub fn discover_physical_lan_interfaces() -> Result<Vec<PhysicalLanInterface>> {
    // On Android, physical Wi-Fi/Ethernet NetworkHandles (`NET_CAPABILITY_NOT_VPN`)
    // and USB tethering interfaces (`rndis0`/`usb0`/`ncm0`) are discovered via Kotlin and passed over FFI.
    Ok(Vec::new())
}

/// Ensures Windows does NOT hijack broadband/Wi-Fi default internet routes when an Android USB
/// tethering adapter is connected, by raising the USB adapter's IPv4 metric to `5000`.
#[cfg(windows)]
pub fn ensure_usb_tether_metric_safe() -> Result<UsbRouteProtectionStatus> {
    use std::os::windows::process::CommandExt;
    const CREATE_NO_WINDOW: u32 = 0x08000000;

    let ifaces = discover_physical_lan_interfaces()?;
    let usb_iface = ifaces
        .iter()
        .find(|i| i.is_usb_tether && i.local_ip.is_ipv4());

    let Some(usb) = usb_iface else {
        return Ok(UsbRouteProtectionStatus {
            usb_tether_detected: false,
            usb_if_index: None,
            usb_if_name: None,
            usb_local_ip: None,
            metric_protected: true,
            needs_elevation: false,
            message: "未检测到 USB 共享网卡".to_string(),
        });
    };

    let has_other_uplink = ifaces
        .iter()
        .any(|i| !i.is_usb_tether && i.local_ip.is_ipv4());
    if !has_other_uplink {
        return Ok(UsbRouteProtectionStatus {
            usb_tether_detected: true,
            usb_if_index: Some(usb.os_index),
            usb_if_name: Some(usb.name.clone()),
            usb_local_ip: Some(usb.local_ip.to_string()),
            metric_protected: true,
            needs_elevation: false,
            message: "检测到 USB 专线（当前无其他活动物理网卡，无需调整跃点数）".to_string(),
        });
    }

    // Check current metric from `netsh interface ipv4 show interfaces`
    if let Some(metric) = query_windows_interface_metric(usb.os_index)
        && metric >= 5000
    {
        return Ok(UsbRouteProtectionStatus {
            usb_tether_detected: true,
            usb_if_index: Some(usb.os_index),
            usb_if_name: Some(usb.name.clone()),
            usb_local_ip: Some(usb.local_ip.to_string()),
            metric_protected: true,
            needs_elevation: false,
            message: format!(
                "USB 防抢网已生效 (接口跃点数 Metric={}，电脑宽带上网不受影响)",
                metric
            ),
        });
    }

    // Attempt silent non-interactive adjustment (succeeds if elevated or allowed by policy).
    let output = std::process::Command::new("netsh")
        .args([
            "interface",
            "ipv4",
            "set",
            "interface",
            &usb.os_index.to_string(),
            "metric=5000",
        ])
        .creation_flags(CREATE_NO_WINDOW)
        .output();

    if let Ok(out) = output
        && out.status.success()
    {
        tracing::info!(
            "set USB tether interface {} metric=5000 to protect host internet",
            usb.os_index
        );
        return Ok(UsbRouteProtectionStatus {
            usb_tether_detected: true,
            usb_if_index: Some(usb.os_index),
            usb_if_name: Some(usb.name.clone()),
            usb_local_ip: Some(usb.local_ip.to_string()),
            metric_protected: true,
            needs_elevation: false,
            message: "已自动将 USB 网卡跃点数设为 5000，确保不劫持电脑宽带流量".to_string(),
        });
    }

    Ok(UsbRouteProtectionStatus {
        usb_tether_detected: true,
        usb_if_index: Some(usb.os_index),
        usb_if_name: Some(usb.name.clone()),
        usb_local_ip: Some(usb.local_ip.to_string()),
        metric_protected: false,
        needs_elevation: true,
        message: "检测到 USB 共享网卡，请点击“一键防抢网”授予一次管理员权限将 USB 跃点数设为 5000"
            .to_string(),
    })
}

#[cfg(windows)]
fn query_windows_interface_metric(os_index: u32) -> Option<u32> {
    use std::os::windows::process::CommandExt;
    const CREATE_NO_WINDOW: u32 = 0x08000000;

    let out = std::process::Command::new("netsh")
        .args(["interface", "ipv4", "show", "interfaces"])
        .creation_flags(CREATE_NO_WINDOW)
        .output()
        .ok()?;
    let stdout = String::from_utf8_lossy(&out.stdout);
    let idx_str = os_index.to_string();
    for line in stdout.lines() {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() >= 4 && cols[0] == idx_str {
            return cols[1].parse::<u32>().ok();
        }
    }
    None
}

/// Requests UAC elevation once on Windows to permanently set the USB tethering adapter metric to 5000.
#[cfg(windows)]
pub fn elevate_and_fix_usb_metric(os_index: u32) -> Result<UsbRouteProtectionStatus> {
    use std::os::windows::process::CommandExt;
    const CREATE_NO_WINDOW: u32 = 0x08000000;

    let ps_cmd = format!(
        "Start-Process netsh -ArgumentList 'interface ipv4 set interface {os_index} metric=5000' -Verb RunAs -Wait"
    );
    let status = std::process::Command::new("powershell")
        .args(["-NoProfile", "-WindowStyle", "Hidden", "-Command", &ps_cmd])
        .creation_flags(CREATE_NO_WINDOW)
        .status()
        .context("failed to launch UAC prompt for USB metric protection")?;

    if !status.success() {
        anyhow::bail!("UAC elevation was cancelled or failed");
    }
    ensure_usb_tether_metric_safe()
}

#[cfg(not(windows))]
pub fn ensure_usb_tether_metric_safe() -> Result<UsbRouteProtectionStatus> {
    Ok(UsbRouteProtectionStatus {
        usb_tether_detected: false,
        usb_if_index: None,
        usb_if_name: None,
        usb_local_ip: None,
        metric_protected: true,
        needs_elevation: false,
        message: "非 Windows 平台无需调整 USB 路由跃点数".to_string(),
    })
}

#[cfg(not(windows))]
pub fn elevate_and_fix_usb_metric(_os_index: u32) -> Result<UsbRouteProtectionStatus> {
    ensure_usb_tether_metric_safe()
}

/// Creates a non-blocking UDP socket pinned to a specific physical LAN/USB interface,
/// bypassing system TUN/VPN routing tables.
pub fn create_pinned_lan_udp_socket(
    iface: &PhysicalLanInterface,
    port: u16,
) -> Result<std::net::UdpSocket> {
    let domain = match iface.local_ip {
        IpAddr::V4(_) => Domain::IPV4,
        IpAddr::V6(_) => Domain::IPV6,
    };

    let socket = Socket::new(domain, Type::DGRAM, Some(Protocol::UDP))
        .context("failed to create UDP socket")?;
    socket
        .set_nonblocking(true)
        .context("failed to set nonblocking on LAN UDP socket")?;
    let _ = socket.set_recv_buffer_size(2 * 1024 * 1024);
    let _ = socket.set_send_buffer_size(2 * 1024 * 1024);

    pin_socket_to_interface(&socket, iface)?;

    let bind_addr = SocketAddr::new(iface.local_ip, port);
    socket
        .bind(&bind_addr.into())
        .with_context(|| format!("failed to bind LAN socket to {bind_addr}"))?;

    Ok(socket.into())
}

#[cfg(windows)]
fn pin_socket_to_interface(socket: &Socket, iface: &PhysicalLanInterface) -> Result<()> {
    use std::os::windows::io::AsRawSocket;
    use windows_sys::Win32::Networking::WinSock::{
        IP_UNICAST_IF, IPPROTO_IP, IPPROTO_IPV6, IPV6_UNICAST_IF, SOCKET, SOCKET_ERROR,
        WSAGetLastError, setsockopt,
    };

    let raw = socket.as_raw_socket() as SOCKET;

    match iface.local_ip {
        IpAddr::V4(_) => {
            let if_index_be: u32 = iface.os_index.to_be();
            let rc = unsafe {
                setsockopt(
                    raw,
                    IPPROTO_IP as i32,
                    IP_UNICAST_IF as i32,
                    &if_index_be as *const u32 as *const u8,
                    std::mem::size_of::<u32>() as i32,
                )
            };
            if rc == SOCKET_ERROR {
                let err = unsafe { WSAGetLastError() };
                anyhow::bail!(
                    "setsockopt(IP_UNICAST_IF={}) failed with WSA error {}",
                    iface.os_index,
                    err
                );
            }
        }
        IpAddr::V6(_) => {
            let if_index_host: u32 = iface.os_index;
            let rc = unsafe {
                setsockopt(
                    raw,
                    IPPROTO_IPV6 as i32,
                    IPV6_UNICAST_IF as i32,
                    &if_index_host as *const u32 as *const u8,
                    std::mem::size_of::<u32>() as i32,
                )
            };
            if rc == SOCKET_ERROR {
                let err = unsafe { WSAGetLastError() };
                anyhow::bail!(
                    "setsockopt(IPV6_UNICAST_IF={}) failed with WSA error {}",
                    iface.os_index,
                    err
                );
            }
        }
    }

    Ok(())
}

#[cfg(target_os = "android")]
fn pin_socket_to_interface(socket: &Socket, iface: &PhysicalLanInterface) -> Result<()> {
    use std::os::unix::io::AsRawFd;

    #[link(name = "android")]
    unsafe extern "C" {
        fn android_setsocknetwork(network: i64, fd: i32) -> i32;
    }

    // USB tether interfaces (`rndis0`/`usb0`/`ncm0`) carry `network_handle = Some(0)` or `None`
    // and route over direct local subnet without needing `android_setsocknetwork`.
    if let Some(handle) = iface.android_network_handle
        && handle > 0
    {
        let fd = socket.as_raw_fd();
        let rc = unsafe { android_setsocknetwork(handle, fd) };
        if rc != 0 {
            let err = std::io::Error::last_os_error();
            anyhow::bail!("android_setsocknetwork(handle={handle}, fd={fd}) failed: {err}");
        }
    }
    Ok(())
}

#[cfg(not(any(windows, target_os = "android")))]
fn pin_socket_to_interface(_socket: &Socket, _iface: &PhysicalLanInterface) -> Result<()> {
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filters_virtual_adapters() {
        assert!(is_virtual_adapter_name("Mihomo"));
        assert!(is_virtual_adapter_name("Clash Tunnel Wintun"));
        assert!(is_virtual_adapter_name("sing-tun"));
        assert!(is_virtual_adapter_name("vEthernet (Default Switch)"));
        assert!(!is_virtual_adapter_name("WLAN (Intel(R) Wi-Fi 6E AX211)"));
        assert!(!is_virtual_adapter_name(
            "以太网 (Realtek PCIe 2.5GbE Family Controller)"
        ));
    }

    #[test]
    fn detects_usb_tether_adapters() {
        assert!(is_usb_tether_adapter(
            "以太网 2 (Remote NDIS based Internet Sharing Device)",
            &"192.168.42.100".parse().unwrap()
        ));
        assert!(is_usb_tether_adapter(
            "rndis0",
            &"192.168.42.129".parse().unwrap()
        ));
        assert!(!is_usb_tether_adapter(
            "WLAN (Intel Wi-Fi 6E)",
            &"192.168.1.50".parse().unwrap()
        ));
    }

    #[test]
    fn filters_unusable_ips() {
        assert!(!is_usable_lan_ip(&"127.0.0.1".parse().unwrap()));
        assert!(!is_usable_lan_ip(&"169.254.12.34".parse().unwrap()));
        assert!(!is_usable_lan_ip(&"fe80::1".parse().unwrap()));
        assert!(is_usable_lan_ip(&"192.168.1.42".parse().unwrap()));
    }
}
