// SCAFFOLDING entry point — launches TimelineScreen standalone, seeded with
// real tasks AND real zones, for visual review of ZoneBackgroundBlock's
// rendering (behind tasks, offset, aligned to the same time scale). Not
// part of the real app. Run with:
//   flutter run -t lib/features/timeline/zone_background_preview_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/zone_providers.dart';
import 'timeline_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();

  final taskBox = await Hive.openBox<Task>(taskBoxName);
  await taskBox.clear();
  final categoryBox = await Hive.openBox<Category>(categoryBoxName);
  await categoryBox.clear();
  final zoneBox = await Hive.openBox<Zone>(zoneBoxName);
  await zoneBox.clear();
  // TimelineScreen reads several Settings-backed providers
  // (preferencesRepositoryProvider and its dependents) even in this
  // scaffold — without this box open, the very first build throws
  // "HiveError: Box not found."
  await Hive.openBox<dynamic>(preferencesBoxName);

  const workCategoryId = 'preview-work';
  const healthCategoryId = 'preview-health';
  await categoryBox.putAll({
    workCategoryId: Category(
      id: workCategoryId,
      name: 'Work',
      colorToken: 8,
      emoji: '💼',
    ),
    healthCategoryId: Category(
      id: healthCategoryId,
      name: 'Health',
      colorToken: 4,
      emoji: '⛑️',
    ),
  });

  final now = DateTime.now();
  final seedTasks = [
    Task.create(
      title: 'Morning run',
      scheduledAt: DateTime(now.year, now.month, now.day, 7, 10),
      durationMinutes: 30,
      categoryId: healthCategoryId,
    ),
    Task.create(
      title: 'Team standup',
      scheduledAt: DateTime(now.year, now.month, now.day, 9, 0),
      durationMinutes: 15,
      categoryId: workCategoryId,
    ),
    Task.create(
      title: 'Deep work: Zone rendering',
      scheduledAt: DateTime(now.year, now.month, now.day, 10, 15),
      durationMinutes: 90,
      categoryId: workCategoryId,
    ),
  ];
  await taskBox.putAll({for (final task in seedTasks) task.id: task});

  // Two zones: one overlapping the morning run + standup, one overlapping
  // the deep-work block — deliberately NOT referenced by any task's
  // zoneId, since Zone rendering on this view is explicitly unconditional
  // (see CONSTITUTION.md's Zone section / this session's own scope).
  await zoneBox.putAll({
    'preview-zone-1': Zone(
      id: 'preview-zone-1',
      title: 'Morning ritual',
      startMinutes: 7 * 60,
      endMinutes: 9 * 60 + 30,
    ),
    'preview-zone-2': Zone(
      id: 'preview-zone-2',
      title: 'Deep work block',
      startMinutes: 10 * 60,
      endMinutes: 12 * 60,
    ),
  });

  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: AmbleTheme.light.colorSurfacePrimary,
          extensions: [AmbleTheme.light],
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AmbleTheme.dark.colorSurfacePrimary,
          extensions: [AmbleTheme.dark],
        ),
        home: const Scaffold(body: TimelineScreen()),
      ),
    );
  }
}
