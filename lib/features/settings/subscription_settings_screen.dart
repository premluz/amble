import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../core/revenue_cat_config.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../shared/providers/purchases_providers.dart';
import 'settings_detail_scaffold.dart';
import 'settings_panel.dart';

Future<void> showSubscriptionSettingsScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (context) => const SubscriptionSettingsScreen()),
  );
}

class SubscriptionSettingsScreen extends ConsumerStatefulWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  ConsumerState<SubscriptionSettingsScreen> createState() =>
      _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState
    extends ConsumerState<SubscriptionSettingsScreen> {
  String? _statusMessage;
  bool _statusIsError = false;
  bool _busy = false;

  Future<void> _presentPaywall() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      // Through the repository, not `RevenueCatUI` directly — that rule
      // is [PurchasesRepository]'s own ("UI and state never call
      // Purchases/RevenueCatUI directly"), and the wrapper already
      // existed but was being bypassed here.
      final result = await ref
          .read(purchasesRepositoryProvider)
          .presentPaywallIfNeeded(RevenueCatConfig.pantaProEntitlementId);
      await ref.read(pantaCustomerInfoProvider.notifier).refresh();
      if (!mounted) return;
      setState(() {
        _statusMessage = switch (result) {
          PaywallResult.purchased => 'Panta Pro unlocked. Thank you!',
          PaywallResult.restored => 'Your Panta Pro purchase was restored.',
          PaywallResult.cancelled => null,
          PaywallResult.notPresented => null,
          PaywallResult.error =>
            'Something went wrong presenting the paywall. Please try again.',
        };
        _statusIsError = result == PaywallResult.error;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _messageForPlatformException(error);
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _presentCustomerCenter() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      // Through the repository, not `RevenueCatUI` directly — see
      // `_presentPaywall`'s own note.
      await ref.read(purchasesRepositoryProvider).presentCustomerCenter();
      await ref.read(pantaCustomerInfoProvider.notifier).refresh();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _messageForPlatformException(error);
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await ref.read(purchasesRepositoryProvider).restorePurchases();
      await ref.read(pantaCustomerInfoProvider.notifier).refresh();
      if (!mounted) return;
      final isPro = ref.read(isPantaProProvider);
      setState(() {
        _statusMessage = isPro
            ? 'Purchases restored — Panta Pro is active.'
            : 'No previous Panta Pro purchase was found for this account.';
        _statusIsError = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _messageForPlatformException(error);
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// `purchaseCancelledError` is a normal user action, not a failure — it
  /// gets no message at all rather than reading as an error toast. Every
  /// other code gets a short, user-facing explanation; the full
  /// [PurchasesErrorCode] carries far more detail than a subscription
  /// settings screen should surface.
  String? _messageForPlatformException(PlatformException error) {
    final code = PurchasesErrorHelper.getErrorCode(error);
    return switch (code) {
      PurchasesErrorCode.purchaseCancelledError => null,
      PurchasesErrorCode.networkError =>
        'No network connection. Please check your connection and try again.',
      PurchasesErrorCode.purchaseNotAllowedError =>
        'Purchases are not allowed on this device.',
      PurchasesErrorCode.paymentPendingError =>
        'Your payment is pending approval.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isPro = ref.watch(isPantaProProvider);
    final customerInfo = ref.watch(pantaCustomerInfoProvider);
    final expirationDate = customerInfo
        ?.entitlements
        .active[RevenueCatConfig.pantaProEntitlementId]
        ?.expirationDate;

    // Purchases are unavailable in this build — an unsupported platform
    // (only iOS/Android have the RevenueCat SDK) or no `--dart-define`
    // API key. The SDK was never configured, so every action below would
    // throw; say so plainly instead of offering buttons that cannot work.
    if (!RevenueCatConfig.isAvailable) {
      return SettingsDetailScaffold(
        title: 'Subscription',
        body: SettingsPanel(
          theme: theme,
          child: Text(
            'Subscriptions are not available in this build.',
            style: theme.textBody.copyWith(color: theme.colorTextSecondary),
          ),
        ),
      );
    }

    return SettingsDetailScaffold(
      title: 'Subscription',
      body: SettingsPanel(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPro ? 'Panta Pro is active.' : 'Panta Pro is not active.',
              style: theme.textBody,
            ),
            if (isPro && expirationDate != null) ...[
              SizedBox(height: theme.spacingXs),
              Text(
                'Renews or expires $expirationDate.',
                style: theme.textBody.copyWith(color: theme.colorTextSecondary),
              ),
            ],
            SizedBox(height: theme.spacingMd),
            if (!isPro)
              AppButton(
                label: 'Upgrade to Panta Pro',
                onPressed: _busy ? null : _presentPaywall,
              ),
            if (isPro) ...[
              AppButton(
                label: 'Manage subscription',
                variant: AppButtonVariant.secondary,
                onPressed: _busy ? null : _presentCustomerCenter,
              ),
              SizedBox(height: theme.spacingSm),
            ],
            AppButton(
              label: 'Restore purchases',
              variant: AppButtonVariant.secondary,
              onPressed: _busy ? null : _restorePurchases,
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
