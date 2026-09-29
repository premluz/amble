import 'package:amble/core/tokens/delete_puff_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_delete_puff.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

Widget deletePuffDemo(BuildContext context) {
  final defaults = const DeletePuffSpec();
  double knob(
    String name,
    double value,
    double min,
    double max, {
    int precision = 2,
  }) => context.knobs.double.slider(
    label: name,
    initialValue: value,
    min: min,
    max: max,
    precision: precision,
  );
  final spec = DeletePuffSpec(
    durationSeconds: knob(
      'Duration (seconds)',
      defaults.durationSeconds,
      .4,
      3,
    ),
    count: knob(
      'Cloud clusters',
      defaults.count.toDouble(),
      6,
      24,
      precision: 0,
    ).round(),
    spread: knob('Outward spread', defaults.spread, 20, 160),
    lift: knob('Upward drift', defaults.lift, 0, 100),
    size: knob('Cloud size', defaults.size, 10, 40),
    curl: knob('Sideways curl', defaults.curl, 0, 80),
    stagger: knob('Emission stagger', defaults.stagger, 0, .3),
    fadeStart: knob('Fade begins', defaults.fadeStart, .15, .75),
    scale: knob('Effect size', defaults.scale, .4, 2),
    seed: knob(
      'Variation seed',
      defaults.seed.toDouble(),
      1,
      100,
      precision: 0,
    ).round(),
  );
  return _DeletePuffDemo(spec: spec);
}

class _DeletePuffDemo extends StatelessWidget {
  const _DeletePuffDemo({required this.spec});

  final DeletePuffSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return ColoredBox(
      color: theme.colorSurfacePrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Selected-item delete', style: theme.textTitle),
            SizedBox(height: theme.spacingXl),
            Builder(
              builder: (buttonContext) => AppButton(
                icon: Icons.delete_outline_rounded,
                shape: AppButtonShape.circle,
                variant: AppButtonVariant.ghost,
                tooltip: 'Remove selected',
                onPressed: () =>
                    AppDeletePuff.show(context: buttonContext, spec: spec),
              ),
            ),
            SizedBox(height: theme.spacingMd),
            Text('Tap the bin to replay the puff', style: theme.textCaption),
          ],
        ),
      ),
    );
  }
}
