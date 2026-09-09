import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/category.dart';
import '../../shared/providers/category_providers.dart';
import 'add_category_modal.dart';

/// Opens the Categories list — every saved [Category] (built-in and
/// user-defined alike), tap to edit, "+" to add. Mirrors
/// `zone_list_screen.dart`'s `ZoneListScreen`/`ZoneListBody` split exactly:
/// this pushed-page shell for Settings → Categories, [CategoryListBody]
/// (no back button/heading of its own) for embedding inside the Manage
/// screen's "Categories" sub-tab.
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
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: theme.spacingMd),
                  Expanded(
                    child: Text('Categories', style: theme.textHeadline),
                  ),
                  AppIconButton(
                    icon: Icons.add_rounded,
                    onPressed: () => showAddCategoryModal(context),
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
              child: Text(category.emoji, style: theme.textBody),
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
