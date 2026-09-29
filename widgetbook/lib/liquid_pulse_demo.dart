import 'package:amble/core/tokens/liquid_pulse_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_liquid_pulse.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

Widget liquidPulseSelectDemo(BuildContext context) =>
    _knobbed(context, LiquidPulseSpec.select);

Widget liquidPulseCompleteDemo(BuildContext context) =>
    _knobbed(context, LiquidPulseSpec.complete);

Widget _knobbed(BuildContext context, LiquidPulseSpec defaults) {
  double knob(String name, double value, double min, double max) =>
      context.knobs.double.slider(
        label: name,
        initialValue: value,
        min: min,
        max: max,
        precision: 2,
      );
  return _LiquidPulseDemo(
    spec: LiquidPulseSpec(
      depth: knob('Compress depth', defaults.depth, .01, .3),
      compressSeconds: knob('Compress (s)', defaults.compressSeconds, .03, .3),
      springSeconds: knob('Spring (s)', defaults.springSeconds, .15, 1.2),
      bounce: knob('Bounce', defaults.bounce, 0, .9),
      squash: knob('Liquid squash', defaults.squash, 0, 1),
    ),
  );
}

class _LiquidPulseDemo extends StatefulWidget {
  const _LiquidPulseDemo({required this.spec});

  final LiquidPulseSpec spec;

  @override
  State<_LiquidPulseDemo> createState() => _LiquidPulseDemoState();
}

class _LiquidPulseDemoState extends State<_LiquidPulseDemo> {
  var _active = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return ColoredBox(
      color: theme.colorSurfaceBase,
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() => _active = !_active),
          child: AppLiquidPulse(
            active: _active,
            spec: widget.spec,
            child: Container(
              width: theme.sizeTaskBadgeLg,
              height: theme.sizeTaskBadgeLg * 3,
              decoration: BoxDecoration(
                color: _active
                    ? theme.colorAccent
                    : theme.colorSurfaceSecondary,
                borderRadius: BorderRadius.circular(theme.radiusPill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
