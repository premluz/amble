import 'package:hive_ce/hive_ce.dart';

part 'tag_color_style.g.dart';

/// How a Tag's color renders on a task/zone pill — one global setting
/// spanning every pill-shaped surface in the app (Task view, Zone view,
/// Inbox), not a per-tag choice. Requested directly: "add config in admin
/// that lets to manage what gets the tag color as per tag (the pill or
/// just the icon...)."
///
/// Named rungs, not a raw opacity/color value, for the same reason
/// [PillShape] is an enum rather than a stored double — a persisted value
/// must not depend on a design decision that can still change later.
@HiveType(typeId: 16)
enum TagColorStyle {
  /// The whole pill/rail is filled with the tag's color (today's existing,
  /// unchanged look) — the icon glyph is just a contrast color on top of
  /// it, same as before this setting existed.
  @HiveField(0)
  pill,

  /// Only the small badge behind the icon carries the tag's full color;
  /// the rest of the pill/rail is the same tag color at reduced opacity
  /// (see `pillOpacityFor` in `category_visual.dart`) — requested
  /// directly: "the pill also being colored but much paler than the main
  /// color of the tag color selected." No lighten-by-lightness scale
  /// exists for the 12-swatch custom-tag palette today (only the 5
  /// built-ins have a hand-tuned pale-tint counterpart), so this mode
  /// reaches its paler rail via opacity — confirmed directly as the
  /// fallback to try first when no scale exists.
  @HiveField(1)
  iconOnly,
}
