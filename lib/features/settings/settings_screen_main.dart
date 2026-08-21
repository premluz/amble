// SCAFFOLDING entry point — seeds a few real tasks and boots SettingsScreen
// standalone (no auto-triggered export/import), for a plain baseline
// screenshot of the screen itself. Not part of the real app. Run with:
//   flutter run -t lib/features/settings/settings_screen_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_category.dart';
import '../../shared/providers/task_providers.dart';
import 'settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  final now = DateTime.now();
  final seedTasks = [
    Task.create(
      title: 'Morning run',
      scheduledAt: DateTime(now.year, now.month, now.day, 7, 0),
      durationMinutes: 30,
      category: TaskCategory.health,
    ),
    Task.captured(title: 'Read that article'),
  ];
  await box.putAll({for (final task in seedTasks) task.id: task});

  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: const Scaffold(body: SettingsScreen()),
      ),
    );
  }
}
