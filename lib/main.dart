import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'core/tokens/semantic_theme.dart';
import 'features/timeline/timeline_screen.dart';
import 'hive_registrar.g.dart';
import 'shared/models/task.dart';
import 'shared/providers/task_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<Task>(taskBoxName);
  runApp(const ProviderScope(child: AmbleApp()));
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
      home: const Scaffold(body: TimelineScreen()),
    );
  }
}
