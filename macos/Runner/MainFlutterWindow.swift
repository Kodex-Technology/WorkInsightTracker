import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let trackingPlugin = WitrackTrackingPlugin()

  /// Keep in sync with AppConstants.windowWidth/Height (1180×760).
  private let fixedContentSize = NSSize(width: 1180, height: 760)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Fixed size: no user resize / zoom-to-fill.
    styleMask.remove(.resizable)
    minSize = fixedContentSize
    maxSize = fixedContentSize
    setContentSize(fixedContentSize)
    center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    trackingPlugin.register(with: flutterViewController)

    super.awakeFromNib()
  }
}
