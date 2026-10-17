import '../../models/category.dart';
import '../../models/external_calendar_event.dart';
import '../../models/task.dart';
import '../../models/zone.dart';
import 'assistant_task_edit.dart';

/// Everything the assistant tools need from the app, behind one interface so
/// the tools stay testable with a fake. The app's implementation reads and
/// writes through the same providers the screens use; nothing here touches
/// storage directly.
abstract interface class AssistantBackend {
  DateTime now();

  /// Scheduled tasks on [day], including series occurrences.
  List<Task> tasksOn(DateTime day);

  /// Imported calendar events overlapping [from]..[to]. Empty when calendar
  /// access is off.
  Future<List<ExternalCalendarEvent>> eventsBetween(DateTime from, DateTime to);

  List<Zone> zonesOn(DateTime day);

  List<Category> categories();

  /// A one-off task or a repeating task's occurrence, by the id the tools
  /// hand out.
  Task? taskById(String id);

  /// Throws [AssistantToolError] with a plain reason when the app refuses
  /// (for example, the trial has ended).
  Future<Task> createTask({
    required String title,
    required DateTime start,
    required int durationMinutes,
    required String categoryId,
    required bool isImportant,
  });

  Future<void> moveTask(Task task, DateTime start);

  /// Applies [edit] the way Amble's own task editor saves it, including
  /// repeating tasks. Returns how to put the plan back (null when that is
  /// not possible). Throws [AssistantToolError] when the app refuses.
  Future<Future<void> Function()?> editTask(Task task, AssistantTaskEdit edit);

  /// Used only to undo an assistant's own addition from the activity list.
  /// Never offered to the assistant as a tool.
  Future<void> removeTask(Task task);
}
