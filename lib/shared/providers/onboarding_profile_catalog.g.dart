// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_profile_catalog.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Parses [onboardingProfileCatalogAssetPath] into the list of
/// [OnboardingProfile]s the quiz scores against and the browse-all-profiles
/// screen lists. `keepAlive: true` — this is fixed, bundled content read
/// once per app session, not screen-scoped state; re-parsing it on every
/// screen visit would be wasted work for data that can never change
/// without a new app release.

@ProviderFor(onboardingProfileCatalog)
final onboardingProfileCatalogProvider = OnboardingProfileCatalogProvider._();

/// Parses [onboardingProfileCatalogAssetPath] into the list of
/// [OnboardingProfile]s the quiz scores against and the browse-all-profiles
/// screen lists. `keepAlive: true` — this is fixed, bundled content read
/// once per app session, not screen-scoped state; re-parsing it on every
/// screen visit would be wasted work for data that can never change
/// without a new app release.

final class OnboardingProfileCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<OnboardingProfile>>,
          List<OnboardingProfile>,
          FutureOr<List<OnboardingProfile>>
        >
    with
        $FutureModifier<List<OnboardingProfile>>,
        $FutureProvider<List<OnboardingProfile>> {
  /// Parses [onboardingProfileCatalogAssetPath] into the list of
  /// [OnboardingProfile]s the quiz scores against and the browse-all-profiles
  /// screen lists. `keepAlive: true` — this is fixed, bundled content read
  /// once per app session, not screen-scoped state; re-parsing it on every
  /// screen visit would be wasted work for data that can never change
  /// without a new app release.
  OnboardingProfileCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingProfileCatalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingProfileCatalogHash();

  @$internal
  @override
  $FutureProviderElement<List<OnboardingProfile>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<OnboardingProfile>> create(Ref ref) {
    return onboardingProfileCatalog(ref);
  }
}

String _$onboardingProfileCatalogHash() =>
    r'959dd0481553c51b58878f9f1b40dab0566dfcdf';
