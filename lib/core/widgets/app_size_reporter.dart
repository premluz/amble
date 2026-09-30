import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Reports [child]'s laid-out size whenever it changes, after the frame —
/// for a parent that sizes itself from its content's natural size (the
/// quick-create sheet hugging its fields) where intrinsics can't be asked
/// (a horizontal list inside).
class AppSizeReporter extends SingleChildRenderObjectWidget {
  const AppSizeReporter({
    super.key,
    required this.onSize,
    required super.child,
  });

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAppSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderAppSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class RenderAppSizeReporter extends RenderProxyBox {
  RenderAppSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final size = this.size;
    if (size == _reported) return;
    _reported = size;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(size);
    });
  }
}
