import 'package:flutter/material.dart';

import '../tokens/floating_surface_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_dock_primitives.dart';
import 'app_liquid_slide.dart';
import 'app_option_switch_option.dart';
import 'app_press_feedback.dart';

/// [AppTabSwitch]'s options in the bottom toolbar's segmented style: the
/// dock's floating glass pane, the dock group's sliding highlight, the
/// selected label in accent like a selected dock icon. No tap ripple — the
/// moving highlight is the feedback, as in the dock. Fixed, equal-width
/// options only: no scrolling and no drop-target outline.
class AppFloatingTabSwitch<T> extends StatelessWidget {
  const AppFloatingTabSwitch({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<AppOptionSwitchOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    // The track's height, not the dock pane's (button + inset): the header
    // slot matches the main nav's height, so swapping them never jumps.
    return SizedBox(
      height: theme.sizeButtonMd,
      child: AppDockSurface(
        theme: theme,
        child: AppFloatingTabTrack<T>(
          options: options,
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// [AppFloatingTabSwitch] without its pane: the segments and the sliding
/// highlight, for a host that draws the pane itself (the shell header grows
/// it in with `AppPaneMorph`).
class AppFloatingTabTrack<T> extends StatelessWidget {
  const AppFloatingTabTrack({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<AppOptionSwitchOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Padding(
      padding: EdgeInsets.all(theme.spacingXs),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          // The liquid highlight stretches past the track as it slides; a
          // hard-edge clip here squared its ends. The pane's own rounded
          // clip is the only edge, as in the toolbar's dock.
          clipBehavior: Clip.none,
          children: [
            _highlight(theme, constraints.maxWidth, constraints.maxHeight),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in options)
                  Expanded(
                    child: _FloatingTabSegment(
                      key: option.segmentKey,
                      theme: theme,
                      label: option.label,
                      selected: option.value == value,
                      onTap: () => onChanged(option.value),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlight(AmbleTheme theme, double width, double height) {
    final index = options.indexWhere((option) => option.value == value);
    if (index < 0) return const SizedBox.shrink();
    final segment = width / options.length;
    return AppLiquidSlide(
      target: Rect.fromLTWH(segment * index, 0, segment, height),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FloatingSurfaceTokens.selected(theme),
          borderRadius: BorderRadius.circular(theme.radiusPillFull),
        ),
      ),
    );
  }
}

class _FloatingTabSegment extends StatelessWidget {
  const _FloatingTabSegment({
    super.key,
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AmbleTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppPressFeedback(
    onTap: onTap,
    ripple: false,
    borderRadius: BorderRadius.circular(theme.radiusPillFull),
    child: Center(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textBody.copyWith(
          color: selected ? theme.colorAccent : theme.colorTextSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
