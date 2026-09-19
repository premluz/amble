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

## Adding a new canonical component to this file

When a visual treatment gets used a third time (per CONSTITUTION.md
design principle 5's "second location" trigger for tokens, applied here
one level up to whole components): promote it to a real shared widget in
`lib/core/widgets/` (app-wide) or the relevant feature directory (if it's
genuinely scoped to one feature, like `TaskEdgeTimeLabel`'s Timeline/Zone
scope), then add a section to this file with the same shape as the two
above: what it is, its exact token values, its API, every current call
site, and an explicit "never" line naming the ad hoc pattern it replaces.
