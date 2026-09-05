import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';
import 'package:amble/shared/models/task_status.dart';

void main() {
  test('toJson -> fromJson round-trips a fully-populated scheduled task', () {
    final task = Task(
      id: 'task-1',
      title: 'Deep work',
      notes: 'Bring headphones',
      scheduledAt: DateTime(2026, 8, 20, 9, 30),
      durationMinutes: 90,
      originalScheduledAt: DateTime(2026, 8, 20, 8, 0),
      status: TaskStatus.rescheduled,
      completedAt: DateTime(2026, 8, 20, 10, 0),
      categoryId: BuiltInCategoryIds.work,
      schemaVersion: 1,
    );

    final restored = Task.fromJson(task.toJson());

    expect(restored.id, task.id);
    expect(restored.title, task.title);
    expect(restored.notes, task.notes);
    expect(restored.scheduledAt, task.scheduledAt);
    expect(restored.durationMinutes, task.durationMinutes);
    expect(restored.originalScheduledAt, task.originalScheduledAt);
    expect(restored.status, task.status);
    expect(restored.completedAt, task.completedAt);
    expect(restored.category, task.category);
    expect(restored.schemaVersion, task.schemaVersion);
    expect(restored.hasSameFieldsAs(task), isTrue);
  });

  test('toJson -> fromJson round-trips an unscheduled (Inbox) task', () {
    final task = Task.captured(title: 'Buy milk');

    final restored = Task.fromJson(task.toJson());

    expect(restored.id, task.id);
    expect(restored.title, 'Buy milk');
    expect(restored.scheduledAt, isNull);
    expect(restored.durationMinutes, isNull);
    expect(restored.isScheduled, isFalse);
    expect(restored.hasSameFieldsAs(task), isTrue);
  });

  test('fromJson throws FormatException for a missing id', () {
    final json = Task.captured(title: 'x').toJson()..remove('id');
    expect(() => Task.fromJson(json), throwsFormatException);
  });

  test('fromJson throws FormatException for a missing title', () {
    final json = Task.captured(title: 'x').toJson()..remove('title');
    expect(() => Task.fromJson(json), throwsFormatException);
  });

  test('fromJson throws FormatException for an unrecognized status', () {
    final json = Task.captured(title: 'x').toJson()
      ..['status'] = 'not_a_real_status';
    expect(() => Task.fromJson(json), throwsFormatException);
  });

  test('fromJson throws FormatException for an unrecognized category', () {
    final json = Task.captured(title: 'x').toJson()
      ..['category'] = 'not_a_real_category';
    expect(() => Task.fromJson(json), throwsFormatException);
  });

  test('fromJson throws FormatException for a malformed date string', () {
    final json = Task.create(
      title: 'x',
      scheduledAt: DateTime(2026, 8, 20),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.personal,
    ).toJson()..['scheduledAt'] = 'not-a-date';
    expect(() => Task.fromJson(json), throwsFormatException);
  });

  test('hasSameFieldsAs is false when any field differs', () {
    final a = Task.captured(title: 'Same title');
    final b = Task(
      id: a.id,
      title: 'Different title',
      categoryId: BuiltInCategoryIds.personal,
    );
    expect(a.hasSameFieldsAs(b), isFalse);
  });

  group('TrackedBehavior link fields (Phase 10)', () {
    test('both factories leave the behavior link null — ordinary tasks are '
        'entirely unaffected', () {
      final created = Task.create(
        title: 'Ordinary',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );
      final captured = Task.captured(title: 'Ordinary inbox item');

      for (final task in [created, captured]) {
        expect(task.behaviorId, isNull);
        expect(task.actualAmount, isNull);
        expect(task.isBehaviorInstance, isFalse);
      }
    });

    test('behaviorId and actualAmount survive a JSON round-trip', () {
      final task =
          Task.create(
              title: 'Exercise',
              scheduledAt: DateTime(2026, 8, 20, 7),
              durationMinutes: 60,
              categoryId: BuiltInCategoryIds.health,
            )
            ..behaviorId = 'behavior-123'
            ..actualAmount = 30;

      final restored = Task.fromJson(task.toJson());

      expect(restored.behaviorId, 'behavior-123');
      expect(restored.actualAmount, 30);
      expect(restored.isBehaviorInstance, isTrue);
    });

    test('a backup exported before these fields existed still imports — the '
        'keys are simply absent', () {
      final legacyJson =
          Task.create(
              title: 'Legacy task',
              scheduledAt: DateTime(2026, 8, 20, 9),
              durationMinutes: 30,
              categoryId: BuiltInCategoryIds.work,
            ).toJson()
            ..remove('behaviorId')
            ..remove('actualAmount');

      final restored = Task.fromJson(legacyJson);

      expect(restored.title, 'Legacy task');
      expect(restored.behaviorId, isNull);
      expect(restored.actualAmount, isNull);
    });

    test('hasSameFieldsAs distinguishes tasks differing only by their '
        'behavior link', () {
      final a = Task.captured(title: 'Same');
      final b = Task(id: a.id, title: 'Same', category: TaskCategory.personal)
        ..behaviorId = 'behavior-1';

      expect(a.hasSameFieldsAs(b), isFalse);
    });
  });

  group('notificationsEnabled', () {
    test('survives a JSON round-trip', () {
      final task = Task.create(
        title: 'Silent task',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
        notificationsEnabled: false,
      );

      final restored = Task.fromJson(task.toJson());

      expect(restored.notificationsEnabled, isFalse);
    });

    test('a backup exported before this field existed imports as true — '
        'matching the historical unconditional-notification behavior', () {
      final legacyJson = Task.create(
        title: 'Legacy task',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      ).toJson()..remove('notificationsEnabled');

      final restored = Task.fromJson(legacyJson);

      expect(restored.notificationsEnabled, isTrue);
    });

    test('hasSameFieldsAs distinguishes tasks differing only by '
        'notificationsEnabled', () {
      final a = Task.create(
        title: 'Same',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );
      final b = Task.create(
        title: 'Same',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
        notificationsEnabled: false,
      );

      expect(a.hasSameFieldsAs(b), isFalse);
    });
  });

  group('externalEventId', () {
    test('survives a JSON round-trip', () {
      final task = Task.create(
        title: 'Synced task',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      )..externalEventId = 'device-event-1';

      final restored = Task.fromJson(task.toJson());

      expect(restored.externalEventId, 'device-event-1');
    });

    test('a backup exported before Calendar sync existed still imports — '
        'externalEventId defaults to null, not required', () {
      final legacyJson = Task.create(
        title: 'Legacy task',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      ).toJson()..remove('externalEventId');

      final restored = Task.fromJson(legacyJson);

      expect(restored.externalEventId, isNull);
    });

    test('hasSameFieldsAs distinguishes tasks differing only by '
        'externalEventId', () {
      final a = Task.create(
        title: 'Same',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );
      final b = Task.create(
        title: 'Same',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      )..externalEventId = 'device-event-1';

      expect(a.hasSameFieldsAs(b), isFalse);
    });
  });

  group('templateId', () {
    test('survives a JSON round-trip', () {
      final task = Task.create(
        title: 'Take a walk',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
        templateId: 'template-1',
      );

      final restored = Task.fromJson(task.toJson());

      expect(restored.templateId, 'template-1');
    });

    test('a backup exported before TaskTemplate existed still imports — '
        'templateId defaults to null, not required', () {
      final legacyJson = Task.create(
        title: 'Legacy task',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      ).toJson()..remove('templateId');

      final restored = Task.fromJson(legacyJson);

      expect(restored.templateId, isNull);
    });

    test('an ordinary task created without a template leaves it null', () {
      final task = Task.create(
        title: 'Ordinary',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      expect(task.templateId, isNull);
    });

    test('hasSameFieldsAs distinguishes tasks differing only by '
        'templateId', () {
      final a = Task.create(
        title: 'Same',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );
      final b = Task.create(
        title: 'Same',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
        templateId: 'template-1',
      );

      expect(a.hasSameFieldsAs(b), isFalse);
    });
  });
}
