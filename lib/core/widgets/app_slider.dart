import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// Adaptive slider, consuming only Tier 2 tokens. Custom-painted rather
/// than branching Cupertino/Material — the design calls for a thick,
/// full-width track with a thumb in the same active color as the filled
/// portion, which neither `Slider` nor `CupertinoSlider` can produce
/// natively (both reserve horizontal padding for the thumb, and
/// `CupertinoSlider`'s thumb color is fixed by the platform). Screens
/// should never reach for `Slider`/`CupertinoSlider` directly; this is the
/// only entry point, per docs/CONSTITUTION.md design principle 4.
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final trackHeight = theme.spacingSm;

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: trackHeight,
        activeTrackColor: theme.colorAccent,
        inactiveTrackColor: theme.colorSurfaceSecondary,
        thumbColor: theme.colorAccent,
        overlayColor: theme.colorAccent.withValues(alpha: 0.15),
        trackShape: const _FullWidthTrackShape(),
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: trackHeight * 1.4,
        ),
        tickMarkShape: SliderTickMarkShape.noTickMark,
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

/// A [SliderTrackShape] with zero horizontal inset, so the track spans the
/// slider's full available width instead of leaving room for the thumb's
/// default overlay padding on each side.
class _FullWidthTrackShape extends RoundedRectSliderTrackShape {
  const _FullWidthTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4.0;
    final trackWidth = parentBox.size.width;
    final trackTop = (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
      offset.dx,
      offset.dy + trackTop,
      trackWidth,
      trackHeight,
    );
  }
}
