import 'dart:io';

import 'package:amble/core/amble_material_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('times format with a lower-case day-period: "9:00 pm"', (
    tester,
  ) async {
    late String evening;
    late String morning;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AmbleMaterialLocalizations.delegate],
        home: Builder(
          builder: (context) {
            evening = const TimeOfDay(hour: 21, minute: 0).format(context);
            morning = const TimeOfDay(hour: 9, minute: 30).format(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(evening, '9:00 pm');
    expect(morning, '9:30 am');
  });

  test('the app registers it, so this holds everywhere', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('AmbleMaterialLocalizations.delegate'));
  });
}
