import AppIntents

@available(iOS 16.0, *)
struct AmbleShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(intent: AddTaskIntent(), phrases: [
      "Add a task in \(.applicationName)", "Add a task with \(.applicationName)"
    ], shortTitle: "Add Task", systemImageName: "plus.circle")
    AppShortcut(intent: AddNoteIntent(), phrases: [
      "Add a note in \(.applicationName)", "Take a note with \(.applicationName)"
    ], shortTitle: "Add Note", systemImageName: "note.text")
    AppShortcut(intent: AddZoneIntent(), phrases: [
      "Add a zone in \(.applicationName)"
    ], shortTitle: "Add Zone", systemImageName: "rectangle.badge.plus")
    AppShortcut(intent: ReadDaySummaryIntent(), phrases: [
      "Read my day in \(.applicationName)", "Read my day summary in \(.applicationName)"
    ], shortTitle: "Day Summary", systemImageName: "calendar")
    AppShortcut(intent: RemoveTaskIntent(), phrases: [
      "Remove a task in \(.applicationName)", "Remove \(\.$task) in \(.applicationName)"
    ], shortTitle: "Remove Task", systemImageName: "trash")
  }
}
