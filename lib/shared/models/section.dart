import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

part 'section.g.dart';

const _uuid = Uuid();

/// A user-created folder for Inbox items — requested directly ("Sections
/// in inbox... essentially Folders for inbox items"). Structurally mirrors
/// [Category] (id/name, client-generated UUID, hand-written toJson/
/// fromJson) minus the category-specific display fields (no color token,
/// no icon) — a Section is a plain named grouping, nothing more.
///
/// A `Task` links to at most one Section via the nullable `Task.sectionId`
/// — same "id is just the link, resolved through the repository/provider"
/// shape [Category]/`Task.categoryId` already establish. There is no
/// built-in/seeded Section (unlike [Category]'s 5 seeded rows) — every
/// Section is user-created.
@HiveType(typeId: 17)
class Section extends HiveObject {
  Section({required this.id, required this.name, this.schemaVersion = 1});

  /// Creates a new Section with a client-generated UUID — same `uuid` call
  /// [Category.create]/[Task.create] use, per the Constitution's
  /// "IDs are client-generated UUIDs from day one" rule.
  Section.create({required String name})
    : this(id: _uuid.v4(), name: name);

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int schemaVersion;

  /// Serializes every persisted field to a JSON-safe map, for export.
  /// Hand-written, matching [Category.toJson]'s style.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'schemaVersion': schemaVersion,
  };

  /// Reconstructs a [Section] from [toJson]'s output, for import. Throws
  /// [FormatException] if a required field is missing or malformed —
  /// matches [Category.fromJson]'s fail-loud-on-malformed-input
  /// convention.
  factory Section.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final schemaVersion = json['schemaVersion'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Section.fromJson: missing or invalid "id"');
    }
    if (name is! String) {
      throw const FormatException(
        'Section.fromJson: missing or invalid "name"',
      );
    }
    if (schemaVersion is! int) {
      throw const FormatException(
        'Section.fromJson: missing or invalid "schemaVersion"',
      );
    }
    return Section(id: id, name: name, schemaVersion: schemaVersion);
  }
}
