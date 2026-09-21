// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchases_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(purchasesRepository)
final purchasesRepositoryProvider = PurchasesRepositoryProvider._();

final class PurchasesRepositoryProvider
    extends
        $FunctionalProvider<
          PurchasesRepository,
          PurchasesRepository,
          PurchasesRepository
        >
    with $Provider<PurchasesRepository> {
  PurchasesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchasesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchasesRepositoryHash();

  @$internal
  @override
  $ProviderElement<PurchasesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PurchasesRepository create(Ref ref) {
    return purchasesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PurchasesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PurchasesRepository>(value),
    );
  }
}

String _$purchasesRepositoryHash() =>
    r'fb5201dd37853f8be1b558e3fcbdb6c8ecedb543';

/// The current [CustomerInfo], kept live via RevenueCat's own
/// update-listener feed rather than a one-shot fetch — reflects renewals,
/// expirations, and purchases/restores made elsewhere in the app.
///
/// `keepAlive: true`: this must survive independent of any one screen
/// watching it, matching every other cross-cutting setting in
/// `preferences_providers.dart`. Starts null until [configure] in
/// `main.dart` has resolved the first [Purchases.getCustomerInfo] call.

@ProviderFor(PantaCustomerInfo)
final pantaCustomerInfoProvider = PantaCustomerInfoProvider._();

/// The current [CustomerInfo], kept live via RevenueCat's own
/// update-listener feed rather than a one-shot fetch — reflects renewals,
/// expirations, and purchases/restores made elsewhere in the app.
///
/// `keepAlive: true`: this must survive independent of any one screen
/// watching it, matching every other cross-cutting setting in
/// `preferences_providers.dart`. Starts null until [configure] in
/// `main.dart` has resolved the first [Purchases.getCustomerInfo] call.
final class PantaCustomerInfoProvider
    extends $NotifierProvider<PantaCustomerInfo, CustomerInfo?> {
  /// The current [CustomerInfo], kept live via RevenueCat's own
  /// update-listener feed rather than a one-shot fetch — reflects renewals,
  /// expirations, and purchases/restores made elsewhere in the app.
  ///
  /// `keepAlive: true`: this must survive independent of any one screen
  /// watching it, matching every other cross-cutting setting in
  /// `preferences_providers.dart`. Starts null until [configure] in
  /// `main.dart` has resolved the first [Purchases.getCustomerInfo] call.
  PantaCustomerInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pantaCustomerInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pantaCustomerInfoHash();

  @$internal
  @override
  PantaCustomerInfo create() => PantaCustomerInfo();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerInfo? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerInfo?>(value),
    );
  }
}

String _$pantaCustomerInfoHash() => r'ee8be4f9b478121655d7d0959809e6e5e2ef11f6';

/// The current [CustomerInfo], kept live via RevenueCat's own
/// update-listener feed rather than a one-shot fetch — reflects renewals,
/// expirations, and purchases/restores made elsewhere in the app.
///
/// `keepAlive: true`: this must survive independent of any one screen
/// watching it, matching every other cross-cutting setting in
/// `preferences_providers.dart`. Starts null until [configure] in
/// `main.dart` has resolved the first [Purchases.getCustomerInfo] call.

abstract class _$PantaCustomerInfo extends $Notifier<CustomerInfo?> {
  CustomerInfo? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CustomerInfo?, CustomerInfo?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CustomerInfo?, CustomerInfo?>,
              CustomerInfo?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the current customer has an active `panta_pro` entitlement.
/// This — not a product id — is the correct check per RevenueCat's own
/// guidance: entitlements survive product renames/repricing that a raw
/// product-id check would not.

@ProviderFor(isPantaPro)
final isPantaProProvider = IsPantaProProvider._();

/// Whether the current customer has an active `panta_pro` entitlement.
/// This — not a product id — is the correct check per RevenueCat's own
/// guidance: entitlements survive product renames/repricing that a raw
/// product-id check would not.

final class IsPantaProProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the current customer has an active `panta_pro` entitlement.
  /// This — not a product id — is the correct check per RevenueCat's own
  /// guidance: entitlements survive product renames/repricing that a raw
  /// product-id check would not.
  IsPantaProProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isPantaProProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isPantaProHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isPantaPro(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isPantaProHash() => r'91df8f62bbddd578e17d12fd867073e29bc5332f';
