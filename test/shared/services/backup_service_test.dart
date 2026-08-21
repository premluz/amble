import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';
import 'package:amble/shared/services/backup_service.dart';

void main() {
  late BackupService service;

  setUp(() {
    service = BackupService();
  });

  String buildBackupJson({Object? schemaVersion = 1, Object? tasks}) {
    return jsonEncode({
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime(2026, 8, 20).toIso8601String(),
      'tasks': tasks ?? [],
    });
  }

  test('parses a well-formed backup with tasks', () {
    final task = Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 8, 20, 9),
      durationMinutes: 30,
      category: TaskCategory.work,
    );
    final json = buildBackupJson(tasks: [task.toJson()]);

    final parsed = service.parseImportFile(json);

    expect(parsed, hasLength(1));
    expect(parsed.single.id, task.id);
    expect(parsed.single.title, 'Deep work');
  });

  test('parses a well-formed backup with an empty task list', () {
    final parsed = service.parseImportFile(buildBackupJson());
    expect(parsed, isEmpty);
  });

  test('rejects malformed (non-JSON) content', () {
    expect(
      () => service.parseImportFile('not json at all'),
      throwsA(isA<BackupImportException>()),
    );
  });

  test('rejects a JSON array at the top level (not an object)', () {
    expect(
      () => service.parseImportFile('[1, 2, 3]'),
      throwsA(isA<BackupImportException>()),
    );
  });

  test('rejects a missing schemaVersion', () {
    final json = jsonEncode({'tasks': []});
    expect(
      () => service.parseImportFile(json),
      throwsA(isA<BackupImportException>()),
    );
  });

  test('rejects an unrecognized (future) schemaVersion', () {
    final json = buildBackupJson(schemaVersion: 999);
    expect(
      () => service.parseImportFile(json),
      throwsA(isA<BackupImportException>()),
    );
  });

  test('rejects a missing tasks list', () {
    final json = jsonEncode({'schemaVersion': 1});
    expect(
      () => service.parseImportFile(json),
      throwsA(isA<BackupImportException>()),
    );
  });

  test('rejects a file with one invalid task record — the whole import '
      'fails, not a partial import', () {
    final validTask = Task.captured(title: 'Valid').toJson();
    final invalidTask = {'notAValidTaskRecord': true};
    final json = buildBackupJson(tasks: [validTask, invalidTask]);

    expect(
      () => service.parseImportFile(json),
      throwsA(isA<BackupImportException>()),
    );
  });
}
