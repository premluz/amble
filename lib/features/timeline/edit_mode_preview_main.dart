// SCAFFOLDING entry point — verifies Edit Mode (CONSTITUTION.md's "Edit
// Mode" section) on a real device with real provider-backed data. Not part
// of the real app. Run with:
//
//   flutter run -t lib/features/timeline/edit_mode_preview_main.dart \
//     --dart-define=mode=task
//   flutter run -t lib/features/timeline/edit_mode_preview_main.dart \
//     --dart-define=mode=zone
//
// Modes:
//   task — Task view (showHourLabels/zoneViewEnabled off), Edit Mode ON at
//          launch, seeded with one task to show the resize handle + wiggle.
//   zone — Zone view (zoneViewEnabled on), Edit Mode ON at launch, seeded
//          with one zone (containing one task) to show both resize
//          handles + wiggle.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/dev_config.dart';
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
import 'edit_mode_provider.dart';
import 'timeline_screen.dart';

const _mode = String.fromEnvironment('mode', defaultValue: 'task');

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
  await preferencesBox.put(PreferenceKeys.zoneViewEnabled, _mode == 'zone');

  const healthCategoryId = 'preview-health';
  const workCategoryId = 'preview-work';
  await categoryBox.putAll({
    healthCategoryId: Category(
      id: healthCategoryId,
      name: 'Health',
      colorToken: 4,
      emoji: '⛑️',
    ),
    workCategoryId: Category(
      id: workCategoryId,
      name: 'Work',
      colorToken: 8,
      emoji: '💼',
    ),
  });

  final now = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(now.year, now.month, now.day, hour, minute);

  final morningRun = Task.create(
    title: 'Morning run',
    scheduledAt: at(7, 0),
    durationMinutes: 30,
    categoryId: healthCategoryId,
  );
  final deepWork = Task.create(
    title: 'Deep work',
    scheduledAt: at(9, 30),
    durationMinutes: 90,
    categoryId: workCategoryId,
  )..zoneId = 'preview-zone-morning';
  await taskBox.putAll({
    morningRun.id: morningRun,
    if (_mode == 'zone') deepWork.id: deepWork,
  });

  if (_mode == 'zone') {
    await zoneBox.put(
      'preview-zone-morning',
      Zone(
        id: 'preview-zone-morning',
        title: 'Morning ritual',
        startMinutes: 9 * 60,
        endMinutes: 11 * 60,
      ),
    );
  }

  runApp(const _PreviewApp());
}

class _StartsOnEditModeEnabled extends EditModeEnabled {
  @override
  bool build() => true;
}

class _ZoneViewInCycleOn extends DevZoneViewInCycle {
  @override
  bool build() => true;
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      // Edit Mode ON at launch — this scaffold's whole point is verifying
      // it, so starting there skips a manual tap on every run.
      overrides: [
        editModeEnabledProvider.overrideWith(() => _StartsOnEditModeEnabled()),
        // Zone view is additionally gated by a debug-only dev toggle (see
        // core/dev_config.dart's DevZoneViewInCycle, default false) on top
        // of the persisted zoneViewEnabled preference this scaffold
        // already sets — both gates must be on for Zone view to actually
        // be reachable in a debug build, which is what `flutter run`
        // always is.
        if (_mode == 'zone')
          devZoneViewInCycleProvider.overrideWith(() => _ZoneViewInCycleOn()),
      ],
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
