import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_press_feedback.dart';
import 'task_edge_time_label.dart';
import 'timeline_drag_math.dart';

/// Snap granularity for the placement line's dropped time — matches the
/// task-drag reschedule's own snap (see `timeline_screen.dart`'s
/// `_snapMinutes`), so a task created here and one dragged there land on
/// the same rhythm of times.
const _snapMinutes = 5;

/// **2026-09-27 — superseded by the "quick task add" long-press flow.**
/// Requested directly: "on timeline day spatial long press shows line
/// that when release in that position options create task or move / Let's
/// put it aside comment out or archive... Instead of tap to create new
/// task we'll have 'quick task add'... long press and when task is shown
/// (no sheet yet coming) user can move down or up to set length... on
/// release we show sheet quick add."
///
/// [PlaceTaskLineLayer] no longer draws a moving line and hands the
/// release to a "Move all"/"New task" menu (`place_task_release_menu.dart`,
/// left in the codebase unused per the same "archive, don't delete"
/// instruction). It now starts a `PendingTaskDraft` directly the instant
/// the long-press is recognized — so the provisional placeholder PILL itself
/// appears immediately, before any drag — then reports the hold's
/// vertical delta as a live duration change for the rest of the hold, and
/// fires [onHoldReleased] on release so the caller can reveal the
/// quick-create sheet. [PlaceTaskLineOverlay] and
/// [PlaceTaskLineController] are likewise kept, now unused, since nothing
/// draws a line any more.
///
/// Still built on [LongPressDraggable] rather than a hand-rolled
/// `RawGestureDetector`/`LongPressGestureRecognizer` — the earlier
/// hand-rolled version never reliably worked once a `SingleChildScrollView`
/// ancestor was in the picture (wrong drop position, no drag tracking at
/// all on a real device). `LongPressDraggable` is Flutter's own
/// purpose-built widget for exactly this interaction — the same mechanism
/// `ReorderableListView` itself uses internally — and reliably survives a
/// scrollable ancestor, which is the whole reason it exists. `feedback` is
/// invisible; the placeholder pill (drawn elsewhere in the Stack, driven
/// by the pending-draft provider) is the real visual, in the timeline's
/// own coordinate space rather than the app-wide `Overlay` `feedback`
/// would otherwise float in.
///
/// This widget MUST be the FIRST child in the timeline's Stack — a `Stack`
/// hit-tests from last child to first, so every task pill and free-window
/// block (added later in that list) gets first refusal at any pointer down
/// before it reaches this background layer. Combined with those widgets'
/// own `HitTestBehavior.opaque`, a press that starts on a pill or a
/// free-window block never reaches here at all — exactly "not on the
/// pill."
typedef PlaceTaskLineController = ValueNotifier<double?>;

class PlaceTaskLineLayer extends StatefulWidget {
  const PlaceTaskLineLayer({
    super.key,
    required this.theme,
    required this.rangeStart,
    required this.rangeEnd,
    required this.pixelsPerMinute,
    required this.controller,
    required this.onHoldStarted,
    required this.onDurationDeltaChanged,
    required this.onHoldReleased,
    this.onEmptyTap,
  });

  final AmbleTheme theme;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final double pixelsPerMinute;

  /// Unused by the current "quick task add" gesture — kept only so
  /// [PlaceTaskLineOverlay] (archived alongside the rest of the old
  /// mechanism) still type-checks against a live controller.
  final PlaceTaskLineController controller;

  /// Fired the instant a long-press on empty Timeline background is
  /// recognized, with the pressed instant already snapped to
  /// [_snapMinutes] and clamped inside [rangeStart]/[rangeEnd] — the
  /// caller starts the pending draft here so the placeholder pill appears
  /// immediately, before any drag. Requested directly: "long press and
  /// when task is shown (no sheet yet coming) user can move down or up to
  /// set length."
  final ValueChanged<DateTime> onHoldStarted;

  /// Fired on every pointer move for the rest of the same hold, with the
  /// TOTAL vertical delta (in minutes, already snapped to
  /// [resizeSnapMinutes]) since [onHoldStarted] — the caller applies this
  /// as a live duration change on the same draft. Positive means the
  /// finger has moved down (longer), matching a bottom-edge resize.
  final ValueChanged<int> onDurationDeltaChanged;

  /// Fired on release — the caller reveals the quick-create sheet for the
  /// draft [onHoldStarted] already started.
  final VoidCallback onHoldReleased;

  /// A short tap on empty Timeline space. Observed from raw pointer events
  /// so it does not add a TapGestureRecognizer that could defeat the
  /// long-press quick-create recognizer below.
  final VoidCallback? onEmptyTap;

  @override
  State<PlaceTaskLineLayer> createState() => _PlaceTaskLineLayerState();
}

class _PlaceTaskLineLayerState extends State<PlaceTaskLineLayer> {
  /// Anchors this layer's inner [Stack] — every drag position (delivered
  /// in screen/global coordinates by [LongPressDraggable]) is converted
  /// back through this key via `RenderBox.globalToLocal`. Deliberately on
  /// the Stack rather than any wrapper: it's a real `RenderStack` box AND
  /// it's the exact coordinate space `_PlacementLine` positions itself in,
  /// so the converted value and the rendered position can't disagree.
  final _anchorKey = GlobalKey();

  /// The most recent raw pointer position, tracked independently of the
  /// drag's own gesture-arena participation via a `Listener` (see build())
  /// — `Draggable`'s own `onDragUpdate` only fires once the pointer has
  /// actually MOVED past its start (see `_DragAvatar.update`'s
  /// `_position != oldPosition` guard), so a hold that's released
  /// perfectly still would never fire it at all and the draft would never
  /// start. `onDragStarted` (fired the instant the hold completes) has
  /// no position of its own — this field is what supplies one.
  Offset? _lastPointerPosition;

  /// The Y position (this layer's own local coordinate space) the hold
  /// started at — the draft's start time is fixed here for the rest of
  /// the hold; only the duration changes as the finger moves, via
  /// [_reportDurationDelta].
  double? _holdStartY;

  /// Set once [LongPressDraggable] actually begins a drag, so
  /// [PlaceTaskLineLayer.onHoldReleased] only fires for a hold that
  /// actually started one.
  bool _dragStarted = false;
  int? _tapPointer;
  Offset? _tapOrigin;
  Duration? _tapStartedAt;

  double get _totalMinutes =>
      widget.rangeEnd.difference(widget.rangeStart).inMinutes.toDouble();

  double get _maxTop => _totalMinutes * widget.pixelsPerMinute;

  DateTime _instantAt(double top) {
    final rawMinutes = top / widget.pixelsPerMinute;
    final snapped = (rawMinutes / _snapMinutes).round() * _snapMinutes;
    final clamped = snapped.clamp(0, _totalMinutes.floor());
    return widget.rangeStart.add(Duration(minutes: clamped));
  }

  double? _localY(Offset globalPosition) {
    final renderObject = _anchorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    return renderObject.globalToLocal(globalPosition).dy;
  }

  /// Reports the total vertical delta since the hold started, converted
  /// to a snapped minutes delta — [PlaceTaskLineLayer.onDurationDeltaChanged]
  /// applies it as a live duration on the same draft [_holdStartY] already
  /// anchored the start of.
  void _reportDurationDelta(Offset globalPosition) {
    final startY = _holdStartY;
    if (startY == null) return;
    final y = _localY(globalPosition);
    if (y == null) return;
    final rawDelta = y - startY;
    final snapped = snappedDurationDelta(rawDelta, widget.pixelsPerMinute);
    widget.onDurationDeltaChanged(snapped);
  }

  void _observePointerDown(PointerDownEvent event) {
    if (_tapPointer != null) {
      _cancelTapCandidate();
      return;
    }
    _tapPointer = event.pointer;
    _tapOrigin = event.position;
    _tapStartedAt = event.timeStamp;
    _lastPointerPosition = event.position;
    _dragStarted = false;
  }

  void _observePointerMove(PointerMoveEvent event) {
    _lastPointerPosition = event.position;
    if (event.pointer != _tapPointer) return;
    final origin = _tapOrigin;
    if (origin != null && (event.position - origin).distance > kTouchSlop) {
      _cancelTapCandidate();
    }
  }

  void _observePointerUp(PointerUpEvent event) {
    if (event.pointer != _tapPointer) return;
    final origin = _tapOrigin;
    final startedAt = _tapStartedAt;
    final isTap =
        !_dragStarted &&
        origin != null &&
        startedAt != null &&
        (event.position - origin).distance <= kTouchSlop &&
        event.timeStamp - startedAt < kLongPressTimeout;
    _cancelTapCandidate();
    if (isTap) widget.onEmptyTap?.call();
  }

  void _cancelTapCandidate() {
    _tapPointer = null;
    _tapOrigin = null;
    _tapStartedAt = null;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // Listener wraps the draggable purely to observe raw pointer
      // events — it doesn't participate in the gesture arena at all, so
      // it can't interfere with LongPressDraggable's own recognizer or
      // the ancestor SingleChildScrollView's. Only used to know where the
      // finger currently is at the moment the hold completes (see
      // _lastPointerPosition's own doc comment).
      child: Listener(
        onPointerDown: _observePointerDown,
        onPointerMove: _observePointerMove,
        onPointerUp: _observePointerUp,
        onPointerCancel: (_) => _cancelTapCandidate(),
        // The anchor key sits on a real RenderBox (this SizedBox), never
        // on a `Positioned`/`Listener` — `Positioned` is a
        // ParentDataWidget with no box of its own, so `findRenderObject()`
        // through it resolves to whatever descendant comes first, exactly
        // the ambiguity that can silently yield a consistently-wrong
        // offset. This box fills the day column, so its local space is the
        // same one the hold's start position is measured in.
        child: SizedBox.expand(
          key: _anchorKey,
          // decorationOnly: this layer's own GestureDetector below (and
          // LongPressDraggable beside it) must keep owning the gesture
          // arena exactly as documented there — AppPressFeedback here
          // only OBSERVES pointers to paint the wash, so the hold-to-place
          // interaction doesn't change at all.
          //
          // maxRippleRadius, unlike every other caller: this layer covers
          // the whole day column, so an uncapped wash would flood the
          // entire Timeline instead of marking the spot the finger landed
          // on. Confirmed directly as a "small ripple at the tap point."
          // No scale-down either — there is no control here to dip, only
          // empty background.
          child: AppPressFeedback(
            decorationOnly: true,
            maxRippleRadius: _tapRippleRadius,
            // Silent, unlike every other AppPressFeedback: this layer is
            // the whole empty day column, so it sees the first touch of
            // every scroll and every drag that merely *starts* on blank
            // background. A tap haptic here would fire constantly while
            // just moving around the Timeline. The long-press-to-place
            // interaction this layer hosts carries its own haptic at its
            // own commit point (see [PlaceTaskLineLayer.onHoldStarted]'s
            // call site).
            haptic: null,
            // Deliberately NO onTap. A non-null onTap here builds a real
            // TapGestureRecognizer as an ANCESTOR of LongPressDraggable's
            // own recognizer; on a stationary hold both enter the arena,
            // the tap one is nearer the root and never yields, so the
            // long press never wins and onDragStarted never fires at all.
            onTap: null,
            child: LongPressDraggable<Object>(
              // OPAQUE, not the default deferToChild — fixed directly after
              // this stopped firing entirely: `deferToChild` hit-tests
              // against the child's own painted content, and the child
              // here paints nothing, so there was literally nothing to hit
              // and the pointer passed straight through without the
              // recognizer ever seeing it. Opaque makes this layer claim
              // its whole area regardless of what its child paints.
              hitTestBehavior: HitTestBehavior.opaque,
              // Invisible: the placeholder pill itself (drawn elsewhere in
              // the Stack, driven by the pending-draft provider) is the
              // real visual — this feedback exists only to drive
              // `onDragUpdate`'s stream of `globalPosition`s.
              feedback: const SizedBox.shrink(),
              onDragStarted: () {
                _dragStarted = true;
                final position = _lastPointerPosition;
                final y = position == null ? null : _localY(position);
                if (y == null) return;
                final startY = y.clamp(0.0, _maxTop);
                _holdStartY = startY;
                widget.onHoldStarted(_instantAt(startY));
              },
              onDragUpdate: (details) =>
                  _reportDurationDelta(details.globalPosition),
              onDragEnd: (details) {
                final started = _dragStarted;
                _dragStarted = false;
                _holdStartY = null;
                if (started) widget.onHoldReleased();
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

/// How far the tap-to-create wash spreads from the finger. A small fixed
/// radius rather than this layer's own (full-day-column) bounds — see the
/// `maxRippleRadius` note at its call site above.
const double _tapRippleRadius = 48;

/// Draws the placement line, and nothing else. Rendered as the LAST child
/// of the timeline's Stack so it paints above every task — requested
/// directly after the line appeared underneath them. Kept separate from
/// [PlaceTaskLineLayer] (which must be the FIRST child, so task pills win
/// any press over it) because a single Stack child can't be both bottom
/// for hit-testing and top for painting.
class PlaceTaskLineOverlay extends StatelessWidget {
  const PlaceTaskLineOverlay({
    super.key,
    required this.theme,
    required this.rangeStart,
    required this.pixelsPerMinute,
    required this.controller,
  });

  final AmbleTheme theme;
  final DateTime rangeStart;
  final double pixelsPerMinute;
  final PlaceTaskLineController controller;

  @override
  Widget build(BuildContext context) {
    // This whole subtree is ALWAYS a Positioned.fill, and _PlacementLine
    // is positioned inside a NEW, SEPARATE inner Stack rather than the
    // outer timeline Stack it used to share with PlaceTaskLineLayer —
    // fixed directly after a genuinely surprising discovery: a
    // non-positioned sibling (a bare SizedBox.shrink(), rendered while the
    // line is idle) in the SAME Stack as PlaceTaskLineLayer's own
    // Positioned.fill broke long-press recognition entirely. Confirmed by
    // isolated repro: a Positioned sibling was harmless, a bare
    // non-positioned one was not — a Stack containing a mix of positioned
    // and non-positioned children sizes itself against the non-positioned
    // ones (StackFit.loose), which apparently shifted the coordinate space
    // enough to move PlaceTaskLineLayer's actual hit-testable geometry out
    // from under where a press landed. Isolating this overlay inside its
    // own Positioned.fill + inner Stack means the outer timeline Stack
    // only ever sees ONE positioned child from this widget, regardless of
    // whether the line is currently showing.
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ValueListenableBuilder<double?>(
              valueListenable: controller,
              builder: (context, top, _) {
                if (top == null) return const SizedBox.shrink();
                final rawMinutes = top / pixelsPerMinute;
                final snapped =
                    (rawMinutes / _snapMinutes).round() * _snapMinutes;
                return _PlacementLine(
                  theme: theme,
                  top: top,
                  time: rangeStart.add(Duration(minutes: snapped)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The line itself — a full-width hairline with a time label on its
/// right edge, per direct request ("line shows with time on the right"),
/// matching [CurrentTimeIndicator]'s own shape but in the accent colour
/// rather than red — this is a task being PLACED, not the current time.
/// The actual hairline+pill visual now lives in [TaskEdgeTimeLabel],
/// promoted so it can be reused wherever else a task's own start/end
/// needs this same treatment (the pending draft pill, Edit Mode's
/// selected task) — this class only keeps this call site's own
/// positioning (a `FractionalTranslation` centering the line on its
/// dropped instant, unique to the placement-line use case).
class _PlacementLine extends StatelessWidget {
  const _PlacementLine({
    required this.theme,
    required this.top,
    required this.time,
  });

  final AmbleTheme theme;
  final double top;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        // pillAlignment: start — design-system consolidation, requested
        // directly ("should be consistent on left"): every other accent-bg
        // hour indicator in the app (task edit/resize, zone resize) is
        // left-aligned over the gutter; this was the one remaining
        // right-aligned case (an explicit earlier request, "time on the
        // right," now superseded). The full-width hairline (`showLine`,
        // unchanged) still needs the full `left: 0, right: 0` box to
        // stretch across — only the PILL's own end of the Row moves, via
        // TaskEdgeTimeLabel's new `pillAlignment` param, rather than
        // dropping `right:` the way the shrink-wrapped (showLine: false)
        // callers do. See docs/DESIGN_SYSTEM.md.
        child: TaskEdgeTimeLabel(
          theme: theme,
          time: TimeOfDay.fromDateTime(time),
          pillAlignment: TaskEdgeTimeLabelAlignment.start,
        ),
      ),
    );
  }
}
