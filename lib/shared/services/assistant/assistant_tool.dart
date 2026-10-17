/// What an assistant connected to Amble may do. Chosen by the user in
/// Settings › Claude; read-only is the default.
enum AssistantPermission { read, readWrite }

/// Limits and defaults for assistant tools, in one place so the descriptions
/// the assistant reads and the checks the tools run never disagree.
abstract final class AssistantLimits {
  /// The longest range a single question may cover.
  static const maxRangeDays = 31;

  /// Planning hours used when the assistant does not say otherwise.
  static const defaultDayStartMinutes = 7 * 60;
  static const defaultDayEndMinutes = 22 * 60;

  /// Shortest free window `get_day` reports, and the default for
  /// `get_availability`.
  static const dayFreeMinMinutes = 15;
  static const defaultSlotMinutes = 30;

  static const minTaskMinutes = 5;
  static const maxTaskMinutes = 12 * 60;
  static const maxTitleLength = 200;

  /// The loopback port Amble listens on unless it is taken. Above the
  /// registered range commonly used by other tools; a port conflict is
  /// reported in Settings rather than silently moved.
  static const defaultPort = 47213;

  /// Bytes of randomness in the connection secret.
  static const secretBytes = 32;

  /// How many recent assistant actions the activity list keeps.
  static const activityCapacity = 50;
}

/// The outcome of one tool call: structured [data] for the assistant to
/// reason over, and a one-line [summary] a person could read.
class AssistantToolResult {
  const AssistantToolResult({
    required this.summary,
    this.data,
    this.isError = false,
  });

  const AssistantToolResult.error(this.summary) : data = null, isError = true;

  final String summary;
  final Object? data;
  final bool isError;
}

/// A problem the assistant should be told about in plain words (bad input,
/// unknown task, not allowed). Thrown by tools, turned into an error result
/// by the toolbox, never shown as a crash.
class AssistantToolError implements Exception {
  const AssistantToolError(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef AssistantArgs = Map<String, Object?>;

/// One capability offered to an assistant: what it is called, how the
/// assistant should use it, what input it takes (JSON Schema) and whether it
/// changes the user's plan.
class AssistantTool {
  const AssistantTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.run,
    this.writes = false,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final bool writes;
  final Future<AssistantToolResult> Function(AssistantArgs args) run;
}
