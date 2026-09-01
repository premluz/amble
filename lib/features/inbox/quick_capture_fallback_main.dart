// SCAFFOLDING entry point — exercises the non-confident fallback path
// (parseQuickCapture -> taskListProvider.captureTask), the SAME call
// quick_capture_sheet.dart's `_submit()` makes when no date/time anchor
// is found, then shows the Inbox so the result (a plain, unscheduled
// title-only task) is visible. No tap-injection tool is available in this
// environment to type into the sheet and press its button, so this
// scaffold drives the identical call programmatically. Not part of the
// real app. Run with:
//   flutter run -t lib/features/inbox/quick_capture_fallback_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/services/quick_capture_parser.dart';
import 'inbox_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  runApp(const ProviderScope(child: _PreviewApp()));
}

class _PreviewApp extends ConsumerStatefulWidget {
  const _PreviewApp();

  @override
  ConsumerState<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends ConsumerState<_PreviewApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Deliberately ambiguous — no date/time anchor, matching the exact
      // "bare recurrence phrase" example from the work order.
      const rawInput = 'Book dentist appointment sometime next month';
      final result = parseQuickCapture(
        rawInput,
        now: DateTime.now(),
        categories: const [],
      );
      assert(!result.isConfident, 'This scaffold seeds the FALLBACK path.');
      await ref.read(taskListProvider.notifier).captureTask(rawInput);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: const Scaffold(body: InboxScreen()),
    );
  }
}
