#include "tracking_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "notice_toast.h"
#include "tracking_engine.h"

namespace witrack {
namespace {

flutter::EncodableMap SnapshotMap(const EngineSnapshot& snap) {
  return flutter::EncodableMap{
      {flutter::EncodableValue("atMs"),
       flutter::EncodableValue(static_cast<int64_t>(snap.at_ms))},
      {flutter::EncodableValue("status"),
       flutter::EncodableValue(TrackingEngine::StatusToString(snap.status))},
      {flutter::EncodableValue("secondsSinceLastInput"),
       flutter::EncodableValue(snap.seconds_since_last_input)},
      {flutter::EncodableValue("isActiveSignal"),
       flutter::EncodableValue(snap.is_active_signal)},
      {flutter::EncodableValue("foregroundApp"),
       flutter::EncodableValue(snap.foreground_app)},
      {flutter::EncodableValue("exeName"),
       flutter::EncodableValue(snap.exe_name)},
  };
}

flutter::EncodableList CapturesList(
    const std::vector<CapturedDisplay>& captures) {
  flutter::EncodableList list;
  for (const auto& capture : captures) {
    std::vector<uint8_t> bytes = capture.png_bytes;
    list.push_back(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("displayIndex"),
         flutter::EncodableValue(capture.display_index)},
        {flutter::EncodableValue("width"),
         flutter::EncodableValue(capture.width)},
        {flutter::EncodableValue("height"),
         flutter::EncodableValue(capture.height)},
        {flutter::EncodableValue("pngBytes"),
         flutter::EncodableValue(std::move(bytes))},
    }));
  }
  return list;
}

class TrackingPluginImpl : public TrackingPlugin {
 public:
  explicit TrackingPluginImpl(flutter::BinaryMessenger* messenger)
      : method_channel_(
            std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                messenger, "com.witrack.desktop/tracking",
                &flutter::StandardMethodCodec::GetInstance())) {
    method_channel_->SetMethodCallHandler(
        [this](const auto& call, auto result) {
          HandleMethod(call, std::move(result));
        });
  }

  ~TrackingPluginImpl() override { engine_.Stop(); }

 private:
  void HandleMethod(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const std::string& method = call.method_name();
    if (method == "start") {
      result->Success(flutter::EncodableValue(engine_.Start()));
    } else if (method == "pause") {
      result->Success(flutter::EncodableValue(engine_.Pause()));
    } else if (method == "resume") {
      result->Success(flutter::EncodableValue(engine_.Resume()));
    } else if (method == "stop") {
      result->Success(flutter::EncodableValue(engine_.Stop()));
    } else if (method == "getStatus") {
      result->Success(flutter::EncodableValue(
          TrackingEngine::StatusToString(engine_.status())));
    } else if (method == "poll") {
      result->Success(flutter::EncodableValue(SnapshotMap(engine_.Poll())));
    } else if (method == "updatePolicies") {
      const auto* args =
          std::get_if<flutter::EncodableMap>(call.arguments());
      int idle = 300;
      bool auto_pause = false;
      if (args) {
        auto idle_it = args->find(flutter::EncodableValue("idleThresholdSeconds"));
        if (idle_it != args->end()) {
          if (const auto* idle32 = std::get_if<int32_t>(&idle_it->second)) {
            idle = *idle32;
          } else if (const auto* idle64 =
                         std::get_if<int64_t>(&idle_it->second)) {
            idle = static_cast<int>(*idle64);
          }
        }
        auto pause_it = args->find(flutter::EncodableValue("autoPauseOnIdle"));
        if (pause_it != args->end()) {
          if (const auto* pause_flag = std::get_if<bool>(&pause_it->second)) {
            auto_pause = *pause_flag;
          }
        }
      }
      engine_.UpdatePolicies(idle, auto_pause);
      result->Success();
    } else if (method == "captureDisplays") {
      result->Success(
          flutter::EncodableValue(CapturesList(engine_.CaptureDisplays())));
    } else if (method == "permissionStatus") {
      result->Success(flutter::EncodableValue(flutter::EncodableMap{
          {flutter::EncodableValue("screenCapture"),
           flutter::EncodableValue("available")},
          {flutter::EncodableValue("accessibility"),
           flutter::EncodableValue("not_required")},
          {flutter::EncodableValue("notes"),
           flutter::EncodableValue(
               "Windows uses desktop capture APIs; protected content may fail.")},
      }));
    } else if (method == "showDesktopNotice") {
      const auto* args =
          std::get_if<flutter::EncodableMap>(call.arguments());
      std::string title = "WorkInsight";
      std::string body;
      std::string kind = "info";
      int duration_ms = 7000;
      if (args) {
        auto title_it = args->find(flutter::EncodableValue("title"));
        if (title_it != args->end()) {
          if (const auto* v = std::get_if<std::string>(&title_it->second)) {
            title = *v;
          }
        }
        auto body_it = args->find(flutter::EncodableValue("body"));
        if (body_it != args->end()) {
          if (const auto* v = std::get_if<std::string>(&body_it->second)) {
            body = *v;
          }
        }
        auto kind_it = args->find(flutter::EncodableValue("kind"));
        if (kind_it != args->end()) {
          if (const auto* v = std::get_if<std::string>(&kind_it->second)) {
            kind = *v;
          }
        }
        auto dur_it = args->find(flutter::EncodableValue("durationMs"));
        if (dur_it != args->end()) {
          if (const auto* v32 = std::get_if<int32_t>(&dur_it->second)) {
            duration_ms = *v32;
          } else if (const auto* v64 = std::get_if<int64_t>(&dur_it->second)) {
            duration_ms = static_cast<int>(*v64);
          }
        }
      }
      ShowDesktopNoticeToastUtf8(title, body, kind, duration_ms);
      result->Success();
    } else {
      result->NotImplemented();
    }
  }

  TrackingEngine engine_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
};

}  // namespace

std::unique_ptr<TrackingPlugin> RegisterTrackingPlugin(
    flutter::BinaryMessenger* messenger) {
  return std::make_unique<TrackingPluginImpl>(messenger);
}

}  // namespace witrack
