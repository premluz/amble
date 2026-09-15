import 'package:hive_ce/hive_ce.dart';

part 'pill_shape.g.dart';

/// Which corner-rounding a task/zone pill's badge renders at — one global
/// setting spanning every pill-shaped surface in the app (Task view, Zone
/// view, Inbox), not a per-view choice. Requested directly: "we have
/// squary rounded shape of pills but rounded on inbox ... let's make it
/// configurable in admin ... this should affect globally, in edit tasks
/// etc."
///
/// Named rungs, not raw pixel values, for the same reason [TaskSize] is an
/// enum rather than a stored double — a persisted value must not depend on
/// a design decision that can still change later. See
/// `AmbleTheme.radiusPillSmall`/`radiusPillRounded`/`radiusPillFull` for
/// the actual pixel values, chosen to match Material 3's own named corner
/// scale (confirmed via AskUserQuestion) rather than reusing this app's
/// existing `radiusSm` unchanged — the old hardcoded pill corner (4px) was
/// tighter than Material's own "small" (8px), so [small] is a deliberate,
/// visible step up from what shipped before this setting existed, not a
/// silent no-op default.
///
/// Its own Hive type (not reused from anywhere else), mirroring
/// [TaskSize]'s own doc comment: a persisted value needs a storage format
/// that doesn't depend on this enum's declaration order or any other
/// type's shape.
@HiveType(typeId: 14)
enum PillShape {
  /// 8px — Material 3's own "small" component corner.
  @HiveField(0)
  small,

  /// 16px — Material 3's own "large" component corner.
  @HiveField(1)
  rounded,

  /// Fully round (a stadium shape) — matches [RadiusPrimitives.radiusFull]
  /// via `AmbleTheme.radiusPillFull`, the same value `radiusTaskPill`
  /// already uses for buttons/chips elsewhere in this app.
  @HiveField(2)
  full,
}
