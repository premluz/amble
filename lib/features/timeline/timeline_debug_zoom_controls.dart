import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_config.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../shared/providers/preferences_providers.dart';
import 'timeline_simulated_pinch.dart';

/// Keyboard pinch preview, gated by the existing developer touch setting.
class TimelineDebugZoomControls extends ConsumerStatefulWidget {
  const TimelineDebugZoomControls({
    super.key,
    required this.child,
    required this.multiTouch,
    this.scrollController,
  });
  final Widget child;
  final ValueNotifier<bool> multiTouch;
  final ScrollController? scrollController;

  @override
  ConsumerState<TimelineDebugZoomControls> createState() => _DebugZoomState();
}

class _DebugZoomState extends ConsumerState<TimelineDebugZoomControls>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this)
    ..addListener(_tick)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _stop();
    });
  final _pressed = <int>{};
  Offset? _hover;
  SimulatedPinch? _pinch;

  @override
  void initState() {
    super.initState();
    if (isDevConfigAvailable) HardwareKeyboard.instance.addHandler(_key);
  }

  bool get _enabled => isDevConfigAvailable && ref.read(devShowTouchesProvider);
  bool get _current => ModalRoute.of(context)?.isCurrent ?? true;
  bool get _typing {
    final focus = FocusManager.instance.primaryFocus?.context;
    return focus?.widget is EditableText ||
        focus?.findAncestorStateOfType<EditableTextState>() != null;
  }

  bool _key(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (!_enabled ||
        !_current ||
        _hover == null ||
        _typing ||
        _pressed.isNotEmpty ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        keyboard.isShiftPressed) {
      return false;
    }
    final zoomIn =
        event.logicalKey == LogicalKeyboardKey.digit1 ||
        event.logicalKey == LogicalKeyboardKey.numpad1;
    final zoomOut =
        event.logicalKey == LogicalKeyboardKey.digit2 ||
        event.logicalKey == LogicalKeyboardKey.numpad2;
    if (!zoomIn && !zoomOut) return false;
    if (event is KeyDownEvent && _pinch == null) _start(zoomIn);
    return true;
  }

  void _start(bool zoomIn) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final scroll = widget.scrollController;
    final scale = ref.read(timelinePixelsPerMinuteSettingProvider);
    _pinch = SimulatedPinch(
      center: _hover!,
      startScale: scale,
      zoomIn: zoomIn,
      scrollOffset: scroll != null && scroll.hasClients ? scroll.offset : 0,
    );
    widget.multiTouch.value = true;
    _animation.duration = theme.motionSlow;
    _animation.forward(from: 0);
  }

  void _tick() {
    final pinch = _pinch;
    if (pinch == null) return;
    if (!_enabled || !_current || _typing) {
      _stop();
      return;
    }
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final scale = pinch.scaleAt(
      theme.curveStandard.transform(_animation.value),
    );
    ref.read(timelinePixelsPerMinuteSettingProvider.notifier).set(scale);
    _anchor(pinch.scrollAt(scale));
    setState(() {});
  }

  void _anchor(double offset) {
    final scroll = widget.scrollController;
    if (scroll == null) return;
    // Extents change during layout; apply the cursor anchor after that frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      final position = scroll.position;
      scroll.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  void _stop() {
    if (_pinch == null) return;
    _animation.stop();
    _pinch = null;
    widget.multiTouch.value = false;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_key);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(devShowTouchesProvider, (_, enabled) {
      if (!enabled) _stop();
    });
    return MouseRegion(
      onHover: (event) => _hover = event.localPosition,
      onExit: (_) {
        _hover = null;
        _stop();
      },
      child: Listener(
        onPointerDown: (event) {
          _pressed.add(event.pointer);
          _stop();
        },
        onPointerUp: (event) => _pressed.remove(event.pointer),
        onPointerCancel: (event) => _pressed.remove(event.pointer),
        child: Stack(
          children: [
            widget.child,
            if (_pinch case final pinch?) _overlay(context, pinch),
          ],
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context, SimulatedPinch pinch) =>
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: SimulatedPinchPainter(
              pinch: pinch,
              progress: _animation.value,
              theme: Theme.of(context).extension<AmbleTheme>()!,
            ),
          ),
        ),
      );
}
