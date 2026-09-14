import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../models/zone.dart';
import '../models/zone_facet.dart';

/// The current export-file schema version. Independent of [Task.schemaVersion]
/// in spirit (both start at 1 and would only diverge if the file's own
/// envelope needed a breaking change separate from the Task shape), but
/// kept as its own constant rather than reusing the model's default so a
/// future file-format change doesn't have to touch the model.
const backupSchemaVersion = 1;

/// The parsed, validated contents of an import file — tasks plus the
/// user's custom [Category] rows, so a fresh install's export/restore
/// carries a user's own categories forward, not just the built-in 5 (which
/// re-seed on their own at launch regardless — see
/// `CategoryList.seedBuiltInsAndBackfillIfNeeded`) — and the user's [Zone]
/// rows, which have no equivalent seed/backfill and would otherwise be
/// silently lost on restore.
class ParsedImportFile {
  const ParsedImportFile({
    required this.tasks,
    required this.categories,
    required this.zones,
    this.zoneFacets = const [],
  });

  final List<Task> tasks;
  final List<Category> categories;
  final List<Zone> zones;
  final List<ZoneFacet> zoneFacets;
}

/// Thrown when an import file is malformed or its schema version isn't
/// recognized. Callers should show [message] directly — it's already
/// written to be user-facing, not a raw exception dump.
class BackupImportException implements Exception {
  BackupImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Serializes/deserializes the full [Task] dataset to/from a JSON file, and
/// drives the platform share sheet / file picker for it. Contains no
/// storage logic of its own — every read comes from [TaskRepository]
/// (via the caller) and every write goes through [TaskList.importTasks],
/// per the "no bypassing the normal write path for bulk operations" rule.
class BackupService {
  /// Writes [tasks], [categories], and [zones] (so a user's custom
  /// categories and zones survive export/restore on a fresh install) to a
  /// temp JSON file and opens the platform share sheet for it. The file
  /// includes the full dataset (not just current/future) since export
  /// doubles as backup — see docs/SCOPE.md.
  Future<void> exportTasks(
    List<Task> tasks,
    List<Category> categories,
    List<Zone> zones, {
    List<ZoneFacet> zoneFacets = const [],
  }) async {
    final payload = {
      'schemaVersion': backupSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'categories': categories.map((category) => category.toJson()).toList(),
      'zones': zones.map((zone) => zone.toJson()).toList(),
      'zoneFacets': zoneFacets.map((facet) => facet.toJson()).toList(),
    };
    final json = const JsonEncoder.withIndent('  ').convert(payload);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final file = File('${tempDir.path}/amble-backup-$timestamp.json');
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/json')]),
    );
  }

  /// Opens the file picker for a JSON file, parses and validates it, and
  /// returns the tasks/categories it contains — ready to hand to
  /// `TaskList.importTasks`/`CategoryList.createCategory`-style saves.
  /// Returns `null` if the user cancelled the picker (not an error). Throws
  /// [BackupImportException] for anything that makes the file unsafe to
  /// import: unreadable, invalid JSON, missing/unrecognized
  /// `schemaVersion`, or any task record that fails [Task.fromJson]'s
  /// validation — the whole file is rejected in that case, never a partial
  /// import of only the records that happened to parse.
  Future<ParsedImportFile?> pickAndParseImportFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Select an Amble backup file',
    );
    if (file == null) return null;

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw BackupImportException('Could not read the selected file.');
    }

    return parseImportFile(utf8.decode(bytes));
  }

  /// The pure parsing/validation core of [pickAndParseImportFile], split
  /// out so it's directly unit-testable without a file picker platform
  /// channel. Same contract: throws [BackupImportException] for anything
  /// that makes [jsonString] unsafe to import.
  ParsedImportFile parseImportFile(String jsonString) {
    final Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Top-level JSON value is not an object');
      }
      payload = decoded;
    } on FormatException {
      throw BackupImportException('This file is not valid Amble backup JSON.');
    }

    final schemaVersion = payload['schemaVersion'];
    if (schemaVersion is! int) {
      throw BackupImportException(
        'This file is missing a schema version and cannot be imported.',
      );
    }
    if (schemaVersion != backupSchemaVersion) {
      throw BackupImportException(
        'This backup was made with a newer or unrecognized format '
        '(schema version $schemaVersion) and cannot be imported by this '
        'version of Amble.',
      );
    }

    final tasksJson = payload['tasks'];
    if (tasksJson is! List) {
      throw BackupImportException(
        'This file is missing its task list and cannot be imported.',
      );
    }

    final List<Task> tasks;
    try {
      tasks = tasksJson.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('task record is not a JSON object');
        }
        return Task.fromJson(entry);
      }).toList();
    } on FormatException catch (error) {
      throw BackupImportException(
        'This file contains an invalid task record and cannot be '
        'imported: ${error.message}',
      );
    }

    // Deliberately not required — a backup exported before Category
    // existed simply has no "categories" key at all, and must still
    // import cleanly (its tasks' categoryId values, if any, just won't
    // resolve to anything until the standard built-in seed runs).
    final categoriesJson = payload['categories'];
    final List<Category> categories;
    if (categoriesJson == null) {
      categories = const [];
    } else if (categoriesJson is! List) {
      throw BackupImportException(
        'This file has an invalid category list and cannot be imported.',
      );
    } else {
      try {
        categories = categoriesJson.map((entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException('category record is not a JSON object');
          }
          return Category.fromJson(entry);
        }).toList();
      } on FormatException catch (error) {
        throw BackupImportException(
          'This file contains an invalid category record and cannot be '
          'imported: ${error.message}',
        );
      }
    }

    // Deliberately not required — a backup exported before Zone existed
    // simply has no "zones" key at all, and must still import cleanly,
    // same "old exports still import" contract as categories above.
    final zonesJson = payload['zones'];
    final List<Zone> zones;
    if (zonesJson == null) {
      zones = const [];
    } else if (zonesJson is! List) {
      throw BackupImportException(
        'This file has an invalid zone list and cannot be imported.',
      );
    } else {
      try {
        zones = zonesJson.map((entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException('zone record is not a JSON object');
          }
          return Zone.fromJson(entry);
        }).toList();
      } on FormatException catch (error) {
        throw BackupImportException(
          'This file contains an invalid zone record and cannot be '
          'imported: ${error.message}',
        );
      }
    }

    final List<ZoneFacet> facets;
    try {
      facets = ((payload['zoneFacets'] ?? []) as List).map((e) => ZoneFacet.fromJson(Map<String,dynamic>.from(e as Map))).toList();
    } catch (_) { throw BackupImportException('This backup contains invalid zone names.'); }
    return ParsedImportFile(tasks: tasks, categories: categories, zones: zones, zoneFacets: facets);
  }
}
