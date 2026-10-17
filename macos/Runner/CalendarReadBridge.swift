import Cocoa
import EventKit
import FlutterMacOS

/// Read-only access to the Mac's Calendar (EventKit) for Amble's external
/// event display. `device_calendar` ships no macOS implementation, so this
/// answers the same method channel it uses on iOS and Android, with the same
/// JSON shapes, and the Dart side needs no macOS branch.
///
/// Only the four read methods are implemented. Anything else (create,
/// update, delete, the iOS event modal) falls through to
/// `FlutterMethodNotImplemented`, so Amble never writes to the user's
/// calendars from the desktop app, matching CONSTITUTION.md's read-only
/// rule for Feature 1.
///
/// Every calendar account the user has added in System Settings > Internet
/// Accounts (iCloud, Google, Exchange, ...) appears in EventKit, so a Google
/// account added there is included with no Google sign-in of our own.
final class CalendarReadBridge {
  private static let channelName = "plugins.builttoroam.com/device_calendar"
  private static let changesChannelName = "com.amble/calendar_changes"
  private let store = EKEventStore()
  private var changeObserver: NSObjectProtocol?

  static func register(with messenger: FlutterBinaryMessenger) {
    let bridge = CalendarReadBridge()
    bridge.announceChanges(on: messenger)
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
  }

  /// Tells Dart whenever the Calendar database changes (an event edited in
  /// Calendar.app, or a synced account delivering new ones), so open views
  /// re-read without waiting for the periodic refresh. The notification
  /// carries no detail; Dart just re-reads what it displays.
  private func announceChanges(on messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: CalendarReadBridge.changesChannelName, binaryMessenger: messenger)
    changeObserver = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged, object: store, queue: .main
    ) { _ in
      channel.invokeMethod("changed", arguments: nil)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasPermissions":
      result(hasAccess())
    case "requestPermissions":
      requestAccess(result: result)
    case "retrieveCalendars":
      guardAccess(result) { self.retrieveCalendars(result) }
    case "retrieveEvents":
      guardAccess(result) { self.retrieveEvents(call, result) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Permission

  private func hasAccess() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(macOS 14.0, *) {
      return status == .fullAccess
    }
    return status == .authorized
  }

  private func requestAccess(result: @escaping FlutterResult) {
    if hasAccess() {
      result(true)
      return
    }
    let completion: EKEventStoreRequestAccessCompletionHandler = { granted, _ in
      DispatchQueue.main.async { result(granted) }
    }
    if #available(macOS 14.0, *) {
      store.requestFullAccessToEvents(completion: completion)
    } else {
      store.requestAccess(to: .event, completion: completion)
    }
  }

  private func guardAccess(_ result: @escaping FlutterResult, _ action: () -> Void) {
    guard hasAccess() else {
      result(
        FlutterError(
          code: "ACCESS_DENIED",
          message: "Calendar access has not been granted.",
          details: nil))
      return
    }
    action()
  }

  // MARK: Reads

  private func retrieveCalendars(_ result: @escaping FlutterResult) {
    let defaultId = store.defaultCalendarForNewEvents?.calendarIdentifier
    let calendars: [[String: Any]] = store.calendars(for: .event).map { calendar in
      [
        "id": calendar.calendarIdentifier,
        "name": calendar.title,
        "isReadOnly": !calendar.allowsContentModifications,
        "isDefault": calendar.calendarIdentifier == defaultId,
        "color": Self.argb(calendar.cgColor),
        "accountName": calendar.source.title,
        "accountType": Self.accountType(calendar.source.sourceType),
      ]
    }
    encode(calendars, result)
  }

  private func retrieveEvents(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let calendarId = arguments["calendarId"] as? String,
      let startMs = (arguments["startDate"] as? NSNumber)?.doubleValue,
      let endMs = (arguments["endDate"] as? NSNumber)?.doubleValue,
      let calendar = store.calendar(withIdentifier: calendarId)
    else {
      encode([[String: Any]](), result)
      return
    }
    let predicate = store.predicateForEvents(
      withStart: Date(timeIntervalSince1970: startMs / 1000),
      end: Date(timeIntervalSince1970: endMs / 1000),
      calendars: [calendar])
    let events: [[String: Any]] = store.events(matching: predicate).map { event in
      var json: [String: Any] = [
        "eventId": event.eventIdentifier ?? "",
        "calendarId": calendarId,
        "eventTitle": event.title ?? "",
        "eventStartDate": Int64(event.startDate.timeIntervalSince1970 * 1000),
        "eventEndDate": Int64(event.endDate.timeIntervalSince1970 * 1000),
        "eventAllDay": event.isAllDay,
      ]
      if let zone = event.timeZone { json["eventStartTimeZone"] = zone.identifier }
      if let notes = event.notes { json["eventDescription"] = notes }
      if let location = event.location { json["eventLocation"] = location }
      return json
    }
    encode(events, result)
  }

  // MARK: Encoding

  private func encode(_ value: [[String: Any]], _ result: FlutterResult) {
    do {
      let data = try JSONSerialization.data(withJSONObject: value)
      result(String(data: data, encoding: .utf8))
    } catch {
      result(
        FlutterError(
          code: "ENCODING_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  /// 0xAARRGGBB, the integer `device_calendar` expects for a calendar colour.
  private static func argb(_ cgColor: CGColor) -> Int {
    guard
      let color = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB)
    else { return 0xFF00_0000 }
    func channel(_ value: CGFloat) -> Int { Int((value * 255).rounded()) }
    return (0xFF << 24) | (channel(color.redComponent) << 16)
      | (channel(color.greenComponent) << 8) | channel(color.blueComponent)
  }

  private static func accountType(_ type: EKSourceType) -> String {
    switch type {
    case .local: return "Local"
    case .exchange: return "Exchange"
    case .calDAV: return "CalDAV"
    case .mobileMe: return "MobileMe"
    case .subscribed: return "Subscribed"
    case .birthdays: return "Birthdays"
    @unknown default: return "Unknown"
    }
  }
}
