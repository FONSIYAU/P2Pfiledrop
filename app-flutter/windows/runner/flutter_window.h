#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <shellapi.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that hosts a Flutter view plus native Windows system tray,
// startup auto-run, explorer reveal, and desktop notifications.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void InitTrayIcon();
  void RemoveTrayIcon();
  void ShowTrayBalloon(const std::wstring& title, const std::wstring& body);
  void RestoreFromTray();
  void HideToTray();
  void ShowTrayContextMenu();
  bool IsAutoStartEnabled() const;
  bool SetAutoStartEnabled(bool enabled) const;
  void InitDefaultShellStrings();
  void UpdateTrayTooltip();
  void SetupPlatformChannel();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      platform_channel_;
  NOTIFYICONDATAW nid_{};
  bool tray_initialized_ = false;
  bool close_to_tray_ = true;
  bool really_quit_ = false;
  bool start_minimized_ = false;

  std::wstring str_app_title_;
  std::wstring str_tray_tooltip_;
  std::wstring str_open_window_;
  std::wstring str_auto_start_;
  std::wstring str_close_to_tray_;
  std::wstring str_exit_app_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
