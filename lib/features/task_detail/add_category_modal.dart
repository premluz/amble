import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';
import '../../shared/models/category.dart';
import '../../shared/providers/category_providers.dart';

/// A small, curated emoji set for the new-category picker — hand-picked,
/// not an emoji-picker package, matching how the 5 built-in categories'
/// own emoji are each just a literal in `task_category_token_mapping.dart`.
/// Broad enough to cover common category themes without becoming its own
/// scrollable-forever wall.
const _curatedCategoryEmoji = [
  '⭐',
  '🎯',
  '📌',
  '📝',
  '📅',
  '💡',
  '🎨',
  '🎵',
  '🏋️',
  '🧘',
  '🍎',
  '☕',
  '🐾',
  '🌱',
  '🚗',
  '✈️',
  '🎓',
  '💰',
  '🛒',
  '🎮',
  '📚',
  '🧹',
  '🔧',
  '❤️',
];

/// "Add new category" — create-only (v1 scope: create + list, no edit/
/// delete, per docs/DECISIONS.md). Reachable via the "+ Add new" link on
/// both [TaskCategoryModal] and `TaskNameCategoryModal`'s title row.
///
/// Three sections (name / color / emoji), matching `task_detail_sheet.dart`'s
/// visual language — a bespoke header rather than promoting that file's
/// private `_StepScaffold`: this modal is a single flat form, not a
/// multi-step wizard, so reusing the step-flow chrome would pull in more
/// than this needs and risk the 2900+-line file's existing callers for no
/// benefit. Save is disabled until name/color/emoji are all set; on save,
/// resolves to the newly created [Category] so the calling picker sheet
/// can select it immediately, matching [TaskCategoryModal.show]'s own
/// resolves-to-a-selection contract.
class AddCategoryModal extends ConsumerStatefulWidget {
  const AddCategoryModal({super.key});

  static Future<Category?> show({required BuildContext context}) {
    return AppSheet.show<Category>(
      context: context,
      builder: (context) => const AddCategoryModal(),
    );
  }

  @override
  ConsumerState<AddCategoryModal> createState() => _AddCategoryModalState();
}

class _AddCategoryModalState extends ConsumerState<AddCategoryModal> {
  final _nameController = TextEditingController();
  int? _colorToken;
  String? _emoji;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Save's enabled state depends on the name being non-empty, so it has
    // to react on every keystroke — AppTextField's own onFocusChanged only
    // fires on focus change, not per-character, so this listens to the
    // controller directly instead (the same "controller is the single
    // source of truth" contract AppTextField itself uses internally).
    _nameController.addListener(_handleNameChanged);
  }

  void _handleNameChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _colorToken != null &&
      _emoji != null &&
      !_isSaving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final created = await ref
          .read(categoryListProvider.notifier)
          .createCategory(
            name: _nameController.text.trim(),
            colorToken: _colorToken!,
            emoji: _emoji!,
          );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New category',
            textAlign: TextAlign.center,
            style: theme.textTitle.copyWith(
              color: theme.colorTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacingLg),
          AppPane(
            title: 'Name',
            child: AppTextField(
              controller: _nameController,
              label: 'Category name',
              autofocus: true,
            ),
          ),
          SizedBox(height: theme.spacingLg),
          AppPane(
            title: 'Color',
            child: Wrap(
              spacing: theme.spacingSm,
              runSpacing: theme.spacingSm,
              children: [
                for (
                  var index = 0;
                  index < theme.categorySwatches.length;
                  index++
                )
                  _ColorSwatch(
                    color: theme.categorySwatches[index],
                    selected: _colorToken == index,
                    onSelected: () => setState(() => _colorToken = index),
                  ),
              ],
            ),
          ),
          SizedBox(height: theme.spacingLg),
          AppPane(
            title: 'Emoji',
            child: Wrap(
              spacing: theme.spacingSm,
              runSpacing: theme.spacingSm,
              children: [
                for (final emoji in _curatedCategoryEmoji)
                  _EmojiOption(
                    emoji: emoji,
                    selected: _emoji == emoji,
                    onSelected: () => setState(() => _emoji = emoji),
                  ),
              ],
            ),
          ),
          SizedBox(height: theme.spacingLg),
          AppButton(
            label: 'Save',
            size: AppButtonSize.large,
            shape: AppButtonShape.pill,
            isLoading: _isSaving,
            onPressed: _canSave ? _save : null,
          ),
        ],
      ),
    );
  }
}

/// One rounded color square in the 12-swatch palette grid — selection is a
/// border ring, matching the existing category chips' selected-state
/// affordance (`_CategoryChip` in `task_category_modal.dart`).
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final Color color;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: theme.motionFast,
        curve: theme.curveStandard,
        width: theme.spacingXl,
        height: theme.spacingXl,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          border: Border.all(
            color: selected ? theme.colorTextPrimary : Colors.transparent,
            width: theme.borderWidthHairline * 1.5,
          ),
        ),
      ),
    );
  }
}

/// One emoji option in the curated grid — selection is a border ring,
/// same affordance as [_ColorSwatch].
class _EmojiOption extends StatelessWidget {
  const _EmojiOption({
    required this.emoji,
    required this.selected,
    required this.onSelected,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: theme.motionFast,
        curve: theme.curveStandard,
        width: theme.spacingXl,
        height: theme.spacingXl,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          border: Border.all(
            color: selected ? theme.colorTextPrimary : Colors.transparent,
            width: theme.borderWidthHairline * 1.5,
          ),
        ),
        child: Text(emoji, style: theme.textBody),
      ),
    );
  }
}
