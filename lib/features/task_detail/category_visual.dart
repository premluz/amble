import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/category.dart';
import '../../shared/models/tag_color_style.dart';

/// [BuiltInCategoryIds.general]'s own [Category.colorToken] — a stable
/// seed-time value (see `category_providers.dart`'s built-in seed block),
/// named here rather than left as a bare `0` literal at every "no
/// category chosen yet" fallback call site (`CategoryBadge`,
/// `task_detail_sheet.dart`'s several unresolved-category placeholders).
const int generalCategoryColorToken = 0;

/// The resolved pill fill / icon glyph color for one [Category] — shared
/// between the category-picker chips and (via `TaskCapsuleBlock`'s own
/// legacy-aware wrapper) the timeline pill.
///
/// **Unified onto the 12-swatch `categorySwatches` palette for EVERY
/// category, built-in or custom** — requested directly, against a
/// screenshot showing a built-in category's light-mode pill visibly not
/// matching its own swatch. Built-ins used to route through a separate,
/// hand-tuned `categoryColors`/`categoryIconColors` Tier 2 map pair
/// (`TaskCategoryToken`-keyed), independently solved per theme and never
/// cross-checked against the swatch palette's own light/dark solving —
/// the two systems could and did drift apart. Every built-in
/// [Category] row already carries a stable [Category.colorToken] (set at
/// seed time, previously unused for built-ins — see
/// `category_providers.dart`'s own seed block), so there is exactly one
/// color-resolution path now: [Category.colorToken] indexes
/// [AmbleTheme.categorySwatches] for every row, same swatch for both fill
/// and icon-ring color (matching how a custom category already worked).
class CategoryVisual {
  const CategoryVisual({required this.pillColor, required this.iconColor});

  final Color pillColor;
  final Color iconColor;

  /// The tag's own full-saturation color. `pillColor`/`iconColor` are now
  /// always the same single swatch (see this class's own doc comment), so
  /// this simply returns it — kept as its own getter for
  /// [railColorFor]'s `TagColorStyle.iconOnly` mode, which was written
  /// against "the true color, however `CategoryVisual` happens to
  /// represent it" rather than assuming which field held it.
  Color get trueColor => iconColor;
}

CategoryVisual resolveCategoryVisual({
  required AmbleTheme theme,
  required Category category,
}) {
  final swatch = theme.categorySwatches[category.colorToken];
  return CategoryVisual(pillColor: swatch, iconColor: swatch);
}

/// How much of [TagColorStyle.iconOnly]'s full-saturation
/// [CategoryVisual.trueColor] survives on the paled rail — requested
/// directly: "the pill also being colored but much paler than the main
/// color of the tag color selected. If we have scales to go down, let's
/// do it, if not let's try opacity reduction first." No lighten-by-
/// lightness scale exists for the 12-swatch custom-tag palette today
/// (only the 5 built-ins have a hand-tuned pale-tint counterpart, and
/// even that is 5 independently-chosen OKLCH values, not a formula this
/// function could reuse for an arbitrary swatch) — so this reaches the
/// "much paler" rail via opacity, the confirmed fallback.
///
/// 0.4, not the originally-shipped 0.18 — reported directly ("still see
/// them as white"): at 0.18, a saturated swatch over this app's light
/// `colorSurfaceTimeline` background read as indistinguishable from no
/// color at all, not "this color, but paler." 0.4 keeps the "much paler
/// than the main color" request while staying visibly tinted rather than
/// blank.
const double iconOnlyRailOpacity = 0.4;

/// The color a pill/rail's own fill should use, given the active
/// [TagColorStyle]: the tag's [CategoryVisual.pillColor] unchanged for
/// [TagColorStyle.pill] (today's existing look), or its
/// [CategoryVisual.trueColor] at [iconOnlyRailOpacity] for
/// [TagColorStyle.iconOnly] — the small badge behind the icon then
/// carries [CategoryVisual.trueColor] at full opacity instead, painted
/// by the caller (see `CategoryBadge`'s own `style` parameter).
Color railColorFor(CategoryVisual visual, TagColorStyle style) =>
    switch (style) {
      TagColorStyle.pill => visual.pillColor,
      TagColorStyle.iconOnly => visual.trueColor.withValues(
        alpha: iconOnlyRailOpacity,
      ),
    };

/// A curated set of Tabler glyphs offered in the new/edit-category picker
/// — hand-picked, not the full ~6,250-icon set, matching how the old
/// curated emoji set (`add_category_modal.dart`'s `_curatedCategoryEmoji`)
/// was never a full emoji-picker either. Broadened twice from the
/// original 16-icon set (16 -> 60 -> 105) — requested directly both
/// times: "add more icons... broader choice of icons that represent
/// tasks, lifestyle, etc. Not UI or anything like that," then "let's pull
/// more useful icons into selectable for [tags]." Every addition is a
/// concrete real-world thing (a lifestyle domain, an activity, an
/// object), never a generic app/UI glyph (no gear, no bell, no generic
/// arrow/chevron).
const List<IconData> curatedCategoryIcons = [
  TablerIcons.circle,
  TablerIcons.heart,
  TablerIcons.briefcase,
  TablerIcons.home,
  TablerIcons.clipboardList,
  // TablerIcons.star deliberately excluded — reserved for the "Important"
  // task marker (Icons.star_rounded, task_action_sheet.dart/
  // task_capsule_block.dart), requested directly: a Label offering the
  // same glyph would read as if it meant "important" rather than
  // whatever the Label itself represents. Still a real Tabler icon and
  // still rendered correctly for any Label that already picked it before
  // this change — only removed from the picker's own offered choices,
  // not a data migration.
  TablerIcons.bulb,
  TablerIcons.book,
  TablerIcons.run,
  TablerIcons.school,
  TablerIcons.shoppingCart,
  TablerIcons.plane,
  TablerIcons.tools,
  TablerIcons.pig,
  TablerIcons.paw,
  TablerIcons.music,
  // Health & fitness.
  TablerIcons.dumbbell,
  TablerIcons.yoga,
  TablerIcons.pill,
  TablerIcons.stethoscope,
  TablerIcons.bike,
  TablerIcons.walk,
  TablerIcons.swimming,
  // Food & drink.
  TablerIcons.apple,
  TablerIcons.salad,
  TablerIcons.coffee,
  TablerIcons.toolsKitchen,
  TablerIcons.pizza,
  // Rest & routine.
  TablerIcons.bed,
  TablerIcons.moon,
  TablerIcons.sun,
  TablerIcons.sunrise,
  TablerIcons.hourglass,
  // Money & shopping.
  TablerIcons.wallet,
  TablerIcons.cashBanknote,
  TablerIcons.gift,
  // Family & pets.
  TablerIcons.users,
  TablerIcons.babyCarriage,
  TablerIcons.dog,
  TablerIcons.cat,
  // Places & travel.
  TablerIcons.car,
  TablerIcons.map,
  TablerIcons.compass,
  // Nature.
  TablerIcons.tree,
  TablerIcons.leaf,
  // Communication.
  TablerIcons.phone,
  TablerIcons.mail,
  // Creative & hobbies.
  TablerIcons.palette,
  TablerIcons.camera,
  TablerIcons.guitarPick,
  TablerIcons.shirt,
  // Achievement.
  TablerIcons.trophy,
  TablerIcons.target,
  TablerIcons.checklist,
  // Work & study.
  TablerIcons.deviceLaptop,
  TablerIcons.keyboard,
  TablerIcons.printer,
  TablerIcons.calculator,
  TablerIcons.presentation,
  // TablerIcons.folder deliberately excluded — reserved for Sections
  // ("Inbox folders," see shared/models/section.dart), so a Label can't
  // visually pass itself off as a folder. Same "picker choice only, not
  // a data migration" reasoning as TablerIcons.star above.
  // Home & chores.
  TablerIcons.armchair,
  TablerIcons.sofa,
  TablerIcons.bath,
  TablerIcons.vacuumCleaner,
  // Weather & outdoors.
  TablerIcons.umbrella,
  TablerIcons.snowflake,
  TablerIcons.cloudRain,
  TablerIcons.mountain,
  TablerIcons.tent,
  TablerIcons.campfire,
  TablerIcons.backpack,
  // Sport & games.
  TablerIcons.golf,
  TablerIcons.ballBasketball,
  TablerIcons.ballFootball,
  TablerIcons.ballVolleyball,
  TablerIcons.skateboard,
  TablerIcons.puzzle,
  TablerIcons.dice,
  // Celebrations.
  TablerIcons.confetti,
  TablerIcons.balloon,
  TablerIcons.cake,
  TablerIcons.iceCream,
  TablerIcons.cookie,
  TablerIcons.soup,
  // Health, extended.
  TablerIcons.firstAidKit,
  TablerIcons.vaccine,
  TablerIcons.thermometer,
  TablerIcons.brain,
  // Animals, extended.
  TablerIcons.horse,
  TablerIcons.butterfly,
  TablerIcons.ghost,
  // Ideas & science.
  TablerIcons.infinity,
  TablerIcons.flask,
  TablerIcons.microscope,
  TablerIcons.telescope,
  TablerIcons.rocket,
  TablerIcons.planet,
  TablerIcons.rainbow,
  TablerIcons.droplet,
  TablerIcons.recycle,
  // Time.
  TablerIcons.stopwatch,
  TablerIcons.clockHour3,
  // Travel, extended.
  TablerIcons.anchor,
  TablerIcons.road,
  TablerIcons.parking,
  // **2026-09-24 — requested directly, against a supplied list of
  // lifestyle/activity names** (Sport, Reading, Food, Pets, Home,
  // Beauty, Mind, Body Exercise, Journaling, Shopping, Cleaning, Gaming,
  // Music, Outdoors, Parenting, Side Project, Networking, Wellness,
  // Rest, Planning, Garden, Chore): "let's pull icon for meditation from
  // the system we use... if can't find appropriate icon check the
  // system we use and pull." Most of that list already had a matching
  // icon above (Reading→book, Food→apple/salad/toolsKitchen, Pets→dog/
  // cat/paw, Home→home, Sport/Body Exercise→run/dumbbell/walk/bike/
  // swimming, Music→music, Outdoors→tent/mountain/campfire/backpack,
  // Parenting→babyCarriage, Rest→bed, Shopping→shoppingCart, Cleaning→
  // vacuumCleaner/bath, Planning→checklist/clipboardList, Chore→
  // vacuumCleaner, Side Project→rocket, Mind→brain). Meditation has no
  // dedicated glyph in Tabler (checked directly against the installed
  // `tabler_icons_plus` package) — [TablerIcons.yoga] (a seated,
  // cross-legged figure) is the standard meditation pictogram across
  // icon sets generally and was ALREADY in this list above, under
  // Health & fitness. These six are the genuinely new additions, one
  // per name that had no existing match:
  TablerIcons.scissors, // Beauty
  TablerIcons.notebook, // Journaling
  TablerIcons.deviceGamepad2, // Gaming
  TablerIcons.usersGroup, // Networking — distinct from the plain `users`
  // glyph already above (Parenting/family), since a group-of-people
  // silhouette reads more specifically as "network" than "family."
  TablerIcons.activityHeartbeat, // Wellness
  TablerIcons.gardenCart, // Garden
];

/// The built-in categories' default Tabler glyph — requested directly:
/// "let's get tabler icons installed and use it instead of emojis for
/// categories." [categoryIconFor] never actually calls this for General
/// any more (that id resolves to null before reaching here) — the `_`
/// fallback below is for a genuinely unrecognized id, not General; see
/// [categoryIconFor]'s own doc comment for the full "no icon for
/// untagged" reasoning.
IconData builtInIconFor(String categoryId) => switch (categoryId) {
  BuiltInCategoryIds.health => TablerIcons.heart,
  BuiltInCategoryIds.work => TablerIcons.briefcase,
  // Renamed "Home" — keeps the home icon it always had.
  BuiltInCategoryIds.personal => TablerIcons.home,
  // The NEW "Personal" — a user icon, per direct request.
  BuiltInCategoryIds.personalNew => TablerIcons.user,
  BuiltInCategoryIds.social => TablerIcons.users,
  BuiltInCategoryIds.reading => TablerIcons.book,
  BuiltInCategoryIds.learning => TablerIcons.school,
  BuiltInCategoryIds.admin => TablerIcons.clipboardList,
  _ => TablerIcons.circle,
};

/// Resolves the glyph actually shown for [category]: its own
/// [Category.iconCodePoint] when set, else the matching built-in default,
/// else (a genuinely custom category created before this field existed,
/// still only carrying a legacy [Category.emoji]) null — the caller falls
/// back to that legacy emoji text itself, see [CategoryGlyph].
///
/// **General always resolves to null, never a fallback glyph.** General
/// IS the "untagged" state (every new task defaults its `categoryId` to
/// it explicitly — see `Task.create`'s own callers), so a task that has
/// never had a real category chosen must render no icon at all — not
/// [builtInIconFor]'s own generic `TablerIcons.circle` default, which is
/// meant for a genuinely unrecognized id, not this specific "no category
/// chosen" placeholder. Checked here, in the one shared resolver, rather
/// than at each call site: this used to be special-cased only inside
/// [CategoryGlyph]'s own `build()`, which left `task_capsule_block.dart`'s
/// `_CapsuleCategoryVisual` — a caller that reads this function directly,
/// not through `CategoryGlyph` — still showing a circle for an untagged
/// task's Timeline capsule. Reported directly against a screenshot: "New
/// task should not have icon if label not set."
IconData? categoryIconFor(Category category) {
  if (category.id == BuiltInCategoryIds.general) return null;
  final codePoint = category.iconCodePoint;
  if (codePoint != null) {
    // Not const — codePoint is a runtime value read from persisted data,
    // not one of the fixed literals `flutter build`'s icon tree-shaker
    // can see ahead of time. This is the standard, unavoidable shape for
    // reconstructing an IconData from a stored code point (Category only
    // persists an int, not an IconData); every one of curatedCategoryIcons
    // is still a real `const TablerIcons.*` reference at its own call
    // sites. `flutter analyze` therefore always shows exactly one
    // `non_const_argument_for_const_parameter` warning right here — not
    // suppressible by an `// ignore:` comment (this is a hard analyzer
    // diagnostic tied to IconData's own `@mustBeConst` annotation, not an
    // ordinary lint rule). Accepted as a known, permanent warning rather
    // than switching Category.iconCodePoint to a string icon NAME with a
    // hand-maintained name<->icon switch just to keep every reference
    // const (confirmed directly). Consequence: a RELEASE build needs
    // `flutter build ... --no-tree-shake-icons`, since this one dynamic
    // reconstruction is exactly what IconData's own constructor doc
    // comment warns disables tree-shaking ("Instantiating non-const
    // instances of this class in your app will mean the app cannot be
    // built in release mode with icon tree-shaking").
    return IconData(
      codePoint,
      fontFamily: 'tabler-icons',
      fontPackage: 'tabler_icons_plus',
    );
  }
  final builtInToken = builtInTokenFor(category.id);
  if (builtInToken != null) return builtInIconFor(category.id);
  return null;
}

/// Renders [category]'s glyph — a Tabler icon when [categoryIconFor]
/// resolves one, else the legacy [Category.emoji] text (only reachable for
/// a custom category created before [Category.iconCodePoint] existed), else
/// nothing. The one shared render site every `Text(category.emoji, ...)`
/// call in the app converts to, so the Tabler-vs-legacy fallback lives in
/// exactly one place.
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph({
    super.key,
    required this.category,
    required this.color,
    required this.size,
  });

  final Category category;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    // General (the "untagged" state) resolves to null here — see
    // [categoryIconFor]'s own doc comment for why that check lives there
    // now, shared by every caller, rather than duplicated in this widget.
    final icon = categoryIconFor(category);
    if (icon != null) return Icon(icon, size: size, color: color);
    if (category.id == BuiltInCategoryIds.general || category.emoji.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(category.emoji, style: TextStyle(fontSize: size));
  }
}

/// The shared category badge: a colored circle or pill holding a
/// centered [CategoryGlyph] — one reusable widget every render site that
/// draws "a colored shape with a category icon in it" now uses, instead
/// of each independently reimplementing `Container(decoration:...) ->
/// Center -> Icon` with its own slightly different glyph-to-badge ratio.
/// Reported directly: "all other pills should be [a] consistent padding
/// scale of icon, ensure using [the] same class[,] reusable."
///
/// [category] null renders the General fallback (a plain outline circle,
/// [BuiltInCategoryIds.general]'s own default) rather than requiring
/// every caller to branch on "no category assigned" itself — mirrors the
/// identical null-handling every call site already had inline.
///
/// [shape] is deliberately a parameter, not a fixed choice: this app has
/// two genuinely different existing badge shapes in use on purpose —
/// [BoxShape.circle] (the Inbox's own toggle badge, template rows,
/// category list) and the "Pill shape" setting's own [radiusPill] rung
/// (task/zone pills, which must keep tracking that setting) — unifying
/// the WIDGET does not mean forcing one shape where two were each chosen
/// deliberately.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.theme,
    required this.category,
    required this.size,
    this.shape = BoxShape.circle,
    this.glyphSizeRatio = 0.55,
  });

  final AmbleTheme theme;
  final Category? category;

  /// Width and height of the badge square.
  final double size;
  final BoxShape shape;

  /// The glyph's size as a fraction of [size] — 0.55 by default, matching
  /// the ratio already tuned for `sizeTaskBadge`-scale badges (Task view,
  /// Zone view, imported events). A badge much smaller than that scale
  /// (e.g. the quick-create mini sheet's template chips, `spacingLg`) can
  /// override this: a thin-stroke Tabler icon at the same 0.55 ratio read
  /// as too small on that badge specifically, reported directly ("Badge
  /// on add task sheet icons too small").
  final double glyphSizeRatio;

  @override
  Widget build(BuildContext context) {
    final resolvedCategory = category;
    final badgeColor = resolvedCategory == null
        ? theme.categorySwatches[generalCategoryColorToken]
        : resolveCategoryVisual(
            theme: theme,
            category: resolvedCategory,
          ).pillColor;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: shape == BoxShape.circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(theme.radiusPill),
      ),
      // **2026-09-23 — no glyph at all for "no category."** Requested
      // directly: General/untagged should have "no icon and just grey."
      // A plain grey circle now carries the "uncategorised" signal on its
      // own, same reasoning as the emoji already being empty for this
      // case (see `TaskCategoryTokenMapping.emoji`'s own comment) — the
      // whole point is the absence of a glyph, not a neutral one.
      child: resolvedCategory == null
          ? null
          : CategoryGlyph(
              category: resolvedCategory,
              color: glyphColorOn(badgeColor),
              size: size * glyphSizeRatio,
            ),
    );
  }
}

/// The glyph color that reads against a badge/pill filled with
/// [background] — near-white on a dark/saturated fill, near-black on a
/// light one. Needed because a monochrome Tabler icon, unlike the emoji it
/// replaces, carries no color of its own: for a BUILT-IN category the pill
/// (pale tint) and icon ([resolveCategoryVisual]'s `categoryIconColors`,
/// saturated) already differ, but a CUSTOM category's pill and icon
/// currently resolve to the exact same 12-swatch color — rendering a
/// monochrome icon straight in that color would be invisible against its
/// own background. Uses [ThemeData.estimateBrightnessForColor] rather
/// than a hand-rolled luminance check — this codebase has no existing
/// contrast helper to reuse (confirmed by search) and this is the
/// standard Flutter primitive for exactly this question.
Color glyphColorOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black;

/// Maps a built-in [Category]'s fixed id back to its original
/// [TaskCategoryToken], so a built-in category still renders through the
/// existing hand-tuned color maps rather than the new 12-swatch palette.
/// Null for any non-built-in (user-created) category id.
///
/// **2026-09-23** — [BuiltInCategoryIds.personal] (the RENAMED "Home"
/// category, same id as before the rename — see that constant's own doc
/// comment) now maps to [TaskCategoryToken.home], not `.personal`. The
/// token named `.personal` belongs to the NEW category at
/// [BuiltInCategoryIds.personalNew].
TaskCategoryToken? builtInTokenFor(String categoryId) => switch (categoryId) {
  BuiltInCategoryIds.general => TaskCategoryToken.general,
  BuiltInCategoryIds.health => TaskCategoryToken.health,
  BuiltInCategoryIds.work => TaskCategoryToken.work,
  BuiltInCategoryIds.personal => TaskCategoryToken.home,
  BuiltInCategoryIds.personalNew => TaskCategoryToken.personal,
  BuiltInCategoryIds.social => TaskCategoryToken.social,
  BuiltInCategoryIds.reading => TaskCategoryToken.reading,
  BuiltInCategoryIds.learning => TaskCategoryToken.learning,
  BuiltInCategoryIds.admin => TaskCategoryToken.admin,
  _ => null,
};
