# Amble — Constitution

This is the stable core. It should rarely change. Every build session (Claude Code or otherwise) reads this before touching code.

## Locked stack

- **Framework**: Flutter, single codebase → iOS + Android
- **State management**: Riverpod (`flutter_riverpod`, code-gen via `riverpod_generator`)
- **Local persistence**: Hive (`hive`, `hive_flutter`) — local-only for MVP, no auth, no cloud sync
- **Access pattern**: Repository interfaces only. UI and state never call Hive directly. This is what makes a future Supabase swap a new implementation of an existing interface, not a rewrite.
- **Backend**: none in MVP. Deferred behind the repository interface, not designed around yet.
- **Calendar integration**: implemented (see the "Calendar" section below) — two architecturally distinct features (read-only external event display, manual one-directional task sync-out) via `device_calendar`. This reverses the earlier "explicitly out of scope" lock below, confirmed directly by the user rather than assumed; kept as a record of the reversal, not deleted, since the original entry documented a deliberate decision at the time.

  ~~Calendar import/sync: explicitly out of scope. Not a phase-2 default — a decision to revisit deliberately if it ever comes up.~~ *(superseded — see above and docs/DECISIONS.md)*

## Data-model non-negotiables

These apply to every persisted entity (Task, TrackedBehavior, and anything added later):

- **IDs are client-generated UUIDs from day one.** Never rely on Hive auto-increment. This avoids an ID-remapping migration if/when a backend is added.
- **`status` is an enum**, not a boolean: `pending | completed | skipped | rescheduled`. A skipped or rescheduled task is analytically different from one the user simply never engaged with — collapsing this to `completed: bool` loses information that can't be recovered later. This enum stays fixed even for tracked-behavior instances (see below) — partial performance is expressed numerically, not as a fifth status value, so ordinary tasks are never affected by tracked-behavior concerns. Reversible if this proves wrong in practice, but not to be changed silently.
- **`completedAt` is a separate timestamp from `scheduledAt`.** This is what makes lateness/earliness and any future recovery analytics possible.
- **`originalScheduledAt` is preserved on reschedule.** Without this, replanning behavior is invisible after the fact.
- **`schemaVersion` is present on every persisted object and every export file.** Required for safe future migrations and for import validation.
- **`scheduledAt` and `durationMinutes` are nullable** (added Phase 5, for Inbox capture). A task with both null is unscheduled (lives in the Inbox); a derived `isScheduled` getter treats these as a single atomic unit — the UI/detail form always sets both together via defaults, so a task is never persisted in a half-scheduled state. `Task.captured({title, notes})` is the factory for title-only Inbox items; `Task.create({...})` remains the factory for fully-specified tasks.

## Recurring vs. tracked behavior — two different concepts, not one

Easy to conflate; must stay architecturally separate:

- **Recurring** is a scheduling property of an ordinary `Task` — "this repeats every Monday." It does not imply tracking, history, or a target, and stays a lightweight rule on `Task` itself, never its own entity.
- **`TrackedBehavior`** is a genuinely different, persistent object — see below. A recurring task and a tracked behavior are independent concepts that often co-occur, but neither implies the other.
**UI promotion (this round): a dedicated top-level nav destination**, not just
inline creation during task/template save. Users create, list, and edit
`TrackedBehavior` rows directly from this destination; they still also surface
as quick-drop chips during task/template creation, same as before.
`FeatureFlags.trackedBehaviorEnabled` stays the gating seam, and is intended as
the actual pro/paid-tier boundary going forward — `Category` and
`TaskTemplate` are explicitly NOT gated behind it; core planning stays free,
the tracked-behavior/habit layer is the premium surface. No monetization logic
is built this round, only keeping the flag load-bearing for it. History/
rollup view remains deferred per SCOPE.md — this round adds the container and
basic create/list/attach only.

## Recurring tasks — materialized instances, not virtual expansion

A recurring task is implemented as **real, persisted `Task` records, one per occurrence** ("materialized instances") — not a single rule row with occurrences computed on the fly for display. This is a deliberate choice: notifications, completion tracking, reschedule, export/import, and the Inbox already operate on the assumption that every `Task` visible in the app is a real Hive record. Virtual/on-the-fly expansion would require every one of those systems to learn to handle non-persisted tasks — a much larger, more invasive change than the extra storage cost of materialized rows.

Model shape:
- `RecurrenceRule` — not a persisted entity of its own for MVP, just a value object embedded on the originating `Task`: `frequency` (`daily | weekly`), `interval` (int, e.g. every 2 weeks), optional `daysOfWeek` (for weekly), optional `endDate`. Kept deliberately small — no monthly/yearly, no complex RRULE-style patterns, for MVP.
- Every `Task` generated from a rule carries `recurrenceId` (the UUID of the originating rule/series) and `recurrenceRule` only on the first ("template") instance — later instances reference `recurrenceId` but don't repeat the full rule.
- Generation is a **rolling window**: instances are materialized some fixed distance ahead (e.g. 8 weeks) whenever the app opens or a relevant screen loads, not all at once to `endDate`. This avoids generating years of rows for an open-ended recurrence.
- **Editing scope for MVP**: editing or deleting a materialized instance only ever affects that single instance ("this one"), never the series. "Edit all future occurrences" is a real, deferred feature — not built in the first pass. This keeps the interaction model simple and matches design principle 3 (replanning should be faster than abandoning the plan) without introducing series-wide edit complexity before it's proven necessary.
- A recurring task can independently also be linked to a `TrackedBehavior` via `behaviorId` (each materialized instance carries its own `behaviorId`/`actualAmount`, same as any task) — the two systems compose without special-casing.

## TrackedBehavior — persistent tracked objects (feature-flaggable)

A `TrackedBehavior` is a separate, persistent entity — its own model, own Hive box, own repository — representing an intention that accumulates evidence across many scheduled `Task` instances over time (e.g. "Exercise," target 60 minutes, 3x/week). Deliberately minimal for MVP: title, target type (`duration | count | binary`), target amount, optional minimum/fallback amount, simple frequency. No cue/context fields, no reflection scale, no learning/suggestion engine, no weekly review screen yet — real future territory, not MVP architecture.

`Task` gains two nullable fields to link to this system without disturbing existing behavior:
- `behaviorId: String?` — null for an ordinary task (unchanged default), non-null when this instance belongs to a `TrackedBehavior`.
- `actualAmount: num?` — the recorded outcome (e.g. 30 of a 60-minute target), meaningful only when `behaviorId` is set.

Additive and inert when unused: with the feature flagged off, `behaviorId` simply stays null everywhere and `Task`'s existing lifecycle is unaffected. A feature flag only needs to gate UI entry points (creating a tracked behavior, a history view) — the data model itself is never "turned off," only left dormant. Same pattern as `Task.captured()` in Phase 5: extending the model to accommodate a new case without breaking the old one.

## Category — persisted, user-extensible task categories

`Category` is a separate, persistent entity — its own model, own Hive box (`categories`), own repository — replacing the old fixed 5-value `TaskCategory` enum (`shared/models/task_category.dart`) as the source of truth for a task's category. Built because a real "Add new category" flow needs categories to be user-creatable data, not a closed Dart enum.

Fields: `id` (client UUID), `name`, `colorToken` (an `int` index into the 12-swatch palette, `ColorPrimitives.categoryPalette12`/`AmbleTheme.categorySwatches` — not a Hive-adapted enum, matching how the codebase already indexes into fixed color lists elsewhere), `emoji`, `isBuiltIn` (flags the 5 seeded rows; no behavior depends on it yet — v1 has no edit/delete UI for any category), `schemaVersion`. `Category.create({name, colorToken, emoji})` mirrors `TrackedBehavior.create`'s factory shape.

**`Task.category` (the old enum field) is deprecated but NOT removed, renumbered, or repurposed** — Hive field-index stability: retiring or reusing `@HiveField(8)` would silently corrupt/misread already-installed users' persisted data. It stays on the model, marked `@Deprecated`, populated only on old rows, still read/written by `toJson`/`fromJson` for backward-compatible export — but no longer consulted by any real UI. `Task` gains a new field, `categoryId: String?` (`@HiveField(15)`), which is authoritative for every current task; `Task.create` requires it.

**Seed + one-time migration, at launch**: gated by `PreferenceKeys.categoriesSeeded` (default-if-empty pattern, same as every other preference), `CategoryList.seedBuiltInsAndBackfillIfNeeded()` seeds the `categories` box with 5 built-in rows at fixed, hardcoded UUIDs (`BuiltInCategoryIds` — not randomly generated, so re-seeding is idempotent), then walks every existing `Task`: if `categoryId` is null and the old `category` enum is set, resolves it to the matching built-in's fixed id and saves. Runs once, from `main.dart`, alongside `TaskList.materializeDueRecurrences()`.

**v1 scope is create + list only — no edit, no delete.** Confirmed directly rather than assumed. `CategoryRepository` has no `deleteCategory`; deleting a category that existing tasks reference (orphaned `categoryId`) is a real open question, deliberately deferred rather than resolved on the spot — same posture CONSTITUTION.md already takes on `TrackedBehavior` deletion.

Export/import carries categories alongside tasks: the backup JSON envelope gained a `categories` array (`Category.toJson`/`fromJson`, hand-written like `Task`'s own), so a user's custom categories survive a fresh-install restore, not just the 5 built-ins (which re-seed on their own regardless).

Additive and inert when unused, same guarantee as `TrackedBehavior`/`Zone`: `categoryId` stays resolvable through the seed+backfill migration, and `Task`'s existing lifecycle is unaffected by the presence of this new entity.

## TaskTemplate — persisted, reusable task blueprints

A `TaskTemplate` is a separate, persistent entity — its own model, own Hive box (`task_templates`), own repository, same shape as `Category`/`Zone` — representing a reusable blueprint for tasks a user creates repeatedly (e.g. "Take a walk").
Deliberately task-shaped but never itself schedulable: no `scheduledAt`, no
`durationMinutes` requirement, no `status`, no `completedAt`. It exists to be
copied, not executed.

Fields: `id` (client UUID), `title`, `categoryId` (required, same as `Task`),
`durationMinutes` (nullable — a default to prefill, not enforced), `notes`
(nullable), `behaviorId` (nullable — links the template to a `TrackedBehavior`,
carried forward to any task spawned from it), `schemaVersion`.

**Copy semantics, not a reference.** Spawning a task from a template calls
`Task.create()` populated from the template's fields — a real, independent
`Task` row. `Task` gains one new nullable field, `templateId: String?`,
recorded purely for frequency-ranking the quick-drop drawer (below) — it is
never consulted for cascade logic. Editing or deleting a `TaskTemplate` never
touches any `Task` already spawned from it, matching the "additive and inert"
guarantee every other optional entity in this doc gets.

**v1 scope: create, list, edit, delete — templates ARE deletable**, unlike
`Category`/`Zone`, since nothing depends on a template's continued existence
once it's been used to spawn a task (no orphaned-reference problem, because
nothing points *back* to it).

Surfaced in two places: a second Inbox tab ("Templates"), and a frequency-ranked
quick-drop chip row beneath the task-creation title field, alongside
`TrackedBehavior` chips (small icon distinguishes tracked from plain).

Ungated — free functionality, same tier as `Category`, not behind
`FeatureFlags.trackedBehaviorEnabled`.

## Zone — a time-boxed container of tasks

**Status: data layer, feature-flagged create/edit UI, and BOTH Timeline rendering modes (Spatial Task View and Spatial Zone View) are all implemented** (see `docs/PROGRESS_LOG.md`/`docs/DECISIONS.md` for the individual sessions: model+repository, first UI, ungating, simple recurrence+notifications, the Spatial Task View background rendering, and the Spatial Zone View container rendering covered in this section). This section's field/design notes below still describe the ORIGINAL 2026-09-01 design agreement and are mostly current, but treat any specific claim of "not yet built" elsewhere in this section as stale — check DECISIONS.md for what has actually shipped since. Still genuinely not built: per-occurrence-adjustable recurrence, capacity enforcement, zone drag/cascade, and any UI for assigning a `Task` to a zone.

**Spatial Task View rendering (implemented)**: on the existing Timeline (the *spatial task view*, per the per-view-job principle below), every persisted Zone renders as a light, low-chroma background block (`ZoneBackgroundBlock`, `AmbleTheme.colorZoneBackground`) behind the task capsules, positioned by the zone's own time range using the same time-to-pixel math tasks use. Purely decorative — it does not reposition, resize, or otherwise affect task rendering, matching "Zone is metadata on a Task, not a container that owns it" below.

**Spatial Zone View rendering (implemented, 2026-09-02)**: a second Timeline display mode, switched via a Settings toggle (`ZoneViewEnabledSetting`, only surfaced when `FeatureFlags.zoneEnabled` is on), where a Zone genuinely acts as a real layout container — `ZoneContainerBlock`, stacked chronologically on an outer time axis via `ZoneDayTimeline`. A task belongs inside a zone's container by **time whenever it has one**: if `scheduledAt` is set, the task renders in whichever zone's time window contains it, and in no zone at all if it falls outside every window — even when `zoneId` names one. Only a zone-only task (no `scheduledAt`, nothing to resolve against) places by its explicit `zoneId`. This resolution is read-only for display: it never writes, clears, or persists `zoneId` on any `Task`, preserving the "metadata, not ownership" rule below.

**Reversed 2026-09-04** (confirmed directly), from the original rule that explicit `zoneId` was authoritative and won even over a conflicting `scheduledAt`. Reported directly: a task showing 05:15 in Task view still rendered inside the 09:00–13:00 container in Zone view. Root cause is that `zoneId` is only ever SET (by a Zone-view drop, `rescheduleTaskWithZone`) and never cleared — Task view's own drag (`rescheduleTask`) and the task detail sheet both leave it untouched by design — so any later time change stranded a stale assignment that then outranked the task's real time. Resolving by time makes the two views agree without requiring every write path to maintain the assignment; a stale `zoneId` simply stops affecting placement, and stays on the row untouched. A task matching neither path renders as an ordinary capsule at its own real spatial time position, interleaved with the zone containers on the same outer axis, not hidden or bucketed into a separate section. See `shared/services/zone_containment.dart` (`resolveZoneContainment`) for the pure containment-resolution logic and docs/DECISIONS.md for the full reasoning. The Spatial Task View above is completely unaffected — the two modes are separate widget trees, not a shared one with a rendering-mode flag threaded through it.

A `Zone` is a separate, persistent entity — its own model, own Hive box, own repository, same shape as `TrackedBehavior` above — representing a named time window (e.g. "Morning ritual," 07:00–08:00) that a `Task` can optionally be assigned into. Distinct from *recurring*, the same way `TrackedBehavior` is distinct from it: a Zone is a container with a start/end time and a capacity, not a scheduling rule on `Task` itself.

**Zone is metadata on a Task, not a container that owns it.** A `Task` does not live "inside" a `Zone` structurally — `zoneId` is a reference, same shape as `behaviorId`, and a task remains fully valid and functional with it unset. Time (`scheduledAt`) and zone (`zoneId`) are independent dimensions on `Task`, not a hierarchy — a task can be precisely timed + zoned, precisely timed + unzoned, loosely timed (zone-only) + zoned, or neither. This independence is what makes multiple views over the same data possible without duplicating the model per view.

**Each Timeline view has one job; views should not converge on answering the same question.** Confirmed as a design rule, not just an observation: a *Zone/spatial-zone view* organizes meaning (understand the shape of the day), a *spatial task view* organizes time (manipulate the schedule), and a *list/compact view* organizes action (execute the schedule — see the overlap-cluster feature's flat-list-inside-a-spatial-shell pattern as the existing precedent for this). If a future feature request would make one view start doing another view's job (e.g. list view growing zone-editing), that's a signal to push back or split it into the view whose job it actually is, not to blend the views.

- **`Zone` fields (draft)**: `id` (client UUID), `title`, `startTime`/`endTime` (time-of-day, not a specific date — see recurrence note below), `schemaVersion`. Duration is derived (`endTime - startTime`), not stored separately, so it can never drift from the two times that define it.
**Zone resize — reversed 2026-09-06, now in scope (see "Edit Mode" section).**
Originally grouped under "dragging a zone... are deferred" below; resize
(changing `startTime`/`endTime` via a drag handle) and reposition (moving the
whole zone earlier/later without changing its duration) are actually two
different operations and are being un-bundled. **Resize is now in scope**,
built as part of Edit Mode. **Reposition (dragging a zone's entire block to a
new time, with its assigned tasks) remains deferred** — it's a strictly
harder problem (deciding whether assigned tasks move by the same delta or
re-anchor) than resize, which only ever changes one edge at a time and
composes cleanly with the existing read-only, time-based containment
resolution (`resolveZoneContainment`) with no new write path needed: a task
that falls outside a zone's new, shrunk window simply stops rendering inside
it on the next frame, same as it would for any other time-based mismatch
today.

Resize still enforces the existing zone-to-zone non-overlap rule (checked on
release, reusing the add/edit form's existing validation) and recalculates
`calculateZoneCapacity` live — consistent with "capacity is checked, not
enforced," a resize that would push a zone over its assigned tasks' combined
duration is still allowed, just reflected in the capacity indicator, not
blocked.


## Edit Mode — direct manipulation of the Timeline

A toggleable mode on the real Timeline (not onboarding-only — onboarding
introduces it on a pre-populated first day, per docs/DECISIONS.md, but it's a
permanent, always-available Timeline feature). While active:

- **Resize handles appear on both Task capsules and Zone containers.**
  Dragging a handle changes `durationMinutes` (Task) or `startTime`/`endTime`
  (Zone) — a deliberately separate gesture from the existing move-drag, since
  move is a plain, non-long-press drag on the block body and needs a distinct
  touch target to avoid gesture collision.
- **Move (reschedule) is unchanged** — the existing drag-to-reschedule
  interaction (Phase 4/11) already works exactly this way outside Edit Mode
  too; Edit Mode doesn't alter it, only adds resize/delete/drawer alongside it.
- **Delete via drag-to-target**: while dragging a Task, a delete target
  appears on screen (bottom of viewport); dropping onto it deletes the task
  instead of rescheduling it — same interaction shape as Android/YouTube's
  drag-to-dismiss picture-in-picture pattern. This drop path must short-circuit
  the existing cascade-push algorithm entirely (see SCOPE.md's "Cascade
  replanning") — it is a different drop outcome, not a reschedule needing a
  push-direction computed for it. **Zone delete is NOT included this round**
  — no zone-delete UI exists anywhere in the app yet (Settings → Zones is
  add/edit only), and deleting a zone raises the same orphaned-reference
  question already on record for Category (what happens to tasks/zoneId
  referencing a deleted zone) — deliberately deferred, not assumed.
- **Presets/Templates drawer** — the same TaskTemplate/TrackedBehavior
  quick-drop drawer already scoped for task creation, given a second entry
  point here: persistently accessible as a sheet while Edit Mode is active,
  same underlying data and ranking, not a second implementation.

Additive and inert when off: Edit Mode is a UI-layer toggle only, no new
persisted state — a Task or Zone looks and behaves identically whether it was
last touched via Edit Mode's handles or the existing detail sheet/drag.

- **`Task` gains one nullable field: `zoneId: String?`** — same pattern as `behaviorId`: null for an ordinary task (unchanged default), non-null when assigned to a zone. Confirmed directly: this is a real relationship (`taskId` → `zoneId`), not something derived by checking whether `scheduledAt` falls inside a zone's time window — because a task can be assigned to a zone with **no `scheduledAt` at all**. That's the actual reason this can't be computed from overlap: a zone-only task has nothing to overlap against.
- **A task may set a zone, a `scheduledAt`, or both.** Confirmed directly ("sufficient for task to set either zone or time for it, or both, but can set just zone and not a time"). This makes the resolved "when" of a task three-way rather than the current two-way (Inbox vs. scheduled): explicit time, zone-only (time implied by zone + capacity ordering), or neither (Inbox, unchanged). Every read site that currently treats `scheduledAt == null` as "this task is in the Inbox" needs to learn this third state — that is the single largest ripple from this feature and the main reason it's being spiked as a design pass first, not built directly.
- **Zones cannot overlap each other.** Enforced the same shape as the existing "Prevent overlapping tasks" setting, but zone-to-zone, not task-to-task — needs its own check, since the existing `overlapsExistingTask` helper reasons over `Task.scheduledAt`/`durationMinutes`, which a `Zone` doesn't share a supertype with.
- **Capacity is checked, not enforced physically**: the sum of `durationMinutes` across a zone's assigned tasks (that also have a `scheduledAt`) is compared against the zone's own duration (`endTime - startTime`). What happens when the sum exceeds capacity — hard block, warning, or silent overflow — is undecided; needs its own confirm-first pass before building, same as the overlap-prevention setting got.
- **Recurrence: SIMPLE version implemented (2026-09-02), reusing `RecurrenceRule` as-is.** `Zone.recurrenceRule` is a nullable `RecurrenceRule` (same `frequency`/`interval`/`daysOfWeek` value object `Task` embeds) — one rule, the SAME start/end time on every occurrence. Confirmed directly by the user as the scope for this pass, explicitly choosing this over the harder fork below. No materialization: a recurring `Zone` is still a single persisted row (unlike a recurring `Task`, which is materialized as one real row per occurrence) — the rule is evaluated live wherever "does this zone apply today / what's its next occurrence" is asked (see `NotificationService.scheduleForZone`'s `_nextZoneOccurrence`/`_ruleMatchesDay` helpers for the reference implementation of that evaluation).

  **The per-occurrence-adjustable-times version below is still NOT built and remains the deferred future fork** — e.g. a Monday zone at 07:00–08:00 and a Wednesday zone at 07:30–08:15 as one logical recurring series with different times per day. Be precise about which one "Zone recurrence" means in any future session: what's implemented is one uniform rule/uniform time; what's still open is per-occurrence overrides. If that harder version is ever built, it most likely means a `Zone` series needs its own, separately materialized-instance model (real per-day `Zone` rows, sharing a `recurrenceId`-style series link, each with its own `startTime`/`endTime`) rather than the shared `RecurrenceRule` value object now in place — same "materialized instances, not virtual expansion" philosophy as recurring tasks, but the rule itself would need to live per-instance instead of only on the template. Needs its own dedicated design pass before building.

- **Notifications: implemented (2026-09-02).** `Zone.notificationsEnabled` (default `true`, same opt-out-not-opt-in default as `Task.notificationsEnabled`) gates a start-time alert via `NotificationService.scheduleForZone`/`cancelForZone`, mirroring `scheduleForTask`/`cancelForTask`'s shape and the same horizon/cap discipline (`isWithinSchedulingHorizon`, `notificationHorizonDays`). Because a recurring `Zone` has no materialized per-occurrence rows, a recurring zone's notification is a single ONE-SHOT alert for its next upcoming occurrence, re-resolved and re-scheduled whenever the zone is next saved — not a true recurring OS-level alarm. See docs/DECISIONS.md for the full reasoning and the known gap (no launch-time refresh for zone notifications yet, unlike `Task`'s `refreshScheduledNotifications`).
- **Dragging a zone (with its contained tasks) and cascading zones are deferred, out of scope for the first build.** Structurally similar to the existing task-level cascade-push algorithm (see SCOPE.md), but not the same code: moving a zone has to move every assigned task in lockstep, decide what happens to a task's own explicit `scheduledAt` if it had one (move it by the same delta? re-anchor to the new zone-relative position?), and the non-overlap constraint applies at the zone level while the existing cascade reasons at the task level. Real future work, not assumed to fall out of the existing cascade code for free.

Additive and inert when unused, same guarantee as `TrackedBehavior`: `zoneId` stays null everywhere until a Zone UI exists, and `Task`'s existing lifecycle (Inbox, scheduling, recurrence, notifications) is unaffected by an unset `zoneId`.

## Calendar — two architecturally distinct features, one dependency

Reverses the earlier "Calendar import/sync: explicitly out of scope" lock above — confirmed directly by the user, not assumed. Both features share `device_calendar` and a lazy permission-request flow, and are housed together in one "Calendar" Settings section, but the two directions of data flow **must stay cleanly separated in code and behavior**: reading external events never writes anything back to them, and sync-out never reads or modifies an event it didn't create itself.

**Feature 1 — read-only display of external calendar events on the Timeline.** `ExternalCalendarEvent` is a plain, non-Hive, non-persisted value type (title, start, end, source calendar name/color) — NOT a `Task`, never stored in any repository. Fetched fresh via `device_calendar` each time the Timeline loads/refreshes for the visible day(s), scoped to whichever device calendars the user selected to *display* in Settings. Any fetch failure (permission denied, no calendars selected, device error) degrades to "no external events shown" — it never blocks or degrades ordinary Amble task rendering. Rendered read-only, reusing the Zone background block's visual language (light, low-chroma, non-interactive-feeling) — never a `TaskCapsuleBlock`; tapping one shows basic info only (title/time), never edit/complete/drag/delete/category. **Excluded from overlap-cluster detection entirely** (confirmed directly, not guessed) — `detectOverlapClusters`/`layoutOverlappingTasks`/`OverlapClusterBlock` all assume real `Task` objects with status/category/completion, and folding a read-only foreign type into that machinery would be a disproportionate amount of architecture for a decorative feature; external events render as their own always-visible layer, independent of what's clustering underneath.

**Feature 2 — manual, one-directional sync of Amble tasks OUT to a device calendar.** Every scheduled `Task` (has `scheduledAt`) can optionally be pushed to a single user-chosen *target* device calendar, distinct from Feature 1's *display* calendar selection. `Task.externalEventId: String?` (nullable, additive) links a task to the device event it created. Sync is manual only (a "Sync to Calendar" button) — no automatic/background sync, no inbound import, no conflict resolution (Amble always overwrites on next sync). Unscheduled (Inbox) tasks are never synced. A previously-synced event whose source `Task` has since been deleted is removed from the device calendar on the next sync — this requires tracking synced event ids independent of the `Task` row itself once deleted; see docs/DECISIONS.md for the chosen storage shape.

Additive and inert when unused, same guarantee as every other optional entity here: `externalEventId` stays null until a task is actually synced, and neither feature's absence (permission denied, dependency unavailable) affects the Timeline's or Task's ordinary lifecycle.

## Design principles

Named, and referenced by name in reviews and work orders — not just implied.

1. **The plan is provisional, not a verdict.** Non-completion is not failure. No shame-coded UI (no red "you failed" states) for tasks that were skipped or rescheduled — the status enum exists specifically so the UI can tell these apart from abandonment.
2. **Capture is frictionless; prioritization is deferred.** The Inbox exists so a thought can be recorded without forcing an immediate scheduling decision. Anything that adds friction to capture (required fields, forced categorization) works against this.
3. **Replanning should be faster than abandoning the plan.** Every interaction involving moving/resizing/rescheduling a task should be evaluated against this bar.
4. **Screens compose from the design system, never from raw platform widgets.** No direct `Cupertino*`/`Material*` imports in feature screens — always through the adaptive widget layer, so cross-platform consistency isn't something to inspect for after the fact.
5. **A value used twice becomes a token.** Any spacing, color, or radius value repeated in a second location must be promoted to the token system before a third session touches that screen.

## Enforcement status

Most rules above are conventional today — written down and expected to be followed, not yet checked by tooling. `CLAUDE.md` at the repo root carries the same rules so Claude Code loads them automatically every session, and CI (`.github/workflows/flutter-ci.yml`) runs `flutter analyze` + `flutter test` on every push.

The one rule genuinely worth automated enforcement — "no direct Hive calls outside `shared/repositories/`" — isn't enforced by the analyzer yet. Doing so would mean adding the `custom_lint` + `import_lint` packages and a project-specific rule. This is a real new dependency, not a default — flag it as a decision to confirm before adding, per the "no new dependency without naming it" rule, rather than adding it silently.

## What this document is not

It is not the architecture doc (see `ARCHITECTURE.md`), not the feature scope (see `SCOPE.md`), and not a running decision log (see `DECISIONS.md`). Keep it short enough to actually be re-read every session.
