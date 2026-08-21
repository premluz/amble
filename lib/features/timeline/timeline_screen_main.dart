// SCAFFOLDING entry point — launches TimelineScreen standalone for visual
// review, wired to a real Hive box seeded with sample tasks so the screen
// exercises the actual provider chain, not hardcoded data. Not part of the
// real app. Run with:
//   flutter run -t lib/features/timeline/timeline_screen_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_category.dart';
import '../../shared/models/task_status.dart';
import '../../shared/providers/task_providers.dart';
import 'timeline_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  final now = DateTime.now();
  final seedTasks = [
    Task(
      id: 'seed-1',
      title: 'Morning run',
      scheduledAt: DateTime(now.year, now.month, now.day, 7, 0),
      durationMinutes: 30,
      category: TaskCategory.health,
    ),
    Task(
      id: 'seed-2',
      title: 'Team standup',
      scheduledAt: DateTime(now.year, now.month, now.day, 9, 0),
      durationMinutes: 15,
      category: TaskCategory.work,
    ),
    Task(
      id: 'seed-3',
      title: 'Deep work: Amble timeline',
      scheduledAt: DateTime(now.year, now.month, now.day, 10, 0),
      durationMinutes: 120,
      category: TaskCategory.work,
    ),
    Task(
      id: 'seed-4',
      title: 'Call mom',
      scheduledAt: DateTime(now.year, now.month, now.day, 13, 0),
      durationMinutes: 20,
      category: TaskCategory.personal,
      status: TaskStatus.skipped,
    ),
    Task(
      id: 'seed-5',
      title: 'Pay rent',
      scheduledAt: DateTime(now.year, now.month, now.day, 17, 0),
      durationMinutes: 10,
      category: TaskCategory.admin,
      status: TaskStatus.completed,
      completedAt: DateTime(now.year, now.month, now.day, 17, 5),
    ),
    Task(
      id: 'seed-6',
      title: 'Dentist appointment',
      scheduledAt: DateTime(now.year, now.month, now.day, 15, 0),
      durationMinutes: 45,
      originalScheduledAt: DateTime(now.year, now.month, now.day, 14, 0),
      status: TaskStatus.rescheduled,
      category: TaskCategory.health,
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
