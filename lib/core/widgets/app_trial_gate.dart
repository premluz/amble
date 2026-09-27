import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart' show PaywallResult;

import '../revenue_cat_config.dart';
import '../../shared/providers/purchases_providers.dart';
import 'app_undo_toast.dart';

/// Shared reaction to [TrialExpiredException] (`trial_providers.dart`) for
/// every widget-level task-creation entry point — quick capture, the task
/// detail sheet's create path, and the Timeline's quick-create overlay.
/// One function rather than duplicating the paywall call at each site,
/// mirroring `backup_settings_screen.dart`'s own `_ensureUnlocked`, just
/// reactive (catch the thrown exception) instead of a pre-check, since
/// these flows only know creation is blocked once `TaskList.createTask`/
/// `captureTask` actually throws.
///
/// Presents the RevenueCat paywall through [PurchasesRepository] — never
/// `RevenueCatUI` directly, matching that repository's own access rule.
/// Returns true if the purchase/restore succeeded, meaning the caller
/// should retry its create/capture call; false otherwise (cancelled,
/// errored, or purchases unavailable in this build), meaning it should
/// give up and leave the user's typed input in place.
Future<bool> presentPaywallForTrialExpired(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!RevenueCatConfig.isAvailable) {
    if (context.mounted) {
      AppUndoToast.show(
        context: context,
        message: 'Your free trial has ended, and purchases are not '
            'available in this build.',
      );
    }
    return false;
  }
  final result = await ref
      .read(purchasesRepositoryProvider)
      .presentPaywallIfNeeded(RevenueCatConfig.pantaProEntitlementId);
  await ref.read(pantaCustomerInfoProvider.notifier).refresh();
  return result == PaywallResult.purchased || result == PaywallResult.restored;
}
