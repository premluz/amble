import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_button.dart';
import 'app_sheet.dart';

/// Two side-by-side scroll wheels — hours and minutes — offered as an
/// ALTERNATIVE to typing in [AppSegmentedTimeField], not a replacement.
///
/// Typing is the primary path (it's faster for someone who knows the
/// value); the wheels are for browsing to one. Both write to the same
/// underlying value, so neither is a separate mode the user can get stuck
/// in.
///
/// This is the BARE wheel pair — no title, no Done button — for embedding
/// inline alongside a typed field in one screen (see
/// `TaskStartTimeModal`/`TaskDurationModal`). [AppWheelTimePicker] wraps
/// this in its own titled, "Done"-confirmed sheet for standalone use.
class AppWheelPicker extends StatefulWidget {
  const AppWheelPicker({
    super.key,
    required this.initialHour,
    required this.initialMinute,
    required this.hourCount,
    required this.onChanged,
    this.minuteStep = 1,
    this.controller,
  });

  /// Where the wheels open. Both default to 0 when the field is unset, so
  /// an untouched wheel reads `00 : 00` rather than seeding a value the
  /// user never chose.
  final int initialHour;
  final int initialMinute;

  /// How many hour rows to offer — 24 for both a time of day and a
  /// duration. A duration longer than a day stays reachable by typing,
  /// which keeps this wheel short enough to actually scroll.
  final int hourCount;

  /// The minute wheel's row spacing — 1 for every minute (60 rows), or a
  /// coarser step (e.g. 5, giving 12 rows: 00, 05, 10…55) for a picker
  /// whose typed entry already offers full precision, where the wheel's
  /// job is fast rough browsing rather than exact entry. [initialMinute]
  /// is snapped DOWN to the nearest step so the wheel always opens on one
  /// of its own real rows rather than an in-between value it can't select.
  final int minuteStep;

  /// Fires on every scroll settle — this widget has no "confirm" step of
  /// its own, so the caller decides when a value is final.
  final void Function(int hour, int minute) onChanged;

  /// Lets a caller command an animated jump to a specific (hour, minute)
  /// — e.g. a duration preset chip rolling the wheel to match, rather
  /// than just updating a typed field silently. Optional: a picker with
  /// no presets has no need for external control.
  final AppWheelPickerController? controller;

  @override
  State<AppWheelPicker> createState() => _AppWheelPickerState();
}

/// External handle for [AppWheelPicker] — lets a caller (a preset chip
/// row) drive an animated scroll on the wheel from outside it, the same
/// way a `TextEditingController` lets a caller drive a text field. Not a
/// [ChangeNotifier]: the picker owns no observable state a caller needs to
/// read back, it only accepts commands.
class AppWheelPickerController {
  _AppWheelPickerState? _state;

  void _attach(_AppWheelPickerState state) => _state = state;
  void _detach(_AppWheelPickerState state) {
    if (_state == state) _state = null;
  }

  /// Animates both wheels to show [hour]/[minute] — the roll a tapped
  /// duration preset triggers. No-ops if the picker isn't currently
  /// mounted (e.g. called after the sheet closed).
  void animateTo(int hour, int minute) => _state?._animateTo(hour, minute);
}

class _AppWheelPickerState extends State<AppWheelPicker> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  int get _minuteRowCount => (60 / widget.minuteStep).ceil();

  @override
  void initState() {
    super.initState();
    // Snapped down to the nearest step: an initial value the wheel's own
    // rows can't represent (e.g. "12" on a 5-minute wheel) would leave no
    // row actually selected.
    final snappedMinute =
        widget.initialMinute - (widget.initialMinute % widget.minuteStep);
    _hourController = FixedExtentScrollController(
      initialItem: widget.initialHour,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: snappedMinute ~/ widget.minuteStep,
    );
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(AppWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _animateTo(int hour, int minute) {
    final snappedMinute = minute - (minute % widget.minuteStep);
    final minuteRow = snappedMinute ~/ widget.minuteStep;
    // Both wheels animate together — a preset is one value, not two
    // independent scrolls, so they should visibly move as one gesture.
    _hourController.animateToItem(
      hour,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    _minuteController.animateToItem(
      minuteRow,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Row(
      children: [
        Expanded(
          child: _Wheel(
            controller: _hourController,
            itemCount: widget.hourCount,
            label: 'Hours',
            onChanged: (hour) => widget.onChanged(
              hour,
              _minuteController.selectedItem * widget.minuteStep,
            ),
          ),
        ),
        Text(
          ':',
          style: theme.textTitle.copyWith(
            color: theme.colorTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: _Wheel(
            controller: _minuteController,
            itemCount: _minuteRowCount,
            step: widget.minuteStep,
            label: 'Minutes',
            onChanged: (row) => widget.onChanged(
              _hourController.selectedItem,
              row * widget.minuteStep,
            ),
          ),
        ),
      ],
    );
  }
}

/// Serves both "a time of day" and "a duration": they differ only in the
/// hour range offered, which the caller supplies via [hourCount].
class AppWheelTimePicker extends StatefulWidget {
  const AppWheelTimePicker({
    super.key,
    required this.title,
    required this.initialHour,
    required this.initialMinute,
    required this.hourCount,
    this.minuteStep = 1,
  });

  final String title;
  final int initialHour;
  final int initialMinute;
  final int hourCount;
  final int minuteStep;

  /// Opens the picker as a sheet. Resolves to the chosen (hour, minute),
  /// or null if dismissed without confirming — so a cancelled picker
  /// leaves the field exactly as it was.
  static Future<(int, int)?> show({
    required BuildContext context,
    required String title,
    required int initialHour,
    required int initialMinute,
    int hourCount = 24,
    int minuteStep = 1,
  }) {
    return AppSheet.show<(int, int)>(
      context: context,
      // This picker applies its own padding, so it doesn't take the
      // sheet's — stacking both left the wheels inset twice over.
      padded: false,
      builder: (context) => AppWheelTimePicker(
        title: title,
        initialHour: initialHour,
        initialMinute: initialMinute,
        hourCount: hourCount,
        minuteStep: minuteStep,
      ),
    );
  }

  @override
  State<AppWheelTimePicker> createState() => _AppWheelTimePickerState();
}

class _AppWheelTimePickerState extends State<AppWheelTimePicker> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialHour;
    _minute = widget.initialMinute;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    // Tall enough to show the selected row plus two either side, which is
    // what makes a wheel read as scrollable rather than as a single value.
    final wheelHeight = theme.spacingXl * 5;

    return Padding(
      padding: EdgeInsets.all(theme.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: theme.textTitle.copyWith(
              color: theme.colorTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacingLg),
          SizedBox(
            height: wheelHeight,
            child: AppWheelPicker(
              initialHour: _hour,
              initialMinute: _minute,
              hourCount: widget.hourCount,
              minuteStep: widget.minuteStep,
              onChanged: (hour, minute) {
                _hour = hour;
                _minute = minute;
              },
            ),
          ),
          SizedBox(height: theme.spacingLg),
          AppButton(
            label: 'Done',
            size: AppButtonSize.large,
            shape: AppButtonShape.pill,
            onPressed: () => Navigator.of(context).pop((_hour, _minute)),
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.itemCount,
    required this.label,
    required this.onChanged,
    this.step = 1,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final String label;

  /// Fires with the ROW index (0, 1, 2…), not the displayed value — the
  /// caller multiplies by its own step, since only the caller knows
  /// whether this wheel counts by ones or by fives.
  final ValueChanged<int> onChanged;

  /// Each row's displayed number is `row * step` — 1 for an ordinary
  /// every-value wheel (hours, or an unstepped minutes), higher for a
  /// coarser one (00, 05, 10… at step 5).
  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Semantics(
      label: label,
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: theme.spacingXl,
        onSelectedItemChanged: onChanged,
        // The default overlay is a Cupertino-styled bar; this one takes
        // the app's own field surface so the wheel belongs to this design
        // system rather than to iOS.
        //
        // CupertinoPicker paints selectionOverlay ON TOP of its children,
        // so an opaque fill here hides the very value it is meant to
        // highlight. Low alpha keeps it a highlight rather than a lid —
        // the selected number reads through it.
        selectionOverlay: Container(
          decoration: BoxDecoration(
            color: theme.colorSurfaceField.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
        ),
        children: [
          for (var i = 0; i < itemCount; i++)
            Center(
              child: Text(
                (i * step).toString().padLeft(2, '0'),
                style: theme.textBody.copyWith(color: theme.colorTextPrimary),
              ),
            ),
        ],
      ),
    );
  }
}
