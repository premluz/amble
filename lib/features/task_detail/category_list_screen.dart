import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/category.dart';
import '../../shared/providers/category_providers.dart';
import 'add_category_modal.dart';
import 'category_visual.dart';

/// Opens the Tags list — every saved [Category] (built-in and
/// user-defined alike), tap to edit, "+" to add. "Tags" in the UI,
/// "Category" in code throughout this file and everywhere else — requested
/// directly: "categories become tags." A copy-only rename this session:
/// the model class, its file name, `categoryId`, and every provider/
/// repository identifier are unchanged, so this doc comment (and every
/// other one in this file) keeps saying "Category"/"category" for the
/// underlying concept and switches to "Tag" only in the literal strings a
/// user actually reads.
///
/// Mirrors `zone_list_screen.dart`'s `ZoneListScreen`/`ZoneListBody` split
/// exactly: this pushed-page shell for Settings → Tags, [CategoryListBody]
/// (no back button/heading of its own) for embedding inside the Manage
/// screen's own Tags sub-tab.
///
/// Per CONSTITUTION.md's "v2: rename, recolor, and reorder" section —
/// reorder itself confirmed out of scope for now, so this is rename +
/// recolor + list/add only, same v1 scope [ZoneListScreen] already has.
Future<void> showCategoryListScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (context) => const CategoryListScreen()),
  );
}

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Scaffold(
      backgroundColor: theme.colorSurfacePrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(theme.spacingScreenPadding),
              child: Row(
                children: [
                  AppButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                    shape: AppButtonShape.circle,
                  ),
                  SizedBox(width: theme.spacingMd),
                  Expanded(child: Text('Tags', style: theme.textTitle)),
                  AppButton(
                    icon: Icons.add_rounded,
                    onPressed: () => showAddCategoryModal(context),
                    shape: AppButtonShape.circle,
                  ),
                ],
              ),
            ),
            const Expanded(child: CategoryListBody()),
          ],
        ),
      ),
    );
  }
}

/// The list+rows portion of the Categories screen, with no `Scaffold`/back
/// button/heading of its own — see [CategoryListScreen]'s own doc comment.
class CategoryListBody extends ConsumerWidget {
  const CategoryListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categories = ref.watch(categoryListProvider);

    if (categories.isEmpty) return _EmptyState(theme: theme);

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: theme.spacingScreenPadding),
      itemCount: categories.length,
      separatorBuilder: (_, _) => SizedBox(height: theme.spacingSm),
      itemBuilder: (context, index) => _CategoryRow(
        theme: theme,
        category: categories[index],
        onTap: () => showAddCategoryModal(context, category: categories[index]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spacingLg),
        child: Text(
          'No categories yet. Tap + to add one.',
          textAlign: TextAlign.center,
          style: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.theme,
    required this.category,
    required this.onTap,
  });

  final AmbleTheme theme;
  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatch = theme.categorySwatches[category.colorToken];

    return AppPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusXl),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(theme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusXl),
        ),
        child: Row(
          children: [
            Container(
              width: theme.spacingXl,
              height: theme.spacingXl,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
              // Not CategoryBadge — this row deliberately reads the raw
              // 12-swatch color by colorToken regardless of built-in
              // status (this IS the Tags management list; showing each
              // row's own assigned swatch, not a built-in override, is
              // the point here), which CategoryBadge's own fill logic
              // (resolveCategoryVisual, built-in-aware) doesn't produce.
              // Ratio bumped to CategoryBadge's own 0.55 default for
              // consistency, without adopting its differing fill color.
              child: CategoryGlyph(
                category: category,
                color: glyphColorOn(swatch),
                size: theme.spacingXl * 0.55,
              ),
            ),
            SizedBox(width: theme.spacingSm),
            Expanded(
              child: Text(
                category.name,
                style: theme.textBody.copyWith(
                  color: theme.colorTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorTextSecondary),
          ],
        ),
      ),
    );
  }
}
