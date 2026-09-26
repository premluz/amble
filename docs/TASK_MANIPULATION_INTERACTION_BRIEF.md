# Task manipulation: interaction review and reusable architecture

Status: first implementation slice completed, 2026-09-26.
Scope: small task hit areas, selection, resize, move, crowded lanes, and reuse in the zone grid.

Implemented in the spatial task Timeline:

- `TaskManipulationTargets` keeps two dots on the true capsule edges, with
  wider invisible hit regions and a side move region on tiny tasks. The
  initial displaced controls, labels, and connectors were removed after
  device feedback; see the 2026-09-26 correction in DESIGN_SYSTEM.md.
- The current primary task paints above neighboring tasks. Starting a move on
  another selected task promotes it without changing selection membership.
- Other selected tasks retain their existing in-pill Start/End handles, so
  group resize can still begin from any selected member.
- Pointer cancellation rolls back move/resize preview state while retaining
  selection, with recognizer and raw-pointer cancellation coalesced exactly
  once.
- Handle taps are consumed and cannot fall through to the task body or
  empty-Timeline deselection/create behavior.

The viewport-wide placement layer, auto-scroll/session unification, keyboard
actions, draft reuse, and seven-column zone-grid adapter remain later slices.

## Recommendation

Historical proposal below: the displaced compact controls and connectors were
rejected in device feedback. The implemented summary above and DESIGN_SYSTEM.md
take precedence; do not reintroduce that visible layout.

Separate scheduling geometry, visual geometry, and interaction geometry.
An active task retains its true duration and lane position, but its manipulation controls live in a foreground layer sized to the timeline viewport, not inside the tiny capsule.
Give controls independent touch targets; resolve overlap explicitly rather than letting widget insertion order choose an operation.
When three usable targets cannot fit near the true edges, visibly separate the controls with short connectors to those edges.
Larger invisible rectangles alone cannot solve three competing operations on a 24 px capsule.

## Findings from the current implementation

These are source findings, not a reproduction on a device. Existing test definitions were inspected; execution was blocked by approval review.

| Finding | Evidence | Consequence |
| --- | --- | --- |
| Task handles consume the pill interior. | [resize_handle.dart](../lib/features/timeline/resize_handle.dart), `taskResizeHandleHeightFor` | Smaller tasks lose resize area and eventually all body-move area. |
| Targets span the badge width; default badge width is 24 logical px. | [task_capsule_block.dart](../lib/features/timeline/task_capsule_block.dart), handle `Positioned(left: 0, right: 0)`; [semantic_theme.dart](../lib/core/tokens/semantic_theme.dart), `sizeTaskBadge` | Increasing target height alone leaves horizontal aiming difficult. |
| The visible dot is translated beyond its target's edge. | `ResizeHandle.build` | Part of the visible affordance can lie outside its own effective touch region. |
| Handles are sibling detectors above the body detector. | `TaskCapsuleBlock` | A useful existing separation: keep resize and move out of nested competing vertical-drag detectors. |
| Task stacking promotes the dragged/settling task. | [timeline_screen.dart](../lib/features/timeline/timeline_screen.dart), `_dragLastOrder` | Selection/arming and resize do not receive equivalent priority through this function. Full overlap symptoms need runtime confirmation. |
| Empty taps clear armed-task and multi-task selection, then return. | `TimelineScreen.onEmptyTap` | Correctly avoids creating a task on the same deselection tap, but an unprotected handle near-miss can reach this path. Full Edit mode itself is separate. |
| The empty timeline uses a raw pointer-up tap approximation. | [place_task_line.dart](../lib/features/timeline/place_task_line.dart), `_handlePointerUp` | It checks elapsed time and final displacement, not maximum excursion or a shared gesture owner. A move away and back deserves explicit regression coverage. |
| Resize and capsule drag APIs lack a cancellation callback. | `ResizeHandle`, `TaskCapsuleBlock` | There is no explicit callback contract here for rolling back a canceled preview; do not assume `onEnd` will clean it up. |
| Zone-grid handles also remain inside block bounds, defaulting to 16 px high. | [zone_grid_block.dart](../lib/features/zone_grid/zone_grid_block.dart) | The same ownership issue occurs in a genuinely different layout: seven narrow day columns and two movement axes. |
| Zone axis-lock cancellation clears its local axis without forwarding a cancellation callback. | `_AxisLockedMoveExtendDetector` | Shared cancellation should reach preview/session state, not merely reset the recognizer. |
| Task sweep selection currently checks Y, not lane X. | `_sweepSelectAt` | It behaves as a time-band selection across lanes. Preserve this deliberately; do not silently reinterpret it as a narrow finger path. |

Current task geometry, derived from the helper with the default theme:

| Actual pill height | Each handle's height | Remaining body-move height |
| --- | --- | --- |
| 72 px | 24 px | 24 px |
| 48 px | 12 px | 24 px |
| 24 px | 8 px | 8 px |
| 16 px | 8 px | 0 px |
| 4 px after trimming/capping | 2 px | 0 px |

This is not caused only by task duration: zoom, badge size, `bottomTrim`, and `maxPillHeight` affect the actual result.
The [existing height tests](../test/features/timeline/resize_handle_height_test.dart) explicitly accept 2 px handles on a 4 px block. They protect non-overlap, not usability.

## Platform guidance and Flutter constraints

- Android recommends at least 48 × 48 dp touch targets and explicitly permits a smaller visual icon: [Android accessibility guidance](https://support.google.com/accessibility/android/answer/7101858?hl=en-GB).
- Apple generally recommends at least 44 × 44 pt hit regions: [Apple buttons guidance](https://developer.apple.com/design/human-interface-guidelines/buttons).
- Use 48 × 48 Flutter logical pixels as the proposed shared touch minimum. This is a starting design token, not a claim that every crowded arrangement becomes usable automatically.
- `Clip.none` changes painting, not ancestor hit-test bounds: [Flutter Transform hit testing](https://api.flutter.dev/flutter/widgets/Transform/transformHitTests.html). The historical conclusion in `ERROR_LOG.md` is correct for children of the pill, not a prohibition on viewport-owned targets.
- `HitTestBehavior.opaque` does not assign priority between parent and child gesture recognizers: [Flutter GestureDetector](https://api.flutter.dev/flutter/widgets/GestureDetector-class.html). Use deliberate target ownership and gesture arbitration.

## Interaction contract

### Selection and focus

Keep three concepts separate: route Edit mode, selected IDs, and the primary manipulation target.
Long-press arming remains separate from the full Edit screen. A protected near-miss changes none of them.
In multi-selection, the primary target is the last deliberately selected/manipulated member; the gesture affects the captured selection using existing group rules.
Recommendation: show expanded controls for the primary member only; retain selection borders on the others. This is a proposed presentation change, not an already-adopted rule.
Starting a drag on another selected member may promote it without changing membership. A short tap on its body retains the existing toggle-selection behavior.

### Hit areas and dense layouts

1. Place normal Start/End targets at their visible affordances, at least 48 × 48 logical px for touch, expanding outward and sideways in viewport coordinates.
2. Reserve a distinct usable Move target, using the body/label or a visible move affordance in compact mode. Do not sacrifice it to resize targets.
3. If these regions intersect, use compact manipulation chrome: three separated Start/Move/End touch cells, visually linked to the true task edges/body. Do not secretly assign their overlapping areas by Stack order.
4. Prefer outward placement; near viewport boundaries, use a side rail with enough room. Preserve minimum targets instead of clipping them under the header, dock, keyboard, or system gesture inset.
5. Do not enlarge the actual duration geometry or move neighboring tasks to manufacture touch space. The schedule must remain legible and truthful.
6. If no usable placement exists, offer the existing time editor with accessible controls; never silently shrink targets back below the minimum. The implementation should make this fallback exceptional and explicit.

All visible handles must lie within their effective hit regions. Targets must stay inside the interactive viewport and outside reserved chrome.
Keep normal dots small. Compact mode may displace/enlarge the visible affordances enough to explain where the controls actually are; this requires device design review.

### Priority and accidental deselection

Priority is: existing pointer owner → primary manipulation controls → primary task body → other selected bodies → unselected tasks → empty background.
Apply the same ordering to painting and target resolution. The active task and its chrome stay above neighbors during selection, resize, move, commit, and settle.
An expanded handle target intentionally owns its bounded overlap with a neighboring task. A tap there preserves selection; a drag there resizes. Do not forward the same sequence to the neighbor or background.
Do not cover an entire lane with an invisible selection shield. Keep a distinct visible route to neighboring tasks, such as an unobscured label; reposition compact chrome if it blocks every route.
Overlapping primary Start/End/Move regions are a layout failure requiring compact chrome, not a nearest-distance tie to guess at.
For other expanded target ties, prefer a visible body hit, then distance to the affordance, then stable ID; never incidental render order.
Clear selection only after a completed, unclaimed empty-space tap: both endpoints outside protected regions, no earlier movement beyond device slop, no cancellation, no scroll or manipulation owner.
A failed drag attempt inside a handle region is a consumed no-op. It must not toggle selection or create a task.

### Gesture lifetime

Model `ready → pending pointer → moving / resizingStart / resizingEnd / sweeping / scrolling → committing / settling → ready`.
Cancellation returns to ready with original data and retained selection; it is never a successful drop.
At pointer-down, record candidates, pointer ID, geometry, and original schedule values. Resolve ownership once intent is accepted, using platform/device gesture slop rather than a custom arbitrary delay.
Freeze operation, edge, primary target, and affected IDs for that gesture. Crossing a handle or neighboring task cannot switch resize to move or deselect anything.
Retain control identity and hit geometry throughout the gesture. Do not rebuild/reparent its recognizer on selection, lift, toolbar changes, or lane reflow.
Track cumulative displacement and maximum excursion; returning to the down position does not turn an accepted drag back into a tap.
Use one canonical time/viewport transform incorporating scroll offset. Auto-scroll must update preview time even when the finger remains stationary, using frame elapsed time rather than pointer-event frequency.
Keep zoom fixed during an accepted manipulation. Extra fingers do not steal it; pinch may win while still pending. OS pointer cancellation still aborts cleanly.
Release commits at most once through existing providers/undo. Persistence failure restores a consistent preview and reports the error. No writes on every move event.
Clear all temporary group broadcasts, delete-target state, and auto-scroll on cancel, route disposal, or app interruption.
If the affected item is removed or revised, or the date/view changes during manipulation, cancel the session rather than silently committing stale data; ordinary preview rebuilds do not count as revisions.
Drag-to-delete is available only to the existing permitted move gesture; resize can never enter it.

### Preserve existing domain semantics

- Move changes position while preserving duration; preserve existing overlap/cascade policy.
- Start resize keeps each task's end anchored; End resize keeps its start anchored. Edges never cross; retain existing day/minimum-duration constraints and five-minute snapping.
- Group task resize keeps existing independent per-task clamps; do not silently turn it into proportional scaling or a group-wide clamp.
- Zone group validation remains its existing all-or-nothing policy. Share interaction machinery, not task-specific commit rules.
- Preserve existing armed-task tap behavior, selection-body tap toggles, sweep semantics, and undo. Any product change to these needs explicit agreement during implementation.

## Reusable architecture

Names below describe proposed responsibilities, not existing APIs or a requirement to build one large framework.

| Piece | Responsibility |
| --- | --- |
| `ManipulationGeometry` | Pure calculation of visual rects, minimum hit rects, compact placement, reserved regions, and explicit priorities. Input is actual geometry, not task duration alone. |
| `ManipulationSession` | Route-local pointer ownership, primary ID, captured selected IDs, operation, original values, preview, cancellation and completion. Selection providers remain authoritative for membership. |
| `ManipulationLayer` | A bounded viewport-level sibling of timeline content, above task paint and below application chrome/modals. Renders and hit-tests only registered controls; unused space passes through. |
| Task / draft / zone adapters | Supply capabilities, coordinate conversion, snap/clamp preview, and commit/undo through existing providers. No Hive access or persistence in the interaction layer. |
| Semantic interaction tokens | Minimum touch target, protected-region geometry, compact-control spacing and lift styling; reuse existing primitive scales and haptic/snap services. Do not scatter constants across callers. |

Use ordinary sized overlay targets and Flutter recognizers where possible. A custom hit-test container is justified only if disjoint regions cannot be expressed cleanly; it must use the same resolver geometry as painting and semantics.
Do not add a full-screen opaque gesture detector, route-wide modal barrier, or duplicate interactive `TaskCapsuleBlock` subtree.
Keep keyed task children under stable parents; changing sibling paint order is different from reparenting the active detector.
The empty-tap raw listener must consult session ownership, or migrate to a compatible tap recognizer with regression coverage for its existing long-press placement behavior.
Do not assume arena victory alone suppresses raw pointer listeners. Register target geometry before pointer-down, never one frame after the interaction has already begun.
Only the active overlay needs frame-by-frame updates; avoid rebuilding every task or sorting all tasks on every pointer move.

## Accessibility and feedback

Expose Start time, End time, and Move as distinct semantic actions with current time values, keyboard adjustment, and a non-drag time-editor path.
Use the same interaction regions for focus/semantics so assistive technology does not inherit the tiny painted-dot bounds.
Announce committed values and constraints, not every raw pointer pixel. Keep lift/snap/drop haptics in the existing shared system and avoid repeated boundary vibration.
Pause decorative wiggle on the primary task during manipulation; reduced motion must not disable direct tracking or shrink hit regions.

## Implementation order and acceptance criteria

1. Capture current behavior with targeted interaction tests; retain existing resize/move/group math and undo coverage.
2. Build geometry and primary-task overlay for one task, including compact controls and viewport exclusions.
3. Unify pointer ownership, cancellation, empty-tap protection and stacking; then connect group selection and drafts.
4. Reuse the same contract in the seven-column zone grid with its separate horizontal-extend and validation adapter.
5. Update DESIGN_SYSTEM and supersede the historical inward-only compromise when the behavior is approved and implemented.

Required automated scenarios:

- Hit samples across each target, including invisible outward/side strips and the visible dot; validate actual callback ownership, not only render-box size or center taps.
- Task heights 4/16/24/48/72 px, supported badge sizes and zoom levels; all three operations reachable with non-overlapping compact targets.
- Back-to-back tasks in one lane and overlapping tasks in three lanes; primary task selected before any drag; near-miss never selects a neighbor or clears selection.
- Independent seven-column zone cases with narrow columns and horizontal extension; do not validate the resolver against only task capsules.
- Handle tap without drag, short jitter, move away and back, crossing targets, pointer cancel, second pointer, route pop, and pending commit failure.
- Group move/start/end resize with different durations and day-boundary clamps; affected IDs stay stable; one commit/undo operation; no resize-to-delete handoff.
- Auto-scroll at both viewport edges, scrolling near a selected task, zoom changes before a gesture, and controls near header/dock/keyboard exclusions.
- Normal empty taps still clear selection once and do not also create; normal unselected-task access and existing time-band sweep remain available.
- Accessibility actions, large text, reduced motion, and frame timing measured inside the test/runtime environment.

Device evaluation must still establish thumb reach and error rate in dense schedules; static analysis cannot certify the physical comfort of the proposed compact controls.
Verification for the implemented slice: targeted analysis is clean and the
88-test task-manipulation group passes, covering compact targets at
4/16/24/48/72 px, cancellation, legacy handles, armed editing, group resize,
selection, edge anchoring, live labels, and finger tracking. Device evaluation
and the deferred cross-layout scenarios above remain open.
