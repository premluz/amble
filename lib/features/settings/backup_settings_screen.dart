import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart' show PaywallResult;

import '../../core/revenue_cat_config.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../shared/providers/backup_providers.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/purchases_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/providers/zone_facet_providers.dart';
import '../../shared/services/backup_service.dart';
import 'settings_detail_scaffold.dart';
import 'settings_panel.dart';

Future<void> showBackupSettingsScreen(
  BuildContext context, {
  bool debugAutoTriggerExport = false,
  bool debugAutoTriggerImport = false,
}) {
  return pushSettingsDetailRoute<void>(
    context,
    (context) => BackupSettingsScreen(
      debugAutoTriggerExport: debugAutoTriggerExport,
      debugAutoTriggerImport: debugAutoTriggerImport,
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

  /// Export/import require an active `panta_pro` entitlement — no free
  /// trial window, requested directly ("no export/import only available
  /// when panta purchased, not available during trial"). Presents the
  /// same RevenueCat paywall `SubscriptionSettingsScreen` uses, through
  /// [PurchasesRepository] rather than `RevenueCatUI` directly (see that
  /// repository's own "UI and state never call Purchases/RevenueCatUI
  /// directly" rule). Returns whether the caller should proceed —
  /// unlocked already, or just unlocked by a purchase/restore made from
  /// this paywall.
  Future<bool> _ensureUnlocked() async {
    if (ref.read(isPantaProProvider)) return true;
    if (!RevenueCatConfig.isAvailable) {
      setState(() {
        _statusMessage = 'Purchases are not available in this build.';
        _statusIsError = true;
      });
      return false;
    }
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final result = await ref
          .read(purchasesRepositoryProvider)
          .presentPaywallIfNeeded(RevenueCatConfig.pantaProEntitlementId);
      await ref.read(pantaCustomerInfoProvider.notifier).refresh();
      return result == PaywallResult.purchased ||
          result == PaywallResult.restored;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    if (!await _ensureUnlocked()) return;
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
          .exportTasks(
            tasks,
            categories,
            zones,
            zoneFacets: ref.read(zoneFacetListProvider),
          );
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
    if (!await _ensureUnlocked()) return;
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
      await ref
          .read(zoneFacetListProvider.notifier)
          .importFacets(parsed.zoneFacets);
      final zoneResult = await ref
          .read(zoneListProvider.notifier)
          .importZones(parsed.zones);
      await ref.read(zoneListProvider.notifier).migrateToWeeklySchedule();
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
    final isPro = ref.watch(isPantaProProvider);

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
            // Requires panta_pro — no free trial window for this feature,
            // requested directly. `_ensureUnlocked` presents the paywall
            // when tapped locked; the label says so up front rather than
            // reading as a broken free button.
            if (!isPro) ...[
              SizedBox(height: theme.spacingXs),
              Text(
                'Requires Panta Pro.',
                style: theme.textCaption.copyWith(
                  color: theme.colorTextSecondary,
                ),
              ),
            ],
            SizedBox(height: theme.spacingMd),
            AppButton(
              label: isPro ? 'Export backup' : 'Export backup (Unlock)',
              // Secondary, not primary — settings actions are equal-weight
              // utilities, no single dominant CTA. App-wide button
              // unification pass, requested directly.
              variant: AppButtonVariant.secondary,
              onPressed: _busy ? null : _export,
            ),
            SizedBox(height: theme.spacingSm),
            AppButton(
              label: isPro ? 'Import backup' : 'Import backup (Unlock)',
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
