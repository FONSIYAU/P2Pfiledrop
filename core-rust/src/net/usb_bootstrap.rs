//! Built-in lightweight HTTP bootstrap server (`:42420`) and USB neighbor prober
//! for cold-start Windows client distribution and one-click USB auto-pairing.

use serde::{Deserialize, Serialize};
use std::future::Future;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::PathBuf;
use std::pin::Pin;
use std::sync::{Arc, RwLock};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};

pub const USB_BOOTSTRAP_HTTP_PORT: u16 = 42420;

/// Async handler for loopback-only provisioning & diagnostic control calls (`/api/local/*`).
pub type LocalControlHandler = Arc<
    dyn Fn(String, String, Vec<u8>) -> Pin<Box<dyn Future<Output = (u16, Vec<u8>)> + Send>>
        + Send
        + Sync,
>;

/// JSON payload returned at `GET /api/bootstrap-ticket`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UsbBootstrapPayload {
    pub node_id: String,
    pub device_name: String,
    pub home_node_mode: bool,
    pub pairing_ticket_json: String,
    pub room_invite_json: Option<String>,
    pub installer_filename: Option<String>,
    pub installer_size_bytes: Option<u64>,
    pub lan_addrs: Vec<String>,
    pub usb_addrs: Vec<String>,
}

/// Starts the built-in USB HTTP bootstrap server on `0.0.0.0:42420`.
/// Gracefully skips if the port is already bound by another process/instance.
pub fn start_usb_bootstrap_server<F>(
    provider: Arc<F>,
    installer_path: Arc<RwLock<Option<PathBuf>>>,
    local_ctrl: Option<LocalControlHandler>,
) where
    F: Fn() -> UsbBootstrapPayload + Send + Sync + 'static,
{
    tokio::spawn(async move {
        let addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), USB_BOOTSTRAP_HTTP_PORT);
        let listener = match TcpListener::bind(addr).await {
            Ok(l) => {
                tracing::info!("USB bootstrap HTTP server listening on http://0.0.0.0:{USB_BOOTSTRAP_HTTP_PORT}");
                l
            }
            Err(e) => {
                tracing::warn!("USB bootstrap HTTP server bind on {addr} skipped: {e}");
                return;
            }
        };

        loop {
            let Ok((stream, peer_addr)) = listener.accept().await else {
                continue;
            };
            let prov = Arc::clone(&provider);
            let inst = Arc::clone(&installer_path);
            let ctrl = local_ctrl.clone();
            tokio::spawn(async move {
                let _ = handle_http_connection(stream, peer_addr, prov, inst, ctrl).await;
            });
        }
    });
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BootstrapLang {
    ZhCn,
    ZhTw,
    En,
    Ja,
    Ko,
    Es,
    Pt,
    Fr,
    De,
    Ru,
    Uk,
}

impl BootstrapLang {
    fn from_tag(raw: &str) -> Option<Self> {
        let lower = raw.trim().to_ascii_lowercase().replace('_', "-");
        if lower.is_empty() {
            return None;
        }
        if lower.starts_with("zh") {
            if lower.contains("hant")
                || lower.contains("-tw")
                || lower.contains("-hk")
                || lower.contains("-mo")
            {
                return Some(Self::ZhTw);
            }
            return Some(Self::ZhCn);
        }
        if lower == "ja" || lower.starts_with("ja-") {
            return Some(Self::Ja);
        }
        if lower == "ko" || lower.starts_with("ko-") {
            return Some(Self::Ko);
        }
        if lower == "es" || lower.starts_with("es-") {
            return Some(Self::Es);
        }
        if lower == "pt" || lower.starts_with("pt-") {
            return Some(Self::Pt);
        }
        if lower == "fr" || lower.starts_with("fr-") {
            return Some(Self::Fr);
        }
        if lower == "de" || lower.starts_with("de-") {
            return Some(Self::De);
        }
        if lower == "ru" || lower.starts_with("ru-") {
            return Some(Self::Ru);
        }
        if lower == "uk" || lower.starts_with("uk-") {
            return Some(Self::Uk);
        }
        if lower == "en" || lower.starts_with("en-") {
            return Some(Self::En);
        }
        None
    }

    pub fn resolve(query: Option<&str>, accept_language: Option<&str>) -> Self {
        if let Some(q) = query {
            for pair in q.split('&') {
                if let Some((k, v)) = pair.split_once('=')
                    && k.eq_ignore_ascii_case("lang")
                    && let Some(lang) = Self::from_tag(v)
                {
                    return lang;
                }
            }
        }
        if let Some(header) = accept_language {
            for item in header.split(',') {
                let tag = item.split(';').next().unwrap_or("").trim();
                if let Some(lang) = Self::from_tag(tag) {
                    return lang;
                }
            }
        }
        Self::En
    }

    fn html_lang(self) -> &'static str {
        match self {
            Self::ZhCn => "zh-CN",
            Self::ZhTw => "zh-TW",
            Self::En => "en",
            Self::Ja => "ja",
            Self::Ko => "ko",
            Self::Es => "es",
            Self::Pt => "pt",
            Self::Fr => "fr",
            Self::De => "de",
            Self::Ru => "ru",
            Self::Uk => "uk",
        }
    }
}

struct ParsedHttpRequest {
    method: String,
    path: String,
    query: Option<String>,
    accept_language: Option<String>,
    body: Vec<u8>,
}

async fn read_http_request(stream: &mut TcpStream) -> std::io::Result<Option<ParsedHttpRequest>> {
    let mut raw = Vec::with_capacity(2048);
    let mut tmp = [0u8; 4096];
    let mut header_end = None;

    while header_end.is_none() {
        let n = tokio::time::timeout(std::time::Duration::from_secs(3), stream.read(&mut tmp))
            .await
            .ok()
            .and_then(|r| r.ok())
            .unwrap_or(0);
        if n == 0 {
            break;
        }
        raw.extend_from_slice(&tmp[..n]);
        if let Some(pos) = raw.windows(4).position(|w| w == b"\r\n\r\n") {
            header_end = Some(pos + 4);
            break;
        }
        if raw.len() > 64 * 1024 {
            return Ok(None);
        }
    }

    let Some(hdr_end) = header_end else {
        return Ok(None);
    };

    let header_text = String::from_utf8_lossy(&raw[..hdr_end]).to_string();
    let mut lines = header_text.lines();
    let request_line = lines.next().unwrap_or("");
    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or("GET").to_uppercase();
    let raw_target = parts.next().unwrap_or("/");
    let (path_raw, query_raw) = match raw_target.split_once('?') {
        Some((p, q)) => (p, Some(q.to_string())),
        None => (raw_target, None),
    };
    let path = path_raw.to_string();

    let mut content_len = 0usize;
    let mut accept_language = None;
    for line in lines {
        if let Some((k, v)) = line.split_once(':') {
            if k.trim().eq_ignore_ascii_case("content-length") {
                content_len = v.trim().parse::<usize>().unwrap_or(0).min(256 * 1024);
            } else if k.trim().eq_ignore_ascii_case("accept-language") {
                accept_language = Some(v.trim().to_string());
            }
        }
    }

    let mut body = raw[hdr_end..].to_vec();
    while body.len() < content_len {
        let n = tokio::time::timeout(std::time::Duration::from_secs(3), stream.read(&mut tmp))
            .await
            .ok()
            .and_then(|r| r.ok())
            .unwrap_or(0);
        if n == 0 {
            break;
        }
        body.extend_from_slice(&tmp[..n]);
    }
    body.truncate(content_len);
    Ok(Some(ParsedHttpRequest {
        method,
        path,
        query: query_raw,
        accept_language,
        body,
    }))
}

async fn handle_http_connection<F>(
    mut stream: TcpStream,
    peer_addr: SocketAddr,
    provider: Arc<F>,
    installer_path: Arc<RwLock<Option<PathBuf>>>,
    local_ctrl: Option<LocalControlHandler>,
) -> std::io::Result<()>
where
    F: Fn() -> UsbBootstrapPayload + Send + Sync + 'static,
{
    let Some(req) = read_http_request(&mut stream).await? else {
        return Ok(());
    };
    let method = req.method;
    let path = req.path;
    let req_body = req.body;
    let lang = BootstrapLang::resolve(req.query.as_deref(), req.accept_language.as_deref());

    if path.starts_with("/api/local/") {
        if !peer_addr.ip().is_loopback() {
            let body = br#"{"error":"forbidden_loopback_only"}"#;
            let header = format!(
                "HTTP/1.1 403 Forbidden\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                body.len()
            );
            stream.write_all(header.as_bytes()).await?;
            stream.write_all(body).await?;
            stream.flush().await?;
            return Ok(());
        }

        let (status, resp_body) = if let Some(handler) = local_ctrl {
            handler(method, path, req_body).await
        } else {
            (404, br#"{"error":"local_ctrl_disabled"}"#.to_vec())
        };
        let reason = match status {
            200 => "OK",
            400 => "Bad Request",
            403 => "Forbidden",
            404 => "Not Found",
            _ => "Internal Server Error",
        };
        let header = format!(
            "HTTP/1.1 {status} {reason}\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
            resp_body.len()
        );
        stream.write_all(header.as_bytes()).await?;
        stream.write_all(&resp_body).await?;
        stream.flush().await?;
        return Ok(());
    }

    match path.as_str() {
        "/api/bootstrap-ticket" => {
            let payload = provider();
            let body = serde_json::to_vec(&payload).unwrap_or_else(|_| b"{}".to_vec());
            let header = format!(
                "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                body.len()
            );
            stream.write_all(header.as_bytes()).await?;
            stream.write_all(&body).await?;
        }
        "/download" => {
            let path_opt = installer_path
                .read()
                .expect("installer_path lock poisoned")
                .clone();
            if let Some(file_path) = path_opt
                && let Ok(mut file) = tokio::fs::File::open(&file_path).await
                && let Ok(meta) = file.metadata().await
            {
                let filename = file_path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("p2p-chat-windows.zip");
                let header = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=\"{filename}\"\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                    meta.len()
                );
                stream.write_all(header.as_bytes()).await?;
                let mut chunk = vec![0u8; 64 * 1024];
                loop {
                    let read_n = file.read(&mut chunk).await?;
                    if read_n == 0 {
                        break;
                    }
                    stream.write_all(&chunk[..read_n]).await?;
                }
            } else {
                let body = b"No Windows client installer package is currently mounted on this Home Node.";
                let header = format!(
                    "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                    body.len()
                );
                stream.write_all(header.as_bytes()).await?;
                stream.write_all(body).await?;
            }
        }
        _ => {
            let payload = provider();
            let html = render_bootstrap_html(&payload, lang);
            let body = html.as_bytes();
            let header = format!(
                "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                body.len()
            );
            stream.write_all(header.as_bytes()).await?;
            stream.write_all(body).await?;
        }
    }

    stream.flush().await?;
    Ok(())
}

fn escape_html(raw: &str) -> String {
    raw.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

pub fn render_bootstrap_html(payload: &UsbBootstrapPayload, lang: BootstrapLang) -> String {
    let (
        page_title,
        heading,
        node_id_label,
        badge_home,
        badge_peer,
        step1_dl_title,
        step1_dl_desc,
        step1_dl_btn,
        step1_empty_title,
        step1_empty_desc,
        step2_title,
        step2_desc,
    ) = match lang {
        BootstrapLang::ZhCn => (
            "P2P 家庭快递柜 · USB 专线引导页",
            "P2P 私人快传 · USB 数据线引导站",
            "节点 ID：",
            "📦 家庭常驻盲盒节点运行中 (24h Online)",
            "📱 P2P 私人快传节点在线",
            "1. 裸机冷启动：高速下载电脑端程序",
            "通过 USB 数据线直连高速下载，不消耗流量。",
            "⬇ 下载",
            "1. 电脑端安装引导",
            "暂未在旧手机中挂载电脑端安装包（可在旧手机「常驻节点设置」中选择 Windows 安装包）。若电脑已安装客户端，启动后会自动发现本节点！",
            "2. 自动认亲与手动配对凭证",
            "Windows 端启动后会自动探测本机 42420 端口并弹出“一键绑定”横幅；如需手动绑定，可复制下方凭证：",
        ),
        BootstrapLang::ZhTw => (
            "P2P 家庭快遞櫃 · USB 專線引導頁",
            "P2P 私人快傳 · USB 傳輸線引導站",
            "節點 ID：",
            "📦 家庭常駐盲盒節點運行中 (24h Online)",
            "📱 P2P 私人快傳節點在線",
            "1. 裸機冷啟動：高速下載電腦端程式",
            "透過 USB 傳輸線直連高速下載，不消耗行動流量。",
            "⬇ 下載",
            "1. 電腦端安裝引導",
            "暫未在舊手機中掛載電腦端安裝包（可在舊手機「常駐節點設定」中選擇 Windows 安裝包）。若電腦已安裝用戶端，啟動後會自動發現本節點！",
            "2. 自動配對與手動綁定憑證",
            "Windows 端啟動後會自動探測本機 42420 連接埠並彈出「一鍵綁定」橫幅；如需手動綁定，可複製下方憑證：",
        ),
        BootstrapLang::En => (
            "P2P Home Locker · USB Bootstrap",
            "P2P Private Transfer · USB Bootstrap Station",
            "Node ID: ",
            "📦 Home Blind-Locker Node Active (24h Online)",
            "📱 P2P Private Transfer Node Online",
            "1. Cold-Start Setup: High-Speed Desktop Download",
            "Download directly over USB cable with zero cellular data usage.",
            "⬇ Download",
            "1. Desktop Client Setup",
            "No Windows installer package is mounted on this device yet (mount one under Home Node Settings). If the desktop app is already installed, it will auto-discover this node on launch.",
            "2. Auto-Discovery & Manual Pairing Ticket",
            "The Windows client automatically probes port 42420 on launch for one-click pairing. To pair manually, copy the ticket below:",
        ),
        BootstrapLang::Ja => (
            "P2P ホームロッカー · USB ブートストラップ",
            "P2P プライベート転送 · USB ケーブル案内ステーション",
            "ノード ID：",
            "📦 ホーム常駐ブラインドロッカー稼働中 (24h Online)",
            "📱 P2P プライベート転送ノード オンライン",
            "1. 初期セットアップ：PC 版クライアント高速ダウンロード",
            "USB ケーブル経由で直接高速ダウンロードできるため、モバイル通信量は消費しません。",
            "⬇ ダウンロード",
            "1. PC 版クライアント案内",
            "この端末には Windows インストーラーがまだマウントされていません（「ホームノード設定」で指定できます）。PC 版が既にインストール済みの場合は起動時にこのノードを自動検出します！",
            "2. 自動検出と手動ペアリングチケット",
            "Windows 版は起動時にポート 42420 を自動検出し、ワンクリック連携バナーを表示します。手動で連携する場合は下のチケットをコピーしてください：",
        ),
        BootstrapLang::Ko => (
            "P2P 홈 로커 · USB 부트스트랩",
            "P2P 프라이빗 전송 · USB 케이블 연결 안내 스테이션",
            "노드 ID: ",
            "📦 상시 홈 블라인드 로커 가동 중 (24h Online)",
            "📱 P2P 프라이빗 전송 노드 온라인",
            "1. 초기 설치: 데스크톱 앱 고속 다운로드",
            "USB 케이블 직통 연결로 고속 다운로드하므로 모바일 데이터를 소모하지 않습니다.",
            "⬇ 다운로드",
            "1. 데스크톱 클라이언트 안내",
            "아직 이 기기에 Windows 설치 패키지가 마운트되지 않았습니다(「홈 노드 설정」에서 선택 가능). PC 앱이 이미 설치되어 있다면 실행 시 이 노드를 자동으로 찾습니다!",
            "2. 자동 탐색 및 수동 페어링 티켓",
            "Windows 클라이언트는 실행 시 42420 포트를 자동 탐지하여 원클릭 연동 배너를 띄웁니다. 수동으로 연결하려면 아래 티켓을 복사하세요:",
        ),
        BootstrapLang::Es => (
            "Buzón P2P · Arranque USB",
            "Transferencia Privada P2P · Estación USB",
            "ID del nodo: ",
            "📦 Nodo doméstico 24h activo (Buzón cifrado)",
            "📱 Nodo P2P en línea",
            "1. Instalación inicial: Descarga rápida por USB",
            "Descarga directa por cable USB a máxima velocidad sin gastar datos móviles.",
            "⬇ Descargar",
            "1. Cliente de escritorio",
            "Aún no hay ningún instalador de Windows montado (puedes elegir uno en Ajustes del Nodo). Si el cliente ya está instalado, detectará este nodo automáticamente al abrirlo.",
            "2. Detección automática y ticket manual",
            "El cliente Windows detecta el puerto 42420 automáticamente al iniciar. Para vincular manualmente, copia este ticket:",
        ),
        BootstrapLang::Pt => (
            "Armário P2P · Inicialização USB",
            "Transferência Privada P2P · Estação USB",
            "ID do nó: ",
            "📦 Nó doméstico 24h ativo (Cifrado)",
            "📱 Nó P2P online",
            "1. Instalação inicial: Download rápido via USB",
            "Baixe diretamente pelo cabo USB em alta velocidade sem usar dados móveis.",
            "⬇ Baixar",
            "1. Cliente para computador",
            "Nenhum instalador Windows está montado neste dispositivo (configure em Ajustes do Nó). Se o app já estiver instalado, ele encontrará este nó automaticamente.",
            "2. Detecção automática e ticket manual",
            "O cliente Windows sonda a porta 42420 ao abrir para pareamento em um clique. Para parear manualmente, copie o ticket:",
        ),
        BootstrapLang::Fr => (
            "Casier P2P · Amorçage USB",
            "Transfert Privé P2P · Station USB",
            "ID du nœud : ",
            "📦 Nœud domestique 24h actif (Chiffré)",
            "📱 Nœud P2P en ligne",
            "1. Installation initiale : Téléchargement rapide USB",
            "Téléchargez directement via le câble USB sans consommer de données mobiles.",
            "⬇ Télécharger",
            "1. Client ordinateur",
            "Aucun programme d'installation Windows n'est monté (sélectionnez-en un dans les réglages du nœud). Si l'app est déjà installée, elle détectera ce nœud automatiquement.",
            "2. Découverte auto & ticket manuel",
            "Le client Windows détecte le port 42420 au lancement. Pour associer manuellement, copiez le ticket ci-dessous :",
        ),
        BootstrapLang::De => (
            "P2P-Heimknoten · USB-Bootstrap",
            "P2P-Privattransfer · USB-Startstation",
            "Knoten-ID: ",
            "📦 24h-Heimknoten aktiv (Verschlüsselter Speicher)",
            "📱 P2P-Knoten online",
            "1. Ersteinrichtung: Schneller USB-Download",
            "Direkter Highspeed-Download per USB-Kabel ohne Mobilfunkverbrauch.",
            "⬇ Herunterladen",
            "1. Desktop-Client einrichten",
            "Auf diesem Gerät ist noch kein Windows-Setup hinterlegt (in den Heimknoten-Einstellungen wählbar). Ein installierter Client erkennt diesen Knoten automatisch.",
            "2. Auto-Erkennung & manuelles Ticket",
            "Der Windows-Client prüft beim Start automatisch Port 42420. Für die manuelle Kopplung kopiere dieses Ticket:",
        ),
        BootstrapLang::Ru => (
            "P2P Домашний узел · USB-запуск",
            "P2P Приватный обмен · USB-станция",
            "ID узла: ",
            "📦 Домашний узел 24/7 активен (Шифрованный сейф)",
            "📱 P2P-узел в сети",
            "1. Быстрый старт: загрузка ПК-клиента по USB",
            "Скачайте напрямую по USB-кабелю на высокой скорости без расхода трафика.",
            "⬇ Скачать",
            "1. Клиент для Windows",
            "Установщик Windows пока не прикреплён (выберите его в настройках домашнего узла). Если клиент уже установлен, он найдёт этот узел автоматически!",
            "2. Автопоиск и тикет для ручной пары",
            "Windows-клиент сам опрашивает порт 42420 при запуске. Для ручного подключения скопируйте тикет ниже:",
        ),
        BootstrapLang::Uk => (
            "P2P Домашній вузол · USB-старт",
            "P2P Приватний обмін · USB-станція",
            "ID вузла: ",
            "📦 Домашній вузол 24/7 активний (Шифрований сейф)",
            "📱 P2P-вузол у мережі",
            "1. Швидкий старт: завантаження ПК-клієнта через USB",
            "Завантажуйте напряму USB-кабелем без витрати мобільного трафіку.",
            "⬇ Завантажити",
            "1. Клієнт для Windows",
            "Інсталятор Windows іще не прикріплено (оберіть його в налаштуваннях домашнього вузла). Якщо клієнт уже встановлено, він знайде цей вузол автоматично!",
            "2. Автопошук і тікет для ручного зв'язування",
            "Windows-клієнт сам перевіряє порт 42420 під час запуску. Для ручного підключення скопіюйте тікет нижче:",
        ),
    };

    let installer_block = match (&payload.installer_filename, payload.installer_size_bytes) {
        (Some(name), Some(bytes)) => {
            let mb = (bytes as f64) / (1024.0 * 1024.0);
            let name_escaped = escape_html(name);
            format!(
                r#"<div class="card">
                    <h2>{step1_dl_title}</h2>
                    <p>{step1_dl_desc}</p>
                    <a class="btn" href="/download">{step1_dl_btn} {name_escaped} ({mb:.1} MB)</a>
                </div>"#
            )
        }
        _ => format!(
            r#"<div class="card">
                <h2>{step1_empty_title}</h2>
                <p>{step1_empty_desc}</p>
            </div>"#
        ),
    };

    let status_badge = if payload.home_node_mode {
        badge_home
    } else {
        badge_peer
    };

    let node_id_escaped = escape_html(&payload.node_id);
    let ticket_escaped = escape_html(&payload.pairing_ticket_json);
    let html_lang = lang.html_lang();

    format!(
        r#"<!DOCTYPE html>
<html lang="{html_lang}">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{page_title}</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0f172a; color: #e2e8f0; margin: 0; padding: 24px; }}
    .wrap {{ max-width: 680px; margin: 0 auto; }}
    .topbar {{ display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; }}
    .lang-nav {{ display: flex; gap: 6px; font-size: 12px; flex-wrap: wrap; }}
    .lang-nav a {{ color: #94a3b8; text-decoration: none; padding: 4px 8px; border-radius: 6px; border: 1px solid #334155; }}
    .lang-nav a.active {{ color: #fff; background: #0d9488; border-color: #0d9488; }}
    .badge {{ display: inline-block; padding: 6px 12px; border-radius: 999px; background: #14532d; color: #86efac; font-size: 13px; font-weight: 600; }}
    .card {{ background: #1e293b; border: 1px solid #334155; border-radius: 14px; padding: 18px 20px; margin-top: 16px; }}
    .btn {{ display: inline-block; margin-top: 10px; padding: 12px 18px; border-radius: 10px; background: #0d9488; color: #fff; text-decoration: none; font-weight: 600; }}
    textarea {{ width: 100%; height: 110px; background: #0f172a; color: #cbd5e1; border: 1px solid #475569; border-radius: 8px; padding: 10px; font-family: monospace; font-size: 12px; box-sizing: border-box; }}
    code {{ background: #0f172a; padding: 2px 6px; border-radius: 6px; font-size: 12px; word-break: break-all; }}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="topbar">
      <span class="badge">{status_badge}</span>
      <nav class="lang-nav">
        <a href="?lang=zh-CN" class="{cls_cn}">简体中文</a>
        <a href="?lang=zh-TW" class="{cls_tw}">繁體中文</a>
        <a href="?lang=en" class="{cls_en}">English</a>
        <a href="?lang=ja" class="{cls_ja}">日本語</a>
        <a href="?lang=ko" class="{cls_ko}">한국어</a>
        <a href="?lang=es" class="{cls_es}">Español</a>
        <a href="?lang=pt" class="{cls_pt}">Português</a>
        <a href="?lang=fr" class="{cls_fr}">Français</a>
        <a href="?lang=de" class="{cls_de}">Deutsch</a>
        <a href="?lang=ru" class="{cls_ru}">Русский</a>
        <a href="?lang=uk" class="{cls_uk}">Українська</a>
      </nav>
    </div>
    <h1>{heading}</h1>
    <p>{node_id_label}<code>{node_id_escaped}</code></p>
    {installer_block}
    <div class="card">
      <h2>{step2_title}</h2>
      <p>{step2_desc}</p>
      <textarea readonly>{ticket_escaped}</textarea>
    </div>
  </div>
</body>
</html>"#,
        cls_cn = if lang == BootstrapLang::ZhCn { "active" } else { "" },
        cls_tw = if lang == BootstrapLang::ZhTw { "active" } else { "" },
        cls_en = if lang == BootstrapLang::En { "active" } else { "" },
        cls_ja = if lang == BootstrapLang::Ja { "active" } else { "" },
        cls_ko = if lang == BootstrapLang::Ko { "active" } else { "" },
        cls_es = if lang == BootstrapLang::Es { "active" } else { "" },
        cls_pt = if lang == BootstrapLang::Pt { "active" } else { "" },
        cls_fr = if lang == BootstrapLang::Fr { "active" } else { "" },
        cls_de = if lang == BootstrapLang::De { "active" } else { "" },
        cls_ru = if lang == BootstrapLang::Ru { "active" } else { "" },
        cls_uk = if lang == BootstrapLang::Uk { "active" } else { "" },
    )
}

/// Probes candidate USB neighbor IPs on port `42420` (`GET /api/bootstrap-ticket`)
/// to automatically discover a tethered Home Node.
pub async fn probe_usb_bootstrap_candidates(
    candidate_ips: Vec<IpAddr>,
) -> Option<(String, UsbBootstrapPayload)> {
    for ip in candidate_ips {
        let target = SocketAddr::new(ip, USB_BOOTSTRAP_HTTP_PORT);
        let Ok(Ok(mut stream)) = tokio::time::timeout(
            std::time::Duration::from_millis(450),
            TcpStream::connect(target),
        )
        .await
        else {
            continue;
        };

        let req = format!(
            "GET /api/bootstrap-ticket HTTP/1.1\r\nHost: {ip}:{USB_BOOTSTRAP_HTTP_PORT}\r\nConnection: close\r\n\r\n"
        );
        if stream.write_all(req.as_bytes()).await.is_err() {
            continue;
        }
        let mut resp = Vec::new();
        let Ok(Ok(_)) = tokio::time::timeout(
            std::time::Duration::from_millis(600),
            stream.read_to_end(&mut resp),
        )
        .await
        else {
            continue;
        };

        let text = String::from_utf8_lossy(&resp);
        if let Some((_, body)) = text.split_once("\r\n\r\n")
            && let Ok(payload) = serde_json::from_str::<UsbBootstrapPayload>(body.trim())
        {
            return Some((format!("http://{ip}:{USB_BOOTSTRAP_HTTP_PORT}"), payload));
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolve_bootstrap_lang_follows_fallback_chain() {
        assert_eq!(
            BootstrapLang::resolve(None, Some("zh-CN,zh;q=0.9,en;q=0.8")),
            BootstrapLang::ZhCn
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("zh-TW,zh;q=0.9")),
            BootstrapLang::ZhTw
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("zh-HK,en-US;q=0.8")),
            BootstrapLang::ZhTw
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("zh-Hant,en;q=0.9")),
            BootstrapLang::ZhTw
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("fr-FR,uk;q=0.9")),
            BootstrapLang::Fr
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("ar-SA,th-TH;q=0.9")),
            BootstrapLang::En
        );
        assert_eq!(
            BootstrapLang::resolve(Some("lang=zh-TW"), Some("en-US")),
            BootstrapLang::ZhTw
        );
        assert_eq!(
            BootstrapLang::resolve(Some("lang=en"), Some("zh-CN")),
            BootstrapLang::En
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("ja-JP,en-US;q=0.8")),
            BootstrapLang::Ja
        );
        assert_eq!(
            BootstrapLang::resolve(Some("lang=ja"), Some("en-US")),
            BootstrapLang::Ja
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("ko-KR,ko;q=0.9,en;q=0.8")),
            BootstrapLang::Ko
        );
        assert_eq!(
            BootstrapLang::resolve(Some("lang=ko"), Some("zh-CN")),
            BootstrapLang::Ko
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("es-MX,en;q=0.8")),
            BootstrapLang::Es
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("pt-BR,en;q=0.8")),
            BootstrapLang::Pt
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("de-AT,en;q=0.8")),
            BootstrapLang::De
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("ru-RU,en;q=0.8")),
            BootstrapLang::Ru
        );
        assert_eq!(
            BootstrapLang::resolve(None, Some("uk-UA,ru;q=0.8")),
            BootstrapLang::Uk
        );
    }

    #[test]
    fn render_bootstrap_html_outputs_localized_content() {
        let payload = UsbBootstrapPayload {
            node_id: "node-123".into(),
            device_name: "Pixel".into(),
            home_node_mode: true,
            pairing_ticket_json: r#"{"node":"123"}"#.into(),
            room_invite_json: None,
            installer_filename: Some("setup.zip".into()),
            installer_size_bytes: Some(10 * 1024 * 1024),
            lan_addrs: vec![],
            usb_addrs: vec![],
        };
        let cases = [
            (BootstrapLang::ZhCn, r#"<html lang="zh-CN">"#, "裸机冷启动"),
            (BootstrapLang::ZhTw, r#"<html lang="zh-TW">"#, "裸機冷啟動"),
            (BootstrapLang::En, r#"<html lang="en">"#, "Cold-Start Setup"),
            (BootstrapLang::Ja, r#"<html lang="ja">"#, "初期セットアップ"),
            (BootstrapLang::Ko, r#"<html lang="ko">"#, "초기 설치"),
            (BootstrapLang::Es, r#"<html lang="es">"#, "Instalación inicial"),
            (BootstrapLang::Pt, r#"<html lang="pt">"#, "Instalação inicial"),
            (BootstrapLang::Fr, r#"<html lang="fr">"#, "Installation initiale"),
            (BootstrapLang::De, r#"<html lang="de">"#, "Ersteinrichtung"),
            (BootstrapLang::Ru, r#"<html lang="ru">"#, "Быстрый старт"),
            (BootstrapLang::Uk, r#"<html lang="uk">"#, "Швидкий старт"),
        ];
        for (lang, expected_attr, expected_snippet) in cases {
            let html = render_bootstrap_html(&payload, lang);
            assert!(html.contains(expected_attr), "missing {expected_attr}");
            assert!(html.contains(expected_snippet), "missing {expected_snippet}");
        }
    }
}
