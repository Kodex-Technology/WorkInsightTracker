import Cocoa
import FlutterMacOS
import CoreGraphics
import ApplicationServices

/// Native macOS tracking adapter matching `com.witrack.desktop/tracking`.
final class WitrackTrackingPlugin: NSObject {
  private let engine = MacTrackingEngine()
  private var channel: FlutterMethodChannel?

  func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.witrack.desktop/tracking",
      binaryMessenger: controller.engine.binaryMessenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      result(engine.start())
    case "pause":
      result(engine.pause())
    case "resume":
      result(engine.resume())
    case "stop":
      result(engine.stop())
    case "getStatus":
      result(engine.statusString())
    case "poll":
      result(engine.poll())
    case "updatePolicies":
      if let args = call.arguments as? [String: Any] {
        let idle = args["idleThresholdSeconds"] as? Int ?? 300
        let autoPause = args["autoPauseOnIdle"] as? Bool ?? false
        engine.updatePolicies(idleThresholdSeconds: idle, autoPauseOnIdle: autoPause)
      }
      result(nil)
    case "captureDisplays":
      result(engine.captureDisplays())
    case "permissionStatus":
      result(engine.permissionStatus())
    case "requestPermissions":
      let args = call.arguments as? [String: Any] ?? [:]
      let prompt = args["prompt"] as? Bool ?? false
      result(engine.requestPermissions(prompt: prompt))
    case "showDesktopNotice":
      let args = call.arguments as? [String: Any] ?? [:]
      let title = args["title"] as? String ?? "Witrack"
      let body = args["body"] as? String ?? ""
      let kind = args["kind"] as? String ?? "info"
      let durationMs = args["durationMs"] as? Int ?? 7000
      WitrackNoticeToast.show(title: title, body: body, kind: kind, durationMs: durationMs)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Compact floating notice — brand eyebrow, icon badge, close, auto-dismiss.
enum WitrackNoticeToast {
  private static var panel: NSPanel?
  private static var hideWork: DispatchWorkItem?
  private static var currentKind: String?

  static func show(title: String, body: String, kind: String, durationMs: Int) {
    DispatchQueue.main.async {
      let total = max(durationMs, 2000)

      // Same kind already visible — reset auto-close only (no recreate flicker).
      if panel != nil, currentKind == kind {
        hideWork?.cancel()
        let work = DispatchWorkItem { dismiss() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(total), execute: work)
        return
      }

      hideWork?.cancel()
      panel?.close()

      let width: CGFloat = 360
      let height: CGFloat = 92
      let screen = NSScreen.main?.visibleFrame ?? .zero
      let x = screen.maxX - width - 20
      let y = screen.minY + 20
      let accent = kind == "idle"
        ? NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.04, alpha: 1)
        : NSColor(calibratedRed: 0.18, green: 0.83, blue: 0.75, alpha: 1)

      let panel = NSPanel(
        contentRect: NSRect(x: x, y: y, width: width, height: height),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
      )
      panel.level = .floating
      panel.isFloatingPanel = true
      panel.hidesOnDeactivate = false
      panel.becomesKeyOnlyIfNeeded = true
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hasShadow = true

      let root = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
      root.wantsLayer = true
      root.layer?.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.15, alpha: 0.98).cgColor
      root.layer?.cornerRadius = 14
      root.layer?.borderWidth = 1
      root.layer?.borderColor = NSColor(calibratedRed: 0.28, green: 0.33, blue: 0.41, alpha: 0.55).cgColor

      let icon = NSView(frame: NSRect(x: 14, y: (height - 40) / 2, width: 40, height: 40))
      icon.wantsLayer = true
      icon.layer?.cornerRadius = 20
      icon.layer?.backgroundColor = accent.withAlphaComponent(0.18).cgColor
      root.addSubview(icon)

      let brand = NSTextField(labelWithString: "WORKINSIGHT")
      brand.font = .systemFont(ofSize: 9, weight: .bold)
      brand.textColor = NSColor(calibratedRed: 0.18, green: 0.83, blue: 0.75, alpha: 1)
      brand.frame = NSRect(x: 66, y: height - 28, width: 200, height: 12)
      root.addSubview(brand)

      let titleField = NSTextField(labelWithString: title)
      titleField.font = .systemFont(ofSize: 13, weight: .semibold)
      titleField.textColor = .white
      titleField.frame = NSRect(x: 66, y: height - 48, width: width - 110, height: 18)
      root.addSubview(titleField)

      let bodyField = NSTextField(labelWithString: body)
      bodyField.font = .systemFont(ofSize: 11)
      bodyField.textColor = NSColor(calibratedWhite: 0.62, alpha: 1)
      bodyField.lineBreakMode = .byTruncatingTail
      bodyField.frame = NSRect(x: 66, y: 16, width: width - 110, height: 16)
      root.addSubview(bodyField)

      let close = NSButton(frame: NSRect(x: width - 36, y: height - 34, width: 22, height: 22))
      close.title = ""
      close.bezelStyle = .inline
      close.isBordered = false
      close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
      close.contentTintColor = NSColor(calibratedWhite: 0.65, alpha: 1)
      close.target = ToastCloseTarget.shared
      close.action = #selector(ToastCloseTarget.close)
      root.addSubview(close)

      let bar = NSView(frame: NSRect(x: 1, y: 1, width: width - 2, height: 2))
      bar.wantsLayer = true
      bar.layer?.backgroundColor = accent.cgColor
      root.addSubview(bar)

      panel.contentView = root
      panel.orderFrontRegardless()
      self.panel = panel
      self.currentKind = kind

      let work = DispatchWorkItem { dismiss() }
      hideWork = work
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(total), execute: work)
    }
  }

  static func dismiss() {
    hideWork?.cancel()
    panel?.close()
    panel = nil
    currentKind = nil
  }
}

private final class ToastCloseTarget: NSObject {
  static let shared = ToastCloseTarget()
  @objc func close() { WitrackNoticeToast.dismiss() }
}

private final class MacTrackingEngine {
  private enum Status: String {
    case stopped, initializing, tracking, paused, idle, error
  }

  private let lock = NSLock()
  private var running = false
  private var status: Status = .stopped
  private var timer: Timer?
  private var foregroundApp = "Unknown"
  private var foregroundExe = ""
  private var secondsSinceLastInput = 0
  private var idleThresholdSeconds = 300
  private var autoPauseOnIdle = false

  func start() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    if running { return true }
    running = true
    status = .tracking
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        self?.tick()
      }
    }
    return true
  }

  func pause() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard status == .tracking || status == .idle else { return false }
    status = .paused
    return true
  }

  func resume() -> Bool {
    let idle = currentIdleSeconds()
    lock.lock()
    defer { lock.unlock() }
    guard status == .paused else { return false }
    status = idle >= idleThresholdSeconds ? .idle : .tracking
    secondsSinceLastInput = idle
    return true
  }

  func stop() -> Bool {
    lock.lock()
    running = false
    status = .stopped
    lock.unlock()
    DispatchQueue.main.async {
      self.timer?.invalidate()
      self.timer = nil
    }
    return true
  }

  func statusString() -> String {
    lock.lock()
    defer { lock.unlock() }
    return status.rawValue
  }

  func updatePolicies(idleThresholdSeconds: Int, autoPauseOnIdle: Bool) {
    lock.lock()
    self.idleThresholdSeconds = max(1, idleThresholdSeconds)
    self.autoPauseOnIdle = autoPauseOnIdle
    lock.unlock()
  }

  func poll() -> [String: Any] {
    lock.lock()
    defer { lock.unlock() }
    return [
      "atMs": Int(Date().timeIntervalSince1970 * 1000),
      "status": status.rawValue,
      "secondsSinceLastInput": secondsSinceLastInput,
      "isActiveSignal": secondsSinceLastInput < 10,
      "foregroundApp": foregroundApp,
      "exeName": foregroundExe,
    ]
  }

  func permissionStatus() -> [String: Any] {
    let screen: String
    if #available(macOS 10.15, *) {
      // CGPreflightScreenCaptureAccess is available on newer macOS.
      if CGPreflightScreenCaptureAccess() {
        screen = "granted"
      } else {
        screen = "denied_or_not_determined"
      }
    } else {
      screen = "unknown"
    }
    return [
      "screenCapture": screen,
      "accessibility": AXIsProcessTrusted() ? "granted" : "not_required_or_denied",
      "notes": "Screen Recording is required for screenshots. Idle uses CGEventSource.",
    ]
  }

  func requestPermissions(prompt: Bool) -> [String: Any] {
    if prompt {
      if #available(macOS 10.15, *) {
        if !CGPreflightScreenCaptureAccess() {
          _ = CGRequestScreenCaptureAccess()
        }
      }
      let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
      _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    return permissionStatus()
  }

  func captureDisplays() -> [[String: Any]] {
    if #available(macOS 10.15, *) {
      if !CGPreflightScreenCaptureAccess() {
        _ = CGRequestScreenCaptureAccess()
      }
    }

    var results: [[String: Any]] = []
    let screens = NSScreen.screens
    for (index, screen) in screens.enumerated() {
      let rect = screen.frame
      guard let cgImage = CGWindowListCreateImage(
        rect,
        .optionOnScreenOnly,
        kCGNullWindowID,
        [.bestResolution, .boundsIgnoreFraming]
      ) else {
        continue
      }
      let rep = NSBitmapImageRep(cgImage: cgImage)
      guard let png = rep.representation(using: .png, properties: [:]) else {
        continue
      }
      results.append([
        "displayIndex": index,
        "width": cgImage.width,
        "height": cgImage.height,
        "pngBytes": FlutterStandardTypedData(bytes: png),
      ])
    }
    return results
  }

  private func tick() {
    let idle = currentIdleSeconds()
    let app = currentForegroundApp()
    lock.lock()
    secondsSinceLastInput = idle
    foregroundApp = app.name
    foregroundExe = app.bundle
    if status == .tracking && idle >= idleThresholdSeconds {
      status = .idle
    } else if status == .idle && idle < 10 {
      status = .tracking
    }
    lock.unlock()
  }

  private func currentIdleSeconds() -> Int {
    // kCGAnyInputEventType is represented as UInt32.max.
    guard let anyInputEventType = CGEventType(rawValue: UInt32.max) else {
      return 0
    }
    let idle = CGEventSource.secondsSinceLastEventType(
      .combinedSessionState,
      eventType: anyInputEventType
    )
    if idle.isInfinite || idle.isNaN {
      return 0
    }
    return Int(idle)
  }

  private func currentForegroundApp() -> (name: String, bundle: String) {
    if let app = NSWorkspace.shared.frontmostApplication {
      return (
        app.localizedName ?? app.bundleIdentifier ?? "Unknown",
        app.bundleIdentifier ?? ""
      )
    }
    return ("Unknown", "")
  }
}
