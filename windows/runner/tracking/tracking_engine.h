#ifndef WITRACK_TRACKING_ENGINE_H_
#define WITRACK_TRACKING_ENGINE_H_

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace witrack {

enum class EngineStatus {
  kStopped,
  kInitializing,
  kTracking,
  kPaused,
  kIdle,
  kError,
};

struct EngineSnapshot {
  int64_t at_ms = 0;
  EngineStatus status = EngineStatus::kStopped;
  int seconds_since_last_input = 0;
  bool is_active_signal = false;
  std::string foreground_app;
  std::string exe_name;
};

struct CapturedDisplay {
  int display_index = 0;
  int width = 0;
  int height = 0;
  std::vector<uint8_t> png_bytes;
};

class TrackingEngine {
 public:
  TrackingEngine();
  ~TrackingEngine();

  TrackingEngine(const TrackingEngine&) = delete;
  TrackingEngine& operator=(const TrackingEngine&) = delete;

  bool Start();
  bool Pause();
  bool Resume();
  bool Stop();
  EngineStatus status() const;
  EngineSnapshot Poll() const;
  void UpdatePolicies(int idle_threshold_seconds, bool auto_pause_on_idle);
  std::vector<CapturedDisplay> CaptureDisplays() const;

  static std::string StatusToString(EngineStatus status);

 private:
  void WorkerLoop();
  int SecondsSinceLastInput() const;
  void ReadForegroundApp(std::string* app_name, std::string* exe_name) const;
  int64_t NowMs() const;

  mutable std::mutex mutex_;
  std::atomic<bool> running_{false};
  EngineStatus status_ = EngineStatus::kStopped;
  std::thread worker_;

  std::string foreground_app_ = "Unknown";
  std::string foreground_exe_;
  int seconds_since_last_input_ = 0;
  int idle_threshold_sec_ = 300;
  bool auto_pause_on_idle_ = false;
};

}  // namespace witrack

#endif  // WITRACK_TRACKING_ENGINE_H_
