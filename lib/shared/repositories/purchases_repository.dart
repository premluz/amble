import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'
    show PaywallResult;

/// Wraps the RevenueCat SDK's global static [Purchases] API behind an
/// instance interface, mirroring [SyncedCalendarEventRepository]'s
/// "external source of truth, not a Hive box" shape rather than
/// [PreferencesRepository]'s key-value shape — RevenueCat, not Hive, owns
/// this data. UI and state never call `Purchases`/`RevenueCatUI` directly,
/// same "never call the underlying SDK outside the repository layer" rule
/// CONSTITUTION.md applies to Hive.
abstract class PurchasesRepository {
  /// Configures the SDK. Must be called once, before any other method here,
  /// per RevenueCat's own docs. A no-op if already configured for this
  /// `appUserID`.
  ///
  /// Returns whether purchases are actually usable in this build: false
  /// when there is no API key for the running platform (an unsupported
  /// platform, or a build without the `--dart-define`s). Callers must
  /// skip every other method on this repository when it returns false —
  /// the SDK is unconfigured and they would throw.
  Future<bool> configure();

  /// The current customer's entitlements/purchase state, fetched fresh from
  /// RevenueCat (which itself caches and network-syncs).
  Future<CustomerInfo> getCustomerInfo();

  /// Registers [listener] to be called whenever [CustomerInfo] changes —
  /// renewals, expirations, restores, or a purchase completed elsewhere.
  /// The real, ongoing feed; [getCustomerInfo] alone is a one-shot read.
  void addCustomerInfoUpdateListener(CustomerInfoUpdateListener listener);

  void removeCustomerInfoUpdateListener(CustomerInfoUpdateListener listener);

  /// Presents RevenueCat's prebuilt paywall (configured in the dashboard)
  /// unless [entitlementId] is already active, in which case nothing is
  /// shown and [PaywallResult.notPresented] is returned.
  Future<PaywallResult> presentPaywallIfNeeded(String entitlementId);

  /// Presents RevenueCat's prebuilt Customer Center for self-serve
  /// cancel/refund/plan-change.
  Future<void> presentCustomerCenter();

  /// Restores previous purchases for the current store account (App
  /// Store/Play Store), returning the resulting [CustomerInfo].
  Future<CustomerInfo> restorePurchases();
}
