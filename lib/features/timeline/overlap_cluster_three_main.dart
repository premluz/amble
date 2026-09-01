// SCAFFOLDING entry point — seeds ONLY a 3-task cluster, positioned early
// in the day so it's visible without scrolling, for a clean screenshot.
// Not part of the real app. Run with:
//   flutter run -t lib/features/timeline/overlap_cluster_three_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/models/category.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import 'timeline_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final taskBox = await Hive.openBox<Task>(taskBoxName);
  await taskBox.clear();
  // ShowHourLabelsSetting/DisableOverlapClusteringSetting both read this
  // box unconditionally — required even though this scaffold never writes
  // to it, or every provider read throws "Box not found." Cleared, not
  // just opened: a stale on-disk `disableOverlapClustering: true` from an
  // earlier session's screenshot run silently defeated clustering here.
  final preferencesBox = await Hive.openBox<dynamic>(preferencesBoxName);
  await preferencesBox.clear();

  final now = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(now.year, now.month, now.day, hour, minute);

  final seedTasks = [
    Task.create(
      title: 'Overlap A',
      scheduledAt: at(8, 0),
      durationMinutes: 60,
      categoryId: BuiltInCategoryIds.personal,
    ),
    Task.create(
      title: 'Overlap B',
      scheduledAt: at(8, 30),
      durationMinutes: 60,
      categoryId: BuiltInCategoryIds.health,
    ),
    Task.create(
      title: 'Overlap C',
      scheduledAt: at(9, 0),
      durationMinutes: 60,
      categoryId: BuiltInCategoryIds.work,
    ),
  ];
  await taskBox.putAll({for (final task in seedTasks) task.id: task});

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
