#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

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
  tracking_plugin_ =
      witrack::RegisterTrackingPlugin(flutter_controller_->engine()->messenger());
  deep_link_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.witrack.desktop/deeplink",
          &flutter::StandardMethodCodec::GetInstance());
  deep_link_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "startListening") {
          result->NotImplemented();
          return;
        }

        deep_link_listener_ready_ = true;
        flutter::EncodableList pending;
        pending.reserve(pending_deep_links_.size());
        for (const auto& link : pending_deep_links_) {
          pending.emplace_back(link);
        }
        pending_deep_links_.clear();
        result->Success(flutter::EncodableValue(std::move(pending)));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  deep_link_channel_.reset();
  tracking_plugin_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_COPYDATA: {
      auto* cds = reinterpret_cast<COPYDATASTRUCT*>(lparam);
      if (cds && cds->dwData == 1001 && cds->lpData &&
          cds->cbData >= sizeof(wchar_t) &&
          cds->cbData <= 32767 * sizeof(wchar_t) &&
          cds->cbData % sizeof(wchar_t) == 0) {
        const auto* data = static_cast<const wchar_t*>(cds->lpData);
        const size_t char_count = cds->cbData / sizeof(wchar_t);
        if (data[char_count - 1] != L'\0') {
          return TRUE;
        }
        const std::wstring uri_w(data, char_count - 1);
        const int size_needed = WideCharToMultiByte(
            CP_UTF8, WC_ERR_INVALID_CHARS, uri_w.c_str(),
            static_cast<int>(uri_w.length()), nullptr, 0, nullptr, nullptr);
        if (size_needed <= 0) return TRUE;
        std::string uri(size_needed, '\0');
        if (WideCharToMultiByte(
                CP_UTF8, WC_ERR_INVALID_CHARS, uri_w.c_str(),
                static_cast<int>(uri_w.length()), uri.data(), size_needed,
                nullptr, nullptr) <= 0) {
          return TRUE;
        }

        if (deep_link_listener_ready_ && deep_link_channel_) {
          deep_link_channel_->InvokeMethod(
              "handleDeepLink",
              std::make_unique<flutter::EncodableValue>(std::move(uri)));
        } else {
          pending_deep_links_.push_back(std::move(uri));
        }

        ::SetForegroundWindow(hwnd);
        if (::IsIconic(hwnd)) {
          ::ShowWindow(hwnd, SW_RESTORE);
        }
      }
      return TRUE;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
