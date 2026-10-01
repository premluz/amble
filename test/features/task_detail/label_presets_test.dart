import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_badge_chip.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/add_category_modal.dart';
import 'package:amble/features/task_detail/category_visual.dart';
import 'package:amble/shared/models/label_presets.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';

import '../../support/seeded_category_box.dart';

/// Requested directly: "populate more icons, match it with preset labels…
/// come up with 20–30"; offered as suggestions in New label.
void main() {
  group('labelPresets', () {
    test('20–30 presets, unique names, curated icons, real swatches', () {
      expect(labelPresets.length, inInclusiveRange(20, 30));
      final names = labelPresets.map((p) => p.name.toLowerCase());
      expect(names.toSet(), hasLength(labelPresets.length));
      final curated = curatedCategoryIcons.map((i) => i.codePoint).toSet();
      final swatches = AmbleTheme.light.categorySwatches.length;
      for (final preset in labelPresets) {
        expect(curated, contains(preset.icon.codePoint), reason: preset.name);
        expect(preset.colorToken, lessThan(swatches), reason: preset.name);
      }
    });

    test('suggestions drop existing labels and follow the typed name', () {
      final gym = labelSuggestions(existingNames: ['gym'], query: '');
      expect(gym.map((p) => p.name), isNot(contains('Gym')));
      final typed = labelSuggestions(existingNames: const [], query: 'swim');
      expect(typed.map((p) => p.name), ['Swimming']);
    });
  });

  testWidgets('tapping a suggestion fills name, colour and icon, and saves', (
    tester,
  ) async {
    late Box<Category> box;
    await tester.runAsync(() async {
      Hive.init('./.dart_tool/test_hive_label_presets');
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
      box = await openSeededCategoryBox(
        'test_categories_${DateTime.now().microsecondsSinceEpoch}',
      );
    });
    addTearDown(() => tester.runAsync(box.close));
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(box),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData(extensions: [AmbleTheme.light]),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    unawaited(showAddCategoryModal(navigatorKey.currentContext!));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'swim');
    await tester.pump();
    final chip = find.widgetWithText(AppBadgeChip, 'Swimming');
    // Compact like every chip: the value chips' badge size.
    expect(
      tester.getSize(
        find.descendant(of: chip, matching: find.byType(CategoryBadge)),
      ),
      Size.square(ChipTokens.compactBadgeSize(AmbleTheme.light)),
    );
    // Near its end: the name field's cursor handle floats over the chip's
    // middle right after typing.
    await tester.tapAt(tester.getRect(chip).centerRight - const Offset(12, 0));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Save label'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final saved = box.values.singleWhere((c) => c.name == 'Swimming');
    final preset = labelPresets.singleWhere((p) => p.name == 'Swimming');
    expect(saved.colorToken, preset.colorToken);
    expect(saved.iconCodePoint, preset.icon.codePoint);
  });
}
