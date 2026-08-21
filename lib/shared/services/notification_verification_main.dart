// SCAFFOLDING entry point — boots the real app (real notification plugin
// init, real permission prompt) and, once ready, calls the real
// TaskList.createTask with a scheduledAt 90 seconds in the future, via a
// visible on-screen button (no tap-injection tool in this environment, so
// this needs a real human tap on-device — the button is intentionally
// large and only exists in this scaffold). Used to manually verify a real
// notification fires on a physical device/simulator. Not part of the real
// app. Run with:
//   flutter run -t lib/shared/services/notification_verification_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../providers/notification_providers.dart';
import '../providers/task_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  runApp(const ProviderScope(child: _VerificationApp()));
}

class _VerificationApp extends ConsumerStatefulWidget {
  const _VerificationApp();

  @override
  ConsumerState<_VerificationApp> createState() => _VerificationAppState();
}

class _VerificationAppState extends ConsumerState<_VerificationApp> {
  bool _initialized = false;
  String _status = 'Initializing notification plugin…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(notificationServiceProvider)
          .initialize(onNotificationTap: (id) {});
      if (mounted) {
        setState(() {
          _initialized = true;
          _status = 'Ready. Tap the button to schedule a test notification.';
        });
      }
    });
  }

  Future<void> _scheduleTestNotification() async {
    final fireAt = DateTime.now().add(const Duration(seconds: 90));
    setState(
      () => _status =
          'Scheduling "Notification test" for '
          '${fireAt.hour.toString().padLeft(2, '0')}:'
          '${fireAt.minute.toString().padLeft(2, '0')}:'
          '${fireAt.second.toString().padLeft(2, '0')} '
          '(90s from now)…',
    );
    await ref
        .read(taskListProvider.notifier)
        .createTask(
          title: 'Notification test',
          scheduledAt: fireAt,
          durationMinutes: 5,
          category: TaskCategory.personal,
        );
    setState(
      () => _status =
          'Scheduled. Background the app now and wait ~90s for the '
          'notification to fire.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_status, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initialized ? _scheduleTestNotification : null,
                  child: const Text('Schedule test notification (+90s)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
