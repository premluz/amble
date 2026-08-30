import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_segmented_time_field.dart';

/// Drives the real widget rather than the private formatter directly —
/// the formatter's contract only means anything as observed through a
/// [TextField], which is also where the caret behaviour actually matters.
Widget _host({
  required int? first,
  required int? second,
  int? firstMax = 23,
  required void Function(int, int) onChanged,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
    home: Scaffold(
      body: AppSegmentedTimeField(
        label: 'Time',
        first: first,
        second: second,
        firstMax: firstMax,
        onChanged: onChanged,
      ),
    ),
  );
}

/// The field's current text and caret offset, as the user would see them.
({String text, int caret}) _state(WidgetTester tester) {
  final field = tester.widget<TextField>(find.byType(TextField));
  final value = field.controller!.value;
  return (text: value.text, caret: value.selection.baseOffset);
}

void main() {
  group('AppSegmentedTimeField masking', () {
    testWidgets('renders the initial value in hh : mm shape', (tester) async {
      await tester.pumpWidget(_host(first: 14, second: 0, onChanged: (_, _) {}));
      expect(_state(tester).text, '14 : 00');
    });

    testWidgets('a full replacement rewrites the mask from the start', (
      tester,
    ) async {
      await tester.pumpWidget(_host(first: 0, second: 0, onChanged: (_, _) {}));
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Supplying all four digits at once (paste/autofill, and what
      // `enterText` does) must rewrite the field from slot 0 — this is the
      // case a length-based deletion check silently swallowed.
      await tester.enterText(find.byType(TextField), '0930');
      await tester.pump();
      expect(_state(tester).text, '09 : 30');
    });

    testWidgets('caret sits past the separator once hours are complete', (
      tester,
    ) async {
      await tester.pumpWidget(_host(first: 0, second: 0, onChanged: (_, _) {}));
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Three digits entered: hours are full, so the caret must already be
      // in the minutes segment (past " : ") rather than stuck before it.
      await tester.enterText(find.byType(TextField), '093');
      await tester.pump();

      final state = _state(tester);
      final separatorEnd = state.text.indexOf(':') + 2;
      expect(
        state.caret,
        greaterThan(separatorEnd),
        reason: 'caret should have advanced into the minutes segment',
      );
    });

    testWidgets(
        'backspace at the minutes boundary crosses into the hours and '
        'SHRINKS it, rather than re-zeroing a fixed slot', (tester) async {
      await tester.pumpWidget(_host(first: 9, second: 0, onChanged: (_, _) {}));
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      final controller = field.controller!;

      // Put the caret immediately after the separator — the exact spot
      // where a naive implementation would delete the separator itself and
      // appear to do nothing.
      final afterSeparator = controller.text.indexOf(':') + 2;
      controller.selection = TextSelection.collapsed(offset: afterSeparator);
      await tester.pump();

      // Simulate a backspace: the platform reports the text minus the char
      // before the caret, which here is a separator character.
      final withSeparatorRemoved =
          controller.text.substring(0, afterSeparator - 1) +
          controller.text.substring(afterSeparator);
      await tester.enterText(find.byType(TextField), withSeparatorRemoved);
      await tester.pump();

      // Per direct confirmation: backspace shrinks the segment it acts on
      // rather than re-zeroing a fixed-width slot. "09" loses its last
      // digit and becomes "0" — not "00" — with minutes untouched.
      expect(_state(tester).text, '0 : 00');
    });

    testWidgets('digits typed one at a time roll across the separator', (
      tester,
    ) async {
      await tester.pumpWidget(_host(first: 0, second: 0, onChanged: (_, _) {}));
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;

      // Start from slot 0, then deliver ONE character per edit the way a
      // real keyboard does — a different code path from the bulk
      // replacement above, and the one that actually exercises the caret
      // advancing over the separator on its own.
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();

      for (final digit in ['1', '4', '3', '0']) {
        final value = controller.value;
        final caret = value.selection.baseOffset;
        final spliced =
            value.text.substring(0, caret) +
            digit +
            value.text.substring(caret);
        await tester.enterText(find.byType(TextField), spliced);
        await tester.pump();
      }

      expect(_state(tester).text, '14 : 30');
    });

    testWidgets('clearing every digit empties the field so the hint shows', (
      tester,
    ) async {
      await tester.pumpWidget(_host(first: 9, second: 0, onChanged: (_, _) {}));
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;

      // Backspace repeatedly from the end until nothing is left. The
      // field focuses at the HOUR, so the caret is placed at the end
      // explicitly — as it would be for someone who just typed the value.
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      await tester.pump();

      for (var i = 0; i < 6; i++) {
        final value = controller.value;
        if (value.text.isEmpty) break;
        final caret = value.selection.baseOffset.clamp(1, value.text.length);
        final spliced =
            value.text.substring(0, caret - 1) + value.text.substring(caret);
        await tester.enterText(find.byType(TextField), spliced);
        await tester.pump();
      }

      // Empty text — NOT "00 : 00", which would be indistinguishable from
      // a real midnight value and would hide the placeholder.
      expect(_state(tester).text, isEmpty);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, 'hh : mm');
    });

    testWidgets('duration renders its hour at natural width, not padded '
        'out to the 3-digit capacity', (tester) async {
      await tester.pumpWidget(
        _host(
          first: 2,
          second: 30,
          firstMax: null,
          onChanged: (_, _) {},
        ),
      );

      // 2h30m reads "02 : 30" — NOT "002 : 30". The 3-digit capacity is
      // headroom for a long duration, not a width every value is padded
      // to; padding to it advertises the maximum instead of the value.
      expect(_state(tester).text, '02 : 30');

      // And the hint describes what to type, so it stays two-digit.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, 'hh : mm');
    });

    testWidgets('a duration past 99 hours still renders in full', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          first: 120,
          second: 0,
          firstMax: null,
          onChanged: (_, _) {},
        ),
      );
      // The hour segment grows to fit rather than truncating.
      expect(_state(tester).text, '120 : 00');
    });

    testWidgets('typing into a cleared field starts at the first slot', (
      tester,
    ) async {
      var committed = (-1, -1);
      await tester.pumpWidget(
        _host(first: 9, second: 0, onChanged: (f, s) => committed = (f, s)),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      // Backspacing starts from the end of the value, the way it would
      // for someone who has just finished typing. The field itself now
      // focuses at the HOUR, so the caret has to be placed explicitly.
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        final value = controller.value;
        if (value.text.isEmpty) break;
        final caret = value.selection.baseOffset.clamp(1, value.text.length);
        await tester.enterText(
          find.byType(TextField),
          value.text.substring(0, caret - 1) + value.text.substring(caret),
        );
        await tester.pump();
      }
      expect(_state(tester).text, isEmpty);

      // Retype from empty — digits must fill from the hour slot onward.
      for (final digit in ['1', '4', '3', '0']) {
        final value = controller.value;
        final caret = value.selection.baseOffset;
        await tester.enterText(
          find.byType(TextField),
          value.text.substring(0, caret) + digit + value.text.substring(caret),
        );
        await tester.pump();
      }
      expect(_state(tester).text, '14 : 30');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(committed, (14, 30));
    });

    testWidgets('an emptied field stays empty on blur — it does not fall '
        'back to a value', (tester) async {
      var committed = false;
      await tester.pumpWidget(
        _host(first: 9, second: 15, onChanged: (_, _) => committed = true),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      // Backspacing starts from the end of the value, the way it would
      // for someone who has just finished typing. The field itself now
      // focuses at the HOUR, so the caret has to be placed explicitly.
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        final value = controller.value;
        if (value.text.isEmpty) break;
        final caret = value.selection.baseOffset.clamp(1, value.text.length);
        await tester.enterText(
          find.byType(TextField),
          value.text.substring(0, caret - 1) + value.text.substring(caret),
        );
        await tester.pump();
      }

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Unset is a real state: the field shows its placeholder and commits
      // nothing, so the caller's value stays null and Confirm stays off.
      expect(_state(tester).text, isEmpty);
      expect(committed, isFalse);
    });

    testWidgets('starts empty when the value is null', (tester) async {
      await tester.pumpWidget(
        _host(first: null, second: null, onChanged: (_, _) {}),
      );
      expect(_state(tester).text, isEmpty);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, 'hh : mm');
    });

    testWidgets('clamps an out-of-range hour on blur', (tester) async {
      var committedFirst = -1;
      await tester.pumpWidget(
        _host(
          first: 0,
          second: 0,
          onChanged: (f, _) => committedFirst = f,
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '9900');
      await tester.pump();

      // Blur commits — 99 is past firstMax (23) and must come back clamped.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(committedFirst, 23);
      expect(_state(tester).text, '23 : 00');
    });

    testWidgets('uncapped duration keeps a 3-digit hour', (tester) async {
      var committedFirst = -1;
      await tester.pumpWidget(
        _host(
          first: 0,
          second: 0,
          firstMax: null,
          onChanged: (f, _) => committedFirst = f,
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // 120 hours — well past any time-of-day cap; must survive intact,
      // since duration is explicitly uncapped.
      await tester.enterText(find.byType(TextField), '12000');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(committedFirst, 120);
    });

    testWidgets('minutes are clamped to 59', (tester) async {
      var committedSecond = -1;
      await tester.pumpWidget(
        _host(
          first: 0,
          second: 0,
          onChanged: (_, s) => committedSecond = s,
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '1099');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(committedSecond, 59);
    });

    testWidgets(
        'caret lands in front of the minutes, not right after the hour, '
        'once two hour digits are entered', (tester) async {
      await tester.pumpWidget(_host(first: null, second: null, onChanged: (_, _) {}));
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '09');
      await tester.pump();

      final state = _state(tester);
      final separatorEnd = state.text.indexOf(':') + 2;
      // Not merely past the separator START — past the space after it,
      // i.e. sitting directly in front of the minutes' own first digit.
      // Landing one character short of this (right after the separator's
      // colon but before its trailing space) reads as the caret stalling
      // at the boundary instead of moving into minutes.
      expect(state.caret, separatorEnd);
    });

    testWidgets('backspace removes ONE digit from a two-digit minutes '
        'segment, leaving the other digit rather than re-zeroing to "00"',
        (tester) async {
      await tester.pumpWidget(_host(first: 9, second: 15, onChanged: (_, _) {}));
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      await tester.pump();

      // One backspace from the end of "09 : 15" — minutes "15" loses its
      // trailing digit and becomes "1", not "10" and not "00".
      final withLastCharRemoved = controller.text.substring(
        0,
        controller.text.length - 1,
      );
      await tester.enterText(find.byType(TextField), withLastCharRemoved);
      await tester.pump();

      expect(_state(tester).text, '09 : 1');
    });

    testWidgets('backspacing the LAST remaining digit of a segment clears '
        'the whole field to the placeholder, not to "00 : 00"',
        (tester) async {
      await tester.pumpWidget(_host(first: 9, second: null, onChanged: (_, _) {}));
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;

      // Starting value is "09 : mm" (minutes unset) — repeatedly
      // backspace from the end until only the single hour digit remains,
      // then remove that too.
      for (var i = 0; i < 4; i++) {
        final value = controller.value;
        if (value.text.isEmpty) break;
        controller.selection = TextSelection.collapsed(
          offset: value.text.length,
        );
        await tester.pump();
        final shortened = value.text.substring(0, value.text.length - 1);
        await tester.enterText(find.byType(TextField), shortened);
        await tester.pump();
      }

      expect(_state(tester).text, isEmpty);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, 'hh : mm');
    });
  });
}
