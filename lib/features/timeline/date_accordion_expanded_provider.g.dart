// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'date_accordion_expanded_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the week-strip under the date label is expanded — shared
/// between every [AppCalendarHeader] instance, not per-screen local state.
///
/// Reported directly: opening the days on the Timeline screen, then
/// pushing into the merged Edit screen (whose Tasks tab shows its own
/// `AppCalendarHeader`), landed back on the COLLAPSED strip — each
/// `AppCalendarHeader` mount owned its own `AppDateAccordion`, which used
/// to keep this as local `State`, so two mounts of the same widget never
/// shared it. Confirmed directly this should track ONE state across both
/// screens, and both the spatial and non-spatial (List) views on each —
/// open on one, open on the other; closed on one, closed on the other.
///
/// Same "screen-local UI state, not app-level" precedent as
/// [SelectedDate]/[EditModeEnabled] (`selected_date_provider.dart`,
/// `edit_mode_provider.dart`) — lives under `features/timeline/`, not
/// `shared/providers/` or `core/`, even though [AppDateAccordion] itself
/// (the widget this drives) stays under `core/widgets/` and generic
/// (Widgetbook, any future caller) by taking this as a plain
/// `expanded`/`onExpandedChanged` pair rather than reaching for this
/// provider directly.

@ProviderFor(DateAccordionExpanded)
final dateAccordionExpandedProvider = DateAccordionExpandedProvider._();

/// Whether the week-strip under the date label is expanded — shared
/// between every [AppCalendarHeader] instance, not per-screen local state.
///
/// Reported directly: opening the days on the Timeline screen, then
/// pushing into the merged Edit screen (whose Tasks tab shows its own
/// `AppCalendarHeader`), landed back on the COLLAPSED strip — each
/// `AppCalendarHeader` mount owned its own `AppDateAccordion`, which used
/// to keep this as local `State`, so two mounts of the same widget never
/// shared it. Confirmed directly this should track ONE state across both
/// screens, and both the spatial and non-spatial (List) views on each —
/// open on one, open on the other; closed on one, closed on the other.
///
/// Same "screen-local UI state, not app-level" precedent as
/// [SelectedDate]/[EditModeEnabled] (`selected_date_provider.dart`,
/// `edit_mode_provider.dart`) — lives under `features/timeline/`, not
/// `shared/providers/` or `core/`, even though [AppDateAccordion] itself
/// (the widget this drives) stays under `core/widgets/` and generic
/// (Widgetbook, any future caller) by taking this as a plain
/// `expanded`/`onExpandedChanged` pair rather than reaching for this
/// provider directly.
final class DateAccordionExpandedProvider
    extends $NotifierProvider<DateAccordionExpanded, bool> {
  /// Whether the week-strip under the date label is expanded — shared
  /// between every [AppCalendarHeader] instance, not per-screen local state.
  ///
  /// Reported directly: opening the days on the Timeline screen, then
  /// pushing into the merged Edit screen (whose Tasks tab shows its own
  /// `AppCalendarHeader`), landed back on the COLLAPSED strip — each
  /// `AppCalendarHeader` mount owned its own `AppDateAccordion`, which used
  /// to keep this as local `State`, so two mounts of the same widget never
  /// shared it. Confirmed directly this should track ONE state across both
  /// screens, and both the spatial and non-spatial (List) views on each —
  /// open on one, open on the other; closed on one, closed on the other.
  ///
  /// Same "screen-local UI state, not app-level" precedent as
  /// [SelectedDate]/[EditModeEnabled] (`selected_date_provider.dart`,
  /// `edit_mode_provider.dart`) — lives under `features/timeline/`, not
  /// `shared/providers/` or `core/`, even though [AppDateAccordion] itself
  /// (the widget this drives) stays under `core/widgets/` and generic
  /// (Widgetbook, any future caller) by taking this as a plain
  /// `expanded`/`onExpandedChanged` pair rather than reaching for this
  /// provider directly.
  DateAccordionExpandedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dateAccordionExpandedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dateAccordionExpandedHash();

  @$internal
  @override
  DateAccordionExpanded create() => DateAccordionExpanded();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$dateAccordionExpandedHash() =>
    r'8a43359511a0768baa5138599f85a370cd1dc5d2';

/// Whether the week-strip under the date label is expanded — shared
/// between every [AppCalendarHeader] instance, not per-screen local state.
///
/// Reported directly: opening the days on the Timeline screen, then
/// pushing into the merged Edit screen (whose Tasks tab shows its own
/// `AppCalendarHeader`), landed back on the COLLAPSED strip — each
/// `AppCalendarHeader` mount owned its own `AppDateAccordion`, which used
/// to keep this as local `State`, so two mounts of the same widget never
/// shared it. Confirmed directly this should track ONE state across both
/// screens, and both the spatial and non-spatial (List) views on each —
/// open on one, open on the other; closed on one, closed on the other.
///
/// Same "screen-local UI state, not app-level" precedent as
/// [SelectedDate]/[EditModeEnabled] (`selected_date_provider.dart`,
/// `edit_mode_provider.dart`) — lives under `features/timeline/`, not
/// `shared/providers/` or `core/`, even though [AppDateAccordion] itself
/// (the widget this drives) stays under `core/widgets/` and generic
/// (Widgetbook, any future caller) by taking this as a plain
/// `expanded`/`onExpandedChanged` pair rather than reaching for this
/// provider directly.

abstract class _$DateAccordionExpanded extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
