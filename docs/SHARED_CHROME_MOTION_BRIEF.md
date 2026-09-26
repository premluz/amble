# Persistent chrome and shared dock motion — implementation handoff

Status: implementation handoff, 2026-09-26. The dock and content-transition
contracts below are implemented in the core widgets and main shell. The
calendar ownership seam is documented explicitly where the current Edit
Tasks route still has a mode-specific header.

## Objective and scope

Keep shared controls mounted and fully visible while the content underneath changes. The bottom dock changes its layout; it does not disappear and reappear with each page. The Day calendar remains the same mounted calendar across list/spatial views and entry to/exit from task Edit. Use a subtle crossfade only for content that actually changes.

Assumption: “shared calendar” means Day list, Day spatial, and Edit → Tasks. The Edit → Zones weekly grid is a different calendar interface; do not introduce the Day accordion there or add it to Inbox/Tracked.

Keep the What Matters ripple, persistent tint, active-button treatment, and haptics separate. Do not retune them, sheet/keyboard animation, typography, task layout, or task/zone data behavior in this work. Preserve existing button appearance. The floating create button is not a dock action and must not be morphed into a dock button.

## Implementation checkpoint

The reusable dock and content-transition pieces are now wired into the
application shell:

- `AppContextDock` reconciles stable action IDs in one keyed action layer,
  animates retained geometry and pane bounds, gates input and semantics for
  entering/leaving actions, and retires obsolete entries by transition
  generation.
- `AppViewTransition` keeps live keyed slots at one wrapper topology,
  prepares incoming content before the 140 ms crossfade, supports reduced
  motion, and samples the current blend when a request is interrupted.
- `AppBottomDock` is mounted once in the shell. A route-scoped controller
  publishes contextual configurations, while the shell-owned content
  Navigator keeps Edit below the dock and preserves route-local Edit state.

The shared-calendar seam is intentionally still explicit: Edit Tasks has a
mode-specific `AppCalendarHeader` of its own. The Day calendar remains
isolated and stable across list/spatial switches; lifting that accordion into
the shell is the next step before claiming retained calendar identity across
Day ↔ Edit.

## Findings in the current working tree

| Location | Relevant behavior / limitation |
| --- | --- |
| [main.dart](../lib/main.dart) | Main-page `AppViewTransition` contains whole screens; another host contains the whole Day screen for list/spatial switches. Top navigation already sits outside the main-page fade. |
| [timeline_screen.dart](../lib/features/timeline/timeline_screen.dart) | Both `AppCalendarHeader` and `AppBottomDock` are descendants of the fading Day screen. |
| [zone_grid_screen.dart](../lib/features/zone_grid/zone_grid_screen.dart) | `showEditScreen` pushes a whole-screen reveal route. Tasks/Zones branches each contain their own header/tab chrome and context dock inside a view transition. |
| [app_context_dock.dart](../lib/core/widgets/app_context_dock.dart), [render part](../lib/core/widgets/app_context_dock_render.dart) | Actions have IDs, but outer action/group siblings are unkeyed. The key on inner `Semantics` cannot preserve an action moved to another group parent. `AnimatedSize` adjusts size; it is not an explicit position transition. |
| [dock configuration](../lib/core/widgets/app_context_dock_config.dart) | `stateId` exists but is not used by reconciliation. Every `didUpdateWidget` restarts post-frame/pruning work, including ordinary same-layout rebuilds. |
| [app_view_transition.dart](../lib/core/widgets/app_view_transition.dart) | Cached Widget objects move between different wrapper structures. This is not a guarantee of mounted State retention. `_visualSnapshot` builds a live widget subtree, not a frozen frame; rapid changes can duplicate/remount content. |
| [app_calendar_header.dart](../lib/features/timeline/app_calendar_header.dart), [app_date_accordion.dart](../lib/core/widgets/app_date_accordion.dart) | View/Edit branches construct separate accordion subtrees. Expansion is provider-backed, but the browsed-week offset is local State. Restoring the selected date alone does not preserve the calendar viewport. |

Existing dock tests cover a retained action in the same position; view tests largely assert final contents. Neither proves cross-group identity, persistent shell opacity, calendar lifetime, or continuous geometry during real navigation. Treat the retention statements in [DECISIONS.md](DECISIONS.md) as intended behavior that now needs stronger implementation and evidence.

## 1. Ownership: a persistent application shell

Introduce one shell within the main app lifetime after onboarding, above the navigation surface for Day, Inbox, Tracked, Settings, and Edit. It owns the following stable slots:

- **Top chrome:** main navigation or Edit Tasks/Zones tabs. These are different controls and may locally crossfade; switching Edit tabs must not recreate or fade the tab bar itself.
- **Day calendar:** one mounted `AppCalendarHeader`/`AppDateAccordion`, outside all content fades. When absent from a destination, keep the Day calendar slot alive but non-rendering, non-focusable, and non-interactive; it must occupy no layout space there.
- **Content viewport:** page/view bodies and their content-only transition owner.
- **Context dock:** exactly one mounted `AppContextDock`, bottom-leading anchored above the safe area, independently of page body opacity.
- **Primary-action slot:** keep create/microphone controls separate from the dock. Retained Day create controls should also sit outside the body fade; preserve their existing visibility and pending-draft rules. Do not invent shared identity between task-create, zone-create, and behavior-create just because all use a plus icon.
- **Local overlay layer:** task/zone creation overlays and other in-tree sheets must paint above, and block, the shared chrome where they do today. Root modal routes remain above the entire shell.

Apply system insets once at the shell boundary. Avoid nested SafeAreas adding/removing bottom or top padding on route changes. Use existing screen-padding, dock-gap, pane-padding, and button-size tokens. Content must reserve its existing bottom interaction space without inheriting dock opacity or animation.

| Transition | Persistent elements | What animates |
| --- | --- | --- |
| Day list ↔ spatial | Main navigation, calendar, all Day dock actions, applicable create control | Body crossfade; selected view button updates locally. No dock movement if its geometry is unchanged. |
| Day ↔ Inbox/Settings | Main navigation and shell; Day calendar state retained while absent | Body crossfade; actual calendar presence change; departing dock actions fade to an empty configuration. |
| Day ↔ Tracked | Main navigation and shell | Body crossfade; calendar presence; pane layout and added/removed actions. Similar view icons do not imply shared identity. |
| Day ↔ task Edit | Calendar and shell; any genuinely shared actions | Content-route fade; top navigation ↔ Edit tabs locally transition; dock changes layout. Calendar never fades. |
| Edit Tasks ↔ Zones | Edit tab bar and shell | Body crossfade, actual calendar presence change, dock configuration. Preserve Day calendar state when absent. |
| Edit selection changes | Calendar, Edit tab bar, content host, retained dock actions | Dock action/pane layout and local selection styling. No page/view fade. |

### Edit must stay inside this ownership boundary

Moving the dock out of `TimelineScreen` alone is insufficient: the current Edit route is above that screen and includes another full-screen dock/header.

Recommended navigation structure: keep the root Navigator for modal/full-screen flows, and place a shell-owned content Navigator beneath persistent chrome. Its home route owns main-page/view bodies; its Edit route owns Edit content and the existing route-local `ProviderScope`. Keep `showEditScreen` as the entry API and preserve its returned Future, push/pop semantics, and selection behavior. Use an explicit shell navigation handle rather than assuming the nearest Navigator is always the intended one.

For main-page and in-place view changes, `AppViewTransition` owns the body fade. For Edit push/pop, a content-route adapter owns that body's fade. It must use the same readiness/timing contract, keep the outgoing body visible during preparation, and coordinate route completion/disposal with the fade. Do not wrap the content Navigator in another fading host or leave `layoutRevealRoute` fading the whole Edit screen. Do not change reveal routes used by unrelated flows.

Before migrating Edit, prove the content-route adapter with a focused navigation test: delayed layout readiness, push completion, pop completion, and system Back. Inspect installed Flutter APIs before choosing implementation hooks. A route timer that expires while waiting for layout is not an acceptable readiness mechanism. Preserve platform back behavior, including cancellation where supported; avoid adding a second manually maintained navigation stack.

Audit every modal/sheet launch affected by the new nested Navigator: root sheets must still cover header and dock. Also audit in-tree quick-create overlays; lifting only the dock can otherwise put it above an editor that currently occludes it. Standalone preview/test hosts should use a small shell harness, not silently render a second dock in production.

### Route-local edit state is non-negotiable

Retain the initial `editModeEnabledProvider` override created by `showEditScreen`. The outgoing Day subtree must remain in normal mode while Edit is prepared or faded in. Never toggle a global edit provider to configure shared chrome. Instead, supply the shell a presentation configuration built from the active route's scoped state. Returning from Edit disposes its local state after the handoff completes.

## 2. Declarative chrome configuration

Extend/reuse `AppContextDockConfiguration`, `AppContextGroup`, and `AppContextAction`; do not create a competing toolbar framework. Add a feature-agnostic shell presentation contract for top chrome, calendar presentation, dock configuration, primary-action visibility, and overlay occlusion.

Use distinct identities for distinct purposes:

| Identity | Contract |
| --- | --- |
| Scene/view ID | Stable destination identity, e.g. Day list, Day spatial, Inbox, task Edit. Data refresh, time ticks, and selection counts do not create new view IDs. |
| Route instance / owner ID | Identifies the currently active presentation producer and callback lifetime. An offstage or outgoing route cannot overwrite active chrome. |
| Dock state ID | Semantic configuration such as Day, task selection, or zone selection. A state-ID change alone does not require moving unchanged buttons. |
| Action ID | Stable semantic action identity across layouts. Preserve current IDs where semantics match; do not match by list index, label, or icon. |
| Group ID | Stable visual grouping/pane identity, independent of the action's element parent. |

A Back icon that becomes Clear selection changes command semantics. Model this explicitly: either distinct actions in the same placement slot, or a retained navigation control with atomically updated command, tooltip, and accessibility label. Never retain an old callback under a new label. Do not falsely equate unrelated Day/Tracked view buttons to manufacture a shared-element animation.

Separate structural comparison (ordered action/group IDs and geometry-affecting fields) from presentation updates (callbacks, enabled, selected, destructive, color, labels). Same geometry means no layout animation, no outgoing ghosts, and no reset of cleanup timers. Update callbacks and semantics even when IDs are unchanged. Reject duplicate action IDs across the entire configuration and duplicate group IDs with contextual diagnostics.

The active navigation coordinator selects the presentation owner. Cached routes may update their own configuration, but must not publish themselves as active during `build`. If using a registration/controller bridge, register with a route token, accept updates only from the active token, and ignore stale cleanup from a previously active route. Keep repositories and feature providers out of the reusable core dock.

## 3. Shared-element dock layout algorithm

Implement explicit layout interpolation, not a whole-toolbar `AnimatedSwitcher` and not a Hero flight. Retained actions are real mounted buttons at full opacity throughout; only their layout rectangles change.

1. Compute target action and pane rectangles from the ordered configuration, constraints, directionality, and existing tokens. Keep the dock's bottom-leading anchor fixed. Its external layout envelope must accommodate the union of current and target geometry without clipping or a shrinking-Row overflow.
2. Maintain one flat keyed action layer under a stable parent. Key the direct reconciled action wrapper by action ID; moving an action between groups must not move it to a different widget parent. Put group pane backgrounds in a separate keyed layer behind the actions.
3. Preserve the visuals of `AppDockPane` and `AppDockIconButton`. If necessary, extract the pane decoration internally so backgrounds can interpolate independently of button ownership. Avoid duplicate shadow/color/radius definitions and hardcoded measurements.
4. For retained actions, tween displayed rectangle → target rectangle. Keep opacity at 1 and glyph/button size unchanged. Animate group background bounds and inter-group gaps on the same progress; do not scale the entire pane and its children.
5. For removed actions, retain a visual entry long enough to fade at its displayed position, but immediately exclude pointer input, focus, and semantics. For inserted actions, lay out a complete icon/button before fading it in at its target position. Never expose a blank primary circle for a frame.
6. Remove empty panes with their contents; do not leave empty capsules, stale trailing gaps, or orphaned shadows. Group membership affects target geometry, not widget identity. Define paint ordering for crossing actions so no retained button is clipped by a shrinking pane.
7. On interruption, sample current displayed rectangles and opacities and retarget from those values. A disappearing action that returns reverses smoothly from its current visibility and reuses its live entry. Do not jump to the previous destination or remount it as a new button.
8. Retire ghosts on controller completion for the matching transition generation. Avoid the existing unconditional `Timer` pruning cycle. Initial mount renders the final layout immediately; ordinary state/data rebuilds do not replay entrance motion.

Prefer a deterministic layout calculation using the existing uniform icon-button metrics. If future content needs measurement, measure under final constraints without painting a provisional layout; do not repeatedly read global coordinates after visible frames. Animate layout/hit-test rectangles consistently. Pointer handling must follow the visible control, with each live action exposed exactly once to accessibility.

## 4. One calendar element, stable geometry

Unify `AppCalendarHeader`'s normal/Edit presentation around one stable accordion slot rather than switching entire parent subtrees. Pass mode-specific presentation explicitly, including `showTodayLabel: false` in Edit and the existing close-button rule. Only the controls that genuinely appear/disappear may animate locally; the date text, chevron, and visible week strip remain opaque and mounted.

Preserve `selectedDateProvider`, `dateAccordionExpandedProvider`, and the accordion's locally browsed week. Current calendar behavior is intentional: swiping pages the viewed week without selecting a date; tapping/scrubbing selects. A shell migration must not reset the browsed week to the selected week, collapse the accordion, or restore the former swipe-changes-date behavior. Preserve the existing explicit-selection reset behavior.

Day list ↔ spatial should leave calendar bounds unchanged. For Day ↔ task Edit, retain the same calendar anchor where current chrome metrics allow it. The current header uses different top padding in normal/Edit mode; resolve that centrally. If top-row geometry genuinely changes, interpolate the calendar's position/available space with chrome-layout motion rather than instantly jumping or fading it. Lay out the incoming body under its final viewport before revealing it; coordinate viewport changes to avoid a second scroll correction during the fade.

During task Edit ↔ zone Edit, the shared Tasks/Zones tab bar stays mounted. The Day accordion can leave its slot as the weekly grid enters; this is an actual presence change, not a global header fade. Keep its saved Day state for returning to Tasks. On main-page changes, hide the Day calendar only where it is not applicable.

## 5. Readiness and content crossfade contract

Reuse and repair `AppViewTransition` rather than adding another generic switcher. Store persistent keyed view slots at a stable parent/wrapper topology; a map of Widget values alone does not preserve State. Keep each cached page's scroll controller/restoration ownership distinct. Use explicit retention/disposal policy: retain fixed main/day views, dispose popped Edit routes after transition completion, and never grow a cache by arbitrary data IDs.

Replace recursive `_visualSnapshot` widget compositions with bounded live slots and sampled opacity state. Never mount the same logical view twice to represent a snapshot. Define compositing so interruptions preserve the already displayed blend without a one-frame brightness change; naive multiplication of independently nested opacities is insufficient. Keep the background opaque and constant throughout.

Use a generation-tagged transition transaction:

1. **Prepare:** accept target scene; keep the current displayed body/chrome configuration. Lay out incoming content invisibly with target viewport constraints, initialized route state, and restored scroll. Stop outgoing body interaction; navigation controls that allow retargeting remain usable.
2. **Ready:** the target reports final initial geometry and scroll restoration complete. A post-frame callback alone is sufficient only for a demonstrably synchronous view. Connect existing Day layout/reveal readiness to this contract; do not stack a second mount fade or guess with a fixed delay.
3. **Commit:** atomically activate the incoming scene's presentation owner, labels, and callbacks; start its body fade and dock/chrome layout motion together. Shared elements never inherit body opacity. Outgoing body and ghost actions remain input/focus/semantics excluded.
4. **Complete:** expose incoming body interaction and semantics; pause cached inactive subtrees and dispose transient outgoing entries/routes. Inactive content must not own keyboard focus, keep unnecessary tickers running, or announce itself to accessibility.

When requests change during preparation or animation, invalidate stale ready/completion callbacks, preserve the current visual blend/geometry, and prepare the latest target. Keep the last valid presentation until its replacement is ready; a stale route callback cannot publish or dispose the new scene. Do not replay old navigation requests after the latest one finishes. Scope focus transfer deliberately so switching pages does not summon a keyboard.

Timing already exists in [motion_primitives.dart](../lib/core/tokens/motion_primitives.dart): `durationContextDockMs = 200` and `durationViewCrossfadeMs = 140`. Start with these and the existing standard easing; no bounce, slide, or scale on page content. Read duration/curve through the shared token system. Calendar/chrome geometry may reuse dock layout timing; do not add per-screen magic delays.

Reduced motion preserves readiness and callback ordering, then applies target layout/content immediately. Retained shared elements remain mounted. On push/pop, exactly one body-transition owner is active; route fade plus a whole-page view fade is prohibited. Disabling body interaction must not unnecessarily disable persistent navigation for the entire animation.

## 6. Integration map and implementation order

Inspect current file contents and concurrent changes before editing. Split new responsibilities into small files; do not enlarge the already oversized screen files with a motion engine. The names below are proposed seams, not instructions to overwrite existing code wholesale.

| Phase | Files / responsibility | Exit requirement |
| --- | --- | --- |
| 1. Contracts and dock | Existing `app_context_dock_config.dart`, `app_context_dock.dart`, `app_context_dock_render.dart`, `app_dock_primitives.dart`; proposed dock-layout/motion helpers | Identity, grouping, callback updates, interruption, reduced motion, and geometry tests pass for multiple distinct configurations. |
| 2. Persistent shell | Proposed shell/chrome configuration and coordinator under `lib/core/`; `main.dart`; Day and Tracked dock adapters | One dock lifetime across main pages and Day views; body fades cannot dim it. Inbox/Settings currently have no left dock: supply empty configuration rather than inventing actions. |
| 3. Shared calendar | `timeline_screen.dart`, `app_calendar_header.dart`; change `app_date_accordion.dart` only if the stable-slot integration needs it | Same accordion/week-strip element across list/spatial; preserve selected date, expansion, browsed week, and existing Today-label rules. |
| 4. Edit ownership | `zone_grid_screen.dart`; content-route adapter and shell navigation handle; affected sheet/overlay entry points | Route-local providers, system Back, modal occlusion, retained calendar, stable Tasks/Zones tabs, and selection dock transitions work through real push/pop. |
| 5. Content host | `app_view_transition.dart`, `app_layout_reveal.dart`/`day_view_reveal.dart` only where ownership changes; page adapters including Inbox/Tracked | Stable view slots, explicit readiness, bounded interruption behavior, and a single fade owner. Implement this foundation earlier if required by phases 2–4. |
| 6. Record behavior | `docs/DESIGN_SYSTEM.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/PROGRESS_LOG.md` | Document the shipped contracts and actual verification; distinguish superseded intention from verified behavior. |

Before writing runtime changes, the implementing agent must list its exact planned files and reuse existing tokens/providers/components. No dependencies, broad cleanup, data migrations, or resets of the dirty worktree. Keep existing standalone previews working through explicit harness/adapters. Do not carry screenshot-only or test-only fallback layout behavior into production.

## 7. Automated acceptance checks

Extend [dock tests](../test/core/widgets/app_context_dock_test.dart), [view-transition tests](../test/core/widgets/app_view_transition_test.dart), [calendar tests](../test/features/timeline/app_calendar_header_test.dart), [navigation tests](../test/timeline_nav_consolidation_test.dart), and [Edit integration tests](../test/features/zone_grid/zone_grid_edit_screen_merge_test.dart). Add a shell integration test using the actual route hierarchy, not just isolated widget hosts.

- **Identity and opacity:** retain the same dock State and action element through reorder, removal before a retained action, and moves between groups. Assert retained actions' effective ancestor opacity remains 1, including during page and Edit navigation; checking only the button's own Opacity is insufficient. Test both Day's grouped layout and a structurally different selection/Tracked layout.
- **Geometry:** sample frames inside Flutter's test clock from before change through completion. Assert no first-frame jump, continuity when retargeted mid-flight, stable button dimensions, final target rectangles, consistent safe-area anchor, and no empty-pane/blank-icon frame. Do not use external sleeps/screenshots as timing evidence.
- **Calendar lifetime:** expand, browse away from the selected week, switch list/spatial, push task Edit, then pop. Assert unchanged selection, expanded state, viewed week, retained element identity, and stable/interpolated bounds as specified. Verify Tasks/Zones and Today-label behavior separately.
- **Readiness and cache:** deliberately delay geometry/scroll restoration; outgoing body stays visible and the target's provisional position is never painted. Test scroll round trips and State mount/dispose counts. Rapid A → B → C → A must not duplicate views, accumulate snapshots, miss readiness, or leave a blank frame.
- **Semantics and focus:** outgoing bodies/removed actions have no tap handlers, focus, or accessibility nodes; retained actions expose one current label/callback. Test same-ID enabled/selected/callback updates without restarting layout. Clear selection must never unexpectedly navigate Back or vice versa.
- **Navigation and overlays:** use real push/pop and system Back; assert route-local Edit state leaves the underlying Day unchanged. Test pending task/zone drafts, root sheets, modal dismissals, feature-flag-dependent destinations, and returning to the prior page/view. Shared chrome must not intercept a modal or appear above its scrim.
- **Constraints and accessibility:** narrow/wide viewports, nonzero safe areas, RTL, increased text scale, calendar expanded/collapsed, and reduced motion. Do not make the dock follow keyboard insets unless existing behavior requires it; sheet/keyboard orchestration remains separate.
- **Appearance/performance evidence:** use deterministic component-scoped golden diffs for stable intermediate/final states where useful. Add an in-app integration/profile scenario for repeated Day/view/Edit/selection switches on the target Android device; collect Flutter frame timings with refresh-rate context. No frame-by-frame layout measurement loops, blanket repaint caching, or screenshot polling as performance fixes.

Run targeted tests while iterating, then repository-required analysis and test gates. Record actual failures with commands and logs; do not claim that passing isolated widgets proves the shell flow is correct, or fix unrelated baseline failures under this scope. Completion requires that shared controls survive the real transitions, not merely that their replacements look identical after settling.
