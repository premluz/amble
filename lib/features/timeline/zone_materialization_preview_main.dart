// SCAFFOLDING entry point — launches TimelineScreen standalone with a real
// recurring Zone materialized via ZoneList.createZone (the actual provider
// write path, not raw Hive seeding), for visual review of the Zone
// materialization session (see docs/DECISIONS.md). Not part of the real
// app. Run with:
//   flutter run -t lib/features/timeline/zone_materialization_preview_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/category.dart';
import '../../shared/models/recurrence_frequency.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/models/task.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/category_providers.dart';
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

  const workCategoryId = 'preview-work';
  await categoryBox.put(
    workCategoryId,
    Category(id: workCategoryId, name: 'Work', colorToken: 8, emoji: '💼'),
  );

  final container = ProviderContainer();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // A real recurring series, created through the actual provider path
  // (ZoneList.createZone) so this preview exercises the same
  // materialization code (zone_recurrence_generator.dart) the app itself
  // runs, not a hand-seeded imitation of its output.
  await container
      .read(zoneListProvider.notifier)
      .createZone(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
        anchorDateForRecurrence: today,
      );

  container.dispose();

  runApp(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: const Scaffold(
          body: TimelineScreen(mode: TimelineDisplayMode.zone),
        ),
      ),
    ),
  );
}
