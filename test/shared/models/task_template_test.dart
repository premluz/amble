import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaskTemplate.create', () {
    test('generates a distinct client UUID per template', () {
      final a = TaskTemplate.create(
        title: 'Take a walk',
        categoryId: BuiltInCategoryIds.health,
      );
      final b = TaskTemplate.create(
        title: 'Take a walk',
        categoryId: BuiltInCategoryIds.health,
      );

      expect(a.id, isNotEmpty);
      expect(a.id, isNot(b.id));
    });

    test('leaves every optional field null and defaults schemaVersion', () {
      final template = TaskTemplate.create(
        title: 'Take a walk',
        categoryId: BuiltInCategoryIds.health,
      );

      expect(template.durationMinutes, isNull);
      expect(template.notes, isNull);
      expect(template.behaviorId, isNull);
      expect(template.schemaVersion, 1);
    });
  });

  group('toJson/fromJson', () {
    test('round-trips every field', () {
      final template = TaskTemplate.create(
        title: 'Take a walk',
        categoryId: BuiltInCategoryIds.health,
        durationMinutes: 30,
        notes: 'Around the block',
        behaviorId: 'behavior-1',
      );

      final restored = TaskTemplate.fromJson(template.toJson());

      expect(restored.id, template.id);
      expect(restored.hasSameFieldsAs(template), isTrue);
    });

    test('round-trips a template with every optional field unset', () {
      final template = TaskTemplate.create(
        title: 'Take a walk',
        categoryId: BuiltInCategoryIds.health,
      );

      final restored = TaskTemplate.fromJson(template.toJson());

      expect(restored.durationMinutes, isNull);
      expect(restored.notes, isNull);
      expect(restored.behaviorId, isNull);
      expect(restored.hasSameFieldsAs(template), isTrue);
    });

    test('throws on a missing required field rather than defaulting it', () {
      final json = TaskTemplate.create(
        title: 'Take a walk',
        categoryId: BuiltInCategoryIds.health,
      ).toJson()..remove('categoryId');

      expect(() => TaskTemplate.fromJson(json), throwsFormatException);
    });
  });

  group('hasSameFieldsAs', () {
    test('is false when any single field differs', () {
      final base = TaskTemplate.create(
        title: 'Take a walk',
        categoryId: BuiltInCategoryIds.health,
        durationMinutes: 30,
      );
      final other = TaskTemplate.fromJson(base.toJson())..durationMinutes = 45;

      expect(base.hasSameFieldsAs(other), isFalse);
    });
  });
}
