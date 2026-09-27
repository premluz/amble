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

## Horizontal spacing — two values, no third

The app has exactly **two** horizontal measurements. Every screen derives
from them; nothing re-states them, and nothing invents a third.

| Token | Value | What it measures |
| --- | --- | --- |
| `theme.spacingScreenPadding` | 16 | Screen edge → page content. The top nav's "Day", the settings gear opposite it, page titles, list rows, sheet bodies, **and the Timeline's hour labels in both the spatial and non-spatial views.** |
| `theme.spacingHourGutter` | 90 | Screen edge → Timeline *content* (a task pill, a zone card). The hour labels occupy the space between this and `spacingScreenPadding`. |

**The rule:** any horizontal distance from a screen edge is one of these
two tokens. If you are about to write a number, an arithmetic expression
combining a token with a literal (`66 + spacingScreenPadding`), or a new
top-level `const` for a side inset — stop; that is the drift this section
exists to prevent.

### Why it is written down

Added 2026-09-21 after a screenshot marked the intended inset down both
screen edges and showed the top nav, the calendar under it, and the
timeline's hour labels each landing somewhere different. Reported
directly: *"we need a coherent system that can manage this spacing without
drift."*

The drift was structural, not careless. The same two distances were
expressed three different ways:

- the spatial Timeline built its gutter as `66 + spacingScreenPadding`;
- the non-spatial Zone view hardcoded the same distance as a top-level
  `const zoneContentLeftInset = 90.0`;
- the page inset was a separate token at 24, so the hour labels (16) and
  the nav above them (24) disagreed by 8px.

Because `90` and `66 + 24` were *equal by coincidence*, the two views
looked aligned — right up until the page inset changed, at which point
they silently came apart. The non-spatial view was named as the reference
("the right size of it comes from the non-spatial view"), so
`spacingScreenPadding` moved **out** to 16 to meet the hour label already
sitting there, rather than the hour moving in.

### How it is enforced

`test/core/tokens/horizontal_spacing_system_test.dart` pins the system:

- both themes agree on both values (a per-theme side inset would move the
  page's edge when the user switched theme);
- `zoneRowTimeLabelEdgeInset == spacingScreenPadding` and
  `zoneContentLeftInset == spacingHourGutter` — these two are top-level
  `const`s in the non-spatial view, which **cannot read the theme**, so
  nothing in the type system stops them from disagreeing. This is the
  check that catches it;
- the gutter still leaves ≥8px clearance beside the widest hour label
  ("12:00 AM", 57.6px), the overlap rule from a real reported bug;
- `timeline_screen.dart` reads the token and has not reintroduced a local
  `_hourGutterWidth` constant.

### The one exception

The **Weekly Zone Authoring Grid** (`zone_grid_screen.dart`) keeps its own
denser axis (`_axisWidth`, 60) and its own 8px label inset. Confirmed
directly: *"edit zone view has its own more dense space, which is fine,
keep it as is."* It is a distinct authoring surface, not a page view of
the day, and its axis width also drives tap-target maths for
drag-to-paint. Do not fold it into the tokens above.

---

## Two-font system — mono for values, DM Sans for prose

The app uses exactly two fonts, and every `TextStyle` in `semantic_theme
.dart` is built from one or the other via `TypePrimitives.fontFamily`
(the mono family) or an explicit DM Sans override — there is no third
family and no per-call-site font choice.

**The rule**: a token whose name ends in `Mono` (`textBodyMono`,
`textCaptionMono`, …) is for a genuinely NUMERIC/TEMPORAL value — a
clock time, a duration, a countdown, a raw number read at a glance. Its
plain twin (`textBody`, `textCaption`, …) is DM Sans, for prose — labels,
names, captions, anything read as a sentence or a word rather than a
value. The two are NOT interchangeable "same size, different mood"
options; picking the wrong one is a real bug, not a style preference —
see the incident below.

**Known correct call sites** for the mono twin: `TaskBoundaryMarkers`
(the spatial Task view's own hour-gutter labels), `ZoneContainerBlock`'s
own header time-range text, `CurrentTimeIndicator`, and any other place a
clock time or duration renders as its own short, self-contained label.
The compact task-start column uses the shared `textTaskEdgeTime` token
through `ZoneRowTimeLabel` and `TaskEdgeTimeLabel`.

**Incident, 2026-09-22**: `ZoneRowTimeLabel` and `ZoneContainerBlock`'s
own header time-range text both read `theme.textCaption` (DM Sans)
instead of `theme.textCaptionMono` — reported directly, comparing the two
Timeline views side by side: "between views hours on spatial zone are
not mono font, but spatial ther are mono... there is a rule in design MD
about it?" There WASN'T one written down anywhere (the rule only lived as
scattered doc comments on the token fields themselves in `semantic_theme
.dart`) — this section is that missing rule, added alongside the fix so
the next divergence is caught by a person reading this file rather than
rediscovered from a screenshot.

**Never**: reach for `textCaption`/`textBody` at a call site rendering a
clock time, a duration, or any other value a user reads as a number —
even if the surrounding text nearby happens to already be on the plain
twin. Check what the token's OWN doc comment in `semantic_theme.dart`
names as its call sites before assuming either family is the safe
default.

---

## Timeline annotation type scale

The base type scale is fixed and shared across themes:

| Primitive | Size | Current timeline use |
| --- | ---: | --- |
| `TypePrimitives.size0` | 11px | `textZoneName`, `textTaskEdgeTime`, and the small task-title rung |
| `TypePrimitives.size1` | 12px | `textCaptionMono`, ordinary captions, and the default task-title rung |
| `TypePrimitives.size2` | 14px | the largest task-title rung and zone-card header titles |
| `TypePrimitives.size3` | 16px | regular body text and larger prose |

Spatial/edit zone names use `AmbleTheme.textZoneName` at `size0`, one rung
below the 12px hour axis, so vertical labels stay subordinate to task
content. Task start/end times use `AmbleTheme.textTaskEdgeTime` at the same
11px compact scale. `ZoneNameLabel`, `ZoneGridBlock`'s rotated title, and
`TaskEdgeTimeLabel`/`ZoneRowTimeLabel` are the shared owners; call sites do
not invent a local `fontSize`.

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

## Zones — saved blocks and ghost placeholders

Saved weekly zones use `ZoneGridBlock`: `colorSurfaceSecondary`, `radiusSm`,
and the compact `textZoneName` label. Body drags move the current selection
in both time and weekday; top/bottom handles resize time; side handles extend
the active zone's hours to additional weekdays. Empty grid space remains scrollable.
Batch actions read the current selected IDs at invocation, not the set captured
when the toolbar first appeared.

The new-zone and existing-zone extension previews share `_marqueeBody` and
`_Phantom` in `zone_grid_screen.dart`:

- One `SelectedPillBorder` encloses the span: accent ring, theme-surface
  separation, `radiusMd`, and accent fill at 9% alpha.
- During side extension the moving boundary follows pointer pixels; weekday
  ghost membership and the saved placements snap to columns.
- Each covered weekday has a non-interactive ghost: `colorSurfaceSecondary`
  at 55% alpha, `radiusMd`, a centered rotated `textCaption` title in
  `colorTextSecondary`, and ellipsis overflow. No independent accent outline.
- Ghosts are inset by `spacingXs` horizontally and half `spacingXs` vertically.
  They preview placement only; persistence occurs on release or confirmation.
- Hide the original source block visually during extension, preserving its
  gesture element. Only the shared marquee and its handles should be visible.

## Task pills — saved and draft materials

Saved tasks use `TaskCapsuleBlock` and the current `radiusPill` setting.
`PendingTaskPill` is an unsaved placement and uses `GlassPillSurface` in
`GlassPillMaterial.glass`: theme `colorSurfaceBlurOverlay` over a clipped
`blurOverlaySigma` backdrop blur. It carries no invented category glyph.
The draft is wrapped in `SelectedPillBorder` with `fillColor: null`, preserving
its glass material and the same accent/theme-surface selection rings as zones.
Imported calendar pills use `GlassPillMaterial.flat` without blur; they are real
calendar entries, not ghosts. Zone ghosts remain flat translucent panes rather
than adopting the task pill's glass material.

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
- Pill: `theme.colorAccent` fill, `theme.radiusMd` corners, text in `theme.colorSurfacePrimary`, `theme.textTaskEdgeTime` weight 700.
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

## Task manipulation targets — `TaskManipulationTargets`

**Files**: `lib/features/timeline/task_manipulation_targets.dart`,
`task_compact_controls.dart`, and `cancel_safe_vertical_drag.dart`.

The task shows exactly two resize dots, centered on the selection stroke at
the capsule's top and bottom. There are no displaced Start/End controls, visible labels, or
connector lines. Enlarging interaction geometry must not reposition the dots
or the visual capsule.

The primary task reserves a `spacingMinTapTarget`-wide interaction area.
Resize regions use the existing fitted handle-height helper so they cannot
overlap. On pills shorter than that token, the strip beside the pill stays
move-only. This preserves all three operations, but does not promise a full
48 × 48 resize target on a tiny capsule. Secondary selected tasks retain
in-pill handles and group-resize behavior. Primary-task stacking remains.

Handle taps are consumed. They cannot toggle the task, clear selection, create
a task, or reach a neighboring task. Pointer cancellation restores the
pre-gesture preview and selection; `CancelSafeVerticalDrag` coalesces Flutter
recognizer cancellation and raw pointer cancellation into one callback.

**Never**: use `Clip.none` as evidence that painted overflow is hittable, give
overlapping Start/End detectors the same bounds, remove handles from secondary
selected tasks, or treat cancellation as a successful drag end.

---

## Resize handle visual — `ResizeHandleDot`

`lib/core/widgets/resize_handle_dot.dart` owns the visual used by task and
zone time handles, saved-zone side handles, and the new-zone marquee.
Diameter is `spacingSm`; fill is `colorAccent`. A border painted inside the
dot uses `colorSurfacePrimary` at `borderWidthHairline / 2`, separating it
from the accent selection outline in both light and dark themes.

Place its center inward by `ResizeHandleDot.edgeInset(theme)` (half the
selection stroke width) from the geometric edge, on the stroke's centerline.
Top moves down, bottom up, left rightward, and right leftward. Position the
visual independently of the larger invisible gesture target.

Selected weekly zones expose left/right handles that copy their hours and
zone identity to the crossed weekdays through the existing day-fill operation.
Time handles change start/end. Dragging the body moves the existing placement
in time or to another weekday, preserving its ID; only side handles copy to
additional days. During day-fill, replace the source's visible selection with
ONE expanding marquee and per-day ghosts, using the same marker as an unsaved
zone. Keep the source gesture mounted but invisible until release; preview
handles must not intercept that drag. New-zone marquee side resizing keeps the opposite edge fixed and
tracks horizontal pixels continuously, snapping the final outline to days
on release. Key each handle by its edge so adding day previews cannot replace
the recognizer during an active gesture.

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

## Sheets — container, handle, header row

Created 2026-09-22, requested directly: "let's unify all drawer sheets...
sheets should have handles on top center, the style and position should
be defined (reference is new task (quick add))... let's unify interaction
and animation... there might already be a section for sheets that should
define position of CTA top right and top left close button... spacing
should be defined." Consolidates what was one narrower section
(`AppSheetHandle` alone) into the full shape every slide-up sheet in the
app should share: the container (`AppSheet`), the drag handle, and the
header row's button positions.

**The reference is the Timeline's quick-create sheet**
(`quick_create_sheet_shell.dart`/`quick_create_overlay.dart`) — the first
sheet built with this exact header row shape (handle behind, primary
action right, close left), now the pattern every other sheet should
match rather than re-deriving its own header layout.

### The container — `AppSheet`

**File**: `lib/core/widgets/app_sheet.dart`

**What it is**: the ONE entry point for a slide-up modal — a rounded
Material bottom sheet everywhere except iOS/macOS, where it uses
Cupertino's native modal-popup styling. Screens must never reach for
`showModalBottomSheet`/`showCupertinoModalPopup` directly (per
CONSTITUTION.md design principle 4).

**Inline creation sheets and toolbox:** Edit task drafts and new-zone naming
sheets remain in-tree so the timeline/marquee stays interactive. Edit publishes
`AppShellChromeController.setDockObscured(true)` for the whole draft lifetime,
including keyboard movement and sheet dismissal animation. `AppBottomDock`
suppresses its rendering and hit targets immediately: empty action groups alone
are insufficient because exiting buttons keep painting above nested sheets.
Clear suppression when the draft closes or the owning Edit route releases chrome.
This is toolbar suppression, not promotion to a modal root overlay.

**Exact shape**:
- Corners: `theme.radiusModal`, top corners only.
- Fill: `theme.colorSurfaceOverlay` — the top of the elevation ramp, so a
  sheet reads as a layer ABOVE the page behind it rather than the same
  flat surface (a real, reported bug: "sheets across the app should have
  next surface level to bg").
- Barrier: `theme.colorScrim`.
- Body padding: `theme.spacingLg` on all sides (`padded: true`, the
  default) — see "Spacing" below.
- Three sizes (`AppSheetSize`): `small` (sizes to content — the default,
  and what every sheet in this section uses), `half` (fixed 50% of
  viewport, scrollable), `nearFull` (matches `StepScaffold`'s near-full
  inset). Picking a size larger than `small` is for a picker/list with
  real content, not for a form that should just size to itself.
- Entrance/exit: `motionSheetSlide` (180ms), `curveDecelerate` in and
  `curveStandard` out. Only the sheet surface translates, not the viewport.
- Plain mode slides immediately. `autofocusesKeyboard: true` mounts the
  focused field immediately but holds the surface until the IME's final
  `motionSheetSlide` window. Android 11+ supplies actual IME fraction,
  duration and inset through `AndroidKeyboardAnimation`; the surface and
  keyboard finish together even when the IME opens slowly or starts late.
- An already-open keyboard uses the normal slide. Older Android/iOS use
  `motionKeyboardSettle` as a grace period; hardware/suppressed keyboards
  have a bounded request timeout. These are explicit unmeasured paths,
  not a promise of native synchronization on those platforms.
- Keyboard clearance belongs to `AppSheetMotion`, outside the translated
  surface. No global remembered height, no `AnimatedPadding`, and no
  additional caller-owned keyboard padding.
- Full-screen route helpers retain their separate navigation behavior.

**API**:
```dart
AppSheet.show<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool padded = true,           // false only for content managing its own edge-to-edge layout
  AppSheetSize size = AppSheetSize.small,
  bool autofocusesKeyboard = false,
})
```

### The drag handle — `AppSheetHandle`

**File**: `lib/core/widgets/app_sheet_handle.dart`

**What it is**: the small horizontal grip bar shown at the top-center of
every sheet — the "this can be dragged/tapped, or swipe down to close"
affordance. Purely visual (no gesture handling of its own): a real
caller wraps its own `GestureDetector` around the WHOLE header row (not
just the bar) and places this bar inside via `Align`/`Positioned`/
`Center`, so the drag/tap target is the full row's width and height, not
a precise hit on a 4px bar.

**Exact shape**:
- Size: `theme.spacingXl * 1.2` wide, `4` tall.
- Corners: `theme.radiusSm`.
- Fill: `AppButton.subtleTint(theme)` — the same low-alpha
  `colorTextPrimary` wash `AppButtonVariant.secondary` uses, not a
  text/icon-contrast token and not a bespoke alpha invented just for
  this bar.
- **Position: top-CENTER of the header row, `theme.spacingSm` top
  inset.** (2026-09-22 — nudged down one rung from the original
  `theme.spacingXs`, requested directly as the unification's own
  reference value: "slightly lower than currently.") Never centered in
  the whole (button-height) row — that puts it at the same vertical
  mid-point as the row's own Close/CTA buttons, reading as one more
  control rather than a separate "sheet can be dragged" affordance
  sitting above the row's real content.
- Interaction: dragging down past a distance-or-velocity threshold
  closes the sheet — the SAME "handle to dismiss" gesture as tapping
  Close, never a different outcome. A sheet with more than one height
  state (only the quick-create overlay, so far) settles into its own
  intermediate states first; a plain single-height sheet just closes.
  See "The drag gesture" below for how that gesture is wired and
  whether it's visually responsive during the drag.

**API**:
```dart
AppSheetHandle({ required AmbleTheme theme })
```

**Never**: a bare `Container` re-declaring this bar's size/color/radius
inline, and never `colorTextSecondary` (or any other text-contrast
token) for a purely decorative grip — reach for `AppButton.subtleTint`
instead, the app's one "subtle neutral tint on any surface" token,
already shared with `AppButtonVariant.secondary`'s own fill.

### The drag gesture — `AppDragToCloseHandle`, responsive by default

**File**: `lib/core/widgets/app_drag_to_close_handle.dart`

**Added 2026-09-26**, reported directly: "the handle pattern in sheets
should be responsive when grabbed to drag, similar to quick create task
on timeline... but sometimes when release earlier it stays with
revealed button and not clickable" — actually two related reports about
the SAME underlying gap: `new_zone_sheet.dart`'s handle didn't visually
move at all while dragging (a bare `_dragDistance` accumulator with no
live feedback, only a threshold check on release), unlike the Timeline
quick-create task sheet's own handle, which visually follows the finger
in real time via `QuickCreateSheetHeightController`.

**Two sheets had independently hand-rolled the identical
non-responsive gesture** before this: `quick_capture_sheet.dart` and
`new_zone_sheet.dart`. Both now use this shared widget instead — this
is the "third near-identical implementation" trigger the header-row
section above says promotes a hand-rolled pattern into a real shared
one (per CONSTITUTION.md design principle 5).

**What it is**: wraps `AppSheetHandle`'s visual bar with the actual
drag gesture — updates a small `AppDragToCloseController` as the finger
moves, and on release decides close-vs-snap-back using the same
distance-or-velocity threshold every handle already used.

**Two modes, chosen per call site**:
- **`responsive: true` (the default).** The sheet visually translates
  with the finger DURING the drag — `controller.offset` updates on
  every `onVerticalDragUpdate`, and the caller's own `build` reads it
  (via `ListenableBuilder`) to apply `Transform.translate`. Releasing
  short of the threshold animates the offset back to zero
  (`theme.motionFast`/`curveStandard`, the same easing every other
  sheet transition in this section uses); releasing past it calls
  `onClose` and leaves the sheet at rest for whatever exit animation
  the caller's own close path plays. This is the norm now — a sheet
  that doesn't visibly respond to being grabbed reads as unresponsive
  or broken, which is exactly what both reports above were describing.
- **`responsive: false`.** The controller's `offset` never leaves
  zero — the drag is still tracked and the same threshold still
  decides close-vs-nothing on release, but nothing visually moves
  until then. This is the EXACT previous behavior every existing
  caller had before this widget existed; kept as an explicit opt-out
  rather than removed, for a sheet where live translation would fight
  its own layout (nothing currently needs this — it exists so a future
  caller isn't forced into responsiveness if it genuinely can't
  support it, not because two behaviors are equally recommended).

**Threshold** (unchanged from what every caller already had): drag
distance past `theme.spacingXl` (default; overridable per call site via
`closeDistance`), OR release velocity past `800` px/s
(`closeVelocity`) — whichever comes first.

**API**:
```dart
final controller = AppDragToCloseController();   // create once, dispose in State.dispose

AppDragToCloseHandle({
  required AmbleTheme theme,
  required AppDragToCloseController controller,
  required VoidCallback onClose,
  bool responsive = true,
  double? closeDistance,     // defaults to theme.spacingXl
  double closeVelocity = 800.0,
})
```

The caller's own `build` composes the live offset in, typically as the
OUTERMOST transform around the sheet's whole content (or, for a sheet
that already has its own entrance/exit `Transform` — see `new_zone_sheet
.dart` — as a SECOND, separate one nested inside it, so the two never
fight over the same offset value):
```dart
ListenableBuilder(
  listenable: controller,
  builder: (context, child) => Transform.translate(
    offset: Offset(0, controller.offset),
    child: child,
  ),
  child: /* the sheet's own content */,
)
```

**Current call sites**:
- `lib/features/task_detail/quick_create_sheet_shell.dart`
  (`QuickCreateSheetHandle`) — NOT built on this widget. It drives its
  own richer 3-state (small/minimised/full) fraction system
  (`QuickCreateSheetHeightController`), a genuinely different, larger
  feature than "drag down enough and it closes." This remains the
  reference for what a fully responsive handle should FEEL like; this
  section's own widget generalizes that feel to the simpler one-size
  case every other handle-bearing sheet actually has.
- `lib/features/inbox/quick_capture_sheet.dart` — `responsive: true`
  (the default). Previously a bare accumulator with no live feedback.
- `lib/features/zone_grid/new_zone_sheet.dart` — `responsive: true`
  (the default). The sheet this was reported against directly.

**Never**: a THIRD hand-rolled `GestureDetector` reimplementing this
same accumulate-then-threshold gesture at a new call site — every sheet
with a drag-to-close handle uses this widget now.

### The header row — button positions

**Not yet its own shared widget** — this is the settled LAYOUT rule every
sheet's own header `Row`/`Stack` should follow by hand, until a third
near-identical implementation appears (per CONSTITUTION.md design
principle 5), at which point it should be promoted the same way
`AppSheetHandle` was.

**The rule**:
- **Close — top-LEFT.** Always `HeaderCircleButton` (`app_step_scaffold
  .dart`), never a bare `IconButton`/IconData without the circular fill.
  Closes the sheet and ONLY closes it — never also submits/saves
  whatever the sheet is for. The only three ways a sheet closes: tapping
  Close, dragging the handle down past its threshold, or (Material only)
  tapping the scrim outside it.
- **Primary action — top-RIGHT.** A small circular `HeaderCircleButton`
  for a single-glyph action sitting IN the header row itself (e.g. Quick
  Capture's check-mark Done), or a pill `AppButton` for a labeled action
  (e.g. quick-create's "Schedule"). Which shape depends on whether the
  action has a short label worth showing — a glyph-only button for
  something already obvious from context (a check mark after typing a
  title), a labeled pill when the verb itself is the point.
- **A secondary/supporting control** (e.g. Quick Capture's mic button)
  sits between Close and the primary action, same size as the primary
  action's own `HeaderCircleButton` so the row's icons read as one
  family — confirmed directly ("voice record should be same size as
  done").
- **The handle sits BEHIND the whole row** (`Positioned.fill`, painted
  first), not squeezed into its own separate strip above the buttons —
  its drag/tap target is the entire row's width and height; Close and
  the primary action paint ON TOP of it and win their own taps, but any
  part of the row they don't cover still drags/dismisses.
- **A sheet's primary action must not also silently close it** unless
  closing genuinely IS the action's whole outcome (e.g. a picker whose
  only job is "pick one, done"). A capture/create flow whose primary
  action is "add another one of these" (Quick Capture's Done, matching
  its own keyboard-submit) stays open on success — see Quick Capture's
  own doc comment for the reasoning and docs/DECISIONS.md for the
  2026-09-22 entry that aligned its top-right button to this rule (it
  used to close on every save; now it only closes via Close/swipe-down,
  exactly like the keyboard's own submit already did).

**Reference implementation** — `quick_create_overlay.dart`'s header
`Stack`:
```dart
Stack(
  children: [
    Positioned.fill(child: /* the handle's GestureDetector, AppSheetHandle centered inside */),
    Positioned(top: 0, bottom: 0, right: 0, child: Center(child: /* primary action */)),
    Positioned(top: 0, bottom: 0, left: 0, child: Center(child: /* Close */)),
  ],
)
```

### Spacing

Every value below is the same one the quick-create sheet already uses —
nothing new invented for this unification, only named as the shared rule:

| What | Token | Value |
| --- | --- | --- |
| Sheet body padding (all sides) | `theme.spacingLg` | 24 |
| Handle's own top inset | `theme.spacingSm` | 8 |
| Header row height | `theme.spacingXl * 1.8` | 72 |
| Gap between Close/mic/primary-action buttons in the header row | `theme.spacingSm` | 8 |
| Header row → body content below it | `theme.spacingSm` | 8 |
| A `HeaderCircleButton`'s own size | `theme.spacingXl` | 40 |

**Never**: a bare numeric literal for any of the above at a new call
site — every one of these is already a named token on `AmbleTheme`.

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
  true screen edge — `theme.spacingScreenPadding` (16), the SAME token
  `TaskBoundaryMarkers`' own `leftInset` reads directly at its
  `timeline_screen.dart` call site. (Both used to be built from a
  different formula — `spacingSm + spacingSm` — before
  `spacingScreenPadding` existed as its own token; pinned by
  `horizontal_spacing_system_test.dart` now so the two can't drift
  independently again.)
- Reserved width in the caller's own `Row`:
  `zoneRowTimeLabelReservedWidth` = **0.0px** (as of 2026-09-20 — see
  that constant's own doc comment for why zero is correct: the label
  TEXT itself paints outside this box entirely via the negative
  `Positioned.left` above, so nothing needs to reserve space for it).
- Text style: `theme.textTaskEdgeTime` + `theme.colorTextSecondary` — the
  compact shared task-time style used by `TaskEdgeTimeLabel` in spatial and
  Edit mode. It stays monospace, but is 11px so a leading task time does not
  compete with the 12px `TaskBoundaryMarkers` hour axis. Not
  `textTaskTitleZone` (the row's own title scale) or `colorTextTertiary`.

**API**:
```dart
ZoneRowTimeLabel({
  required AmbleTheme theme,
  required String text,
  required double leftPaddingToEscape, // sum of every padding layer to the true screen edge
  required double reservedWidth,       // usually zoneRowTimeLabelReservedWidth
})
```

**Current call sites** (as of 2026-09-22):
- `_ZoneTaskRow` / `_ZoneExternalEventRow` (`zone_container_block.dart`)
  — a zoned row's own leading time column. `leftPaddingToEscape` =
  `zoneContentLeftInset` (90, where a zone card itself starts — matches
  the spatial view's own hour-gutter width, see "Horizontal spacing"
  above) + `spacingMd` (16, `ZoneContainerBlock`'s own card padding) =
  106. Wrapped in the row's existing `GestureDetector` (tap/drag-to-
  reschedule) — a `Positioned` child still hit-tests correctly wherever
  it actually paints, so escaping the label doesn't disturb its own
  gesture handling.
- The unzoned task row (`ZoneDayTimeline`) — same 106px total, reached
  via `zoneContentLeftInset + spacingMd` again (this row has no card of
  its own, but is inset by the same total so its badge/title still lines
  up under a zoned row's). Kept at the identical total specifically so
  zoned and unzoned times stay lined up with each other, not just with
  the spatial view.

**Never**: a `Transform.translate` or negative `Container(margin:)` to
fake this position — the margin version measurably breaks any ancestor
that needs to MEASURE this subtree (an `IntrinsicWidth`, a `Flexible`
resolving against intrinsics), and `Transform` alone works but leaves the
"why does this text visually escape its own box" reasoning scattered as
a comment at each call site instead of owned by one shared widget. Add a
new call site here, with its own correct `leftPaddingToEscape`, rather
than reinventing the escape math inline.

---

## Full-screen modal route — `pushFullScreenRoute`

The app's first full-screen (not slide-up-sheet) modal convention. Added
for the voice-capture flow (`voice_capture_screen.dart`), requested
directly as a component to reuse: "make it a reusable component... we'll
be reusing it" applied one level up, to the route shape itself, not just
the waveform inside it.

Every OTHER modal in the app is `pushAppSheetRoute` (above) — a partial
reveal from 50% up, with a scrim behind it, because something of the
screen underneath stays visible and relevant. `pushFullScreenRoute` is
for the opposite case: a screen that takes over completely, where nothing
behind it matters until the user leaves.

```dart
Future<T?> pushFullScreenRoute<T>(BuildContext context, WidgetBuilder builder)
```

- `opaque: true`, no `barrierColor` — a full-screen page has nothing left
  showing behind it, so it needs no scrim.
- Entrance starts at 15% of the screen's own height (`_fullScreenEntranceOffset`),
  not the sheet's 50% — this fills the whole screen, so it should read as
  arriving immediately, not revealing from partway up.
- Shares every timing/easing token with `pushAppSheetRoute`:
  `AmbleTheme.motionNormal` in, `AmbleTheme.motionFast` out,
  `AmbleTheme.curveDecelerate`/`curveStandard`. One motion language across
  every modal in the app, whichever shape it takes.

**Current call site**: `voice_capture_screen.dart`'s `showVoiceCaptureScreen`.

**Never**: a bare `Navigator.push(MaterialPageRoute(...))` with Flutter's
default transition for a full-screen feature — that is what a handful of
plain settings/list screens still do (`backup_settings_screen.dart`,
`zone_list_screen.dart`), predating this convention, but any NEW
full-screen feature should use this route instead, the same way any new
modal reaches for `pushAppSheetRoute` rather than hand-rolling a
`PageRouteBuilder`.

---

## Live audio waveform — `AppVoiceWaveform`

`lib/core/widgets/app_voice_waveform.dart`. A row of bars whose heights
track a live amplitude value — added for the voice-capture flow, and
built deliberately SDK-agnostic per direct request ("make it a reusable
component... we'll be reusing it"): it takes a plain `double` (`level`,
0.0-1.0), never a `speech_to_text` package type, so any future caller can
drive it from a different audio source without this widget depending on
that package.

```dart
AppVoiceWaveform({
  required AmbleTheme theme,
  required double level,   // clamped internally — callers may pass a raw,
                            // unnormalized platform sound-level value
  bool isActive = true,    // false = flat, still baseline (paused/idle)
  int barCount = 24,
})
```

Internally a single `CustomPainter` driven by one continuous
`AnimationController..repeat()` — each bar samples the SAME sine wave at
a different phase offset, scaled by `level`, which is what makes the
whole row ripple across rather than pulse in lockstep ("constantly moving
across," per direct request).

**Testing note**: the perpetual `repeat()` means any screen embedding
this widget can never use `pumpAndSettle` in a widget test — it never
settles by design. Use bounded, timed `pump()` calls instead (see
`voice_capture_screen_test.dart`'s own `pumpScreen` helper), and when a
test also needs to wait out a route's exit transition on the SAME screen,
prefer many short pumps over one long one — the two animations compete
for frame budget in the test harness, and a single long `pump(duration)`
measured as insufficient where 20 shorter ones were not.

**Current call site**: `voice_capture_screen.dart`, fed from
`VoiceCapture`'s own `soundLevel` state. Registered in the Widgetbook
gallery under "Voice" → "AppVoiceWaveform" (idle / listening / loud use
cases).

**Never**: a bare `AnimatedContainer` per bar with no shared phase
relationship — that reads as several unrelated things pulsing, not one
waveform. The shared-sine-with-per-bar-phase approach is what makes it
read as one continuous wave.

---

## Zone pane indicator — corner radius, standing gap, and label placement

**What it is**: the ONE rounding/spacing treatment for a zone's own
rendered block, wherever a zone renders as a real pane (not a list row) —
the spatial Timeline's `ZoneBackgroundBlock`, and the Weekly Zone
Authoring Grid's `ZoneGridBlock`. Unified 2026-09-21, requested directly:
"zone rounding should be consistent everywhere... use the rounding from
non spatial zone view."

**Corner radius**: `theme.radiusXl` (16) — taken from the non-spatial Zone
view's own card (`ZoneContainerBlock`, already `radiusXl`, unchanged),
named as the reference. `ZoneBackgroundBlock` previously used
`theme.radiusMd` (8), a real, previously undocumented divergence from the
non-spatial view.

**Exception — Weekly Zone Authoring Grid uses `theme.radiusSm`**
(2026-09-21, same day, superseding this section's own original
unification for that ONE surface): requested directly, "the rounding of
zone edit zone mode should be xs." `ZoneGridBlock` briefly matched
`radiusXl` alongside `ZoneBackgroundBlock` per the unification above, then
was confirmed as its own deliberately smaller rung — this dense authoring
surface (see the horizontal-spacing section's own "edit zone view has its
own more dense space" carve-out) reads better with the smallest radius on
the scale than with the same large rounding a full-size zone pane
elsewhere gets. `ZoneBackgroundBlock` (spatial Timeline) keeps
`radiusXl`, unaffected.

**Standing gap between adjacent zones**: `zoneBackgroundGap` (4.0,
`lib/features/timeline/zone_background_block.dart`) — taken entirely off
a block's BOTTOM edge (never its top, so a zone's top edge still lands
exactly on its own start time), so two zones whose times are exactly
back-to-back never visually touch. Was spatial-Timeline-only; the Weekly
Zone Authoring Grid's own `_block` (`zone_grid_screen.dart`) had no
equivalent trim at all until this pass — now applies the same constant
the same way (subtracted from a block's own rendered `height`).

**Zone name label placement**: renders INSIDE the zone's own pane, not as
a sibling positioned outside/beside it. The Weekly Zone Authoring Grid
already did this (`ZoneGridBlock`'s own `_RotatedTitle`, inside its
`Stack`); the spatial Timeline's `ZoneNameLabel` did not — it was a
separate widget `Positioned(right: 0, ...)` in the day column's outer
`Stack`, landing at the day's right edge rather than inside the band it
names. Now positioned inside `ZoneBackgroundBlock`'s own width, with
`theme.spacingSm` padding from the band's right inner edge.

**Zone name typography**: both the spatial Timeline's `ZoneNameLabel` and
the Weekly Zone Authoring Grid's rotated title use `theme.textZoneName`
(`TypePrimitives.size0`, 11px, monospace). This is deliberately smaller than
the 12px hour-axis `textCaptionMono` label and is the shared style for dense
vertical zone annotations.

**Dynamic zone width — dev toggle, default OFF** (2026-09-21): the
spatial Timeline used to size each zone band dynamically off the day's
own deepest overlap-lane stack (`_zoneBackgroundWidth`, reading
`dayPillLanes`), so a day with more overlapping tasks widened every zone
band. A new `DevDynamicZoneWidth` toggle (`core/dev_config.dart`,
`kDebugMode`-gated Settings → Developer switch, mirroring
`DevZoneCardFlat`'s own shape) restores that behavior when explicitly
turned on; **off (the default)**, every zone band on the spatial Timeline
spans from `hourGutterWidth` to `rightEdgeInset` — the same
`left`/`right` (no explicit `width`) mechanism every other full-width
Timeline element (a drag ghost, the frosted lift pane) already uses to
reach the true page edge — so the band now fills 100% of the available
row regardless of lane count, and the zone name label (now painted
inside, per above) sits inside that same fixed-width band rather than
tracking a shifting one. The Weekly Zone Authoring Grid is unaffected —
its own blocks were never lane-width-driven.

**Full-width mode's own left inset matches the non-spatial view**
(2026-09-21, same day): requested directly, "use same padding left for
first lane as in non spatial view." `ZoneBackgroundBlock` gained a new
`leftInset` parameter (default `zoneBackgroundOffset`, 4px — the original
"padding around the pill column" inset used everywhere else, including
`DevDynamicZoneWidth`'s own ON state). The full-width spatial call site
passes `theme.spacingMd` (16px) instead, matching `ZoneContainerBlock`'s
own left padding before its first task row exactly. Widening `leftInset`
only extends the band's own LEFT edge further out — `width` is adjusted
by the same amount so the band's right edge, and every task pill's own
position, are completely unaffected; this block never repositions a
task, only its own decorative edge.

**Never**: a bare `theme.radiusMd` on a new zone-pane `BoxDecoration`, a
zone block with no `zoneBackgroundGap` trim on at least one shared edge,
or a zone name label positioned as a `Stack` sibling outside the band it
names. If a new zone-rendering surface is added, give it this exact
radius/gap/label-placement treatment rather than picking a fresh value.

---

## Brief confirmation toast — `AppUndoToast`

**File**: `lib/core/widgets/app_undo_toast.dart`

**What it is**: the ONE brief, self-dismissing toast in the app,
optionally with an "Undo" action — added for quick-capture's own
confident-parse task creation, then widened (2026-09-22, requested
directly: "let's build undo change mechanism") into the app's single
mechanism for "this destructive/easy-to-regret action just happened, and
here's how to take it back" across every delete/remove path. Not a
platform branch (no separate Cupertino/Material look) — a plain rounded
card with text + a text button reads identically as "the app's own"
chrome on both platforms, the same reasoning `AppTextField`/
`ListWheelScrollView` already apply to genuinely platform-neutral
widgets.

**Imperative, not a plain widget with props**: `AppUndoToast.show(...)`
inserts its own `OverlayEntry` on the app's ROOT Overlay
(`Overlay.of(context, rootOverlay: true)` — deliberately the outermost
one, supplied by `MaterialApp`'s own Navigator, not the nearest enclosing
one, so the toast outlives the specific screen that triggered it even if
that screen pops immediately afterward) and manages its own lifetime
entirely: it auto-dismisses after `duration` unless `onUndo` fires first
(which also dismisses it immediately), and removes itself cleanly either
way. Callers never track or manually remove the entry.

**API**:
```dart
AppUndoToast.show({
  required BuildContext context,
  required String message,
  VoidCallback? onUndo,               // null = plain informational
                                       // notice, no action row at all
  Duration duration = const Duration(seconds: 4),
})
```

**`context` must be a genuine DESCENDANT of the root Overlay** — a
`navigatorKey.currentContext` will NOT work here (see this file's own
"Never" line below): that context is the `Navigator`'s own element,
sitting structurally above the Overlay that same Navigator builds
internally, so `Overlay.of` walking upward from it never finds one.
Every real call site instead passes an ordinary widget's own
`BuildContext` — the calling screen's, or (when that screen is about to
pop) a `rootContext` captured before the pop happens, the exact same
"capture the caller's context before this sheet's own route exists"
contract `showQuickCaptureSheet`/`showTaskActionSheet`/
`showTaskDetailSheet`/`showZoneFormScreen` already establish for their
own undo toasts.

**Undo restores via snapshot-then-keyed-re-save, not a separate undo
stack**: every caller snapshots the affected row(s) via the model's own
`toJson()` BEFORE the delete runs, and `onUndo` restores via `fromJson` +
the ordinary `updateTask`/`updateZone` write — a plain keyed re-save
(Hive keys by id), the same round-trip export/import already proves
correct. A group action (multi-select Remove) snapshots the WHOLE
selection and shows ONE toast for the batch, restoring everything on a
single Undo tap — see `docs/DECISIONS.md`'s 2026-09-22 entry for the full
mechanism, including how a whole recurring-series delete snapshots every
row that operation could touch (delete OR mutate), not just the tapped
instance.

**Testing note**: the auto-dismiss timer is a real, cancellable `Timer`
(not a bare `Future.delayed`, which exposes no cancel handle — a real bug
this file's own timer-cancel fix corrected, see `docs/ERROR_LOG.md`). A
test that lets the toast expire naturally needs to `pump()` past the
full `duration` before the test ends, or `flutter_test`'s own teardown
fails on "a Timer is still pending." A test that taps Undo instead needs
no such drain — the timer is cancelled the moment Undo fires.

**Current call sites** (as of 2026-09-22): `task_remove.dart`'s
`removeTask` (the action sheet's Remove row, the detail screen's delete
button, the Timeline's drag-to-delete-target — single-instance AND
whole-series removal), `zone_grid_screen.dart` (the Edit Mode selection
dock's group Remove for tasks, and the Zones tab's own bulk "Remove
placements"), `zone_form_screen.dart` (its own delete button),
`timeline_screen.dart` (the spatial Timeline's zone drag-to-delete, and
the multi-task group drag-to-delete-target path), `inbox_screen.dart`
(swipe-to-delete), and `quick_capture_sheet.dart`/
`quick_capture_undo_main.dart` (the original confident-parse creation
that introduced this widget). Registered in the Widgetbook gallery under
"Feedback" → "AppUndoToast" ("With Undo action" / "Message only (no
Undo)" use cases, triggered via a demo button since the widget itself
has nothing to render until `.show()` is called).

Also, as of 2026-09-22, every task/zone MOVE and RESIZE commit via the
shared `lib/shared/services/move_resize_undo.dart` helpers
(`commitTaskChangeWithUndo`/`commitZoneChangeWithUndo`) —
`timeline_screen.dart`'s group and single-task move/resize (cascade and
non-cascade alike) and its shared zone cascade commit
(`_commitZoneCascade`), plus `zone_grid_screen.dart`'s own zone cascade
commit (`_finishMove`). Every commit shows a toast, including a plain
single-task move with no cascade — confirmed via AskUserQuestion, same
"every write gets one" consistency delete already established.

**Never**: a `navigatorKey.currentContext` (or any other Navigator-level,
non-descendant context) as the `context` passed to `show` — it silently
throws "No Overlay widget found" despite a real Overlay genuinely
existing one level below. A bare `Future.delayed` for any future
auto-dismiss-style timer that can also be cancelled early by a different
code path — use a real `Timer` so `dispose()` can cancel it outright,
not just guard the eventual fire with a `mounted` check. A second,
hand-rolled "brief message, optionally with an action" widget anywhere
else in the app — extend this one's API if the shape doesn't quite fit
yet.

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

---

## Persistent contextual chrome and content motion (2026-09-26)

`AppContextDock` is the shared state-driven bottom toolbar. Its
`AppContextDockConfiguration.stateId` describes the current semantic state;
`AppContextGroup.id` describes a pane; and `AppContextAction.id` is the
semantic identity of one retained control. IDs are not list indexes, icon
matches, or labels. A callback/selected/enabled update with the same shape
must update in place without replaying entrance motion.

The dock uses one flat keyed action layer and separately painted pane
backgrounds. A retained action can therefore move between groups while its
button element, haptic behavior, focus identity, and tooltip remain stable.
Its rectangle, group bounds, and gaps animate with
`MotionPrimitives.durationContextDockMs` (200ms) and `curveStandard`.
Removed actions lose input, focus, and semantics immediately, then fade out;
new actions are laid out at their final position before fading in. The
floating create button is a separate primary-action slot and is not a dock
action.

Inline creation sheets temporarily suppress the shell toolbox through
`AppShellChromeController.dockObscured`; see **Inline creation sheets and toolbox**
under Sheets. A feature-local Stack cannot outpaint a later shell sibling.

`AppBottomDock` is mounted by the main shell and supplies an empty
configuration outside Day. That keeps the dock element alive while pages
change, so a page crossfade cannot dim or remount the toolbar. Edit now enters
through the shell-owned content Navigator, so its route-scoped dock
configuration remains above the route body. The Day calendar header is
outside the Day list/spatial content transition; its expansion, selected date,
and browsed-week state remain stateful. Edit Tasks still has a mode-specific
calendar header, so the accordion itself has not yet been lifted into the
shell calendar slot.

`AppViewTransition` is the opt-in content transition. Each `viewId` gets
one keyed live slot; cached slots are paused and excluded from input,
semantics, and focus while inactive. A target is laid out before its fade
starts, and reduced motion completes after the same readiness point. Rapid
changes retain the current blend as weights over existing live slots instead
of creating a widget subtree as a fake screenshot. The shared token is
`MotionPrimitives.durationViewCrossfadeMs` (140ms) for crossfades. Main
navigation opts into a directional horizontal slide, using the selected
destination order to choose left or right. Main slides and
`directionalPageRoute` use the shared 150ms fast duration and decelerating
curve; Back reverses route direction. Only one transition host may own a
given handoff.

Never wrap persistent toolbar/calendar chrome in `AppViewTransition`, use a
second `AnimatedSwitcher` for the same view change, key a retained action
only inside a different group parent, or use a fixed delay as proof that
scroll restoration/layout readiness is complete. The implementation brief
and migration/acceptance matrix live in
`docs/SHARED_CHROME_MOTION_BRIEF.md`.

Dock additions use `durationContextDockStaggerMs` (35 ms) between new
actions, with the existing 200 ms fade for each. Retained controls do not
re-enter. A new pane begins with its first action; reduced motion skips
both the stagger and fades. Interrupted entrances cancel pending delays.

Dock removals use the same 35 ms sequential delay and 200 ms fade; input,
focus, and semantics disable immediately. A departing pane fades with its
last departing action. The shell's `AppShellHeader` crossfades main navigation
and Edit tabs in the same md-button-height slot, with shell-owned padding.
Changing Edit tabs updates the retained tab control without another header
crossfade. Edit bodies paint an opaque base under their content transitions.
