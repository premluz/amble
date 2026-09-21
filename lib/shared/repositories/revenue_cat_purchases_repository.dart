import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../core/revenue_cat_config.dart';
import 'purchases_repository.dart';

/// Real [PurchasesRepository] implementation, wrapping the RevenueCat SDK.
/// The only file in this app allowed to import `Purchases`/`RevenueCatUI`
/// directly outside tests — see [PurchasesRepository]'s own doc comment.
class RevenueCatPurchasesRepository implements PurchasesRepository {
  @override
  Future<bool> configure() async {
    // No key for this build (an unsupported platform, or a run without the
    // --dart-defines) — report "not configured" and let the caller carry
    // on without purchases, rather than throwing before `runApp` and
    // taking the whole app down with it. See RevenueCatConfig's own
    // doc comment.
    final key = RevenueCatConfig.keyForCurrentPlatformOrNull;
    if (key == null) return false;

    // isConfigured guards against a hot-restart or a second call
    // re-running configure() with a fresh appUserID, which RevenueCat
    // treats as a login change.
    if (await Purchases.isConfigured) return true;
    await Purchases.configure(PurchasesConfiguration(key));
    return true;
  }

  @override
  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  @override
  void addCustomerInfoUpdateListener(CustomerInfoUpdateListener listener) =>
      Purchases.addCustomerInfoUpdateListener(listener);

  @override
  void removeCustomerInfoUpdateListener(CustomerInfoUpdateListener listener) =>
      Purchases.removeCustomerInfoUpdateListener(listener);

  @override
  Future<PaywallResult> presentPaywallIfNeeded(String entitlementId) =>
      RevenueCatUI.presentPaywallIfNeeded(entitlementId);

  @override
  Future<void> presentCustomerCenter() => RevenueCatUI.presentCustomerCenter();

  @override
  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();
}
