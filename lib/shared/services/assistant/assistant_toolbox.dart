import 'assistant_activity.dart';
import 'assistant_backend.dart';
import 'assistant_read_tools.dart';
import 'assistant_tool.dart';
import 'assistant_write_tools.dart';

/// The tools offered to a connected assistant, with the user's permission
/// enforced on every call (not only when the list is shown, because an
/// assistant may call a tool it saw before the permission changed).
class AssistantToolbox {
  AssistantToolbox({
    required AssistantBackend backend,
    required this.activity,
    required this.permission,
  }) : _reads = assistantReadTools(backend),
       _writes = assistantWriteTools(backend, activity);

  final AssistantActivityLog activity;

  /// Read on every call, so a change in Settings applies at once.
  final AssistantPermission Function() permission;
  final List<AssistantTool> _reads;
  final List<AssistantTool> _writes;

  bool get _canWrite => permission() == AssistantPermission.readWrite;

  /// Every tool, whatever the permission. The permission is enforced on
  /// each call instead: Claude reads the tool list once (when the extension
  /// is installed and when it starts) and does not refresh it, so a list
  /// filtered by permission went stale the moment the person changed the
  /// permission in Settings (seen 2026-10-10). A write while read-only gets
  /// a plain refusal saying where to allow changes.
  List<AssistantTool> get available => [..._reads, ..._writes];

  /// Whether [name] is one of Amble's tools at all, whatever the permission.
  bool knows(String name) => [..._reads, ..._writes].any((t) => t.name == name);

  /// Runs [name]. Bad input, unknown tools and refusals come back as error
  /// results the assistant can read; anything else is a real failure and is
  /// rethrown for the caller to report.
  Future<AssistantToolResult> call(String name, AssistantArgs args) async {
    final tool = [..._reads, ..._writes].where((t) => t.name == name);
    if (tool.isEmpty) {
      return AssistantToolResult.error('Amble has no tool called "$name".');
    }
    if (tool.single.writes && !_canWrite) {
      return const AssistantToolResult.error(
        'Amble only lets you see this plan. The person can allow changes in '
        'Amble: Settings › Claude › "See and update my plan".',
      );
    }
    try {
      return await tool.single.run(args);
    } on AssistantToolError catch (error) {
      return AssistantToolResult.error(error.message);
    }
  }
}
