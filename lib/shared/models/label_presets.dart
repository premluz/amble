import 'package:flutter/widgets.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// A ready-made label offered as a one-tap suggestion when creating a label
/// — name, icon and colour together. Nothing is created until one is
/// picked and saved, so a new install's label list stays short.
class LabelPreset {
  const LabelPreset(this.name, this.icon, this.colorToken);

  final String name;
  final IconData icon;

  /// Index into `AmbleTheme.categorySwatches`.
  final int colorToken;
}

/// Requested directly: "populate more icons, match it with preset labels…
/// come up with 20–30." Every icon is in `curatedCategoryIcons`, so a
/// picked preset can still be re-iconned from the same picker. Built-in
/// label names (Health, Work, Home…) are left out — they always exist.
const labelPresets = [
  LabelPreset('Exercise', TablerIcons.run, 1),
  LabelPreset('Gym', TablerIcons.dumbbell, 0),
  LabelPreset('Sport', TablerIcons.ballFootball, 13),
  LabelPreset('Swimming', TablerIcons.swimming, 14),
  LabelPreset('Walking', TablerIcons.walk, 4),
  LabelPreset('Cycling', TablerIcons.bike, 5),
  LabelPreset('Yoga', TablerIcons.yoga, 9),
  LabelPreset('Mindfulness', TablerIcons.sparkles, 15),
  LabelPreset('Sleep', TablerIcons.moon, 8),
  LabelPreset('Wind-down', TablerIcons.candle, 10),
  LabelPreset('Screen-free', TablerIcons.deviceTvOff, 7),
  LabelPreset('Meals', TablerIcons.toolsKitchen, 2),
  LabelPreset('Groceries', TablerIcons.shoppingCart, 3),
  LabelPreset('Shopping', TablerIcons.shoppingBag, 11),
  LabelPreset('Travel', TablerIcons.luggage, 7),
  LabelPreset('Holiday', TablerIcons.beach, 12),
  LabelPreset('Commute', TablerIcons.train, 6),
  LabelPreset('Office', TablerIcons.buildingSkyscraper, 8),
  LabelPreset('Focus', TablerIcons.target, 14),
  LabelPreset('Study', TablerIcons.books, 15),
  LabelPreset('Leisure', TablerIcons.sofa, 12),
  LabelPreset('Hobby', TablerIcons.palette, 10),
  LabelPreset('Fishing', TablerIcons.fishHook, 5),
  LabelPreset('Outdoors', TablerIcons.mountain, 4),
  LabelPreset('Family', TablerIcons.users, 11),
  LabelPreset('Kids', TablerIcons.moodHappy, 1),
  LabelPreset('Me time', TablerIcons.coffee, 2),
  LabelPreset('Audiobook', TablerIcons.headphones, 9),
  LabelPreset('Finance', TablerIcons.wallet, 3),
  LabelPreset('Chores', TablerIcons.vacuumCleaner, 6),
];

/// The suggestions still worth offering: not already a label, and matching
/// what has been typed so far.
List<LabelPreset> labelSuggestions({
  required Iterable<String> existingNames,
  required String query,
}) {
  final taken = {for (final name in existingNames) name.toLowerCase()};
  final typed = query.trim().toLowerCase();
  return [
    for (final preset in labelPresets)
      if (!taken.contains(preset.name.toLowerCase()) &&
          preset.name.toLowerCase().contains(typed))
        preset,
  ];
}
