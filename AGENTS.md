# P2Pfiledrop (文件随手传) — Project Memory & Engineering Guide

> Engineering architecture and contributor guidelines for this workspace. Keep it concise, accurate, and free of personal/machine-specific secrets or identifiers.

---

## 1. Project Overview & Architecture

Decentralized, end-to-end encrypted (E2EE), multi-room P2P chat and file transfer application (`Windows <-> Android`), featuring an optional **24/7 zero-knowledge Home Node ("家庭常驻盲盒快递柜")** mode that turns an idle Android phone into an offline encrypted relay locker.

### Directory Structure (Repository Root)
- `core-rust/` — Shared Rust core engine compiled to `p2p_chat_core.dll` (Windows x64) and `libp2p_chat_core.so` (Android `arm64-v8a` / `x86_64`), exposed to Flutter via `flutter_rust_bridge`:
  - `src/engine.rs`: Top-level orchestrator (`ChatTransferEngine`), dual WAN/LAN connection management (`ActiveConnection::UsbLan`, `Lan`, `WanDirectNoq`, `Wan`), USB discovery, priority outbox drain with exponential backoff, and blind locker purge loops.
  - `src/net/lan_bypass.rs`: Physical-NIC discovery, TUN/VPN exclusion (`mihomo`, `clash`, `sing-tun`, `wintun`, `wireguard`, etc.), Windows socket pinning (`IP_UNICAST_IF` / `IPV6_UNICAST_IF`), Android socket pinning (`android_setsocknetwork`), USB RNDIS detection, and Windows `InterfaceMetric=5000` USB anti-route-hijack (`ensure_usb_tether_metric_safe`).
  - `src/net/lan_quic.rs` & `src/net/wan_iroh.rs`: `noq` direct QUIC over physical/USB/IPv6 links (2 MiB stream window, 1350 PMTUD upper bound, LAN vs cellular/WAN IPv6 classifier) + `iroh` WAN/Relay fallback (supporting custom relay URLs).
  - `src/net/usb_bootstrap.rs`: Built-in USB HTTP bootstrap server on port `42420` (`USB_BOOTSTRAP_HTTP_PORT = 42420`) for bare-metal client download and one-click USB auto-pairing (`/api/bootstrap-ticket`).
  - `src/crypto/room_cipher.rs` & `identity.rs`: Room-scoped Encrypt-then-MAC using BLAKE3 keyed XOF + MAC (`RoomKey`) and device cryptographic identities; pure Home Nodes store ciphertext envelopes/chunks without holding room keys.
  - `src/db/store.rs` & `src/transfer/`: SQLite local store, chunked resume (`chunker.rs`, filename sanitization & `validate_safe_id`), and sync/ACK/locker GC protocol (`sync_engine.rs`).
- `app-flutter/` — Unified Flutter codebase (single APK / EXE supports both **Chat Client** and **24h Home Node Server** role switching):
  - `lib/controllers/app_workspace_controller.dart`: State orchestrator (rooms, live transfer MB/s & ETA calculation, Windows tray shell sync & desktop notifications, device model/profile & avatar resolution, event-driven low-power Home Node handling).
  - `lib/services/platform_bridge.dart` & `thumbnail_cache_service.dart`: MethodChannel (`dev.p2pchat/platform`) for Windows tray/auto-start/Explorer reveal, Android physical-NIC handles, Share Sheet intents, All-Files access, battery whitelist, hardware device model detection, and O(1) thumbnail cache.
  - `lib/l10n/`: 11-language localizations (`zh`, `en`, `zh_TW`, `ja`, `ko`, `es`, `fr`, `de`, `pt`, `ru`, `ar`).
  - `lib/ui/`: Telegram/WhatsApp-styled workspace UI (`chat_page.dart`, `contacts_pane.dart`, `chat_list_pane.dart` with `CustomScrollView` landscape scrolling, `me_tab_view.dart`, `room_invite_sheet.dart`, `home_node_sheet.dart`, `oled_stealth_overlay.dart`).
  - `windows/runner/`: Win32 single-instance mutex (`Local\P2PChatTransferSingleInstanceMutex`), system tray icon/menu/balloon notifications, registry auto-start (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run\P2PChatTransfer --minimized`), `explorer.exe /select`.
  - `android/app/src/main/kotlin/dev/p2pchat/p2p_chat_app/`: `MainActivity.kt` (`getDeviceModelName`, `ConnectivityManager.NetworkCallback`, background `ACTION_SEND` share receiver, All-Files & battery whitelist intents) and `HomeNodeForegroundService.kt`.
- `build.ps1` — Master Windows + Android build & packaging script.
- `dist/` — Built release bundles (git-ignored).

---

## 2. Release Status (`v1.0.0+1`)

- **Core Transport & Multi-Room E2EE**: Dual-stack `iroh` + `noq`, physical-NIC pinning bypassing VPN/TUN virtual adapters, USB RNDIS (`192.168.42.0/24`) + Windows `InterfaceMetric=5000` protection, 24h zero-knowledge Home Node blind locker with auto-purge.
- **v1.0.0 Hardening & Packaging**:
  - Permanent Android 4096-bit RSA release keystore support (`app-flutter/android/key.properties.example`), `--split-per-abi` (`arm64-v8a` / `x86_64`), `[profile.release]` LTO + symbol stripping.
  - Filename sanitization, path-traversal `validate_safe_id`, 5 MiB `engine.log` rotation, `Tokio` runtime guard in `revoke_message_for_everyone`.
  - Verified on real Windows + Android hardware across 1 GB+ chunked disconnect/resume, 120 MB external Share Sheet intake, 5G cross-carrier direct IPv6 + lockscreen auto-drain, and landscape `CustomScrollView` responsiveness.

---

## 3. Common Build & Test Commands

Run from the repository root:
- **Windows release rebuild (when only Flutter/C++ changed)**:
  `.\build.ps1 -SkipAndroidRust -SkipWindowsRust -BuildWindows`
- **Android APK release rebuild (when only Flutter/Kotlin changed)**:
  `.\build.ps1 -SkipAndroidRust -SkipWindowsRust -BuildApk`
- **Full Rust + Windows + Android build (when `core-rust/` changed)**:
  `.\build.ps1 -BuildWindows -BuildApk`
- **Install / deploy APK to a connected Android device**:
  ```powershell
  adb -s <device-serial> install -r .\dist\p2p-chat-android-arm64-v8a-release.apk
  ```
- **Static analysis & Flutter unit tests**:
  ```powershell
  Set-Location .\app-flutter
  flutter analyze
  flutter test --reporter expanded
  ```
- **Rust core checks/tests**:
  ```powershell
  Set-Location .\core-rust
  cargo test
  ```

---

## 4. Critical Engineering Constraints & Gotchas

1. **Windows MSVC CP936 Encoding (`warning C4819` / `error C2220`)**:
   - Simplified Chinese Windows compiles UTF-8 `.cpp` files without BOM as GBK (CP936), failing the build if literal non-ASCII characters appear in `app-flutter\windows\runner\*.cpp` or `*.h`.
   - **Rule**: Keep all C++ runner sources strictly 7-bit ASCII; encode non-ASCII UI strings using `\uXXXX` escapes in `L"..."` UTF-16 literals.
2. **Windows Single-Instance Mutex & Agent Sandbox Isolation (`WinSta0\exebox-...`)**:
   - Processes started from agent shell commands run in an invisible desktop while sharing `Local\P2PChatTransferSingleInstanceMutex`.
   - **Rule**: Never leave `p2p_chat_app.exe` running from an agent command after testing; always confirm `Get-Process p2p_chat_app` count is `0` before handing back to the user.
3. **Avoid Unnecessary `flutter_rust_bridge` Regenerate Unless Signatures Change**:
   - Existing FFI bindings live in `app-flutter/lib/src/rust/` and `core-rust/src/frb_generated.rs`.
4. **Preserve Prebuilt Native Libraries During Local Builds**:
   - Windows `Release` build copies `core-rust\target\release\p2p_chat_core.dll` and syncs to `Debug\` (stopping any running `p2p_chat_app.exe` first so `icudtl.dat` is not locked). Android APK release packages `app-flutter\android\app\src\main\jniLibs\{arm64-v8a,x86_64}\libp2p_chat_core.so` (git-ignored).
