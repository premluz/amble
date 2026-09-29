import 'package:flutter/painting.dart';

import 'semantic_theme.dart';
import 'spacing_primitives.dart';

/// Tier 3 — component tokens: rare, per-component overrides for cases
/// where a component genuinely deviates from the Tier 2 semantic default.
///
/// Direct-manipulation previews share one quiet source-slot ghost across
/// draggable components, so the opacity belongs here rather than being
/// repeated as a per-widget value.
abstract final class DragPreviewTokens {
  static const double ghostOpacity = 0.2;
}

/// Clear space around the 24-hour spatial day surfaces so the first and last
/// time ticks can scroll clear of the fixed app chrome.
abstract final class TimelineScrollTokens {
  static const double topClearance = 60.0;
  static const double bottomClearance = 200.0;
}

/// A zone's card fill (Timeline and Zone view): the plain secondary surface,
/// slightly see-through so the day behind a zone still reads through it.
/// Zone-only: other cards on `colorSurfaceSecondary` stay opaque.
abstract final class ZoneSurfaceTokens {
  static const double fillAlpha = 0.8;

  static Color fill(AmbleTheme theme) => theme.colorSurfaceSecondary.withValues(
    alpha: theme.colorSurfaceSecondary.a * fillAlpha,
  );
}

/// The main nav's settings gear.
abstract final class TopNavTokens {
  /// One step up from `spacingMd` (16), so the gear holds its own beside
  /// the nav's text labels.
  static const double settingsIconSize = SpacingPrimitives.space6;
}
