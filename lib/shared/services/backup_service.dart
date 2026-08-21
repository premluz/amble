import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/task.dart';

/// The current export-file schema version. Independent of [Task.schemaVersion]
/// in spirit (both start at 1 and would only diverge if the file's own
/// envelope needed a breaking change separate from the Task shape), but
/// kept as its own constant rather than reusing the model's default so a
/// future file-format change doesn't have to touch the model.
const backupSchemaVersion = 1;

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
  /// Writes [tasks] to a temp JSON file and opens the platform share sheet
  /// for it. The file includes the full dataset (not just current/future)
  /// since export doubles as backup — see docs/SCOPE.md.
  Future<void> exportTasks(List<Task> tasks) async {
    final payload = {
      'schemaVersion': backupSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': tasks.map((task) => task.toJson()).toList(),
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
  /// returns the tasks it contains — ready to hand to
  /// `TaskList.importTasks`. Returns `null` if the user cancelled the
  /// picker (not an error). Throws [BackupImportException] for anything
  /// that makes the file unsafe to import: unreadable, invalid JSON,
  /// missing/unrecognized `schemaVersion`, or any task record that fails
  /// [Task.fromJson]'s validation — the whole file is rejected in that
  /// case, never a partial import of only the records that happened to
  /// parse.
  Future<List<Task>?> pickAndParseImportFile() async {
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
  List<Task> parseImportFile(String jsonString) {
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

    try {
      return tasksJson.map((entry) {
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
  }
}
