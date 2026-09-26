import 'package:flutter/widgets.dart';

import '../../core/widgets/app_layout_reveal.dart';

/// Allows the incoming day view to lay out before its first visible frame.
class DayViewReveal extends StatelessWidget {
  const DayViewReveal({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AppLayoutReveal(
    opacityKey: const ValueKey('positioned-zone-content'),
    child: child,
  );
}
