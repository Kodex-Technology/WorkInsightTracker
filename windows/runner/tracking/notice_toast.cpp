#include "notice_toast.h"

#include <dwmapi.h>
#include <windows.h>
#include <windowsx.h>

#include <string>

#include <gdiplus.h>

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif
#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif

namespace witrack {
namespace {

constexpr wchar_t kClassName[] = L"WitrackNoticeToast";
constexpr UINT kCloseTimerId = 1;
constexpr int kToastW = 360;
constexpr int kToastH = 92;
constexpr int kRadius = 14;
constexpr int kPad = 14;
constexpr int kIconSize = 40;
constexpr int kCloseSize = 28;

struct ToastState {
  HWND hwnd = nullptr;
  std::wstring title;
  std::wstring body;
  std::wstring kind;
  int duration_ms = 7000;
};

ToastState g_toast;
ULONG_PTR g_gdiplus_token = 0;
int g_gdiplus_refs = 0;

void EnsureGdiplus() {
  if (g_gdiplus_refs == 0) {
    Gdiplus::GdiplusStartupInput input;
    Gdiplus::GdiplusStartup(&g_gdiplus_token, &input, nullptr);
  }
  ++g_gdiplus_refs;
}

void ReleaseGdiplus() {
  if (g_gdiplus_refs <= 0) return;
  --g_gdiplus_refs;
  if (g_gdiplus_refs == 0 && g_gdiplus_token) {
    Gdiplus::GdiplusShutdown(g_gdiplus_token);
    g_gdiplus_token = 0;
  }
}

Gdiplus::Color AccentForKind(const std::wstring& kind) {
  if (kind == L"idle") {
    return Gdiplus::Color(255, 245, 158, 11);  // amber
  }
  return Gdiplus::Color(255, 20, 184, 166);  // brand teal #14B8A6
}

Gdiplus::Color AccentSoft(const std::wstring& kind) {
  if (kind == L"idle") {
    return Gdiplus::Color(40, 245, 158, 11);
  }
  return Gdiplus::Color(40, 20, 184, 166);
}

void DestroyToast() {
  if (!g_toast.hwnd) return;
  KillTimer(g_toast.hwnd, kCloseTimerId);
  DestroyWindow(g_toast.hwnd);
  g_toast.hwnd = nullptr;
  ReleaseGdiplus();
}

void DrawCloseIcon(Gdiplus::Graphics& g, int x, int y, int size);
void DrawKindIcon(Gdiplus::Graphics& g, float cx, float cy, float r,
                  const std::wstring& kind);

void DrawToastContent(Gdiplus::Graphics& g, int w, int h) {
  g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
  g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);
  g.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);

  Gdiplus::GraphicsPath path;
  path.AddArc(0, 0, kRadius * 2, kRadius * 2, 180, 90);
  path.AddArc(w - kRadius * 2 - 1, 0, kRadius * 2, kRadius * 2, 270, 90);
  path.AddArc(w - kRadius * 2 - 1, h - kRadius * 2 - 1, kRadius * 2, kRadius * 2,
              0, 90);
  path.AddArc(0, h - kRadius * 2 - 1, kRadius * 2, kRadius * 2, 90, 90);
  path.CloseFigure();

  Gdiplus::SolidBrush bg(Gdiplus::Color(255, 23, 30, 39));
  g.FillPath(&bg, &path);

  Gdiplus::Pen border(Gdiplus::Color(90, 71, 85, 105), 1.0f);
  g.DrawPath(&border, &path);

  const float icon_cx = static_cast<float>(kPad + kIconSize / 2);
  const float icon_cy = static_cast<float>(h / 2 - 2);
  DrawKindIcon(g, icon_cx, icon_cy, static_cast<float>(kIconSize) / 2.0f,
               g_toast.kind);

  const int text_left = kPad + kIconSize + 12;
  const int text_right = w - kPad - kCloseSize;

  Gdiplus::FontFamily family(L"Segoe UI");
  Gdiplus::Font brand_font(&family, 9.0f, Gdiplus::FontStyleBold,
                           Gdiplus::UnitPixel);
  Gdiplus::Font title_font(&family, 14.0f, Gdiplus::FontStyleBold,
                           Gdiplus::UnitPixel);
  Gdiplus::Font body_font(&family, 11.5f, Gdiplus::FontStyleRegular,
                          Gdiplus::UnitPixel);

  Gdiplus::SolidBrush brand_brush(Gdiplus::Color(255, 20, 184, 166));
  Gdiplus::SolidBrush title_brush(Gdiplus::Color(255, 248, 250, 252));
  Gdiplus::SolidBrush body_brush(Gdiplus::Color(255, 148, 163, 184));

  Gdiplus::StringFormat near_fmt;
  near_fmt.SetAlignment(Gdiplus::StringAlignmentNear);
  near_fmt.SetLineAlignment(Gdiplus::StringAlignmentNear);
  near_fmt.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);

  Gdiplus::RectF brand_rc(static_cast<Gdiplus::REAL>(text_left), 12.0f,
                          static_cast<Gdiplus::REAL>(text_right - text_left),
                          14.0f);
  g.DrawString(L"WORKINSIGHT", -1, &brand_font, brand_rc, &near_fmt,
               &brand_brush);

  Gdiplus::RectF title_rc(static_cast<Gdiplus::REAL>(text_left), 28.0f,
                          static_cast<Gdiplus::REAL>(text_right - text_left),
                          20.0f);
  g.DrawString(g_toast.title.c_str(), -1, &title_font, title_rc, &near_fmt,
               &title_brush);

  Gdiplus::RectF body_rc(static_cast<Gdiplus::REAL>(text_left), 50.0f,
                         static_cast<Gdiplus::REAL>(text_right - text_left),
                         28.0f);
  g.DrawString(g_toast.body.c_str(), -1, &body_font, body_rc, &near_fmt,
               &body_brush);

  DrawCloseIcon(g, w - kPad - kCloseSize + 2, 10, kCloseSize - 4);

  // Static accent underline (no animated redraw).
  Gdiplus::SolidBrush bar(AccentForKind(g_toast.kind));
  g.FillRectangle(&bar, 1.0f, h - 3.0f, w - 2.0f, 2.0f);
}

void DrawCloseIcon(Gdiplus::Graphics& g, int x, int y, int size) {
  const float inset = 9.0f;
  Gdiplus::Pen pen(Gdiplus::Color(200, 148, 163, 184), 1.6f);
  pen.SetStartCap(Gdiplus::LineCapRound);
  pen.SetEndCap(Gdiplus::LineCapRound);
  g.DrawLine(&pen, x + inset, y + inset, x + size - inset, y + size - inset);
  g.DrawLine(&pen, x + size - inset, y + inset, x + inset, y + size - inset);
}

void DrawKindIcon(Gdiplus::Graphics& g, float cx, float cy, float r,
                  const std::wstring& kind) {
  const auto accent = AccentForKind(kind);
  Gdiplus::SolidBrush soft(AccentSoft(kind));
  Gdiplus::SolidBrush fill(Gdiplus::Color(255, 23, 30, 39));
  g.FillEllipse(&soft, cx - r, cy - r, r * 2, r * 2);
  g.FillEllipse(&fill, cx - r + 3, cy - r + 3, (r - 3) * 2, (r - 3) * 2);

  Gdiplus::Pen pen(accent, 1.8f);
  pen.SetStartCap(Gdiplus::LineCapRound);
  pen.SetEndCap(Gdiplus::LineCapRound);
  pen.SetLineJoin(Gdiplus::LineJoinRound);

  if (kind == L"idle") {
    // Minimal clock
    g.DrawEllipse(&pen, cx - 9.f, cy - 9.f, 18.f, 18.f);
    g.DrawLine(&pen, cx, cy, cx, cy - 6.f);
    g.DrawLine(&pen, cx, cy, cx + 5.f, cy + 2.f);
  } else {
    // Minimal camera
    g.DrawRectangle(&pen, cx - 10.f, cy - 6.f, 18.f, 13.f);
    g.DrawEllipse(&pen, cx - 4.f, cy - 3.f, 8.f, 8.f);
    g.DrawLine(&pen, cx - 4.f, cy - 8.f, cx + 2.f, cy - 8.f);
  }
}

void PaintToast(HWND hwnd) {
  PAINTSTRUCT ps;
  HDC hdc = BeginPaint(hwnd, &ps);
  RECT rc{};
  GetClientRect(hwnd, &rc);
  const int w = rc.right;
  const int h = rc.bottom;

  // Double-buffer so a single paint never flashes.
  HDC mem = CreateCompatibleDC(hdc);
  HBITMAP bmp = CreateCompatibleBitmap(hdc, w, h);
  HGDIOBJ old = SelectObject(mem, bmp);

  Gdiplus::Graphics g(mem);
  DrawToastContent(g, w, h);
  BitBlt(hdc, 0, 0, w, h, mem, 0, 0, SRCCOPY);

  SelectObject(mem, old);
  DeleteObject(bmp);
  DeleteDC(mem);
  EndPaint(hwnd, &ps);
}

LRESULT CALLBACK ToastWndProc(HWND hwnd, UINT msg, WPARAM wparam,
                              LPARAM lparam) {
  switch (msg) {
    case WM_NCHITTEST: {
      POINT pt{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      ScreenToClient(hwnd, &pt);
      RECT close{kToastW - kPad - kCloseSize, 8, kToastW - kPad, 8 + kCloseSize};
      if (PtInRect(&close, pt)) return HTCLIENT;
      return HTCLIENT;
    }
    case WM_ERASEBKGND:
      return 1;
    case WM_TIMER:
      if (wparam == kCloseTimerId) {
        DestroyToast();
      }
      return 0;
    case WM_LBUTTONUP: {
      POINT pt{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      RECT close{kToastW - kPad - kCloseSize, 8, kToastW - kPad, 8 + kCloseSize};
      if (PtInRect(&close, pt)) {
        DestroyToast();
      }
      return 0;
    }
    case WM_PAINT:
      PaintToast(hwnd);
      return 0;
    case WM_DESTROY:
      g_toast.hwnd = nullptr;
      return 0;
    default:
      return DefWindowProcW(hwnd, msg, wparam, lparam);
  }
}

bool EnsureClass(HINSTANCE instance) {
  static bool registered = false;
  if (registered) return true;
  WNDCLASSEXW wc{};
  wc.cbSize = sizeof(wc);
  wc.lpfnWndProc = ToastWndProc;
  wc.hInstance = instance;
  wc.lpszClassName = kClassName;
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.hbrBackground = nullptr;
  registered = RegisterClassExW(&wc) != 0;
  return registered;
}

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return L"";
  const int needed =
      MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  std::wstring out(needed > 0 ? needed - 1 : 0, L'\0');
  if (needed > 1) {
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, out.data(), needed);
  }
  return out;
}

}  // namespace

void ShowDesktopNoticeToast(const std::wstring& title,
                            const std::wstring& body,
                            const std::wstring& kind,
                            int duration_ms) {
  HINSTANCE instance = GetModuleHandleW(nullptr);
  if (!EnsureClass(instance)) return;

  const int dur = duration_ms > 0 ? duration_ms : 7000;

  // Same toast already up — refresh text + restart close timer (no recreate).
  if (g_toast.hwnd && IsWindow(g_toast.hwnd) && g_toast.kind == kind) {
    g_toast.title = title;
    g_toast.body = body;
    g_toast.duration_ms = dur;
    KillTimer(g_toast.hwnd, kCloseTimerId);
    SetTimer(g_toast.hwnd, kCloseTimerId, dur, nullptr);
    InvalidateRect(g_toast.hwnd, nullptr, FALSE);
    UpdateWindow(g_toast.hwnd);
    return;
  }

  DestroyToast();
  EnsureGdiplus();

  g_toast.title = title;
  g_toast.body = body;
  g_toast.kind = kind;
  g_toast.duration_ms = dur;

  RECT work{};
  SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
  const int x = work.right - kToastW - 20;
  const int y = work.bottom - kToastH - 20;

  HWND hwnd = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      kClassName, L"Witrack", WS_POPUP, x, y, kToastW, kToastH, nullptr,
      nullptr, instance, nullptr);
  if (!hwnd) {
    ReleaseGdiplus();
    return;
  }
  g_toast.hwnd = hwnd;

  HRGN rgn = CreateRoundRectRgn(0, 0, kToastW + 1, kToastH + 1, kRadius * 2,
                                kRadius * 2);
  SetWindowRgn(hwnd, rgn, TRUE);

  const DWORD corner = DWMWCP_ROUND;
  DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner,
                        sizeof(corner));
  const COLORREF border = RGB(71, 85, 105);
  DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &border, sizeof(border));

  BOOL dark = TRUE;
  DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                        sizeof(dark));

  ShowWindow(hwnd, SW_SHOWNOACTIVATE);
  UpdateWindow(hwnd);
  SetTimer(hwnd, kCloseTimerId, dur, nullptr);
}

void ShowDesktopNoticeToastUtf8(const std::string& title,
                                const std::string& body,
                                const std::string& kind,
                                int duration_ms) {
  ShowDesktopNoticeToast(Utf8ToWide(title), Utf8ToWide(body),
                         Utf8ToWide(kind), duration_ms);
}

}  // namespace witrack
