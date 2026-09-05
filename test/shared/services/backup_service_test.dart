import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/services/backup_service.dart';

void main() {
  late BackupService service;

  setUp(() {
    service = BackupService();
  });

  String buildBackupJson({
    Object? schemaVersion = 1,
    Object? tasks,
    Object? categories,
    Object? zones,
  }) {
    return jsonEncode({
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime(2026, 8, 20).toIso8601String(),
      'tasks': tasks ?? [],
      'categories': ?categories,
      'zones': ?zones,
    });
  }

  test('parses a well-formed backup with tasks', () {
    final task = Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 8, 20, 9),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.work,
    );
    final json = buildBackupJson(tasks: [task.toJson()]);

    final parsed = service.parseImportFile(json);

    expect(parsed.tasks, hasLength(1));
    expect(parsed.tasks.single.id, task.id);
    expect(parsed.tasks.single.title, 'Deep work');
  });

  test('parses a well-formed backup with an empty task list', () {
    final parsed = service.parseImportFile(buildBackupJson());
    expect(parsed.tasks, isEmpty);
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

  group('zones', () {
    test('parses a well-formed backup with zones', () {
      final zone = Zone.create(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );
      final json = buildBackupJson(zones: [zone.toJson()]);

      final parsed = service.parseImportFile(json);

      expect(parsed.zones, hasLength(1));
      expect(parsed.zones.single.id, zone.id);
      expect(parsed.zones.single.title, 'Morning ritual');
      expect(parsed.zones.single.startMinutes, 7 * 60);
      expect(parsed.zones.single.endMinutes, 8 * 60);
    });

    test('a backup exported before Zone existed (no "zones" key) still '
        'imports cleanly — zones default to an empty list', () {
      final parsed = service.parseImportFile(buildBackupJson());
      expect(parsed.zones, isEmpty);
    });

    test('rejects a file with one invalid zone record — the whole import '
        'fails, not a partial import', () {
      final validZone = Zone.create(
        title: 'Valid',
        startMinutes: 0,
        endMinutes: 60,
      ).toJson();
      final invalidZone = {'notAValidZoneRecord': true};
      final json = buildBackupJson(zones: [validZone, invalidZone]);

      expect(
        () => service.parseImportFile(json),
        throwsA(isA<BackupImportException>()),
      );
    });

    test('rejects a zone list that is not a JSON array', () {
      final json = buildBackupJson(zones: 'not a list');
      expect(
        () => service.parseImportFile(json),
        throwsA(isA<BackupImportException>()),
      );
    });
  });
}
