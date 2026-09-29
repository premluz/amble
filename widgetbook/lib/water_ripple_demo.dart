import 'package:amble/core/tokens/liquid_pulse_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/water_ripple_spec.dart';
import 'package:amble/core/widgets/app_liquid_pulse.dart';
import 'package:amble/core/widgets/app_water_ripple.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

Widget waterRippleDemo(BuildContext context) {
  const defaults = WaterRippleSpec();
  double knob(String name, double value, double min, double max) =>
      context.knobs.double.slider(
        label: name,
        initialValue: value,
        min: min,
        max: max,
        precision: 2,
      );
  return _WaterRippleDemo(
    spec: WaterRippleSpec(
      rings: knob('Rings', defaults.rings.toDouble(), 1, 4).round(),
      ringSeconds: knob('Ring life (s)', defaults.ringSeconds, .3, 2),
      ringDelaySeconds: knob(
        'Ring delay (s)',
        defaults.ringDelaySeconds,
        0,
        .5,
      ),
      spread: knob('Spread (px)', defaults.spread, 6, 60),
      strokeWidth: knob('Stroke', defaults.strokeWidth, .5, 3),
      peakOpacity: knob('Peak opacity', defaults.peakOpacity, .05, .6),
    ),
  );
}

/// Tap the pill to complete it: the completion pulse and the ripple play
/// together, as they do on a swipe-to-done.
class _WaterRippleDemo extends StatefulWidget {
  const _WaterRippleDemo({required this.spec});

  final WaterRippleSpec spec;

  @override
  State<_WaterRippleDemo> createState() => _WaterRippleDemoState();
}

class _WaterRippleDemoState extends State<_WaterRippleDemo> {
  var _completed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final width = theme.sizeTaskBadgeLg;
    final height = width * 3;
    return ColoredBox(
      color: theme.colorSurfaceBase,
      child: Center(
        child: Builder(
          builder: (pillContext) => GestureDetector(
            onTap: () {
              if (!_completed) {
                AppWaterRipple.show(
                  context: pillContext,
                  rect: Offset.zero & Size(width, height),
                  radius: theme.radiusPill,
                  spec: widget.spec,
                );
              }
              setState(() => _completed = !_completed);
            },
            child: AppLiquidPulse(
              active: _completed,
              spec: LiquidPulseSpec.complete,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: _completed
                      ? theme.colorTextSecondary
                      : theme.colorAccent,
                  borderRadius: BorderRadius.circular(theme.radiusPill),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
