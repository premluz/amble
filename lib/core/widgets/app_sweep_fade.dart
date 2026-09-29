import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Fades its child as a front sweeps up the screen from the bottom edge:
/// at [sweep] 0 everything is visible; as it rises, items lower on screen
/// fade first and those higher up follow, so a list reads as swept away
/// from the bottom (voice mode's glow rising over the Inbox). Played in
/// reverse, items return top first. Each item uses its own position on
/// screen, so it needs no index and works inside any scrolling list.
class AppSweepFade extends SingleChildRenderObjectWidget {
  const AppSweepFade({super.key, required this.sweep, super.child});

  final Animation<double> sweep;

  /// Height of the fading edge, as a share of the screen: an item goes from
  /// visible to gone while the front crosses this band.
  static const band = .35;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderSweepFade(sweep, MediaQuery.sizeOf(context).height);

  @override
  void updateRenderObject(BuildContext context, RenderSweepFade renderObject) {
    renderObject
      ..sweep = sweep
      ..screenHeight = MediaQuery.sizeOf(context).height;
  }
}

/// The render object behind [AppSweepFade].
class RenderSweepFade extends RenderProxyBox {
  RenderSweepFade(this._sweep, this._screenHeight);

  Animation<double> _sweep;
  double _screenHeight;

  /// The opacity last painted (tests read it).
  @visibleForTesting
  double get debugOpacity => _lastOpacity;
  double _lastOpacity = 1;

  set sweep(Animation<double> value) {
    if (value == _sweep) return;
    if (attached) _sweep.removeListener(markNeedsPaint);
    _sweep = value;
    if (attached) _sweep.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set screenHeight(double value) {
    if (value == _screenHeight) return;
    _screenHeight = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _sweep.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _sweep.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  /// 1 = fully visible. The front travels from the bottom edge to past the
  /// top by one [AppSweepFade.band], so at 1 every item is gone.
  double _opacity() {
    final sweep = _sweep.value.clamp(0.0, 1.0);
    if (sweep == 0 || _screenHeight <= 0) return 1;
    const band = AppSweepFade.band;
    final centre = localToGlobal(size.center(Offset.zero)).dy;
    final fromBottom = 1 - (centre / _screenHeight).clamp(0.0, 1.0);
    final front = sweep * (1 + band);
    return (1 - (front - fromBottom) / band).clamp(0.0, 1.0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final opacity = _opacity();
    _lastOpacity = opacity;
    if (opacity == 0) {
      layer = null;
      return;
    }
    // Fully visible (always, at rest): no layer at all, so a page that never
    // sweeps pays nothing — not even an idle opacity layer per row.
    if (opacity == 1) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    layer = context.pushOpacity(
      offset,
      (opacity * 255).round(),
      super.paint,
      oldLayer: switch (layer) {
        final OpacityLayer previous => previous,
        _ => null,
      },
    );
  }
}
