#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "window_placement.h"

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

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

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
