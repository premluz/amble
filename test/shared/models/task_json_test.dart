import 'package:flutter_test/flutter_test.dart';
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
      category: TaskCategory.work,
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
      category: TaskCategory.personal,
    ).toJson()..['scheduledAt'] = 'not-a-date';
    expect(() => Task.fromJson(json), throwsFormatException);
  });

  test('hasSameFieldsAs is false when any field differs', () {
    final a = Task.captured(title: 'Same title');
    final b = Task(
      id: a.id,
      title: 'Different title',
      category: TaskCategory.personal,
    );
    expect(a.hasSameFieldsAs(b), isFalse);
  });
}
