<p align="center">
  <img src="docs/bubbledrop_icon.png" width="112" alt="BubbleDrop Icon" />
</p>

# BubbleDrop（文件随手传） · Android ↔ Windows

像聊天一样随手互传文件——去中心化、端到端加密（E2EE）、仿 Telegram / WhatsApp 风格的多房间私人传输与零知识家庭盲盒快递柜工具。

Share files as effortlessly as chatting — decentralized, end-to-end encrypted (`BLAKE3` + `Ed25519`) P2P chat and resumable file transfer between Android and Windows, with an optional 24/7 zero-knowledge Home Node relay mode.

---

## 核心特性 / Highlights

- **多通道自动无缝切换**：优先走 **USB 共享专线（`192.168.42.0/24`）** 与 **物理局域网（Wi-Fi / 网线，绕过代理 TUN 虚拟网卡）** `noq` QUIC 直传；跨网或纯 5G 环境下支持公网 IPv6 直连与 `iroh` P2P 打洞 / 加密中继接力（支持自定义 Relay URL）。
- **USB 防抢网保护**：Windows 端自动检测并在诊断面板中支持一键修复 USB 共享网卡跃点数（`Metric = 5000`），避免插上旧手机充当 USB 专线时电脑宽带上网被劫持。
- **同款 App 双身份（客户端 ⇄ 24h 盲盒快递柜）**：同一份客户端可一键切换为 **「24h 常驻盲盒快递柜节点」**（适合部署在闲置安卓旧手机上），零密钥零明文暂存密文分片，全员签收后自动销毁，并内置 `42420` 端口 USB HTTP 引导页分发安装包。
- **Telegram / WhatsApp 风格交互与桌面常驻**：
  - 支持 11 国语言界面、多房间密钥隔离、扫码入群、拖拽文件、`Ctrl+V` 粘贴截图/文件、大图缩放预览、实时速率（`MB/s`）与 ETA、Windows「在文件夹中显示」。
  - Windows 原生系统托盘常驻（点 `×` 最小化到托盘、开机 `--minimized` 自启、气泡通知、单实例唤醒）。
  - Android 支持系统“分享到本应用”、自定义保存目录 / MediaStore、1GB+ 断点续传与横竖屏自适应布局。

---

## 目录结构 / Structure

```text
.
├── core-rust/          # Rust 核心引擎（iroh + noq + 物理网卡绑定 + BLAKE3 E2EE + SQLite + :42420 USB 引导）
├── app-flutter/        # Flutter 跨平台客户端（Android + Windows 原生壳与托盘，支持 11 种语言）
├── build.ps1           # Windows & Android 一键构建与分架构打包脚本
├── AGENTS.md           # 工程架构说明与开发/测试规范
├── LICENSE             # MIT License
└── README.md
```

---

## 构建与打包 / Build from Source

前置依赖 / Prerequisites:
- Rust (`stable` + `aarch64-linux-android` / `x86_64-linux-android` targets for Android builds)
- Flutter SDK (`>= 3.x`)
- Windows: Visual Studio C++ Desktop workload
- Android: JDK 17 + Android SDK & NDK (`ANDROID_HOME` / `JAVA_HOME` configured)

Android 正式签名配置（可选，未配置时回退 debug 签名）/ Release signing:
- 复制 `app-flutter/android/key.properties.example` 为 `app-flutter/android/key.properties` 并填入你自己的 Keystore 路径与密码（已被 `.gitignore` 排除）。

```powershell
# 全量编译 Rust 核心引擎与 Windows + Android 分架构正式包
.\build.ps1 -BuildWindows -BuildApk

# 仅重新编译打包 Windows 桌面端（Rust 未改动时）
.\build.ps1 -SkipAndroidRust -SkipWindowsRust -BuildWindows

# 仅重新编译打包 Android APK（Rust 未改动时）
.\build.ps1 -SkipAndroidRust -SkipWindowsRust -BuildApk

# 国内网络环境可追加 -UseChinaMirrors 使用 Flutter 国内镜像
.\build.ps1 -BuildWindows -BuildApk -UseChinaMirrors
```

打包产物输出在 `dist/` 目录：
- `dist/p2p-chat-windows-x64.zip`
- `dist/p2p-chat-android-arm64-v8a-release.apk`
- `dist/p2p-chat-android-x86_64-release.apk`
