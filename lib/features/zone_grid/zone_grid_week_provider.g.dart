// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zone_grid_week_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Monday of the week the grid displays. Screen-local, ephemeral —
/// same reasoning as `selected_date_provider.dart`: the grid always opens
/// on the CURRENT week (not a persisted "last viewed week"), so a returning
/// user never reopens onto a stale one.
///
/// Monday, not Sunday — `AppCalendarHeader`'s own week grid starts on
/// Sunday (matching the reference screenshot it was built from), but this
/// screen's own mockup showed M/T/W/T/F/S/S, so it anchors to Monday
/// instead. The two week-starts are independent by design: this screen
/// has no relationship to the Timeline's own day-strip.

@ProviderFor(ZoneGridWeek)
final zoneGridWeekProvider = ZoneGridWeekProvider._();

/// The Monday of the week the grid displays. Screen-local, ephemeral —
/// same reasoning as `selected_date_provider.dart`: the grid always opens
/// on the CURRENT week (not a persisted "last viewed week"), so a returning
/// user never reopens onto a stale one.
///
/// Monday, not Sunday — `AppCalendarHeader`'s own week grid starts on
/// Sunday (matching the reference screenshot it was built from), but this
/// screen's own mockup showed M/T/W/T/F/S/S, so it anchors to Monday
/// instead. The two week-starts are independent by design: this screen
/// has no relationship to the Timeline's own day-strip.
final class ZoneGridWeekProvider
    extends $NotifierProvider<ZoneGridWeek, DateTime> {
  /// The Monday of the week the grid displays. Screen-local, ephemeral —
  /// same reasoning as `selected_date_provider.dart`: the grid always opens
  /// on the CURRENT week (not a persisted "last viewed week"), so a returning
  /// user never reopens onto a stale one.
  ///
  /// Monday, not Sunday — `AppCalendarHeader`'s own week grid starts on
  /// Sunday (matching the reference screenshot it was built from), but this
  /// screen's own mockup showed M/T/W/T/F/S/S, so it anchors to Monday
  /// instead. The two week-starts are independent by design: this screen
  /// has no relationship to the Timeline's own day-strip.
  ZoneGridWeekProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoneGridWeekProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoneGridWeekHash();

  @$internal
  @override
  ZoneGridWeek create() => ZoneGridWeek();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$zoneGridWeekHash() => r'080b80271dea50918afd223dff7cfa306cde7b98';

/// The Monday of the week the grid displays. Screen-local, ephemeral —
/// same reasoning as `selected_date_provider.dart`: the grid always opens
/// on the CURRENT week (not a persisted "last viewed week"), so a returning
/// user never reopens onto a stale one.
///
/// Monday, not Sunday — `AppCalendarHeader`'s own week grid starts on
/// Sunday (matching the reference screenshot it was built from), but this
/// screen's own mockup showed M/T/W/T/F/S/S, so it anchors to Monday
/// instead. The two week-starts are independent by design: this screen
/// has no relationship to the Timeline's own day-strip.

abstract class _$ZoneGridWeek extends $Notifier<DateTime> {
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
