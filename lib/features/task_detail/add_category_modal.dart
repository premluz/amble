import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_staggered_entrance.dart';
import '../../core/widgets/app_step_scaffold.dart';
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

/// Pushes the "Add new category" screen — the same near-full-screen
/// slide-up route `task_detail_sheet.dart`'s own `_pushDetailRoute` and
/// `zone_form_screen.dart`'s `showZoneFormScreen` both use, not
/// [AppSheet]: requested directly, "add category sheet should be near full
/// screen same as add task, and same pattern" — progressive disclosure
/// (Name-only first, everything else fading in once Done is confirmed) is
/// [StepScaffold]'s own pattern, and [AppSheet]'s fixed-content-height
/// contract has no notion of a primary button pinned to the bottom or a
/// two-stage body, both of which this now needs.
///
/// Reachable via the "+ Add new" link on both [TaskCategoryModal] and
/// `TaskNameCategoryModal`'s title row (create-only there — [category] is
/// always null) — resolves to the newly created [Category] so the calling
/// picker sheet can select it immediately, unchanged from before this
/// became a pushed route rather than a sheet.
///
/// [category] non-null opens in EDIT mode — rename + recolor + re-emoji an
/// existing category, per CONSTITUTION.md's "v2" section (reorder itself
/// confirmed out of scope for now). Reached from [CategoryListScreen]'s
/// own list. Mirrors `zone_form_screen.dart`'s `showZoneFormScreen(zone:)`
/// shape exactly: editing skips straight to the full form (stage 2),
/// there being nothing to stage for a category that already has every
/// field filled in.
Future<Category?> showAddCategoryModal(
  BuildContext context, {
  Category? category,
}) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  return Navigator.of(context).push<Category?>(
    PageRouteBuilder<Category?>(
      opaque: false,
      // Same slide-up, scrim-barrier presentation as the task and zone
      // creation flows — this is the exact route shape [StepScaffold] was
      // designed to sit inside.
      barrierColor: theme.colorScrim,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) =>
          _AddCategoryScreen(category: category),
    ),
  );
}

class _AddCategoryScreen extends ConsumerStatefulWidget {
  const _AddCategoryScreen({this.category});

  /// Non-null for edit mode — see [showAddCategoryModal]'s own doc
  /// comment.
  final Category? category;

  @override
  ConsumerState<_AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends ConsumerState<_AddCategoryScreen> {
  final _nameController = TextEditingController();
  int? _colorToken;
  String? _emoji;
  bool _isSaving = false;

  /// Stage 1 (Name only) vs. stage 2 (Color + Emoji) — the same
  /// progressive-disclosure pattern the task and zone creation flows use.
  /// Requested directly: "this would be a pattern of progressive
  /// disclosure that applies to task, zone, category." Editing an existing
  /// category skips straight to stage 2, same as `zone_form_screen.dart`'s
  /// own `_isEditing` skip — there is nothing to stage for a category that
  /// already has every field filled in.
  bool _isNameStage = true;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    if (category != null) {
      _nameController.text = category.name;
      _colorToken = category.colorToken;
      _emoji = category.emoji;
      _isNameStage = false;
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
      _emoji != null &&
      !_isSaving;

  /// Confirms stage 1 (Name) and advances to stage 2 — fired by stage 1's
  /// own Done button or the Name field's keyboard-complete action. Mirrors
  /// `task_detail_sheet.dart`'s own `_confirmNameStage` exactly: an empty
  /// name at this point closes the whole screen instead of advancing to a
  /// form with nothing named yet, rather than asking to confirm discarding
  /// a draft the user never actually started.
  void _confirmNameStage() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_nameController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isNameStage = false);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final existing = widget.category;
      if (existing != null) {
        existing.name = _nameController.text.trim();
        existing.colorToken = _colorToken!;
        existing.emoji = _emoji!;
        await ref.read(categoryListProvider.notifier).updateCategory(existing);
        if (!mounted) return;
        Navigator.of(context).pop(existing);
        return;
      }
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

    // Stage 2's panes, staggered in exactly like the task and zone
    // creation flows' own `staggeredPanes` — built as a plain list so the
    // entrance index is each pane's position in it, not hand-numbered at
    // each call site.
    final staggeredPanes = [
      AppPane(
        title: 'Color',
        child: Wrap(
          spacing: theme.spacingSm,
          runSpacing: theme.spacingSm,
          children: [
            for (var index = 0; index < theme.categorySwatches.length; index++)
              _ColorSwatch(
                color: theme.categorySwatches[index],
                selected: _colorToken == index,
                onSelected: () => setState(() => _colorToken = index),
              ),
          ],
        ),
      ),
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
    ];

    return StepScaffold(
      theme: theme,
      modalTitle: _isEditing ? 'Edit category' : 'New category',
      titleAlignment: TextAlign.left,
      headerColor: theme.colorAccent,
      headerContent: null,
      onClose: () => Navigator.of(context).pop(),
      onBack: null,
      // Same stage-1/stage-2 pattern as the task and zone creation flows —
      // requested directly, applying it to category too.
      primaryLabel: _isNameStage ? 'Done' : 'Save',
      onPrimaryPressed: _isNameStage
          ? _confirmNameStage
          : (_canSave ? _save : null),
      isPrimaryLoading: !_isNameStage && _isSaving,
      body: SingleChildScrollView(
        // Top reverted to a plain spacingLg — the fade now lives inside
        // StepScaffold's own header container, clipped to it.
        padding: EdgeInsets.fromLTRB(
          theme.spacingLg,
          theme.spacingLg,
          theme.spacingLg,
          theme.spacingXl * 3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Always in the tree, never rebuilt as a different instance —
            // same reasoning as the task/zone flows' own Name field: its
            // Element (and any focus/keyboard state) must survive the
            // stage 1 -> 2 transition untouched, not remount as a fresh
            // field.
            AppPane(
              title: 'Name',
              child: AppTextField(
                controller: _nameController,
                label: 'Category name',
                autofocus: !_isEditing,
                onSubmitted: (_) => _confirmNameStage(),
              ),
            ),
            if (!_isNameStage) ...[
              SizedBox(height: theme.spacingLg),
              for (final (index, pane) in staggeredPanes.indexed) ...[
                AppStaggeredEntrance(index: index, child: pane),
                SizedBox(height: theme.spacingLg),
              ],
            ],
          ],
        ),
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
