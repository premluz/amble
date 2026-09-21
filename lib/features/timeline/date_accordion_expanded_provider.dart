import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'date_accordion_expanded_provider.g.dart';

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
@riverpod
class DateAccordionExpanded extends _$DateAccordionExpanded {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
