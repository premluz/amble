import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/task_detail/category_visual.dart';
import 'package:amble/shared/models/category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Requested directly, against a screenshot: "New task should not have
/// icon if label not set." General is the "untagged" placeholder every
/// new task's `categoryId` defaults to — it must resolve to no icon at
/// all everywhere, not just through `CategoryGlyph`, which is what left
/// `task_capsule_block.dart`'s own direct `categoryIconFor` call still
/// showing a fallback circle on the Timeline capsule for an untagged
/// task. See `categoryIconFor`'s own doc comment for the fuller story.
void main() {
  Category general({int? iconCodePoint}) => Category(
    id: BuiltInCategoryIds.general,
    name: 'General',
    colorToken: 0,
    emoji: '',
    iconCodePoint: iconCodePoint,
  );

  test('categoryIconFor returns null for General, never a fallback glyph', () {
    expect(categoryIconFor(general()), isNull);
  });

  test(
    'categoryIconFor returns null for General even if it somehow carries '
    'a stored iconCodePoint — the untagged state always wins',
    () {
      expect(categoryIconFor(general(iconCodePoint: Icons.star.codePoint)), isNull);
    },
  );

  test(
    'categoryIconFor still resolves a real icon for a genuine built-in '
    'category',
    () {
      final health = Category(
        id: BuiltInCategoryIds.health,
        name: 'Health',
        colorToken: 1,
        emoji: '',
      );
      expect(categoryIconFor(health), isNotNull);
    },
  );

  testWidgets('CategoryGlyph renders nothing for General', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryGlyph(
            category: general(),
            color: Colors.black,
            size: 24,
          ),
        ),
      ),
    );

    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('CategoryBadge renders no glyph for a null category either', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryBadge(
            theme: AmbleTheme.light,
            category: null,
            size: 24,
          ),
        ),
      ),
    );

    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Text), findsNothing);
  });
}
