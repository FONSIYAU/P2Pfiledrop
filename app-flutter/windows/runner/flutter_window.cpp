#include "flutter_window.h"

#include <algorithm>
#include <optional>
#include <string>
#include <variant>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {

constexpr UINT kWmTrayIcon = WM_USER + 101;
constexpr UINT kWmRestoreFromExternal = WM_USER + 102;
constexpr UINT kTrayIconId = 1;
constexpr UINT kCmdOpenWindow = 1001;
constexpr UINT kCmdToggleAutoStart = 1002;
constexpr UINT kCmdToggleCloseToTray = 1003;
constexpr UINT kCmdExitApp = 1004;

constexpr wchar_t kRunRegKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kAutoStartValueName[] = L"P2PChatTransfer";

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  int len = ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  if (len <= 0) {
    return std::wstring();
  }
  std::wstring out(static_cast<size_t>(len), L'\0');
  ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), &out[0], len);
  return out;
}

std::optional<std::string> GetStringArg(const flutter::EncodableMap* args,
                                        const char* key) {
  if (!args) return std::nullopt;
  auto it = args->find(flutter::EncodableValue(key));
  if (it == args->end()) return std::nullopt;
  if (const auto* s = std::get_if<std::string>(&it->second)) {
    return *s;
  }
  return std::nullopt;
}

std::optional<bool> GetBoolArg(const flutter::EncodableMap* args,
                               const char* key) {
  if (!args) return std::nullopt;
  auto it = args->find(flutter::EncodableValue(key));
  if (it == args->end()) return std::nullopt;
  if (const auto* b = std::get_if<bool>(&it->second)) {
    return *b;
  }
  return std::nullopt;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  const auto& args = project_.dart_entrypoint_arguments();
  start_minimized_ =
      std::find(args.begin(), args.end(), "--minimized") != args.end();

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  InitDefaultShellStrings();
  InitTrayIcon();
  SetupPlatformChannel();

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    if (!start_minimized_) {
      this->Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTrayIcon();
  platform_channel_.reset();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::InitDefaultShellStrings() {
  const LANGID lang_id = ::GetUserDefaultUILanguage();
  const WORD primary = PRIMARYLANGID(lang_id);
  const WORD sub = SUBLANGID(lang_id);
  if (primary == LANG_CHINESE) {
    if (sub == SUBLANG_CHINESE_TRADITIONAL ||
        sub == SUBLANG_CHINESE_HONGKONG ||
        sub == SUBLANG_CHINESE_MACAU) {
      str_app_title_ = L"P2P \u79C1\u4EBA\u5FEB\u50B3";
      str_tray_tooltip_ =
          L"P2P \u79C1\u4EBA\u5FEB\u50B3 \u00B7 "
          L"\u80CC\u666F\u5E38\u99D0\u5FEB\u50B3\u670D\u52D9";
      str_open_window_ = L"\u958B\u555F\u4E3B\u8996\u7A97";
      str_auto_start_ = L"\u958B\u6A5F\u81EA\u52D5\u975C\u9ED8\u555F\u52D5";
      str_close_to_tray_ =
          L"\u95DC\u9589\u6642\u6700\u5C0F\u5316\u81F3\u7CFB\u7D71\u5323";
      str_exit_app_ = L"\u5FB9\u5E95\u7D50\u675F\u7A0B\u5F0F";
      return;
    }
    str_app_title_ = L"P2P \u79C1\u4EBA\u5FEB\u4F20";
    str_tray_tooltip_ =
        L"P2P \u79C1\u4EBA\u5FEB\u4F20 \u00B7 "
        L"\u540E\u53F0\u5E38\u9A7B\u5FEB\u4F20\u670D\u52A1";
    str_open_window_ = L"\u6253\u5F00\u4E3B\u7A97\u53E3";
    str_auto_start_ = L"\u5F00\u673A\u81EA\u52A8\u9759\u9ED8\u542F\u52A8";
    str_close_to_tray_ = L"\u5173\u95ED\u65F6\u6700\u5C0F\u5316\u5230\u6258\u76D8";
    str_exit_app_ = L"\u5F7B\u5E95\u9000\u51FA\u7A0B\u5E8F";
    return;
  }
  if (primary == LANG_JAPANESE) {
    str_app_title_ = L"P2P \u30D7\u30E9\u30A4\u30D9\u30FC\u30C8\u8EE2\u9001";
    str_tray_tooltip_ =
        L"P2P \u30D7\u30E9\u30A4\u30D9\u30FC\u30C8\u8EE2\u9001 \u00B7 "
        L"\u30D0\u30C3\u30AF\u30B0\u30E9\u30A6\u30F3\u30C9\u5F85\u6A5F"
        L"\u30B5\u30FC\u30D3\u30B9";
    str_open_window_ = L"\u30E1\u30A4\u30F3\u30A6\u30A3\u30F3\u30C9\u30A6\u3092\u958B\u304F";
    str_auto_start_ =
        L"\u8D77\u52D5\u6642\u306B\u6700\u5C0F\u5316\u3057\u3066"
        L"\u81EA\u52D5\u958B\u59CB";
    str_close_to_tray_ =
        L"\u9589\u3058\u308B\u6642\u306B\u30C8\u30EC\u30A4\u3078"
        L"\u6700\u5C0F\u5316";
    str_exit_app_ = L"\u30A2\u30D7\u30EA\u3092\u5B8C\u5168\u306B\u7D42\u4E86";
    return;
  }
  if (primary == LANG_KOREAN) {
    str_app_title_ = L"P2P \uD504\uB77C\uC774\uBE57 \uC804\uC1A1";
    str_tray_tooltip_ =
        L"P2P \uD504\uB77C\uC774\uBE57 \uC804\uC1A1 \u00B7 "
        L"\uC0C1\uC2DC \uBC31\uADF8\uB77C\uC6B4\uB4DC \uC11C\uBE44\uC2A4";
    str_open_window_ = L"\uAE30\uBCF8 \uCC3D \uC5F4\uAE30";
    str_auto_start_ =
        L"\uBD80\uD305 \uC2DC \uCD5C\uC18C\uD654\uB85C "
        L"\uC790\uB3D9 \uC2E4\uD589";
    str_close_to_tray_ =
        L"\uB2EB\uC744 \uB54C \uD2B8\uB808\uC774\uB85C "
        L"\uCD5C\uC18C\uD654";
    str_exit_app_ =
        L"\uD504\uB85C\uADF8\uB7A8 \uC644\uC804\uD788 \uC885\uB8CC";
    return;
  }
  if (primary == LANG_SPANISH) {
    str_app_title_ = L"Transferencia Privada P2P";
    str_tray_tooltip_ =
        L"Transferencia Privada P2P \u00B7 Servicio en segundo plano";
    str_open_window_ = L"Abrir ventana principal";
    str_auto_start_ = L"Iniciar minimizado con Windows";
    str_close_to_tray_ = L"Minimizar a la bandeja al cerrar";
    str_exit_app_ = L"Salir completamente";
    return;
  }
  if (primary == LANG_PORTUGUESE) {
    str_app_title_ = L"Transfer\u00EAncia Privada P2P";
    str_tray_tooltip_ =
        L"Transfer\u00EAncia Privada P2P \u00B7 Servi\u00E7o ativo";
    str_open_window_ = L"Abrir janela principal";
    str_auto_start_ = L"Iniciar minimizado com o Windows";
    str_close_to_tray_ = L"Minimizar para bandeja ao fechar";
    str_exit_app_ = L"Sair do aplicativo";
    return;
  }
  if (primary == LANG_FRENCH) {
    str_app_title_ = L"Transfert Priv\u00E9 P2P";
    str_tray_tooltip_ = L"Transfert Priv\u00E9 P2P \u00B7 Service actif";
    str_open_window_ = L"Ouvrir la fen\u00EAtre principale";
    str_auto_start_ = L"D\u00E9marrer r\u00E9duit avec Windows";
    str_close_to_tray_ = L"R\u00E9duire dans la zone \u00E0 la fermeture";
    str_exit_app_ = L"Quitter l'application";
    return;
  }
  if (primary == LANG_GERMAN) {
    str_app_title_ = L"P2P-Privattransfer";
    str_tray_tooltip_ = L"P2P-Privattransfer \u00B7 Hintergrunddienst";
    str_open_window_ = L"Hauptfenster \u00F6ffnen";
    str_auto_start_ = L"Minimiert mit Windows starten";
    str_close_to_tray_ = L"Beim Schlie\u00DFen in Infoleiste minimieren";
    str_exit_app_ = L"App vollst\u00E4ndig beenden";
    return;
  }
  if (primary == LANG_RUSSIAN) {
    str_app_title_ =
        L"P2P \u041F\u0440\u0438\u0432\u0430\u0442\u043D\u044B\u0439 "
        L"\u043E\u0431\u043C\u0435\u043D";
    str_tray_tooltip_ =
        L"P2P \u041F\u0440\u0438\u0432\u0430\u0442\u043D\u044B\u0439 "
        L"\u043E\u0431\u043C\u0435\u043D \u00B7 \u0424\u043E\u043D\u043E"
        L"\u0432\u044B\u0439 \u0441\u0435\u0440\u0432\u0438\u0441";
    str_open_window_ =
        L"\u041E\u0442\u043A\u0440\u044B\u0442\u044C "
        L"\u0433\u043B\u0430\u0432\u043D\u043E\u0435 "
        L"\u043E\u043A\u043D\u043E";
    str_auto_start_ =
        L"\u0410\u0432\u0442\u043E\u0437\u0430\u043F\u0443\u0441\u043A "
        L"\u0432 \u0441\u0432\u0435\u0440\u043D\u0443\u0442\u043E\u043C "
        L"\u0432\u0438\u0434\u0435";
    str_close_to_tray_ =
        L"\u0421\u0432\u043E\u0440\u0430\u0447\u0438\u0432\u0430\u0442\u044C "
        L"\u0432 \u0442\u0440\u0435\u0439 \u043F\u0440\u0438 "
        L"\u0437\u0430\u043A\u0440\u044B\u0442\u0438\u0438";
    str_exit_app_ =
        L"\u041F\u043E\u043B\u043D\u043E\u0441\u0442\u044C\u044E "
        L"\u0432\u044B\u0439\u0442\u0438";
    return;
  }
  if (primary == LANG_UKRAINIAN) {
    str_app_title_ =
        L"P2P \u041F\u0440\u0438\u0432\u0430\u0442\u043D\u0438\u0439 "
        L"\u043E\u0431\u043C\u0456\u043D";
    str_tray_tooltip_ =
        L"P2P \u041F\u0440\u0438\u0432\u0430\u0442\u043D\u0438\u0439 "
        L"\u043E\u0431\u043C\u0456\u043D \u00B7 \u0424\u043E\u043D\u043E"
        L"\u0432\u0438\u0439 \u0441\u0435\u0440\u0432\u0456\u0441";
    str_open_window_ =
        L"\u0412\u0456\u0434\u043A\u0440\u0438\u0442\u0438 "
        L"\u0433\u043E\u043B\u043E\u0432\u043D\u0435 "
        L"\u0432\u0456\u043A\u043D\u043E";
    str_auto_start_ =
        L"\u0410\u0432\u0442\u043E\u0437\u0430\u043F\u0443\u0441\u043A "
        L"\u0437\u0433\u043E\u0440\u043D\u0443\u0442\u0438\u043C \u0443 "
        L"\u0442\u0440\u0435\u0439";
    str_close_to_tray_ =
        L"\u0417\u0433\u043E\u0440\u0442\u0430\u0442\u0438 \u0443 "
        L"\u0442\u0440\u0435\u0439 \u043F\u0440\u0438 "
        L"\u0437\u0430\u043A\u0440\u0438\u0442\u0442\u0456";
    str_exit_app_ =
        L"\u041F\u043E\u0432\u043D\u0456\u0441\u0442\u044E "
        L"\u0432\u0438\u0439\u0442\u0438";
    return;
  }
  str_app_title_ = L"P2P Private Transfer";
  str_tray_tooltip_ = L"P2P Private Transfer \u00B7 Background Service";
  str_open_window_ = L"Open Main Window";
  str_auto_start_ = L"Start Minimized on Boot";
  str_close_to_tray_ = L"Minimize to Tray on Close";
  str_exit_app_ = L"Exit Application";
}

void FlutterWindow::UpdateTrayTooltip() {
  if (!tray_initialized_) {
    return;
  }
  NOTIFYICONDATAW tip = nid_;
  tip.uFlags = NIF_TIP;
  wcsncpy_s(tip.szTip, str_tray_tooltip_.c_str(), _TRUNCATE);
  ::Shell_NotifyIconW(NIM_MODIFY, &tip);
}

void FlutterWindow::InitTrayIcon() {
  if (tray_initialized_) {
    return;
  }
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  ZeroMemory(&nid_, sizeof(nid_));
  nid_.cbSize = sizeof(NOTIFYICONDATAW);
  nid_.hWnd = hwnd;
  nid_.uID = kTrayIconId;
  nid_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  nid_.uCallbackMessage = kWmTrayIcon;
  HICON icon = static_cast<HICON>(::LoadImageW(
      ::GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
      ::GetSystemMetrics(SM_CXSMICON), ::GetSystemMetrics(SM_CYSMICON),
      LR_DEFAULTCOLOR | LR_SHARED));
  if (!icon) {
    icon = ::LoadIconW(nullptr, IDI_APPLICATION);
  }
  nid_.hIcon = icon;
  wcsncpy_s(nid_.szTip, str_tray_tooltip_.c_str(), _TRUNCATE);
  tray_initialized_ = ::Shell_NotifyIconW(NIM_ADD, &nid_) == TRUE;
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_initialized_) {
    return;
  }
  ::Shell_NotifyIconW(NIM_DELETE, &nid_);
  tray_initialized_ = false;
}

void FlutterWindow::ShowTrayBalloon(const std::wstring& title,
                                    const std::wstring& body) {
  if (!tray_initialized_) {
    return;
  }
  NOTIFYICONDATAW balloon = nid_;
  balloon.uFlags = NIF_INFO;
  balloon.dwInfoFlags = NIIF_INFO;
  wcsncpy_s(balloon.szInfoTitle, title.c_str(), _TRUNCATE);
  wcsncpy_s(balloon.szInfo, body.c_str(), _TRUNCATE);
  ::Shell_NotifyIconW(NIM_MODIFY, &balloon);
}

void FlutterWindow::RestoreFromTray() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  ::ShowWindow(hwnd, SW_SHOW);
  if (::IsIconic(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  }
  ::SetForegroundWindow(hwnd);
  if (flutter_controller_) {
    flutter_controller_->ForceRedraw();
  }
}

void FlutterWindow::HideToTray() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  ::ShowWindow(hwnd, SW_HIDE);
}

void FlutterWindow::ShowTrayContextMenu() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  HMENU menu = ::CreatePopupMenu();
  if (!menu) {
    return;
  }

  const bool auto_start = IsAutoStartEnabled();
  ::AppendMenuW(menu, MF_STRING, kCmdOpenWindow, str_open_window_.c_str());
  ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  ::AppendMenuW(menu, MF_STRING | (auto_start ? MF_CHECKED : MF_UNCHECKED),
                kCmdToggleAutoStart, str_auto_start_.c_str());
  ::AppendMenuW(
      menu, MF_STRING | (close_to_tray_ ? MF_CHECKED : MF_UNCHECKED),
      kCmdToggleCloseToTray, str_close_to_tray_.c_str());
  ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  ::AppendMenuW(menu, MF_STRING, kCmdExitApp, str_exit_app_.c_str());
  ::SetMenuDefaultItem(menu, kCmdOpenWindow, FALSE);

  POINT pt{};
  ::GetCursorPos(&pt);
  ::SetForegroundWindow(hwnd);
  UINT cmd = ::TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_NONOTIFY, pt.x, pt.y, 0, hwnd,
      nullptr);
  ::PostMessageW(hwnd, WM_NULL, 0, 0);
  ::DestroyMenu(menu);

  switch (cmd) {
    case kCmdOpenWindow:
      RestoreFromTray();
      break;
    case kCmdToggleAutoStart:
      SetAutoStartEnabled(!auto_start);
      break;
    case kCmdToggleCloseToTray:
      close_to_tray_ = !close_to_tray_;
      break;
    case kCmdExitApp:
      really_quit_ = true;
      ::DestroyWindow(hwnd);
      break;
    default:
      break;
  }
}

bool FlutterWindow::IsAutoStartEnabled() const {
  HKEY hkey = nullptr;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER, kRunRegKey, 0, KEY_READ, &hkey) !=
      ERROR_SUCCESS) {
    return false;
  }
  DWORD type = 0;
  DWORD size = 0;
  LONG rc = ::RegQueryValueExW(hkey, kAutoStartValueName, nullptr, &type,
                               nullptr, &size);
  ::RegCloseKey(hkey);
  return rc == ERROR_SUCCESS && size > 0;
}

bool FlutterWindow::SetAutoStartEnabled(bool enabled) const {
  HKEY hkey = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, kRunRegKey, 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &hkey,
                        nullptr) != ERROR_SUCCESS) {
    return false;
  }
  LONG rc = ERROR_SUCCESS;
  if (enabled) {
    wchar_t exe_path[MAX_PATH] = {0};
    DWORD len = ::GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) {
      ::RegCloseKey(hkey);
      return false;
    }
    std::wstring cmd = std::wstring(L"\"") + exe_path + L"\" --minimized";
    DWORD bytes = static_cast<DWORD>((cmd.size() + 1) * sizeof(wchar_t));
    rc = ::RegSetValueExW(hkey, kAutoStartValueName, 0, REG_SZ,
                          reinterpret_cast<const BYTE*>(cmd.c_str()), bytes);
  } else {
    rc = ::RegDeleteValueW(hkey, kAutoStartValueName);
    if (rc == ERROR_FILE_NOT_FOUND) {
      rc = ERROR_SUCCESS;
    }
  }
  ::RegCloseKey(hkey);
  return rc == ERROR_SUCCESS;
}

void FlutterWindow::SetupPlatformChannel() {
  platform_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "dev.p2pchat/platform",
          &flutter::StandardMethodCodec::GetInstance());

  platform_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());

        if (method == "getWindowsShellState") {
          flutter::EncodableMap map;
          map[flutter::EncodableValue("autoStart")] =
              flutter::EncodableValue(IsAutoStartEnabled());
          map[flutter::EncodableValue("closeToTray")] =
              flutter::EncodableValue(close_to_tray_);
          result->Success(flutter::EncodableValue(map));
          return;
        }

        if (method == "setWindowsAutoStart") {
          bool enabled = GetBoolArg(args, "enabled").value_or(false);
          SetAutoStartEnabled(enabled);
          result->Success(flutter::EncodableValue(IsAutoStartEnabled()));
          return;
        }

        if (method == "setWindowsCloseToTray") {
          close_to_tray_ = GetBoolArg(args, "enabled").value_or(true);
          result->Success(flutter::EncodableValue(close_to_tray_));
          return;
        }

        if (method == "showTrayNotification") {
          HWND hwnd = GetHandle();
          if (hwnd && ::IsWindowVisible(hwnd) && !::IsIconic(hwnd) &&
              ::GetForegroundWindow() == hwnd) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          std::string title = GetStringArg(args, "title").value_or("");
          std::string body = GetStringArg(args, "body").value_or("");
          std::wstring wtitle = Utf16FromUtf8(title);
          if (wtitle.empty()) {
            wtitle = str_app_title_;
          }
          ShowTrayBalloon(wtitle, Utf16FromUtf8(body));
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (method == "setWindowsShellStrings") {
          if (auto v = GetStringArg(args, "appTitle"); v && !v->empty()) {
            str_app_title_ = Utf16FromUtf8(*v);
            if (HWND hwnd = GetHandle()) {
              ::SetWindowTextW(hwnd, str_app_title_.c_str());
            }
          }
          if (auto v = GetStringArg(args, "trayTooltip"); v && !v->empty()) {
            str_tray_tooltip_ = Utf16FromUtf8(*v);
            UpdateTrayTooltip();
          }
          if (auto v = GetStringArg(args, "openWindow"); v && !v->empty()) {
            str_open_window_ = Utf16FromUtf8(*v);
          }
          if (auto v = GetStringArg(args, "autoStart"); v && !v->empty()) {
            str_auto_start_ = Utf16FromUtf8(*v);
          }
          if (auto v = GetStringArg(args, "closeToTray"); v && !v->empty()) {
            str_close_to_tray_ = Utf16FromUtf8(*v);
          }
          if (auto v = GetStringArg(args, "exitApp"); v && !v->empty()) {
            str_exit_app_ = Utf16FromUtf8(*v);
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (method == "revealInExplorer") {
          std::string path = GetStringArg(args, "path").value_or("");
          if (!path.empty()) {
            std::wstring wpath = Utf16FromUtf8(path);
            std::wstring params = L"/select,\"" + wpath + L"\"";
            ::ShellExecuteW(nullptr, L"open", L"explorer.exe", params.c_str(),
                            nullptr, SW_SHOWNORMAL);
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (method == "hideToTray") {
          HideToTray();
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (method == "quitApp") {
          really_quit_ = true;
          HWND hwnd = GetHandle();
          result->Success(flutter::EncodableValue(true));
          if (hwnd) {
            ::DestroyWindow(hwnd);
          }
          return;
        }

        result->NotImplemented();
      });
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE:
      if (close_to_tray_ && !really_quit_) {
        HideToTray();
        return 0;
      }
      break;

    case kWmRestoreFromExternal:
      RestoreFromTray();
      return 0;

    case kWmTrayIcon: {
      UINT event_msg = LOWORD(lparam);
      if (event_msg == WM_LBUTTONUP || event_msg == WM_LBUTTONDBLCLK ||
          event_msg == NIN_BALLOONUSERCLICK) {
        RestoreFromTray();
        return 0;
      }
      if (event_msg == WM_RBUTTONUP || event_msg == WM_CONTEXTMENU) {
        ShowTrayContextMenu();
        return 0;
      }
      break;
    }

    case WM_COMMAND: {
      UINT cmd = LOWORD(wparam);
      if (cmd == kCmdOpenWindow) {
        RestoreFromTray();
        return 0;
      }
      if (cmd == kCmdToggleAutoStart) {
        SetAutoStartEnabled(!IsAutoStartEnabled());
        return 0;
      }
      if (cmd == kCmdToggleCloseToTray) {
        close_to_tray_ = !close_to_tray_;
        return 0;
      }
      if (cmd == kCmdExitApp) {
        really_quit_ = true;
        ::DestroyWindow(hwnd);
        return 0;
      }
      break;
    }

    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
