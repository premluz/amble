// SCAFFOLDING entry point — launches TimelineScreen standalone with the
// Zone view toggle already on, seeded with a mix of explicit-zoneId,
// computed-fallback, and genuinely unzoned tasks, for visual review of
// ZoneContainerBlock / ZoneDayTimeline. Not part of the real app. Run
// with:
//   flutter run -t lib/features/timeline/zone_view_preview_main.dart
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
import '../../shared/repositories/preferences_repository.dart';
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
  final preferencesBox = await Hive.openBox<dynamic>(preferencesBoxName);
  // Pre-set so the Zone view renders immediately on launch, without
  // needing to visit Settings first.
  await preferencesBox.put(PreferenceKeys.zoneViewEnabled, true);

  const workCategoryId = 'preview-work';
  const healthCategoryId = 'preview-health';
  const personalCategoryId = 'preview-personal';
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
    personalCategoryId: Category(
      id: personalCategoryId,
      name: 'Personal',
      colorToken: 2,
      emoji: '🏠',
    ),
  });

  final now = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(now.year, now.month, now.day, hour, minute);

  // "Morning ritual" zone (07:00-08:30): one task with an EXPLICIT zoneId
  // (scheduled inside the zone's own range too, so it's unambiguous), one
  // task relying purely on the COMPUTED FALLBACK (no zoneId, scheduledAt
  // just falls inside the window).
  final morningRun = Task.create(
    title: 'Morning run',
    scheduledAt: at(7, 10),
    durationMinutes: 30,
    categoryId: healthCategoryId,
  )..zoneId = 'preview-zone-morning';
  final stretch = Task.create(
    title: 'Stretch',
    scheduledAt: at(7, 50),
    durationMinutes: 15,
    categoryId: healthCategoryId,
  ); // no zoneId — computed fallback only.

  // "Deep work block" zone (10:00-12:00): a task explicitly assigned to
  // this zone but scheduled OUTSIDE its time range — the stale-assignment
  // case. Since 2026-09-04 TIME WINS (see CONSTITUTION.md's Zone section,
  // reversed from the original zoneId-wins rule), so this now renders at
  // its own 14:00 position OUTSIDE every container, not inside the
  // 10:00-12:00 one. Kept seeded precisely because it exercises that
  // reversal on a real device.
  final deepWork = Task.create(
    title: 'Deep work: Zone rendering',
    scheduledAt: at(14, 0), // well outside 10:00-12:00
    durationMinutes: 90,
    categoryId: workCategoryId,
  )..zoneId = 'preview-zone-deepwork';

  // Genuinely unzoned: no zoneId, and scheduledAt falls in no zone's
  // range at all — renders outside any container, at its own real
  // spatial time position, per the confirmed decision.
  final lunch = Task.create(
    title: 'Lunch with Sam',
    scheduledAt: at(12, 45),
    durationMinutes: 45,
    categoryId: personalCategoryId,
  );

  final seedTasks = [morningRun, stretch, deepWork, lunch];
  await taskBox.putAll({for (final task in seedTasks) task.id: task});

  await zoneBox.putAll({
    'preview-zone-morning': Zone(
      id: 'preview-zone-morning',
      title: 'Morning ritual',
      startMinutes: 7 * 60,
      endMinutes: 8 * 60 + 30,
    ),
    // Reported gap-verification case: two SHORT (30-min) back-to-back
    // zones with no member tasks, followed immediately by a third
    // (also back-to-back) zone that DOES have a member task — zones
    // can never genuinely overlap in real data (zonesOverlap is
    // enforced at save time), so these three are chained end-to-end
    // rather than overlapping like the old "Deep work block" seed did.
    'preview-zone-commute': Zone(
      id: 'preview-zone-commute',
      title: 'Commute to work',
      startMinutes: 8 * 60 + 30,
      endMinutes: 9 * 60,
    ),
    'preview-zone-worktill-lunch': Zone(
      id: 'preview-zone-worktill-lunch',
      title: 'Work till lunch',
      startMinutes: 9 * 60,
      endMinutes: 12 * 60,
    ),
    'preview-zone-deepwork': Zone(
      id: 'preview-zone-deepwork',
      title: 'Deep work block',
      startMinutes: 12 * 60,
      endMinutes: 13 * 60,
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
