import 'package:hive_ce/hive_ce.dart';

part 'task_size.g.dart';

/// Which rung of the task-size scale (badge/icon diameter + task-related
/// font size, moving together) the Timeline currently renders at — one
/// global setting affecting Task view, List view, and Zone view alike, not
/// a per-view choice. Requested directly: "let's establish this size as
/// sm ... let's bring md that is slight larger ... previous before this
/// change was lg" (original values sm 20/12, md 24/14, lg 28/16; the font
/// half of each pairing was shifted one step down the type scale
/// 2026-09-12 — now sm 20/11, md 24/12, lg 28/14 — see
/// `AmbleTheme.sizeTaskBadgeSm`/`textTaskTitleSm` and its md/lg siblings
/// for the exact pairing).
///
/// Its own Hive type (not reused from anywhere else) for the same reason
/// [AppThemeMode] has one: a persisted value needs a storage format that
/// doesn't depend on this enum's declaration order or any other type's
/// shape.
@HiveType(typeId: 11)
enum TaskSize {
  @HiveField(0)
  sm,
  @HiveField(1)
  md,
  @HiveField(2)
  lg,
}
