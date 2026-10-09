import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/motion_primitives.dart';
import '../tokens/semantic_theme.dart';
import 'app_floating_surface.dart';
import 'app_liquid_morph.dart';
import 'app_popover_geometry.dart';
import 'app_size_reporter.dart';

/// The route behind [AppSheetPresentation.popover]: [builder]'s content in
/// a glass panel beside [anchor] (screen coordinates), sized to that
/// content. No scrim, so the rest of the screen stays readable; a tap
/// outside closes it, as a sheet's scrim does. It grows out of the anchor
/// like the anchored context menu, and fades on the way out.
class AppPopoverRoute<T> extends PopupRoute<T> {
  AppPopoverRoute({
    required this.anchor,
    required this.theme,
    required this.builder,
  });

  final Rect anchor;
  final AmbleTheme theme;
  final WidgetBuilder builder;

  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: MotionPrimitives.durationFastMs);

  @override
  Duration get reverseTransitionDuration =>
      const Duration(milliseconds: MotionPrimitives.durationInstantMs);

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => 'Dismiss';

  @override
  Color get barrierColor => Colors.transparent;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _PopoverBody(
    anchor: anchor,
    theme: theme,
    animation: animation,
    child: Builder(builder: builder),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Measures the content off stage first, then places the panel where its
/// real size fits and starts the entrance there. The content is keyed, so
/// moving it on stage keeps its state; later size changes (a toggle that
/// reveals more, a page pushed in a flow) resize the panel in place.
class _PopoverBody extends StatefulWidget {
  const _PopoverBody({
    required this.anchor,
    required this.theme,
    required this.animation,
    required this.child,
  });

  final Rect anchor;
  final AmbleTheme theme;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_PopoverBody> createState() => _PopoverBodyState();
}

class _PopoverBodyState extends State<_PopoverBody> {
  final _contentKey = GlobalKey();
  double? _height;

  void _onSize(Size size) {
    if (mounted && size.height != _height) {
      setState(() => _height = size.height);
    }
  }

  /// The screen minus safe areas, the keyboard and a small margin.
  Rect _bounds(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = widget.theme.spacingSm;
    return Rect.fromLTRB(
      media.padding.left + inset,
      media.padding.top + inset,
      media.size.width - media.padding.right - inset,
      media.size.height -
          math.max(media.padding.bottom, media.viewInsets.bottom) -
          inset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final bounds = _bounds(context);
    final width = math.min(PopoverTokens.width, bounds.width);
    final maxHeight = math.max(0.0, bounds.height);
    final content = KeyedSubtree(
      key: _contentKey,
      child: AppSizeReporter(onSize: _onSize, child: widget.child),
    );
    final height = _height;
    if (height == null) {
      return Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: width,
            child: Offstage(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: content,
              ),
            ),
          ),
        ],
      );
    }
    final origin = popoverOrigin(
      anchor: widget.anchor,
      size: Size(width, height),
      bounds: bounds,
      gap: theme.spacingSm,
    );
    final radius = theme.radiusXxl;
    return Stack(
      children: [
        Positioned(
          left: origin.dx,
          top: origin.dy,
          width: width,
          height: height,
          child: FadeTransition(
            opacity: _exitOpacity(widget.animation),
            child: AppLiquidMorph(
              origin: widget.anchor.center - origin,
              borderRadius: radius,
              child: AppFloatingSurface(
                theme: theme,
                borderRadius: BorderRadius.circular(radius),
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: maxHeight,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fully opaque while opening (the morph is the entrance); follows the
/// route back to zero while closing.
Animation<double> _exitOpacity(Animation<double> route) => _ExitOpacity(route);

class _ExitOpacity extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ExitOpacity(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value =>
      parent.status == AnimationStatus.reverse ? parent.value : 1;
}
