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
| `theme.spacingScreenPadding` | 16 | Screen edge → page content. The top nav's "Days", the settings gear opposite it, page titles, list rows, sheet bodies, **and the Timeline's hour labels in both the spatial and non-spatial views.** |
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

## Compact top navigation and Timeline date control

The persistent Days/Things/Habits navigation and Timeline date selector use
`theme.textBody` for their visible labels. Settings and the date chevron use
`theme.spacingMd` for their icon size. Keep the navigation row and Settings
tap target at `AppButtonSize.md` (40px); compact the visible content without
shrinking the interaction area. The expanded week strip keeps its existing
cell padding and hit-area sizing.

---

## Vertical safe-area clearance — compact top and bottom edges

The phone's status and gesture regions belong to the platform safe area.
App padding is the small visual gap *inside* those safe boundaries, not a
second safe-area inset.

- The main shell starts its header directly below `SafeArea`'s top edge;
  do not add another app-level top spacer. Keep the system status inset.
- Floating toolbars, create buttons, sheet footers, and bottom-padded sheet
  bodies use `theme.spacingBottomClearance`, which aliases `spacingSm`
  (8px). This is the same gap as the quick-create sheet's top header inset.
- Apply the bottom safe area once, then add `spacingBottomClearance` once.
  The phone's rounded bottom and home-indicator region provide the larger
  outer breathing room; extra `spacingMd`/`spacingLg` above them needlessly
  lifts controls and wastes usable screen space.
- Full-screen sheet surfaces may keep their own top-corner inset where it
  reveals the rounded sheet edge. That local surface geometry is separate
  from the main shell's removed top spacer.

**Current call sites**: `AppBottomDock`, local task/zone/Tracked docks,
`AppFloatingCreateButton`, Inbox's adjacent microphone button, `AppSheet`,
`StepScaffold`'s primary footer, and the in-tree quick-capture sheet.

**Never**: combine a full device bottom inset with this token manually,
or stack multiple component-owned safe areas around one control. If a new
bottom control sits too high, adjust the shared clearance rule instead of
introducing a per-screen bottom value.

`test/core/widgets/bottom_clearance_system_test.dart` pins the token to
`spacingSm` in both themes and checks the shared sheet/create/footer
components.

## Spatial day scroll clearance

The 24-hour spatial Timeline and weekly spatial Zones grid use the shared
`TimelineScrollTokens` content insets: 60 logical px above the first tick and
200 logical px after the final tick. These are scrollable-content clearances,
not safe-area or toolbar padding. They let both midnight labels scroll fully
into view above fixed chrome and leave enough lower-day space to start a task
without the bottom dock covering the 00:00 time position. Keep the insets
shared across both spatial surfaces; preserve their own existing page/header
layout and do not apply them to the non-spatial zone list.

`_DayTimelineState`'s center/report and scroll-to-item calculations include
the top inset, so remembered times and newly created tasks remain aligned with
the rendered time axis as clearance changes.

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

Saved weekly zones use `ZoneGridBlock`: `colorSurfaceSecondary`, `radiusMd`,
and the compact `textZoneName` label. Body drags move the current selection
in both time and weekday; horizontal body movement snaps to whole weekday
lanes, while vertical movement retains its 5-minute time snap. Top/bottom
handles resize time. Side handles copy the active zone to additional weekdays
only when exactly one zone is selected; multi-selection keeps group move and
time-resize available. Empty grid space remains scrollable.
Batch actions read the current selected IDs at invocation, not the set captured
when the toolbar first appeared.

During a body move, the source slot remains as a non-interactive silhouette
under the moving blocks. Its 20% opacity comes from
`DragPreviewTokens.ghostOpacity`, shared with the Timeline task drag ghost.

The new-zone and existing-zone extension previews share `_marqueeBody` and
`_Phantom` in `zone_grid_screen.dart`:

- One `SelectedPillBorder` encloses the span: accent ring, theme-surface
  separation, `radiusMd`, and accent fill at 9% alpha.
- During side extension the moving boundary follows pointer pixels; weekday
  ghost membership and saved placements use the same accumulated horizontal
  drag delta as moving a pending marquee. The delta is rounded by lane width,
  so an adjacent day appears once the pointer moves at least half a lane from
  its original touch position, independent of the handle's inset.
- Each covered weekday has a non-interactive ghost: `colorSurfaceSecondary`
  at `DragPreviewTokens.ghostOpacity` overall opacity, `radiusMd`, a centered
  rotated `textCaption` title in `colorTextSecondary`, and ellipsis overflow.
  No independent accent outline.
- Ghosts are inset by `spacingXs` horizontally and half `spacingXs` vertically.
  They preview placement only; persistence occurs on release or confirmation.
- Hide the original source block visually during extension, preserving its
  gesture element. Only the shared marquee and its handles should be visible.

## Floating surfaces — material and elevation

`AppFloatingSurface` is the shared floating-surface component. Surface role
(`surfaceColor`, normally `colorSurfaceOverlay`), material (`solid` or `glass`),
and elevation (`menu` or `drag`) are independent. `FloatingSurfaceTokens` owns
the material and shadow values; ordinary controls do not inherit glass borders.
Anchored context menus use `theme.radiusXxl` (20 px) for both the glass panel
and its entrance morph; reserve `radiusModal` (40 px) for sheet corners.

| Property | Light | Dark |
| --- | --- | --- |
| Glass fill | `creamOverlay` at 92% | `ink650` at 92% |
| Quiet border | `slate900` at 6% | `sand200` at 10% |
| Top highlight | white at 18% over quiet border | white at 16% over quiet border |
| Border width | 1 logical px, inside the shape | Same |
| Backdrop blur | sigma 12 | Same |
| Menu shadow | `slate900` at 10% | `ink900` at 28% |
| Drag shadow | `slate900` at 16% | `ink900` at 40% |

Border color graduates from the brighter top to quieter sides/bottom, without
a glow. Shadow is outside the clip; the border belongs to glass material, not
elevation. Menu geometry: offset (0, 6), blurRadius 20, spreadRadius −4.
Drag geometry: offset (0, 12), blurRadius 32, spreadRadius −6. Theme changes
alter shadow opacity/color only, never geometry. Use the repository's palette
primitives rather than reproducing approximate hex values from mockups.

- Anchored context menus and floating popovers: elevated glass + menu shadow.
- Position anchored menus from the global touch/drop point. Prefer below when
  the full menu fits; otherwise open above when that gives more room, then
  clamp within safe-area and keyboard insets. Center horizontally on the
  anchor and keep the gap to the anchor small. Constrain and scroll only when
  the menu itself is taller than the available viewport.
- During press-drag, one inset capsule highlight tracks the row under the
  finger and eases to the next row. Keep the caller's action order, with
  destructive actions last; don't add edge-to-edge row fills.
- Present anchored and press-drag menus in the root overlay layer so they
  cover the app's top navigation and bottom toolbar. Dismiss open menus on
  route changes and when an `AppViewTransition` changes its view ID.
- Lifted task: identical glass + drag shadow. Animated `strength` keeps the
  render subtree mounted; zero strength removes paint, blur, and clipping so
  resting resize handles remain visible and gestures retain ownership.
- Every toolbar pane, whether it holds a group or one independently floating
  action: the same glass fill, border, and menu shadow. Ordinary items stay
  transparent; selected items get a solid tonal fill; there are no separate
  borders on the icons. Both dock renderers use `AppDockSurface`. Primary create
  (+) remains solid brand accent.
- Solid sheets remain solid. A future glass sheet must opt into this component.
- Task lanes, habit dots, zone backgrounds, draft rails, inputs, and ordinary
  buttons receive no floating glass border. Their existing treatments remain.

Primary/secondary content uses the existing semantic text tokens. What Matters
retains its per-button active tint but leaves the page at its ordinary surface
color when the ripple settles. Widgetbook: **Feedback → AppFloatingSurface
→ Glass and solid elevation**; existing context-menu demos use the real material.
Verification: `flutter test test/core/widgets/app_floating_surface_test.dart
test/core/widgets/floating_surface_paint_test.dart` checks lift identity, dock
materials, elevation geometry, identical menu/drag fills, and painted edges.

## Task pills — saved and draft materials

Saved tasks use `TaskCapsuleBlock` and the current `radiusPill` setting.
`PendingTaskPill` is an unsaved placement and uses `GlassPillSurface` in
`GlassPillMaterial.glass`: `GlassPillSurface.glassTint(theme)` over a clipped
`blurOverlaySigma` backdrop blur. This borderless draft material is separate
from floating menus and lifted cards. It carries no invented category glyph.
The draft is wrapped in `SelectedPillBorder` with `fillColor: null`, preserving
its glass material and the same accent/theme-surface selection rings as zones.
Imported calendar pills use `GlassPillMaterial.flat` without blur; they are real
calendar entries, not ghosts. Zone ghosts remain flat translucent panes rather
than adopting the task pill's glass material.

---

## Task completion bubbles — `AppBubbleBurst`

`AppBubbleBurst.show` is reusable decorative feedback for swipe completion in
spatial task pills and zone/list task rows. Emit before updating the task, using
the pill's top-center in the source context's local coordinates and its width.
The root-overlay effect snapshots that position, survives removal of the source,
ignores pointer input and accessibility focus, and removes itself on completion.
Undo does not emit bubbles. Existing completion behavior and haptics are retained.

`BubbleBurstSpec` holds the shared controls adapted from the seeded bubble
emitter in `rios-motion 15/rios-motion.js`: `bubbleEmission`, `bubbleStagger`,
and `bubbleLinger` are seconds; `bubbleRate` is births per second per lane;
`bubbleTravel` and `bubbleSpread` are multiples of pill width;
`bubbleRandomness` and `frontDots` (opacity) range from zero to one.
Defaults emit six tiny accent-colored bubbles across three emission lanes,
rising, shrinking, and fading over approximately 1.2 seconds. Bubble diameter
is only a small fraction of the pill width. These are completion feedback,
separate from the What Matters ripple. Reduced motion skips emission entirely.

Widgetbook: **Feedback → AppBubbleBurst → Task completion** exposes all eight
controls, a real swipe action, and replay. Focused verification:
`flutter test test/core/widgets/app_bubble_burst_test.dart test/features/timeline/task_completion_bubbles_test.dart`.

## Tracked day cells — current-day surface fill

The shared Tracked `_DayCell` uses theme-scale colors across all three views.
Light mode uses `colorSurfaceField` for incomplete days and for today's cell;
today's label uses `textCaption` and `colorTextTertiary` so both its size and
contrast stay quiet. Dark mode uses the intermediate
`colorSurfaceOverlay` rung and `colorTextTertiary` for incomplete
non-current days; today's cell keeps
`colorSurfaceFieldActive` and primary `textLabel` styling. Other incomplete
dark-mode day labels use `textCaption` and `colorTextTertiary`. Completion
takes precedence in both themes and uses `colorAccent` with
`colorSurfacePrimary` text; there is no accent outline. Weekday initials and
six-month month names use `colorTextTertiary` as supporting labels. Tracked
behavior cards have no trailing chevron; the card remains tappable without
implying a separate navigation destination.

## Tracked period calendar

`TrackedPeriodCalendar` occupies the Day calendar header's position below
the shared top navigation. Its caption uses `textBody`, the same horizontal
screen padding and bottom spacing as `AppDateAccordion`, and a fixed reserved
slot where Day's collapsed grip sits; it has no chevron, grip, or expansion.
This keeps the header's height and caption position stable when switching
between Day and Tracked.

The caption follows the selected Tracked view: a Monday-Sunday date range for
Weekly, the month name for Monthly, and January-June or July-December plus the
year for Six-monthly. Swiping left advances by one week, month, or aligned
half-year; swiping right goes back. The same period bounds drive every
behavior's completion cells. This cursor is local to Tracked and never
changes Day's selected date. The six-month grid uses fixed calendar
half-years, not a trailing 183-day window.
The period caption is left-aligned. A small trailing `Today` action fades in
when the displayed week, month, or half-year differs from the current period;
tapping it returns the Tracked cursor to the current period.

## Selected-item deletion puff — `AppDeletePuff`

`AppDeletePuff.show(context:)` is reusable overlay feedback for a delete
control. It captures the control's top-center point before its selected-item
action clears the dock, then emits seeded smoke clusters above that point. The
root-overlay effect is transparent, ignores pointers and accessibility focus,
survives the source button disappearing, and removes itself after 1.25 seconds.
Reduced motion skips it. Existing delete behavior and haptics remain owned by
the action.

`DeletePuffSpec` copies the numeric preset and smoke/shadow/highlight colors
from `rios-motion-v19/delete-puff-config.json`: 11 clusters, 104 spread, 34
lift, 22 size and curl, .27 stagger, .325 fade start, .85 scale, seed 15.
Distances scale with the source button relative to the export's 136px object
width. The studio's sample object and opaque background are omitted because
the live delete button is the source and the effect must layer over the app.
Widgetbook: **Feedback → AppDeletePuff → Selected-item delete** exposes the
export's ten numeric controls. Selected task and zone delete actions in Edit
use the same component. Verification:
`flutter test test/core/widgets/app_delete_puff_test.dart`.

## Liquid pulse — `AppLiquidPulse`

The single "something just happened to this object" response. When `active`
turns true, the child compresses quickly (ease-out), then a native Flutter
spring (`SpringDescription.withDurationAndBounce`, the SwiftUI duration/bounce
model) releases it past rest once and settles exactly at identity. The
horizontal axis deforms less than the vertical (`squash`), which makes it read
as liquid rather than a rigid zoom. Turning `active` false never pulses. Only
paint is transformed, so layout and neighbours never move. Reduced motion
skips it.

`LiquidPulseSpec` holds the presets: `select` (6% depth, bounce .5) is
felt more than seen; `selectSurface` (2.5%, bounce .45) is for large blocks
like zones, where a proportional squeeze would lurch; `complete` (14%, bounce
.7) is clearly elastic, with about a 5% overshoot and one visible return wobble.
Brand rule: fluid and springy, never cartoonish; overshoot stays below the
compress depth.

**Current call sites**:
- `TaskCapsuleBlock` (Task and List views): `select` on `isSelected`,
  `complete` on `isCompleted`. Both wrap the **whole manipulation unit**
  (pill, selection rings and resize dots, via `TaskManipulationTargets`),
  pivoting on the pill's centre (`TaskManipulationTargets.targetWidthFor`), so
  the controls move with the pill instead of floating while it squeezes.
- Zone view rows (`_ZoneTaskRow` badge): `complete` on completion.
- `ZoneBackgroundBlock` (Task view) and `ZoneGridBlock` (weekly grid):
  `selectSurface` on selection, wrapping fill, ring and handles together.

**Rule:** a pulse wraps the selected unit *with* its controls, never the
visual alone.

**Press: swell, Liquid Glass style.** `AppPressFeedback` runs on the same
`LiquidDeformation` helper, driven by the ONE shared press spec,
`LiquidPressSpec.standard`. Press-and-hold **grows** the control toward the
finger (like Apple's Liquid Glass), and release springs it home with a fluid
overshoot just past rest. Growth is sized in pixels, not as a flat percentage:
8px spread over the control's longest side, clamped to 2–18%. A 44px icon
button swells about 18%, a full-width row about 3%. While held, a faint glass fill
(`holdFillAlpha`, 8%) covers the whole control, so a fill-less ghost icon
button (sheet close, toolbar and dock buttons) visibly swells as a whole, not
just its icon. A release that arrives mid-swell waits for it to land, so the
quickest tap shows the full press. Every `AppButton`, chip, row, icon button
and `HeaderCircleButton` inherits it. `AppDockIconButton`'s selected tint is
the button's own `fillColor`, so it swells with the press rather than
sitting still behind it. A **single-action dock pane** (Edit, What Matters,
Back) IS the visible button, but its glass is drawn as a separate layer
behind the action. `AppPressFollower` swells that pane with its action's
press, fed by a pointer `Listener` that never competes for the tap.
Multi-action panes stay still while the pressed button swells on its own,
as in Liquid Glass toolbars. Widgetbook: **Feedback → AppPressFeedback** (four
shapes, eight knobs; press and hold).

Deliberately different from the pulses: a press *swells* (the control
answers the finger), while select and complete *squeeze then rebound* (an
event happened to the object).

**Never deform an object under the finger.** Pass `suppressed: true` while
the child is being dragged or resized: any pulse in flight snaps to rest, and
activations during it are swallowed. `TaskCapsuleBlock` suppresses on
`isLifted || isResizing`. This came from a real regression: selecting on
resize-start squeezed the pill 6% while it had to track the finger. **Never** hand-roll a scale bounce with `easeOutBack` or
`elasticOut` for a state change; use this component with a spec.
Widgetbook: **Feedback → AppLiquidPulse** (Select / Complete) exposes all
five spec values. Verification:
`flutter test test/core/widgets/app_liquid_pulse_test.dart`.

## Liquid entrance and shape morph — `AppLiquidMorph`

The one way a surface appears out of a point. On mount, a droplet
(`dropletDiameter`) at `origin` spreads into the child's own rounded shape.
Width and height ride separate native springs, with height a beat slower, so
the shape widens and then stretches toward where it opens, overshooting a
touch before landing exactly. The content grows with the shape
(`contentScaleFrom`) and fades in over the first quarter of the width spring.
An origin outside the child is clamped to its nearest edge, so a popover
anchored beside a finger grows from the side facing it. The clip's reveal
never passes the child's own edges and never shrinks once the shape has
formed; the overshoot is carried only by the content scale, and the clip
switches off the moment the shape forms. Otherwise the spring pulled an edge
back inside the rim and briefly hid the glass's top highlight (reported as a
"glitch": a reflection doesn't blink out). Reduced motion shows
the finished shape immediately.

`LiquidMorphSpec.popover`: 28px droplet, width .25s / bounce .4, height .32s
/ bounce .45, content from 60%. It pops about 4–5% oversized and settles back,
after Liquid Glass (fast, and bouncier after device review), content from 70%. **Current call sites**: both context-menu
entry points (`AppContextMenu.showAt` and `AppLongPressContextMenu`), growing
from the touch point. The route's own animation now only fades the popover
out. **Never** use a plain `FadeTransition` + `ScaleTransition` for a surface
that emerges from a touch; use this. It is also the draft task's entrance. Widgetbook: **Feedback → AppLiquidMorph** (tap
anywhere, seven knobs) and **AppContextMenu → Long-press, drag, release**.
**Draft task: dot to line.** `PendingTaskPill`'s rail enters with
`LiquidMorphSpec.draftPill`. Its droplet size is unset, which means the
child's own shortest side, so the droplet is a rail-wide dot at the top of the
pill, exactly where a real task's badge sits. It then stretches down into the
full-length pill on the longer, bouncier height spring. This is BRAND.md's
dot → line grammar made literal: a thing becomes something placed in time.
Only the rail morphs; the title, edge time labels and resize handles do not.
The clip switches off once the shape has formed, so the selection ring at the
rail's edge is never shaved.

Widgetbook: **Feedback → Task pill** has three use cases: *All states*
(normal, selected, important, completed, imported, draft), *Select and
complete* (interactive: every pulse, the ripple and the bubbles) and *Draft:
dot to line* (replays the entrance). They are smoke-tested by
`widgetbook/test/task_pill_demo_test.dart`.

Verification: `flutter test test/core/widgets/app_liquid_morph_test.dart`.

## Task states — `TaskStateStyle` and `TaskStateTokens`

Every row that draws a task (Task/List pill `TaskCapsuleBlock`, its text row
`TaskCapsuleTextRow`, Zone view `_ZoneTaskRow`, cluster rows) resolves its look
through ONE `TaskStateStyle.resolve(theme, task, labelColor)`. No call site
picks a "completed grey" itself. Colours come from `TaskStateTokens`, derived
per theme from text/surface/accent, so light and dark each read correctly.

| State | Pill fill | Title | Extra |
| --- | --- | --- | --- |
| Normal | label colour | primary | — |
| Unlabeled (new, "General") | reserved opaque "mist" tone `unlabeledFill` (`ColorPrimitives.mistLight/mistDark`, hue 218°) | primary | never in the label palette; shared ONLY with imported events (`importedFill`, plus the hatch) |
| Important | label colour | primary tinted 35% toward accent (`importantTitle`) | star straddling the pill's top-right edge (`TaskImportantStar`) |
| Done | pale tint of its own label (`doneFill`, 72% page) | receding (`doneTitle`, primary at 42%) | strike line in the title's own colour, 1.6px; glyph at 25% (`doneGlyphAlpha`) |
| Done + important | as done | as done | star stays |
| Imported | flat grey rail with faint 45° hatching (`AppHatch`, `importedHatch`), clipped to the pill, no outline | secondary | calendar glyph |

The star is not accent-coloured. It is a softened primary-text tone (paper
cream in dark, a lighter charcoal in light, `importantStarSoften`) with a
subtle diagonal gradient into a hint of accent (`importantStarAccentMix`). It
sits on the pill's edge, 30% past the right side and 15% above the top, with a
1.5px outline in `colorSurfaceBase` to separate it from the pill fill. Both
spatial and zone/list views use this shared `TaskImportantStar` treatment.

Glyphs on a pill are warm paper (`glyphOnDark`) or charcoal
(`glyphOnLight`), chosen against the pill's ACTUAL fill (including a done
task's pale tint), never pure white or black; a done task's glyph fades to
`doneGlyphAlpha` (25%, barely there) with its pill.

Rules: done must never look like unlabeled. Done keeps a trace of its label's
hue and is struck; unlabeled keeps a full-strength title. The important star
lives on the pill, never in the title margin, and bounces with the pill. The
Toolbar's What Matters action is a star (outline off / filled on), matching the
star it filters for. Widgetbook: **Feedback → Task pill → All states** shows
all six rows. Verification:
`flutter test test/features/timeline/task_state_style_test.dart`.

## Chips — `AppSelectableChip` and `CategoryChip`

`AppSelectableChip` has two sizes: `compact` (default; caption text, fixed
height, for day and preset rows) and `regular` (body text, roomier padding,
for option pickers such as a behavior's type or a developer setting). Both
follow the "Pill shape" setting (`radiusPill`). `CategoryChip`
(`lib/features/task_detail/category_chip.dart`) is the one category picker
chip (label colour, glyph, name, hairline ring when selected), shared by the
category modal, the name+category modal and the task detail sheet. Both use
the shared press. **Never** hand-build a private chip. Extend one of these.

## Depth: create and delete — `AppDepthPresence`, `AppDepthShape`, `AppDepthFade`

The one motion for an object coming into and leaving the page (BRAND.md
§18). The object never scales, blurs or slides as a whole. Instead:

- **Room:** `AppDepthPresence` opens the object's own height first, so
  neighbours make room, and closes it after removal. Only then does it call
  `onExited`, so the caller deletes the data.
- **Shape:** the part marked `AppDepthShape` (a pill, a badge) springs up
  from small (30%) and transparent: **larger, smaller, then actual**, a
  real spring (`shapeSpringSeconds` .5, `shapeBounce` .45), in place about
  its own centre. On removal it simply shrinks and fades, with no bounce.
- **Text:** the parts marked `AppDepthFade` only fade in (and out).
- No blur anywhere. Several arrivals are staggered
  (`DepthMotionSpec.staggerFor`, 0.1s); the entrance is 0.8s. Reduced
  motion is instant. Markers are inert outside a presence.
  `emerge: false` keeps the room-making but holds the parts still, for when
  something else supplies the entrance (a card flying in).
- `AppDepthTransition` is the separate whole-object recede (fade + slight
  shrink), used for voice mode's controls.

Current use: Inbox rows (pill = shape, title and duration badge = fade). New
tasks emerge; switching section tabs does not replay them; swipe-remove
recedes and then deletes (with undo, and an undone task emerges again).
**Not** on Timeline pills: a just-created pill entrance was removed there on
request because it replayed on view switches. Widgetbook: **Feedback →
AppDepthPresence**. Verification: `flutter test
test/core/widgets/app_depth_test.dart test/features/inbox/inbox_depth_test.dart`.

## What Matters — ripple on, glow while on

Turning What Matters ON plays the upward ripple ring once. Turning it OFF
plays no ripple; the page just returns. While on, a soft radial glow
rises from the bottom centre (where the toolbar button sits), painted UNDER
all content, so the page itself reads as in a mode and a sparse day never
looks like missing tasks. The glow is painted by `WhatMattersBackdrop`, which
REPLACES the page's own solid background (`WhatMattersBackdrop(color: …)` in
place of `Container(color: …)`). A glow under an opaque page background is
never seen. The Timeline's bottom scroll fade is hidden while the mode is on,
because it would otherwise cut through the glow. It is low and soft (accent at 22–26% at its peak,
`WhatMattersTokens.glow*`), unlike voice mode's layered rising glow, so it
doesn't read as an AI mode. The What Matters toolbar action is the star.
Verification: `flutter test test/core/widgets/what_matters_appearance_test.dart`.

## Voice mode — morph in, glow rises; morph back, fly

Voice mode opens on its own root route (`pushVoiceModeRoute`). The route is
non-opaque and only supplies the timing (`VoiceModeTokens.enterSeconds` .7,
`exitSeconds` .8). The screen choreographs itself from the route animation:

- **Toolbar morph** (`AppPaneMorph`, reusable, `LiquidMorphSpec.dockPane`):
  the Inbox mic is a glass dock pane (`AppDockSurface` + `AppDockIconButton`,
  like the Day dock). Voice mode's toolbar (pause · waveform · submit) is one
  glass pane that stretches out of the mic's own rect with a spring, like the
  Day dock regrouping between views. The mic icon cross-fades into the
  toolbar content. On close it eases back into the mic without bouncing.
  It takes taps only once formed.
- **Toolbar position**: same height and bottom clearance as every other
  toolbar dock (`voiceToolbarLayout`: `spacingBottomClearance` above the
  safe area, pane = md button + `spacingXs` × 2). Close is its own
  single-item pane at the right edge (where the Inbox "+" sits). The
  pause/submit toolbar fills the row from `spacingXl`, one `spacingSm` dock
  gap to its left. Both panes split out of the mic and merge back into it.
- **Morph timing**: the entrance plays its springs in real time
  (`forwardSeconds` = `VoiceModeTokens.enterSeconds`), so the stretch is done
  in about 0.4s and then holds. It is firm (width bounce .12, height .08,
  `LiquidMorphSpec.dockPane`), and the whole pane springs larger, smaller,
  then actual (`popFrom` .75, `popBounce` .6). The return accelerates hard
  (ease-out-quart played backwards) and is home at `AppPaneMorph.returnEnd`
  (.55), i.e. in the first 45% of the exit.
- **Exit sequence**: everything returns together with the toolbar. The
  scrim lifts, the glow sinks and the Inbox rows sweep back (top first)
  within the first 45% of the exit (`VoiceModeTokens.revealShare`). That is
  the moment the toolbar is home in the mic. Flying tasks land by 80%
  (`flightLandShare`), still staggered.
- **"+" submerges**: as voice mode opens, the Inbox "+" swells
  (`DepthMotionSpec.submergeSwell` .15), then shrinks away while fading
  (`AppSpringPresence(swell:)`), so the close pane isn't just covering it.
  When voice mode starts closing, it springs back: larger, smaller,
  actual.
- **Waveform keys**: the bars rise in left to right, one after another, each
  on its own bouncy spring (up past its height, back under, then settled),
  like a run of piano keys. They start once the pane has stretched open
  (`AppVoiceWaveform(entranceDelay:)`, `VoiceModeTokens.key*`).
- **Can't listen**: if the recognizer can't start (permission denied, no
  recognizer), the status card says "Can't listen" with what to do, and
  Resume retries. It never passes for "Listening".
- **Page sweep** (`AppSweepFade`, reusable): while voice mode covers the
  Inbox, its tabs, day headers and rows fade by their own screen position,
  bottom first, as the glow rises (`voiceModeSweepProvider`, over the scrim
  share). They return top first as it sinks.
- **Glow** (`AppVoiceGlow`, reusable): the page colour fades in over the
  first half of the entrance. A layered glow rises from the bottom: a wide
  deep base, two drifting accent/light lobes and a bright core
  (`VoiceModeTokens.glowLayers`). It reaches ¾ of the height, and above that
  the screen is left clean (masked, not just faded). The lobes drift and
  breathe slowly (18s cycle), and are still under reduced motion. On exit it
  sinks.
- **Controls** (status card, transcript) arrive in the last 45% of the
  entrance and leave in the first 45% of the exit.
- **On Submit**, every line that became an Inbox task flies from where it
  sat into its Inbox row as a hero (`voiceFlightTag`), staggered so they land
  one after another. The rows open room for them (`AppDepthPresence(emerge:
  false)` via `voiceArrivalsProvider`). While each task flies, its pill
  emerges from depth exactly like a typed task's pill (small and
  transparent, then larger, smaller, actual), over that task's own staggered
  flight window. Its text, already on screen in voice mode, stays shown
  (`voiceFlightShuttle(index)`, `AppDepthScope(fadeText: false)`). Lines that became scheduled tasks
  fade with the transcript.

Widgetbook: "AppPaneMorph + AppVoiceGlow". Verification:
`flutter test test/core/widgets/app_sweep_fade_test.dart test/core/widgets/app_pane_morph_test.dart
test/core/widgets/app_voice_glow_test.dart test/features/inbox/voice_flight_test.dart
test/features/inbox/voice_capture_screen_test.dart`.

## Completion ripple — `AppWaterRipple`

`AppWaterRipple.show(context:, rect:, radius:)` is the "stone in water" half of
completion. Hairline rings leave the source shape's own outline (same corner
radius) and spread outward on a decelerating curve. Each ring thins and fades
as it travels, and each later ring travels less far. It uses the accent colour.
It sits on the root overlay, so it survives the row reflowing, and it ignores
pointers and semantics. Reduced motion skips it.

`WaterRippleSpec` defaults: 2 rings, .9s each, .14s apart, 22px spread, 1px
stroke, .22 peak opacity. It must stay very subtle: it confirms the event, it
doesn't decorate it. **Fired only through `AppCompletionFeedback.play`**,
which plays bubbles + ripple together; the `complete` pulse is state-driven
and plays on its own. Current callers: swipe-to-done in `TaskCapsuleBlock` and
in Zone view rows. The trailing checkbox still plays its own Noto emoji
celebration (an earlier explicit decision that conflicts with BRAND.md's "no
emoji applause"), so it gets the bounce but not bubbles/ripple until that is
decided. Widgetbook: **Feedback → AppWaterRipple → Task completion** plays the
pulse and the ripple together with six knobs. Verification:
`flutter test test/core/widgets/app_water_ripple_test.dart`.

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

**What it is**: the ONE rule for ordering zones before rendering them —
unselected zones paint first, selected zones next, and the actively lifted
zone paints last above every other zone. A moved object must stay in the
foreground while crossing lanes; being selected alone does not identify
which item owns the active drag.

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
List<Zone> selectedZonesLast(
  Iterable<Zone> zones,
  Set<String> selectedIds, {
  String? liftedId,
})
```
Stable partition — items keep their input order within each priority. The zone
grid supplies weekday-ordered zones to one shared stack so later day
columns cannot cover a lifted block that crosses into them.

**Current call sites** (as of 2026-09-28):
- `lib/features/timeline/timeline_screen.dart` — the spatial Task view's own zone band, via a `Consumer` reading `zoneEditSelectionProvider` (the outer `_DayTimelineState` is a plain, non-Riverpod-aware `State`, so a local `Consumer` is what reads the selection to reorder against, mirroring how `_DraggableZoneBlock` itself is already Riverpod-aware for the same "read `ref` locally rather than thread it" reason).
- `lib/features/zone_grid/zone_grid_screen.dart` — all saved day-column zones in one shared paint stack; the moving zone ID is passed as `liftedId`.

**General lifted-object rule**: active drag objects belong to the final
foreground interaction layer of their content canvas. They paint above
all peer content, including other selected objects and items in later
lanes. Their hit testing follows that same foreground order. A sheet or
system overlay may still cover the canvas as a separate higher-level
surface.

**Never**: rely on a repository's return order for render z-order, sort
inside an individual block widget, or keep cross-lane siblings in separate
stacks when one can move across them. Reordering belongs at the common
paint parent, where the whole peer set is visible.

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

## Sheets — components and interaction pattern

Reconciled 2026-09-29 against iOS (sheets, navigation inside a sheet) and
Material 3 (modal bottom sheets, which should not stack). Replaces the
2026-09-22 section, which had every chip open its own sheet on top of the
last and each sheet wire its own drag controller. The rules below are the
contract; the components enforce most of them.

### Interaction rules

1. **One sheet, pages inside it.** A control on a page (a chip, a row)
   opens ONE picker sheet over the page. Going deeper from that sheet
   (Label → New label → Color) pushes a **page inside the same sheet**
   (`AppSheetFlow`) — never another sheet on top. Two stacked sheets with
   two primary buttons is the bug this rule exists for.
2. **At most two levels are visible**: the thing you came from (a page,
   or the quick-create task sheet) under the scrim, and one sheet. The
   level below is dimmed and inert (the route's scrim barrier); only the
   top sheet's primary action is live.
3. **Header: × or ‹ left · title centre · primary action right.** The
   first page of a sheet closes (×); a deeper page goes back (‹). The
   title lives in the header row, never as a big heading in the body.
4. **Height fits the content** (`AppSheetSize.small`, capped at the
   viewport). No fixed half-height sheets with empty space. Moving between
   pages animates the height.
5. **Drag down closes — the whole sheet, from anywhere.** The handle, the
   header, the body; and on scrolled content, pulling down past its top.
   The sheet follows the finger; past the threshold (or a fling) it closes,
   otherwise it eases back. From a deeper page, the drag still closes the
   whole sheet, as on iOS. A `PopScope` guarding unsaved work still
   decides — a refused close eases back.
6. **The handle bar is decoration.** It never moves on its own and is not
   its own drag target: dragging it drags the sheet.
7. **Back steps through pages first.** Android back (and an iOS edge swipe
   inside a flow) goes back one page; on the first page it closes the
   sheet. A left-edge swipe never closes a sheet — on both platforms it
   means "back a page".
8. **Primary action never silently closes** unless closing is its whole
   outcome (a picker: pick one, done). Capture flows whose action is "add
   another" stay open (Quick Capture).
9. **Sheets sit above page chrome.** A page's own scroll fades belong to
   the page and paint UNDER any sheet (the Day fade used to darken the
   quick-create sheet's bottom). Sheets whose body scrolls (`StepScaffold`)
   carry their own top/bottom fades in their own surface colour; fitted
   sheets have none.

### Components

| Component | File | Role |
| --- | --- | --- |
| `AppSheet.show` | `core/widgets/app_sheet.dart` | The one entry point for a slide-up modal (never `showModalBottomSheet`). Sizes `small` (default) / `half` / `nearFull`. |
| `AppSheetSurface` | `core/widgets/app_sheet_surface.dart` | The panel: `SheetTokens.surface` fill, the toolbar's floating edge and shadow (`AppFloatingSurface`, solid, open bottom), top corners `radiusModal`. |
| `AppSheetDragDismiss` | `core/widgets/app_sheet_drag_dismiss.dart` | Rule 5: whole-sheet drag, scroll-at-top pull, `maybePop`, ease-back on refusal. Wraps every `AppSheet` panel and `StepScaffold`. |
| `AppSheetFlow` / `AppSheetFlowHeader` | `core/widgets/app_sheet_flow.dart` | Rules 1, 3, 4, 7: pages inside one sheet (`push`, `pop`), pages below kept alive, one fixed handle, the header that picks × or ‹. |
| `AppSheetHeader` | `core/widgets/app_sheet_header.dart` | The header row (72 high): × / ‹ left, `title` centred, `trailing` right, handle bar behind (off with `showHandle: false`). |
| `AppSheetHandle` / `AppSheetTopHandle` | `core/widgets/app_sheet_handle.dart` | The bar (`spacingXl * 1.2` × 4, `radiusSm`, `AppButton.subtleTint`) and its place: top-centre, `spacingSm` down. |
| `StepScaffold` | `core/widgets/app_step_scaffold.dart` | The near-full form sheet (task detail, zone/habit/template forms): own scroll fades, footer CTA. |
| `SheetTokens` | `core/tokens/component_tokens.dart` | `surface` (light: page bg; dark: `colorSurfaceSecondary`), `inset` (controls inside a sheet, one step off it), `dragCloseDistance` (96), `pageBehindShift` (.3). |

`AppDragToCloseHandle` remains the gesture engine under
`AppSheetDragDismiss` (distance-or-velocity threshold, live follow,
ease-back; `dragBy`/`release`/`cancelClose` on its controller). Sheets no
longer create their own controller. Exceptions that move their own panel:
the quick-create overlay (`QuickCreateSheetHandle`, three heights) and
`new_zone_sheet.dart` (in-tree, not a route).

### Building a sheet

```dart
// A single-page picker.
AppSheet.show<int>(
  context: context,
  builder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSheetHeader(theme: theme, title: 'Duration', onClose: close, trailing: done),
      SizedBox(height: theme.spacingMd),
      /* body */
    ],
  ),
);

// A sheet that goes deeper: pages in one flow.
AppSheet.show<String>(
  context: context,
  builder: (context) => AppSheetFlow(theme: theme, root: const LabelPage()),
);
// …inside LabelPage:
AppSheetFlowHeader(theme: theme, title: 'Label', trailing: addButton);
AppSheetFlow.of(context).push(AddCategoryPage(onSaved: …));
```

A page that is also opened on its own (New label from Settings) is the
root of its own `AppSheetFlow`; `AppSheetFlowHeader` shows × there and ‹
when pushed. Results travel by callback (`onSelected`, `onSaved`), not by
popping values between pages.

### Container details (`AppSheet`)

- Fill `SheetTokens.surface`; barrier `colorScrim`; body padding
  `spacingLg` horizontally and `spacingBottomClearance` at the bottom
  (`padded: true`); the route's `SafeArea` adds the device inset.
- Entrance/exit: `motionSheetSlide`, `curveDecelerate` in, `curveStandard`
  out; only the surface translates.
- `autofocusesKeyboard: true` holds the surface until the IME's final
  `motionSheetSlide` window (Android 11+ measured via
  `AndroidKeyboardAnimation`; elsewhere `motionKeyboardSettle` grace).
  Keyboard clearance belongs to `AppSheetMotion` — no caller padding.
- `SheetKeyboardBackground` paints the sheet surface behind the keyboard's
  rounded corners (`sheet_keyboard_background_test.dart`).
- Inline, in-tree sheets (Edit task drafts, new-zone naming) stay in the
  tree so the timeline stays interactive, and hide the bottom dock via
  `AppShellChromeController.setDockObscured(true)` for their lifetime.

### Spacing

| What | Token |
| --- | --- |
| Side inset for everything in a sheet (content left-aligned, never a centred shrink-wrapped column) | `spacingLg` |
| Handle top inset | `spacingSm` |
| Header row height | `spacingXl * 1.8` |
| Header → body | `spacingMd` |
| Title/name field → its settings chips | `spacingMd` |
| Between chips (both axes) | `spacingSm` |
| Header circle button | `spacingXl` |

**Never**: a sheet opened from inside another sheet; a big title in the
body; a per-sheet drag controller or `Transform` on the content; a fixed
`half` size for content that fits; a numeric literal for any spacing above.

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

**2026-09-29 — text style back to `textCaptionMono`.** It had drifted to the
smaller `textTaskEdgeTime` (the task start/end time rung), making list-view
hours visibly smaller than the timeline's. Reported directly: "hours zone
view are smaller than spatial view... should align." It now uses the same
`textCaptionMono` + `colorTextSecondary` as `TaskBoundaryMarkers`.
`textTaskEdgeTime` stays for task edge times (`TaskEdgeTimeLabel`).

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
The helper pushes on the root navigator so this full-page voice mode covers
the persistent top navigation as well as the Inbox content. Keep the voice
screen's own close control as its only header action.

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

**Exception — Weekly Zone Authoring Grid uses `theme.radiusMd`**
(2026-09-28, superseding its earlier `radiusSm` exception): the compact
weekday blocks need more corner rounding in edit mode, while `radiusMd`
preserves their narrow lane shape. The saved fill, selected outline,
move-source ghost, and cross-day ghost all use this same radius. The
spatial Timeline's `ZoneBackgroundBlock` keeps `radiusXl`.

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

**Current call sites** (as of 2026-09-29): `task_remove.dart`'s
`removeTask` (the action sheet's Remove row and the detail screen's delete
button), `zone_grid_screen.dart` (the Edit Mode selection dock's group
Remove for tasks, the Zones tab's own bulk "Remove placements", and its
zone drag-to-delete), `zone_form_screen.dart` (its own delete button), `inbox_screen.dart`
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
Removed actions lose input, focus, and semantics immediately, then fade out
while shrinking (no bounce). New actions are laid out at their final position,
then fade in while springing up from small: larger, smaller, then their real
size, the same bounce as the view switch press. New panes do the same, with
their first icon. This is `AppSpringPresence` (reusable; springs from
`DepthMotionSpec.shapeFromScale/shapeSpringSeconds/shapeBounce`). Every
configuration change uses it, including Day ↔ Edit and the selection
actions. The
floating create button is a separate primary-action slot and is not a dock
action.

The main dock and standalone bottom controls sit inside the bottom safe
area with one additional `spacingBottomClearance`. Use that same placement
for every page-local dock so toolbar buttons share a baseline across Day,
Inbox, Tracked, and Edit.

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

## Page slide follow-through — `AppFollowThrough`

When the top-nav pages slide (`AppViewTransition(slide: true)`), the page's
KEY items (things the user adds on that page) follow through: they trail
the page and catch up one after another.
- **Timeline**: one timeline of `FollowThroughSpec.pages.totalMs` (380ms).
  The page slides over its first 60% (228ms, was 150ms), and each item runs
  the same motion delayed within the remaining 40%, so everything lands by
  the end.
- **Order** (by position on screen, no indexes): rows higher up go first
  (`rowWeight` .75). Across the page, the edge leading the travel goes
  first: moving left (forward), the left side leads; moving right (back),
  the right side leads.
- **Direction**: it works entering and leaving, in whichever direction the
  page travels.
- **Nested**: a follower inside another (a Tracked card's dots) trails its
  own card, not the page, within `nestedShare` (.3) of the tail. So a card's
  dots ripple after the card.
- **Where**: Inbox task rows, Day non-spatial (Zone view) task rows, Tracked
  cards and each day dot (`_DayCell`, in every view mode).
- **Mechanism**: paint-only (layout and hit testing never move), and inert
  outside a sliding page.
- **Cost**: each follower works out where it sits (its delay, and the card
  it trails) ONCE per slide (`AppFollowThroughScope.generation`), not every
  frame. The screen-position lookups are the expensive part, and a
  six-month heatmap puts ~900 dots on screen. Per frame, a follower only
  evaluates its curve and translates its canvas (no layer).
- **Layering**: during a slide, the page being left paints ABOVE the
  arriving one, in either direction (e.g. Inbox → Day: Inbox on top). Its
  items trail back toward the arriving side, and the arriving page's
  background would otherwise cover them.
- **Clipping**: a page's scrolling list clips at its top and bottom only
  (`AppVerticalClip` around a `clipBehavior: Clip.none` list). Otherwise the
  list cuts trailing items off at the page's side edge, which reads as the
  new page covering them. This applies to the Inbox, Day (Zone view) and
  Patterns lists.

Widgetbook: "AppFollowThrough". Verification: `flutter test
test/core/widgets/app_follow_through_test.dart`.

## Day tasks emerge and recede — `DayTaskMotion`

Day tasks now do the same create/delete motion as Inbox tasks, in both
views:
- **Arriving** (created, scheduled onto this day, undone back): the pill
  springs up from depth (small and transparent, then larger, smaller,
  actual) and the title fades in.
- **Leaving** (deleted, moved to another day or back to the Inbox): the pill
  and title recede. The timeline task recedes in place, since tasks sit at
  fixed times (`AppDepthPresence(opensSpace: false)`). A list row also
  closes its room.
- **Changing the day never animates.**
- **Tracking lives above the widgets**, in `dayTaskMotionProvider`, which
  listens to the day's tasks. Switching timeline ↔ list remounts every task,
  and a mount-time entrance used to replay on every switch (the reason the
  old one was removed). Arrivals are cleared once their first frame is
  built. Leaving tasks stay drawn (`DayTaskMotion.shown`, in time order),
  untouchable, until they have receded.
- **Wiring**: `DayTaskMotionScope` (placed by `TimelineScreen` over both
  views) feeds `DayTaskPresence`, which is inert outside it. Marked parts:
  the pill (`AppDepthShape`, about the pill's own centre) and
  `TaskCapsuleTextRow` (`AppDepthFade`), plus the list rows' badge and
  title.
- **Page switches**: timeline tasks also trail the page as it slides
  (`AppFollowThrough`), like the list rows.

Known gap: an unzoned list row (a `TaskCapsuleBlock` with its own inline
text) emerges its pill, but its inline title does not fade.

## Task list row — `TaskListRow`

**File**: `lib/features/inbox/task_list_row.dart`. The ONE card for a task
in a list: the Inbox rows AND voice mode's spoken lines both use it, so a
task looks identical while being spoken, while flying into the Inbox, and
once it lands.
- **Pill**: `sizeTaskBadge` at `radiusPill`, with the category glyph at 55%.
  A task with no label yet ("General") wears the reserved unassigned tone
  (`TaskStateTokens.unlabeledFill`), exactly as on the timeline, never a
  label swatch. Voice lines have no label yet, so they wear it too.
- **Title**: `textTaskTitle` w700. A line still being spoken uses the
  secondary colour.
- **Forming cue** (`pendingProgress`): a hairline (`borderWidthHairline`,
  accent) traced just OUTSIDE the pill's edge, one hairline away, from the
  top clockwise. It never paints over the pill. Voice mode fills it over
  the 2s silence window (`voiceCaptureSilenceGap`), restarting with each
  new word, so it closes as the task is finalised. It replaced the
  spinner that sat inside the pill.
- Takes part in depth emergence (`AppDepthShape` pill, `AppDepthFade`
  title).

## Toolbars on page change — submerge and emerge

- **Dock buttons** (every `AppContextDock`) now leave by submerging: they
  swell (`DepthMotionSpec.submergeSwell` .15), then shrink away and fade.
  That mirrors their springy arrival (larger, smaller, actual). The fade
  starts at once, so the stagger reads the same as before.
- **Page toolbars** (the "+" on Day/Inbox/Patterns, the Inbox mic, the
  Patterns view dock) live inside their pages but don't slide with them.
  `AppPageToolbarAnchor` holds them in place while the page slides, and
  `AppPageToolbarGate` hides them the moment their page starts leaving, so
  they submerge. On arrival they are revealed after `revealDelay` (200ms),
  once the leaving toolbar has gone: out, then in. `AppPageToolbarItem`
  combines these with the spring for single buttons. The Patterns view
  dock empties and refills, so its buttons stagger like the Day dock's.
- **Several buttons stagger**, left to right, both going and coming, one
  dock step (35ms) apart (`AppPageToolbarItem.order`,
  `AppFloatingCreateButton.toolbarOrder`). Inbox: mic 0, "+" 1. Patterns:
  the view dock's three buttons, then the "+" (order 3).
- **Exceptions**: a toolbar that is there at app start doesn't animate.
  Outside a sliding page (e.g. the Edit screen's "+") it is always shown.

## Done tasks fade their star; the week strip has no tap wash

- **Star**: a completed important task's star fades with its title
  (`TaskImportantStar(faded:)`, `TaskStateTokens.doneStarAlpha` =
  `doneTitleAlpha`). Only the star's fill fades; its surface-coloured
  outline keeps separating it from the pill. This applies on the timeline
  (`TaskCapsuleBlock`) and in list rows (`zone_container_block`).
- **Week strip**: the Day screen's 7-day pills (`AppDateAccordion`'s
  `_WeekDayCell`) have no tap wash (`AppPressFeedback(ripple: false)`),
  the one exception to the shared press feedback. The selected-day state
  already answers the tap. The press squeeze and haptic stay. `ripple`
  defaults to true everywhere else.

## Sub nav — `AppSubNav` (page-heading slot)

**File**: `lib/core/widgets/app_sub_nav.dart`. A page's own navigation
under the main nav (first user: the Inbox sections).
- **Labels**: `AppNavLabel` (extracted from `AppTopNav`) in its
  `AppNavLabelVariant.sub`, i.e. the page-heading type
  (`PageHeadingTokens.text`: body copy one step down the scale, 14 instead
  of 16, regular weight, the Day date's own weight). Selection is shown by
  colour only (primary vs tertiary). The gap is the main nav's `spacingLg`.
  The main nav itself is unchanged (`textBody`, w700/w500, 40px row).
- **One heading type and line across Day, Inbox and Habits**: the Day date
  (`AppDateAccordion`), the Habits period (`_TrackedPeriodHeading`) and the
  sub nav all use `PageHeadingTokens.text` on a fixed
  `PageHeadingTokens.rowHeight` line (24 = `spacingLg`) with the text
  centred. The small controls on that line (chevron, "Today", "+") can't
  nudge the text, and the three line up by construction.
- **The page-heading slot**: screen padding at the sides, no top padding,
  then `spacingXs × 2` and `spacingSm` below. This is exactly the Day date's
  (`AppDateAccordion` in `AppCalendarHeader`) and the Habits period
  heading's (`_TrackedPeriodHeading`) footprint. The first label sits where
  those dates sit, so switching Day ↔ Inbox ↔ Habits the heading line
  doesn't move. Pinned by `inbox_sub_nav_alignment_test.dart`.
- **`AppSubNavLabel.highlighted`**: a soft `colorSurfaceField` wash behind
  the label that takes no layout, used for "drop a row here". Tapping the
  selected section still opens Rename/Remove, and long-press still works.
- **Trailing action**: never taller than the labels (the Inbox's "+" is a
  bare `spacingMd` icon), and the row is top-aligned so it can't push the
  labels down.

Widgetbook: "AppSubNav".

## Main nav settings gear — optical right edge

The gear is `TopNavTokens.settingsIconSize` (20, was `spacingMd` 16) in its
unchanged 40px tap box. The box is pulled right by (40 − 20) / 2, so the
glyph, not the invisible box, ends on the screen-padding line, optically
aligned with that edge. The tap box moves with it. Pinned in
app_top_nav_test.dart.

## Navigation active state — `AppNavPress` / `AppNavWash`

Main nav destinations, the settings gear and sub-nav tabs don't use the
shared dark press wash (`AppPressFeedback(ripple: false)`, keeping the
squeeze and haptic). Their active state is the next surface up,
`colorSurfaceSecondary` (the Settings group container surface), drawn
behind the label/icon, a little past it, with no layout (`AppNavWash`).
It shows while pressed, and on a sub-nav tab while a drag hovers it. That
is the same subtle step as the week strip's selected day.
`AppNavLabel` moved to `app_nav_label.dart` (re-exported by
`app_top_nav.dart`).

## Pinch vs. marquee — `TimelineMultiTouch`

Two fingers down is a pinch, never a marquee. `TimelinePinchZoom` (already
tracking pointers for zoom) publishes "two or more fingers down" as a
`ValueNotifier<bool>`. Descendants read it via `TimelineMultiTouch.of`, and
an owner above it can pass its own (`multiTouch:`).
- **Edit Tasks** (the task-pill sweep, `_DraggableTaskBlockState`): a drag
  that begins with two fingers down is ignored entirely. A second finger
  landing mid-sweep cancels it through `_cancelMove()`, removing the
  marquee and restoring the pre-sweep selection. A second finger landing
  mid-MOVE cancels the move the same way: dropped unsaved, and the task
  stays where it was.
- **Edit Zones** (the long-press paint marquee in `ZoneGridScreen`): it
  won't start while two fingers are down (two still fingers read as a
  long-press), and a second finger landing mid-paint abandons it via
  `_cancelPaint()`.

## Connected buttons — liquid selection (`AppLiquidSlide`)

A selection highlight moving between connected segments is gooey, not
rigid. `AppLiquidSlide` (`LiquidSlideSpec.connected`) springs the edge that
leads the travel to its new place quickly (.3s, bounce .25) and the
trailing edge on a slower spring (.48s, bounce .15). The highlight
stretches toward the target, thinning a touch (`squash` .12 per unit of
stretch), then its tail catches up and it settles exactly on the new
segment. Reduced motion jumps. Used by:
- `AppTabSwitch` when its segments fit (e.g. the Edit screen's Things |
  Zones): one shared highlight under equal segments. A scrolling, overflow
  switch keeps its per-segment highlight.
- `AppContextDock` groups of two or more buttons (e.g. the Day dock's
  Timeline | List): one highlight per group, with the buttons'
  own fill off (`AppDockIconButton.showsSelectedFill`). Single-button panes
  keep their own fill.

The Edit screen's first tab is labelled "Things" (was "Tasks"), matching
the main nav.
