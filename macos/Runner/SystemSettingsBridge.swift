import Cocoa
import FlutterMacOS

/// Opens System Settings at the page Amble needs, for the Dart side's
/// `SystemSettingsService` (channel `com.amble/system_settings`).
final class SystemSettingsBridge {
  private static let channelName = "com.amble/system_settings"
  private static let calendarsPane =
    "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "openCalendarSettings":
        guard let url = URL(string: calendarsPane) else {
          result(false)
          return
        }
        result(NSWorkspace.shared.open(url))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
