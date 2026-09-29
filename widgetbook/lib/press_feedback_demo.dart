import 'package:amble/core/tokens/liquid_press_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_press_feedback.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

/// The shared press on the app's four tappable shapes. Every real control
/// (AppButton, chips, rows, icon buttons) uses [LiquidPressSpec.standard];
/// press and HOLD to see the swell, release for the fluid return. The knobs
/// tune the one shared spec before it is committed.
Widget pressFeedbackDemo(BuildContext context) {
  const defaults = LiquidPressSpec.standard;
  double knob(String name, double value, double min, double max) =>
      context.knobs.double.slider(
        label: name,
        initialValue: value,
        min: min,
        max: max,
        precision: 3,
      );
  final spec = LiquidPressSpec(
    growPx: knob('Grow (px, longest side)', defaults.growPx, 0, 24),
    minGrow: knob('Min grow', defaults.minGrow, 0, .05),
    maxGrow: knob('Max grow', defaults.maxGrow, .05, .4),
    growSeconds: knob('Grow (s)', defaults.growSeconds, .04, .4),
    releaseSeconds: knob('Release spring (s)', defaults.releaseSeconds, .15, 1),
    releaseBounce: knob('Release bounce', defaults.releaseBounce, 0, .9),
    squash: knob('Liquid squash', defaults.squash, 0, 1),
    holdFillAlpha: knob('Hold glass fill', defaults.holdFillAlpha, 0, .3),
  );
  return _PressFeedbackDemo(spec: spec);
}

class _PressFeedbackDemo extends StatelessWidget {
  const _PressFeedbackDemo({required this.spec});

  final LiquidPressSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    Widget surface({
      required double width,
      required double height,
      required BorderRadius radius,
      required Color color,
      Widget? child,
    }) => AppPressFeedback(
      onTap: () {},
      spec: spec,
      borderRadius: radius,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          boxShadow: theme.shadowPane,
        ),
        child: child,
      ),
    );

    final circle = theme.sizeTaskBadgeLg * 2;
    return ColoredBox(
      color: theme.colorSurfaceBase,
      child: Center(
        child: Wrap(
          spacing: theme.spacingLg,
          runSpacing: theme.spacingLg,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            surface(
              width: circle * 3,
              height: circle,
              radius: BorderRadius.circular(circle / 2),
              color: theme.colorAccent,
              child: Text(
                'Button',
                style: theme.textBody.copyWith(
                  color: theme.colorSurfacePrimary,
                ),
              ),
            ),
            surface(
              width: circle * 1.8,
              height: circle * .7,
              radius: BorderRadius.circular(theme.radiusMd),
              color: theme.colorSurfaceSecondary,
              child: Text('Chip', style: theme.textBody),
            ),
            surface(
              width: circle * 5,
              height: circle * 1.1,
              radius: BorderRadius.circular(theme.radiusXl),
              color: theme.colorSurfacePrimary,
              child: Text('Row / card', style: theme.textBody),
            ),
            AppPressFeedback(
              onTap: () {},
              spec: spec,
              shape: BoxShape.circle,
              child: Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  color: theme.colorSurfacePrimary,
                  shape: BoxShape.circle,
                  boxShadow: theme.shadowPane,
                ),
                child: Icon(Icons.add_rounded, color: theme.colorTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
