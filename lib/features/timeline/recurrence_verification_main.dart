// SCAFFOLDING entry point — verifies the recurrence feature end to end on a
// real device: the create form's Repeats control, the Timeline showing
// materialized instances with the recurrence indicator, and editing one
// instance without touching its siblings. Not part of the real app.
//
// Modes (pass via --dart-define=mode=...):
//   form   — opens the create form with Repeats already on
//   series — creates a real daily series, then shows the Timeline
//   edit   — creates a series, edits ONE instance, shows the result
//
// Run with:
//   flutter run -t lib/features/timeline/recurrence_verification_main.dart \
//     --dart-define=mode=series
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/recurrence_frequency.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/models/task.dart';
import '../../shared/models/category.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/providers/notification_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../task_detail/task_detail_sheet.dart';
import 'timeline_screen.dart';

const _mode = String.fromEnvironment('mode', defaultValue: 'series');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();
  await Hive.openBox<TrackedBehavior>(trackedBehaviorBoxName);

  final container = ProviderContainer();
  // Mirrors main.dart — without this, the timezone database used by
  // notification scheduling is uninitialized and every save throws.
  await container
      .read(notificationServiceProvider)
      .initialize(onNotificationTap: (_) {});

  if (_mode != 'form') {
    final notifier = container.read(taskListProvider.notifier);
    final now = DateTime.now();

    // Anchor the seeded times to the current hour rather than a fixed
    // 07:00. The Timeline auto-scrolls to "now" on open, so hardcoded
    // early-morning times land above the fold and can't be screenshotted
    // without a scroll gesture — which iOS Simulator has no tool to
    // perform (see docs/ERROR_LOG.md). Anchoring keeps both seeded tasks
    // in view on any platform, at any time of day.
    final seriesHour = (now.hour + 1) % 24;
    final oneOffHour = (now.hour + 2) % 24;

    // A real recurring series, created through the normal write path.
    await notifier.createTask(
      title: 'Morning run',
      scheduledAt: DateTime(now.year, now.month, now.day, seriesHour, 0),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.health,
      recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
    );

    // A non-recurring task, so the indicator's presence/absence is a
    // visible contrast rather than something to take on trust.
    await notifier.createTask(
      title: 'One-off meeting',
      scheduledAt: DateTime(now.year, now.month, now.day, oneOffHour, 0),
      durationMinutes: 60,
      categoryId: BuiltInCategoryIds.work,
    );

    if (_mode == 'edit') {
      // Edit exactly one instance of the series — today's — and leave every
      // sibling untouched. Uses the same updateTask path the detail form
      // uses, so this exercises the real edit behaviour.
      final todays = container
          .read(taskListProvider)
          .firstWhere(
            (task) =>
                task.isRecurring &&
                task.scheduledAt!.day == now.day &&
                task.scheduledAt!.hour == seriesHour,
          );
      todays.title = 'Morning run (EDITED — today only)';
      todays.scheduledAt = DateTime(
        now.year,
        now.month,
        now.day,
        seriesHour,
        30,
      );
      await notifier.updateTask(todays);
    }
  }

  runApp(UncontrolledProviderScope(container: container, child: const _App()));
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: _mode == 'form'
          ? const _FormLauncher()
          : const Scaffold(
              body: TimelineScreen(mode: TimelineDisplayMode.spatial),
            ),
    );
  }
}

/// Opens the create form and switches Repeats on, so the expanded
/// recurrence options can be screenshotted without a tap-injection tool
/// (unavailable on iOS Simulator — see docs/ERROR_LOG.md).
class _FormLauncher extends StatefulWidget {
  const _FormLauncher();

  @override
  State<_FormLauncher> createState() => _FormLauncherState();
}

class _FormLauncherState extends State<_FormLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      showTaskDetailSheet(
        context,
        initialScheduledAt: DateTime(now.year, now.month, now.day, 7, 0),
        debugStartWithRepeatsOn: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
