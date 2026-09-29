import 'package:flutter/painting.dart';

import 'floating_surface_tokens.dart';
import 'semantic_theme.dart';
import 'spacing_primitives.dart';
import 'type_primitives.dart';

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

/// The page-heading line: the Day date, the Habits period heading and a
/// page's sub nav (e.g. the Inbox sections) share one type — body copy one
/// step down the scale (14, was `textBody`'s 16), regular weight — so the
/// three read as one line that stays put between pages.
abstract final class PageHeadingTokens {
  static TextStyle text(AmbleTheme theme) =>
      theme.textBody.copyWith(fontSize: TypePrimitives.size2);

  /// The heading line's own height, fixed and shared, with its text
  /// centred: tall enough for the small controls that sit on it (the date
  /// chevron, "Today", the sub nav's "+"), so none of them nudge the text
  /// and the three pages' headings line up by construction.
  static double rowHeight(AmbleTheme theme) => theme.spacingLg;
}

/// How far tasks sit in from a zone's edges, in both Day views: 75% of the
/// base spacing (requested directly: "reduce by 25% bottom, top and aside
/// padding of tasks inside zones"). What the SIDE inset gives up goes to
/// the time column ([freedForTimeColumn]), so zones start that much later
/// and the tasks themselves stay exactly where they were.
abstract final class ZoneInsetTokens {
  static const double scale = .75;

  /// A task's left inset from its zone's edge (timeline: from the band to
  /// the pill lanes; list view: the card's left padding). 18, was 24.
  static double side(AmbleTheme theme) => theme.spacingLg * scale;

  /// The list-view zone card's top/bottom padding. 12, was 16.
  static double vertical(AmbleTheme theme) => theme.spacingMd * scale;

  /// The side inset's saving (6), added to the time column's width.
  static double freedForTimeColumn(AmbleTheme theme) =>
      theme.spacingLg - side(theme);
}

/// The Day screen's time column.
abstract final class TimeColumnTokens {
  /// Taken from the gap between the time column and the zones and given to
  /// the column itself (requested directly: "slight more room for the time
  /// column at the cost of the gap between time and zone"). Zones and tasks
  /// don't move; the labels get the room.
  /// 8 (was 4, asked "still slightly wider"): the gap is now 8.
  static const double borrowedFromZoneGap = SpacingPrimitives.space3;

  /// Breathing room after the widest label, so the last letter (the "m" of
  /// "pm") never sits against — or under — the column's edge.
  static const double labelSlack = SpacingPrimitives.space2;
}

/// Every bottom sheet's fill. Light: the page background — the scrim and
/// the floating edge separate the sheet, so it reads as a page and its
/// content layers exactly like a page's (Settings-style groups and chips on
/// [inset]). Dark: one step up (the Settings-group surface), because a
/// shadow barely reads on dark and an edge alone gives little lift — the
/// same reason iOS lightens its "elevated" dark backgrounds.
abstract final class SheetTokens {
  static Color surface(AmbleTheme theme) => FloatingSurfaceTokens.isDark(theme)
      ? theme.colorSurfaceSecondary
      : theme.colorSurfaceBase;

  /// How far a sheet is dragged down by its body before letting go closes
  /// it — longer than a handle's own, since a body drag starts anywhere.
  static const double dragCloseDistance = SpacingPrimitives.space12;

  /// How far the page underneath shifts aside while the next page of an
  /// `AppSheetFlow` slides in over it (a share of the sheet's width).
  static const double pageBehindShift = .3;

  /// A chip, toggle row or tile inside a sheet: one step off [surface].
  static Color inset(AmbleTheme theme) => FloatingSurfaceTokens.isDark(theme)
      ? theme.colorSurfaceField
      : theme.colorSurfaceSecondary;
}
