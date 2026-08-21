// SCAFFOLDING entry point — same setup as exit_confirm_modal_main.dart, but
// also auto-confirms the exit-confirmation modal with "Schedule this"
// (debugAutoConfirmOutcome: true), landing back on the Inbox with the item
// now scheduled and removed from the unscheduled list. For screenshotting
// the "Schedule this" outcome. Not part of the real app. Run with:
//   flutter run -t lib/features/task_detail/exit_confirm_schedule_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../inbox/inbox_screen.dart';
import 'task_detail_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  final task = Task.captured(title: 'Book dentist appointment');
  await box.put(task.id, task);
  // A second, untouched Inbox item makes the "still in Inbox" vs. "moved to
  // Timeline" outcome visually unambiguous in a screenshot.
  final otherTask = Task.captured(title: 'Read that article Sam sent');
  await box.put(otherTask.id, otherTask);

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
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => TaskDetailForm(
            task: widget.task,
            initialScheduledAt: DateTime.now(),
            debugInitialDurationOverride: 90,
            debugAutoTriggerClose: true,
            debugAutoConfirmOutcome: true,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: const Scaffold(body: InboxScreen()),
      ),
    );
  }
}
