import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/revenue_cat_config.dart';
import '../repositories/purchases_repository.dart';
import '../repositories/revenue_cat_purchases_repository.dart';

part 'purchases_providers.g.dart';

@Riverpod(keepAlive: true)
PurchasesRepository purchasesRepository(Ref ref) {
  return RevenueCatPurchasesRepository();
}

/// The current [CustomerInfo], kept live via RevenueCat's own
/// update-listener feed rather than a one-shot fetch — reflects renewals,
/// expirations, and purchases/restores made elsewhere in the app.
///
/// `keepAlive: true`: this must survive independent of any one screen
/// watching it, matching every other cross-cutting setting in
/// `preferences_providers.dart`. Starts null until [configure] in
/// `main.dart` has resolved the first [Purchases.getCustomerInfo] call.
@Riverpod(keepAlive: true)
class PantaCustomerInfo extends _$PantaCustomerInfo {
  CustomerInfoUpdateListener? _listener;

  @override
  CustomerInfo? build() {
    final repository = ref.read(purchasesRepositoryProvider);
    _listener = (info) => state = info;
    repository.addCustomerInfoUpdateListener(_listener!);
    ref.onDispose(() {
      final currentListener = _listener;
      if (currentListener != null) {
        repository.removeCustomerInfoUpdateListener(currentListener);
      }
    });
    return null;
  }

  /// Fetches the current [CustomerInfo] once and stores it, called from
  /// `main.dart` right after `Purchases.configure` so the first frame
  /// already has real entitlement data rather than waiting for the first
  /// listener callback (which only fires on a subsequent change).
  Future<void> refresh() async {
    final repository = ref.read(purchasesRepositoryProvider);
    state = await repository.getCustomerInfo();
  }
}

/// Whether the current customer has an active `panta_pro` entitlement.
/// This — not a product id — is the correct check per RevenueCat's own
/// guidance: entitlements survive product renames/repricing that a raw
/// product-id check would not.
@riverpod
bool isPantaPro(Ref ref) {
  final info = ref.watch(pantaCustomerInfoProvider);
  return info?.entitlements.active.containsKey(
        RevenueCatConfig.pantaProEntitlementId,
      ) ??
      false;
}
