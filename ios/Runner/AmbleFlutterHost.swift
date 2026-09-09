import Flutter
import UIKit
import flutter_local_notifications

/// One engine for both scene-less App Intents and the visible app. A second
/// Hive engine would have its own stale in-memory cache and competing writer.
@MainActor
final class AmbleFlutterHost {
  static let shared = AmbleFlutterHost()
  private(set) lazy var engine = FlutterEngine(
    name: "amble.shared", project: nil, allowHeadlessExecution: true)
  private var started = false
  private var ready = false
  private var channel: FlutterMethodChannel?

  @discardableResult
  func start() -> Bool {
    if started { return true }
    guard engine.run() else { return false }
    started = true
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engine)
    let channel = FlutterMethodChannel(
      name: "com.amble/app_intents", binaryMessenger: engine.binaryMessenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "ready":
        self?.ready = true
        result(nil)
      case "isForeground":
        result(UIApplication.shared.applicationState == .active)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return true
  }

  @available(iOS 16.0, *)
  func request(_ method: String, _ arguments: [String: Any] = [:]) async throws -> Any {
    guard start() else { throw AmbleIntentFailure("Amble could not start. Please open the app.") }
    let deadline = Date().addingTimeInterval(15)
    while !ready {
      try Task.checkCancellation()
      guard Date() < deadline else {
        // Nothing dispatched: a late ready signal must not perform this request.
        throw AmbleIntentFailure("Amble is not ready. Please open the app and try again.")
      }
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    try Task.checkCancellation()
    guard let channel else { throw AmbleIntentFailure("Amble is not available.") }
    return try await withCheckedThrowingContinuation { continuation in
      var finished = false
      let timeout = DispatchWorkItem {
        guard !finished else { return }
        finished = true
        // Never retry a write after a lost reply: it may already have committed.
        continuation.resume(throwing: AmbleIntentFailure(
          "Amble could not confirm completion. Check the app before trying again."))
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: timeout)
      channel.invokeMethod(method, arguments: arguments) { value in
        guard !finished else { return }
        finished = true
        timeout.cancel()
        if let error = value as? FlutterError {
          continuation.resume(throwing: AmbleIntentFailure(
            error.message ?? "Amble could not complete this action."))
        } else if let value, !(value is NSObject && (value as AnyObject) === FlutterMethodNotImplemented) {
          continuation.resume(returning: value)
        } else {
          continuation.resume(throwing: AmbleIntentFailure("This Amble action is not available."))
        }
      }
    }
  }
}
