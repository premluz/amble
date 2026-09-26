import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'color_primitives.dart';
import 'motion_primitives.dart';
import 'radius_primitives.dart';
import 'spacing_primitives.dart';
import 'type_primitives.dart';

/// Semantic task category. Fixed taxonomy, not a free color picker —
/// see docs/DECISIONS.md ("Task colors are semantic categories").
// **2026-09-23 — expanded from 5 to 9.** `personal` is now a NEW
// category (user icon) at its own hue; the OLD "personal" role (home
// icon) is `home`. `social`/`reading`/`learning` are new. See
// `ColorPrimitives`' own 2026-09-23 comment for the full hue reassignment.
enum TaskCategoryToken {
  general,
  health,
  work,
  home,
  personal,
  social,
  reading,
  learning,
  admin,
}

/// Tier 2 — semantic tokens, meaning-bound references to Tier 1.
/// This is the layer widgets actually consume; never reference
/// [ColorPrimitives] etc. directly from a widget.
@immutable
class AmbleTheme extends ThemeExtension<AmbleTheme> {
  const AmbleTheme({
    required this.colorSurfaceBase,
    required this.colorSurfacePrimary,
    required this.colorSurfaceSecondary,
    required this.colorSurfaceOverlay,
    required this.colorSurfaceTimeline,
    required this.colorSurfaceField,
    required this.colorSurfaceFieldActive,
    required this.colorScrim,
    required this.colorSurfaceBlurOverlay,
    required this.blurOverlaySigma,
    required this.colorFreeWindow,
    required this.colorZoneBackground,
    required this.colorTextPrimary,
    required this.colorTextSecondary,
    required this.colorTextTertiary,
    required this.colorBorder,
    required this.colorAccent,
    required this.colorTaskCompleted,
    required this.colorTaskSkipped,
    required this.colorTaskAlert,
    required this.categoryColors,
    required this.categoryIconColors,
    required this.categorySwatches,
    required this.spacingXs,
    required this.spacingSm,
    required this.spacingIconTop,
    required this.spacingMd,
    required this.spacingLg,
    required this.spacingXl,
    required this.spacingBlockGap,
    required this.spacingScreenPadding,
    required this.spacingTimeColumnWidth,
    required this.spacingTimelineGutter,
    required this.spacingContentTop,
    required this.spacingMinTapTarget,
    required this.sizeMinFieldHeight,
    required this.sizeTaskBadgeSm,
    required this.sizeTaskBadgeMd,
    required this.sizeTaskBadgeLg,
    required this.sizeTaskBadgeXl,
    required this.sizeTaskBadge,
    required this.sizeButtonXs,
    required this.sizeButtonSm,
    required this.sizeButtonMd,
    required this.sizeButtonLg,
    required this.sizeButtonXl,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusXxl,
    required this.radiusTaskPill,
    required this.radiusPillSmall,
    required this.radiusPillRounded,
    required this.radiusPillFull,
    required this.radiusPill,
    required this.radiusModal,
    required this.borderWidthHairline,
    required this.borderWidthConnector,
    required this.shadowLift,
    required this.shadowPane,
    required this.textHeadline,
    required this.textTitle,
    required this.textBody,
    required this.textBodyMono,
    required this.textLabel,
    required this.textCaption,
    required this.textCaptionMono,
    required this.textZoneName,
    required this.textTaskEdgeTime,
    required this.textTaskTitleSm,
    required this.textTaskTitleMd,
    required this.textTaskTitleLg,
    required this.textTaskTitle,
    required this.textTaskTitleZone,
    required this.motionFast,
    required this.motionNormal,
    required this.motionSlow,
    required this.motionRouteSettle,
    required this.motionSheetSlide,
    required this.motionKeyboardSettle,
    required this.curveStandard,
    required this.curveDecelerate,
  });

  // Surfaces — an explicit elevation scale, read as steps 0/1/2 rather
  // than as unrelated colors. Level 0 is the ground everything sits on;
  // level 1 is a pane raised off it; level 2 is a control inset INTO a
  // pane. Anything that needs a surface picks the level that matches its
  // structural role, so nesting stays legible without borders.
  /// Level 0 — the app background panes are laid on top of.
  final Color colorSurfaceBase;

  /// Level 1 — a pane/card raised above [colorSurfaceBase].
  final Color colorSurfacePrimary;
  final Color colorSurfaceSecondary;
  final Color colorSurfaceTimeline;

  /// The TOP of the elevation stack — a floating pane that sits above all
  /// page content (the bottom nav; a modal's own surface).
  ///
  /// In dark mode this is the LIGHTEST surface in the ramp, not the
  /// darkest. That direction is the whole point: light falls from above,
  /// so a surface nearer the viewer catches more of it. The nav bar
  /// previously painted `colorSurfacePrimary`, which in dark mode is
  /// `ink900` — the same value as `bg.base`, making the floating element
  /// the darkest thing on screen and inverting the depth cue. In light
  /// mode the direction flips: the base is already near-white, so an
  /// overlay separates by staying white and casting a soft shadow
  /// instead ([shadowPane]).
  final Color colorSurfaceOverlay;

  /// Level 2 — a form field's resting fill, inset into a level-1 pane.
  final Color colorSurfaceField;

  /// Level 2, active — the same field while focused. One tone further from
  /// the pane, so focus is carried by the fill itself and needs no ring or
  /// border to be visible.
  final Color colorSurfaceFieldActive;

  /// The dim laid over whatever a modal covers.
  ///
  /// One token for every modal layer, so a sheet opened on top of another
  /// sheet dims it by exactly the amount the first sheet dimmed the page.
  /// Deliberately the SAME value in both palettes: a scrim's job is to
  /// push the layer behind it back, and black at low alpha does that on
  /// any background — lightening it for dark mode would make it stop
  /// reading as depth.
  final Color colorScrim;

  /// [colorSurfacePrimary] at 36% opacity, paired with [blurOverlaySigma] —
  /// the "frosted glass" fill for content that floats OVER other content
  /// rather than sitting flat on a page (currently the dragged task
  /// block's card). Derived from the pane surface, not a separate color:
  /// the intent is "the same pane material, translucent because it's
  /// airborne," not a new surface family. Always paired with a
  /// `BackdropFilter` using [blurOverlaySigma] — the opacity alone, with
  /// no blur behind it, would just look like a dim rather than glass.
  final Color colorSurfaceBlurOverlay;

  /// The Gaussian blur sigma (in logical pixels) for whatever sits behind
  /// [colorSurfaceBlurOverlay] — 12px, per direct specification. A single
  /// shared value rather than each call site picking its own, so every
  /// frosted-glass surface in the app blurs by the same amount.
  final double blurOverlaySigma;

  /// [colorBorder] at low opacity — the subtle wash for a large free-time
  /// window's block on the Timeline (see `free_window_block.dart`).
  /// Derived from the border/hairline color rather than a new primitive:
  /// the intent is "a faint structural hint, not a surface," matching how
  /// the block itself is meant to read as quiet scaffolding rather than a
  /// competing task-like element. Requested directly: "a subtle block...
  /// some transparent light grey color."
  final Color colorFreeWindow;

  /// The rendering-only backdrop for a [Zone] on the Spatial Task View
  /// (Timeline) — see `zone_background_block.dart`. Deliberately its own
  /// primitive (`ColorPrimitives.zoneBackground`), not a reuse of
  /// [colorFreeWindow] or any category color: a zone block and a
  /// free-window block answer different questions (Zone = "this time
  /// range has meaning," free window = "nothing is scheduled here") and
  /// must not be visually conflated. See CONSTITUTION.md's Zone section —
  /// this token exists purely for the Spatial Task View's decorative
  /// treatment; it carries no container/layout meaning.
  final Color colorZoneBackground;

  // Text
  final Color colorTextPrimary;
  final Color colorTextSecondary;

  /// Even subtler than [colorTextSecondary] — for ambient, purely
  /// decorative text that should read as background chrome rather than
  /// content (the rotated zone-name label on the Task view's right edge;
  /// a zone card's own header title in the non-spatial Zone view).
  /// Requested directly: zone names needed to be "even subtler" than the
  /// existing secondary color. A dedicated token rather than a darker/
  /// lighter inline tweak at each call site, so every ambient-label use
  /// stays in sync and the exact subtlety is tunable in one place. Solved
  /// for ~3.3-3.4:1 against each theme's own base — past WCAG's 3:1 floor
  /// for large/decorative text, clearly lighter than [colorTextSecondary]
  /// (4.66:1 light / 7.61:1 dark) without fading to illegible.
  final Color colorTextTertiary;

  // Structure
  final Color colorBorder;
  final Color colorAccent;

  // Task status
  final Color colorTaskCompleted;
  final Color colorTaskSkipped;
  final Color colorTaskAlert;

  /// Fixed task-category taxonomy → pill fill color. See [TaskCategoryToken].
  final Map<TaskCategoryToken, Color> categoryColors;

  /// Fixed task-category taxonomy → icon glyph color, drawn on top of
  /// [categoryColors]'s fill. A separate map rather than a single color
  /// per category because the two now serve different jobs: the fill is a
  /// pale tint (Phase 13a-pastel-v2) that alone can't carry real contrast
  /// at any glyph color, so the icon is a deliberately more saturated,
  /// same-hue color chosen to read clearly against its own pale fill — see
  /// docs/DECISIONS.md for the contrast numbers per category.
  final Map<TaskCategoryToken, Color> categoryIconColors;

  /// The 12-swatch palette a user picks from when creating a new
  /// [Category] (the persisted, user-extensible entity — distinct from the
  /// fixed [TaskCategoryToken] taxonomy above). Single saturated swatch per
  /// color, not a tint+icon pair, per the confirmed decision in
  /// docs/DECISIONS.md — [Category.colorToken] is a plain index into this
  /// list. Same list in both [light] and [dark] — its lightness/chroma
  /// were chosen to already be dark-mode-safe, so there's no separate dark
  /// ramp to maintain.
  final List<Color> categorySwatches;

  // Spacing
  final double spacingXs;
  final double spacingSm;

  /// A standalone 12px value for the timeline task badge's icon top
  /// padding — not part of the general Xs(4)/Sm(8)/Md(16) progression,
  /// which has no rung at 12. Added as its own narrow-purpose token
  /// (mirrors [borderWidthConnector]) rather than restructuring the
  /// shared scale for one call site. Per direct request.
  final double spacingIconTop;
  final double spacingMd;
  final double spacingLg;
  final double spacingXl;
  final double spacingBlockGap;

  /// The app's ONE horizontal side inset — the distance from either
  /// screen edge to the leading edge of a page's own content, on every
  /// screen: the top nav's "Day", the settings gear opposite it, page
  /// titles, list rows, sheet bodies, AND the Timeline's own hour labels
  /// in both the spatial and non-spatial views.
  ///
  /// **16px since 2026-09-21, down from 24px.** Reported directly against
  /// a screenshot with the intended inset marked down both edges: the top
  /// nav and the calendar below it sat further in than the hour labels on
  /// the timeline under them, so the page's left edge visibly stepped as
  /// the eye travelled down. The non-spatial Zone view was named as the
  /// reference ("the right size of it comes from the non-spatial view"),
  /// and its hour label already sat at 16px — so the rest of the app
  /// moves OUT to meet the hour, rather than the hour moving in.
  ///
  /// See docs/DESIGN_SYSTEM.md's "Horizontal spacing" section for the
  /// rule this token anchors, and [spacingTimeColumnWidth] for the
  /// time column it precedes.
  final double spacingScreenPadding;

  /// The Timeline's TIME column width — column 1 of the three-column
  /// layout both Timeline views share (time · zone/pills · content).
  ///
  /// Fixed, and sized for the WIDEST time label either view can render
  /// ("12:00 PM" in the spatial view's hour gutter, "06:40" on a
  /// non-spatial task row), so the gap that follows it lands on
  /// [spacingTimelineGutter] exactly rather than on whatever the current
  /// row's own text happened to measure. A variable-width time column is
  /// what made the time-to-content gap differ per row and per day.
  ///
  /// Excludes the Weekly Zone Authoring Grid, which keeps its own denser
  /// axis — confirmed directly ("edit zone view has its own more dense
  /// space, which is fine, keep it as is").
  final double spacingTimeColumnWidth;

  /// The single gap between every pair of Timeline columns, and between
  /// the outer columns and the screen edge — so edge · time · gap ·
  /// zone · gap · content · edge all read as one rhythm.
  ///
  /// **2026-09-23 — replaces `spacingHourGutter`.** That token was a
  /// frozen `90` documented as "66px gutter + 24px page inset," but
  /// [spacingScreenPadding] had since become 16, so 90 no longer
  /// decomposed into anything real and the two views agreed only by
  /// arithmetic coincidence. Reported directly, repeatedly, against
  /// annotated screenshots, and finally: "can we have literally three
  /// columns of the same size... we would have the same gap between these
  /// columns," with the reasoning that the old structure "would mean
  /// future problems with some other devices and sizes."
  ///
  /// Column 1 starts at [spacingScreenPadding]; the content column's own
  /// left edge is therefore always
  /// `spacingScreenPadding + spacingTimeColumnWidth + spacingTimelineGutter`
  /// — see `timelineContentLeft`, which is the one place that sum lives.
  final double spacingTimelineGutter;

  /// The shared top offset for a scrollable's own first item/pane, under
  /// a fixed heading or [AppTopScrollFade] — one value across Tasks,
  /// Templates, Tracked, and every modal sheet's body, confirmed directly
  /// after "templates are higher" than the other two: "as in templates
  /// current position +30 becomes NEW for all." Not part of the general
  /// Xs/Sm/Md/Lg/Xl progression — a narrow-purpose token for this one
  /// role, matching [spacingIconTop]'s own precedent.
  final double spacingContentTop;

  /// Minimum interactive tap target size (48dp/pt), independent of any
  /// element's own visible size — a visually small control (e.g. the
  /// timeline completion checkbox's 24px ring) still needs a 48px hit
  /// area via invisible padding, per Material Design/WCAG 2.5.8 target-size
  /// guidance. Not part of the general spacing progression; a fixed
  /// accessibility floor, not a design-scale rung.
  final double spacingMinTapTarget;

  /// Minimum height for a form field's filled box.
  ///
  /// Set by design rather than derived from content: a field sized purely
  /// to its text plus padding collapses to a thin strip once the label
  /// floats, which makes a column of fields read as cramped and shrinks
  /// the tap target. Distinct from [spacingMinTapTarget] — that is an
  /// accessibility floor for any control, this is the field's own visual
  /// minimum, and it is deliberately the larger of the two.
  final double sizeMinFieldHeight;

  /// The four fixed rungs of the task-size scale's badge/icon diameter —
  /// the "Task size" Settings toggle (`TaskSizeSetting`, still only 3
  /// options: sm/md/lg) picks a badge/font PAIR from these via
  /// `_resolveTaskSize` in `main.dart`, not necessarily the same-named
  /// font rung. Requested directly: "let's establish this size as sm ...
  /// let's bring md that is slight larger ... previous before this
  /// change was lg" (lg's own value later overridden to 28, not the
  /// original 36, per direct follow-up).
  ///
  /// **Decoupled from `textTaskTitle*` 2026-09-10** (requested directly:
  /// "Current medium size but with font size from small should be
  /// small... Current large but with the font size medium should be
  /// medium... large should be larger task pill but font size same as
  /// medium") — each named `TaskSize` option now pairs a badge rung with
  /// a DIFFERENT font rung, shifted one step apart, rather than the two
  /// always moving in lockstep at the same named rung. See
  /// `_resolveTaskSize`'s own doc comment for the exact pairing table.
  ///
  /// sm ([SpacingPrimitives.space6], 20) is no longer selected by the
  /// setting at all (kept only as the smallest rung, unused above sm's
  /// own font pairing); md ([SpacingPrimitives.space7], 24) is now the
  /// "Small" option's badge; lg ([SpacingPrimitives.space7Point5], 28) is
  /// now the "Medium" option's badge; [sizeTaskBadgeXl]
  /// ([SpacingPrimitives.space8], 32) is new, and is the "Large" option's
  /// badge.
  final double sizeTaskBadgeSm;
  final double sizeTaskBadgeMd;
  final double sizeTaskBadgeLg;
  final double sizeTaskBadgeXl;

  /// The ACTIVE badge/icon diameter — whichever of [sizeTaskBadgeSm]/
  /// [sizeTaskBadgeMd]/[sizeTaskBadgeLg]/[sizeTaskBadgeXl] the "Task
  /// size" setting currently selects. Every real call site
  /// ([TaskCapsuleBlock]'s own pill width, [ZoneContainerBlock]'s row
  /// category-emoji circle, and — indirectly, since it feeds
  /// `_collapsedPixelsPerMinute` — List view's own scale) reads this ONE
  /// resolved value, never the four rungs directly, so a setting change
  /// propagates everywhere without touching a call site. Resolved once in
  /// `main.dart` via `AmbleTheme.copyWith` before the palette reaches
  /// [MaterialApp]'s `extensions`.
  final double sizeTaskBadge;

  /// The button-family height scale — `AppButton`, `AppTabSwitch`, and
  /// `AppConnectedButtons` all pick a rung by their own `size` parameter
  /// (its own enum, not this scale's name directly, mirroring
  /// [AppButtonShape]/[AppButtonVariant]'s own separation of "what the
  /// call site asks for" from "what pixel value that resolves to"). Fixed
  /// design values, unlike [sizeTaskBadge] — there is no user-facing
  /// "Button size" setting, so these are plain constants rather than an
  /// "active" resolved field.
  ///
  /// 44-48px is the standard minimum comfortable tap target (iOS HIG /
  /// Material both land in that range) — [sizeButtonLg] (48) is the
  /// baseline "real tap target" rung; [sizeButtonMd] (40) still clears 40,
  /// the smaller end of what's broadly considered acceptable for a
  /// button that isn't the primary action on a dense row; [sizeButtonXs]/
  /// [sizeButtonSm] are for compact icon-only or inline contexts where the
  /// surrounding row itself is the tap target, not the control alone.
  final double sizeButtonXs;
  final double sizeButtonSm;
  final double sizeButtonMd;
  final double sizeButtonLg;
  final double sizeButtonXl;

  // Radii`
  // Corner radii, named by SIZE rather than by component. A component
  // picks the rung that matches its visual weight, so two unrelated
  // controls that should look alike can't drift apart by being pointed at
  // two differently-named tokens that happen to hold the same number.
  /// 4 — the smallest rounding.
  final double radiusSm;

  /// 8 — form fields, category pills, day chips.
  final double radiusMd;

  /// 12.
  final double radiusLg;

  /// 16 — panes.
  final double radiusXl;

  /// 20 — one rung past [radiusXl], for a zone's own Edit Mode selection
  /// state (`ZoneBackgroundBlock`'s `editModeEnabled` branch), which reads
  /// more rounded than its resting card corner. See
  /// [RadiusPrimitives.radiusXxl]'s own doc comment for why this isn't
  /// [radiusModal] instead.
  final double radiusXxl;

  /// Fully rounded — the timeline task pill and any capsule-shaped
  /// control. Not a rung on the size scale; a shape.
  final double radiusTaskPill;

  /// 8 — the [PillShape.small] rung of the "Pill shape" setting. Matches
  /// Material 3's own named "small" component corner (confirmed via
  /// AskUserQuestion) rather than reusing [radiusSm] (4) unchanged — the
  /// existing hardcoded task/zone badge corner was tighter than any real
  /// design-system's own "small," so this is a deliberate step up, not a
  /// silent no-op default for whoever picks it.
  final double radiusPillSmall;

  /// 16 — the [PillShape.rounded] rung. Matches Material 3's own named
  /// "large" component corner.
  final double radiusPillRounded;

  /// Fully round — the [PillShape.full] rung. Same value as
  /// [radiusTaskPill]/[RadiusPrimitives.radiusFull]; kept as its own named
  /// field (rather than pointing call sites at `radiusTaskPill` directly)
  /// so every pill-shape-aware call site reads one consistent name
  /// regardless of which rung is active.
  final double radiusPillFull;

  /// The ACTIVE pill corner — whichever of [radiusPillSmall]/
  /// [radiusPillRounded]/[radiusPillFull] the "Pill shape" setting
  /// currently selects, resolved once in `main.dart` via `AmbleTheme
  /// .copyWith` before the palette reaches [MaterialApp], mirroring
  /// [sizeTaskBadge]'s own mechanism exactly. Every task/zone/Inbox badge
  /// call site reads THIS field, not the setting itself — see
  /// `PillShapeSetting`'s own doc comment. Requested directly: "we have
  /// squary rounded shape of pills but rounded on inbox ... this should
  /// affect globally, in edit tasks etc."
  final double radiusPill;

  /// 40 — the modal sheet's corner, and only that. Deliberately off the
  /// size scale so it can't be reached for by ordinary cards.
  final double radiusModal;

  /// Hairline stroke/line width — thin connectors, dividers, borders.
  final double borderWidthHairline;

  /// Stroke width for the Timeline's vertical connector line between
  /// consecutive task blocks — deliberately thicker than
  /// [borderWidthHairline] so it reads as a real visual thread through the
  /// day, not an incidental divider. A distinct token per direct request,
  /// not a reuse of the hairline value. See docs/DECISIONS.md.
  final double borderWidthConnector;

  /// Shadow for an element the user has physically picked up — currently
  /// the drag "lift" on a timeline task block.
  ///
  /// A Tier 2 token rather than an inline `BoxShadow` because this is the
  /// second shadow in the app (the task detail sheet's sticky Continue
  /// button is the first), and per design principle 5 a value used twice
  /// gets promoted before a third use appears.
  ///
  /// Deliberately different per palette rather than one shared value:
  /// depth on a near-black surface reads as *darker than the background*,
  /// so the dark variant is pure black at a much higher alpha. Reusing the
  /// light shadow (tinted with the light-mode text colour) would be close
  /// to invisible against `ink900`.
  final List<BoxShadow> shadowLift;

  /// The pane's own quiet elevation — what separates a level-1 pane from
  /// the level-0 ground.
  ///
  /// Carries a boundary the fills alone can't: #F7F7F7 → #FFFFFF is only
  /// ~3% lightness, so without this a pane reads as absent and its fields
  /// look like they float on the page. A shadow rather than a border
  /// because the pane is *raised*, not outlined — and unlike a border it
  /// doesn't add a hard line to every card edge.
  ///
  /// Much lighter than [shadowLift]: that one says "you have picked this
  /// up", this one says "this sits slightly above the page". A negative
  /// spread keeps the shadow tucked under the pane rather than haloing
  /// out around it.
  final List<BoxShadow> shadowPane;

  // Type
  final TextStyle textHeadline;
  final TextStyle textTitle;

  /// **2026-09-21 — DM Sans**, per the dual-font policy: general body
  /// copy, descriptions, category names (via `.copyWith(fontWeight:)` at
  /// call sites — see [textBodyMono]'s own doc comment for the one
  /// exception this token does NOT cover).
  final TextStyle textBody;

  /// The MONOSPACE twin of [textBody] — identical size/weight/height,
  /// [TypePrimitives.fontFamily] instead of [TypePrimitives.fontFamilySans].
  /// Added because [textBody] itself is shared between two kinds of text
  /// that can't share one font: general body copy (→ DM Sans) and two
  /// exception call sites that must stay monospace — the zone-list-row
  /// zone name (`zone_form_screen.dart`) and the Settings app-version
  /// string (`about_settings_screen.dart`). Confirmed via AskUserQuestion:
  /// split into a dedicated token rather than a `.copyWith(fontFamily:)`
  /// override scattered at each exception call site, so the font choice
  /// stays centralized in the token name like every other token here.
  final TextStyle textBodyMono;

  final TextStyle textLabel;

  /// **2026-09-21 — DM Sans**, per the dual-font policy: generic
  /// captions, chip/pill labels, timestamps that read as prose rather
  /// than a raw value. See [textCaptionMono]'s own doc comment for the
  /// exception call sites this token does NOT cover.
  final TextStyle textCaption;

  /// The MONOSPACE twin of [textCaption] — same reasoning as
  /// [textBodyMono]. [textCaption] is shared between generic captions/
  /// chips (→ DM Sans) and genuinely numeric/temporal labels that must
  /// stay monospace: hour-axis labels (`task_boundary_markers.dart`),
  /// current-time text, and other 12px numeric annotations. Compact zone
  /// names and task start/end pills use the dedicated `textZoneName` and
  /// `textTaskEdgeTime` tokens below.
  final TextStyle textCaptionMono;

  /// Compact monospace label used for rotated zone names in spatial/edit
  /// surfaces. It is one rung below [textCaptionMono] so dense vertical
  /// annotations do not compete with task content.
  final TextStyle textZoneName;

  /// Compact monospace time used by [TaskEdgeTimeLabel] across spatial task
  /// and Edit/resize surfaces.
  final TextStyle textTaskEdgeTime;

  /// The three fixed rungs of the task-size scale's own font size —
  /// paired with [sizeTaskBadgeSm]/[sizeTaskBadgeMd]/[sizeTaskBadgeLg]
  /// respectively, so the "Task size" setting moves badge and text
  /// together. sm ([TypePrimitives.size1], 12) is List view's prior fixed
  /// size ([textTaskTitleCompact]'s old value); md ([TypePrimitives.size2],
  /// 14) is Task view's prior fixed size (this token's own old, single
  /// value); lg ([TypePrimitives.size3], 16) is a still-larger rung, not
  /// used as any view's default today. Requested directly, alongside the
  /// badge-size scale: "with that also task name and time font size
  /// changes."
  final TextStyle textTaskTitleSm;
  final TextStyle textTaskTitleMd;
  final TextStyle textTaskTitleLg;

  /// The ACTIVE task-title font — whichever of [textTaskTitleSm]/
  /// [textTaskTitleMd]/[textTaskTitleLg] the "Task size" setting currently
  /// selects. Every real call site (Task view's capsule, List view's own
  /// task/external-event text) reads this ONE resolved value. List view
  /// previously read a separate, always-one-step-smaller
  /// `textTaskTitleCompact` token regardless of Task view's own size;
  /// confirmed directly that List view should now track the SAME global
  /// setting Task view does, with no relative step, so that separate token
  /// is gone — resolved once in `main.dart` via `AmbleTheme.copyWith`,
  /// same mechanism as [sizeTaskBadge].
  ///
  /// **Zone view's own rows/header moved OFF this token 2026-09-12** — see
  /// [textTaskTitleZone] below, which reverses the "no relative step"
  /// decision above specifically for Zone view.
  final TextStyle textTaskTitle;

  /// Zone view's own task-title font — ALWAYS one rung larger than
  /// whichever [textTaskTitleSm]/[textTaskTitleMd]/[textTaskTitleLg] the
  /// active "Task size" setting selects for [textTaskTitle] (sm activates
  /// this to md's size, md to lg's, lg has no larger rung so stays at
  /// lg's own size). Requested directly: "Size of text in zone view (task
  /// name one scale up)." Resolved once in `main.dart`'s
  /// `_resolveTaskSize`, the same mechanism [textTaskTitle] itself uses —
  /// every zone-view row/header reads this instead now.
  ///
  /// **2026-09-21 — stays [TypePrimitives.fontFamily] (monospace)**, the
  /// one explicit carve-out in the dual-font policy: this is the zone
  /// container's own header/name, which would otherwise read as an
  /// ordinary title (→ DM Sans) but must stay monospace. Its only real
  /// call site (`zone_container_block.dart`) renders nothing but a zone
  /// name, so this token is pinned wholesale rather than split.
  final TextStyle textTaskTitleZone;

  // Motion
  final Duration motionFast;
  final Duration motionNormal;
  final Duration motionSlow;

  /// How long to wait for a dismissed full-screen route to finish sliding
  /// away before starting an animation on the screen it uncovers.
  ///
  /// Exists because an animation triggered at save time plays entirely
  /// BEHIND the closing modal and is over before the user can see the
  /// timeline at all — reported directly ("no se already placed or
  /// extended"). Slightly longer than Flutter's own 300ms default
  /// `PageRoute` transition, so the reveal starts on a clear screen
  /// rather than racing the last frames of the dismissal.
  final Duration motionRouteSettle;

  /// [AppSheet]'s own slide-in/out duration. See
  /// [MotionPrimitives.durationSheetSlideMs]'s own doc comment.
  final Duration motionSheetSlide;

  /// Keyboard-mode barrier duration and unmeasured-platform grace period.
  /// Android sheet motion itself follows native IME progress.
  /// See [MotionPrimitives.durationKeyboardSettleMs].
  final Duration motionKeyboardSettle;
  final Curve curveStandard;

  /// Starts at full speed and eases to a stop — no slow ramp-in. For
  /// motion that should feel like it has already begun by the time the
  /// user perceives it, which is what makes a sheet entrance read as
  /// immediate rather than as something winding up. Promoted from
  /// [MotionPrimitives.curveDecelerate], which Tier 1 has always defined
  /// but Tier 2 never exposed.
  final Curve curveDecelerate;

  static final light = AmbleTheme(
    // **2026-09-20 — the app's own "website Paper" background.** Re-
    // pointed from `cream0`, then from an intermediate `surface0`
    // attempt, to this NEW anchor — confirmed directly: "keep the
    // website's warm paper background... it feels more like Panta than
    // the cooler grey I proposed."
    colorSurfaceBase: ColorPrimitives.paper,
    // Cards/content surfaces — confirmed directly, choosing `cream2` over
    // a `surface1` (pure white) attempt specifically because pure white
    // collided with `colorSurfaceOverlay` below (also pure white,
    // required so the floating overlay reads as the topmost layer) —
    // see `elevation_direction_test.dart`. `cream2` sits one genuine step
    // lighter than `paper`, preserving the base->card->overlay ordering
    // that test enforces.
    colorSurfacePrimary: ColorPrimitives.cream2,
    // Light mode's base is already near the top of the ramp, so an
    // overlay can't separate by getting lighter in any meaningful way —
    // it goes pure white and relies on `colorBorder`/`shadowPane` for its
    // edge, confirmed directly: "reserve white for floating chrome, and
    // use a fine border on cards plus a soft shadow beneath floating
    // controls."
    colorSurfaceOverlay: ColorPrimitives.creamOverlay,
    // A nested row/card (e.g. a Manage-screen list row) — one step
    // DARKER than `colorSurfacePrimary` (`cream2`) as of 2026-09-20,
    // reversed from the previous "one step lighter" direction: `cream2`
    // is now the lightest Cream step below pure white (reserved for the
    // overlay), leaving no room for a nested row to go lighter still.
    // Confirmed directly: a subtle darker inset reads as content nested
    // INSIDE a card, the same "recessed" cue a text field already uses.
    colorSurfaceSecondary: ColorPrimitives.cream1,
    // Tracks `colorSurfacePrimary` — this token has mirrored that one 1:1
    // since 2026-09-12, and nothing in the 2026-09-20 pass named a
    // separate role for it.
    colorSurfaceTimeline: ColorPrimitives.cream2,
    colorSurfaceField: ColorPrimitives.surface2,
    colorSurfaceFieldActive: ColorPrimitives.surface3,
    colorScrim: const Color(0x66000000),
    // 36% opacity of the pane fill itself (colorSurfacePrimary's own
    // primitive), not a separate hardcoded value.
    colorSurfaceBlurOverlay: ColorPrimitives.cream2.withValues(alpha: 0.36),
    blurOverlaySigma: 12.0,
    // Same primitive as colorBorder below (surface3), at low alpha — kept
    // as a literal primitive reference rather than colorBorder.withValues
    // since these are compile-time const field initializers and colorBorder
    // isn't assigned yet at this point in the constructor call.
    colorFreeWindow: ColorPrimitives.surface3.withValues(alpha: 0.5),
    colorZoneBackground: ColorPrimitives.zoneBackground,
    colorTextPrimary: ColorPrimitives.slate900,
    colorTextSecondary: ColorPrimitives.slate500,
    colorTextTertiary: ColorPrimitives.slate400,
    // **2026-09-20 — re-pointed from `sand300` to `surface3`.** Confirmed
    // directly: "card borders" is `surface3`'s own named role in the
    // confirmed layering — "use a fine border on cards... to create
    // separation without making the whole interface darker."
    colorBorder: ColorPrimitives.surface3,
    colorAccent: ColorPrimitives.brand500,
    // Stays sage, deliberately: green reads as "done" independently of
    // branding, so the accent swap must not drag task status with it.
    colorTaskCompleted: ColorPrimitives.sage500,
    colorTaskSkipped: ColorPrimitives.slate300,
    colorTaskAlert: ColorPrimitives.coral500,
    categoryColors: {
      TaskCategoryToken.general: ColorPrimitives.neutralTint,
      TaskCategoryToken.health: ColorPrimitives.clayTint,
      TaskCategoryToken.work: ColorPrimitives.ochreTint,
      TaskCategoryToken.home: ColorPrimitives.periwinkleTint,
      TaskCategoryToken.personal: ColorPrimitives.amberTint,
      TaskCategoryToken.social: ColorPrimitives.tealTint,
      TaskCategoryToken.reading: ColorPrimitives.skyTint,
      TaskCategoryToken.learning: ColorPrimitives.roseTint,
      TaskCategoryToken.admin: ColorPrimitives.berryTint,
    },
    categoryIconColors: {
      TaskCategoryToken.general: ColorPrimitives.neutral500,
      TaskCategoryToken.health: ColorPrimitives.clay500,
      TaskCategoryToken.work: ColorPrimitives.ochre500,
      TaskCategoryToken.home: ColorPrimitives.periwinkle500,
      TaskCategoryToken.personal: ColorPrimitives.amber500,
      TaskCategoryToken.social: ColorPrimitives.teal500,
      TaskCategoryToken.reading: ColorPrimitives.sky500,
      TaskCategoryToken.learning: ColorPrimitives.rose500,
      TaskCategoryToken.admin: ColorPrimitives.berry500,
    },
    // The LIGHT ramp, not the shared one this used to point at: the dark
    // ramp measures 3.08-3.66:1 against `surface0`, failing AA at every
    // hue. Same 12 hues in the same order, so a stored
    // `Category.colorToken` index is unaffected by the switch.
    categorySwatches: ColorPrimitives.categoryPalette12Light,
    spacingXs: SpacingPrimitives.space2,
    spacingSm: SpacingPrimitives.space3,
    spacingIconTop: SpacingPrimitives.space4,
    spacingMd: SpacingPrimitives.space5,
    spacingLg: SpacingPrimitives.space7,
    spacingXl: SpacingPrimitives.space9,
    spacingBlockGap: SpacingPrimitives.space3,
    spacingScreenPadding: SpacingPrimitives.space5,
    spacingTimeColumnWidth: SpacingPrimitives.space12,
    spacingTimelineGutter: SpacingPrimitives.space5,
    spacingContentTop: SpacingPrimitives.space7Point75,
    spacingMinTapTarget: 48.0,
    sizeMinFieldHeight: 60.0,
    sizeTaskBadgeSm: SpacingPrimitives.space6,
    sizeTaskBadgeMd: SpacingPrimitives.space7,
    sizeTaskBadgeLg: SpacingPrimitives.space7Point5,
    sizeTaskBadgeXl: SpacingPrimitives.space8,
    // Default rung: md — Task view's own prior fixed size, now the
    // starting point for the "Task size" setting.
    sizeTaskBadge: SpacingPrimitives.space7,
    sizeButtonXs: SpacingPrimitives.space7Point5,
    sizeButtonSm: SpacingPrimitives.space8,
    sizeButtonMd: SpacingPrimitives.space9,
    sizeButtonLg: SpacingPrimitives.space9Point5,
    sizeButtonXl: SpacingPrimitives.space10,
    radiusSm: RadiusPrimitives.radiusSm,
    radiusMd: RadiusPrimitives.radiusMd,
    radiusLg: RadiusPrimitives.radiusLg,
    radiusXl: RadiusPrimitives.radiusXl,
    radiusXxl: RadiusPrimitives.radiusXxl,
    radiusTaskPill: RadiusPrimitives.radiusFull,
    // Reuses the existing radiusMd(8)/radiusXl(16) primitives rather than
    // new literals — they already sit at exactly the Material 3
    // small/large values this setting's rungs were chosen to match.
    radiusPillSmall: RadiusPrimitives.radiusMd,
    radiusPillRounded: RadiusPrimitives.radiusXl,
    radiusPillFull: RadiusPrimitives.radiusFull,
    // Default rung: PillShapeSetting.build() defaults to PillShape.full —
    // requested directly ("all buttons and other related should be fully
    // rounded"), main.dart's _resolvePillShape overrides this at runtime
    // for the real app; this const just keeps a bare AmbleTheme.light
    // (tests, the Widgetbook gallery) matching that same real default.
    radiusPill: RadiusPrimitives.radiusFull,
    radiusModal: RadiusPrimitives.radiusModal,
    borderWidthHairline: SpacingPrimitives.space1,
    borderWidthConnector: 3.0,
    // Light: a soft, generous shadow in the ink colour. Larger blur and
    // offset than the Continue button's (spacingMd/spacingXs) — a lifted
    // element should read as clearly nearer the user, not subtly raised.
    shadowPane: [
      BoxShadow(
        color: ColorPrimitives.black.withValues(alpha: 0.08),
        offset: const Offset(0, 2),
        blurRadius: 4,
        spreadRadius: -2,
      ),
    ],
    shadowLift: [
      // Two layers, the standard way to make a large shadow read as depth
      // rather than as a grey haze: a tight, darker contact shadow anchors
      // the element to the surface, and a wide, softer ambient shadow gives
      // the sense of height. A single 40px/22% shadow was measured on-device
      // and was almost invisible — the alpha spread that far just washes
      // out against `sand50`.
      BoxShadow(
        color: ColorPrimitives.slate900.withValues(alpha: 0.30),
        blurRadius: SpacingPrimitives.space4,
        offset: const Offset(0, SpacingPrimitives.space2),
      ),
      BoxShadow(
        color: ColorPrimitives.slate900.withValues(alpha: 0.22),
        blurRadius: SpacingPrimitives.space9,
        offset: const Offset(0, SpacingPrimitives.space5),
      ),
    ],
    textHeadline: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size6,
      fontWeight: TypePrimitives.weightBold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.slate900,
    ),
    textTitle: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size4,
      fontWeight: TypePrimitives.weightSemibold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.slate900,
    ),
    textBody: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size3,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate900,
    ),
    // See textBodyMono's own doc comment — identical to textBody above,
    // monospace instead of sans.
    textBodyMono: TextStyle(
      fontFamily: TypePrimitives.fontFamily,
      fontSize: TypePrimitives.size3,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate900,
    ),
    textLabel: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size2,
      fontWeight: TypePrimitives.weightMedium,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate700,
    ),
    textCaption: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate500,
    ),
    // See textCaptionMono's own doc comment — identical to textCaption
    // above, monospace instead of sans.
    textCaptionMono: TextStyle(
      fontFamily: TypePrimitives.fontFamily,
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate500,
    ),
    textZoneName: TextStyle(
      fontFamily: TypePrimitives.fontFamily,
      fontSize: TypePrimitives.size0,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate500,
    ),
    textTaskEdgeTime: TextStyle(
      fontFamily: TypePrimitives.fontFamily,
      fontSize: TypePrimitives.size0,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate900,
    ),
    // Same fontSize/weight/height as textLabel — the zone header's prior
    // size, now the shared task-title base — but under its own semantic
    // name so a future change to textLabel's more generic meaning can't
    // silently also move every task title. Color left to call sites via
    // .copyWith (they already vary: primary for a task's own title,
    // secondary for its time line), matching every other text token here.
    // **2026-09-12 — each rung shifted one step down the type scale.**
    // Requested directly: "zone names and task names (across 3 different
    // size settings) reduce 1 scale down." sm/md/lg were size1/size2/size3
    // (12/14/16); now size0/size1/size2 (11/12/14) — see TypePrimitives'
    // own comment for why the sm step is 1px rather than the usual 2.
    // `_resolveTaskSize` (main.dart) no longer needs to make `lg` reuse
    // `textTaskTitleMd` to keep its font at 14 — `textTaskTitleLg` now
    // naturally lands there on its own, confirmed directly (lg should get
    // its own genuine one-step reduction, not stay paired with md).
    textTaskTitleSm: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size0,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate900,
    ),
    textTaskTitleMd: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate900,
    ),
    textTaskTitleLg: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size2,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate900,
    ),
    // Default rung: md — Task view's own prior fixed size, now the
    // starting point for the "Task size" setting (see sizeTaskBadge's own
    // matching default comment).
    textTaskTitle: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate900,
    ),
    // Default rung: one up from md (see textTaskTitle's own default
    // comment) — lg's own size, matching main.dart's _resolveTaskSize
    // "one step up" mapping. fontFamily stays monospace — see this
    // field's own doc comment on the dual-font policy's zone-name
    // carve-out.
    textTaskTitleZone: TextStyle(
      fontFamily: TypePrimitives.fontFamily,
      fontSize: TypePrimitives.size2,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate900,
    ),
    motionFast: const Duration(milliseconds: MotionPrimitives.durationFastMs),
    motionNormal: const Duration(
      milliseconds: MotionPrimitives.durationNormalMs,
    ),
    motionSlow: const Duration(milliseconds: MotionPrimitives.durationSlowMs),
    motionRouteSettle: const Duration(
      milliseconds: MotionPrimitives.durationRouteSettleMs,
    ),
    motionSheetSlide: const Duration(
      milliseconds: MotionPrimitives.durationSheetSlideMs,
    ),
    motionKeyboardSettle: const Duration(
      milliseconds: MotionPrimitives.durationKeyboardSettleMs,
    ),
    curveStandard: const Cubic(0.4, 0.0, 0.2, 1.0),
    // Mirrors MotionPrimitives.curveDecelerate's control points. Spelled
    // out rather than read from the record: Tier 1 stores them as a
    // plain tuple (it must stay Flutter-free, so it can't hold a Curve),
    // and record fields aren't accessible in a const expression — the
    // same reason curveStandard above is also written out longhand.
    curveDecelerate: const Cubic(0.0, 0.0, 0.2, 1.0),
  );

  /// First-pass dark palette (Phase 13a). Surfaces/text/border are derived
  /// from the `ink`/`sand` OKLCH ramps rather than inverted from light —
  /// see docs/DECISIONS.md. Category accents are deliberately unchanged
  /// from light: measured at 4.9–5.2:1 against `ink900`, with white glyphs
  /// at 3.6–3.8:1 on the pills, so they hold up without a dark-specific
  /// variant. Flagged as first-pass pending visual review (Phase 13b).
  static final dark = AmbleTheme(
    // **Un-inverted 2026-09-12.** These two were the wrong way round:
    // `ink900` (the DEEPEST surface, and the directly-specified #121110
    // body color) was the raised pane while the lighter `ink800` was the
    // ground behind it. That only went unnoticed because the scaffold
    // painted `colorSurfacePrimary` rather than the base — once the
    // scaffold correctly paints level 0, the base has to actually be the
    // darkest step or the whole elevation ramp runs backwards.
    colorSurfaceBase: ColorPrimitives.ink900,
    colorSurfacePrimary: ColorPrimitives.ink800,
    // The lightest surface in the dark ramp — see the field's own doc
    // comment. Its own rung (`ink650`), not `ink700`: the nav pane sits
    // one step above the raised panels it floats over.
    colorSurfaceOverlay: ColorPrimitives.ink650,
    colorSurfaceSecondary: ColorPrimitives.ink700,
    colorSurfaceTimeline: ColorPrimitives.ink800,
    colorSurfaceField: ColorPrimitives.inkField,
    colorSurfaceFieldActive: ColorPrimitives.inkFieldActive,
    colorScrim: const Color(0x66000000),
    // Same reasoning as light — 36% of dark mode's own pane fill (ink900).
    colorSurfaceBlurOverlay: ColorPrimitives.ink900.withValues(alpha: 0.36),
    blurOverlaySigma: 12.0,
    // Same primitive as colorBorder below (ink600), at low alpha — same
    // reasoning as the light palette above.
    colorFreeWindow: ColorPrimitives.ink600.withValues(alpha: 0.5),
    colorZoneBackground: ColorPrimitives.zoneBackgroundDark,
    colorTextPrimary: ColorPrimitives.sand200,
    colorTextSecondary: ColorPrimitives.sand400,
    colorTextTertiary: ColorPrimitives.sand350,
    colorBorder: ColorPrimitives.ink600,
    colorAccent: ColorPrimitives.brand300,
    // See the light palette — status green is not part of the accent role.
    colorTaskCompleted: ColorPrimitives.sage300,
    colorTaskSkipped: ColorPrimitives.slate500,
    colorTaskAlert: ColorPrimitives.coral300,
    // Category pill fill: unchanged pre-pastel mid-tone values (see
    // ColorPrimitives' *Dark entries) — dark mode is explicitly out of
    // scope for the pastel-palette session that touched light mode, so
    // this stays byte-for-byte identical to Phase 13a, measured at
    // 4.9-5.2:1 against `ink900`.
    categoryColors: {
      TaskCategoryToken.general: ColorPrimitives.neutral500Dark,
      TaskCategoryToken.health: ColorPrimitives.clay500Dark,
      TaskCategoryToken.work: ColorPrimitives.ochre500Dark,
      TaskCategoryToken.home: ColorPrimitives.periwinkle500Dark,
      TaskCategoryToken.personal: ColorPrimitives.amber500Dark,
      TaskCategoryToken.social: ColorPrimitives.teal500Dark,
      TaskCategoryToken.reading: ColorPrimitives.sky500Dark,
      TaskCategoryToken.learning: ColorPrimitives.rose500Dark,
      TaskCategoryToken.admin: ColorPrimitives.berry500Dark,
    },
    // Category icon glyph: real bug, found and fixed via the splash/
    // carousel session, not left as pre-existing. When categoryIconColors
    // was introduced (pastel-palette session) this map was set to mirror
    // categoryColors under the reasoning "dark mode never had a separate
    // icon treatment" — true of the OLD code path (TaskCapsuleBlock read
    // colorSurfacePrimary, which happened to be white in light mode), but
    // that session's TaskCapsuleBlock rewrite made iconColor read
    // categoryIconColors unconditionally in BOTH palettes, so mirroring
    // categoryColors here means the icon is drawn in the exact color of
    // its own background — invisible. Fixed to pure white, the actual
    // pre-pastel-session value (colorSurfacePrimary was white in light
    // mode, not "surface primary" in any meaningful sense for this use —
    // dark mode's colorSurfacePrimary is near-black ink900, the wrong
    // direction entirely). Verified 3.56-3.83:1 white-on-category-color,
    // clearing the 3:1 WCAG graphics floor — matches Phase 13a's own
    // originally-measured 3.6-3.8:1 figure. See docs/DECISIONS.md.
    categoryIconColors: {
      TaskCategoryToken.general: ColorPrimitives.white,
      TaskCategoryToken.health: ColorPrimitives.white,
      TaskCategoryToken.work: ColorPrimitives.white,
      TaskCategoryToken.home: ColorPrimitives.white,
      TaskCategoryToken.personal: ColorPrimitives.white,
      TaskCategoryToken.social: ColorPrimitives.white,
      TaskCategoryToken.reading: ColorPrimitives.white,
      TaskCategoryToken.learning: ColorPrimitives.white,
      TaskCategoryToken.admin: ColorPrimitives.white,
    },
    // Same 12-swatch list as the light palette — deliberately not a
    // separate dark-mode set, see the field's own doc comment above.
    categorySwatches: ColorPrimitives.categoryPalette12,
    spacingXs: SpacingPrimitives.space2,
    spacingSm: SpacingPrimitives.space3,
    spacingIconTop: SpacingPrimitives.space4,
    spacingMd: SpacingPrimitives.space5,
    spacingLg: SpacingPrimitives.space7,
    spacingXl: SpacingPrimitives.space9,
    spacingBlockGap: SpacingPrimitives.space3,
    spacingScreenPadding: SpacingPrimitives.space5,
    spacingTimeColumnWidth: SpacingPrimitives.space12,
    spacingTimelineGutter: SpacingPrimitives.space5,
    spacingContentTop: SpacingPrimitives.space7Point75,
    spacingMinTapTarget: 48.0,
    sizeMinFieldHeight: 60.0,
    sizeTaskBadgeSm: SpacingPrimitives.space6,
    sizeTaskBadgeMd: SpacingPrimitives.space7,
    sizeTaskBadgeLg: SpacingPrimitives.space7Point5,
    sizeTaskBadgeXl: SpacingPrimitives.space8,
    // Default rung: md — Task view's own prior fixed size, now the
    // starting point for the "Task size" setting.
    sizeTaskBadge: SpacingPrimitives.space7,
    sizeButtonXs: SpacingPrimitives.space7Point5,
    sizeButtonSm: SpacingPrimitives.space8,
    sizeButtonMd: SpacingPrimitives.space9,
    sizeButtonLg: SpacingPrimitives.space9Point5,
    sizeButtonXl: SpacingPrimitives.space10,
    radiusSm: RadiusPrimitives.radiusSm,
    radiusMd: RadiusPrimitives.radiusMd,
    radiusLg: RadiusPrimitives.radiusLg,
    radiusXl: RadiusPrimitives.radiusXl,
    radiusXxl: RadiusPrimitives.radiusXxl,
    radiusTaskPill: RadiusPrimitives.radiusFull,
    radiusPillSmall: RadiusPrimitives.radiusMd,
    radiusPillRounded: RadiusPrimitives.radiusXl,
    radiusPillFull: RadiusPrimitives.radiusFull,
    // Same default-rung reasoning as the light palette's own comment above.
    radiusPill: RadiusPrimitives.radiusFull,
    radiusModal: RadiusPrimitives.radiusModal,
    borderWidthHairline: SpacingPrimitives.space1,
    borderWidthConnector: 3.0,
    // Dark: pure black at high alpha. Depth on a near-black surface comes
    // from being *darker* than the background, so a shadow tinted with the
    // light text colour would be invisible here — see docs/DECISIONS.md.
    shadowPane: [
      // Same geometry, deeper alpha: on a near-black ground an 8% shadow
      // is invisible, so dark mode carries the same separation at a
      // strength that actually registers against `ink900`.
      BoxShadow(
        color: ColorPrimitives.black.withValues(alpha: 0.40),
        offset: const Offset(0, 2),
        blurRadius: 4,
        spreadRadius: -2,
      ),
    ],
    shadowLift: [
      // Same two-layer structure as light, at higher alpha — see that
      // palette's comment. Depth on a near-black surface has to come from
      // something darker than the background, so both layers are pure black.
      BoxShadow(
        color: ColorPrimitives.black.withValues(alpha: 0.60),
        blurRadius: SpacingPrimitives.space4,
        offset: const Offset(0, SpacingPrimitives.space2),
      ),
      BoxShadow(
        color: ColorPrimitives.black.withValues(alpha: 0.45),
        blurRadius: SpacingPrimitives.space9,
        offset: const Offset(0, SpacingPrimitives.space5),
      ),
    ],
    textHeadline: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size6,
      fontWeight: TypePrimitives.weightBold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.sand200,
    ),
    textTitle: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size4,
      fontWeight: TypePrimitives.weightSemibold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.sand200,
    ),
    textBody: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size3,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand200,
    ),
    // See textBodyMono's own doc comment — identical to textBody above,
    // monospace instead of sans.
    textBodyMono: TextStyle(
      fontFamily: TypePrimitives.fontFamily,
      fontSize: TypePrimitives.size3,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand200,
    ),
    textLabel: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size2,
      fontWeight: TypePrimitives.weightMedium,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand400,
    ),
    textCaption: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand400,
    ),
    // See textCaptionMono's own doc comment — identical to textCaption
    // above, monospace instead of sans.
    textCaptionMono: TextStyle(
      fontFamily: TypePrimitives.fontFamily,
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand400,
    ),
    textZoneName: TextStyle(
      fontFamily: TypePrimitives.fontFamily,
      fontSize: TypePrimitives.size0,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand400,
    ),
    textTaskEdgeTime: TextStyle(
      fontFamily: TypePrimitives.fontFamily,
      fontSize: TypePrimitives.size0,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand200,
    ),
    // Each rung shifted one step down the type scale — see the light
    // palette's identical comment above for the full reasoning.
    textTaskTitleSm: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size0,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand200,
    ),
    textTaskTitleMd: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand200,
    ),
    textTaskTitleLg: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size2,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand200,
    ),
    // Default rung: md — Task view's own prior fixed size, now the
    // starting point for the "Task size" setting (see sizeTaskBadge's own
    // matching default comment).
    textTaskTitle: TextStyle(
      fontFamily: TypePrimitives.fontFamilySans,
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand200,
    ),
    // One up from md — see the light palette's identical comment above.
    // fontFamily stays monospace — see this field's own doc comment on
    // the dual-font policy's zone-name carve-out.
    textTaskTitleZone: TextStyle(
      fontFamily: TypePrimitives.fontFamily,
      fontSize: TypePrimitives.size2,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand200,
    ),
    motionFast: const Duration(milliseconds: MotionPrimitives.durationFastMs),
    motionNormal: const Duration(
      milliseconds: MotionPrimitives.durationNormalMs,
    ),
    motionSlow: const Duration(milliseconds: MotionPrimitives.durationSlowMs),
    motionRouteSettle: const Duration(
      milliseconds: MotionPrimitives.durationRouteSettleMs,
    ),
    motionSheetSlide: const Duration(
      milliseconds: MotionPrimitives.durationSheetSlideMs,
    ),
    motionKeyboardSettle: const Duration(
      milliseconds: MotionPrimitives.durationKeyboardSettleMs,
    ),
    curveStandard: const Cubic(0.4, 0.0, 0.2, 1.0),
    // Mirrors MotionPrimitives.curveDecelerate's control points. Spelled
    // out rather than read from the record: Tier 1 stores them as a
    // plain tuple (it must stay Flutter-free, so it can't hold a Curve),
    // and record fields aren't accessible in a const expression — the
    // same reason curveStandard above is also written out longhand.
    curveDecelerate: const Cubic(0.0, 0.0, 0.2, 1.0),
  );

  @override
  AmbleTheme copyWith({
    Color? colorSurfaceBase,
    Color? colorSurfacePrimary,
    Color? colorSurfaceSecondary,
    Color? colorSurfaceOverlay,
    Color? colorSurfaceTimeline,
    Color? colorSurfaceField,
    Color? colorSurfaceFieldActive,
    Color? colorScrim,
    Color? colorSurfaceBlurOverlay,
    double? blurOverlaySigma,
    Color? colorFreeWindow,
    Color? colorZoneBackground,
    Color? colorTextPrimary,
    Color? colorTextSecondary,
    Color? colorTextTertiary,
    Color? colorBorder,
    Color? colorAccent,
    Color? colorTaskCompleted,
    Color? colorTaskSkipped,
    Color? colorTaskAlert,
    Map<TaskCategoryToken, Color>? categoryColors,
    Map<TaskCategoryToken, Color>? categoryIconColors,
    List<Color>? categorySwatches,
    double? spacingXs,
    double? spacingSm,
    double? spacingIconTop,
    double? spacingMd,
    double? spacingLg,
    double? spacingXl,
    double? spacingBlockGap,
    double? spacingScreenPadding,
    double? spacingTimeColumnWidth,
    double? spacingTimelineGutter,
    double? spacingContentTop,
    double? spacingMinTapTarget,
    double? sizeMinFieldHeight,
    double? sizeTaskBadgeSm,
    double? sizeTaskBadgeMd,
    double? sizeTaskBadgeLg,
    double? sizeTaskBadgeXl,
    double? sizeTaskBadge,
    double? sizeButtonXs,
    double? sizeButtonSm,
    double? sizeButtonMd,
    double? sizeButtonLg,
    double? sizeButtonXl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusXxl,
    double? radiusTaskPill,
    double? radiusPillSmall,
    double? radiusPillRounded,
    double? radiusPillFull,
    double? radiusPill,
    double? radiusModal,
    double? borderWidthHairline,
    double? borderWidthConnector,
    List<BoxShadow>? shadowLift,
    List<BoxShadow>? shadowPane,
    TextStyle? textHeadline,
    TextStyle? textTitle,
    TextStyle? textBody,
    TextStyle? textBodyMono,
    TextStyle? textLabel,
    TextStyle? textCaption,
    TextStyle? textCaptionMono,
    TextStyle? textZoneName,
    TextStyle? textTaskEdgeTime,
    TextStyle? textTaskTitleSm,
    TextStyle? textTaskTitleMd,
    TextStyle? textTaskTitleLg,
    TextStyle? textTaskTitle,
    TextStyle? textTaskTitleZone,
    Duration? motionFast,
    Duration? motionNormal,
    Duration? motionSlow,
    Duration? motionRouteSettle,
    Duration? motionSheetSlide,
    Duration? motionKeyboardSettle,
    Curve? curveStandard,
    Curve? curveDecelerate,
  }) {
    return AmbleTheme(
      colorSurfaceBase: colorSurfaceBase ?? this.colorSurfaceBase,
      colorSurfacePrimary: colorSurfacePrimary ?? this.colorSurfacePrimary,
      colorSurfaceSecondary:
          colorSurfaceSecondary ?? this.colorSurfaceSecondary,
      colorSurfaceOverlay: colorSurfaceOverlay ?? this.colorSurfaceOverlay,
      colorSurfaceTimeline: colorSurfaceTimeline ?? this.colorSurfaceTimeline,
      colorSurfaceField: colorSurfaceField ?? this.colorSurfaceField,
      colorSurfaceFieldActive:
          colorSurfaceFieldActive ?? this.colorSurfaceFieldActive,
      colorScrim: colorScrim ?? this.colorScrim,
      colorSurfaceBlurOverlay:
          colorSurfaceBlurOverlay ?? this.colorSurfaceBlurOverlay,
      blurOverlaySigma: blurOverlaySigma ?? this.blurOverlaySigma,
      colorFreeWindow: colorFreeWindow ?? this.colorFreeWindow,
      colorZoneBackground: colorZoneBackground ?? this.colorZoneBackground,
      colorTextPrimary: colorTextPrimary ?? this.colorTextPrimary,
      colorTextSecondary: colorTextSecondary ?? this.colorTextSecondary,
      colorTextTertiary: colorTextTertiary ?? this.colorTextTertiary,
      colorBorder: colorBorder ?? this.colorBorder,
      colorAccent: colorAccent ?? this.colorAccent,
      colorTaskCompleted: colorTaskCompleted ?? this.colorTaskCompleted,
      colorTaskSkipped: colorTaskSkipped ?? this.colorTaskSkipped,
      colorTaskAlert: colorTaskAlert ?? this.colorTaskAlert,
      categoryColors: categoryColors ?? this.categoryColors,
      categoryIconColors: categoryIconColors ?? this.categoryIconColors,
      categorySwatches: categorySwatches ?? this.categorySwatches,
      spacingXs: spacingXs ?? this.spacingXs,
      spacingSm: spacingSm ?? this.spacingSm,
      spacingIconTop: spacingIconTop ?? this.spacingIconTop,
      spacingMd: spacingMd ?? this.spacingMd,
      spacingLg: spacingLg ?? this.spacingLg,
      spacingXl: spacingXl ?? this.spacingXl,
      spacingBlockGap: spacingBlockGap ?? this.spacingBlockGap,
      spacingScreenPadding: spacingScreenPadding ?? this.spacingScreenPadding,
      spacingTimeColumnWidth:
          spacingTimeColumnWidth ?? this.spacingTimeColumnWidth,
      spacingTimelineGutter:
          spacingTimelineGutter ?? this.spacingTimelineGutter,
      spacingContentTop: spacingContentTop ?? this.spacingContentTop,
      spacingMinTapTarget: spacingMinTapTarget ?? this.spacingMinTapTarget,
      sizeMinFieldHeight: sizeMinFieldHeight ?? this.sizeMinFieldHeight,
      sizeTaskBadgeSm: sizeTaskBadgeSm ?? this.sizeTaskBadgeSm,
      sizeTaskBadgeMd: sizeTaskBadgeMd ?? this.sizeTaskBadgeMd,
      sizeTaskBadgeLg: sizeTaskBadgeLg ?? this.sizeTaskBadgeLg,
      sizeTaskBadgeXl: sizeTaskBadgeXl ?? this.sizeTaskBadgeXl,
      sizeTaskBadge: sizeTaskBadge ?? this.sizeTaskBadge,
      sizeButtonXs: sizeButtonXs ?? this.sizeButtonXs,
      sizeButtonSm: sizeButtonSm ?? this.sizeButtonSm,
      sizeButtonMd: sizeButtonMd ?? this.sizeButtonMd,
      sizeButtonLg: sizeButtonLg ?? this.sizeButtonLg,
      sizeButtonXl: sizeButtonXl ?? this.sizeButtonXl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusXxl: radiusXxl ?? this.radiusXxl,
      radiusTaskPill: radiusTaskPill ?? this.radiusTaskPill,
      radiusPillSmall: radiusPillSmall ?? this.radiusPillSmall,
      radiusPillRounded: radiusPillRounded ?? this.radiusPillRounded,
      radiusPillFull: radiusPillFull ?? this.radiusPillFull,
      radiusPill: radiusPill ?? this.radiusPill,
      radiusModal: radiusModal ?? this.radiusModal,
      borderWidthHairline: borderWidthHairline ?? this.borderWidthHairline,
      borderWidthConnector: borderWidthConnector ?? this.borderWidthConnector,
      shadowLift: shadowLift ?? this.shadowLift,
      shadowPane: shadowPane ?? this.shadowPane,
      textHeadline: textHeadline ?? this.textHeadline,
      textTitle: textTitle ?? this.textTitle,
      textBody: textBody ?? this.textBody,
      textBodyMono: textBodyMono ?? this.textBodyMono,
      textLabel: textLabel ?? this.textLabel,
      textCaption: textCaption ?? this.textCaption,
      textCaptionMono: textCaptionMono ?? this.textCaptionMono,
      textZoneName: textZoneName ?? this.textZoneName,
      textTaskEdgeTime: textTaskEdgeTime ?? this.textTaskEdgeTime,
      textTaskTitleSm: textTaskTitleSm ?? this.textTaskTitleSm,
      textTaskTitleMd: textTaskTitleMd ?? this.textTaskTitleMd,
      textTaskTitleLg: textTaskTitleLg ?? this.textTaskTitleLg,
      textTaskTitle: textTaskTitle ?? this.textTaskTitle,
      textTaskTitleZone: textTaskTitleZone ?? this.textTaskTitleZone,
      motionFast: motionFast ?? this.motionFast,
      motionNormal: motionNormal ?? this.motionNormal,
      motionSlow: motionSlow ?? this.motionSlow,
      motionRouteSettle: motionRouteSettle ?? this.motionRouteSettle,
      motionSheetSlide: motionSheetSlide ?? this.motionSheetSlide,
      motionKeyboardSettle: motionKeyboardSettle ?? this.motionKeyboardSettle,
      curveStandard: curveStandard ?? this.curveStandard,
      curveDecelerate: curveDecelerate ?? this.curveDecelerate,
    );
  }

  @override
  AmbleTheme lerp(ThemeExtension<AmbleTheme>? other, double t) {
    if (other is! AmbleTheme) return this;
    return AmbleTheme(
      colorSurfaceBase: Color.lerp(
        colorSurfaceBase,
        other.colorSurfaceBase,
        t,
      )!,
      colorSurfacePrimary: Color.lerp(
        colorSurfacePrimary,
        other.colorSurfacePrimary,
        t,
      )!,
      colorSurfaceSecondary: Color.lerp(
        colorSurfaceSecondary,
        other.colorSurfaceSecondary,
        t,
      )!,
      colorSurfaceOverlay: Color.lerp(
        colorSurfaceOverlay,
        other.colorSurfaceOverlay,
        t,
      )!,
      colorSurfaceTimeline: Color.lerp(
        colorSurfaceTimeline,
        other.colorSurfaceTimeline,
        t,
      )!,
      colorSurfaceField: Color.lerp(
        colorSurfaceField,
        other.colorSurfaceField,
        t,
      )!,
      colorSurfaceFieldActive: Color.lerp(
        colorSurfaceFieldActive,
        other.colorSurfaceFieldActive,
        t,
      )!,
      colorScrim: Color.lerp(colorScrim, other.colorScrim, t)!,
      colorSurfaceBlurOverlay: Color.lerp(
        colorSurfaceBlurOverlay,
        other.colorSurfaceBlurOverlay,
        t,
      )!,
      blurOverlaySigma: _lerpDouble(
        blurOverlaySigma,
        other.blurOverlaySigma,
        t,
      ),
      colorFreeWindow: Color.lerp(colorFreeWindow, other.colorFreeWindow, t)!,
      colorZoneBackground: Color.lerp(
        colorZoneBackground,
        other.colorZoneBackground,
        t,
      )!,
      colorTextPrimary: Color.lerp(
        colorTextPrimary,
        other.colorTextPrimary,
        t,
      )!,
      colorTextSecondary: Color.lerp(
        colorTextSecondary,
        other.colorTextSecondary,
        t,
      )!,
      colorTextTertiary: Color.lerp(
        colorTextTertiary,
        other.colorTextTertiary,
        t,
      )!,
      colorBorder: Color.lerp(colorBorder, other.colorBorder, t)!,
      colorAccent: Color.lerp(colorAccent, other.colorAccent, t)!,
      colorTaskCompleted: Color.lerp(
        colorTaskCompleted,
        other.colorTaskCompleted,
        t,
      )!,
      colorTaskSkipped: Color.lerp(
        colorTaskSkipped,
        other.colorTaskSkipped,
        t,
      )!,
      colorTaskAlert: Color.lerp(colorTaskAlert, other.colorTaskAlert, t)!,
      categoryColors: t < 0.5 ? categoryColors : other.categoryColors,
      categoryIconColors: t < 0.5
          ? categoryIconColors
          : other.categoryIconColors,
      categorySwatches: t < 0.5 ? categorySwatches : other.categorySwatches,
      spacingXs: _lerpDouble(spacingXs, other.spacingXs, t),
      spacingSm: _lerpDouble(spacingSm, other.spacingSm, t),
      spacingIconTop: _lerpDouble(spacingIconTop, other.spacingIconTop, t),
      spacingMd: _lerpDouble(spacingMd, other.spacingMd, t),
      spacingLg: _lerpDouble(spacingLg, other.spacingLg, t),
      spacingXl: _lerpDouble(spacingXl, other.spacingXl, t),
      spacingBlockGap: _lerpDouble(spacingBlockGap, other.spacingBlockGap, t),
      spacingScreenPadding: _lerpDouble(
        spacingScreenPadding,
        other.spacingScreenPadding,
        t,
      ),
      spacingTimeColumnWidth: _lerpDouble(
        spacingTimeColumnWidth,
        other.spacingTimeColumnWidth,
        t,
      ),
      spacingTimelineGutter: _lerpDouble(
        spacingTimelineGutter,
        other.spacingTimelineGutter,
        t,
      ),
      spacingContentTop: _lerpDouble(
        spacingContentTop,
        other.spacingContentTop,
        t,
      ),
      spacingMinTapTarget: _lerpDouble(
        spacingMinTapTarget,
        other.spacingMinTapTarget,
        t,
      ),
      sizeMinFieldHeight: _lerpDouble(
        sizeMinFieldHeight,
        other.sizeMinFieldHeight,
        t,
      ),
      sizeTaskBadgeSm: _lerpDouble(sizeTaskBadgeSm, other.sizeTaskBadgeSm, t),
      sizeTaskBadgeMd: _lerpDouble(sizeTaskBadgeMd, other.sizeTaskBadgeMd, t),
      sizeTaskBadgeLg: _lerpDouble(sizeTaskBadgeLg, other.sizeTaskBadgeLg, t),
      sizeTaskBadgeXl: _lerpDouble(sizeTaskBadgeXl, other.sizeTaskBadgeXl, t),
      sizeTaskBadge: _lerpDouble(sizeTaskBadge, other.sizeTaskBadge, t),
      sizeButtonXs: _lerpDouble(sizeButtonXs, other.sizeButtonXs, t),
      sizeButtonSm: _lerpDouble(sizeButtonSm, other.sizeButtonSm, t),
      sizeButtonMd: _lerpDouble(sizeButtonMd, other.sizeButtonMd, t),
      sizeButtonLg: _lerpDouble(sizeButtonLg, other.sizeButtonLg, t),
      sizeButtonXl: _lerpDouble(sizeButtonXl, other.sizeButtonXl, t),
      radiusSm: _lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: _lerpDouble(radiusMd, other.radiusMd, t),
      radiusLg: _lerpDouble(radiusLg, other.radiusLg, t),
      radiusXl: _lerpDouble(radiusXl, other.radiusXl, t),
      radiusXxl: _lerpDouble(radiusXxl, other.radiusXxl, t),
      radiusTaskPill: _lerpDouble(radiusTaskPill, other.radiusTaskPill, t),
      radiusPillSmall: _lerpDouble(radiusPillSmall, other.radiusPillSmall, t),
      radiusPillRounded: _lerpDouble(
        radiusPillRounded,
        other.radiusPillRounded,
        t,
      ),
      radiusPillFull: _lerpDouble(radiusPillFull, other.radiusPillFull, t),
      radiusPill: _lerpDouble(radiusPill, other.radiusPill, t),
      radiusModal: _lerpDouble(radiusModal, other.radiusModal, t),
      borderWidthHairline: _lerpDouble(
        borderWidthHairline,
        other.borderWidthHairline,
        t,
      ),
      borderWidthConnector: _lerpDouble(
        borderWidthConnector,
        other.borderWidthConnector,
        t,
      ),
      shadowLift: BoxShadow.lerpList(shadowLift, other.shadowLift, t)!,
      shadowPane: BoxShadow.lerpList(shadowPane, other.shadowPane, t)!,
      textHeadline: TextStyle.lerp(textHeadline, other.textHeadline, t)!,
      textTitle: TextStyle.lerp(textTitle, other.textTitle, t)!,
      textBody: TextStyle.lerp(textBody, other.textBody, t)!,
      textBodyMono: TextStyle.lerp(textBodyMono, other.textBodyMono, t)!,
      textLabel: TextStyle.lerp(textLabel, other.textLabel, t)!,
      textCaption: TextStyle.lerp(textCaption, other.textCaption, t)!,
      textCaptionMono: TextStyle.lerp(
        textCaptionMono,
        other.textCaptionMono,
        t,
      )!,
      textZoneName: TextStyle.lerp(textZoneName, other.textZoneName, t)!,
      textTaskEdgeTime: TextStyle.lerp(
        textTaskEdgeTime,
        other.textTaskEdgeTime,
        t,
      )!,
      textTaskTitleSm: TextStyle.lerp(
        textTaskTitleSm,
        other.textTaskTitleSm,
        t,
      )!,
      textTaskTitleMd: TextStyle.lerp(
        textTaskTitleMd,
        other.textTaskTitleMd,
        t,
      )!,
      textTaskTitleLg: TextStyle.lerp(
        textTaskTitleLg,
        other.textTaskTitleLg,
        t,
      )!,
      textTaskTitle: TextStyle.lerp(textTaskTitle, other.textTaskTitle, t)!,
      textTaskTitleZone: TextStyle.lerp(
        textTaskTitleZone,
        other.textTaskTitleZone,
        t,
      )!,
      motionFast: t < 0.5 ? motionFast : other.motionFast,
      motionNormal: t < 0.5 ? motionNormal : other.motionNormal,
      motionSlow: t < 0.5 ? motionSlow : other.motionSlow,
      motionRouteSettle: t < 0.5 ? motionRouteSettle : other.motionRouteSettle,
      motionSheetSlide: t < 0.5 ? motionSheetSlide : other.motionSheetSlide,
      motionKeyboardSettle: t < 0.5
          ? motionKeyboardSettle
          : other.motionKeyboardSettle,
      curveStandard: t < 0.5 ? curveStandard : other.curveStandard,
      curveDecelerate: t < 0.5 ? curveDecelerate : other.curveDecelerate,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// The Timeline's three-column geometry, derived in ONE place from
/// [AmbleTheme.spacingScreenPadding], [AmbleTheme.spacingTimeColumnWidth]
/// and [AmbleTheme.spacingTimelineGutter].
///
/// Both Timeline views (spatial and non-spatial) lay out as:
///
/// ```
/// | edge | TIME | gutter | ZONE/PILLS | gutter | CONTENT | edge |
/// ```
///
/// with `edge` == `gutter` == [AmbleTheme.spacingTimelineGutter], so every
/// horizontal gap on the screen is the same value.
///
/// **Why this exists at all**: the two views previously reached these
/// positions through four independent mechanisms — a frozen `90` constant,
/// a `66 + inset` sum, a lane-derived offset that changed with the day's
/// overlap depth, and a negative-margin escape — which agreed only by
/// arithmetic coincidence and drifted apart whenever any input changed.
/// Reported repeatedly against annotated screenshots, and finally as "can
/// we have literally three columns of the same size," with the reason to
/// rebuild rather than patch: the old structure "would mean future
/// problems with some other devices and sizes."
extension TimelineColumns on AmbleTheme {
  /// Column 1's left edge — the time column starts here.
  double get timelineTimeLeft => spacingTimelineGutter;

  /// Column 1's width for the clock format actually in use, rather than
  /// for the widest one any locale could ask for.
  ///
  /// [spacingTimeColumnWidth] is sized for `"12:00 PM"`, which measures
  /// exactly 96 in `textCaptionMono` — correct for a 12-hour locale, but
  /// on a 24-hour one every label ("05:00", "13:41") measures 60, leaving
  /// a dead 36px stripe between the time text and where zones begin.
  /// Reported directly against annotated screenshots marking that gap in
  /// red across both views, with zones expected to start where the gap
  /// does.
  ///
  /// Measures the real rendered format via [MediaQuery.alwaysUse24HourFormat]
  /// so a 12-hour locale keeps its full 96 and nothing clips. Never wider
  /// than [spacingTimeColumnWidth] — this only ever reclaims slack.
  double timelineTimeColumnWidth(BuildContext context) {
    final use24Hour = MediaQuery.maybeOf(context)?.alwaysUse24HourFormat;
    if (use24Hour != true) return spacingTimeColumnWidth;
    // "13:41" — the widest a 24-hour label gets; every digit is the same
    // advance in a monospace face, so one sample measures them all.
    final painter = TextPainter(
      text: TextSpan(text: '13:41', style: textCaptionMono),
      textDirection: TextDirection.ltr,
    )..layout();
    return math.min(spacingTimeColumnWidth, painter.width);
  }

  /// Column 2's left edge for the clock format in use — the context-aware
  /// counterpart to [timelineZoneLeft], built on
  /// [timelineTimeColumnWidth] so zones start right after the time text
  /// instead of after a column sized for a format this device never
  /// renders.
  double timelineZoneLeftFor(BuildContext context) =>
      spacingTimelineGutter +
      timelineTimeColumnWidth(context) +
      spacingTimelineGutter;

  /// Column 2's left edge — zone bands and task pills start here.
  ///
  /// Format-agnostic (assumes the widest, 12-hour label). Prefer
  /// [timelineZoneLeftFor] wherever a [BuildContext] is available; this
  /// remains for the token-level contract tests and for callers with no
  /// context to measure from.
  double get timelineZoneLeft =>
      spacingTimelineGutter + spacingTimeColumnWidth + spacingTimelineGutter;

  /// Column 3's left edge — task titles/content start here, at a fixed x
  /// that does NOT move with the day's own overlap depth.
  double timelineContentLeft(double viewportWidth) =>
      timelineZoneLeft +
      timelineZoneWidth(viewportWidth) +
      spacingTimelineGutter;

  /// Column 2's width — the zone/pill column. Takes a third of whatever
  /// remains after the time column and the four gaps, so columns 2 and 3
  /// share the leftover evenly rather than column 3's start depending on
  /// how deep the day's pills happen to stack.
  double timelineZoneWidth(double viewportWidth) {
    final remaining =
        viewportWidth - spacingTimeColumnWidth - spacingTimelineGutter * 4;
    return math.max(0, remaining / 2);
  }

  /// Column 3's width — the content column, running to the final gutter.
  double timelineContentWidth(double viewportWidth) => math.max(
    0,
    viewportWidth - timelineContentLeft(viewportWidth) - spacingTimelineGutter,
  );
}
