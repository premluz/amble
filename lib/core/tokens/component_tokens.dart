/// Tier 3 — component tokens: rare, per-component overrides for cases
/// where a component genuinely deviates from the Tier 2 semantic default.
///
/// Direct-manipulation previews share one quiet source-slot ghost across
/// draggable components, so the opacity belongs here rather than being
/// repeated as a per-widget value.
abstract final class DragPreviewTokens {
  static const double ghostOpacity = 0.2;
}
