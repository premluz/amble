import 'package:flutter/material.dart';

import 'color_primitives.dart';
import 'motion_primitives.dart';
import 'radius_primitives.dart';
import 'spacing_primitives.dart';
import 'type_primitives.dart';

/// Semantic task category. Fixed taxonomy, not a free color picker —
/// see docs/DECISIONS.md ("Task colors are semantic categories").
enum TaskCategoryToken { general, health, work, personal, admin }

/// Tier 2 — semantic tokens, meaning-bound references to Tier 1.
/// This is the layer widgets actually consume; never reference
/// [ColorPrimitives] etc. directly from a widget.
@immutable
class AmbleTheme extends ThemeExtension<AmbleTheme> {
  const AmbleTheme({
    required this.colorSurfaceBase,
    required this.colorSurfacePrimary,
    required this.colorSurfaceSecondary,
    required this.colorSurfaceTimeline,
    required this.colorSurfaceField,
    required this.colorSurfaceFieldActive,
    required this.colorScrim,
    required this.colorSurfaceBlurOverlay,
    required this.blurOverlaySigma,
    required this.colorFreeWindow,
    required this.colorTextPrimary,
    required this.colorTextSecondary,
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
    required this.spacingMinTapTarget,
    required this.sizeMinFieldHeight,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusTaskPill,
    required this.radiusModal,
    required this.borderWidthHairline,
    required this.borderWidthConnector,
    required this.shadowLift,
    required this.shadowPane,
    required this.textHeadline,
    required this.textTitle,
    required this.textBody,
    required this.textLabel,
    required this.textCaption,
    required this.motionFast,
    required this.motionNormal,
    required this.motionSlow,
    required this.motionRouteSettle,
    required this.curveStandard,
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

  // Text
  final Color colorTextPrimary;
  final Color colorTextSecondary;

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
  final double spacingScreenPadding;

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

  /// Fully rounded — the timeline task pill and any capsule-shaped
  /// control. Not a rung on the size scale; a shape.
  final double radiusTaskPill;

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
  final TextStyle textBody;
  final TextStyle textLabel;
  final TextStyle textCaption;

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
  final Curve curveStandard;

  static final light = AmbleTheme(
    colorSurfaceBase: ColorPrimitives.surface0,
    colorSurfacePrimary: ColorPrimitives.surface1,
    colorSurfaceSecondary: ColorPrimitives.sage100,
    colorSurfaceTimeline: ColorPrimitives.sand100,
    colorSurfaceField: ColorPrimitives.surface2,
    colorSurfaceFieldActive: ColorPrimitives.surface3,
    colorScrim: const Color(0x66000000),
    // 36% opacity of the pane fill itself (surface1), not a separate
    // hardcoded value — always tracks colorSurfacePrimary if that token
    // ever changes.
    colorSurfaceBlurOverlay: ColorPrimitives.surface1.withValues(alpha: 0.36),
    blurOverlaySigma: 12.0,
    // Same primitive as colorBorder below (sand300), at low alpha — kept
    // as a literal primitive reference rather than colorBorder.withValues
    // since these are compile-time const field initializers and colorBorder
    // isn't assigned yet at this point in the constructor call.
    colorFreeWindow: ColorPrimitives.sand300.withValues(alpha: 0.5),
    colorTextPrimary: ColorPrimitives.slate900,
    colorTextSecondary: ColorPrimitives.slate500,
    colorBorder: ColorPrimitives.sand300,
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
      TaskCategoryToken.personal: ColorPrimitives.periwinkleTint,
      TaskCategoryToken.admin: ColorPrimitives.berryTint,
    },
    categoryIconColors: {
      TaskCategoryToken.general: ColorPrimitives.neutral500,
      TaskCategoryToken.health: ColorPrimitives.clay500,
      TaskCategoryToken.work: ColorPrimitives.ochre500,
      TaskCategoryToken.personal: ColorPrimitives.periwinkle500,
      TaskCategoryToken.admin: ColorPrimitives.berry500,
    },
    categorySwatches: ColorPrimitives.categoryPalette12,
    spacingXs: SpacingPrimitives.space2,
    spacingSm: SpacingPrimitives.space3,
    spacingIconTop: SpacingPrimitives.space4,
    spacingMd: SpacingPrimitives.space5,
    spacingLg: SpacingPrimitives.space7,
    spacingXl: SpacingPrimitives.space9,
    spacingBlockGap: SpacingPrimitives.space3,
    spacingScreenPadding: SpacingPrimitives.space7,
    spacingMinTapTarget: 48.0,
    sizeMinFieldHeight: 60.0,
    radiusSm: RadiusPrimitives.radiusSm,
    radiusMd: RadiusPrimitives.radiusMd,
    radiusLg: RadiusPrimitives.radiusLg,
    radiusXl: RadiusPrimitives.radiusXl,
    radiusTaskPill: RadiusPrimitives.radiusFull,
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
      fontSize: TypePrimitives.size6,
      fontWeight: TypePrimitives.weightBold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.slate900,
    ),
    textTitle: TextStyle(
      fontSize: TypePrimitives.size4,
      fontWeight: TypePrimitives.weightSemibold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.slate900,
    ),
    textBody: TextStyle(
      fontSize: TypePrimitives.size3,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate900,
    ),
    textLabel: TextStyle(
      fontSize: TypePrimitives.size2,
      fontWeight: TypePrimitives.weightMedium,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate700,
    ),
    textCaption: TextStyle(
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate500,
    ),
    motionFast: const Duration(milliseconds: MotionPrimitives.durationFastMs),
    motionNormal: const Duration(
      milliseconds: MotionPrimitives.durationNormalMs,
    ),
    motionSlow: const Duration(milliseconds: MotionPrimitives.durationSlowMs),
    motionRouteSettle: const Duration(
      milliseconds: MotionPrimitives.durationRouteSettleMs,
    ),
    curveStandard: const Cubic(0.4, 0.0, 0.2, 1.0),
  );

  /// First-pass dark palette (Phase 13a). Surfaces/text/border are derived
  /// from the `ink`/`sand` OKLCH ramps rather than inverted from light —
  /// see docs/DECISIONS.md. Category accents are deliberately unchanged
  /// from light: measured at 4.9–5.2:1 against `ink900`, with white glyphs
  /// at 3.6–3.8:1 on the pills, so they hold up without a dark-specific
  /// variant. Flagged as first-pass pending visual review (Phase 13b).
  static final dark = AmbleTheme(
    // Dark mode's level 0/1 pairing is inherited, not re-derived: `ink900`
    // is already this palette's deepest surface and stays the pane, so the
    // ground behind it reuses `ink800` (the timeline canvas) rather than
    // inventing a step below `ink900` — going darker than the deepest
    // token would flatten against black on most screens. The light palette
    // gets the literal 0/1 hexes; dark keeps its existing, measured ramp.
    colorSurfaceBase: ColorPrimitives.ink800,
    colorSurfacePrimary: ColorPrimitives.ink900,
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
    colorTextPrimary: ColorPrimitives.sand200,
    colorTextSecondary: ColorPrimitives.sand400,
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
      TaskCategoryToken.personal: ColorPrimitives.periwinkle500Dark,
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
      TaskCategoryToken.personal: ColorPrimitives.white,
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
    spacingScreenPadding: SpacingPrimitives.space7,
    spacingMinTapTarget: 48.0,
    sizeMinFieldHeight: 60.0,
    radiusSm: RadiusPrimitives.radiusSm,
    radiusMd: RadiusPrimitives.radiusMd,
    radiusLg: RadiusPrimitives.radiusLg,
    radiusXl: RadiusPrimitives.radiusXl,
    radiusTaskPill: RadiusPrimitives.radiusFull,
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
      fontSize: TypePrimitives.size6,
      fontWeight: TypePrimitives.weightBold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.sand200,
    ),
    textTitle: TextStyle(
      fontSize: TypePrimitives.size4,
      fontWeight: TypePrimitives.weightSemibold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.sand200,
    ),
    textBody: TextStyle(
      fontSize: TypePrimitives.size3,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand200,
    ),
    textLabel: TextStyle(
      fontSize: TypePrimitives.size2,
      fontWeight: TypePrimitives.weightMedium,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand400,
    ),
    textCaption: TextStyle(
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand400,
    ),
    motionFast: const Duration(milliseconds: MotionPrimitives.durationFastMs),
    motionNormal: const Duration(
      milliseconds: MotionPrimitives.durationNormalMs,
    ),
    motionSlow: const Duration(milliseconds: MotionPrimitives.durationSlowMs),
    motionRouteSettle: const Duration(
      milliseconds: MotionPrimitives.durationRouteSettleMs,
    ),
    curveStandard: const Cubic(0.4, 0.0, 0.2, 1.0),
  );

  @override
  AmbleTheme copyWith({
    Color? colorSurfaceBase,
    Color? colorSurfacePrimary,
    Color? colorSurfaceSecondary,
    Color? colorSurfaceTimeline,
    Color? colorSurfaceField,
    Color? colorSurfaceFieldActive,
    Color? colorScrim,
    Color? colorSurfaceBlurOverlay,
    double? blurOverlaySigma,
    Color? colorFreeWindow,
    Color? colorTextPrimary,
    Color? colorTextSecondary,
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
    double? spacingMinTapTarget,
    double? sizeMinFieldHeight,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusTaskPill,
    double? radiusModal,
    double? borderWidthHairline,
    double? borderWidthConnector,
    List<BoxShadow>? shadowLift,
    List<BoxShadow>? shadowPane,
    TextStyle? textHeadline,
    TextStyle? textTitle,
    TextStyle? textBody,
    TextStyle? textLabel,
    TextStyle? textCaption,
    Duration? motionFast,
    Duration? motionNormal,
    Duration? motionSlow,
    Duration? motionRouteSettle,
    Curve? curveStandard,
  }) {
    return AmbleTheme(
      colorSurfaceBase: colorSurfaceBase ?? this.colorSurfaceBase,
      colorSurfacePrimary: colorSurfacePrimary ?? this.colorSurfacePrimary,
      colorSurfaceSecondary:
          colorSurfaceSecondary ?? this.colorSurfaceSecondary,
      colorSurfaceTimeline: colorSurfaceTimeline ?? this.colorSurfaceTimeline,
      colorSurfaceField: colorSurfaceField ?? this.colorSurfaceField,
      colorSurfaceFieldActive:
          colorSurfaceFieldActive ?? this.colorSurfaceFieldActive,
      colorScrim: colorScrim ?? this.colorScrim,
      colorSurfaceBlurOverlay:
          colorSurfaceBlurOverlay ?? this.colorSurfaceBlurOverlay,
      blurOverlaySigma: blurOverlaySigma ?? this.blurOverlaySigma,
      colorFreeWindow: colorFreeWindow ?? this.colorFreeWindow,
      colorTextPrimary: colorTextPrimary ?? this.colorTextPrimary,
      colorTextSecondary: colorTextSecondary ?? this.colorTextSecondary,
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
      spacingMinTapTarget: spacingMinTapTarget ?? this.spacingMinTapTarget,
      sizeMinFieldHeight: sizeMinFieldHeight ?? this.sizeMinFieldHeight,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusTaskPill: radiusTaskPill ?? this.radiusTaskPill,
      radiusModal: radiusModal ?? this.radiusModal,
      borderWidthHairline: borderWidthHairline ?? this.borderWidthHairline,
      borderWidthConnector: borderWidthConnector ?? this.borderWidthConnector,
      shadowLift: shadowLift ?? this.shadowLift,
      shadowPane: shadowPane ?? this.shadowPane,
      textHeadline: textHeadline ?? this.textHeadline,
      textTitle: textTitle ?? this.textTitle,
      textBody: textBody ?? this.textBody,
      textLabel: textLabel ?? this.textLabel,
      textCaption: textCaption ?? this.textCaption,
      motionFast: motionFast ?? this.motionFast,
      motionNormal: motionNormal ?? this.motionNormal,
      motionSlow: motionSlow ?? this.motionSlow,
      motionRouteSettle: motionRouteSettle ?? this.motionRouteSettle,
      curveStandard: curveStandard ?? this.curveStandard,
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
      radiusSm: _lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: _lerpDouble(radiusMd, other.radiusMd, t),
      radiusLg: _lerpDouble(radiusLg, other.radiusLg, t),
      radiusXl: _lerpDouble(radiusXl, other.radiusXl, t),
      radiusTaskPill: _lerpDouble(radiusTaskPill, other.radiusTaskPill, t),
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
      textLabel: TextStyle.lerp(textLabel, other.textLabel, t)!,
      textCaption: TextStyle.lerp(textCaption, other.textCaption, t)!,
      motionFast: t < 0.5 ? motionFast : other.motionFast,
      motionNormal: t < 0.5 ? motionNormal : other.motionNormal,
      motionSlow: t < 0.5 ? motionSlow : other.motionSlow,
      motionRouteSettle: t < 0.5 ? motionRouteSettle : other.motionRouteSettle,
      curveStandard: t < 0.5 ? curveStandard : other.curveStandard,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
