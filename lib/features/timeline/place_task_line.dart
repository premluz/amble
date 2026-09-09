import 'package:flutter/gestures.dart' show kLongPressTimeout, kTouchSlop;
import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_press_feedback.dart';

/// Snap granularity for the placement line's dropped time — matches the
/// task-drag reschedule's own snap (see `timeline_screen.dart`'s
/// `_snapMinutes`), so a task created here and one dragged there land on
/// the same rhythm of times.
const _snapMinutes = 5;

/// Layer that turns a long-press-and-drag anywhere on the timeline's empty
/// background into "place a new task starting here." Requested directly:
/// "press and hold any where but not the pill... after short hold line
/// shows with time on the right... user could move it up and down...
/// hold itself for a moment line shown when shown is drag a line mode...
/// on release... create task flow is opened with start time as the line
/// was dropped."
///
/// Built on [LongPressDraggable] rather than a hand-rolled
/// `RawGestureDetector`/`LongPressGestureRecognizer` — the earlier
/// hand-rolled version never reliably worked once a `SingleChildScrollView`
/// ancestor was in the picture (wrong drop position, no drag tracking at
/// all on a real device). `LongPressDraggable` is Flutter's own
/// purpose-built widget for exactly this interaction — the same mechanism
/// `ReorderableListView` itself uses internally — and reliably survives a
/// scrollable ancestor, which is the whole reason it exists.
///
/// The VISIBLE line/label is deliberately NOT `LongPressDraggable`'s own
/// `feedback` (which the framework positions via the app-wide `Overlay`,
/// a different coordinate space entirely, and can't reliably line up with
/// the underlying timeline's own hour axis). `feedback` here is invisible
/// and exists only to drive `onDragUpdate`'s stream of `globalPosition`s;
/// the real visual is drawn by [PlaceTaskLineOverlay] in the timeline's
/// own coordinate space — matching [CurrentTimeIndicator]'s own line+label
/// shape and hairline weight, just accent-coloured instead of red, per
/// direct request.
///
/// This widget MUST be the FIRST child in the timeline's Stack — a `Stack`
/// hit-tests from last child to first, so every task pill and free-window
/// block (added later in that list) gets first refusal at any pointer down
/// before it reaches this background layer. Combined with those widgets'
/// own `HitTestBehavior.opaque`, a press that starts on a pill or a
/// free-window block never reaches here at all — exactly "not on the
/// pill." [PlaceTaskLineOverlay] correspondingly must be the LAST child,
/// so the line paints above everything; the two communicate through a
/// shared [PlaceTaskLineController].
/// The line's live position while a placement drag is in progress, in the
/// day column's own local Y — null whenever nothing is being placed.
///
/// Exists because the press surface and the visible line have opposite
/// stacking requirements: the surface must be the timeline Stack's FIRST
/// child (hit-tested last, so task pills win any press over it), while the
/// line must paint ABOVE everything (requested directly — it was rendering
/// underneath tasks). A Stack can't give one widget both, so the two are
/// separate children sharing this notifier rather than duplicated state.
typedef PlaceTaskLineController = ValueNotifier<double?>;

class PlaceTaskLineLayer extends StatefulWidget {
  const PlaceTaskLineLayer({
    super.key,
    required this.theme,
    required this.rangeStart,
    required this.rangeEnd,
    required this.pixelsPerMinute,
    required this.controller,
    required this.onPlaced,
    this.onTapAt,
  });

  final AmbleTheme theme;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final double pixelsPerMinute;

  /// Publishes the line's position to [PlaceTaskLineOverlay], which the
  /// caller renders as the LAST child of the same Stack.
  final PlaceTaskLineController controller;

  /// Fired on release with the dropped instant, already snapped to
  /// [_snapMinutes] and clamped inside [rangeStart]/[rangeEnd].
  final ValueChanged<DateTime> onPlaced;

  /// Fired on a plain TAP (not a hold-and-drag) on empty Timeline
  /// background — requested directly: "tap on an empty space in timeline
  /// view... puts a wiggly gray default task and opens a small sheet."
  /// A quick tap and a long-press-drag resolve independently in Flutter's
  /// gesture arena (this widget's own `GestureDetector.onTapUp` alongside
  /// [LongPressDraggable]'s recognizer below), so both interactions coexist
  /// without custom arbitration. Optional — null leaves plain taps
  /// unhandled, same as before this parameter existed.
  final ValueChanged<DateTime>? onTapAt;

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

  /// The line's current position, in this layer's own local Y (the same
  /// coordinate space every other Positioned child of the timeline's
  /// Stack uses) — null while no drag is active. Mirrored onto
  /// [PlaceTaskLineLayer.controller] so the separately-stacked overlay can
  /// render it; kept here too so the drop handler can read it without
  /// reaching back through the notifier.
  double? get _lineTop => widget.controller.value;
  set _lineTop(double? value) => widget.controller.value = value;

  /// The most recent raw pointer position, tracked independently of the
  /// drag's own gesture-arena participation via a `Listener` (see build())
  /// — `Draggable`'s own `onDragUpdate` only fires once the pointer has
  /// actually MOVED past its start (see `_DragAvatar.update`'s
  /// `_position != oldPosition` guard), so a hold that's released
  /// perfectly still would never fire it at all and the line would never
  /// appear. `onDragStarted` (fired the instant the hold completes) has
  /// no position of its own — this field is what supplies one.
  Offset? _lastPointerPosition;

  /// When the current pointer went down, and where — used by
  /// [_handlePointerUp] to tell a quick tap from a hold or a drag.
  DateTime? _pointerDownAt;
  Offset? _pointerDownPosition;

  /// Set once [LongPressDraggable] actually begins a drag, so the release
  /// at the end of that drag is never also treated as a tap.
  bool _dragStarted = false;

  /// Fires [PlaceTaskLineLayer.onTapAt] straight from the raw pointer
  /// stream, rather than through a `GestureDetector.onTapUp`.
  ///
  /// Reported directly: "the quick task add tap on the timeline is not
  /// responsive. It opens after a few moments." A tap recognizer here
  /// shares the gesture arena with [LongPressDraggable]'s own recognizer,
  /// and `onTapUp` only fires once that arena resolves — so every tap
  /// waited out the long-press contest before anything happened. A
  /// [Listener] sits outside the arena entirely, so this fires on the
  /// actual finger-lift.
  ///
  /// Guards reproduce what the tap recognizer was doing for us: ignore a
  /// release that ended a drag, one that lingered past the long-press
  /// threshold, and one that moved far enough to read as a scroll.
  void _handlePointerUp(PointerUpEvent event) {
    final downAt = _pointerDownAt;
    final downPosition = _pointerDownPosition;
    _pointerDownAt = null;
    _pointerDownPosition = null;

    final onTapAt = widget.onTapAt;
    if (onTapAt == null || downAt == null || downPosition == null) return;
    if (_dragStarted) return;
    if (DateTime.now().difference(downAt) > kLongPressTimeout) return;
    if ((event.position - downPosition).distance > kTouchSlop) return;

    final y = _localY(event.position);
    if (y == null) return;
    onTapAt(_instantAt(y.clamp(0.0, _maxTop)));
  }

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

  void _updateFromGlobal(Offset globalPosition) {
    final y = _localY(globalPosition);
    if (y == null) return;
    // No setState: this widget renders nothing that depends on the value.
    // The notifier is what rebuilds the overlay that actually draws it.
    _lineTop = y.clamp(0.0, _maxTop);
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
        onPointerDown: (event) {
          _lastPointerPosition = event.position;
          _pointerDownAt = DateTime.now();
          _pointerDownPosition = event.position;
          _dragStarted = false;
        },
        onPointerMove: (event) => _lastPointerPosition = event.position,
        onPointerUp: _handlePointerUp,
        onPointerCancel: (_) => _pointerDownAt = null,
        // The anchor key sits on a real RenderBox (this SizedBox), never
        // on a `Positioned`/`Listener` — `Positioned` is a
        // ParentDataWidget with no box of its own, so `findRenderObject()`
        // through it resolves to whatever descendant comes first, exactly
        // the ambiguity that can silently yield a consistently-wrong
        // offset. This box fills the day column, so its local space is the
        // same one PlaceTaskLineOverlay positions the line in.
        child: SizedBox.expand(
          key: _anchorKey,
          // decorationOnly: this layer's own GestureDetector below (and
          // LongPressDraggable beside it) must keep owning the gesture
          // arena exactly as documented there — AppPressFeedback here
          // only OBSERVES pointers to paint the wash, so neither the tap
          // nor the hold-to-drag interaction changes at all.
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
            onTap: widget.onTapAt == null ? null : () {},
            child: LongPressDraggable<Object>(
              // OPAQUE, not the default deferToChild — fixed directly after
              // this stopped firing entirely: `deferToChild` hit-tests
              // against the child's own painted content, and the child
              // here paints nothing, so there was literally nothing to hit
              // and the pointer passed straight through without the
              // recognizer ever seeing it. Opaque makes this layer claim
              // its whole area regardless of what its child paints.
              hitTestBehavior: HitTestBehavior.opaque,
              // Invisible: the real line is drawn by PlaceTaskLineOverlay,
              // in the timeline's own coordinate space, rather than the
              // app-wide Overlay this feedback would otherwise float in.
              feedback: const SizedBox.shrink(),
              onDragStarted: () {
                _dragStarted = true;
                final position = _lastPointerPosition;
                if (position != null) _updateFromGlobal(position);
              },
              onDragUpdate: (details) =>
                  _updateFromGlobal(details.globalPosition),
              onDragEnd: (details) {
                final top = _lineTop;
                _lineTop = null;
                if (top != null) widget.onPlaced(_instantAt(top));
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
        child: IgnorePointer(
          // Purely visual — every pointer event on this row still needs
          // to reach the LongPressDraggable underneath it (the same one
          // that's driving this line's own position), not get eaten by
          // the label/line themselves.
          child: Row(
            children: [
              Expanded(
                child: Container(
                  // Same hairline weight CurrentTimeIndicator's own line
                  // uses — requested directly. The two lines mean
                  // different things (now vs. a task being placed) and
                  // differ only in colour, so any weight difference would
                  // read as unintentional.
                  height: theme.borderWidthHairline,
                  color: theme.colorAccent,
                ),
              ),
              SizedBox(width: theme.spacingSm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacingSm,
                  vertical: theme.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: theme.colorAccent,
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Text(
                  TimeOfDay.fromDateTime(time).format(context),
                  style: theme.textCaption.copyWith(
                    color: theme.colorSurfacePrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
