#ifndef WITRACK_TRACKING_PLUGIN_H_
#define WITRACK_TRACKING_PLUGIN_H_

#include <flutter/binary_messenger.h>

#include <memory>

namespace witrack {

class TrackingPlugin;

std::unique_ptr<TrackingPlugin> RegisterTrackingPlugin(
    flutter::BinaryMessenger* messenger);

class TrackingPlugin {
 public:
  virtual ~TrackingPlugin() = default;
};

}  // namespace witrack

#endif  // WITRACK_TRACKING_PLUGIN_H_
