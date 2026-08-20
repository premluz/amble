# Amble — Initial Project Plan

Sequenced build order, mapped to SCOPE.md. Each phase is sized to be one or a few Claude Code work orders (see the handoff prompt pattern already in use) — not a rigid calendar, since actual pace depends on how much iteration each piece needs (the capsule timeline block especially, per ARCHITECTURE.md).

Read alongside: CONSTITUTION.md (non-negotiables), ARCHITECTURE.md (layers/tokens), SCOPE.md (in/out of scope), ERROR_LOG.md (update as you go).

---

## Phase 0 — Foundation (in progress)
**Status: underway.** Models, Hive persistence, TaskRepository interface. (This is the work order already handed off.)

---

## Phase 1 — State layer
- Riverpod providers/notifiers over `TaskRepository`
- Basic CRUD flows wired end-to-end (create/read/update/delete a task) with no UI polish — a bare test screen or widget test is enough to confirm the plumbing works
- **Exit criteria**: a task can be created, persisted, fetched, and updated purely through providers, **with unit tests actually covering create/read/update/delete** — before any real screen exists. "Compiles and I tried it once" does not satisfy this; from this phase onward, exit criteria implies test coverage unless a phase says otherwise.

## Phase 2 — Design system foundation
- Tier 1 primitives (color ramps, spacing scale, radii, type scale) as plain Dart consts
- Tier 2 semantic tokens via `ThemeExtension`
- Adaptive widget layer starter set: `AppButton`, `AppSheet`, at minimum
- **Exit criteria**: a tiny throwaway screen can render using only tokens/adaptive widgets, nothing hardcoded — proves the system works before real screens depend on it

## Phase 3 — Timeline screen (core)
- Vertical day view, static rendering first (hardcoded/seeded tasks) before wiring to real state
- Then wire to Phase 1 providers
- Current-time indicator
- Day navigation (swipe/tap between days, jump to today)
- **This is where the capsule timeline block gets built** — budget the most iteration time here per ARCHITECTURE.md's note on this being a design-taste problem as much as a code one
- **Exit criteria**: a real day of tasks renders and scrolls correctly, matching the token system, no interaction yet. **Definition of done for this phase includes a visual review checkpoint** — a screenshot compared against the reference UI, reviewed by you and logged as a short note in PROGRESS_LOG.md — not just "it builds." This applies to any phase touching the capsule timeline block or other signature visual elements.

## Phase 4 — Task interactions
- Task detail bottom sheet (create/edit)
- Completion toggle (writes `completedAt` + status)
- Manual reschedule (drag-to-move, writes `originalScheduledAt`)
- **Exit criteria**: full task lifecycle usable end-to-end on the timeline itself

## Phase 5 — Inbox
- Capture screen/flow for unscheduled tasks
- Move-to-timeline interaction
- **Exit criteria**: a thought can be captured with zero friction and later scheduled — validates design principle 2 from CONSTITUTION.md

## Phase 6 — Notifications
- `flutter_local_notifications` wired to task `scheduledAt`
- Permission request flow (iOS + Android differ here — expect a real platform-adaptive moment)
- **Exit criteria**: a scheduled task reliably fires a local notification on both platforms

## Phase 7 — Export / Import
- JSON export via `share_plus`, full dataset (not just current/future — see earlier decision that export doubles as backup)
- Import via `file_picker`, with `schemaVersion` validation
- **Exit criteria**: export → wipe local data → import round-trips cleanly with no data loss

## Phase 8 — Settings + polish
- Settings screen (notification prefs, export/import entry points)
- Bottom nav finalized: Inbox / Timeline / Settings
- Pass over empty states, edge cases (very long task titles, overlapping tasks, etc.)

## Phase 9 — Device testing + store prep
- Extended testing on your own physical device (already confirmed working)
- App icon, splash screen, store metadata
- TestFlight / Play internal testing track setup, if/when this moves beyond personal use

---

## Deferred (from SCOPE.md, not part of this plan)
Recurring tasks and category tagging are the two "nice-to-have" items worth slotting in opportunistically between phases 4–7 if a session has spare capacity — everything else in SCOPE.md's "explicitly out of scope" list stays untouched until deliberately revisited.

## How to use this with Claude Code
Each phase becomes one work order using the same pattern as the Phase 0 handoff prompt: read the docs, scoped task list, explicit non-goals, run `flutter analyze` + `flutter test` before reporting back. Update DECISIONS.md and ERROR_LOG.md as real choices/gotchas surface — this plan should get lighter edits over time as those two files absorb the detail.
