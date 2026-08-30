// SCAFFOLDING entry point — verifies the TrackedBehavior first UI slice on
// a real device. Not part of the real app. Requires the feature flag:
//
//   flutter run -t lib/features/tracked_behavior/tracked_behavior_main.dart \
//     --dart-define=trackedBehavior=true --dart-define=mode=create
//
// Modes:
//   create  — Settings, with the "Track a behavior" entry point + form open
//   link    — task detail form showing the behavior picker
//   outcome — the outcome prompt, as shown when completing a linked task
//   ordinary — an ORDINARY task's detail form, to show no added friction
//   timeline — Timeline seeded with four contrasting tasks, to verify the
//              tracked-behavior indicator renders (and coexists with the
//              recurring indicator). Headless goldens draw icons as blank
//              boxes (see docs/DECISIONS.md, Phase 3), so only a real
//              screenshot actually verifies an icon.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/behavior_target_type.dart';
import '../../shared/models/recurrence_frequency.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_category.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/providers/notification_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../settings/settings_screen.dart';
import '../timeline/timeline_screen.dart';
import '../task_detail/task_detail_sheet.dart';
import 'behavior_outcome_prompt.dart';
import 'tracked_behavior_form.dart';

const _mode = String.fromEnvironment('mode', defaultValue: 'create');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final taskBox = await Hive.openBox<Task>(taskBoxName);
  final behaviorBox = await Hive.openBox<TrackedBehavior>(
    trackedBehaviorBoxName,
  );
  await taskBox.clear();
  await behaviorBox.clear();

  final container = ProviderContainer();
  // Mirrors main.dart — without this the timezone database used by
  // notification scheduling is uninitialized and every save throws.
  await container
      .read(notificationServiceProvider)
      .initialize(onNotificationTap: (_) {});

  // Seed a behavior for every mode except the bare create flow, so the
  // picker and prompt have something real to show.
  if (_mode != 'create') {
    await container
        .read(trackedBehaviorListProvider.notifier)
        .createBehavior(
          title: 'Exercise',
          targetType: BehaviorTargetType.duration,
          targetAmount: 60,
          minimumAmount: 15,
          timesPerWeek: 3,
        );
  }

  if (_mode == 'timeline') {
    await _seedTimeline(container);
  }

  runApp(UncontrolledProviderScope(container: container, child: const _App()));
}

/// Seeds four contrasting tasks so one screenshot shows every indicator
/// combination side by side: neither, behavior-only, recurring-only, and
/// both together (the coexistence case).
///
/// Times are anchored just ahead of the current hour because the Timeline
/// auto-scrolls to "now" on open — hardcoded morning times would land above
/// the fold, and iOS Simulator has no scroll gesture (docs/ERROR_LOG.md).
Future<void> _seedTimeline(ProviderContainer container) async {
  final notifier = container.read(taskListProvider.notifier);
  final behavior = container.read(trackedBehaviorListProvider).single;
  final now = DateTime.now();
  // Four tasks at 30-minute spacing, starting one hour out. Half-hour
  // steps (rather than hourly) keep all four inside the Timeline's 06:00
  // –22:00 window and inside one screenful, so a single screenshot can
  // show every indicator combination without scrolling — which iOS
  // Simulator cannot do (docs/ERROR_LOG.md). Clamped so a late-evening run
  // still lands them on-screen rather than past the end of the day.
  final baseHour = (now.hour + 1).clamp(7, 19);
  DateTime at(int halfHourSteps) => DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(hours: baseHour, minutes: 30 * halfHourSteps));

  // 1. Ordinary task — the control. No indicators at all.
  await notifier.createTask(
    title: 'Ordinary task',
    scheduledAt: at(0),
    durationMinutes: 30,
    category: TaskCategory.work,
  );

  // 2. Linked to a tracked behavior only — the track_changes icon.
  await notifier.createTask(
    title: 'Tracked only',
    scheduledAt: at(1),
    durationMinutes: 30,
    category: TaskCategory.health,
    behaviorId: behavior.id,
  );

  // 3. Recurring only — the repeat icon, for visual contrast.
  await notifier.createTask(
    title: 'Recurring only',
    scheduledAt: at(2),
    durationMinutes: 30,
    category: TaskCategory.personal,
    recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
  );

  // 4. Both at once — the coexistence case. A recurring series linked to a
  //    behavior; every materialized instance inherits the link, so this
  //    also exercises that inheritance on a real render.
  await notifier.createTask(
    title: 'Recurring and tracked',
    scheduledAt: at(3),
    durationMinutes: 30,
    category: TaskCategory.admin,
    recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
    behaviorId: behavior.id,
  );
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: const _Launcher(),
    );
  }
}

class _Launcher extends ConsumerStatefulWidget {
  const _Launcher();

  @override
  ConsumerState<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends ConsumerState<_Launcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final now = DateTime.now();

      switch (_mode) {
        case 'create':
          await showTrackedBehaviorForm(context);

        case 'link':
          // The picker appears inside the normal task detail form.
          if (!mounted) return;
          await showTaskDetailSheet(
            context,
            initialScheduledAt: DateTime(
              now.year,
              now.month,
              now.day,
              now.hour + 1,
            ),
          );

        case 'ordinary':
          // Same form, flag ON, but nothing linked — evidence that an
          // ordinary task is unchanged apart from an opt-in "None" row.
          if (!mounted) return;
          await showTaskDetailSheet(
            context,
            initialScheduledAt: DateTime(
              now.year,
              now.month,
              now.day,
              now.hour + 1,
            ),
          );

        case 'timeline':
          // Nothing to open — the seeded Timeline is the subject itself.
          break;

        case 'outcome':
          final behavior = ref.read(trackedBehaviorListProvider).single;
          if (!mounted) return;
          await showBehaviorOutcomePrompt(context, behavior: behavior);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The timeline mode is verifying the Timeline itself; every other mode
    // shows Settings, the real home of the create entry point.
    if (_mode == 'timeline') return const Scaffold(body: TimelineScreen());
    return const Scaffold(body: SettingsScreen());
  }
}
