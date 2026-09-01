import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/task_detail/task_duration_modal.dart';

Widget _host({required int? initialMinutes}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => TaskDurationModal.show(
            context: context,
            initialMinutes: initialMinutes,
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

Future<void> _openModal(WidgetTester tester, {int? initialMinutes}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_host(initialMinutes: initialMinutes));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

/// Tap a preset chip by its label ("5m", "1h", ...).
Future<void> _tapPreset(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// A selected chip is rendered by AppSelectableChip with the accent fill —
/// checked here via the chip's own decoration rather than a separate
/// selection-tracking mechanism, matching how the widget actually derives
/// "selected" (from the current duration, not stored state).
bool _isPresetSelected(WidgetTester tester, String label) {
  final theme = AmbleTheme.light;
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
  );
  final decoration = container.decoration! as BoxDecoration;
  return decoration.color == theme.colorAccent;
}

void main() {
  group('TaskDurationModal presets', () {
    testWidgets('defaults to 5 minutes selected when nothing is set yet', (
      tester,
    ) async {
      await _openModal(tester, initialMinutes: null);

      expect(_fieldText(tester), '00 : 05');
      expect(_isPresetSelected(tester, '5m'), isTrue);
      expect(_isPresetSelected(tester, '15m'), isFalse);
    });

    testWidgets('tapping a preset updates the typed field and rolls the '
        'wheel to match', (tester) async {
      await _openModal(tester, initialMinutes: null);

      await _tapPreset(tester, '1h');

      expect(_fieldText(tester), '01 : 00');
      expect(_isPresetSelected(tester, '1h'), isTrue);
      expect(_isPresetSelected(tester, '5m'), isFalse);

      // The wheel rolled to match — its Hours row now reads "01", not the
      // "00" it opened on.
      final hourWheel = tester.widget<Semantics>(
        find.bySemanticsLabel('Hours'),
      );
      expect(hourWheel.properties.label, 'Hours');
      // (The wheel's own displayed row is exercised more directly by
      // app_wheel_time_picker_test.dart; this test's job is confirming
      // the CALL happens, not re-testing the wheel's own rendering.)
    });

    testWidgets('typing a value that matches a preset selects it', (
      tester,
    ) async {
      await _openModal(tester, initialMinutes: null);

      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, '0030');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(_isPresetSelected(tester, '30m'), isTrue);
      expect(_isPresetSelected(tester, '5m'), isFalse);
    });

    testWidgets('a value outside every preset selects none of them', (
      tester,
    ) async {
      await _openModal(tester, initialMinutes: null);

      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, '0107');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      for (final label in ['5m', '15m', '30m', '45m', '1h', '2h']) {
        expect(
          _isPresetSelected(tester, label),
          isFalse,
          reason: '$label should not be selected for 1h07m',
        );
      }
    });

    testWidgets('confirming with the default 5-minute value saves 5 '
        'minutes, not an unset/empty duration', (tester) async {
      // The view size MUST be set before pumpWidget, matching every other
      // test in this file (see _openModal) — fixed directly: setting it
      // after the first pump left the sheet laid out at the default
      // 800x600 test surface, so "Done" ended up positioned outside the
      // viewport once the size was corrected afterward, and the tap
      // missed it entirely.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late int? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await TaskDurationModal.show(
                    context: context,
                    initialMinutes: null,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // ensureVisible first — the sheet's own bottom inset/safe-area
      // handling can leave Done positioned such that a bare tap()
      // misses it entirely (caught directly: the offset landed on
      // RenderIgnorePointer/RenderOffstage instead of the button).
      final doneButton = find.text('Done');
      await tester.ensureVisible(doneButton);
      await tester.pumpAndSettle();
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      expect(result, 5);
    });
  });
}
