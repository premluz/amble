import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

part 'category.g.dart';

const _uuid = Uuid();

/// Fixed client-generated UUIDs for the 5 seeded built-in categories —
/// deliberately NOT random, so seeding is idempotent if it ever runs twice
/// (see `category_providers.dart`'s `CategoryList.seedBuiltInsIfNeeded`) and
/// so the one-time [Task.category] -> [Task.categoryId] backfill migration
/// can resolve a legacy `TaskCategory` enum value to a stable, known id
/// without a lookup that could vary between runs.
abstract final class BuiltInCategoryIds {
  static const String general = '00000000-0000-4000-8000-000000000001';
  static const String health = '00000000-0000-4000-8000-000000000002';
  static const String work = '00000000-0000-4000-8000-000000000003';
  static const String personal = '00000000-0000-4000-8000-000000000004';
  static const String admin = '00000000-0000-4000-8000-000000000005';
}

/// A user-visible task category — the persisted, user-extensible successor
/// to the old fixed `TaskCategory` enum (`shared/models/task_category.dart`).
///
/// `TaskCategory` and `Task.category` are NOT removed or changed by this
/// model's existence — see the deprecation note on `Task.category` for why
/// (Hive field-index stability). This is purely an additive new entity: a
/// `Task` links to one via the new nullable `Task.categoryId`, resolved
/// through [CategoryRepository]/`categoryListProvider` rather than the old
/// enum's extension getters.
@HiveType(typeId: 8)
class Category extends HiveObject {
  Category({
    required this.id,
    required this.name,
    required this.colorToken,
    required this.emoji,
    this.iconCodePoint,
    this.isBuiltIn = false,
    this.schemaVersion = 1,
  });

  /// Creates a new user-defined category with a client-generated UUID —
  /// same `uuid` call [Task.create]/[TrackedBehavior.create] use, per the
  /// Constitution's "IDs are client-generated UUIDs from day one" rule.
  /// [isBuiltIn] is never passed here — only the fixed-UUID seed rows
  /// (see [BuiltInCategoryIds]) are built-in.
  Category.create({
    required String name,
    required int colorToken,
    required String emoji,
    int? iconCodePoint,
  }) : this(
         id: _uuid.v4(),
         name: name,
         colorToken: colorToken,
         emoji: emoji,
         iconCodePoint: iconCodePoint,
       );

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  /// Index into the 12-swatch palette (`ColorPrimitives.categoryPalette` /
  /// `AmbleTheme.categorySwatches`) — an int rather than a Hive-adapted
  /// enum, matching how the codebase already indexes into fixed color
  /// lists elsewhere (`OverlapClusterBlock`'s column index, etc.) rather
  /// than adding a new small enum + adapter for a value that's purely a
  /// positional lookup.
  @HiveField(2)
  int colorToken;

  /// Legacy display glyph — superseded by [iconCodePoint] (Tabler Icons,
  /// requested directly: "let's get tabler icons installed and use it
  /// instead of emojis for categories"). Kept, not removed or repurposed:
  /// a pre-existing export/import (`toJson`/`fromJson`) or a row from
  /// before this field existed still carries a real emoji here, and every
  /// render site now prefers [iconCodePoint] but falls back to this when
  /// it's null, so those rows keep showing SOMETHING rather than going
  /// blank. New categories (built-in re-seed and the add-category modal)
  /// no longer set this to anything but `''`.
  @HiveField(3)
  String emoji;

  /// Flags one of the 5 seeded rows (see [BuiltInCategoryIds]) for future
  /// reference. No behavior depends on this yet — v1 has no edit/delete UI
  /// for any category, built-in or custom.
  @HiveField(4)
  bool isBuiltIn;

  @HiveField(5)
  int schemaVersion;

  /// A Tabler Icons glyph (`IconData.codePoint` from the `tabler_icons_plus`
  /// package's `TablerIcons.*` constants) — the current display icon,
  /// replacing [emoji]. Null for a category that predates this field (an
  /// old export, or a row written before this session); render sites fall
  /// back to [emoji] in that case rather than showing nothing.
  @HiveField(6)
  int? iconCodePoint;

  /// Serializes every persisted field to a JSON-safe map, for export.
  /// Hand-written, matching [Task.toJson]'s style — not generated, per the
  /// same "small and stable enough to avoid a new dependency" reasoning.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorToken': colorToken,
    'emoji': emoji,
    'iconCodePoint': iconCodePoint,
    'isBuiltIn': isBuiltIn,
    'schemaVersion': schemaVersion,
  };

  /// Reconstructs a [Category] from [toJson]'s output, for import. Throws
  /// [FormatException] if a required field is missing or malformed —
  /// matches [Task.fromJson]'s fail-loud-on-malformed-input convention.
  factory Category.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final colorToken = json['colorToken'];
    final emoji = json['emoji'];
    final schemaVersion = json['schemaVersion'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Category.fromJson: missing or invalid "id"');
    }
    if (name is! String) {
      throw const FormatException(
        'Category.fromJson: missing or invalid "name"',
      );
    }
    if (colorToken is! int) {
      throw const FormatException(
        'Category.fromJson: missing or invalid "colorToken"',
      );
    }
    if (emoji is! String) {
      throw const FormatException(
        'Category.fromJson: missing or invalid "emoji"',
      );
    }
    if (schemaVersion is! int) {
      throw const FormatException(
        'Category.fromJson: missing or invalid "schemaVersion"',
      );
    }
    return Category(
      id: id,
      name: name,
      colorToken: colorToken,
      emoji: emoji,
      // Absent for any export written before this field existed — falls
      // back to null (and so to `emoji` at render time), same as every
      // other optional-field import precedent in this file.
      iconCodePoint: json['iconCodePoint'] as int?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      schemaVersion: schemaVersion,
    );
  }
}
