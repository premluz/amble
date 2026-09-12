# Code and architecture review — 2026-09-10

Reviewed the current working tree, including the concurrent changes to non-spatial Zone view and List filters. This is a review, not an implementation of the recommendations. Existing user changes were preserved. Priorities below reflect likely user impact; P1 means fix before relying on the affected behaviour, P2 means a narrower correctness or lifecycle problem.

## Ranked correctness findings

### 1. P1 — Opening a keyboard sheet can leave later sheets floating above empty space

**Location:** `lib/core/widgets/app_sheet.dart:40,82,97`.

Every sheet uses `max(liveInset, _lastKeyboardHeight)`, including sheets with no text input. The static value is never cleared when the keyboard closes. A widget reproduction opened a sheet with a 300px inset, closed it, then opened a plain 100px sheet with no keyboard: its bottom was at 500 in an 800px viewport, leaving 300px of empty space.

The comment claiming a sheet without focus collapses to zero is contradicted by the code. The cache also overwrites its value with every positive intermediate inset; it is not a stable remembered target during keyboard animation. Window, orientation and IME changes compound this problem.

**Recommendation:** remove the unconditional reservation. If reservation is retained, make it explicit for keyboard-requiring routes, scoped to the current view, with a defined release condition and stable opening target. Test opening a non-input sheet after a keyboard sheet, keyboard dismissal, and intermediate inset frames.

### 2. P1 — Editing Repeat does not transition the zone's persisted recurrence state

**Location:** `lib/features/zones/zone_form_screen.dart:222`; `lib/shared/providers/zone_providers.dart:82,96`.

The form changes `recurrenceRule`, but `updateZone` only saves. It neither changes `recurrenceId`/`anchorDate` nor reconciles materialized rows.

Real Hive/provider reproductions confirmed:

- Enabling Repeat on a dateless zone leaves one dateless row with no recurrence ID. Materialization exits without generating occurrences.
- Disabling Repeat on a series template leaves 57 dated rows with recurrence IDs, but no template rule. The zone-management filter then displays zero entries for that series.

Changing weekdays similarly leaves previously generated days in place. This is separate from the intentional policy that ordinary occurrence title/time edits affect one instance.

**Recommendation:** introduce explicit enable/change/stop recurrence operations that reconcile rows and references, or disable unsupported transitions in the form until implemented. A generic save is insufficient for this lifecycle.

### 3. P1 — The final List cluster can extend beyond the scrollable content

**Location:** `lib/features/timeline/timeline_screen.dart:1615,2648`.

`_collapsedTops` allocates cluster row height, but content height is reconstructed from individual block tops plus a single collapsed-block height. The final cluster's full height is lost.

A real `TimelineScreen` widget reproduction with 30 earlier tasks and a final three-task cluster reached maximum scroll with the cluster bottom at 972 and viewport bottom at 852: 120px remained unreachable.

**Recommendation:** compute row tops, row heights and total content extent together, and consume that same result for painting and scrolling.

### 4. P1 — Zone non-overlap validation does not cover all affected dates

**Location:** `lib/features/zones/zone_form_screen.dart:177`; `lib/shared/providers/zone_providers.dart:68,96`; `lib/features/timeline/timeline_screen.dart` (`_commitZoneCascade`).

Source-verified: the form validates the selected/template day, then materializes other days without validating them. An existing Wednesday 09:00–10:00 zone does not prevent a daily series created on Monday at that time from overlapping it on Wednesday. A dateless zone also affects every day, while the form checks one day.

The cascade has the same boundary problem: moving a dateless row changes all days, although candidates were filtered to the viewed day. Containment subsequently chooses a matching zone under an invariant that no longer holds.

**Recommendation:** validate the complete affected date set in the mutation command. Keeping the pure cascade algorithm day-scoped is reasonable if its input is a validated day plan; moving the current filter into that function alone would not solve global dateless mutations.

### 5. P1 — Zone alarms are missing after creation and stale after movement

**Location:** `lib/shared/providers/zone_providers.dart:96,151,195`; `lib/features/zones/zone_form_screen.dart:233`.

Two real Hive/provider reproductions with a notification spy confirmed:

- Creating a daily series persists 57 rows, but the form schedules only the template's alarm. Upcoming occurrences depend on another app launch to enter the notification horizon.
- Moving a zone from 09:00 to 10:00 through the cascade changes persistence to minute 600 while its registered alarm remains at minute 540.

Avoiding one alarm per generated row is sensible. Omitting a bounded notification reconciliation after mutations is not. Reusing Task's materialization policy does not establish correctness for Zone.

**Recommendation:** reconcile a bounded horizon after create/edit/cascade. Coordinate Task and Zone refresh: Task's global cancellation and the two unawaited launch refreshes present a race risk. Zone refresh also needs per-item failure containment. A day horizon alone is not an absolute alarm-count budget.

### 6. P2 — Disabling List clustering puts overlapping task titles on top of each other

**Location:** `lib/features/timeline/timeline_screen.dart:1597,2648`.

Group members retain the same collapsed top even when the cluster widget is disabled. The separate label-placement map is absent in List mode. With the exposed clustering preference disabled, a widget reproduction found both visible task titles at exactly `Rect(112, 24, 326, 42)`.

**Recommendation:** represent individual List rows explicitly when clustering is disabled. The current test only verifies that the cluster widget disappears.

### 7. P2 — AppButton's native keyboard activation calls a no-op

**Location:** `lib/core/widgets/app_button.dart:124,187`.

The platform button receives a no-op callback while the outer gesture detector owns pointer activation. A widget reproduction focused the button with Tab and pressed Enter: the application callback ran zero times.

The gesture-arena rationale also needs correction. `onTapUp` does **not** skip arena resolution; Flutter invokes it after the recognizer wins, immediately before `onTap`. It does not provide the claimed shortcut, and a scroll that wins the arena does not become a tap through this mechanism. `AbsorbPointer` terminates hit testing at itself; its child is not kept hit-testable as the comment claims. See [Flutter onTapUp documentation](https://api.flutter.dev/flutter/gestures/TapGestureRecognizer/onTapUp.html) and [AbsorbPointer documentation](https://api.flutter.dev/flutter/widgets/AbsorbPointer-class.html).

**Recommendation:** give the platform button its actual callback and use decoration-only press feedback around it. Preserve gesture ownership for genuinely custom tap targets. This finding establishes a keyboard regression, not a blanket claim that screen-reader activation fails.

### 8. P2 — Horizontal padding is doubled for task labels and missing for a zone label

**Location:** `lib/features/timeline/timeline_screen.dart:2124,4645,4702`; `lib/features/timeline/zone_background_block.dart` (`ZoneNameLabel`).

Task split layout applies the screen right inset to its outer bounds, then includes that inset again in the inner text column. At viewport width 430 with padding 24, a widget reproduction measured the title row's right edge at 382 rather than 406. Events and cluster rows use different inset composition and therefore do not align.

`ZoneNameLabel` still uses `right: 0` after the outer scroll-view padding was removed, with no corresponding compensation. This part is source-verified. The inspected hour-label and now-line arithmetic does include the left inset; I found no equivalent error there.

**Recommendation:** apply screen padding once per coordinate space. Separate `contentLeft` from the actual hour-label gutter width instead of overloading `hourGutterWidth`.

### 9. P2 — Zone wall-clock times shift across daylight-saving transitions

**Location:** `lib/shared/services/notification_service.dart:341`; zone background time conversion; `lib/features/timeline/zone_day_timeline.dart` (zone row sort key).

These paths convert minutes of day using elapsed-duration addition to local midnight. That is not equivalent to constructing a local wall-clock time. A Dart probe under `TZ=Europe/London` showed that midnight on 29 March 2026 plus nine hours becomes 10:00, whereas the intended calendar time is 09:00.

This affects alarm calculation and spatial band placement, and can distort mixed-row ordering in non-spatial Zone view. The evidence is the production conversion plus a timezone arithmetic reproduction, not a native alarm delivery test.

**Recommendation:** share a calendar-component conversion (`DateTime(year, month, day, hour, minute)`) and test both DST transitions with an injectable clock where scheduling depends on now.

### 10. P2 — Modal transitions recreate listener-owning animations without disposal

**Location:** `lib/core/widgets/app_modal_route.dart:48`.

`transitionsBuilder` constructs a new `CurvedAnimation` each time it runs. The installed Flutter implementation registers a parent status listener in its constructor and explicitly requires disposal. Rebuilds accumulate these listeners until the parent route animation is disposed and discard the curve's direction state between builds.

**Recommendation:** let a small stateful transition widget own and dispose one curved animation. This is a route-lifetime listener problem, not evidence of a permanent ticker leak or the earlier dismissal freeze. The framework-managed `sheetAnimationStyle` approach itself is appropriate. Keeping Cupertino platform timing is a defensible product choice and does not justify another custom sheet controller.

## Architectural risks and simplification

- **Extract the row model, not arbitrary chunks of `build`.** A pure layout result containing ordered rows, member IDs, lane geometry, bounds and total extent would eliminate duplicated height calculations and make real production logic testable. Paint order and drag priority should remain separate from geometric identity.
- **Use one overlap-group representation.** Layout and cluster detection currently derive related membership independently. A `firstBlock` accessor helps event-only clusters, but cannot repair competing row-height calculations. `PendingTaskDraft` is another scheduled-block type while cluster rendering specialises in Task/Event; make that boundary explicit rather than relying on casts or filtered collections. No additional confirmed `.tasks.first` production failure was found in the inspected path.
- **Nullable `anchorDate` is not inherently wrong.** The dangerous part is allowing independent nullable date, rule and recurrence-ID fields to represent invalid combinations. Validated constructors or a domain-level schedule-kind projection can enforce this without immediately changing Hive field indices. Centralise `appliesOn(day)` and calendar-date handling.
- **Orphan instance IDs need an explicit policy.** There is no current zone-pruning implementation, so frequent automatic pruning is not an observed failure today. Nevertheless, deletion leaves task references unresolved, and future recurrence reconciliation will make this more important. Decide whether to clear/reassign membership or preserve an occurrence with dependants. Time-scheduled tasks retain independent placement; zone-only placement has a stronger dependency. The new non-spatial Zone view also removes a reassignment entry point, so reassess now-unused APIs.
- **Centralise notification reconciliation.** One coordinator should own global cancellation, bounded scheduling and mutation-triggered refresh. Storage materialization and scheduling every generated row need not be coupled.
- **Simplify press feedback and sheet caching.** The two feedback modes are useful, but native buttons should retain native activation. Remove the false responsiveness rationale and stale hit-test comments. Keep framework-owned sheet animation lifecycles. Avoid additional abstractions merely to reproduce a speculative animation guarantee.
- **Remove obsolete spatial-Zone configuration only after checking callers.** The non-spatial reversal leaves configuration/API residue, including pixels-per-minute concepts that no longer control that view. This is cleanup, below correctness fixes.

## Test quality

1. `test/features/timeline/collapsed_stack_layout_test.dart` reproduces private grouping logic in a test helper before calling a lower-level function. Reverting the production grouping fix would not necessarily fail this purported end-to-end test. Test the extracted production row model or the actual screen.
2. The event-led case in `test/shared/services/overlap_cluster_test.dart` proves collection filtering, not Timeline placement. It cannot guard the claimed placement fix. Current collapsed tops are shared by members of a group, so the documented mixed-cluster explanation deserves an actual screen reproduction; event-only access safety is a separate concern.
3. `test/features/timeline/list_mode_clustering_test.dart:85` awaits real Hive I/O inside `testWidgets` without `tester.runAsync`, causing the observed stall. Its cluster-presence assertions also miss both overlap and scroll-extent defects. Other fixtures using `runAsync` demonstrate that full-screen widget tests are practical.
4. Notification tests accepting `throwsA(anything)` do not prove scheduling arguments or successful delivery setup. Assertions depending on the current hour are time-sensitive. Capture platform calls with a fake and inject the clock.
5. Press-feedback pointer tests do not cover native keyboard activation. Sheet tests with discrete insets or assertions about the absence of `AnimatedPadding` do not establish animation behaviour or cache release.
6. Preserve useful recurrence idempotence, half-open adjacency and horizon tests. Counts are useful evidence, but need assertions about dates, references, visibility, geometry and scheduled times.

## Standing-constraint compliance

- The literal repository-only Hive rule is not met: main/background bootstrap and provider factories access Hive outside repositories. Distinguish intentional composition-root wiring from forbidden feature persistence, then enforce the chosen boundary. Most inspected UI mutations do use provider/repository paths.
- Features directly import Flutter Material, including Timeline, zone forms and settings. The literal adaptive-import rule is therefore not satisfied.
- No feature access to colour primitives was found in the inspected search, but raw geometry and animation values remain. The documented `dart:ui` colour exception means Tier 1 is not literally independent of Flutter's engine; that exception should be stated consistently.
- Inspected Task/Zone factories use UUIDs and Task status is an enum. Current Task fields 0–19 and Zone fields 0–8 showed no index reuse. This was not a historical audit of every model adapter.

## Validation and limits

Nine temporary regression cases reproduced seven finding areas: sheet cache, recurrence transitions, cluster scroll extent, notification lifecycle, disabled-cluster title overlap, keyboard activation and right padding. The tests intentionally failed against current behaviour; they were removed after review, with copies/logs retained under `/tmp/amble-review-reproductions` and `/tmp/amble-review-*.log`. Source-derived findings are labelled separately above.

`flutter analyze --no-pub` completed with two unused `modalTitle` parameter warnings in `task_detail_sheet.dart`. The full test run reached **933 passes and 10 failures**, then remained stalled in `list_mode_clustering_test.dart`; it was terminated at 75 seconds. This is not a passing or completed suite. Failures included Slack settings, zone-form time saving, group move/resize, and place-task line tests; they were not all diagnosed by this targeted review.

No real-device motion or Siri invocation was validated during this review. The previously reported Apple toolchain blocker remains a limitation, not evidence that animation or layout feels correct. Concurrent working-tree edits mean the findings describe the inspected snapshot, not an immutable commit. No production fixes or new dependencies were introduced by this review.
