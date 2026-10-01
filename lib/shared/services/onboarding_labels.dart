import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../models/label_presets.dart';
import '../providers/category_providers.dart';

/// Resolves a profile entry's `categoryName` to a real label id, in order:
/// 1. a built-in catalog key (`general`/`health`/`work`/`personal`/
///    `admin`), as every original profile uses;
/// 2. an existing label with that display name (any case) — so the Demo
///    can say "Social" or "Reading";
/// 3. a [labelPresets] entry, created on first use with its preset icon
///    and colour — so the Demo can say "Gym" or "Commute".
/// Anything else is a catalog bug and fails loudly.
class OnboardingLabelResolver {
  OnboardingLabelResolver(this._ref, this._profileId);

  final WidgetRef _ref;
  final String _profileId;

  Future<String> idFor(String name) async {
    final categories = _ref.read(categoryListProvider);
    for (final category in categories) {
      if (_builtInKeyFor(category.id) == name) return category.id;
    }
    final lower = name.toLowerCase();
    for (final category in categories) {
      if (category.name.toLowerCase() == lower) return category.id;
    }
    for (final preset in labelPresets) {
      if (preset.name.toLowerCase() != lower) continue;
      final created = await _ref
          .read(categoryListProvider.notifier)
          .createCategory(
            name: preset.name,
            colorToken: preset.colorToken,
            emoji: '',
            iconCodePoint: preset.icon.codePoint,
          );
      return created.id;
    }
    throw StateError(
      'Onboarding profile "$_profileId" references unknown label "$name" — '
      'expected a built-in key, an existing label name or a label preset.',
    );
  }
}

String _builtInKeyFor(String categoryId) => switch (categoryId) {
  BuiltInCategoryIds.general => 'general',
  BuiltInCategoryIds.health => 'health',
  BuiltInCategoryIds.work => 'work',
  BuiltInCategoryIds.personal => 'personal',
  BuiltInCategoryIds.admin => 'admin',
  _ => '',
};
