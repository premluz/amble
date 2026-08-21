// SCAFFOLDING entry point — wipes local task data (simulating a fresh
// install), boots SettingsScreen, and calls the real import parse+merge
// path directly against a known backup file
// (SettingsScreen.debugAutoTriggerImport normally drives the real file
// picker + BackupService.pickAndParseImportFile, but the native document
// picker itself needs a tap this environment can't provide — see
// docs/ERROR_LOG.md — so this scaffold instead reads the file straight
// from disk and calls BackupService.parseImportFile +
// TaskList.importTasks, the exact same code path minus the picker UI
// itself). Not part of the real app. Run with:
//   flutter run -t lib/features/settings/settings_import_main.dart
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

/// Path to a previously-exported backup file. Update this if re-running
/// the export scaffold produces a new file.
const _importFilePath =
    '/private/tmp/claude-501/-Users-przemek-Amble/'
    '6fbeccc6-7290-42a1-9b15-d8394e4b50e6/scratchpad/exported_backup.json';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  final box = await Hive.openBox<Task>(taskBoxName);
  await box.clear();

  runApp(const ProviderScope(child: _ImportVerificationApp()));
}

class _ImportVerificationApp extends ConsumerStatefulWidget {
  const _ImportVerificationApp();

  @override
  ConsumerState<_ImportVerificationApp> createState() =>
      _ImportVerificationAppState();
}

class _ImportVerificationAppState
    extends ConsumerState<_ImportVerificationApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final jsonString = await File(_importFilePath).readAsString();
      final backupService = ref.read(backupServiceProvider);
      final tasks = backupService.parseImportFile(jsonString);
      await ref.read(taskListProvider.notifier).importTasks(tasks);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: const Scaffold(body: SettingsScreen()),
    );
  }
}
