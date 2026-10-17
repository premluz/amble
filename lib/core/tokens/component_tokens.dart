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

  /// Scroll-wheel / trackpad zoom (Cmd+scroll on macOS, Ctrl+scroll
  /// elsewhere): the timeline's scale is multiplied by
  /// `exp(-scrolled / scrollZoomDivisor)`, so one mouse-wheel notch (~100)
  /// is about a 22% step, and a long trackpad swipe covers the 1×–4× range
  /// in a few strokes.
  static const double scrollZoomDivisor = 400;

  /// Bringing a new quick-add draft into view: a calm glide, not a jump —
  /// requested directly ("needs to be smoother, calmer, at the moment too
  /// abrupt"). Longer the further it goes, within these bounds.
  static const revealMinMs = 450;
  static const revealMaxMs = 900;
  static const revealMsPerPixel = .6;

  static Duration revealDuration(double distance) => Duration(
    milliseconds: (revealMinMs + distance * revealMsPerPixel)
        .clamp(revealMinMs, revealMaxMs)
        .round(),
  );
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

/// The shell header row (main nav / a route's header pane).
abstract final class ShellHeaderTokens {
  /// The route header's floating pane (Edit's Things | Zones) sits this far
  /// from the screen edges — tighter than the nav text's
  /// `spacingScreenPadding`, which the nav applies to its own elements.
  static double paneSideInset(AmbleTheme theme) => theme.spacingSm;
}

/// The app shell's wide layout — a left sidebar replaces the top nav once
/// the window is wide enough (desktop, web, iPad landscape). Requested
/// directly, against a desktop-calendar reference: "two panes on the
/// sides: one left navigation... the central area will display the
/// content."
abstract final class ShellLayoutTokens {
  /// Material 3's "expanded" window size class starts at 840dp — the
  /// standard width where a persistent navigation rail/drawer replaces
  /// compact navigation. Below it, the phone layout is unchanged.
  static const double sideNavMinWindowWidth = 840;

  /// The sidebar's fixed width — room for the destination labels and, in
  /// a later phase, a mini month calendar (7 day columns).
  static const double sideNavWidth = 240;

  /// The right-hand create/edit panel's width — room for the task form's
  /// field rows without wrapping, while leaving the centre the most space.
  static const double inspectorWidth = 360;

  /// macOS draws the app under its (transparent) title bar, so the close /
  /// minimise / zoom buttons float over the content. This is that bar's
  /// height: the app treats it as a top safe area, so backgrounds run to
  /// the window's edge while controls start below the buttons and stay
  /// clickable (the bar itself keeps dragging the window).
  static const double macTitleBarHeight = 28;

  /// A browser tab on a phone reports NO status bar / home indicator
  /// inset at all (`MediaQuery.padding` is zero) — there genuinely is no
  /// native chrome to measure, unlike a real iOS/Android app. Content
  /// therefore sat flush against the browser's own UI, reported directly
  /// against the web preview: "add top bottom padding, because I think OS
  /// UI is not accounted for and looks too close to edge." These stand in
  /// for a typical phone's reserved top (status bar / notch) and bottom
  /// (home indicator) space — not any one real device's exact value,
  /// since the web build has no actual device to read it from. Web only
  /// (`AppWindowInsets`), and only below [sideNavMinWindowWidth] — a wide
  /// browser window is the desktop experience and keeps its own chrome
  /// handling untouched.
  static const double webMobileTopInset = 24;
  static const double webMobileBottomInset = 24;

  /// The shell's pane dividers (sidebar, side panel): [AmbleTheme.colorBorder]
  /// at this alpha (Notion Calendar's panel divider: +13 of +15), 1 point
  /// wide (`AppHairline`) — requested directly: "interface shell lines too
  /// thick and too strong".
  static const double dividerAlpha = .85;

  /// The width of shell dividers and calendar grid lines: 1 point (2
  /// physical pixels on Retina), as in Notion Calendar. Half the app's
  /// general `borderWidthHairline` (2 points).
  static const double lineWidth = 1;
}

/// The wide layout's week and month grids (`features/calendar/`).
abstract final class CalendarGridTokens {
  /// One hour's height in the week grid — a 1-hour task reads as a block
  /// with room for its title and time, as in Notion Calendar's week.
  static const double weekHourHeight = SpacingPrimitives.space9Point5;

  /// How far the week can zoom out and in: an hour's height, as multiples
  /// of [weekHourHeight].
  static const double weekZoomMin = 0.5;
  static const double weekZoomMax = 2.5;

  /// One press of the toolbar's zoom buttons multiplies the hour height by
  /// this (or divides by it).
  static const double weekZoomStep = 1.25;

  /// The week grid's hour-label column.
  static const double weekGutterWidth = SpacingPrimitives.space10;

  /// The week opens scrolled to this hour, where most days begin.
  static const int weekFirstVisibleHour = 7;

  /// The colored rail on the left of a week block or month row.
  static const double railWidth = 3;

  /// The strip at a week item's top and bottom edge that resizes it
  /// (resize cursor on hover). Items shorter than three strips keep only
  /// the bottom one, so there is always room left to grab and move.
  static const double weekResizeEdge = 6;

  /// The Day / Week / Month switch: three equal segments, each with room
  /// for "Month" at the desktop body size. A fixed width because the
  /// switch fills whatever width it is given and sits in a toolbar row.
  static const double spanSwitchWidth = 216;

  /// Grid line strength as [AmbleTheme.colorBorder] alphas, matched to
  /// Notion Calendar (measured on its #191919 canvas, separator +15): hour
  /// lines +6 (the quietest), day lines +9. Requested directly: the grid
  /// lines were "too strong".
  static const double hourLineAlpha = .4;
  static const double dayLineAlpha = .6;

  /// The least vertical room a week task's text row takes: two overlapping
  /// tasks that start close together stack their rows at least this far
  /// apart instead of printing over each other.
  static const double weekTextRowHeight = SpacingPrimitives.space7;

  /// A week block never gets shorter than this, so a 5-minute task is still
  /// a tappable sliver with its title readable beside the rail.
  static const double weekBlockMinHeight = SpacingPrimitives.space7;

  /// Space left between a week block and the block or edge beside it.
  static const double weekBlockGap = SpacingPrimitives.space1;

  /// Tasks listed in a month cell before "+N more".
  static const int monthVisibleTasks = 4;
}

/// The contextual popover that stands in for a bottom sheet in the wide
/// layout (`AppSheetPresentation.popover`).
abstract final class PopoverTokens {
  /// Room for the task pickers' wheels and a month calendar, a little
  /// narrower than the panel it opens beside.
  static const double width = 320;
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

  /// A task's edge-time pill's side padding (`TaskEdgeTimeLabel`). The
  /// column is sized to hold the widest pill too, not only bare labels —
  /// a bold pill ran its "m" under the zones otherwise.
  static double edgePillPaddingX(AmbleTheme theme) => theme.spacingSm;
}

/// Every bottom sheet's fill: the page's own background
/// (`colorSurfaceTimeline`, the app's scaffold colour). The scrim and the
/// floating edge separate the sheet, so it reads as a page and its content
/// layers exactly like a page's: Settings-style groups and in-sheet controls
/// on [inset], chips on their translucent rest tint. In dark mode the sheet
/// is lifted by a faint light layer ([darkLift]) — Apple's elevated dark
/// background — since a shadow barely reads on dark; [inset] lifts with it
/// so the step between them holds.
abstract final class SheetTokens {
  static Color surface(AmbleTheme theme) =>
      _lift(theme, theme.colorSurfaceTimeline);

  /// The dark-mode elevation layer: `colorTextPrimary` at this alpha over
  /// the sheet's colours. Slight on purpose — a lift, not the next palette
  /// step.
  static const darkLift = .03;

  static Color _lift(AmbleTheme theme, Color base) =>
      FloatingSurfaceTokens.isDark(theme)
      ? Color.alphaBlend(
          theme.colorTextPrimary.withValues(alpha: darkLift),
          base,
        )
      : base;

  /// A sheet's title (between × / ‹ and the action) and its name fields
  /// share one size, one step below `textTitle`.
  static TextStyle titleStyle(AmbleTheme theme) =>
      theme.textTitle.copyWith(fontSize: TypePrimitives.size3);

  /// Header row → the first field. The header row leaves the ×'s own
  /// breathing room under it, so this small step puts the name's glyphs
  /// about as far below × as × is from the sheet's top and side.
  static double headerToFieldGap(AmbleTheme theme) => theme.spacingXs;

  /// Below a sheet's content — above the home indicator, or the keyboard —
  /// the same as its side inset, so content never ends on an edge.
  static double contentBottomInset(AmbleTheme theme) => theme.spacingLg;

  /// How far a sheet is dragged down by its body before letting go closes
  /// it — longer than a handle's own, since a body drag starts anywhere.
  static const double dragCloseDistance = SpacingPrimitives.space12;

  /// The tallest an `AppSheetFlow` page gets, as a share of the screen:
  /// every page of a flow stays near one size (no jump from a short form to
  /// a full-screen grid); a longer page scrolls its body under its header.
  static const double flowMaxHeightShare = .6;

  /// How far the page underneath shifts aside while the next page of an
  /// `AppSheetFlow` slides in over it (a share of the sheet's width).
  static const double pageBehindShift = .3;

  /// A toggle row, tile or group inside a sheet: one step off [surface],
  /// as a Settings group is off the page.
  static Color inset(AmbleTheme theme) =>
      _lift(theme, theme.colorSurfaceSecondary);
}

/// Every chip — inline settings (`AppValueChip`), picker options
/// (`AppSelectableChip`, `CategoryChip`), badges (`AppBadgeChip`) — draws
/// from one scale. Two sizes, as chip systems conventionally have: compact
/// for a row of settings under a field, regular for the options of a
/// picker. Selected: the glass tint (`AppButton.subtleTint`) with primary
/// text, or — on a chip that carries its own colour (a label, a preset) —
/// a [ring]. The accent is kept for primary actions, not selection.
abstract final class ChipTokens {
  static double compactHeight(AmbleTheme theme) => theme.sizeButtonSm;
  static double regularHeight(AmbleTheme theme) => theme.sizeButtonMd;

  /// A category badge inside a compact chip: what's left of the compact
  /// height after the badge chip's equal `spacingSm` padding (16 of 32), so
  /// the chip lands exactly on a value chip's height.
  static double compactBadgeSize(AmbleTheme theme) =>
      compactHeight(theme) - theme.spacingSm * 2;

  /// A compact chip's icon, relative to its caption text — the value
  /// chip's own proportion (`AppValueChip`).
  static const compactIconScale = 1.2;

  /// The glyph's share of a compact badge — larger than the regular
  /// badge's 0.65 so the icon stays near a value chip's own icon size.
  static const compactBadgeGlyphRatio = .75;

  static double radius(AmbleTheme theme) => theme.radiusPill;

  /// Side padding: a third of the chip's height, so both sizes keep the
  /// same proportions.
  static double horizontalPadding(double height) => height / 3;

  /// A chip at rest — also the header's × / ‹ (`HeaderCircleButton`), so
  /// sheet chrome is as quiet as the chips under it. Translucent, so it sits
  /// one quiet step off ANY surface (page, sheet, Settings group) instead of
  /// matching one of them and vanishing. Selected is the stronger
  /// `AppButton.subtleTint` (.16) of the same colour.
  static Color restFill(AmbleTheme theme) =>
      theme.colorTextPrimary.withValues(alpha: restTintAlpha);
  static const restTintAlpha = .06;
  static Color restText(AmbleTheme theme) => theme.colorTextSecondary;
  static Color selectedText(AmbleTheme theme) => theme.colorTextPrimary;

  static const restWeight = FontWeight.w500;
  static const selectedWeight = FontWeight.w600;

  static Color ring(AmbleTheme theme) => theme.colorTextPrimary;
  static double ringWidth(AmbleTheme theme) => theme.borderWidthHairline * 1.5;
}

/// The developer touch visualizer (`AppTouchVisualizer`): a soft dot under
/// each finger, quiet enough to sit over a screen recording.
abstract final class TouchVisualizerTokens {
  /// Apple's minimum touch target, so the dot reads as "a fingertip".
  static double diameter(AmbleTheme theme) => theme.spacingXl + theme.spacingXs;

  /// Tinted from the text colour rather than plain white, so it shows on
  /// the light theme's paper as well as the dark one.
  static Color fill(AmbleTheme theme) =>
      theme.colorTextPrimary.withValues(alpha: fillAlpha);
  static Color ring(AmbleTheme theme) =>
      theme.colorTextPrimary.withValues(alpha: ringAlpha);
  static const fillAlpha = .16;
  static const ringAlpha = .5;
  static double ringWidth(AmbleTheme theme) => theme.borderWidthHairline;

  /// Arriving it settles up from slightly small; leaving it fades while
  /// easing a little larger, like a ripple letting go.
  static const appearScale = .8;
  static const releaseScale = 1.25;
  static Duration appear(AmbleTheme theme) => theme.motionFast;
  static Duration release(AmbleTheme theme) => theme.motionNormal;
}

/// The undo toast: glass, thinner than the menus' near-opaque glass, so the
/// screen behind it shows through.
abstract final class ToastTokens {
  /// Multiplied by the glass material's own fill alpha.
  static const fillAlpha = .7;
  static Color fill(AmbleTheme theme) =>
      theme.colorSurfaceOverlay.withValues(alpha: fillAlpha);
}

/// Where the floating bottom toolbars sit: as far from the screen's side
/// as from its bottom — requested directly, "for toolbar make same side
/// padding as from bottom". The bottom gap is the device's bottom safe area
/// plus [AmbleTheme.spacingBottomClearance]; the sides match it.
abstract final class DockTokens {
  static double edgeInset(AmbleTheme theme, EdgeInsets viewPadding) =>
      viewPadding.bottom + theme.spacingBottomClearance;
}
