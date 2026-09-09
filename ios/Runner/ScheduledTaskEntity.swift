import AppIntents
import Foundation

@available(iOS 16.0, *)
struct ScheduledTaskEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Scheduled task"
  static var defaultQuery = ScheduledTaskQuery()
  let id: String
  let title: String
  let scheduledAt: Date

  var displayRepresentation: DisplayRepresentation {
    let date = scheduledAt.formatted(date: .abbreviated, time: .shortened)
    return DisplayRepresentation(title: "\(title)", subtitle: "\(date)")
  }
}

@available(iOS 16.0, *)
struct ScheduledTaskQuery: EntityStringQuery {
  func entities(for identifiers: [String]) async throws -> [ScheduledTaskEntity] {
    try await fetch(["ids": identifiers])
  }

  func entities(matching string: String) async throws -> [ScheduledTaskEntity] {
    let results = try await fetch(["query": string])
    guard !results.isEmpty else {
      throw AmbleIntentFailure("No scheduled task matches that title in the next 14 days.")
    }
    return results
  }

  func suggestedEntities() async throws -> [ScheduledTaskEntity] {
    try await fetch([:])
  }

  private func fetch(_ arguments: [String: Any]) async throws -> [ScheduledTaskEntity] {
    guard let rows = try await AmbleFlutterHost.shared.request("findTasks", arguments)
      as? [[String: Any]] else {
      throw AmbleIntentFailure("Amble could not read the task list.")
    }
    return try rows.map { row in
      guard let id = row["id"] as? String, let title = row["title"] as? String,
            let milliseconds = row["scheduledAt"] as? NSNumber else {
        throw AmbleIntentFailure("Amble could not read a scheduled task.")
      }
      return ScheduledTaskEntity(id: id, title: title,
        scheduledAt: Date(timeIntervalSince1970: milliseconds.doubleValue / 1000))
    }
  }
}
