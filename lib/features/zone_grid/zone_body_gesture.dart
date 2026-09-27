import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Claims a deliberate block drag before its enclosing scroll view, while
/// leaving taps available for selection and empty space available for scrolling.
class ZoneBodyGesture extends StatelessWidget {
  const ZoneBodyGesture({
    super.key,
    required this.child,
    required this.onTap,
    this.onStart,
    this.onUpdate,
    this.onEnd,
  });

  final Widget child;
  final VoidCallback onTap;
  final GestureDragStartCallback? onStart;
  final GestureDragUpdateCallback? onUpdate;
  final GestureDragEndCallback? onEnd;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.opaque,
    gestures: {
      TapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            () => TapGestureRecognizer(debugOwner: this),
            (instance) => instance.onTap = onTap,
          ),
      _BlockPanRecognizer:
          GestureRecognizerFactoryWithHandlers<_BlockPanRecognizer>(
            () => _BlockPanRecognizer(debugOwner: this),
            (instance) => instance
              ..dragStartBehavior = DragStartBehavior.down
              ..onStart = onStart
              ..onUpdate = onUpdate
              ..onEnd = onEnd,
          ),
    },
    child: child,
  );
}

class _BlockPanRecognizer extends PanGestureRecognizer {
  _BlockPanRecognizer({super.debugOwner});

  static const _slopFraction = 0.5;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved.abs() >
      computeHitSlop(pointerDeviceKind, gestureSettings) * _slopFraction;
}
