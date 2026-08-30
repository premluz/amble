import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_segmented_time_field.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_wheel_time_picker.dart';

/// The compact "Start time" modal — one of three per-field modals the
/// single-screen create/edit flow opens from its Time field, replacing
/// the old separate wheel-only sheet with one screen that offers BOTH
/// entry methods together (typed field, then wheel below it), matching
/// the mockup.
///
/// Typed entry and the wheel both write to the SAME local (hour, minute)
/// state — picking a wheel row updates the typed field's display, and
/// typing doesn't fight the wheel since nothing re-syncs the wheel FROM
/// the typed field while the sheet is open (the wheel is a coarse jump-to,
/// not a live mirror). "Done" is what commits the final value back to the
/// caller; dismissing without it discards whatever was typed or scrolled.
class TaskStartTimeModal extends StatefulWidget {
  const TaskStartTimeModal({
    super.key,
    required this.initialHour,
    required this.initialMinute,
  });

  /// Seeds both the typed field and the wheel. Null means unset — the
  /// typed field shows its placeholder and the wheel opens at 00:00,
  /// matching how [AppSegmentedTimeField] and [AppWheelTimePicker] each
  /// already handle "nothing chosen yet" on their own.
  final int? initialHour;
  final int? initialMinute;

  /// Opens the modal as a sheet. Resolves to the chosen (hour, minute), or
  /// null if dismissed without confirming.
  static Future<(int, int)?> show({
    required BuildContext context,
    required int? initialHour,
    required int? initialMinute,
  }) {
    return AppSheet.show<(int, int)>(
      context: context,
      builder: (context) => TaskStartTimeModal(
        initialHour: initialHour,
        initialMinute: initialMinute,
      ),
    );
  }

  @override
  State<TaskStartTimeModal> createState() => _TaskStartTimeModalState();
}

class _TaskStartTimeModalState extends State<TaskStartTimeModal> {
  int? _hour;
  int? _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialHour;
    _minute = widget.initialMinute;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // Scrollable rather than a bare Column: the typed field can summon
    // the keyboard, and a small device's remaining height plus the
    // wheel's fixed size can overflow — same class of bug found (and
    // fixed the same way) in TaskNameCategoryModal.
    return SingleChildScrollView(
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Start time',
          textAlign: TextAlign.center,
          style: theme.textTitle.copyWith(
            color: theme.colorTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacingLg),
        AppSegmentedTimeField(
          label: 'Time',
          first: _hour,
          second: _minute,
          firstMax: 23,
          onChanged: (hour, minute) => setState(() {
            _hour = hour;
            _minute = minute;
          }),
        ),
        SizedBox(height: theme.spacingLg),
        SizedBox(
          height: theme.spacingXl * 5,
          child: AppWheelPicker(
            hourCount: 24,
            // A time of day keeps full every-minute precision on its
            // wheel — unlike duration, browsing to an exact minute for a
            // start time is a real, common need (matching a calendar
            // invite, a meeting time), so coarsening it to steps of 5
            // would remove precision the field otherwise offers by typing.
            minuteStep: 1,
            initialHour: _hour ?? 0,
            initialMinute: _minute ?? 0,
            onChanged: (hour, minute) => setState(() {
              _hour = hour;
              _minute = minute;
            }),
          ),
        ),
        SizedBox(height: theme.spacingLg),
        AppButton(
          label: 'Done',
          size: AppButtonSize.large,
          shape: AppButtonShape.pill,
          onPressed: () {
            final hour = _hour;
            final minute = _minute;
            Navigator.of(context).pop(
              hour == null || minute == null ? null : (hour, minute),
            );
          },
        ),
      ],
      ),
    );
  }
}
