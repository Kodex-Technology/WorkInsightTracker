#include "tracking_engine.h"

#include <windows.h>

#include <chrono>
#include <filesystem>
#include <vector>

#include <gdiplus.h>

#pragma comment(lib, "gdiplus.lib")

namespace witrack {
namespace {

std::wstring QueryProcessImage(DWORD pid) {
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) {
    return L"";
  }
  wchar_t buffer[MAX_PATH];
  DWORD size = MAX_PATH;
  std::wstring path;
  if (QueryFullProcessImageNameW(process, 0, buffer, &size)) {
    path.assign(buffer, size);
  }
  CloseHandle(process);
  return path;
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return {};
  }
  int size = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, nullptr, 0,
                                 nullptr, nullptr);
  if (size <= 1) {
    return {};
  }
  std::string out(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, out.data(), size, nullptr,
                      nullptr);
  return out;
}

int GetEncoderClsid(const WCHAR* format, CLSID* clsid) {
  UINT num = 0;
  UINT size = 0;
  Gdiplus::GetImageEncodersSize(&num, &size);
  if (size == 0) {
    return -1;
  }
  std::vector<uint8_t> buffer(size);
  auto* codecs = reinterpret_cast<Gdiplus::ImageCodecInfo*>(buffer.data());
  Gdiplus::GetImageEncoders(num, size, codecs);
  for (UINT i = 0; i < num; ++i) {
    if (wcscmp(codecs[i].MimeType, format) == 0) {
      *clsid = codecs[i].Clsid;
      return static_cast<int>(i);
    }
  }
  return -1;
}

struct MonitorCapture {
  int index;
  RECT rect;
};

BOOL CALLBACK MonitorEnumProc(HMONITOR, HDC, LPRECT rect, LPARAM data) {
  auto* monitors = reinterpret_cast<std::vector<MonitorCapture>*>(data);
  MonitorCapture item;
  item.index = static_cast<int>(monitors->size());
  item.rect = *rect;
  monitors->push_back(item);
  return TRUE;
}

bool CaptureRectToPng(const RECT& rect, std::vector<uint8_t>* out_png,
                      int* width, int* height) {
  const int w = rect.right - rect.left;
  const int h = rect.bottom - rect.top;
  if (w <= 0 || h <= 0) {
    return false;
  }

  HDC screen = GetDC(nullptr);
  HDC mem = CreateCompatibleDC(screen);
  HBITMAP bitmap = CreateCompatibleBitmap(screen, w, h);
  HGDIOBJ old = SelectObject(mem, bitmap);
  BitBlt(mem, 0, 0, w, h, screen, rect.left, rect.top, SRCCOPY | CAPTUREBLT);

  Gdiplus::Bitmap gdi_bitmap(bitmap, nullptr);
  IStream* stream = nullptr;
  if (CreateStreamOnHGlobal(nullptr, TRUE, &stream) != S_OK) {
    SelectObject(mem, old);
    DeleteObject(bitmap);
    DeleteDC(mem);
    ReleaseDC(nullptr, screen);
    return false;
  }

  CLSID png_clsid;
  if (GetEncoderClsid(L"image/png", &png_clsid) < 0) {
    stream->Release();
    SelectObject(mem, old);
    DeleteObject(bitmap);
    DeleteDC(mem);
    ReleaseDC(nullptr, screen);
    return false;
  }

  if (gdi_bitmap.Save(stream, &png_clsid, nullptr) != Gdiplus::Ok) {
    stream->Release();
    SelectObject(mem, old);
    DeleteObject(bitmap);
    DeleteDC(mem);
    ReleaseDC(nullptr, screen);
    return false;
  }

  STATSTG stats{};
  stream->Stat(&stats, STATFLAG_NONAME);
  const ULONG size = static_cast<ULONG>(stats.cbSize.QuadPart);
  out_png->resize(size);
  LARGE_INTEGER zero{};
  stream->Seek(zero, STREAM_SEEK_SET, nullptr);
  ULONG read = 0;
  stream->Read(out_png->data(), size, &read);
  stream->Release();

  *width = w;
  *height = h;

  SelectObject(mem, old);
  DeleteObject(bitmap);
  DeleteDC(mem);
  ReleaseDC(nullptr, screen);
  return read == size;
}

class GdiplusToken {
 public:
  GdiplusToken() {
    Gdiplus::GdiplusStartupInput input;
    Gdiplus::GdiplusStartup(&token_, &input, nullptr);
  }
  ~GdiplusToken() { Gdiplus::GdiplusShutdown(token_); }

 private:
  ULONG_PTR token_ = 0;
};

}  // namespace

TrackingEngine::TrackingEngine() = default;

TrackingEngine::~TrackingEngine() { Stop(); }

bool TrackingEngine::Start() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (running_) {
      return true;
    }
    status_ = EngineStatus::kInitializing;
    running_ = true;
    foreground_app_ = "Unknown";
    foreground_exe_.clear();
    seconds_since_last_input_ = 0;
  }
  worker_ = std::thread([this] { WorkerLoop(); });
  {
    std::lock_guard<std::mutex> lock(mutex_);
    status_ = EngineStatus::kTracking;
  }
  return true;
}

bool TrackingEngine::Pause() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (status_ != EngineStatus::kTracking && status_ != EngineStatus::kIdle) {
    return false;
  }
  status_ = EngineStatus::kPaused;
  return true;
}

bool TrackingEngine::Resume() {
  const int idle_sec = SecondsSinceLastInput();
  int threshold;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    threshold = idle_threshold_sec_;
    if (status_ != EngineStatus::kPaused) {
      return false;
    }
    status_ = idle_sec >= threshold ? EngineStatus::kIdle
                                    : EngineStatus::kTracking;
    seconds_since_last_input_ = idle_sec;
  }
  return true;
}

bool TrackingEngine::Stop() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!running_ && status_ == EngineStatus::kStopped) {
      return true;
    }
    running_ = false;
    status_ = EngineStatus::kStopped;
  }
  if (worker_.joinable()) {
    worker_.join();
  }
  return true;
}

EngineStatus TrackingEngine::status() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return status_;
}

EngineSnapshot TrackingEngine::Poll() const {
  std::lock_guard<std::mutex> lock(mutex_);
  EngineSnapshot snap;
  snap.at_ms = NowMs();
  snap.status = status_;
  snap.seconds_since_last_input = seconds_since_last_input_;
  snap.is_active_signal = seconds_since_last_input_ < 10;
  snap.foreground_app = foreground_app_;
  snap.exe_name = foreground_exe_;
  return snap;
}

void TrackingEngine::UpdatePolicies(int idle_threshold_seconds,
                                    bool auto_pause_on_idle) {
  std::lock_guard<std::mutex> lock(mutex_);
  idle_threshold_sec_ = idle_threshold_seconds > 0 ? idle_threshold_seconds : 300;
  auto_pause_on_idle_ = auto_pause_on_idle;
}

std::vector<CapturedDisplay> TrackingEngine::CaptureDisplays() const {
  GdiplusToken token;
  std::vector<MonitorCapture> monitors;
  EnumDisplayMonitors(nullptr, nullptr, MonitorEnumProc,
                      reinterpret_cast<LPARAM>(&monitors));
  std::vector<CapturedDisplay> captures;
  for (const auto& monitor : monitors) {
    CapturedDisplay item;
    item.display_index = monitor.index;
    if (CaptureRectToPng(monitor.rect, &item.png_bytes, &item.width,
                         &item.height)) {
      captures.push_back(std::move(item));
    }
  }
  return captures;
}

std::string TrackingEngine::StatusToString(EngineStatus status) {
  switch (status) {
    case EngineStatus::kInitializing:
      return "initializing";
    case EngineStatus::kTracking:
      return "tracking";
    case EngineStatus::kPaused:
      return "paused";
    case EngineStatus::kIdle:
      return "idle";
    case EngineStatus::kError:
      return "error";
    case EngineStatus::kStopped:
    default:
      return "stopped";
  }
}

void TrackingEngine::WorkerLoop() {
  while (running_) {
    const int idle_sec = SecondsSinceLastInput();
    std::string app;
    std::string exe;
    ReadForegroundApp(&app, &exe);

    int threshold = 300;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      threshold = idle_threshold_sec_;
      seconds_since_last_input_ = idle_sec;
      if (!app.empty()) {
        foreground_app_ = app;
        foreground_exe_ = exe;
      }

      // Enter Idle after threshold; leave only on fresh activity (not
      // idle_sec < threshold, which can flap around the boundary).
      constexpr int kActiveResumeSec = 10;
      if (status_ == EngineStatus::kTracking && idle_sec >= threshold) {
        status_ = EngineStatus::kIdle;
      } else if (status_ == EngineStatus::kIdle &&
                 idle_sec < kActiveResumeSec) {
        status_ = EngineStatus::kTracking;
      }
    }

    std::this_thread::sleep_for(std::chrono::seconds(1));
  }
}

int TrackingEngine::SecondsSinceLastInput() const {
  LASTINPUTINFO info;
  info.cbSize = sizeof(LASTINPUTINFO);
  if (!GetLastInputInfo(&info)) {
    return 0;
  }
  const DWORD now = GetTickCount();
  const DWORD elapsed_ms = now - info.dwTime;
  return static_cast<int>(elapsed_ms / 1000);
}

void TrackingEngine::ReadForegroundApp(std::string* app_name,
                                       std::string* exe_name) const {
  *app_name = "Unknown";
  exe_name->clear();
  HWND hwnd = GetForegroundWindow();
  if (!hwnd) {
    return;
  }
  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  std::wstring image = QueryProcessImage(pid);
  if (image.empty()) {
    return;
  }
  std::filesystem::path path(image);
  *exe_name = WideToUtf8(path.filename().wstring());
  *app_name = WideToUtf8(path.stem().wstring());
  if (app_name->empty()) {
    *app_name = "Unknown";
  }
}

int64_t TrackingEngine::NowMs() const {
  using namespace std::chrono;
  return duration_cast<milliseconds>(system_clock::now().time_since_epoch())
      .count();
}

}  // namespace witrack
