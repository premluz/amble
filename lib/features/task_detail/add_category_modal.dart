import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_flow.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_value_chip.dart';
import '../../shared/models/category.dart';
import '../../shared/providers/category_providers.dart';
import 'category_color_modal.dart';
import 'category_icon_modal.dart';
import 'category_visual.dart';

/// Opens the label create/edit sheet on its own (Settings' label list,
/// `TaskNameCategoryModal`) and resolves to the saved [Category]. Inside a
/// label picker the same form is a page of the picker's sheet instead —
/// see [AddCategoryPage].
///
/// [category] non-null opens in EDIT mode — rename + recolor + re-icon an
/// existing category, per CONSTITUTION.md's "v2" section (reorder itself
/// confirmed out of scope for now).
Future<Category?> showAddCategoryModal(
  BuildContext context, {
  Category? category,
}) {
  return AppSheet.show<Category?>(
    context: context,
    size: AppSheetSize.small,
    builder: (context) => AppSheetFlow(
      theme: Theme.of(context).extension<AmbleTheme>()!,
      root: AddCategoryPage(category: category),
    ),
  );
}

/// The label form, as a page of an [AppSheetFlow]: its Color and Icon chips
/// open their pickers as further pages of the same sheet.
class AddCategoryPage extends ConsumerStatefulWidget {
  const AddCategoryPage({super.key, this.category, this.onSaved});

  /// Non-null for edit mode — see [showAddCategoryModal]'s own doc
  /// comment.
  final Category? category;

  /// Where the saved label goes. Null closes the sheet with it (the label's
  /// own sheet); a picker passes its own, to select it and close.
  final ValueChanged<Category>? onSaved;

  @override
  ConsumerState<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends ConsumerState<AddCategoryPage> {
  final _nameController = TextEditingController();
  int? _colorToken;

  /// The picked Tabler glyph's `IconData.codePoint` — see
  /// [Category.iconCodePoint]. Replaces the old `_emoji` field; the
  /// underlying [Category.emoji] itself is left untouched on save
  /// (superseded, not repurposed — see that field's own doc comment).
  int? _iconCodePoint;
  bool _isSaving = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    if (category != null) {
      _nameController.text = category.name;
      _colorToken = category.colorToken;
      // Falls back to the curated set's first icon when editing a category
      // that predates this field (still only carrying a legacy emoji) —
      // `_canSave` requires a real selection, so this pre-selects one
      // rather than leaving Save permanently disabled for that row.
      _iconCodePoint =
          category.iconCodePoint ?? curatedCategoryIcons.first.codePoint;
    }
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
      _iconCodePoint != null &&
      !_isSaving;

  /// Removes the category being edited — requested directly: "Edit
  /// category also [remove icon button]." Never offered for a built-in
  /// category (see [_canDelete] and `CategoryList.deleteCategory`'s own
  /// "built-in can never be deleted" floor). No confirmation dialog,
  /// matching the task/zone/template edit flows' identical delete
  /// buttons — reassignment of any task currently using this category
  /// happens inside the notifier, not here.
  Future<void> _delete() async {
    final category = widget.category;
    if (category == null || category.isBuiltIn) return;

    final navigator = Navigator.of(context);
    final notifier = ref.read(categoryListProvider.notifier);
    navigator.pop();
    await notifier.deleteCategory(category.id);
  }

  bool get _canDelete => _isEditing && widget.category!.isBuiltIn == false;

  void _openColorPage() {
    final flow = AppSheetFlow.of(context);
    flow.push(
      CategoryColorPage(
        selectedColorToken: _colorToken,
        onSelected: (colorToken) {
          setState(() => _colorToken = colorToken);
          flow.pop();
        },
      ),
      // Keeps the label form's size instead of dropping to fit the
      // swatches — requested directly.
      keepHeight: true,
    );
  }

  void _openIconPage() {
    final flow = AppSheetFlow.of(context);
    flow.push(
      CategoryIconPage(
        selectedIconCodePoint: _iconCodePoint,
        onSelected: (iconCodePoint) {
          setState(() => _iconCodePoint = iconCodePoint);
          flow.pop();
        },
      ),
    );
  }

  void _finish(Category saved) {
    final onSaved = widget.onSaved;
    if (onSaved != null) {
      onSaved(saved);
    } else {
      Navigator.of(context).pop(saved);
    }
  }

  IconData get _iconChipIcon {
    for (final icon in curatedCategoryIcons) {
      if (icon.codePoint == _iconCodePoint) return icon;
    }
    return Icons.category_outlined;
  }

  Widget _buildHeaderTrailing(AmbleTheme theme) {
    final saveButton = AppButton(
      icon: Icons.check_rounded,
      shape: AppButtonShape.circle,
      tooltip: 'Save label',
      isLoading: _isSaving,
      onPressed: _canSave ? _save : null,
    );
    if (!_canDelete) return saveButton;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          icon: Icons.delete_outline_rounded,
          variant: AppButtonVariant.ghost,
          shape: AppButtonShape.circle,
          tooltip: 'Delete label',
          iconColor: theme.colorDestructive,
          onPressed: _delete,
        ),
        SizedBox(width: theme.spacingSm),
        saveButton,
      ],
    );
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final existing = widget.category;
      if (existing != null) {
        existing.name = _nameController.text.trim();
        existing.colorToken = _colorToken!;
        existing.iconCodePoint = _iconCodePoint!;
        await ref.read(categoryListProvider.notifier).updateCategory(existing);
        if (!mounted) return;
        _finish(existing);
        return;
      }
      final created = await ref
          .read(categoryListProvider.notifier)
          .createCategory(
            name: _nameController.text.trim(),
            colorToken: _colorToken!,
            // Superseded by iconCodePoint — see Category.emoji's own doc
            // comment. Every newly created category leaves this at '',
            // same as the built-in re-seed already does.
            emoji: '',
            iconCodePoint: _iconCodePoint!,
          );
      if (!mounted) return;
      _finish(created);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildHeader(AmbleTheme theme) => AppSheetFlowHeader(
    theme: theme,
    title: _isEditing ? 'Edit label' : 'New label',
    trailing: _buildHeaderTrailing(theme),
  );

  Widget _buildSheetBody(AmbleTheme theme) {
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacingXl * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          SizedBox(height: theme.spacingMd),
          AppTextField(
            controller: _nameController,
            label: 'Label name',
            variant: AppTextFieldVariant.bare,
            autofocus: !_isEditing,
            textInputAction: TextInputAction.done,
          ),
          SizedBox(height: theme.spacingLg),
          Wrap(
            spacing: theme.spacingSm,
            runSpacing: theme.spacingSm,
            children: [
              AppValueChip(
                label: 'Color',
                icon: Icons.palette_outlined,
                hasValue: _colorToken != null,
                onTap: _openColorPage,
              ),
              AppValueChip(
                label: 'Icon',
                icon: _iconChipIcon,
                hasValue: _iconCodePoint != null,
                onTap: _openIconPage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return _buildSheetBody(theme);
  }
}
