/// Tier 1 — raw corner-radius scale, no semantic meaning.
abstract final class RadiusPrimitives {
  static const radius0 = 0.0;
  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 12.0;
  static const radiusXl = 16.0;

  /// One rung past [radiusXl] on the same 4px-step scale — added
  /// specifically for a zone's own Edit Mode selection state
  /// (`ZoneBackgroundBlock`'s `editModeEnabled` branch), which is more
  /// rounded than its resting `radiusXl` card corner. Not [radiusModal]:
  /// that value is a documented one-off for the sheet surface, 2.5x this
  /// scale's own top rung, and would read as too round for a rectangular
  /// zone block.
  static const radiusXxl = 20.0;

  /// The modal sheet's corner. Deliberately far outside the sm→xl
  /// progression rather than an extra rung on it: a sheet corner this
  /// large is a one-off shape for one surface, and putting it on the
  /// shared scale would invite it onto ordinary cards.
  static const radiusModal = 40.0;

  static const radiusFull = 999.0;
}
