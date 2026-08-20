// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_date_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The day currently shown on the Timeline screen. Screen-local UI state,
/// not app-level — lives under features/timeline/, not shared/providers/,
/// per the distinction drawn in docs/DECISIONS.md (Phase 1).

@ProviderFor(SelectedDate)
final selectedDateProvider = SelectedDateProvider._();

/// The day currently shown on the Timeline screen. Screen-local UI state,
/// not app-level — lives under features/timeline/, not shared/providers/,
/// per the distinction drawn in docs/DECISIONS.md (Phase 1).
final class SelectedDateProvider
    extends $NotifierProvider<SelectedDate, DateTime> {
  /// The day currently shown on the Timeline screen. Screen-local UI state,
  /// not app-level — lives under features/timeline/, not shared/providers/,
  /// per the distinction drawn in docs/DECISIONS.md (Phase 1).
  SelectedDateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedDateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedDateHash();

  @$internal
  @override
  SelectedDate create() => SelectedDate();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$selectedDateHash() => r'7756310ea660f31d20b5ac946cbf731232ebc7a9';

/// The day currently shown on the Timeline screen. Screen-local UI state,
/// not app-level — lives under features/timeline/, not shared/providers/,
/// per the distinction drawn in docs/DECISIONS.md (Phase 1).

abstract class _$SelectedDate extends $Notifier<DateTime> {
  DateTime build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime, DateTime>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime, DateTime>,
              DateTime,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
