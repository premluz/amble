import AppIntents
import Foundation

@available(iOS 16.0, *)
struct AmbleIntentFailure: Error, CustomLocalizedStringResourceConvertible {
  let message: String
  init(_ message: String) { self.message = message }
  var localizedStringResource: LocalizedStringResource { "\(message)" }
}

@available(iOS 16.0, *)
struct AddTaskIntent: AppIntent {
  static var title: LocalizedStringResource = "Add Task"
  static var description = IntentDescription(
    "Add a task using text such as Walk tomorrow at 9am for 30 minutes. Text without a definite time is saved as a note.")
  static var openAppWhenRun = false

  @Parameter(title: "Task text", requestValueDialog: "What task would you like to add?")
  var text: String

  static var parameterSummary: some ParameterSummary { Summary("Add task \(\.$text)") }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let message = try await intentMessage("addTask", ["text": text])
    return .result(dialog: "\(message)")
  }
}

@available(iOS 16.0, *)
struct AddNoteIntent: AppIntent {
  static var title: LocalizedStringResource = "Add Note"
  static var description = IntentDescription("Capture a note without scheduling or parsing its text.")
  static var openAppWhenRun = false

  @Parameter(title: "Note", requestValueDialog: "What would you like the note to say?")
  var text: String

  static var parameterSummary: some ParameterSummary { Summary("Add note \(\.$text)") }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let message = try await intentMessage("addNote", ["text": text])
    return .result(dialog: "\(message)")
  }
}

@available(iOS 16.0, *)
struct AddZoneIntent: AppIntent {
  static var title: LocalizedStringResource = "Add Zone"
  static var description = IntentDescription(
    "Create a non-recurring zone with a daily time window, like the Add Zone form. Overnight windows are not supported.")
  static var openAppWhenRun = false

  @Parameter(title: "Title", requestValueDialog: "What is the zone called?")
  var title: String
  @Parameter(title: "Start time", kind: .time, requestValueDialog: "When does it start?")
  var startTime: DateComponents
  @Parameter(title: "End time", kind: .time, requestValueDialog: "When does it end?")
  var endTime: DateComponents

  static var parameterSummary: some ParameterSummary {
    Summary("Add zone \(\.$title) from \(\.$startTime) to \(\.$endTime)")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let start = try Self.minutes(startTime)
    let rawEnd = try Self.minutes(endTime)
    // Midnight as an end boundary is 24:00, which Zone supports explicitly.
    let end = rawEnd == 0 ? 1440 : rawEnd
    guard end > start else {
      throw AmbleIntentFailure("The end must be after the start on the same day. Please give both times with AM or PM.")
    }
    let message = try await intentMessage("addZone", [
      "title": title, "startMinutes": start, "endMinutes": end])
    return .result(dialog: "\(message)")
  }

  static func minutes(_ components: DateComponents) throws -> Int {
    guard let hour = components.hour, let minute = components.minute,
          (0...23).contains(hour), (0...59).contains(minute),
          components.second == nil || components.second == 0 else {
      throw AmbleIntentFailure("I need a clear time in hours and minutes. Please include AM or PM.")
    }
    return hour * 60 + minute
  }
}

@available(iOS 16.0, *)
struct ReadDaySummaryIntent: AppIntent {
  static var title: LocalizedStringResource = "Read Day Summary"
  static var description = IntentDescription("Read today's scheduled task count and next task.")
  static var openAppWhenRun = false

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let message = try await intentMessage("daySummary")
    return .result(value: message, dialog: "\(message)")
  }
}

@available(iOS 16.0, *)
struct RemoveTaskIntent: AppIntent {
  static var title: LocalizedStringResource = "Remove Task"
  static var description = IntentDescription(
    "Remove one scheduled occurrence from today or the next 13 days. Search by its full title or a few words.")
  static var openAppWhenRun = false

  // EntityStringQuery returns every best match. App Intents resolves this
  // parameter and supplies its native disambiguation BEFORE perform runs.
  @Parameter(title: "Task", requestValueDialog: "Which task would you like to remove?",
    requestDisambiguationDialog: "Which task did you mean?", query: ScheduledTaskQuery())
  var task: ScheduledTaskEntity

  static var parameterSummary: some ParameterSummary { Summary("Remove \(\.$task)") }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let message = try await intentMessage("removeTask", [
      "id": task.id, "title": task.title,
      "scheduledAt": Int64((task.scheduledAt.timeIntervalSince1970 * 1000).rounded())])
    return .result(dialog: "\(message)")
  }
}

@available(iOS 16.0, *)
private func intentMessage(_ method: String, _ arguments: [String: Any] = [:]) async throws -> String {
  guard let message = try await AmbleFlutterHost.shared.request(method, arguments) as? String else {
    throw AmbleIntentFailure("Amble returned an unreadable response. Please check the app.")
  }
  return message
}
