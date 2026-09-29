import 'package:flutter/widgets.dart';

/// Clips its child at the top and bottom only, leaving the sides open. For a
/// page's scrolling list (with its own `clipBehavior: Clip.none`): rows still
/// never scroll over the chrome above or below, but while the page slides,
/// its items can trail past the page's side edges ([AppFollowThrough])
/// instead of being cut off there.
class AppVerticalClip extends StatelessWidget {
  const AppVerticalClip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ClipRect(clipper: const _VerticalClipper(), child: child);
}

class _VerticalClipper extends CustomClipper<Rect> {
  const _VerticalClipper();

  @override
  // A full width of slack on each side covers any trail (at most one page
  // width) while staying finite for the clip layer.
  Rect getClip(Size size) =>
      Rect.fromLTRB(-size.width, 0, size.width * 2, size.height);

  @override
  bool shouldReclip(_VerticalClipper oldClipper) => false;
}
