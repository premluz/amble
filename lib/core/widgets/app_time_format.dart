import 'package:flutter/widgets.dart';

/// Imposes 12- or 24-hour time on everything below it — every
/// `TimeOfDay.format` reads `MediaQuery.alwaysUse24HourFormat`. Placed once
/// at the app's root (Settings → Appearance → Time format). [use24Hour]
/// null leaves the device's own setting in place.
class AppTimeFormat extends StatelessWidget {
  const AppTimeFormat({
    super.key,
    required this.use24Hour,
    required this.child,
  });

  final bool? use24Hour;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final imposed = use24Hour;
    if (imposed == null) return child;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: imposed),
      child: child,
    );
  }
}
