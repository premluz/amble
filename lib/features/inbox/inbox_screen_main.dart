// SCAFFOLDING entry point — launches InboxScreen standalone for visual
// review, wired to a real Hive box seeded with unscheduled sample tasks so
// the screen exercises the actual provider chain, not hardcoded data. Not
// part of the real app. Run with:
//   flutter run -t lib/features/inbox/inbox_screen_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import 'inbox_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  final seedTasks = [
    Task.captured(title: 'Book dentist appointment'),
    Task.captured(title: 'Read that article Sam sent'),
    Task.captured(
      title: 'Plan weekend trip',
      notes: 'Check the weather first.',
    ),
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
        home: const Scaffold(body: InboxScreen()),
      ),
    );
  }
}
