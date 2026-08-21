// SCAFFOLDING entry point — reproduces "tap Continue while editing does
// nothing" bug report. Seeds a real scheduled task, opens it in edit mode
// with a changed duration (debugInitialDurationOverride), then calls the
// real _save() handler directly (debugAutoTriggerSave), exercising the
// exact Continue-button code path without a tap-injection tool (unavailable
// on iOS Simulator — see docs/ERROR_LOG.md). Screen shows whether the sheet
// closed and the change persisted. Not part of the real app. Run with:
//   flutter run -t lib/features/task_detail/edit_save_repro_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_category.dart';
import '../../shared/providers/notification_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../timeline/timeline_screen.dart';
import 'task_detail_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  final now = DateTime.now();
  final task = Task.create(
    title: 'Deep work',
    scheduledAt: DateTime(now.year, now.month, now.day, 10, 0),
    durationMinutes: 60,
    category: TaskCategory.work,
  );
  await box.put(task.id, task);

  final container = ProviderContainer();
  // Mirrors main.dart's init sequence — NotificationService.initialize()
  // sets up the timezone database that syncForTask depends on; skipping
  // this (as an earlier version of this scaffold did) throws a
  // LateInitializationError from inside _save's notification sync, which
  // looks identical to "Continue does nothing" but is a scaffold gap, not
  // a real app bug (main.dart always initializes before runApp).
  await container
      .read(notificationServiceProvider)
      .initialize(onNotificationTap: (_) {});

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _PreviewApp(task: task),
    ),
  );
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
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => TaskDetailForm(
            task: widget.task,
            initialScheduledAt: DateTime.now(),
            debugInitialDurationOverride: 90,
            debugAutoTriggerSave: true,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: const Scaffold(body: TimelineScreen()),
    );
  }
}
