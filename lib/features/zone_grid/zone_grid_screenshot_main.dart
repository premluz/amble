// SCAFFOLDING entry point — launches ZoneGridScreen standalone with real
// data seeded through the actual provider paths (ZoneList.createZone), for
// on-device screenshot verification of the Weekly Zone Authoring Grid
// session (see docs/DECISIONS.md's 2026-09-13 entry). Not part of the real
// app. Run with:
//   flutter run -t lib/features/zone_grid/zone_grid_screenshot_main.dart
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
import 'zone_grid_screen.dart';

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
  // This week's own Monday — same anchor `ZoneGridScreen` itself defaults
  // to, so the seeded zones are guaranteed to land inside the visible week
  // rather than depending on which day this happens to be run on.
  final monday = today.subtract(Duration(days: today.weekday - 1));

  final zoneList = container.read(zoneListProvider.notifier);
  final zoneRepository = container.read(zoneRepositoryProvider);

  // A recurring series, through the REAL provider path (ZoneList.createZone)
  // — the same shape the "Recurring" fixtures in zone_grid_screen_test.dart
  // use. Anchored on Monday so it materializes across the WHOLE visible
  // week (this is what the "affect future instances" toggle screenshot
  // needs — select one of these instances to make the toggle appear).
  await zoneList.createZone(
    title: 'Morning ritual',
    startMinutes: 7 * 60,
    endMinutes: 8 * 60,
    recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
    anchorDateForRecurrence: monday,
  );

  // A handful of GENUINELY single-day zones on different days, at
  // different times, so the "multiple zones across several days"
  // screenshot shows real day-to-day variation — the actual point of this
  // screen per the work order.
  //
  // NOT via `ZoneList.createZone` — that method deliberately forces
  // `anchorDate: null` whenever `recurrenceRule` is null (a non-recurring
  // zone is dateless by design per CONSTITUTION.md: "applies to every
  // day it exists on"). Writing directly through the repository instead,
  // since the MODEL itself has no objection to a non-recurring row
  // carrying a real `anchorDate` — only that one convenience constructor's
  // own "non-recurring implies dateless" default does. This is the exact
  // gap this scaffold is here to surface, not a workaround for it: there
  // is genuinely no first-class "just this one day" zone-creation path
  // yet, only "every day" (anchorDate: null) or "this whole recurring
  // series" (ZoneList.createZone with a rule).
  Future<void> seedSingleDayZone({
    required String title,
    required DateTime day,
    required int start,
    required int end,
  }) => zoneRepository.save(
    Zone.create(title: title, startMinutes: start, endMinutes: end)
      ..anchorDate = day,
  );

  await seedSingleDayZone(
    title: 'Deep work',
    day: monday,
    start: 9 * 60,
    end: 11 * 60,
  );
  await seedSingleDayZone(
    title: 'Gym',
    day: monday.add(const Duration(days: 1)),
    start: 17 * 60 + 30,
    end: 18 * 60 + 30,
  );
  await seedSingleDayZone(
    title: 'Client calls',
    day: monday.add(const Duration(days: 2)),
    start: 13 * 60,
    end: 15 * 60,
  );
  await seedSingleDayZone(
    title: 'Long walk',
    day: monday.add(const Duration(days: 3)),
    start: 16 * 60,
    end: 17 * 60,
  );
  await seedSingleDayZone(
    title: 'Errands',
    day: monday.add(const Duration(days: 4)),
    start: 10 * 60,
    end: 12 * 60,
  );

  container.dispose();

  runApp(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: const ZoneGridScreen(),
      ),
    ),
  );
}
