import 'package:amble/core/timeline_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _clock(
  WidgetTester tester,
  TimeOfDay time, {
  required bool use24Hour,
}) async {
  late String out;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(alwaysUse24HourFormat: use24Hour),
      child: Localizations(
        locale: const Locale('en', 'US'),
        delegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            out = timelineClock(context, time);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return out;
}

void main() {
  testWidgets('24-hour is unchanged', (tester) async {
    expect(
      await _clock(
        tester,
        const TimeOfDay(hour: 13, minute: 41),
        use24Hour: true,
      ),
      '13:41',
    );
    expect(
      await _clock(
        tester,
        const TimeOfDay(hour: 9, minute: 0),
        use24Hour: true,
      ),
      '09:00',
    );
  });

  testWidgets('12-hour is compact: whole hours "9 am"/"12 pm", other times '
      '"9:15a"/"12:45p"', (tester) async {
    Future<String> twelve(int h, int m) =>
        _clock(tester, TimeOfDay(hour: h, minute: m), use24Hour: false);
    expect(await twelve(9, 0), '9 am');
    expect(await twelve(12, 0), '12 pm');
    expect(await twelve(0, 0), '12 am');
    expect(await twelve(9, 15), '9:15a');
    expect(await twelve(12, 45), '12:45p');
    expect(await twelve(23, 5), '11:05p');
  });

  test('the column is measured against every label either format writes — '
      'including "12 pm", which in a proportional font is the widest', () {
    final samples = timelineClockSamples();
    expect(
      samples,
      containsAll(['12 pm', '12 am', '12:45p', '13:44', '09:08']),
    );
    expect(samples.every((label) => label.isNotEmpty), isTrue);
  });
}
