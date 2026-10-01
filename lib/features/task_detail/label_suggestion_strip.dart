import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_badge_chip.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip_strip.dart';
import '../../core/widgets/app_value_chip.dart' show AppValueChipSize;
import '../../shared/models/category.dart';
import '../../shared/providers/category_providers.dart';
import 'category_visual.dart';
import '../../shared/models/label_presets.dart';

/// One scrollable row of [labelPresets] under the New label name field.
/// Tapping one fills in its name, colour and icon; nothing is saved until
/// the label itself is.
class LabelSuggestionStrip extends ConsumerWidget {
  const LabelSuggestionStrip({
    super.key,
    required this.theme,
    required this.query,
    required this.onPicked,
  });

  final AmbleTheme theme;
  final String query;
  final ValueChanged<LabelPreset> onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = labelSuggestions(
      existingNames: ref.watch(categoryListProvider).map((c) => c.name),
      query: query,
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: theme.spacingSm),
      child: AppChipStrip<LabelPreset>(
        items: suggestions,
        height: appButtonHeightFor(theme, AppButtonSize.sm),
        itemSpacing: theme.spacingXs,
        edgeInset: 0,
        keyOf: (preset) => ValueKey(preset.name),
        itemBuilder: (context, preset) => AppBadgeChip(
          theme: theme,
          size: AppValueChipSize.sm,
          label: preset.name,
          onTap: () => onPicked(preset),
          leading: CategoryBadge(
            theme: theme,
            category: _preview(preset),
            size: ChipTokens.compactBadgeSize(theme),
            glyphSizeRatio: ChipTokens.compactBadgeGlyphRatio,
          ),
        ),
      ),
    );
  }
}

/// A never-saved stand-in so the chip draws the same badge a saved label
/// would.
Category _preview(LabelPreset preset) => Category(
  id: 'preset:${preset.name}',
  name: preset.name,
  colorToken: preset.colorToken,
  emoji: '',
  iconCodePoint: preset.icon.codePoint,
);
