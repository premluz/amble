import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../shared/providers/backup_providers.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/services/backup_service.dart';
import 'settings_detail_scaffold.dart';
import 'settings_panel.dart';

Future<void> showBackupSettingsScreen(
  BuildContext context, {
  bool debugAutoTriggerExport = false,
  bool debugAutoTriggerImport = false,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => BackupSettingsScreen(
        debugAutoTriggerExport: debugAutoTriggerExport,
        debugAutoTriggerImport: debugAutoTriggerImport,
      ),
    ),
  );
}

class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({
    super.key,
    this.debugAutoTriggerExport = false,
    this.debugAutoTriggerImport = false,
  });

  /// Scaffold-only: calls the real export handler once the screen has
  /// settled, exercising the actual `_export` path (not a
  /// re-implementation of it) so a dev entry point can screenshot the
  /// share sheet without a tap-injection tool (unavailable on iOS
  /// Simulator — see docs/ERROR_LOG.md). Never set outside `*_main.dart`
  /// scaffolding.
  @visibleForTesting
  final bool debugAutoTriggerExport;

  /// Same as [debugAutoTriggerExport], for the import handler.
  @visibleForTesting
  final bool debugAutoTriggerImport;

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  String? _statusMessage;
  bool _statusIsError = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.debugAutoTriggerExport) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _export());
    }
    if (widget.debugAutoTriggerImport) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _import());
    }
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final tasks = ref.read(taskListProvider);
      final categories = ref.read(categoryListProvider);
      final zones = ref.read(zoneListProvider);
      await ref
          .read(backupServiceProvider)
          .exportTasks(tasks, categories, zones);
      if (!mounted) return;
      setState(() {
        // Reports every entity actually written to the file — previously
        // only reported the task count even though categories/zones were
        // silently included too, reported directly as misleading ("says
        // exported 2 tasks, zones also exporting?").
        _statusMessage =
            'Exported ${tasks.length} task(s), '
            '${categories.length} categor${categories.length == 1 ? 'y' : 'ies'}, '
            '${zones.length} zone(s).';
        _statusIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Export failed: $error';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final backupService = ref.read(backupServiceProvider);
      final parsed = await backupService.pickAndParseImportFile();
      if (parsed == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      // Categories and zones first — a task's categoryId/zoneId should
      // resolve against the full restored sets by the time tasks are
      // merged in, though nothing in TaskList.importTasks actually
      // depends on ordering today (it stores the id, doesn't validate it
      // resolves).
      final categoryResult = await ref
          .read(categoryListProvider.notifier)
          .importCategories(parsed.categories);
      final zoneResult = await ref
          .read(zoneListProvider.notifier)
          .importZones(parsed.zones);
      final result = await ref
          .read(taskListProvider.notifier)
          .importTasks(parsed.tasks);
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Imported ${result.imported} task(s). '
            '${result.alreadyPresent} already present, '
            '${result.conflicts} conflict(s) skipped. '
            '${categoryResult.imported} categor${categoryResult.imported == 1 ? 'y' : 'ies'} imported. '
            '${zoneResult.imported} zone(s) imported, '
            '${zoneResult.alreadyPresent} already present, '
            '${zoneResult.conflicts} conflict(s) skipped.';
        _statusIsError = false;
      });
    } on BackupImportException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = error.message;
        _statusIsError = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Import failed: $error';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final taskCount = ref.watch(taskListProvider).length;

    return SettingsDetailScaffold(
      title: 'Backup',
      body: SettingsPanel(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$taskCount task(s) stored locally. Export creates a JSON '
              'backup you can share or save; import merges a backup back '
              'in without overwriting anything already here.',
              style: theme.textBody.copyWith(color: theme.colorTextSecondary),
            ),
            SizedBox(height: theme.spacingMd),
            AppButton(
              label: 'Export backup',
              onPressed: _busy ? null : _export,
            ),
            SizedBox(height: theme.spacingSm),
            AppButton(
              label: 'Import backup',
              variant: AppButtonVariant.secondary,
              onPressed: _busy ? null : _import,
            ),
            if (_statusMessage != null) ...[
              SizedBox(height: theme.spacingMd),
              Text(
                _statusMessage!,
                style: theme.textBody.copyWith(
                  color: _statusIsError
                      ? theme.colorTaskAlert
                      : theme.colorTextPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
