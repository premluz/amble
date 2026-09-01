// SCAFFOLDING entry point — seeds the same overlap scenarios as
// timeline_overlap_main.dart (isolated task, 2-way clash, 3-way clash) but
// launches the real AmbleHome shell (Inbox/Timeline/Settings nav) so the
// clustering feature — the aggregate OverlapClusterBlock, the Settings
// opt-out toggle, and naive-overlap rendering with it off — can all be
// verified/screenshotted on a real device from one entry point. Not part
// of the real app. Run with:
//   flutter run -t lib/features/timeline/overlap_cluster_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/models/category.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/repositories/preferences_repository.dart';
import '../settings/settings_screen.dart';
import 'timeline_screen.dart';

/// Set true for a second screenshot pass demonstrating the Settings
/// opt-out actually rendering naive spatial overlap once persisted —
/// exercises the real `PreferenceKeys.disableOverlapClustering` key
/// through the repository, not a provider override, so the screenshot
/// reflects the genuine on-disk-setting path.
const _startWithClusteringDisabled = bool.fromEnvironment('disableClustering');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final taskBox = await Hive.openBox<Task>(taskBoxName);
  await taskBox.clear();
  final preferencesBox = await Hive.openBox<dynamic>(preferencesBoxName);
  await preferencesBox.clear();
  if (_startWithClusteringDisabled) {
    await preferencesBox.put(PreferenceKeys.disableOverlapClustering, true);
  }

  final now = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(now.year, now.month, now.day, hour, minute);

  final seedTasks = [
    // No overlap — normal, unclustered rendering. Confirms clustering
    // leaves an ordinary day completely unchanged.
    Task.create(
      title: 'Morning run',
      scheduledAt: at(7, 0),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.health,
    ),
    // A 2-task cluster.
    Task.create(
      title: 'Deep work',
      scheduledAt: at(9, 0),
      durationMinutes: 90,
      categoryId: BuiltInCategoryIds.work,
    ),
    Task.create(
      title: 'Standup',
      scheduledAt: at(9, 30),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.admin,
    ),
    // A 3-task cluster.
    Task.create(
      title: 'Overlap A',
      scheduledAt: at(13, 0),
      durationMinutes: 60,
      categoryId: BuiltInCategoryIds.personal,
    ),
    Task.create(
      title: 'Overlap B',
      scheduledAt: at(13, 30),
      durationMinutes: 60,
      categoryId: BuiltInCategoryIds.health,
    ),
    Task.create(
      title: 'Overlap C',
      scheduledAt: at(14, 0),
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
        home: const _Shell(),
      ),
    );
  }
}

/// A minimal 2-tab shell (Timeline/Settings only) rather than the full
/// AmbleHome — this scaffold's whole point is the clustering feature, and
/// Inbox isn't part of it.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  // No tap-injection tool available for this session (see
  // docs/ERROR_LOG.md) — the tab to screenshot is picked at launch time
  // via this constant rather than navigated to interactively.
  int _index = 0;

  // Drives SettingsScreen's own SingleChildScrollView (which has no
  // explicit controller of its own, so it picks up the ambient
  // PrimaryScrollController) — the new clustering toggle sits below the
  // fold, and there's no tap tool to scroll to it interactively.
  final _settingsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToBottomWhenReady();
  }

  // A single post-frame callback can race the ScrollView's own attach —
  // this is throwaway scaffold code, so re-scheduling itself each frame
  // until the controller has a client is simpler than getting the exact
  // right one-shot timing.
  void _scrollToBottomWhenReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_settingsScrollController.hasClients) {
        _scrollToBottomWhenReady();
        return;
      }
      _settingsScrollController.jumpTo(
        _settingsScrollController.position.maxScrollExtent,
      );
    });
  }

  @override
  void dispose() {
    _settingsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const TimelineScreen(),
          PrimaryScrollController(
            controller: _settingsScrollController,
            child: const SettingsScreen(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        backgroundColor: theme.colorSurfacePrimary,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_view_day_outlined),
            selectedIcon: Icon(Icons.calendar_view_day),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
