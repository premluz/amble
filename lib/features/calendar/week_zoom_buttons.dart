import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../shared/providers/week_hour_height_setting.dart';

/// The toolbar's − / + for the week's zoom, for people without a trackpad
/// or who don't know the Cmd+scroll shortcut. Each disables at its limit.
class WeekZoomButtons extends ConsumerWidget {
  const WeekZoomButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = ref.watch(weekHourHeightSettingProvider);
    final zoom = ref.read(weekHourHeightSettingProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          icon: Icons.remove_rounded,
          semanticLabel: 'Zoom out',
          variant: AppButtonVariant.ghost,
          shape: AppButtonShape.circle,
          onPressed: height > WeekHourHeightSetting.min
              ? () => zoom.zoomBy(1 / CalendarGridTokens.weekZoomStep)
              : null,
        ),
        AppButton(
          icon: Icons.add_rounded,
          semanticLabel: 'Zoom in',
          variant: AppButtonVariant.ghost,
          shape: AppButtonShape.circle,
          onPressed: height < WeekHourHeightSetting.max
              ? () => zoom.zoomBy(CalendarGridTokens.weekZoomStep)
              : null,
        ),
      ],
    );
  }
}
