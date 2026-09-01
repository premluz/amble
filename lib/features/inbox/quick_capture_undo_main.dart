// SCAFFOLDING entry point — exercises the confident-parse auto-create +
// undo-toast path end to end (parseQuickCapture -> taskListProvider
// .createTask -> AppUndoToast.show), using the SAME calls
// quick_capture_sheet.dart's `_submit()` makes for a confident parse — no
// tap-injection tool is available in this environment to type into the
// sheet's TextField and press its button, so this scaffold drives the
// identical sequence programmatically instead of re-simulating a tap.
// Not part of the real app. Run with:
//   flutter run -t lib/features/inbox/quick_capture_undo_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_undo_toast.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/models/category.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/services/quick_capture_parser.dart';
import '../timeline/timeline_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();
  // ShowHourLabelsSetting/DisableOverlapClusteringSetting both read this
  // box unconditionally — TimelineScreen throws "Box not found" without
  // it, even though this scaffold never writes to it.
  await Hive.openBox<dynamic>(preferencesBoxName);

  runApp(const ProviderScope(child: _PreviewApp()));
}

class _PreviewApp extends ConsumerStatefulWidget {
  const _PreviewApp();

  @override
  ConsumerState<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends ConsumerState<_PreviewApp> {
  Future<void> _runSequence(BuildContext context) async {
    // The exact sequence _submit() runs for a confident parse — "today"
    // rather than "tomorrow" so the created task lands on the Timeline
    // day already visible, for a more legible screenshot.
    const rawInput = 'Call client today at 10:30 for 30 mins';
    final result = parseQuickCapture(
      rawInput,
      now: DateTime.now(),
      categories: const [],
    );
    final notifier = ref.read(taskListProvider.notifier);
    final created = await notifier.createTask(
      title: result.title,
      scheduledAt: result.scheduledAt!,
      durationMinutes:
          result.durationMinutes ?? quickCaptureDefaultDurationMinutes,
      categoryId: BuiltInCategoryIds.general,
      recurrenceRule: result.recurrenceRule,
    );

    if (!context.mounted) return;
    final time = TimeOfDay.fromDateTime(result.scheduledAt!);
    AppUndoToast.show(
      context: context,
      message: "Created '${created.title}' at ${time.format(context)}",
      onUndo: () => ref.read(taskListProvider.notifier).deleteTask(created.id),
      // Longer than the real 4s default — purely so a manual screenshot
      // (no tap-injection tool to time against the real duration) has a
      // comfortable window to land the shot.
      duration: const Duration(seconds: 30),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Scaffold(
        body: Builder(
          // A Builder's own context is a DESCENDANT of MaterialApp's
          // Navigator/Overlay, unlike a GlobalKey<NavigatorState>'s
          // currentContext (which sits at the Navigator itself, above
          // its own Overlay) — AppUndoToast.show needs the former.
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _runSequence(context),
            );
            return const TimelineScreen();
          },
        ),
      ),
    );
  }
}
