import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'core/tokens/semantic_theme.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/timeline/selected_date_provider.dart';
import 'features/timeline/timeline_screen.dart';
import 'hive_registrar.g.dart';
import 'shared/models/task.dart';
import 'shared/providers/notification_providers.dart';
import 'shared/providers/notification_tap_provider.dart';
import 'shared/providers/task_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<Task>(taskBoxName);

  final container = ProviderContainer();
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.initialize(
    onNotificationTap: (taskId) =>
        container.read(notificationTapProvider.notifier).set(taskId),
  );
  await notificationService.handleColdStartLaunch(
    onNotificationTap: (taskId) =>
        container.read(notificationTapProvider.notifier).set(taskId),
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const AmbleApp()),
  );
}

class AmbleApp extends StatelessWidget {
  const AmbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Amble',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B6F52),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F5F0),
        extensions: [AmbleTheme.light],
      ),
      home: const AmbleHome(),
    );
  }
}

/// The app's root nav shell — Inbox, Timeline, Settings, per
/// docs/SCOPE.md's final Inbox/Timeline/Settings nav structure. Settings
/// (Phase 8) replaces the temporary "Backup" tab from Phase 7 — see
/// docs/DECISIONS.md. Placed after Timeline so the tap-to-open index below
/// (1) still lands correctly.
///
/// Also the single place that reacts to [notificationTapProvider] — tapping
/// a task-start notification switches to the Timeline tab and jumps to that
/// task's day, then consumes the pending tap so it doesn't re-fire on a
/// later rebuild.
class AmbleHome extends ConsumerStatefulWidget {
  const AmbleHome({super.key});

  @override
  ConsumerState<AmbleHome> createState() => _AmbleHomeState();
}

class _AmbleHomeState extends ConsumerState<AmbleHome> {
  int _selectedIndex = 1;

  static const _screens = [InboxScreen(), TimelineScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    ref.listen(notificationTapProvider, (previous, taskId) {
      if (taskId == null) return;
      final task = ref.read(taskByIdProvider(taskId));
      final scheduledAt = task?.scheduledAt;
      if (scheduledAt != null) {
        ref.read(selectedDateProvider.notifier).goTo(scheduledAt);
      }
      setState(() => _selectedIndex = 1);
      ref.read(notificationTapProvider.notifier).consume();
    });

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        backgroundColor: theme.colorSurfacePrimary,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_rounded),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_day_rounded),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
