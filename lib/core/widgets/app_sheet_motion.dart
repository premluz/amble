import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/motion_primitives.dart';
import '../tokens/semantic_theme.dart';
import 'app_sheet_keyboard.dart';

class AppSheetMotion extends StatefulWidget {
  const AppSheetMotion({
    super.key,
    required this.theme,
    required this.routeAnimation,
    required this.autofocusesKeyboard,
    required this.child,
    this.keyboardFrames,
  });

  final AmbleTheme theme;
  final Animation<double> routeAnimation;
  final bool autofocusesKeyboard;
  final Widget child;
  final Stream<SheetKeyboardFrame>? keyboardFrames;

  @override
  State<AppSheetMotion> createState() => _AppSheetMotionState();
}

class _AppSheetMotionState extends State<AppSheetMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  StreamSubscription<SheetKeyboardFrame>? _subscription;
  Timer? _timeout;
  double? _nativeInset;
  bool _nativeOpening = false;
  bool _entered = false;
  bool _nativeUnavailable = false;
  double? _closingProgress;
  double _closingRouteValue = 1;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: widget.theme.motionSheetSlide,
    );
    widget.routeAnimation.addStatusListener(_routeStatus);
    if (!widget.autofocusesKeyboard) return;
    _subscription = (widget.keyboardFrames ?? SheetKeyboard.frames).listen(
      _keyboardFrame,
      onError: (Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'AppSheet keyboard animation',
          ),
        );
        _startUnmeasuredEntrance();
      },
    );
    _timeout = Timer(
      const Duration(
        milliseconds: MotionPrimitives.durationKeyboardRequestTimeoutMs,
      ),
      _startUnmeasuredEntrance,
    );
  }

  void _routeStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      _timeout?.cancel();
      _closingProgress = _visibleProgress();
      _closingRouteValue = widget.routeAnimation.value;
      _nativeOpening = false;
    } else if (status == AnimationStatus.completed &&
        widget.autofocusesKeyboard &&
        (_nativeUnavailable ||
            (!SheetKeyboard.isAndroid && widget.keyboardFrames == null))) {
      _startUnmeasuredEntrance();
    }
  }

  void _startUnmeasuredEntrance() {
    if (!mounted || _nativeOpening || _entered || _closingProgress != null) {
      return;
    }
    _timeout?.cancel();
    _entered = true;
    _entrance.forward();
  }

  void _keyboardFrame(SheetKeyboardFrame frame) {
    if (!mounted || _closingProgress != null) return;
    if (!frame.available) {
      _nativeUnavailable = true;
      if (widget.routeAnimation.status == AnimationStatus.completed) {
        _startUnmeasuredEntrance();
      }
      return;
    }
    if (!frame.opening) {
      final interrupted = _nativeOpening;
      setState(() {
        _nativeOpening = false;
        _nativeInset = null;
      });
      if (interrupted) _startUnmeasuredEntrance();
      return;
    }
    if (_entered) return;
    if (frame.duration == Duration.zero) {
      _startUnmeasuredEntrance();
      return;
    }
    _timeout?.cancel();
    _nativeOpening = true;
    final duration = frame.duration.inMicroseconds;
    final slide = math.min(duration, widget.theme.motionSheetSlide.inMicroseconds);
    final remaining = duration * (1 - frame.fraction);
    final progress = slide == 0 ? 1.0 : (1 - remaining / slide).clamp(0.0, 1.0);
    setState(() => _nativeInset = frame.inset);
    _entrance.value = progress;
    if (frame.fraction == 1) _finishNativeEntrance();
  }

  void _finishNativeEntrance() {
    _entered = true;
    // FlutterView receives its final IME insets later in this native dispatch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _nativeOpening = false;
        _nativeInset = null;
      });
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _subscription?.cancel();
    widget.routeAnimation.removeStatusListener(_routeStatus);
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveInset = MediaQuery.viewInsetsOf(context).bottom;
    final inset = _nativeOpening ? (_nativeInset ?? liveInset) : liveInset;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.routeAnimation, _entrance]),
          child: widget.child,
          builder: (context, child) => _slide(child!, inset),
        ),
      ),
    );
  }

  double _visibleProgress() {
    final closing = _closingProgress;
    if (closing != null) {
      final remaining = _closingRouteValue == 0
          ? 0.0
          : (widget.routeAnimation.value / _closingRouteValue).clamp(0.0, 1.0);
      return closing * widget.theme.curveStandard.transform(remaining);
    }
    final raw = widget.autofocusesKeyboard
        ? _entrance.value
        : widget.routeAnimation.value;
    return widget.theme.curveDecelerate.transform(raw);
  }

  Widget _slide(Widget child, double inset) {
    final progress = _visibleProgress();
    return IgnorePointer(
      ignoring: progress == 0,
      child: Opacity(
        opacity: progress == 0 ? 0 : 1,
        child: FractionalTranslation(
          translation: Offset(0, 1 - progress),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(0, MediaQuery.sizeOf(context).height - inset),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
