import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_field_action_button.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_segmented_time_field.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_wheel_time_picker.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/zone_providers.dart';

/// Bulk edit for 2+ zone occurrences selected on the Weekly Zone
/// Authoring Grid — the zone counterpart of `showMultiTaskEditSheet`
/// (`features/task_detail/multi_task_edit_sheet.dart`), requested
/// directly: "similar for zones but here we can change times start end
/// date, and name." Covers Name, Start, End, and Date only — the same
/// "narrower than the single-item form" posture the task version takes,
/// since a zone occurrence's other fields (recurrence linkage, facet)
/// have no coherent bulk-edit meaning.
///
/// **Same "Mixed" rule as the task version**: a field with DIFFERING
/// values across the selection shows a neutral/empty state rather than
/// defaulting to any one zone's value, and only a field the user actually
/// touches gets written to every selected zone on Save.
Future<void> showMultiZoneEditSheet(
  BuildContext context, {
  required List<String> zoneIds,
}) {
  return AppSheet.show<void>(
    context: context,
    size: AppSheetSize.half,
    builder: (context) => _MultiZoneEditForm(zoneIds: zoneIds),
  );
}

class _MultiZoneEditForm extends ConsumerStatefulWidget {
  const _MultiZoneEditForm({required this.zoneIds});

  final List<String> zoneIds;

  @override
  ConsumerState<_MultiZoneEditForm> createState() =>
      _MultiZoneEditFormState();
}

class _MultiZoneEditFormState extends ConsumerState<_MultiZoneEditForm> {
  late final TextEditingController _titleController;
  bool _titleTouched = false;

  int? _startMinutes;
  bool _startTouched = false;

  int? _endMinutes;
  bool _endTouched = false;

  DateTime? _anchorDate;
  bool _dateTouched = false;

  bool _isSaving = false;

  /// Set only when `updateZone` throws (an invalid resulting time range)
  /// — see [_save]'s own doc comment.
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  List<Zone> get _zones => widget.zoneIds
      .map(
        (id) => ref
            .read(zoneListProvider)
            .where((z) => z.id == id)
            .firstOrNull,
      )
      .whereType<Zone>()
      .toList();

  /// The one shared value across the selection for [selector], or null if
  /// the zones differ — the "Mixed" trigger for every field below. Same
  /// shape as `multi_task_edit_sheet.dart`'s own `_commonValue`.
  T? _commonValue<T>(T? Function(Zone) selector) {
    final zones = _zones;
    if (zones.isEmpty) return null;
    final first = selector(zones.first);
    for (final zone in zones.skip(1)) {
      if (selector(zone) != first) return null;
    }
    return first;
  }

  Future<void> _pickStartTime(int? currentMinutes) async {
    final result = await AppWheelTimePicker.show(
      context: context,
      title: 'Start time',
      initialHour: (currentMinutes ?? 0) ~/ 60,
      initialMinute: (currentMinutes ?? 0) % 60,
    );
    if (result == null) return;
    setState(() {
      _startMinutes = result.$1 * 60 + result.$2;
      _startTouched = true;
    });
  }

  Future<void> _pickEndTime(int? currentMinutes) async {
    final result = await AppWheelTimePicker.show(
      context: context,
      title: 'End time',
      initialHour: (currentMinutes ?? 0) ~/ 60,
      initialMinute: (currentMinutes ?? 0) % 60,
    );
    if (result == null) return;
    setState(() {
      _endMinutes = result.$1 * 60 + result.$2;
      _endTouched = true;
    });
  }

  Future<void> _pickDate(DateTime? currentDate) async {
    // Same showDatePicker config task_detail_sheet.dart's own `_pickDate`
    // uses — the app's one date-picking convention, per direct
    // confirmation ("same as in add zone").
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _anchorDate = DateTime(picked.year, picked.month, picked.day);
      _dateTouched = true;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final notifier = ref.read(zoneListProvider.notifier);
      final trimmedTitle = _titleController.text.trim();
      for (final zone in _zones) {
        var changed = false;
        if (_titleTouched &&
            trimmedTitle.isNotEmpty &&
            zone.title != trimmedTitle) {
          zone.title = trimmedTitle;
          changed = true;
        }
        if (_startTouched &&
            _startMinutes != null &&
            zone.startMinutes != _startMinutes) {
          zone.startMinutes = _startMinutes!;
          changed = true;
        }
        if (_endTouched && _endMinutes != null && zone.endMinutes != _endMinutes) {
          zone.endMinutes = _endMinutes!;
          changed = true;
        }
        if (_dateTouched &&
            _anchorDate != null &&
            zone.anchorDate != _anchorDate) {
          zone.anchorDate = _anchorDate;
          changed = true;
        }
        // `updateZone` throws ArgumentError for an invalid time range
        // (e.g. a new Start left at-or-past this zone's own unchanged
        // End) — surfaced here rather than swallowed, per this app's
        // "fail loud" rule. A failure partway through the selection
        // STOPS the loop (confirmed shape: whatever already saved stays
        // saved, matching how a single-item form failure never rolls
        // back an earlier autosave either) rather than silently
        // continuing past a rejected write.
        if (changed) await notifier.updateZone(zone);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _errorMessage = error.message as String);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    final effectiveStart = _startTouched
        ? _startMinutes
        : _commonValue((z) => z.startMinutes);
    final effectiveEnd = _endTouched
        ? _endMinutes
        : _commonValue((z) => z.endMinutes);
    final effectiveDate = _dateTouched
        ? _anchorDate
        : _commonValue((z) => z.anchorDate);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AppSheet's own outer padding no longer provides a top inset
        // (2026-09-23 — "top padding should be in header").
        SizedBox(height: theme.spacingLg),
        Text('${widget.zoneIds.length} zones selected', style: theme.textTitle),
        SizedBox(height: theme.spacingMd),
        AppPane(
          child: TextField(
            key: const Key('multiZoneEditNameField'),
            controller: _titleController,
            onChanged: (_) => setState(() => _titleTouched = true),
            style: theme.textBody.copyWith(color: theme.colorTextPrimary),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              // "Change name" — the placeholder wording requested
              // directly — doubles as the field's "Mixed" indicator: an
              // untouched field with differing zone names shows this same
              // placeholder rather than any one zone's own title, so
              // there's nothing to distinguish visually from an ordinary
              // empty field. Typing anything and saving renames every
              // selected zone to that one title.
              hintText: 'Change name',
              hintStyle: theme.textBody.copyWith(
                color: theme.colorTextSecondary,
              ),
            ),
          ),
        ),
        SizedBox(height: theme.spacingSm),
        AppPane(
          child: Column(
            children: [
              AppSegmentedTimeField(
                label: 'Start',
                // null renders the field's own "hh:mm" placeholder —
                // doubling as this field's Mixed indicator, same
                // reasoning as the Name field above.
                first: effectiveStart == null ? null : effectiveStart ~/ 60,
                second: effectiveStart == null ? null : effectiveStart % 60,
                firstMax: 23,
                trailing: AppFieldActionButton(
                  icon: Icons.schedule_rounded,
                  semanticLabel: 'Choose start time',
                  onPressed: () => _pickStartTime(effectiveStart),
                ),
                onChanged: (hour, minute) => setState(() {
                  _startMinutes = hour * 60 + minute;
                  _startTouched = true;
                }),
              ),
              SizedBox(height: theme.spacingSm),
              AppSegmentedTimeField(
                label: 'End',
                first: effectiveEnd == null ? null : effectiveEnd ~/ 60,
                second: effectiveEnd == null ? null : effectiveEnd % 60,
                firstMax: 23,
                trailing: AppFieldActionButton(
                  icon: Icons.schedule_rounded,
                  semanticLabel: 'Choose end time',
                  onPressed: () => _pickEndTime(effectiveEnd),
                ),
                onChanged: (hour, minute) => setState(() {
                  _endMinutes = hour * 60 + minute;
                  _endTouched = true;
                }),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacingSm),
        AppPane(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Date',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _pickDate(effectiveDate),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacingMd,
                    vertical: theme.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorSurfaceSecondary,
                    borderRadius: BorderRadius.circular(theme.radiusXl),
                  ),
                  child: Text(
                    effectiveDate != null
                        ? '${effectiveDate.year}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}'
                        : 'Mixed',
                    style: theme.textBody.copyWith(
                      color: theme.colorTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_errorMessage != null) ...[
          SizedBox(height: theme.spacingSm),
          Text(
            _errorMessage!,
            style: theme.textBody.copyWith(color: theme.colorTaskAlert),
          ),
        ],
        SizedBox(height: theme.spacingLg),
        AppButton(
          label: 'Save',
          onPressed: _save,
          isLoading: _isSaving,
          shape: AppButtonShape.pill,
          size: AppButtonSize.lg,
        ),
      ],
    );
  }
}
