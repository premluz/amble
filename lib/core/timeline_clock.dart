import 'package:flutter/material.dart';

/// A time as written in the Day screen's LEFT time column (hour ticks, a
/// task's start/end, the "now" label, the list view's row times). In
/// 24-hour: "13:41", as ever. In 12-hour it is compact, so it fits the same
/// fixed column as 24-hour and switching format never pushes the timeline:
/// a whole hour reads "9 am" / "12 pm", any other time "9:15a" / "12:45p"
/// (day-period in lower case, like the rest of the app).
/// The column is sized for the widest of these (see
/// `TimelineColumns.timelineTimeColumnWidth`).
String timelineClock(BuildContext context, TimeOfDay time) => timelineClockText(
  time,
  use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
);

/// [timelineClock] without a context: the same text for [use24Hour].
/// 24-hour is zero-padded ("09:05"), as `TimeOfDay.format` writes it.
String timelineClockText(TimeOfDay time, {required bool use24Hour}) {
  final minute = time.minute.toString().padLeft(2, '0');
  if (use24Hour) return '${time.hour.toString().padLeft(2, '0')}:$minute';
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final pm = time.period == DayPeriod.pm;
  if (time.minute == 0) return '$hour ${pm ? 'pm' : 'am'}';
  return '$hour:$minute${pm ? 'p' : 'a'}';
}

/// Every label the column must fit, for measuring its width: each hour in
/// both formats, whole and with a spread of minutes. Measured, not
/// assumed from character counts — the default font is proportional, so
/// the widest label depends on the font, not on its length.
List<String> timelineClockSamples() => [
  for (final use24Hour in [false, true])
    for (var hour = 0; hour < 24; hour++)
      for (final minute in const [0, 8, 15, 30, 44, 45, 48, 59])
        timelineClockText(
          TimeOfDay(hour: hour, minute: minute),
          use24Hour: use24Hour,
        ),
];
