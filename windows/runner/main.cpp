#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shellapi.h>

#include "flutter_window.h"
#include "utils.h"
#include "window_placement.h"

#include <string>

namespace {

constexpr int kDefaultWidth = 1180;
constexpr int kDefaultHeight = 760;

Win32Window::Point CenteredOrigin(const Win32Window::Size& size) {
  POINT cursor{0, 0};
  GetCursorPos(&cursor);
  HMONITOR monitor = MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{};
  info.cbSize = sizeof(MONITORINFO);
  if (!GetMonitorInfo(monitor, &info)) {
    return Win32Window::Point(40, 40);
  }

  const RECT& work = info.rcWork;
  const int work_width = work.right - work.left;
  const int work_height = work.bottom - work.top;
  const int x = work.left + (work_width - static_cast<int>(size.width)) / 2;
  const int y = work.top + (work_height - static_cast<int>(size.height)) / 2;
  return Win32Window::Point(
      static_cast<unsigned int>(x > work.left ? x : work.left + 24),
      static_cast<unsigned int>(y > work.top ? y : work.top + 24));
}

std::wstring GetProtocolUrlArgument() {
  int argument_count = 0;
  wchar_t** arguments = CommandLineToArgvW(GetCommandLineW(), &argument_count);
  if (arguments == nullptr) {
    return {};
  }

  std::wstring protocol_url;
  for (int i = 1; i < argument_count; ++i) {
    if (std::wstring(arguments[i]).find(L"://") != std::wstring::npos) {
      protocol_url = arguments[i];
      break;
    }
  }
  LocalFree(arguments);
  return protocol_url;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Single-instance check via Mutex
  HANDLE mutex = CreateMutex(nullptr, TRUE, L"Local\\WorkInsightTracker_SingleInstance_Mutex");
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND hwnd = nullptr;
    for (int attempt = 0; attempt < 100 && hwnd == nullptr; ++attempt) {
      hwnd = FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", L"WorkInsight Tracker");
      if (hwnd == nullptr) {
        Sleep(50);
      }
    }
    if (hwnd) {
      const std::wstring protocol_url = GetProtocolUrlArgument();
      if (!protocol_url.empty()) {
        COPYDATASTRUCT cds;
        cds.dwData = 1001;
        cds.cbData =
            static_cast<DWORD>((protocol_url.length() + 1) * sizeof(wchar_t));
        cds.lpData = const_cast<wchar_t*>(protocol_url.c_str());
        DWORD_PTR receiver_result = 0;
        const LRESULT send_result = SendMessageTimeout(
            hwnd, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&cds),
            SMTO_ABORTIFHUNG, 5000, &receiver_result);
        if (send_result == 0 || receiver_result == 0) {
          OutputDebugStringW(
              L"Failed to forward the protocol URL to the running instance.\n");
        }
      }
      SetForegroundWindow(hwnd);
      if (IsIconic(hwnd)) {
        ShowWindow(hwnd, SW_RESTORE);
      }
    } else {
      OutputDebugStringW(L"Could not find the running WorkInsight Tracker window.\n");
    }
    if (mutex) {
      ReleaseMutex(mutex);
      CloseHandle(mutex);
    }
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Size size(kDefaultWidth, kDefaultHeight);
  Win32Window::Point origin = CenteredOrigin(size);
  if (!window.Create(L"WorkInsight Tracker", origin, size)) {
    return EXIT_FAILURE;
  }

  // Position may be restored; size stays fixed (resize/maximize disabled).
  PersistedWindowBounds bounds;
  if (LoadPersistedWindowBounds(&bounds)) {
    bounds.width = kDefaultWidth;
    bounds.height = kDefaultHeight;
    bounds.maximized = false;
    ApplyPersistedWindowBounds(window.GetHandle(), bounds);
  }
  window.SetLaunchMaximized(false);

  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
