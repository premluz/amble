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
import '../../shared/models/category.dart';
import '../../shared/providers/task_providers.dart';
import 'task_detail_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  final now = DateTime.now();
  // A scheduled task, not a captured one — the edit-schedule modal (what
  // this scaffold now exercises) only ever opens on an already-scheduled
  // task, matching the real "Edit time and duration" action-sheet entry
  // point.
  final task = Task.create(
    title: 'Book dentist appointment',
    scheduledAt: DateTime(now.year, now.month, now.day, now.hour),
    durationMinutes: 30,
    categoryId: BuiltInCategoryIds.personal,
  );
  await box.put(task.id, task);

  runApp(_PreviewApp(task: task));
}

class _PreviewApp extends StatefulWidget {
  const _PreviewApp({required this.task});

  final Task task;

  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context == null) return;
      showEditScheduleSheet(
        context,
        task: widget.task,
        debugInitialDurationOverride: 90,
        debugAutoTriggerClose: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
  }
}
