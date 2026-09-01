import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_field_action_button.dart';
import 'package:amble/core/widgets/app_segmented_time_field.dart';
import 'package:amble/core/widgets/app_wheel_time_picker.dart';

/// Drives the picker through the SAME arrangement the schedule step uses —
/// a segmented field whose trailing button opens the wheels — because the
/// thing worth protecting is the round trip (open, choose, confirm, and
/// see the field update), not the picker in isolation.
Widget _host({
  required void Function(int?, int?) onValue,
  int? initialHour,
  int? initialMinute,
}) {
  int? hour = initialHour;
  int? minute = initialMinute;
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
    home: StatefulBuilder(
      builder: (context, setState) {
        return Scaffold(
          body: AppSegmentedTimeField(
            label: 'Duration',
            first: hour,
            second: minute,
            firstMax: null,
            trailing: AppFieldActionButton(
              icon: Icons.timer_outlined,
              semanticLabel: 'Choose duration',
              onPressed: () async {
                final result = await AppWheelTimePicker.show(
                  context: context,
                  title: 'Duration',
                  initialHour: hour ?? 0,
                  initialMinute: minute ?? 0,
                );
                if (result == null) return;
                setState(() {
                  hour = result.$1;
                  minute = result.$2;
                });
                onValue(hour, minute);
              },
            ),
            onChanged: (a, b) {
              setState(() {
                hour = a;
                minute = b;
              });
              onValue(hour, minute);
            },
          ),
        );
      },
    ),
  );
}

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  group('AppWheelTimePicker', () {
    // A real phone viewport: the default 800px test surface is shorter
    // than the sheet, which puts the confirm button's hit-test position
    // out of step with where it renders.
    void useMobileViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('confirming writes the chosen value back to the field', (
      tester,
    ) async {
      useMobileViewport(tester);
      int? committedHour;
      await tester.pumpWidget(_host(onValue: (h, _) => committedHour = h));

      // Starts unset — the field shows its placeholder, not a value.
      expect(_fieldText(tester), isEmpty);

      await tester.tap(find.bySemanticsLabel('Choose duration'));
      await tester.pumpAndSettle();

      // Scroll the hours wheel, then confirm.
      await tester.drag(find.bySemanticsLabel('Hours'), const Offset(0, -80));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // The field reflects the wheel's value — the two entry methods write
      // the same underlying value rather than being separate modes.
      expect(committedHour, 2);
      expect(_fieldText(tester), '02 : 00');
    });

    testWidgets('changing an ALREADY SET value updates the field', (
      tester,
    ) async {
      useMobileViewport(tester);
      int? committedHour;
      await tester.pumpWidget(
        _host(
          onValue: (h, _) => committedHour = h,
          initialHour: 0,
          initialMinute: 3,
        ),
      );

      // Starts with a real value, unlike the empty case above.
      expect(_fieldText(tester), '00 : 03');

      await tester.tap(find.bySemanticsLabel('Choose duration'));
      await tester.pumpAndSettle();
      await tester.drag(find.bySemanticsLabel('Hours'), const Offset(0, -80));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(committedHour, 2);
      expect(_fieldText(tester), '02 : 03');
    });

    testWidgets('updates a field that still has FOCUS — the picker button '
        'lives inside the field, so tapping it never blurs', (tester) async {
      useMobileViewport(tester);
      int? committedHour;
      await tester.pumpWidget(
        _host(
          onValue: (h, _) => committedHour = h,
          initialHour: 0,
          initialMinute: 3,
        ),
      );

      // Focus the field first, the way typing a value would leave it.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(_fieldText(tester), '00 : 03');

      await tester.tap(find.bySemanticsLabel('Choose duration'));
      await tester.pumpAndSettle();
      await tester.drag(find.bySemanticsLabel('Hours'), const Offset(0, -80));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // A resync guard that skipped while focused silently swallowed this
      // — the field kept showing its old value after every wheel change.
      // Minutes are untouched (the wheel opened on the existing 3), so
      // only the hour moves.
      expect(committedHour, 2);
      expect(_fieldText(tester), '02 : 03');
    });

    testWidgets('dismissing without confirming leaves the field untouched', (
      tester,
    ) async {
      useMobileViewport(tester);
      var committed = false;
      await tester.pumpWidget(_host(onValue: (_, _) => committed = true));

      await tester.tap(find.bySemanticsLabel('Choose duration'));
      await tester.pumpAndSettle();
      await tester.drag(find.bySemanticsLabel('Hours'), const Offset(0, -80));
      await tester.pumpAndSettle();

      // Tap the scrim rather than Done — a cancelled picker must not
      // commit whatever the wheels happened to be showing.
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();

      expect(committed, isFalse);
      expect(_fieldText(tester), isEmpty);
    });
  });
}
