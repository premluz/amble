// SCAFFOLDING entry point — like settings_import_main.dart, but imports
// the same backup file TWICE in a row without wiping in between, to
// verify the "identical task, same id -> skip as alreadyPresent, no
// duplicate" merge behavior live rather than only at the unit-test level.
// Not part of the real app. Run with:
//   flutter run -t lib/features/settings/settings_reimport_main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/backup_providers.dart';
import '../../shared/providers/task_providers.dart';
import 'settings_screen.dart';

const _importFilePath =
    '/private/tmp/claude-501/-Users-przemek-Amble/'
    '6fbeccc6-7290-42a1-9b15-d8394e4b50e6/scratchpad/exported_backup.json';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  runApp(const ProviderScope(child: _ReimportVerificationApp()));
}

class _ReimportVerificationApp extends ConsumerStatefulWidget {
  const _ReimportVerificationApp();

  @override
  ConsumerState<_ReimportVerificationApp> createState() =>
      _ReimportVerificationAppState();
}

class _ReimportVerificationAppState
    extends ConsumerState<_ReimportVerificationApp> {
  String _status = 'Running double-import…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final jsonString = await File(_importFilePath).readAsString();
      final backupService = ref.read(backupServiceProvider);
      final notifier = ref.read(taskListProvider.notifier);

      final firstTasks = backupService.parseImportFile(jsonString);
      final first = await notifier.importTasks(firstTasks);

      final secondTasks = backupService.parseImportFile(jsonString);
      final second = await notifier.importTasks(secondTasks);

      setState(() {
        _status =
            'First import: ${first.imported} imported, '
            '${first.alreadyPresent} already present.\n'
            'Second import (same file again): ${second.imported} imported, '
            '${second.alreadyPresent} already present, '
            '${second.conflicts} conflicts.\n'
            'Final task count: '
            '${ref.read(taskListProvider).length} (should still be 3, '
            'no duplicates).';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]);
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_status),
                const SizedBox(height: 24),
                const Expanded(child: SettingsScreen()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
