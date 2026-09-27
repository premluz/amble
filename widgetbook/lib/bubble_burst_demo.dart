import 'package:amble/core/tokens/bubble_burst_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_bubble_burst.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

Widget bubbleBurstDemo(BuildContext context) {
  const defaults = BubbleBurstSpec();
  double knob(String name, double value, double max) => context.knobs.double
      .slider(label: name, initialValue: value, min: 0, max: max, precision: 2);
  return _BubbleDemo(
    spec: BubbleBurstSpec(
      bubbleEmission: knob(
        'bubbleEmission (seconds)',
        defaults.bubbleEmission,
        1,
      ),
      bubbleRate: context.knobs.double.slider(
        label: 'bubbleRate (/second)',
        initialValue: defaults.bubbleRate,
        min: 1,
        max: 12,
      ),
      bubbleStagger: knob(
        'bubbleStagger (seconds)',
        defaults.bubbleStagger,
        .2,
      ),
      bubbleLinger: context.knobs.double.slider(
        label: 'bubbleLinger (seconds)',
        initialValue: defaults.bubbleLinger,
        min: .2,
        max: 2,
      ),
      bubbleRandomness: knob('bubbleRandomness', defaults.bubbleRandomness, 1),
      bubbleTravel: knob(
        'bubbleTravel (pill widths)',
        defaults.bubbleTravel,
        4,
      ),
      bubbleSpread: knob(
        'bubbleSpread (pill widths)',
        defaults.bubbleSpread,
        2,
      ),
      frontDots: knob('frontDots (opacity)', defaults.frontDots, 1),
    ),
  );
}

class _BubbleDemo extends StatefulWidget {
  const _BubbleDemo({required this.spec});
  final BubbleBurstSpec spec;
  @override
  State<_BubbleDemo> createState() => _BubbleDemoState();
}

class _BubbleDemoState extends State<_BubbleDemo> {
  final _pillKey = GlobalKey();
  bool _completed = false;

  void _emit() {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    AppBubbleBurst.show(
      context: _pillKey.currentContext!,
      origin: Offset(theme.sizeTaskBadge / 2, 0),
      sourceWidth: theme.sizeTaskBadge,
      spec: widget.spec,
    );
  }

  void _toggle() {
    if (!_completed) _emit();
    setState(() => _completed = !_completed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return ColoredBox(
      color: theme.colorSurfacePrimary,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(theme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Swipe left to complete', style: theme.textTitle),
              SizedBox(height: theme.spacingXl * 3),
              AppSwipeActions(
                endAction: AppSwipeAction(
                  icon: Icons.check_rounded,
                  background: theme.colorAccent,
                  semanticLabel: _completed ? 'Mark undone' : 'Mark done',
                  onActivate: _toggle,
                ),
                child: _taskRow(theme),
              ),
              SizedBox(height: theme.spacingXl),
              AppButton(label: 'Replay bubbles', onPressed: _emit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskRow(AmbleTheme theme) => Row(
    children: [
      Container(
        key: _pillKey,
        width: theme.sizeTaskBadge,
        height: theme.spacingXl * 2,
        decoration: BoxDecoration(
          color: _completed ? theme.colorTextSecondary : theme.colorAccent,
          borderRadius: BorderRadius.circular(theme.radiusPill),
        ),
      ),
      SizedBox(width: theme.spacingMd),
      Text(
        'A moment of focus',
        style: theme.textBody.copyWith(
          color: theme.colorTextPrimary,
          decoration: _completed ? TextDecoration.lineThrough : null,
        ),
      ),
    ],
  );
}
