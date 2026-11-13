#include "window_placement.h"

#include <algorithm>

namespace {

constexpr wchar_t kRegKey[] = L"Software\\Witrack\\Window";
constexpr wchar_t kX[] = L"X";
constexpr wchar_t kY[] = L"Y";
constexpr wchar_t kWidth[] = L"Width";
constexpr wchar_t kHeight[] = L"Height";
constexpr wchar_t kMaximized[] = L"Maximized";

// Keep in sync with AppConstants.windowWidth/Height (fixed, non-resizable).
constexpr int kMinWidthLogical = 1180;
constexpr int kMinHeightLogical = 760;

bool ReadDword(HKEY key, const wchar_t* name, DWORD* value) {
  DWORD type = 0;
  DWORD size = sizeof(DWORD);
  return RegQueryValueEx(key, name, nullptr, &type,
                         reinterpret_cast<LPBYTE>(value), &size) ==
             ERROR_SUCCESS &&
         type == REG_DWORD;
}

void WriteDword(HKEY key, const wchar_t* name, DWORD value) {
  RegSetValueEx(key, name, 0, REG_DWORD, reinterpret_cast<const BYTE*>(&value),
                sizeof(value));
}

int MinTrackWidthPhysical(HWND window) {
  const UINT dpi = GetDpiForWindow(window);
  return MulDiv(kMinWidthLogical, static_cast<int>(dpi), 96);
}

int MinTrackHeightPhysical(HWND window) {
  const UINT dpi = GetDpiForWindow(window);
  return MulDiv(kMinHeightLogical, static_cast<int>(dpi), 96);
}

bool ClampPhysicalRect(RECT* rect) {
  if (rect == nullptr) {
    return false;
  }

  HMONITOR monitor = MonitorFromRect(rect, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{};
  info.cbSize = sizeof(MONITORINFO);
  if (!GetMonitorInfo(monitor, &info)) {
    return false;
  }

  const RECT& work = info.rcWork;
  int width = rect->right - rect->left;
  int height = rect->bottom - rect->top;
  const int work_width = work.right - work.left;
  const int work_height = work.bottom - work.top;

  width = std::min(width, work_width);
  height = std::min(height, work_height);
  width = std::max(width, std::min(kMinWidthLogical, work_width));
  height = std::max(height, std::min(kMinHeightLogical, work_height));

  int x = rect->left;
  int y = rect->top;
  if (x + width > work.right) {
    x = work.right - width;
  }
  if (y + height > work.bottom) {
    y = work.bottom - height;
  }
  if (x < work.left) {
    x = work.left;
  }
  if (y < work.top) {
    y = work.top;
  }

  rect->left = x;
  rect->top = y;
  rect->right = x + width;
  rect->bottom = y + height;
  return MonitorFromRect(rect, MONITOR_DEFAULTTONULL) != nullptr;
}

}  // namespace

bool LoadPersistedWindowBounds(PersistedWindowBounds* out) {
  if (out == nullptr) {
    return false;
  }

  HKEY key = nullptr;
  if (RegOpenKeyEx(HKEY_CURRENT_USER, kRegKey, 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return false;
  }

  DWORD x = 0;
  DWORD y = 0;
  DWORD width = 0;
  DWORD height = 0;
  DWORD max_flag = 0;
  const bool ok = ReadDword(key, kX, &x) && ReadDword(key, kY, &y) &&
                  ReadDword(key, kWidth, &width) &&
                  ReadDword(key, kHeight, &height) &&
                  ReadDword(key, kMaximized, &max_flag);
  RegCloseKey(key);
  if (!ok || width == 0 || height == 0) {
    return false;
  }

  RECT rect{static_cast<LONG>(x), static_cast<LONG>(y),
            static_cast<LONG>(x + width), static_cast<LONG>(y + height)};
  if (!ClampPhysicalRect(&rect)) {
    return false;
  }

  out->x = rect.left;
  out->y = rect.top;
  out->width = rect.right - rect.left;
  out->height = rect.bottom - rect.top;
  out->maximized = max_flag != 0;
  return true;
}

bool ApplyPersistedWindowBounds(HWND window,
                                const PersistedWindowBounds& bounds) {
  if (window == nullptr || bounds.width <= 0 || bounds.height <= 0) {
    return false;
  }

  RECT rect{bounds.x, bounds.y, bounds.x + bounds.width,
            bounds.y + bounds.height};
  if (!ClampPhysicalRect(&rect)) {
    return false;
  }

  const int min_w = MinTrackWidthPhysical(window);
  const int min_h = MinTrackHeightPhysical(window);
  if ((rect.right - rect.left) < min_w) {
    rect.right = rect.left + min_w;
  }
  if ((rect.bottom - rect.top) < min_h) {
    rect.bottom = rect.top + min_h;
  }
  ClampPhysicalRect(&rect);

  return SetWindowPos(window, nullptr, rect.left, rect.top,
                      rect.right - rect.left, rect.bottom - rect.top,
                      SWP_NOZORDER | SWP_NOACTIVATE) != FALSE;
}

void PersistWindowBounds(HWND window) {
  if (window == nullptr) {
    return;
  }

  WINDOWPLACEMENT placement{};
  placement.length = sizeof(WINDOWPLACEMENT);
  if (!GetWindowPlacement(window, &placement)) {
    return;
  }

  const RECT& normal = placement.rcNormalPosition;
  const int width = normal.right - normal.left;
  const int height = normal.bottom - normal.top;
  if (width <= 0 || height <= 0) {
    return;
  }

  HKEY key = nullptr;
  if (RegCreateKeyEx(HKEY_CURRENT_USER, kRegKey, 0, nullptr, 0, KEY_WRITE,
                     nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }

  WriteDword(key, kX, static_cast<DWORD>(normal.left));
  WriteDword(key, kY, static_cast<DWORD>(normal.top));
  WriteDword(key, kWidth, static_cast<DWORD>(width));
  WriteDword(key, kHeight, static_cast<DWORD>(height));
  WriteDword(key, kMaximized,
             placement.showCmd == SW_SHOWMAXIMIZED ? 1u : 0u);
  RegCloseKey(key);
}
