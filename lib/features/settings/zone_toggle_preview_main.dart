// SCAFFOLDING entry point — opens straight to SettingsScreen against
// whatever real data is already persisted (typically run right after
// zone_view_preview_main.dart, to screenshot the Zone view toggle in its
// ON state and confirm tapping it off reverts the Timeline). Not part of
// the real app. Run with:
//   flutter run -t lib/features/settings/zone_toggle_preview_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../../shared/providers/zone_providers.dart';
import 'settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<Task>(taskBoxName);
  await Hive.openBox<TrackedBehavior>(trackedBehaviorBoxName);
  await Hive.openBox<Zone>(zoneBoxName);
  await Hive.openBox<Category>(categoryBoxName);
  await Hive.openBox<dynamic>(preferencesBoxName);
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
        home: const SettingsScreen(),
      ),
    );
  }
}
