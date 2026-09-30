import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The space an `AppSheet` keeps at its bottom — the device's bottom safe
/// area plus the sheet's clearance. It sits INSIDE the sheet's scroll, under
/// the bottom fade, so content scrolls right to the phone's edge.
class AppSheetBottomInset extends InheritedWidget {
  const AppSheetBottomInset({
    super.key,
    required this.value,
    required super.child,
  });

  final double value;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppSheetBottomInset>()
          ?.value ??
      0;

  @override
  bool updateShouldNotify(AppSheetBottomInset oldWidget) =>
      value != oldWidget.value;
}

/// A page's body that may be longer than its sheet allows (an icon grid):
/// it takes the room left under the header and scrolls there, so the
/// header's ‹ stays put. It also runs on through the sheet's bottom space
/// ([AppSheetBottomInset]) to the phone's edge, under the bottom fade,
/// instead of stopping short of it. Use as a direct child of the page's
/// `Column`.
class AppSheetScrollBody extends StatelessWidget {
  const AppSheetScrollBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = AppSheetBottomInset.of(context);
    return Flexible(
      child: _BleedDown(
        extent: inset,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: inset),
          child: child,
        ),
      ),
    );
  }
}

/// Lays [child] out up to [extent] taller than the room it is given and
/// reports itself [extent] shorter than the child, so the child's last
/// [extent] (the scroll's bottom padding when it fits, its lower viewport
/// when it scrolls) paints over the space below — the sheet's bottom inset.
class _BleedDown extends SingleChildRenderObjectWidget {
  const _BleedDown({required this.extent, required super.child});

  final double extent;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBleedDown(extent);

  @override
  void updateRenderObject(BuildContext context, _RenderBleedDown renderObject) {
    renderObject.extent = extent;
  }
}

class _RenderBleedDown extends RenderShiftedBox {
  _RenderBleedDown(this._extent) : super(null);

  double _extent;
  set extent(double value) {
    if (_extent == value) return;
    _extent = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final grown = constraints.hasBoundedHeight
        ? constraints.copyWith(maxHeight: constraints.maxHeight + _extent)
        : constraints;
    child.layout(grown, parentUsesSize: true);
    size = constraints.constrain(
      Size(child.size.width, math.max(0, child.size.height - _extent)),
    );
  }
}
