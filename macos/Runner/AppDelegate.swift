import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var activationChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    guard let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }),
          let controller = window.contentViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(
      name: "com.witrack.desktop/window_activation",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "activate" else {
        result(FlutterMethodNotImplemented)
        return
      }
      NSApp.unhide(nil)
      if window.isMiniaturized {
        window.deminiaturize(nil)
      }
      NSApp.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(nil)
      result(nil)
    }
    activationChannel = channel
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
