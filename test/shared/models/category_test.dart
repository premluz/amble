import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/category.dart';

void main() {
  test('Category.create generates a unique client-side UUID', () {
    final a = Category.create(name: 'Reading', colorToken: 0, emoji: '📚');
    final b = Category.create(name: 'Reading', colorToken: 0, emoji: '📚');

    expect(a.id, isNotEmpty);
    expect(a.id, isNot(equals(b.id)));
  });

  test(
    'Category.create defaults isBuiltIn to false and schemaVersion to 1',
    () {
      final category = Category.create(
        name: 'Gardening',
        colorToken: 3,
        emoji: '🌱',
      );

      expect(category.isBuiltIn, isFalse);
      expect(category.schemaVersion, 1);
    },
  );

  test('toJson -> fromJson round-trips a user-created category', () {
    final category = Category.create(
      name: 'Gardening',
      colorToken: 5,
      emoji: '🌱',
    );

    final restored = Category.fromJson(category.toJson());

    expect(restored.id, category.id);
    expect(restored.name, category.name);
    expect(restored.colorToken, category.colorToken);
    expect(restored.emoji, category.emoji);
    expect(restored.isBuiltIn, category.isBuiltIn);
    expect(restored.schemaVersion, category.schemaVersion);
  });

  test('toJson -> fromJson round-trips a built-in category', () {
    final category = Category(
      id: BuiltInCategoryIds.health,
      name: 'Health',
      colorToken: 0,
      emoji: '⛑️',
      isBuiltIn: true,
    );

    final restored = Category.fromJson(category.toJson());

    expect(restored.id, BuiltInCategoryIds.health);
    expect(restored.isBuiltIn, isTrue);
  });

  test('fromJson throws FormatException for a missing id', () {
    final json = Category.create(name: 'x', colorToken: 0, emoji: '⭐').toJson()
      ..remove('id');

    expect(() => Category.fromJson(json), throwsFormatException);
  });

  test('fromJson throws FormatException for a missing name', () {
    final json = Category.create(name: 'x', colorToken: 0, emoji: '⭐').toJson()
      ..remove('name');

    expect(() => Category.fromJson(json), throwsFormatException);
  });

  test('fromJson throws FormatException for a missing colorToken', () {
    final json = Category.create(name: 'x', colorToken: 0, emoji: '⭐').toJson()
      ..remove('colorToken');

    expect(() => Category.fromJson(json), throwsFormatException);
  });

  test('fromJson throws FormatException for a missing emoji', () {
    final json = Category.create(name: 'x', colorToken: 0, emoji: '⭐').toJson()
      ..remove('emoji');

    expect(() => Category.fromJson(json), throwsFormatException);
  });

  test(
    'fromJson defaults isBuiltIn to false when omitted (old export compat)',
    () {
      final json = Category.create(
        name: 'x',
        colorToken: 0,
        emoji: '⭐',
      ).toJson()..remove('isBuiltIn');

      final restored = Category.fromJson(json);

      expect(restored.isBuiltIn, isFalse);
    },
  );

  test('BuiltInCategoryIds are fixed, non-empty, and distinct', () {
    final ids = {
      BuiltInCategoryIds.general,
      BuiltInCategoryIds.health,
      BuiltInCategoryIds.work,
      BuiltInCategoryIds.personal,
      BuiltInCategoryIds.admin,
    };

    expect(ids, hasLength(5));
    for (final id in ids) {
      expect(id, isNotEmpty);
    }
  });
}
