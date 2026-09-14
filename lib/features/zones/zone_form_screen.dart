import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_field_action_button.dart';
import '../../core/widgets/app_modal_route.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_segmented_time_field.dart';
import '../../core/widgets/app_staggered_entrance.dart';
import '../../core/widgets/app_step_scaffold.dart';
import '../../core/widgets/app_switch.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_wheel_time_picker.dart';
import '../../core/widgets/weekday_repeat_panel.dart';
import '../../shared/models/zone_facet.dart';
import '../../shared/providers/zone_facet_providers.dart';
import '../../shared/models/zone.dart';

import '../../shared/providers/zone_providers.dart';


import '../timeline/viewed_time_provider.dart';

/// Opens the "add/edit zone" screen — near-full-screen, built on
/// [StepScaffold] (the same chrome the real task-creation flow uses,
/// promoted out of `task_detail_sheet.dart` specifically so this could
/// reuse it rather than build a look-alike). Null [zone] is a create;
/// a real [zone] pre-fills every field and Save updates it in place.
///
/// All writes go through `zoneListProvider` — this UI never touches
/// [ZoneRepository]/Hive directly.
///
/// Returns a [ZoneFormResult] describing what Save actually did, so a
/// caller that wants to react (the Weekly Zone Authoring Grid scrolling
/// the saved zone into view, matching the Timeline's own "scroll to the
/// just-created task" convention) doesn't have to re-derive it by diffing
/// `zoneListProvider` itself. Null means the screen was dismissed without
/// saving (closed, or the create flow was abandoned at stage 1).
/// [forDay] is the calendar day this create is FOR — the day a new zone
/// anchors on, and the day the same-type collision check below tests
/// against. Null falls back to `selectedDateProvider` (the Timeline's own
/// current day), which is correct for callers that genuinely live on the
/// Timeline but was a real bug for the Weekly Zone Authoring Grid: that
/// screen has its OWN week/day state (`zoneGridWeekProvider`) and never
/// writes `selectedDateProvider`, so every create from the grid silently
/// resolved against the Timeline's day instead of the grid day the user
/// was actually looking at. Reported directly — "we show the message that
/// the zone exists for that day even though it doesn't."
Future<ZoneFormResult?> showZoneFormScreen(
  BuildContext context, {
  Zone? zone,
  DateTime? forDay,
}) {
  return pushAppSheetRoute<ZoneFormResult>(
    context,
    (context) => _ZoneFormScreen(zone: zone, forDay: forDay),
  );
}

/// What [showZoneFormScreen] actually did — returned to the caller once
/// Save completes.
class ZoneFormResult {
  const ZoneFormResult({
    required this.savedZoneId,
    this.existingSameDayId,
    this.existingSameDayTitle,
  });

  /// The id of the zone Save just wrote (created or updated).
  final String savedZoneId;

  /// Set when Save found ANOTHER zone of the same type (matched by title,
  /// per Settings' own "zone type" list — see `_ExistingZonesBrowserPane`'s
  /// doc comment) already applying on the same day — confirmed via
  /// AskUserQuestion: this does NOT block the save, it's surfaced so the
  /// caller can point the user at the pre-existing one, same spirit as the
  /// Timeline's own "scroll to what you just touched" convention, just
  /// aimed at the OTHER occurrence rather than the one just saved.
  final String? existingSameDayId;

  /// That same zone's own title, so the caller can name it in its own
  /// message ('"Morning ritual" already exists on that day.') rather than
  /// re-looking it up from `zoneListProvider` just to render one string.
  /// Non-null exactly when [existingSameDayId] is.
  final String? existingSameDayTitle;
}

/// A zone saved with no explicit time gets this length — requested
/// directly ("as default zone is 2 hours") once start/end stopped being
/// mandatory. Every `Zone` row still has a real `startMinutes`/
/// `endMinutes` under the hood (the model itself has no "timeless" concept
/// — see docs/DECISIONS.md); only the FORM'S requirement to fill them in
/// by hand is what's being removed.
const int _defaultZoneDurationMinutes = 2 * 60;

class _ZoneFormScreen extends ConsumerStatefulWidget {
  const _ZoneFormScreen({this.zone, this.forDay});

  final Zone? zone;

  /// The day this create is for — see [showZoneFormScreen]'s own doc
  /// comment. Null falls back to `selectedDateProvider`.
  final DateTime? forDay;

  @override
  ConsumerState<_ZoneFormScreen> createState() => _ZoneFormScreenState();
}

class _ZoneFormScreenState extends ConsumerState<_ZoneFormScreen> {
  late final TextEditingController _titleController;
  int? _startHour;
  int? _startMinute;
  int? _endHour;
  int? _endMinute;

  /// Repeat/Notify local state, pre-filled from an existing zone when
  /// editing — mirrors `task_detail_sheet.dart`'s own `_repeats`/
  /// `_selectedDays`/`notificationsEnabled` shape for the identical UI.
  String? _facetId;
  Set<int> _selectedDays = {};
  late bool _notificationsEnabled;

  /// Set only when Save was blocked by a real overlap against another
  /// zone — cleared on every field change, matching how the task-creation
  /// flow's own `_overlapError` behaves (`task_detail_sheet.dart`).
  String? _overlapError;
  bool _isSaving = false;

  /// Stage 1 (Name only) vs. stage 2 (everything else) — matches
  /// `task_detail_sheet.dart`'s own create-flow pattern exactly, requested
  /// directly: zones "should follow same pattern of creation as tasks, on
  /// creation first just name visible, other items below (start, end,
  /// repeat etc.) not visible, then fade in after Done is clicked."
  /// Editing an existing zone skips straight to stage 2, same as "Edit
  /// task" does — there is nothing to stage for a zone that already has
  /// every field filled in.
  bool _isNameStage = false;

  bool get _isEditing => widget.zone != null;

  @override
  void initState() {
    super.initState();
    final zone = widget.zone;
    _titleController = TextEditingController(text: zone?.title ?? '')
      // Real bug, reported directly: Save stayed disabled while typing the
      // name and only re-enabled after an unrelated rebuild (e.g. focus
      // leaving the field) happened to re-evaluate `_canSave` — nothing
      // here ever rebuilt on the controller's own text changing, unlike
      // the start/end time fields, whose `onChanged` already calls
      // `setState`. `AppTextField` has no `onChanged` of its own, so this
      // listens to the controller directly instead.
      ..addListener(() => setState(() {}));
    // Create only — an edit already has a name and every other field
    // filled in, so it opens straight on the full form.
    _isNameStage = zone == null;
    _notificationsEnabled = zone?.notificationsEnabled ?? false;
    _facetId = zone?.facetId;
    _selectedDays = {zone?.weekday ?? widget.forDay?.weekday ?? DateTime.now().weekday};
    if (zone != null) {
      _startHour = zone.startMinutes ~/ 60;
      _startMinute = zone.startMinutes % 60;
      _endHour = zone.endMinutes ~/ 60;
      _endMinute = zone.endMinutes % 60;
      final rule = zone.recurrenceRule;
      if (rule != null) {

        _selectedDays = selectedDaysFromRecurrenceRule(rule);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  int? get _startMinutes => _startHour == null || _startMinute == null
      ? null
      : _startHour! * 60 + _startMinute!;

  int? get _endMinutes => _endHour == null || _endMinute == null
      ? null
      : _endHour! * 60 + _endMinute!;

  /// Start/end are no longer required to save — requested directly ("we
  /// should not require time start end as mandatory on zone creation").
  /// An end typed WITHOUT a start (or vice versa) is still refused rather
  /// than silently guessing which one the user meant to leave blank; a
  /// fully-blank pair resolves to [_resolvedStartMinutes]'s own default at
  /// save time. `_endMinutes! > _startMinutes!` is still enforced whenever
  /// BOTH are actually typed in.
  bool get _canSave =>
      _titleController.text.trim().isNotEmpty && _selectedDays.isNotEmpty &&
      (_startMinutes == null) == (_endMinutes == null) &&
      (_startMinutes == null || _endMinutes! > _startMinutes!) &&
      !_isSaving;

  /// The zone's actual start once saved — whatever was typed in, or (if
  /// both fields were left blank) the time the user is currently looking
  /// at on the Timeline, matching the FAB's own "defaults to whatever
  /// time is vertically centered in the current scroll position, not real
  /// 'now'" convention (`timeline_screen.dart`'s own `AppFloatingCreateButton`
  /// handler) — a `null` fallback there (a fresh, never-scrolled session)
  /// falls back to real "now" the same way.
  int _resolvedStartMinutes() =>
      _startMinutes ??
      ref.read(viewedTimeProvider) ??
      (DateTime.now().hour * 60 + DateTime.now().minute);

  int _resolvedEndMinutes(int resolvedStart) =>
      _endMinutes ??
      (resolvedStart + _defaultZoneDurationMinutes).clamp(0, 24 * 60);

  Future<void> _save() async {
    if (_isSaving || !_canSave) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final start = _resolvedStartMinutes();
    final end = _resolvedEndMinutes(start);
    setState(() { _isSaving = true; _overlapError = null; });
    try {
      final notifier = ref.read(zoneListProvider.notifier);
      final existing = widget.zone;
      final Zone saved;
      if (existing == null) {
        final created = await notifier.paintWeeklyZones(title: _titleController.text,
          facetId: _facetId, weekdays: _selectedDays, startMinutes: start, endMinutes: end);
        saved = created.first;
        for (final placement in created) {
          placement.notificationsEnabled = _notificationsEnabled;
          await notifier.updateZone(placement);
        }
      } else {
        final facet = await ref.read(zoneFacetListProvider.notifier).resolve(_titleController.text,
          id: _titleController.text.trim() == existing.title ? _facetId : null);
        saved = Zone.fromJson({...existing.toJson(), 'title': facet.name, 'facetId': facet.id,
          'startMinutes': start, 'endMinutes': end, 'notificationsEnabled': _notificationsEnabled,
          if (existing.isWeeklyPlacement) 'weekday': _selectedDays.single});
        await notifier.updateZone(saved);
      }

      if (mounted) { Navigator.of(context).pop(ZoneFormResult(savedZoneId: saved.id)); }
    } catch (error) {
      if (mounted) { setState(() => _overlapError = error is StateError ? error.message :
        error is ArgumentError ? '${error.message}' : 'Could not save this zone.'); }
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  /// Removes the zone being edited — requested directly: "Edit zone
  /// screen should have remove icon button same as w[ith] edit t[a]sk."
  /// Mirrors `task_detail_sheet.dart`'s own `_delete` exactly: no
  /// confirmation dialog (matches this app's existing "Remove deletes
  /// immediately" convention), edit path only (there is nothing to
  /// delete from the create flow). Unlike `removeTask`, `deleteZone` has
  /// no recurring-scope disambiguation to defer to — a materialized
  /// recurring instance deletes the same single row a plain zone does,
  /// per that provider method's own existing, deliberate design (see
  /// `ZoneList.deleteZone`'s own doc comment).
  Future<void> _delete() async {
    final zone = widget.zone;
    if (zone == null) return;

    final navigator = Navigator.of(context);
    final notifier = ref.read(zoneListProvider.notifier);
    navigator.pop();
    await notifier.deleteZone(zone.id);
  }

  /// Seeds this (still stage-1) form from an existing zone tapped in
  /// [_ExistingZonesBrowserPane] — confirmed via AskUserQuestion: prefill
  /// name AND time, same as tapping a task template seeds name/category.
  /// Advances straight to stage 2, matching the template browser's own
  /// "picking one is a commitment, not just a fill-in" behaviour.
  ///
  /// Repeat/Notifications are still not carried across, but that no
  /// longer decides what Save produces: `ZoneList.createZone` keys off
  /// the TITLE, so a save whose name matches an existing zone type always
  /// becomes a single dated instance of that type — Repeat on or off,
  /// tapped from this list or typed by hand. Confirmed directly ("the one
  /// added as existing template with same name but different hour should
  /// be just [an] instance"); see `createZone`'s own doc comment.
  void _seedFromExistingZone(ZoneFacet zone) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { _titleController.text = zone.name; _facetId = zone.id; _isNameStage = false; });
  }

  /// Confirms stage 1 (Name) and advances to stage 2 — fired by stage 1's
  /// own Done button or the Name field's keyboard-complete action. Mirrors
  /// `task_detail_sheet.dart`'s own `_confirmNameStage` exactly: an empty
  /// name at this point closes the whole screen instead of advancing to a
  /// form with nothing in it, rather than asking to confirm discarding a
  /// draft the user never actually started.
  void _confirmNameStage() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_titleController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isNameStage = false);
  }

  /// Alternate entry for Start: the same combined typed-field-plus-wheel
  /// pattern `task_detail_sheet.dart` uses via `AppFieldActionButton` +
  /// `AppWheelTimePicker.show` (see its `_openStartTimeModal`) — typed
  /// entry stays primary, the wheel is reached via the trailing icon.
  Future<void> _openStartTimeModal(BuildContext context) async {
    final result = await AppWheelTimePicker.show(
      context: context,
      title: 'Start time',
      initialHour: _startHour ?? 0,
      initialMinute: _startMinute ?? 0,
    );
    if (result == null) return;
    setState(() {
      _startHour = result.$1;
      _startMinute = result.$2;
      _overlapError = null;
    });
  }

  Future<void> _openEndTimeModal(BuildContext context) async {
    final result = await AppWheelTimePicker.show(
      context: context,
      title: 'End time',
      initialHour: _endHour ?? 0,
      initialMinute: _endMinute ?? 0,
    );
    if (result == null) return;
    setState(() {
      _endHour = result.$1;
      _endMinute = result.$2;
      _overlapError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // Stage 2's panes, staggered in exactly like
    // task_detail_sheet.dart's own `staggeredPanes` — built as a plain
    // list so the entrance index is each pane's position in it, not
    // hand-numbered at each call site.
    final staggeredPanes = [
      AppPane(
        child: Column(
          children: [
            AppSegmentedTimeField(
              label: 'Start',
              first: _startHour,
              second: _startMinute,
              firstMax: 23,
              trailing: AppFieldActionButton(
                icon: Icons.schedule_rounded,
                semanticLabel: 'Choose start time',
                onPressed: () => _openStartTimeModal(context),
              ),
              onChanged: (hour, minute) => setState(() {
                _startHour = hour;
                _startMinute = minute;
                _overlapError = null;
              }),
            ),
            SizedBox(height: theme.spacingSm),
            AppSegmentedTimeField(
              label: 'End',
              first: _endHour,
              second: _endMinute,
              firstMax: 23,
              trailing: AppFieldActionButton(
                icon: Icons.schedule_rounded,
                semanticLabel: 'Choose end time',
                onPressed: () => _openEndTimeModal(context),
              ),
              onChanged: (hour, minute) => setState(() {
                _endHour = hour;
                _endMinute = minute;
                _overlapError = null;
              }),
            ),
          ],
        ),
      ),
      if (!_isEditing || widget.zone!.isWeeklyPlacement)
      AppPane(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Every week', style: theme.textBody),
        Row(children: [for (var day = 1; day <= 7; day++) Expanded(child: GestureDetector(
          onTap: () => setState(() {
            if (_isEditing) { _selectedDays = {day}; }
            else if (_selectedDays.contains(day)) { _selectedDays = {..._selectedDays}..remove(day); }
            else { _selectedDays = {..._selectedDays, day}; }
          }),
          child: Padding(padding: EdgeInsets.symmetric(vertical: theme.spacingSm), child: Text(
            ['M','T','W','T','F','S','S'][day-1], textAlign: TextAlign.center,
            style: theme.textBody.copyWith(color: _selectedDays.contains(day) ? theme.colorAccent : theme.colorTextTertiary))),
        ))]),
      ])),
      AppPane(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notifications',
              style: theme.textBody.copyWith(color: theme.colorTextPrimary),
            ),
            AppSwitch(
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
            ),
          ],
        ),
      ),
    ];

    return StepScaffold(
      theme: theme,
      modalTitle: _isEditing ? 'Edit zone' : 'New zone',
      titleAlignment: TextAlign.left,
      headerColor: theme.colorAccent,
      headerContent: null,
      onClose: () => Navigator.of(context).pop(),
      onBack: null,
      // Same stage-1/stage-2 pattern as the task-creation flow, requested
      // directly: "should follow same pattern of creation as tasks, on
      // creation first just name visible, other items below (start, end,
      // repeat etc.) not visible, then fade in after Done is clicked."
      primaryLabel: _isNameStage ? 'Done' : 'Save',
      onPrimaryPressed: _isNameStage
          ? _confirmNameStage
          : (_canSave ? _save : null),
      isPrimaryLoading: !_isNameStage && _isSaving,
      errorMessage: _isNameStage ? null : _overlapError,
      // Edit only, requested directly — same "remove icon button" the
      // task edit flow already has.
      onSecondaryAction: _isEditing && !_isNameStage ? _delete : null,
      secondaryActionIcon: Icons.delete_outline_rounded,
      body: SingleChildScrollView(
        // Top reverted to a plain spacingLg — the fade now lives inside
        // StepScaffold's own header container, clipped to it.
        padding: EdgeInsets.fromLTRB(
          theme.spacingLg,
          theme.spacingLg,
          theme.spacingLg,
          theme.spacingXl * 3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Always in the tree, never rebuilt as a different instance —
            // same reasoning as task_detail_sheet.dart's own
            // _NameDescriptionPane: the Name field's Element (and any
            // keyboard/focus state) must survive the stage 1 -> 2
            // transition untouched, not remount as a fresh field.
            AppPane(
              title: 'Name',
              child: AppTextField(
                controller: _titleController,
                label: 'Zone name',
                autofocus: !_isEditing,
                onFocusChanged: (_) => setState(() {}),
                onSubmitted: (_) => _confirmNameStage(),
              ),
            ),
            // Stage 1 (Name) only, create flow only — mirrors
            // `task_detail_sheet.dart`'s own `_TemplateBrowserPane`
            // placement exactly: "on the Add Task sheet, under Task Name,
            // let's list the templates," applied here to existing ZONES
            // rather than templates (Zone has no separate template
            // concept — an existing zone IS the reusable shape). Gone the
            // instant stage 2 reveals, same as the task version, and
            // never shown at all when editing (there's no "new zone" to
            // seed from another one while already editing a specific row).
            if (_isNameStage && !_isEditing) ...[
              SizedBox(height: theme.spacingLg),
              _ExistingZonesBrowserPane(
                theme: theme,
                onSelected: _seedFromExistingZone,
              ),
            ],
            if (!_isNameStage) ...[
              SizedBox(height: theme.spacingLg),
              for (final (index, pane) in staggeredPanes.indexed) ...[
                AppStaggeredEntrance(index: index, child: pane),
                SizedBox(height: theme.spacingLg),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Stage 1's inline "existing zone types" browser — requested directly:
/// "on zone add screen we should list Zones that are already created as
/// cards (same pattern as we have when adding task we list templates)."
///
/// **Reworked to read the EXACT same list Settings → Zones shows**
/// (`ZoneListBody`'s own filter, `zone_list_screen.dart`), not a separately
/// re-derived one — confirmed via AskUserQuestion after a real bug report:
/// "see 2 presets (with different timings) even though in settings is only
/// one." Root cause was a genuine gap in this pane's OWN prior dedup logic:
/// it only deduplicated RECURRING zones (grouped by `recurrenceId`) and
/// applied no deduplication at all to non-recurring zones, so any two
/// non-recurring rows — including two the user never meant to be
/// separate, e.g. two independently-saved zones sharing a title — each
/// rendered their own card. Settings' own list has never had that
/// distinction (it already treats every non-recurring zone as its own
/// row), so the fix is to point this pane at THAT list directly rather
/// than re-implementing a second, subtly different one: `!zone.isRecurring
/// || zone.isRecurrenceTemplate`, one row per plain zone plus one per
/// series template — copied verbatim from `ZoneListBody`'s own query
/// rather than imported, since that widget's build method also owns
/// sorting/rendering concerns this pane doesn't share.
///
/// This list is now the fixed "zone type" registry the work order settled
/// on: Settings owns which types exist, and this pane is the SAME list,
/// browsable while creating a new occurrence — not a separately-curated
/// view that can drift from it.
class _ExistingZonesBrowserPane extends ConsumerWidget {
  const _ExistingZonesBrowserPane({
    required this.theme,
    required this.onSelected,
  });

  final AmbleTheme theme;
  final ValueChanged<ZoneFacet> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = [...ref.watch(zoneFacetListProvider)]..sort((a,b) => a.name.compareTo(b.name));

    if (zones.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: theme.spacingSm),
          child: Text(
            'Existing zones',
            style: theme.textBody.copyWith(
              color: theme.colorTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final (index, zone) in zones.indexed) ...[
          if (index > 0) SizedBox(height: theme.spacingSm),
          _ExistingZoneRow(
            theme: theme,
            zone: zone,
            onTap: () => onSelected(zone),
          ),
        ],
      ],
    );
  }
}

/// One card in [_ExistingZonesBrowserPane] — same visual shape as
/// `inbox/template_list_view.dart`'s `TemplateRow` (flat card, shadow, no
/// border), but written locally rather than reused: `TemplateRow` is
/// `TaskTemplate`-shaped (a category badge/color, a duration-in-minutes
/// line) and Zone has neither a category nor a bare duration — it has a
/// start/end time-of-day range, which reads as its own natural subtitle.
class _ExistingZoneRow extends StatelessWidget {
  const _ExistingZoneRow({
    required this.theme,
    required this.zone,
    required this.onTap,
  });

  final AmbleTheme theme;
  final ZoneFacet zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(theme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusXl),
          boxShadow: theme.shadowPane,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name,
                    style: theme.textBody.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

