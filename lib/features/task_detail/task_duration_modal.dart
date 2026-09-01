import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_segmented_time_field.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_wheel_time_picker.dart';

/// Common durations offered as one-tap presets, in minutes. 5 is the
/// modal's own default (requested directly), so it's deliberately first
/// in this list even though the others read as ascending afterward.
///
/// Not private: the create flow's schedule pane (task_detail_sheet.dart)
/// renders these same presets inline rather than behind this modal, per
/// direct request, so both share this one list rather than keeping two
/// copies in sync by hand.
const presetMinutes = [5, 15, 30, 45, 60, 120];

String presetLabel(int minutes) =>
    minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h';

/// The compact "Duration" modal — the third of the three per-field modals,
/// mirroring [TaskStartTimeModal]'s shape (typed field, then wheel below
/// it, both writing to the same local value).
///
/// The wheel's minutes step by 5 (00, 05, 10…55 — 12 rows instead of 60),
/// per direct confirmation: unlike a start time, browsing to an EXACT
/// minute of duration by wheel isn't a common need — the typed field still
/// offers full-minute precision for anyone who wants it, so the wheel's
/// job here is fast rough browsing (need it half an hour? an hour and a
/// half?) rather than exact entry.
///
/// A row of preset chips (same [AppSelectableChip] the Repeats day-of-week
/// row uses — requested directly, "should be same comp as days in
/// repeat") sits above the wheel. Tapping a preset sets both the typed
/// field and rolls the wheel to match (animated, via
/// [AppWheelPickerController]); typing or scrolling to a value that
/// happens to equal a preset highlights it right back, and any other
/// value clears the highlight entirely — the presets are a reflection of
/// the current value, not a separate mode alongside it.
class TaskDurationModal extends StatefulWidget {
  const TaskDurationModal({super.key, required this.initialMinutes});

  /// Total minutes, or null when unset. Split into hour/minute for both
  /// the typed field and the wheel, and reassembled on Done.
  final int? initialMinutes;

  /// Opens the modal as a sheet. Resolves to the chosen total minutes, or
  /// null if dismissed without confirming.
  static Future<int?> show({
    required BuildContext context,
    required int? initialMinutes,
  }) {
    return AppSheet.show<int>(
      context: context,
      builder: (context) => TaskDurationModal(initialMinutes: initialMinutes),
    );
  }

  @override
  State<TaskDurationModal> createState() => _TaskDurationModalState();
}

class _TaskDurationModalState extends State<TaskDurationModal> {
  late int _hour;
  late int _minute;
  final _wheelController = AppWheelPickerController();

  @override
  void initState() {
    super.initState();
    // Defaults to 5 minutes when nothing is set yet (requested directly)
    // — unlike Start time, which has no sensible non-empty default, a
    // duration reads naturally as "start from the shortest common preset"
    // rather than as truly blank. This is local to the MODAL only: it
    // becomes the task's real duration only if the user taps Done: a
    // dismiss without confirming still discards it, same as every other
    // per-field modal's contract.
    final minutes = widget.initialMinutes ?? presetMinutes.first;
    _hour = minutes ~/ 60;
    _minute = minutes % 60;
  }

  int get _totalMinutes => _hour * 60 + _minute;

  void _selectPreset(int minutes) {
    setState(() {
      _hour = minutes ~/ 60;
      _minute = minutes % 60;
    });
    // Rolls the wheel to match, rather than silently updating state
    // underneath it — requested directly: "when preset tapped then it
    // updates input field and scrolls (animated roll of wheel) wheel".
    _wheelController.animateTo(_hour, _minute);
  }

  /// Shared by both the typed field and the wheel — either one committing
  /// a value just updates the same (hour, minute) state; only a PRESET
  /// tap additionally drives the wheel (see [_selectPreset]).
  void _setValue(int hour, int minute) {
    setState(() {
      _hour = hour;
      _minute = minute;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // Scrollable rather than a bare Column — same reasoning as
    // TaskStartTimeModal: the typed field can summon the keyboard, and a
    // small device's remaining height plus the wheel's fixed size can
    // overflow otherwise.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Duration',
            textAlign: TextAlign.center,
            style: theme.textTitle.copyWith(
              color: theme.colorTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacingLg),
          AppSegmentedTimeField(
            label: 'Duration',
            first: _hour,
            second: _minute,
            // No upper bound (requested directly — "no cap, any positive
            // duration") — same contract the main screen's own duration
            // field already has.
            firstMax: null,
            // Typing a value that happens to match a preset highlights it
            // right back, same as scrolling to a match would (requested
            // directly: "likewise if any other input type matched preset
            // preset gets selected") — the Wrap below re-derives selection
            // from _totalMinutes on every rebuild, so no separate wiring is
            // needed here. No wheel animation on typing: the user is
            // actively typing, so jumping the wheel under their thumb would
            // fight the keyboard rather than help.
            onChanged: _setValue,
          ),
          SizedBox(height: theme.spacingMd),
          // Preset chips — same AppSelectableChip the Repeats day-of-week
          // row uses (requested directly). Highlighting is DERIVED from the
          // current value every rebuild, never tracked as its own selected
          // index — so typing or scrolling to 30 minutes highlights "30m"
          // exactly as tapping it would, and any non-preset value clears
          // every chip at once.
          //
          // One ROW, not a Wrap — requested directly: "same as days of the
          // week in repeat." A Wrap let all 6 chips overflow onto a second
          // line on a narrow screen; each chip is Expanded instead, so all
          // 6 always share the row's real width and shrink together rather
          // than wrapping, matching _RecurrencePanel's own day-chip row.
          Row(
            children: [
              for (final (index, preset) in presetMinutes.indexed) ...[
                if (index > 0) SizedBox(width: theme.spacingXs),
                Expanded(
                  child: AppSelectableChip(
                    label: presetLabel(preset),
                    selected: _totalMinutes == preset,
                    onTap: () => _selectPreset(preset),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: theme.spacingLg),
          SizedBox(
            height: theme.spacingXl * 5,
            child: AppWheelPicker(
              // Matches AppWheelTimePicker's own existing duration range
              // (0–23h on the wheel; a longer duration stays reachable by
              // typing, which is what keeps the wheel scrollable).
              hourCount: 24,
              minuteStep: 5,
              initialHour: _hour,
              initialMinute: _minute,
              controller: _wheelController,
              onChanged: _setValue,
            ),
          ),
          SizedBox(height: theme.spacingLg),
          AppButton(
            label: 'Done',
            size: AppButtonSize.large,
            shape: AppButtonShape.pill,
            onPressed: () {
              // A task must have SOME duration — floor at 1 minute rather
              // than allowing 0h 0m, matching the main screen's own field.
              Navigator.of(context).pop(_totalMinutes < 1 ? 1 : _totalMinutes);
            },
          ),
        ],
      ),
    );
  }
}
