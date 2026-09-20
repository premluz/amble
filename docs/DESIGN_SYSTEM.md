# Amble — Design System

This file documents the small set of **canonical shared visual components**
in this app — not the token architecture (see `docs/ARCHITECTURE.md`'s
"three-tier token architecture" section for that), but the specific,
named widgets that every screen touching a given kind of UI moment must
reuse, and the one settled answer for each recurring styling decision
(which side, which token, which shape) they encode.

Created 2026-09-19, requested directly: "we need a MD file Design System,
that defines these objects... so our design system can be agentic and key
decisions are set and documented." The trigger was a real divergence: the
Weekly Zone Authoring Grid's own drag-to-create preview had grown its own
hand-rolled selection border and its own hand-rolled time label, both
visually different from (and both fixed to match) the two canonical
widgets below — see `docs/DECISIONS.md`'s matching 2026-09-19 entry for
the full incident writeup.

**Read this before adding any new "selected" visual or any new "show a
time" visual anywhere in the app.** If what you need looks close to one of
these, extend the existing shared widget (adding a parameter, as
`TaskEdgeTimeLabel` gained `pillAlignment`) rather than writing a new
`BoxDecoration`/`Border.all` inline — per CONSTITUTION.md design
principle 5 ("a value used twice becomes a token"), the same rule applies
one level up to whole visual treatments, not just individual values.

---

## Selection border — `SelectedPillBorder`

**File**: `lib/core/widgets/selected_pill_border.dart`

**What it is**: the ONE selection treatment for a selected task or zone
anywhere in the app — a thin accent-colored outer ring, separated from
whatever it wraps by a thin, always-dark inner ring (so selection reads
correctly even when the wrapped content happens to already be
accent/blue-colored).

**Exact shape**:
- Outer ring: `theme.colorAccent`, width `SelectedPillBorder.accentWidth(theme)` (= `theme.borderWidthHairline`).
- Inner separator ring: `theme.colorScrim` (fixed dark in BOTH light and dark theme — this is why it's `colorScrim` and not a surface token), width `SelectedPillBorder.separatorWidth(theme)` (= `theme.borderWidthHairline * 2`).
- Both rings are concentric, inset inward from the caller's own `contentRadius` — never draw your own radius on top of this widget's rings, or the corners will mismatch (this exact bug happened once already; see the widget's own doc comment).

**API**:
```dart
SelectedPillBorder({
  required AmbleTheme theme,
  required BorderRadius contentRadius, // the pill's UNSELECTED radius
  required Color? fillColor,           // null if the caller paints its own fill (e.g. a blurred glass rail)
  required Widget child,
})
```

**Current call sites** (as of 2026-09-19):
- `lib/features/zone_grid/zone_grid_block.dart` — a selected zone-grid block's own category glyph badge.
- `lib/features/timeline/task_capsule_block.dart` — a selected task capsule's own category glyph badge.
- `lib/features/timeline/pending_task_pill.dart` — the quick-create draft pill's glass rail (always "selected" while it exists, so this is unconditional, `fillColor: null` since the fill is `GlassPillSurface`, painted separately).
- `lib/features/zone_grid/zone_grid_screen.dart` — the tap-and-drag-to-create-zone preview rectangle (`fillColor: theme.colorAccent.withValues(alpha: .09)`, translucent accent wash, `child: const SizedBox.expand()` since the preview has no content of its own).

**Never**: a raw `Border.all(color: theme.colorAccent, ...)` anywhere a
selection or an about-to-be-created zone/task needs marking. If a new
"this is selected/about to be created" visual is needed and it can't fit
`SelectedPillBorder`'s shape (a pill/rect with a `child`), that's a sign
to extend this widget, not to hand-roll a look-alike.

---

## Hour/time indicator — `TaskEdgeTimeLabel`

**File**: `lib/features/timeline/task_edge_time_label.dart`

**What it is**: the ONE "show a specific time in an accent-filled pill"
treatment, used everywhere the app needs to surface a task or zone's
start/end time as a live, floating indicator — task creation (the
long-press placement line), the pending/draft creation pill, Edit Mode's
selected/wiggling task, and zone move/resize. Optionally paired with a
full-width accent hairline (`showLine`, default `true`) that draws the
eye across the row — used only for the placement line, since every other
caller already sits on a visible block and a second line would be noise.

**The pill is always LEFT-aligned** (`TaskEdgeTimeLabelAlignment.start`,
the default) — settled 2026-09-19, requested directly: "hour start end has
blue bg on create/edit task (on create is on right, on edit is on left)
should be consistent on left." Before this, task creation's placement line
was right-aligned (an earlier, separate direct request, "time on the
right") while every other caller was left-aligned by construction (via
the "no `right:` constraint" pattern below) — a real, previously
undocumented inconsistency. Left won because it was already the majority
convention and matches "read the time where your eye already is, over the
hour gutter," not because right was wrong on its own merits.

**The pill now genuinely sits INSIDE the hour-gutter column, not merely
at the task pill's own left edge** — corrected a second time, same day,
requested directly: "the blue time from to, should not be on top and
bottom of task but on the left timeline where we [see] hours of day." The
first "left" fix above only walked each label back to the day column's
own x=0 (the gutter's RIGHT edge, immediately beside the task/zone pill)
— every `showLine: false` caller's `left:` formula now goes one step
further, landing at `theme.spacingSm` past x=0, the SAME x
`TaskBoundaryMarkers`' own hour ticks use (`leftInset: theme.spacingSm`
at its own call site in `timeline_screen.dart`). A task's start/end pill
now sits at the exact x its own hour tick would, just at the task's
actual y instead of a clock-hour y — genuinely reading as part of the
hour axis rather than as a label hanging off the block.

For a combined-layout task specifically, this also fixed a real, latent
bug the original `-widget.left` formula never accounted for: an
overlap-lane task (`columnOffset > 0`) was landing LEFT of the true
gutter x by however far its lane shifted it, since `columnOffset` was
never subtracted. Every `leftOffset`/`gutterOffset` now explicitly
includes whatever lane/column shift its own local coordinate frame
applies, not just the block's own `left`.

**The Weekly Zone Authoring Grid's own live start/end labels got the
identical fix, same day** — reported directly: "zones also blue time
from to on the left." `ZoneGridBlock`'s pair used a bare `left: 0`,
which only reached its own DAY COLUMN's local x=0 (`_axisWidth + (day -
1) * columnWidth` at the grid's own absolute x, per column), nowhere
near the axis's own labels. `ZoneGridBlock` now takes a `dayColumnLeft`
parameter from its caller so it can walk back to the grid's true x=0,
then forward to `theme.spacingSm` — the same x that grid's own "HH:00"
ticks use.

**Exact shape**:
- Pill: `theme.colorAccent` fill, `theme.radiusMd` corners, text in `theme.colorSurfacePrimary`, `theme.textCaption` weight 700.
- Hairline (when `showLine: true`): `theme.borderWidthHairline` tall, `theme.colorAccent`.
- Gap between pill and hairline: `theme.spacingSm`.

**API**:
```dart
TaskEdgeTimeLabel({
  required AmbleTheme theme,
  required TimeOfDay time,
  bool showLine = true,                                    // full-width hairline alongside the pill
  TaskEdgeTimeLabelAlignment pillAlignment = TaskEdgeTimeLabelAlignment.start, // .start (left) or .end (right)
})
```

**How a caller actually gets left alignment — two different mechanisms,
by design, not two competing conventions**:
1. **`showLine: false` callers** (the pill is the whole visual — pending pill, Edit Mode wiggling task, zone move/resize): position with `Positioned(left: <gutter offset>, ...)` and **no `right:`** at all. With no `right:` the box shrink-wraps to the pill's own size and sits wherever `left` puts it — no `pillAlignment` needed, the box itself already controls the side. Dropping `right:` (rather than adding an alignment param) is deliberate here: it needed no change to `TaskEdgeTimeLabel` itself and no change to five already-working callers when this was first built.
2. **`showLine: true` callers** (currently only the placement line): the hairline genuinely needs the WHOLE width (`Positioned(left: 0, right: 0, ...)`, `Expanded` inside), so shrink-wrap isn't available — this is what `pillAlignment` exists for. Pass `pillAlignment: TaskEdgeTimeLabelAlignment.start` (the default — most callers can omit it) to keep the line's full-width stretch while still moving the pill itself to the left end of that stretched Row.

If you're adding a new caller: prefer mechanism 1 (drop `right:`) whenever
you don't need a full-width hairline: it's simpler and needs no parameter.
Reach for `pillAlignment` only if you genuinely need `showLine: true`'s
full-width line alongside a left-pinned pill.

**Current call sites** (as of 2026-09-19):
- `lib/features/timeline/place_task_line.dart` — the long-press placement line (`showLine: true`, `pillAlignment: start`).
- `lib/features/timeline/pending_task_pill.dart` — two labels (start/end), `showLine: false`, left via mechanism 1.
- `lib/features/timeline/timeline_screen.dart` (`_leftEdgeLabel`) — Edit Mode's selected/wiggling task, `showLine: false`, left via mechanism 1.
- `lib/features/zone_grid/zone_grid_block.dart` — zone move/resize inside the Weekly Zone Authoring Grid, `showLine: false`, left via mechanism 1.
- `lib/features/timeline/zone_background_block.dart` — zone move/resize on the Timeline's own Zone background, `showLine: false`, left via mechanism 1.
- `lib/features/zone_grid/zone_grid_screen.dart` — the tap-and-drag-to-create-zone preview's own start/end labels (two separate `TaskEdgeTimeLabel`s, `showLine: false`) — added 2026-09-19; this was previously a plain accent-colored `Text` with no background pill at all, the one remaining gap once zone move/resize already used the shared widget correctly.

**Never**: a plain `Text(time, style: TextStyle(color: theme.colorAccent))`
or any other ad hoc "show the time" treatment. If `TaskEdgeTimeLabel`
doesn't fit (e.g. you need BOTH edges of a range in one combined label
rather than two separate `TaskEdgeTimeLabel`s), that's a sign to extend
this widget's own API, not to build a fourth lookalike.

---

## Hour-axis label color — `theme.colorTextSecondary`

**What it is**: the ONE text color every "HH:00"/"HH:MM" hour-axis label
uses, on every screen that has an hour axis at all. Unified 2026-09-19,
requested directly: "hours of day have different color on different
screens... needs unified and documented in design system."

**Found before unifying**: the spatial Task view's own hour ticks
(`TaskBoundaryMarkers`, `lib/features/timeline/task_boundary_markers.dart`)
already used `theme.colorTextSecondary`; the Weekly Zone Authoring Grid's
own hour-axis labels (`lib/features/zone_grid/zone_grid_screen.dart`,
the `_axisWidth`-driven "HH:00" column) used a DIFFERENT token,
`theme.colorTextTertiary` — a real, visible divergence between the two
screens' otherwise-identical hour columns. There is no separate "Task
Edit Mode" hour-label path at all — Edit Mode renders the exact same
`TaskBoundaryMarkers` instance the spatial Task view's normal state
does, with no conditional styling, so that was never actually a third
case.

**Rule**: any new hour-axis label, on any current or future screen, uses
`theme.colorTextSecondary` — never `colorTextTertiary` or any other
muted-text token. `colorTextTertiary` stays reserved for its other,
unrelated uses elsewhere in the app (e.g. zone name labels).

**Current call sites** (as of 2026-09-19):
- `lib/features/timeline/task_boundary_markers.dart` (`TaskBoundaryMarkers`) — the spatial Timeline's own hour ticks (both normal state and Edit Mode — same widget, no divergence).
- `lib/features/zone_grid/zone_grid_screen.dart` — the Weekly Zone Authoring Grid's own hour-axis "HH:00" column.

---

## Current-time indicator — `CurrentTimeIndicator`

**File**: `lib/features/timeline/current_time_indicator.dart`

**What it is**: the "now" marker on the spatial Task view's hour gutter —
a red dot and hairline at the current minute, with the current time in a
neutral pill. Corrected 2026-09-19, requested directly: "current time the
red dot should not be close to screen edge, instead... 09:00 / 09:31
o-------- / 10:00" (i.e. NOT "09:00 / o-- 09:31------ / 10:00" — dot
before the time, misaligned with the hour column).

**Exact shape, left to right**: `[time pill] [gap] [dot] [line, filling the rest of the row]`.
- Time pill: `theme.colorSurfaceTimeline` fill (masks whatever's underneath, so "now" never clashes with an hour label it's overlapping), `theme.radiusSm` corners, text `theme.textCaption` weight 700 in `theme.colorTextPrimary`.
- Dot: `theme.spacingSm` square, `theme.colorTaskAlert`, circular.
- Line: `theme.borderWidthHairline` tall, `theme.colorTaskAlert`, `Expanded` to fill the row.
- Whole row starts at `leftInset` — the SAME x [TaskEdgeTimeLabel]/`TaskBoundaryMarkers` use on this screen (`theme.spacingSm` at the Timeline's own call site), so "now" reads as the emphasised member of the same hour column, not a separate element starting at a different x.

**Why not `FractionalTranslation` on the whole row** (the previous
mechanism): once the time pill sits INSIDE the row (rather than as a
separate `Positioned` overlay past a fixed-width dot), the row's own
height is driven by the pill — translating the WHOLE row up by half
of THAT height would shift the dot/line off the true current-minute y
by half the pill's own extra height. The dot and line instead sit
inside a fixed `theme.spacingSm`-tall box (matching the dot's own
size), and the whole assembly is shifted up by exactly half THAT fixed
height via `Transform.translate` — so the dot/line's own center, not
the row's or the pill's, lands on the current minute.

**Never**: a `Positioned`-overlay time pill layered on top of a
[dot, line] `Row`, or any layout where the row's own sizing child isn't
the same element the vertical anchor is computed against — that
combination is exactly what caused both bugs this fix corrects (dot
before the time, and misalignment with the hour column).

---

## Selected zone z-order — `selectedZonesLast`

**File**: `lib/shared/services/zone_selection_order.dart`

**What it is**: the ONE rule for ordering a list of zones before
rendering them inside a `Stack` — a selected zone paints LAST (i.e. on
top) among its siblings. Added 2026-09-19, requested directly: "selected
zone z index goes to top of stack."

**Why this exists as a real bug, not a theoretical one**: both the
spatial Timeline and the Weekly Zone Authoring Grid explicitly allow
zones to overlap or sit adjacent (a designed-for, common case — see
`_Phantom`'s own doc comment in `zone_grid_screen.dart`), and a zone's
resize handles deliberately extend PAST its own bounds (both screens'
zone-rendering `Stack`s are `Clip.none`). Since Flutter's `Stack` paints
strictly in child-list order and the underlying zone list carries no
reliable order of its own (repository insertion order), an unselected
zone rendered after the selected one could paint its own fill/handles
directly over the selected zone's ring/handles/live-edge labels.

**API**:
```dart
List<Zone> selectedZonesLast(Iterable<Zone> zones, Set<String> selectedIds)
```
Stable sort — ties (both selected, or both unselected) keep their
original relative order; only the selected/unselected boundary changes.

**Current call sites** (as of 2026-09-19):
- `lib/features/timeline/timeline_screen.dart` — the spatial Task view's own zone band, via a `Consumer` reading `zoneEditSelectionProvider` (the outer `_DayTimelineState` is a plain, non-Riverpod-aware `State`, so a local `Consumer` is what reads the selection to reorder against, mirroring how `_DraggableZoneBlock` itself is already Riverpod-aware for the same "read `ref` locally rather than thread it" reason).
- `lib/features/zone_grid/zone_grid_screen.dart` — each day column's own zone list, ahead of the `_block(...)` builder call.

**Never**: rely on a zone repository's own return order for render
z-order, or sort inside the zone's own block widget (`ZoneBackgroundBlock`/`ZoneGridBlock`) — a block only knows its OWN selection state, not
its siblings', so reordering has to happen one level up, where the
whole list is visible at once.

---

## Badge/label chip — `AppBadgeChip`

**File**: `lib/core/widgets/app_badge_chip.dart`

**What it is**: the ONE "leading badge/icon + label, optionally
selectable" chip shape in the app — a `colorSurfaceSecondary` pill with a
leading visual (typically a `CategoryBadge`) and a bold label, used both
as a plain display badge and as an on/off selectable chip.

Systematized 2026-09-19, requested directly: "systematize badge (just
displayed, selectable variant on off)... selected border should be inner
not outer, not to change the size" — reference implementation was the
quick-create mini sheet's template chips (`TemplateChip`), whose old
selected-state border toggled `Container.border` between `null` and
`Border.all(...)`, growing the chip's total footprint on selection since
the border track wasn't even reserved when unselected.

**Selection ring is an OVERLAY, not `Padding` or `Container.border`** —
same technique `SelectedPillBorder` already uses (`Positioned.fill` inside
an unpadded `Stack`, painted on top of the full-size fill), so toggling
`selected` never changes the chip's own size. A single accent ring, not
`SelectedPillBorder`'s dual-ring (dark-separator + accent) treatment —
confirmed via AskUserQuestion: this chip's fill is always the neutral
`colorSurfaceSecondary`, never an arbitrary category color, so the risk
`SelectedPillBorder`'s second ring exists to guard against (an
accent-colored selection ring vanishing into an already-accent-colored
fill) doesn't apply here.

**Exact shape**:
- Fill: `theme.colorSurfaceSecondary`, `theme.radiusXl` corners.
- Padding: `theme.spacingMd` horizontal, `theme.spacingXs` vertical.
- Leading-to-label gap: `theme.spacingSm`.
- Label: `theme.textBody`, weight 700.
- Selection ring (selectable variant only): `theme.colorAccent` when
  `selected`, `Colors.transparent` otherwise, width
  `theme.borderWidthHairline` — always present in the tree once the chip
  is selectable, so its color-only swap never changes layout.

**API**:
```dart
AppBadgeChip({
  required AmbleTheme theme,
  required Widget leading,   // typically a CategoryBadge at the caller's own scale
  required String label,
  bool? selected,            // null = non-selectable "just displayed" variant, no ring, no gesture
  VoidCallback? onTap,       // required alongside non-null `selected`
})
```

**Current call sites** (as of 2026-09-19):
- `lib/features/timeline/template_chip_strip.dart` (`TemplateChip`) — the quick-create mini sheet's scrollable template row, the reference implementation this was extracted from.

**Never**: a `Container` with a `border` that's `null` when unselected —
that's the exact bug this widget exists to fix. If a badge/chip needs a
shape this doesn't cover (e.g. genuinely different fill logic per
category, not just a neutral background), extend this widget's API
first; only build a new one if the shape is fundamentally different (see
`AppSelectableChip` for the label-only, no-leading-icon, fill-swap chip
family this is deliberately NOT merged with — different visual family,
not a duplicate).

**On the scrollable row itself**: `TemplateChipStrip`'s horizontal
`ListView.separated` was checked against the rest of the codebase during
this pass and found to be the ONLY horizontally-scrollable badge/chip row
in the app — no sibling implementation exists to deduplicate against, so
it stays a plain `ListView` in its own file rather than becoming a second
systematized component. Revisit if a second horizontal-scroll chip row
shows up.

---

## Sheet drag handle — `AppSheetHandle`

**File**: `lib/core/widgets/app_sheet_handle.dart`

**What it is**: the small horizontal grip bar shown at the top of a
draggable sheet — the "this can be dragged/tapped" affordance. Purely
visual (no gesture handling of its own): a real caller wraps its own
`GestureDetector` around the whole header row and places this bar inside
via `Align`/`Positioned`, since the drag/tap target needs to span the
full row, not just the bar's own small hit box.

Systematized 2026-09-20, requested directly against a screenshot: "move
the handle higher up and make it lighter color, use token colors
available e.g. button subtle color." The quick-create sheet's handle
(`QuickCreateSheetHandle`, `quick_create_sheet_shell.dart`) used to draw
its own bar inline, filled with `colorTextSecondary` (a text-contrast
token, too heavy for a purely decorative grip) and centered in the whole
header row — putting it at the same vertical mid-point as the row's own
X/Schedule buttons, reading as one more control rather than a separate
"sheet can be dragged" affordance above the row's real content.

**Exact shape**:
- Size: `theme.spacingXl * 1.2` wide, `4` tall.
- Corners: `theme.radiusSm`.
- Fill: `AppButton.subtleTint(theme)` — the same low-alpha
  `colorTextPrimary` wash `AppButtonVariant.secondary` uses, not a
  text/icon-contrast token and not a bespoke alpha invented just for
  this bar.
- Position within its caller's header row: top-aligned with a small
  `theme.spacingXs` top inset, not centered in the row.

**API**:
```dart
AppSheetHandle({ required AmbleTheme theme })
```

**Current call sites** (as of 2026-09-20):
- `lib/features/task_detail/quick_create_sheet_shell.dart`
  (`QuickCreateSheetHandle`) — the quick-create mini sheet's own
  drag/tap-to-expand header handle; the reference implementation this
  was extracted from.

**Never**: a bare `Container` re-declaring this bar's size/color/radius
inline, and never `colorTextSecondary` (or any other text-contrast
token) for a purely decorative grip — reach for `AppButton.subtleTint`
instead, the app's one "subtle neutral tint on any surface" token,
already shared with `AppButtonVariant.secondary`'s own fill.

---

## Zone row hour label — `ZoneRowTimeLabel`

**File**: `lib/features/timeline/zone_container_block.dart`

**What it is**: the leading time text on a Zone view task row (a zoned
row via `_ZoneTaskRow`, or an unzoned row via `ZoneDayTimeline`'s own
unzoned-task branch) — e.g. "9:00 AM". Requested directly, twice, against
a side-by-side screenshot of the two views: "structurally its part of
task[s], but semantically it's timeline hour," and then "let's use...
same st[y]ling as spatial view." This is Zone view's answer to the
spatial Task view's `TaskBoundaryMarkers` hour-gutter labels — same text
style, same distance from the true screen edge — for a view that has no
shared time axis to place a real gutter column against.

**Why this can't just reuse `TaskBoundaryMarkers` directly**: that widget
`Positioned`s every label against ONE shared, continuous, absolutely-
positioned `Stack` spanning the whole day — every task block in the
spatial Task view is a sibling in that same `Stack`, all keyed to one
`pixelsPerMinute` coordinate space. Zone view has no such shared space:
its rows are children of a `ListView.separated` (`ZoneDayTimeline`),
flowing one after another with no absolute Y a label could be
`Positioned` against, and each row is nested arbitrarily deep inside its
own padding (a zone card's, or the list's own page inset) — unlike the
spatial view's flat, unnested Stack. A `Positioned` reaching the literal
screen edge would need ONE `Stack` spanning the entire scrolling list,
but a label `Positioned` there wouldn't scroll WITH its own row, only sit
fixed relative to the viewport — wrong for a per-row label.

**What it does instead**: a small `Stack` scoped to just ONE row, with
the label `Positioned` at a NEGATIVE `left` reaching back out through
however much padding that specific row sits inside (the caller supplies
this as `leftPaddingToEscape` — every padding layer between the row and
the true screen edge, summed) to land at the same fixed distance from the
screen edge the spatial view's own labels sit at. This scrolls correctly
(the label is still an ordinary descendant of an ordinary list item)
while visually reaching all the way to the screen edge — the closest a
per-row, list-flowed layout can get to genuinely sharing the spatial
view's own `Positioned` mechanism, rather than faking the end position
with `Transform.translate` (this widget's own predecessor — see
docs/ERROR_LOG.md's entry on why a negative `Container(margin:)`
alternative broke the row's layout outright, and why `Transform` worked
but was a coordinate hack rather than shared structure).

**Exact shape**:
- Target edge distance: `zoneRowTimeLabelEdgeInset` = **16.0px** from the
  true screen edge — matches `TaskBoundaryMarkers` EXACTLY
  (`leftInset: theme.spacingSm` (8) + that widget's own further
  `theme.spacingSm` (8) internal text padding = 16).
- Reserved width in the caller's own `Row`:
  `zoneRowTimeLabelReservedWidth` = **66.0px** — mirrors the spatial Task
  view's own hour-GUTTER width (`_hourGutterWidth`, private to
  `timeline_screen.dart`, kept as a separate literal here rather than
  exported since it's one shared number, not shared logic). The label
  TEXT itself paints outside this box entirely; the box only holds space
  for whatever comes after it (a category badge, or a title).
- Text style: `theme.textCaption` + `theme.colorTextSecondary` — the
  exact style `TaskBoundaryMarkers` uses, not `textTaskTitleZone` (the
  row's own title scale) or `colorTextTertiary` (an earlier, since-
  superseded convention matching the Zone Authoring Grid's own hour-axis
  labels instead).

**API**:
```dart
ZoneRowTimeLabel({
  required AmbleTheme theme,
  required String text,
  required double leftPaddingToEscape, // sum of every padding layer to the true screen edge
  required double reservedWidth,       // usually zoneRowTimeLabelReservedWidth
})
```

**Current call sites** (as of 2026-09-20):
- `_ZoneTaskRow` (`zone_container_block.dart`) — a zoned task's own
  leading time column. `leftPaddingToEscape` = `spacingScreenPadding`
  (24, `ZoneDayTimeline`'s list page inset) + `spacingMd` (16,
  `ZoneContainerBlock`'s own card padding) = 40. Wrapped in the row's
  existing `GestureDetector` (tap/drag-to-reschedule) — a `Positioned`
  child still hit-tests correctly wherever it actually paints, so
  escaping the label doesn't disturb its own gesture handling.
- The unzoned task row (`ZoneDayTimeline`) — same 40px total, reached via
  the row's own `Padding(left: spacingMd)` wrapper instead of a zone
  card's padding. Kept at the identical total specifically so zoned and
  unzoned times stay lined up with each other, not just with the spatial
  view.

**Never**: a `Transform.translate` or negative `Container(margin:)` to
fake this position — the margin version measurably breaks any ancestor
that needs to MEASURE this subtree (an `IntrinsicWidth`, a `Flexible`
resolving against intrinsics), and `Transform` alone works but leaves the
"why does this text visually escape its own box" reasoning scattered as
a comment at each call site instead of owned by one shared widget. Add a
new call site here, with its own correct `leftPaddingToEscape`, rather
than reinventing the escape math inline.

---

## Adding a new canonical component to this file

When a visual treatment gets used a third time (per CONSTITUTION.md
design principle 5's "second location" trigger for tokens, applied here
one level up to whole components): promote it to a real shared widget in
`lib/core/widgets/` (app-wide) or the relevant feature directory (if it's
genuinely scoped to one feature, like `TaskEdgeTimeLabel`'s Timeline/Zone
scope), then add a section to this file with the same shape as the two
above: what it is, its exact token values, its API, every current call
site, and an explicit "never" line naming the ad hoc pattern it replaces.
