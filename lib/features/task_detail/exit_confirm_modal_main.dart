// SCAFFOLDING entry point — launches the task detail form for a captured
// (unscheduled) Inbox item with its duration pre-seeded away from the
// form's own default (via TaskDetailForm.debugInitialDurationOverride —
// no tap-injection tool available in this environment to interactively
// drag the duration slider, see docs/ERROR_LOG.md), then calls the real
// close-button handler (debugAutoTriggerClose) so the exit-confirmation
// modal opens for screenshotting. Not part of the real app. Run with:
//   flutter run -t lib/features/task_detail/exit_confirm_modal_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import 'task_detail_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  final task = Task.captured(title: 'Book dentist appointment');
  await box.put(task.id, task);

  runApp(_PreviewApp(task: task));
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: TaskDetailForm(
          task: task,
          initialScheduledAt: DateTime.now(),
          debugInitialDurationOverride: 90,
          debugAutoTriggerClose: true,
        ),
      ),
    );
  }
}
