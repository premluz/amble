import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_config.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/type_primitives.dart';
import '../../core/widgets/app_switch.dart';
import 'settings_panel.dart';

/// Settings → Developer → Motion: whether top-level pages slide (with
/// their items trailing) or crossfade, the default.
class DevPageMotionPanel extends ConsumerWidget {
  const DevPageMotionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Motion', style: theme.textTitle),
        SizedBox(height: theme.spacingSm),
        SettingsPanel(
          theme: theme,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Page slide motion',
                      style: theme.textBody.copyWith(
                        color: theme.colorTextPrimary,
                        fontWeight: TypePrimitives.weightSemibold,
                      ),
                    ),
                    SizedBox(height: theme.spacingXs),
                    Text(
                      'Pages slide sideways and their items trail one after '
                      'another. Off: pages simply fade.',
                      style: theme.textBody.copyWith(
                        color: theme.colorTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: theme.spacingMd),
              AppSwitch(
                value: ref.watch(devPageSlideMotionProvider),
                onChanged: ref.read(devPageSlideMotionProvider.notifier).set,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
