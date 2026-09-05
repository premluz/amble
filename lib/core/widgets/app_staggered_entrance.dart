import 'package:flutter/material.dart';

/// A short fade+slide-up entrance for one item in a staggered sequence —
/// each successive [index] starts [_stagger] later than the one before it,
/// so a list of panes reads as arriving one after another rather than all
/// at once.
///
/// Promoted out of `task_detail_sheet.dart`'s own private
/// `_StaggeredEntrance` (same shape [AppStepScaffold] was promoted from)
/// specifically so the zone-creation flow could reuse the exact same
/// stage-1/stage-2 reveal the task-creation flow already uses — requested
/// directly: zones "should follow same pattern of creation as tasks."
class AppStaggeredEntrance extends StatefulWidget {
  const AppStaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  /// This item's position in the sequence — 0 starts immediately, each
  /// following index delays by another [_stagger].
  final int index;
  final Widget child;

  @override
  State<AppStaggeredEntrance> createState() => _AppStaggeredEntranceState();
}

class _AppStaggeredEntranceState extends State<AppStaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _stagger = Duration(milliseconds: 40);
  static const _duration = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fade);
    Future.delayed(_stagger * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
