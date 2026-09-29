import 'package:amble/core/tokens/liquid_morph_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_context_menu.dart';
import 'package:amble/core/widgets/app_liquid_morph.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

/// Tap anywhere: a panel grows from that point with the knobbed spec.
Widget liquidMorphDemo(BuildContext context) {
  const defaults = LiquidMorphSpec.popover;
  double knob(String name, double value, double min, double max) =>
      context.knobs.double.slider(
        label: name,
        initialValue: value,
        min: min,
        max: max,
        precision: 2,
      );
  final droplet = knob(
    'Droplet (px, 0 = child width)',
    defaults.dropletDiameter ?? 0,
    0,
    80,
  );
  return _LiquidMorphDemo(
    spec: LiquidMorphSpec(
      dropletDiameter: droplet == 0 ? null : droplet,
      widthSeconds: knob('Width spring (s)', defaults.widthSeconds, .1, 1),
      widthBounce: knob('Width bounce', defaults.widthBounce, 0, .8),
      heightSeconds: knob('Height spring (s)', defaults.heightSeconds, .1, 1),
      heightBounce: knob('Height bounce', defaults.heightBounce, 0, .8),
      contentScaleFrom: knob(
        'Content scale from',
        defaults.contentScaleFrom,
        .2,
        1,
      ),
      fadeInFraction: knob('Fade-in share', defaults.fadeInFraction, .05, 1),
    ),
  );
}

class _LiquidMorphDemo extends StatefulWidget {
  const _LiquidMorphDemo({required this.spec});

  final LiquidMorphSpec spec;

  @override
  State<_LiquidMorphDemo> createState() => _LiquidMorphDemoState();
}

class _LiquidMorphDemoState extends State<_LiquidMorphDemo> {
  Offset? _tap;
  var _generation = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final panelWidth = theme.spacingXl * 8;
    final panelHeight = theme.spacingXl * 5;
    final tap = _tap;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => setState(() {
        _tap = details.localPosition;
        _generation++;
      }),
      child: ColoredBox(
        color: theme.colorSurfaceBase,
        child: Stack(
          children: [
            Center(child: Text('Tap anywhere', style: theme.textBody)),
            if (tap != null)
              Positioned(
                left: tap.dx - panelWidth / 2,
                top: tap.dy + theme.spacingSm,
                width: panelWidth,
                height: panelHeight,
                child: AppLiquidMorph(
                  key: ValueKey(_generation),
                  origin: Offset(panelWidth / 2, -theme.spacingSm),
                  borderRadius: theme.radiusModal,
                  spec: widget.spec,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorSurfacePrimary,
                      borderRadius: BorderRadius.circular(theme.radiusModal),
                      boxShadow: theme.shadowPane,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The real press-drag-release menu, which enters with the liquid morph.
Widget longPressContextMenuDemo(BuildContext context) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  return ColoredBox(
    color: theme.colorSurfaceBase,
    child: Center(
      child: AppLongPressContextMenu(
        actions: [
          AppContextMenuAction(
            icon: Icons.edit_outlined,
            label: 'Rename',
            onTap: () {},
          ),
          AppContextMenuAction(
            icon: Icons.delete_outline,
            label: 'Remove',
            isDestructive: true,
            onTap: () {},
          ),
        ],
        child: Container(
          padding: EdgeInsets.all(theme.spacingMd),
          decoration: BoxDecoration(
            color: theme.colorSurfacePrimary,
            borderRadius: BorderRadius.circular(theme.radiusXl),
          ),
          child: Text('Long-press me, then drag', style: theme.textBody),
        ),
      ),
    ),
  );
}
