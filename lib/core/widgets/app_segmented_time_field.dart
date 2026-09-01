import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/semantic_theme.dart';
import 'app_field_shell.dart';

/// A masked `hh : mm` input — ONE text field with a baked-in separator,
/// not two boxes side by side.
///
/// Serves both "a time of day" and "a duration": they differ only in
/// whether the hour segment is capped ([firstMax]), so they share this
/// component rather than diverging into two near-identical widgets.
///
/// The single-field design is what makes the caret behave the way a date
/// or card-expiry field does. With two separate fields the separator is
/// dead scenery between two independent inputs; here it's part of one
/// string, so:
///  - typing the last hour digit slides the caret past `:` automatically;
///  - backspacing at the start of the minutes crosses back over `:` and
///    deletes the last hour digit, leaving the caret at the hour's end.
///
/// The value is NULLABLE and starts null: the field shows its `hh : mm`
/// placeholder until the user actually enters something, so it never
/// presents a number nobody chose. Callers gate their own save on
/// [first]/[second] being non-null.
class AppSegmentedTimeField extends StatefulWidget {
  const AppSegmentedTimeField({
    super.key,
    required this.label,
    required this.first,
    required this.second,
    required this.onChanged,
    this.firstMax,
    this.secondMax = 59,
    this.trailing,
  });

  /// Inline label, floated by [AppFieldShell] — "Time", "Duration".
  final String label;

  /// Hours, or null when nothing has been entered yet.
  final int? first;

  /// Minutes, or null when nothing has been entered yet.
  final int? second;

  /// Fires with both parts together whenever the value commits — callers
  /// always need the pair (a `TimeOfDay`, or `hours * 60 + minutes`),
  /// never one half alone.
  final void Function(int first, int second) onChanged;

  /// Upper bound for the hour segment, or null for no cap. Time of day
  /// passes 23; duration passes null ("no cap, any positive duration").
  ///
  /// The DISPLAY is always two digits wide regardless: an uncapped value
  /// grows the segment only when it genuinely needs a third digit, so an
  /// ordinary duration reads `02 : 30` rather than advertising the
  /// field's maximum as `002 : 30`.
  final int? firstMax;

  /// Upper bound for the minutes segment.
  final int? secondMax;

  /// Optional adornment inside the field's right edge — used for the
  /// alternative-entry buttons (a clock, a stopwatch) that open a picker.
  final Widget? trailing;

  @override
  State<AppSegmentedTimeField> createState() => _AppSegmentedTimeFieldState();
}

class _AppSegmentedTimeFieldState extends State<AppSegmentedTimeField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isFocused = false;

  /// Set just before a tap lands on the text itself (see the `TextField`'s
  /// own `onTap`) and consumed by [_handleFocusChange] on the very next
  /// focus-gain. Distinguishes "the user tapped a specific spot in the
  /// text" from every other way this field can gain focus (tabbing in,
  /// `requestFocus()` from elsewhere, the shell's own tap-anywhere handler)
  /// — only the latter group should force the caret to the hour segment;
  /// a direct tap already told Flutter exactly where the caret belongs, and
  /// overwriting that is the bug being fixed here.
  bool _pendingTextTap = false;

  static const _separator = ' : ';

  /// Digits the mask can hold. Two for each segment, plus one spare hour
  /// digit so an uncapped duration past 99 hours can still be typed.
  /// Purely the mask's CAPACITY — never a display width, which is what
  /// previously rendered every duration zero-padded out to three digits.
  static const _maxHourDigits = 3;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue());
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(AppSegmentedTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nothing changed from outside — leave the field alone.
    if (oldWidget.first == widget.first && oldWidget.second == widget.second) {
      return;
    }
    // The incoming value already matches what's displayed. This is the
    // echo of the user's OWN edit coming back through the caller, so
    // rewriting the controller here would only move their caret.
    if (_controller.text == _formatValue()) return;

    // Otherwise the value genuinely changed elsewhere — the wheel picker
    // confirming, or the caller resetting the form — and the field must
    // show it.
    //
    // This deliberately does NOT skip while focused. It used to, on the
    // reasoning that overwriting a focused field fights live typing; but
    // the picker button sits INSIDE this field, so tapping it leaves the
    // field focused, and that guard silently discarded every value chosen
    // on the wheel whenever a value was already set. The check above is
    // the precise version of what that guard was reaching for: ignore an
    // echo of your own text, honour a real external change.
    _controller.text = _formatValue();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _hasValue => widget.first != null && widget.second != null;

  /// The widget's value as masked text, or empty when unset so the
  /// placeholder shows through.
  String _formatValue() {
    if (!_hasValue) return '';
    return _format(
      widget.first!.toString().padLeft(2, '0') +
          widget.second!.toString().padLeft(2, '0'),
    );
  }

  /// The empty-state placeholder. Always the two-digit shape — a hint
  /// describes what to type, and nobody types a leading zero triple.
  String get _hintText => 'hh${_separator}mm';

  /// Lays digits into `hh : mm`. Everything except the trailing two
  /// minute digits is the hour part, so the hour segment sizes itself to
  /// what it actually holds rather than to the mask's capacity.
  String _format(String digits) {
    final padded = digits.length < 4 ? digits.padLeft(4, '0') : digits;
    return '${padded.substring(0, padded.length - 2)}$_separator'
        '${padded.substring(padded.length - 2)}';
  }

  void _handleFocusChange() {
    final gainedFocus = _focusNode.hasFocus && !_isFocused;
    if (_focusNode.hasFocus != _isFocused) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }

    if (!_focusNode.hasFocus) {
      _commit();
      return;
    }

    // Entry starts at the HOUR, not wherever the caret happened to land —
    // but only when focus arrived WITHOUT the user tapping a specific spot
    // in the text (tabbing in, `requestFocus()` from opening the sheet, the
    // shell's tap-anywhere-in-the-fill handler). Those all leave Flutter's
    // caret at the text's end by default, which drops the user into the
    // minutes and makes them reach backwards to type an hour — the
    // opposite of how the field reads.
    //
    // A direct tap on the text is different: Flutter already resolved it to
    // the exact offset under the user's finger, including a tap that lands
    // in minutes on purpose. Forcing that back to 0 was the bug — the user
    // would tap into minutes, watch the caret jump to the start, and have
    // to tap a second time to actually land where they meant.
    if (!gainedFocus) return;
    if (_pendingTextTap) {
      _pendingTextTap = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) return;
      final atEnd = _controller.selection.baseOffset >= _controller.text.length;
      if (!atEnd) return;
      _controller.selection = const TextSelection.collapsed(offset: 0);
    });
  }

  void _commit() {
    // Split on the SEPARATOR, not on digit position: each segment now
    // renders at whatever length the user actually typed (e.g. hour "9",
    // not "09"), so folding the two back into one flat digit string and
    // slicing the last two characters off would misread "9 : 3" as hour
    // 93 rather than hour 9, minute 3.
    final separatorIndex = _controller.text.indexOf(_separator);
    final hourText = separatorIndex < 0
        ? ''
        : _controller.text.substring(0, separatorIndex);
    final minuteText = separatorIndex < 0
        ? ''
        : _controller.text.substring(separatorIndex + _separator.length);

    // Emptied: leave it emptied. Restoring the previous value here would
    // make clearing a field impossible — the user would delete everything,
    // tap away, and watch the old value reappear. Nothing is committed, so
    // the caller's value simply stays as it was (null for a fresh create),
    // and the placeholder keeps showing.
    if (hourText.isEmpty && minuteText.isEmpty) return;

    final first = int.tryParse(hourText.isEmpty ? '0' : hourText);
    final second = int.tryParse(minuteText.isEmpty ? '0' : minuteText);
    if (first == null || second == null) {
      _controller.text = _formatValue();
      return;
    }

    final clampedFirst = widget.firstMax == null
        ? first
        : first.clamp(0, widget.firstMax!);
    final clampedSecond = widget.secondMax == null
        ? second
        : second.clamp(0, widget.secondMax!);

    _controller.text = _format(
      clampedFirst.toString().padLeft(2, '0') +
          clampedSecond.toString().padLeft(2, '0'),
    );
    widget.onChanged(clampedFirst, clampedSecond);
  }

  /// Fired by the keyboard's own "Done"/"complete" action — distinct from
  /// [_commit] itself because `TextField.onEditingComplete` overriding the
  /// default implementation means THIS callback is now solely responsible
  /// for closing the keyboard; the default implementation calls
  /// `unfocus()` internally, and overriding it with a bare `_commit`
  /// silently dropped that, so the value committed but the keyboard never
  /// dismissed. `unfocus()` alone would also work (it routes back through
  /// `_handleFocusChange`'s own blur-commit), but committing explicitly
  /// here first keeps the visible behaviour in the same order every other
  /// commit path uses: value settles, THEN focus leaves.
  void _handleEditingComplete() {
    _commit();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return AppFieldShell(
      label: widget.label,
      isFocused: _isFocused,
      // Always floated: the placeholder needs the value row to be visible
      // in order to show at all, so this field has no collapsed state.
      isFloating: true,
      onTap: _focusNode.requestFocus,
      trailing: widget.trailing,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        inputFormatters: [
          const _SegmentedTimeFormatter(
            maxHourDigits: _maxHourDigits,
            separator: _separator,
          ),
        ],
        style: theme.textBody.copyWith(color: theme.colorTextPrimary),
        cursorColor: theme.colorTextPrimary,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: _hintText,
          hintStyle: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
        onEditingComplete: _handleEditingComplete,
        // Fires before the resulting focus-gain is processed, per
        // `TextField`'s own contract — flags this as a tap-driven focus
        // gain so `_handleFocusChange` leaves Flutter's own tap-resolved
        // caret position alone instead of forcing it back to the hours.
        onTap: () => _pendingTextTap = true,
      ),
    );
  }
}

/// Keeps the field's text in `hh : mm` shape and places the caret where a
/// masked field is expected to put it.
///
/// Models the value as TWO INDEPENDENT, variable-length digit strings —
/// hours and minutes, each 0 to their own digit cap — rather than a fixed
/// 4-digit array padded with zeros. That is what lets a segment genuinely
/// SHRINK: deleting one digit from "05" leaves "0", not a re-zeroed "00",
/// and deleting the last digit of a segment empties it to nothing rather
/// than snapping back to a padded value nobody asked for.
///
/// Per direct confirmation, backspace acts on whichever segment the caret
/// is currently in — it does not reach into the other segment until the
/// current one is already empty, at which point one more backspace
/// crosses the separator and starts shrinking the hour segment.
class _SegmentedTimeFormatter extends TextInputFormatter {
  const _SegmentedTimeFormatter({
    required this.maxHourDigits,
    required this.separator,
  });

  /// The most digits the hour segment may HOLD. Never a display width —
  /// an ordinary value renders far shorter, since a segment is only as
  /// wide as what the user actually typed into it.
  final int maxHourDigits;
  final String separator;

  static const _maxMinuteDigits = 2;

  /// Splits the field's current text back into its two segments. Works
  /// directly on the RENDERED text (not a flat digit count) because a
  /// segment's own length is exactly what makes it shrinkable — collapsing
  /// both sides into one digit string is what the old model did, and it's
  /// the reason it couldn't represent "one digit of hours, empty minutes"
  /// as a distinct state from "two digits of hours, one of minutes".
  (String, String) _segments(String text) {
    final separatorIndex = text.indexOf(separator);
    if (separatorIndex < 0) {
      // No separator yet — only reachable transiently; treat everything
      // as hours.
      return (text, '');
    }
    return (
      text.substring(0, separatorIndex),
      text.substring(separatorIndex + separator.length),
    );
  }

  String _render(String hour, String minute) {
    if (hour.isEmpty && minute.isEmpty) return '';
    return '$hour$separator$minute';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final (oldHour, oldMinute) = _segments(oldValue.text);

    // A full replacement — paste, autofill, or a test's enterText — lands
    // as bare digits with no separator at all. Detected by SHAPE: a real
    // in-place edit always leaves the separator in the string, because
    // the user can only change one character at a time.
    final newDigitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final isFullReplacement =
        !newValue.text.contains(separator.trim()) &&
        newDigitsOnly.isNotEmpty &&
        (oldHour.isNotEmpty || oldMinute.isNotEmpty);

    if (isFullReplacement) {
      final capped = newDigitsOnly.length > maxHourDigits + _maxMinuteDigits
          ? newDigitsOnly.substring(0, maxHourDigits + _maxMinuteDigits)
          : newDigitsOnly;
      final hourLen = capped.length > _maxMinuteDigits
          ? (capped.length - _maxMinuteDigits).clamp(0, maxHourDigits)
          : 0;
      final hour = capped.substring(0, hourLen);
      final minute = capped.substring(hourLen);
      final text = _render(hour, minute);
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    // Which segment the caret sits in, and where within it — derived from
    // the OLD value's caret, since that's the position the edit actually
    // happened at.
    final oldCaret = oldValue.selection.baseOffset;
    final separatorStart = oldHour.length;
    final separatorEnd = separatorStart + separator.length;
    final inHourSegment = oldCaret <= separatorStart;
    final posInSegment = inHourSegment
        ? oldCaret.clamp(0, oldHour.length)
        : (oldCaret - separatorEnd).clamp(0, oldMinute.length);

    final isDeletion = newValue.text.length < oldValue.text.length;

    if (isDeletion) {
      if (inHourSegment) {
        if (posInSegment == 0) {
          // Caret already at the start of the hours — nothing before it
          // to delete, and hours is the first segment, so there's no
          // earlier segment to cross into either.
          return TextEditingValue(
            text: oldValue.text,
            selection: TextSelection.collapsed(offset: 0),
          );
        }
        final newHour =
            oldHour.substring(0, posInSegment - 1) +
            oldHour.substring(posInSegment);
        final text = _render(newHour, oldMinute);
        return TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: posInSegment - 1),
        );
      }

      // Caret in the minutes segment.
      if (posInSegment == 0) {
        // Minutes already empty at the caret — this backspace crosses the
        // separator instead of touching minutes at all. If hours also has
        // nothing to remove, this is a no-op; otherwise it shrinks hours
        // by one digit and leaves the caret at the new hour end, which is
        // what makes the separator "disappear through" in one press.
        if (oldHour.isEmpty) {
          return TextEditingValue(
            text: oldValue.text,
            selection: TextSelection.collapsed(offset: separatorEnd),
          );
        }
        final newHour = oldHour.substring(0, oldHour.length - 1);
        final text = _render(newHour, oldMinute);
        return TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: newHour.length),
        );
      }
      final newMinute =
          oldMinute.substring(0, posInSegment - 1) +
          oldMinute.substring(posInSegment);
      final text = _render(oldHour, newMinute);
      final newSeparatorEnd = oldHour.length + separator.length;
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: newSeparatorEnd + posInSegment - 1,
        ),
      );
    }

    // Insertion. A single new character was spliced in at the caret;
    // find it by diffing the two strings around the known caret position
    // rather than assuming length delta == 1, since IME composition can
    // occasionally deliver more than one code unit for what is visually
    // one keystroke.
    if (newValue.text.length <= oldValue.text.length) {
      // Nothing net new (e.g. a non-digit was typed and filtered away by
      // the keyboardType, but still reached the formatter) — leave as is.
      return oldValue;
    }
    final insertedLength = newValue.text.length - oldValue.text.length;
    final insertStart = oldCaret;
    final inserted = newValue.text.substring(
      insertStart,
      (insertStart + insertedLength).clamp(0, newValue.text.length),
    );
    final digitsInserted = inserted.replaceAll(RegExp(r'\D'), '');
    if (digitsInserted.isEmpty) {
      return TextEditingValue(
        text: oldValue.text,
        selection: oldValue.selection,
      );
    }

    if (inHourSegment) {
      final wasTypingAtEnd = posInSegment == oldHour.length;

      // The ordinary display width is TWO digits. Typing at the tail once
      // the segment already holds two digits doesn't grow it to three —
      // it rolls the new digit into minutes instead, which is what makes
      // "14" plus one more keystroke advance across the separator rather
      // than becoming "143". Reaching a genuine 3-digit hour (a duration
      // past 99h) happens by continuing to type WHILE still short of two
      // digits, e.g. typing "1", "2", "0" in a row from empty — each digit
      // lands before the cap is hit, so the segment is allowed to grow
      // past two before the rollover point applies to it again.
      // Two conditions both mean "the hour segment is complete and this
      // edit should land in minutes instead": the segment ALREADY had two
      // digits before this keystroke (the ordinary one-key-at-a-time
      // case), or this single edit supplies two or more digits at once
      // and lands at the tail (e.g. `enterText` delivering "09" in one
      // call, as autofill or a fast typist's IME batching would) — both
      // read as "the hour is done", so both roll into minutes the same
      // way rather than only the first being handled.
      final reachesTwoInOneEdit = oldHour.isEmpty && digitsInserted.length >= 2;
      if (wasTypingAtEnd && (oldHour.length >= 2 || reachesTwoInOneEdit)) {
        final hourPortion = reachesTwoInOneEdit
            ? digitsInserted.substring(0, 2)
            : oldHour;
        final remainder = reachesTwoInOneEdit
            ? digitsInserted.substring(2)
            : digitsInserted;
        // Rolling forward overwrites the minutes segment from its start,
        // the same way the insert-into-minutes path below overwrites
        // rather than pushing existing digits along — this is a caret
        // ARRIVING at minutes, not text being spliced into it, so what
        // minutes held before is stale relative to the keystroke that
        // just crossed the separator.
        final toMinutes = remainder.length > _maxMinuteDigits
            ? remainder.substring(0, _maxMinuteDigits)
            : remainder;
        final text = _render(hourPortion, toMinutes);
        final offset = hourPortion.length + separator.length + toMinutes.length;
        return TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: offset),
        );
      }

      var newHour =
          oldHour.substring(0, posInSegment) +
          digitsInserted +
          oldHour.substring(posInSegment);
      var caretInHour = posInSegment + digitsInserted.length;

      // The segment already reached its natural 2-digit width (this path
      // is only reached when NOT typing at the tail — see above), so an
      // insert in the middle/front OVERWRITES from that point rather than
      // pushing the field to 3 digits. Growing past 2 is reserved for the
      // sequential-typing path above, which is the only way a duration
      // legitimately reaches a 3-digit hour.
      if (oldHour.length >= 2 && newHour.length > oldHour.length) {
        newHour = newHour.substring(0, oldHour.length);
        caretInHour = caretInHour.clamp(0, oldHour.length);
      } else if (newHour.length > maxHourDigits) {
        newHour = newHour.substring(0, maxHourDigits);
        caretInHour = caretInHour.clamp(0, maxHourDigits);
      }
      final text = _render(newHour, oldMinute);
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: caretInHour),
      );
    }

    // Caret in minutes.
    var newMinute =
        oldMinute.substring(0, posInSegment) +
        digitsInserted +
        oldMinute.substring(posInSegment);
    var caretInMinute = posInSegment + digitsInserted.length;
    if (newMinute.length > _maxMinuteDigits) {
      newMinute = newMinute.substring(0, _maxMinuteDigits);
      caretInMinute = caretInMinute.clamp(0, _maxMinuteDigits);
    }
    final text = _render(oldHour, newMinute);
    final separatorEndNow = oldHour.length + separator.length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: separatorEndNow + caretInMinute,
      ),
    );
  }
}
