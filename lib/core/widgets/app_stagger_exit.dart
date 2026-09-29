import 'package:flutter/widgets.dart';

import '../tokens/header_reveal_spec.dart';

/// Hands a header's exit animation down to its items, so each can leave in
/// turn ([AppStaggerExit]). Without a scope the items simply show.
class AppStaggerExitScope extends InheritedWidget {
  const AppStaggerExitScope({
    super.key,
    required this.progress,
    required super.child,
  });

  /// 0 = items showing, 1 = all gone.
  final Animation<double> progress;

  static Animation<double>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppStaggerExitScope>()
      ?.progress;

  @override
  bool updateShouldNotify(AppStaggerExitScope oldWidget) =>
      progress != oldWidget.progress;
}

/// One item of a staggered exit: item [index] fades out in its own window
/// of [HeaderRevealSpec], after the items before it.
class AppStaggerExit extends StatelessWidget {
  const AppStaggerExit({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final progress = AppStaggerExitScope.maybeOf(context);
    if (progress == null) return child;
    final (start, end) = HeaderRevealSpec.itemWindow(index);
    final curve = Interval(start, end.clamp(start, 1.0));
    return FadeTransition(
      opacity: ReverseAnimation(
        CurvedAnimation(parent: progress, curve: curve),
      ),
      child: child,
    );
  }
}
