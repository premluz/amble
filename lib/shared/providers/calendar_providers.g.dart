// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-lifetime singleton, same reasoning as `notificationServiceProvider`
/// — one plugin instance, one permission-request lifecycle for the whole
/// session.

@ProviderFor(deviceCalendarPlugin)
final deviceCalendarPluginProvider = DeviceCalendarPluginProvider._();

/// App-lifetime singleton, same reasoning as `notificationServiceProvider`
/// — one plugin instance, one permission-request lifecycle for the whole
/// session.

final class DeviceCalendarPluginProvider
    extends
        $FunctionalProvider<
          dc.DeviceCalendarPlugin,
          dc.DeviceCalendarPlugin,
          dc.DeviceCalendarPlugin
        >
    with $Provider<dc.DeviceCalendarPlugin> {
  /// App-lifetime singleton, same reasoning as `notificationServiceProvider`
  /// — one plugin instance, one permission-request lifecycle for the whole
  /// session.
  DeviceCalendarPluginProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceCalendarPluginProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceCalendarPluginHash();

  @$internal
  @override
  $ProviderElement<dc.DeviceCalendarPlugin> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  dc.DeviceCalendarPlugin create(Ref ref) {
    return deviceCalendarPlugin(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(dc.DeviceCalendarPlugin value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<dc.DeviceCalendarPlugin>(value),
    );
  }
}

String _$deviceCalendarPluginHash() =>
    r'b01aa2e886f54f03e855802e0c6875004e424765';

@ProviderFor(calendarPermissionService)
final calendarPermissionServiceProvider = CalendarPermissionServiceProvider._();

final class CalendarPermissionServiceProvider
    extends
        $FunctionalProvider<
          CalendarPermissionService,
          CalendarPermissionService,
          CalendarPermissionService
        >
    with $Provider<CalendarPermissionService> {
  CalendarPermissionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarPermissionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarPermissionServiceHash();

  @$internal
  @override
  $ProviderElement<CalendarPermissionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CalendarPermissionService create(Ref ref) {
    return calendarPermissionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarPermissionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarPermissionService>(value),
    );
  }
}

String _$calendarPermissionServiceHash() =>
    r'60f24777a97525d4be3cac4ccf20b0b94de08822';

@ProviderFor(systemSettingsService)
final systemSettingsServiceProvider = SystemSettingsServiceProvider._();

final class SystemSettingsServiceProvider
    extends
        $FunctionalProvider<
          SystemSettingsService,
          SystemSettingsService,
          SystemSettingsService
        >
    with $Provider<SystemSettingsService> {
  SystemSettingsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemSettingsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemSettingsServiceHash();

  @$internal
  @override
  $ProviderElement<SystemSettingsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SystemSettingsService create(Ref ref) {
    return systemSettingsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemSettingsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemSettingsService>(value),
    );
  }
}

String _$systemSettingsServiceHash() =>
    r'bce1c6daae7d9dda6ffd2f1aa9f1387912ffd631';

@ProviderFor(syncedCalendarEventRepository)
final syncedCalendarEventRepositoryProvider =
    SyncedCalendarEventRepositoryProvider._();

final class SyncedCalendarEventRepositoryProvider
    extends
        $FunctionalProvider<
          SyncedCalendarEventRepository,
          SyncedCalendarEventRepository,
          SyncedCalendarEventRepository
        >
    with $Provider<SyncedCalendarEventRepository> {
  SyncedCalendarEventRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncedCalendarEventRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncedCalendarEventRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncedCalendarEventRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncedCalendarEventRepository create(Ref ref) {
    return syncedCalendarEventRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncedCalendarEventRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncedCalendarEventRepository>(
        value,
      ),
    );
  }
}

String _$syncedCalendarEventRepositoryHash() =>
    r'9b7f15f987a69fb138512aec4b62502ff7f3fb21';

@ProviderFor(externalCalendarService)
final externalCalendarServiceProvider = ExternalCalendarServiceProvider._();

final class ExternalCalendarServiceProvider
    extends
        $FunctionalProvider<
          ExternalCalendarService,
          ExternalCalendarService,
          ExternalCalendarService
        >
    with $Provider<ExternalCalendarService> {
  ExternalCalendarServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'externalCalendarServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$externalCalendarServiceHash();

  @$internal
  @override
  $ProviderElement<ExternalCalendarService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExternalCalendarService create(Ref ref) {
    return externalCalendarService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExternalCalendarService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExternalCalendarService>(value),
    );
  }
}

String _$externalCalendarServiceHash() =>
    r'a8cdd58c5597f885d57a9c4154a3c7fc99ee3363';

@ProviderFor(calendarSyncService)
final calendarSyncServiceProvider = CalendarSyncServiceProvider._();

final class CalendarSyncServiceProvider
    extends
        $FunctionalProvider<
          CalendarSyncService,
          CalendarSyncService,
          CalendarSyncService
        >
    with $Provider<CalendarSyncService> {
  CalendarSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarSyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarSyncServiceHash();

  @$internal
  @override
  $ProviderElement<CalendarSyncService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CalendarSyncService create(Ref ref) {
    return calendarSyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarSyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarSyncService>(value),
    );
  }
}

String _$calendarSyncServiceHash() =>
    r'6b982e418cd281ef40c6d44952305be718b64f29';

/// Bumped by "Refresh events" (Settings › Calendars). Every calendar event
/// fetch watches it, so one press re-reads the device calendars for every
/// open view. Without it a fetch made earlier (before access was granted,
/// or before an event was added in the Calendar app) stays on screen until
/// the day changes or the app restarts.

@ProviderFor(ExternalCalendarRefresh)
final externalCalendarRefreshProvider = ExternalCalendarRefreshProvider._();

/// Bumped by "Refresh events" (Settings › Calendars). Every calendar event
/// fetch watches it, so one press re-reads the device calendars for every
/// open view. Without it a fetch made earlier (before access was granted,
/// or before an event was added in the Calendar app) stays on screen until
/// the day changes or the app restarts.
final class ExternalCalendarRefreshProvider
    extends $NotifierProvider<ExternalCalendarRefresh, int> {
  /// Bumped by "Refresh events" (Settings › Calendars). Every calendar event
  /// fetch watches it, so one press re-reads the device calendars for every
  /// open view. Without it a fetch made earlier (before access was granted,
  /// or before an event was added in the Calendar app) stays on screen until
  /// the day changes or the app restarts.
  ExternalCalendarRefreshProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'externalCalendarRefreshProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$externalCalendarRefreshHash();

  @$internal
  @override
  ExternalCalendarRefresh create() => ExternalCalendarRefresh();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$externalCalendarRefreshHash() =>
    r'5aebd5b2db9201c3b65ed3a593b2893f9e7a33a1';

/// Bumped by "Refresh events" (Settings › Calendars). Every calendar event
/// fetch watches it, so one press re-reads the device calendars for every
/// open view. Without it a fetch made earlier (before access was granted,
/// or before an event was added in the Calendar app) stays on screen until
/// the day changes or the app restarts.

abstract class _$ExternalCalendarRefresh extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Every calendar on the device, for the two Settings pickers (display
/// multi-select, sync-target single-select) — a plain `autoDispose` future
/// provider, not `keepAlive`: this is Settings-screen-scoped lookup data,
/// re-fetched fresh each time Settings is opened, unlike the session-long
/// state the other providers in this file hold.

@ProviderFor(availableDeviceCalendars)
final availableDeviceCalendarsProvider = AvailableDeviceCalendarsProvider._();

/// Every calendar on the device, for the two Settings pickers (display
/// multi-select, sync-target single-select) — a plain `autoDispose` future
/// provider, not `keepAlive`: this is Settings-screen-scoped lookup data,
/// re-fetched fresh each time Settings is opened, unlike the session-long
/// state the other providers in this file hold.

final class AvailableDeviceCalendarsProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeviceCalendarsState>,
          DeviceCalendarsState,
          FutureOr<DeviceCalendarsState>
        >
    with
        $FutureModifier<DeviceCalendarsState>,
        $FutureProvider<DeviceCalendarsState> {
  /// Every calendar on the device, for the two Settings pickers (display
  /// multi-select, sync-target single-select) — a plain `autoDispose` future
  /// provider, not `keepAlive`: this is Settings-screen-scoped lookup data,
  /// re-fetched fresh each time Settings is opened, unlike the session-long
  /// state the other providers in this file hold.
  AvailableDeviceCalendarsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'availableDeviceCalendarsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$availableDeviceCalendarsHash();

  @$internal
  @override
  $FutureProviderElement<DeviceCalendarsState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeviceCalendarsState> create(Ref ref) {
    return availableDeviceCalendars(ref);
  }
}

String _$availableDeviceCalendarsHash() =>
    r'ab63511d04a268e331f9b38af01b0077c59b1874';

/// Fetches [ExternalCalendarEvent]s for the given day range from whichever
/// calendars [CalendarDisplayIdsSetting] selects — the Timeline's own
/// read path for Feature 1. `autoDispose`, family-keyed by the exact range
/// requested: this is a per-load fetch, not session state to keep alive,
/// and the Timeline re-requests it on every day-range change/refresh.
///
/// Excludes any device event Amble itself pushed via Feature 2's manual
/// sync-out — otherwise a task synced to a calendar the user also chose to
/// DISPLAY would render twice (the real Amble task capsule, plus a
/// read-only "external" duplicate of the very event Amble just created).
/// Reported directly: "when pushed Amble task to local calendar we
/// shouldn't show that task as 'pulled' from local calendar, otherwise
/// it's duplication." See [ExternalCalendarService.fetchEvents]'s own doc
/// comment for why this stays a pure read-side filter rather than any
/// coupling between the two services.

@ProviderFor(externalCalendarEventsForRange)
final externalCalendarEventsForRangeProvider =
    ExternalCalendarEventsForRangeFamily._();

/// Fetches [ExternalCalendarEvent]s for the given day range from whichever
/// calendars [CalendarDisplayIdsSetting] selects — the Timeline's own
/// read path for Feature 1. `autoDispose`, family-keyed by the exact range
/// requested: this is a per-load fetch, not session state to keep alive,
/// and the Timeline re-requests it on every day-range change/refresh.
///
/// Excludes any device event Amble itself pushed via Feature 2's manual
/// sync-out — otherwise a task synced to a calendar the user also chose to
/// DISPLAY would render twice (the real Amble task capsule, plus a
/// read-only "external" duplicate of the very event Amble just created).
/// Reported directly: "when pushed Amble task to local calendar we
/// shouldn't show that task as 'pulled' from local calendar, otherwise
/// it's duplication." See [ExternalCalendarService.fetchEvents]'s own doc
/// comment for why this stays a pure read-side filter rather than any
/// coupling between the two services.

final class ExternalCalendarEventsForRangeProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ExternalCalendarEvent>>,
          List<ExternalCalendarEvent>,
          FutureOr<List<ExternalCalendarEvent>>
        >
    with
        $FutureModifier<List<ExternalCalendarEvent>>,
        $FutureProvider<List<ExternalCalendarEvent>> {
  /// Fetches [ExternalCalendarEvent]s for the given day range from whichever
  /// calendars [CalendarDisplayIdsSetting] selects — the Timeline's own
  /// read path for Feature 1. `autoDispose`, family-keyed by the exact range
  /// requested: this is a per-load fetch, not session state to keep alive,
  /// and the Timeline re-requests it on every day-range change/refresh.
  ///
  /// Excludes any device event Amble itself pushed via Feature 2's manual
  /// sync-out — otherwise a task synced to a calendar the user also chose to
  /// DISPLAY would render twice (the real Amble task capsule, plus a
  /// read-only "external" duplicate of the very event Amble just created).
  /// Reported directly: "when pushed Amble task to local calendar we
  /// shouldn't show that task as 'pulled' from local calendar, otherwise
  /// it's duplication." See [ExternalCalendarService.fetchEvents]'s own doc
  /// comment for why this stays a pure read-side filter rather than any
  /// coupling between the two services.
  ExternalCalendarEventsForRangeProvider._({
    required ExternalCalendarEventsForRangeFamily super.from,
    required (DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'externalCalendarEventsForRangeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$externalCalendarEventsForRangeHash();

  @override
  String toString() {
    return r'externalCalendarEventsForRangeProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<ExternalCalendarEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ExternalCalendarEvent>> create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime);
    return externalCalendarEventsForRange(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ExternalCalendarEventsForRangeProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$externalCalendarEventsForRangeHash() =>
    r'd32a3ae87475b77adb0b9445d23c5cb14abf9f41';

/// Fetches [ExternalCalendarEvent]s for the given day range from whichever
/// calendars [CalendarDisplayIdsSetting] selects — the Timeline's own
/// read path for Feature 1. `autoDispose`, family-keyed by the exact range
/// requested: this is a per-load fetch, not session state to keep alive,
/// and the Timeline re-requests it on every day-range change/refresh.
///
/// Excludes any device event Amble itself pushed via Feature 2's manual
/// sync-out — otherwise a task synced to a calendar the user also chose to
/// DISPLAY would render twice (the real Amble task capsule, plus a
/// read-only "external" duplicate of the very event Amble just created).
/// Reported directly: "when pushed Amble task to local calendar we
/// shouldn't show that task as 'pulled' from local calendar, otherwise
/// it's duplication." See [ExternalCalendarService.fetchEvents]'s own doc
/// comment for why this stays a pure read-side filter rather than any
/// coupling between the two services.

final class ExternalCalendarEventsForRangeFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ExternalCalendarEvent>>,
          (DateTime, DateTime)
        > {
  ExternalCalendarEventsForRangeFamily._()
    : super(
        retry: null,
        name: r'externalCalendarEventsForRangeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetches [ExternalCalendarEvent]s for the given day range from whichever
  /// calendars [CalendarDisplayIdsSetting] selects — the Timeline's own
  /// read path for Feature 1. `autoDispose`, family-keyed by the exact range
  /// requested: this is a per-load fetch, not session state to keep alive,
  /// and the Timeline re-requests it on every day-range change/refresh.
  ///
  /// Excludes any device event Amble itself pushed via Feature 2's manual
  /// sync-out — otherwise a task synced to a calendar the user also chose to
  /// DISPLAY would render twice (the real Amble task capsule, plus a
  /// read-only "external" duplicate of the very event Amble just created).
  /// Reported directly: "when pushed Amble task to local calendar we
  /// shouldn't show that task as 'pulled' from local calendar, otherwise
  /// it's duplication." See [ExternalCalendarService.fetchEvents]'s own doc
  /// comment for why this stays a pure read-side filter rather than any
  /// coupling between the two services.

  ExternalCalendarEventsForRangeProvider call(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => ExternalCalendarEventsForRangeProvider._(
    argument: (rangeStart, rangeEnd),
    from: this,
  );

  @override
  String toString() => r'externalCalendarEventsForRangeProvider';
}
