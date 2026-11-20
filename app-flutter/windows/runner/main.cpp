#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  HANDLE single_instance_mutex = ::CreateMutexW(
      nullptr, TRUE, L"Local\\P2PChatTransferSingleInstanceMutex");
  if (single_instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing = ::FindWindowW(L"P2P_CHAT_TRANSFER_WIN32_WINDOW", nullptr);
    if (existing != nullptr) {
      ::PostMessageW(existing, WM_USER + 102, 0, 0);
      if (::IsIconic(existing)) {
        ::ShowWindow(existing, SW_RESTORE);
      } else {
        ::ShowWindow(existing, SW_SHOW);
      }
      ::SetForegroundWindow(existing);
    }
    ::CloseHandle(single_instance_mutex);
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  const LANGID ui_lang = ::GetUserDefaultUILanguage();
  const wchar_t* initial_title = L"P2Pfiledrop";
  if (PRIMARYLANGID(ui_lang) == LANG_CHINESE) {
    const WORD sub = SUBLANGID(ui_lang);
    initial_title = (sub == SUBLANG_CHINESE_TRADITIONAL ||
                     sub == SUBLANG_CHINESE_HONGKONG ||
                     sub == SUBLANG_CHINESE_MACAU)
                        ? L"\u6587\u4EF6\u96A8\u624B\u50B3"
                        : L"\u6587\u4EF6\u968F\u624B\u4F20";
  }
  if (!window.Create(initial_title, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single_instance_mutex != nullptr) {
    ::ReleaseMutex(single_instance_mutex);
    ::CloseHandle(single_instance_mutex);
  }
  return EXIT_SUCCESS;
}
