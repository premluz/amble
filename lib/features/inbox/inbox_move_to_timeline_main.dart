// SCAFFOLDING entry point — launches InboxScreen with one seeded unscheduled
// task and immediately opens its detail sheet (via code, not a real tap —
// no tap-injection tool available in this environment), for visual review
// of the move-to-timeline flow (an Inbox item filling in its schedule via
// the existing task detail screen). Not part of the real app. Run with:
//   flutter run -t lib/features/inbox/inbox_move_to_timeline_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../task_detail/task_detail_sheet.dart';
import 'inbox_screen.dart';

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
      if (context != null) {
        showTaskDetailSheet(context, task: widget.task);
      }
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
