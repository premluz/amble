/// Tier 1 — raw spacing scale, no semantic meaning.
abstract final class SpacingPrimitives {
  static const space0 = 0.0;
  static const space1 = 2.0;
  static const space2 = 4.0;
  static const space3 = 8.0;
  static const space4 = 12.0;
  static const space5 = 16.0;
  static const space6 = 20.0;
  static const space7 = 24.0;

  /// Sits between [space7] (24) and [space8] (32) — added specifically for
  /// the "lg" rung of the task-size scale (`AmbleTheme.sizeTaskBadgeLg`),
  /// confirmed directly at 28 rather than either neighbouring rung.
  static const space7Point5 = 28.0;

  /// Sits between [space7Point5] (28) and [space8] (32) — the shared
  /// "content clears the top scroll-fade/heading" offset (`AmbleTheme`'s
  /// own `spacingContentTop`), confirmed directly: "as in templates
  /// current position +30 becomes NEW for all" — Tasks, Templates,
  /// Tracked, and every modal's own first pane all start at this one
  /// value now, per docs/DECISIONS.md.
  static const space7Point75 = 30.0;
  static const space8 = 32.0;
  static const space9 = 40.0;
  static const space10 = 56.0;
}
