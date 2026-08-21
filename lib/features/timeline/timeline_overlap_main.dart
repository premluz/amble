// SCAFFOLDING entry point — seeds deliberately overlapping tasks so the
// side-by-side overlap layout can be verified on a real device. Cascade
// replanning is out of MVP scope (docs/SCOPE.md), so a clash is shown
// rather than auto-resolved. Not part of the real app. Run with:
//   flutter run -t lib/features/timeline/timeline_overlap_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_category.dart';
import '../../shared/providers/task_providers.dart';
import 'timeline_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  final now = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(now.year, now.month, now.day, hour, minute);

  final seedTasks = [
    // No overlap — full width.
    Task.create(
      title: 'Morning run',
      scheduledAt: at(7, 0),
      durationMinutes: 30,
      category: TaskCategory.health,
    ),
    // Two-way clash — should render side by side, half width each.
    Task.create(
      title: 'Deep work',
      scheduledAt: at(9, 0),
      durationMinutes: 90,
      category: TaskCategory.work,
    ),
    Task.create(
      title: 'Standup',
      scheduledAt: at(9, 30),
      durationMinutes: 30,
      category: TaskCategory.admin,
    ),
    // Chained group — 'Last' can reuse the first column once 'Overlap A'
    // has finished, so this needs two columns, not three.
    Task.create(
      title: 'Overlap A',
      scheduledAt: at(13, 0),
      durationMinutes: 60,
      category: TaskCategory.personal,
    ),
    Task.create(
      title: 'Overlap B',
      scheduledAt: at(13, 30),
      durationMinutes: 60,
      category: TaskCategory.health,
    ),
    Task.create(
      title: 'Overlap C',
      scheduledAt: at(14, 0),
      durationMinutes: 60,
      category: TaskCategory.work,
    ),
  ];
  await box.putAll({for (final task in seedTasks) task.id: task});

  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: const Scaffold(body: TimelineScreen()),
      ),
    );
  }
}
