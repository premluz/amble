# Amble — Constitution

This is the stable core. It should rarely change. Every build session (Claude Code or otherwise) reads this before touching code.

## Locked stack

- **Framework**: Flutter, single codebase → iOS + Android
- **State management**: Riverpod (`flutter_riverpod`, code-gen via `riverpod_generator`)
- **Local persistence**: Hive (`hive`, `hive_flutter`) — local-only for MVP, no auth, no cloud sync
- **Access pattern**: Repository interfaces only. UI and state never call Hive directly. This is what makes a future Supabase swap a new implementation of an existing interface, not a rewrite.
- **Backend**: none in MVP. Deferred behind the repository interface, not designed around yet.
- **Calendar import/sync**: explicitly out of scope. Not a phase-2 default — a decision to revisit deliberately if it ever comes up.

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

## Zone — a time-boxed container of tasks (spike, not yet built)

**Status: design-only.** This section records the model shape agreed on 2026-09-01 so it doesn't drift before implementation starts. No `Zone` model, repository, or UI exists yet — see `docs/PROGRESS_LOG.md` for the spike entry and `docs/SCOPE.md` for where this sits relative to MVP. Nothing below is a non-negotiable until code lands; treat it as the agreed starting point for that first implementation session, revisable if it doesn't hold up in practice.

A `Zone` is a separate, persistent entity — its own model, own Hive box, own repository, same shape as `TrackedBehavior` above — representing a named time window (e.g. "Morning ritual," 07:00–08:00) that a `Task` can optionally be assigned into. Distinct from *recurring*, the same way `TrackedBehavior` is distinct from it: a Zone is a container with a start/end time and a capacity, not a scheduling rule on `Task` itself.

**Zone is metadata on a Task, not a container that owns it.** A `Task` does not live "inside" a `Zone` structurally — `zoneId` is a reference, same shape as `behaviorId`, and a task remains fully valid and functional with it unset. Time (`scheduledAt`) and zone (`zoneId`) are independent dimensions on `Task`, not a hierarchy — a task can be precisely timed + zoned, precisely timed + unzoned, loosely timed (zone-only) + zoned, or neither. This independence is what makes multiple views over the same data possible without duplicating the model per view.

**Each Timeline view has one job; views should not converge on answering the same question.** Confirmed as a design rule, not just an observation: a *Zone/spatial-zone view* organizes meaning (understand the shape of the day), a *spatial task view* organizes time (manipulate the schedule), and a *list/compact view* organizes action (execute the schedule — see the overlap-cluster feature's flat-list-inside-a-spatial-shell pattern as the existing precedent for this). If a future feature request would make one view start doing another view's job (e.g. list view growing zone-editing), that's a signal to push back or split it into the view whose job it actually is, not to blend the views.

- **`Zone` fields (draft)**: `id` (client UUID), `title`, `startTime`/`endTime` (time-of-day, not a specific date — see recurrence note below), `schemaVersion`. Duration is derived (`endTime - startTime`), not stored separately, so it can never drift from the two times that define it.
- **`Task` gains one nullable field: `zoneId: String?`** — same pattern as `behaviorId`: null for an ordinary task (unchanged default), non-null when assigned to a zone. Confirmed directly: this is a real relationship (`taskId` → `zoneId`), not something derived by checking whether `scheduledAt` falls inside a zone's time window — because a task can be assigned to a zone with **no `scheduledAt` at all**. That's the actual reason this can't be computed from overlap: a zone-only task has nothing to overlap against.
- **A task may set a zone, a `scheduledAt`, or both.** Confirmed directly ("sufficient for task to set either zone or time for it, or both, but can set just zone and not a time"). This makes the resolved "when" of a task three-way rather than the current two-way (Inbox vs. scheduled): explicit time, zone-only (time implied by zone + capacity ordering), or neither (Inbox, unchanged). Every read site that currently treats `scheduledAt == null` as "this task is in the Inbox" needs to learn this third state — that is the single largest ripple from this feature and the main reason it's being spiked as a design pass first, not built directly.
- **Zones cannot overlap each other.** Enforced the same shape as the existing "Prevent overlapping tasks" setting, but zone-to-zone, not task-to-task — needs its own check, since the existing `overlapsExistingTask` helper reasons over `Task.scheduledAt`/`durationMinutes`, which a `Zone` doesn't share a supertype with.
- **Capacity is checked, not enforced physically**: the sum of `durationMinutes` across a zone's assigned tasks (that also have a `scheduledAt`) is compared against the zone's own duration (`endTime - startTime`). What happens when the sum exceeds capacity — hard block, warning, or silent overflow — is undecided; needs its own confirm-first pass before building, same as the overlap-prevention setting got.
- **Recurrence is a genuine open fork, not resolved by reusing `RecurrenceRule`.** Confirmed directly: zone recurrence needs to be "adjusted per day individually" — e.g. a Monday zone at 07:00–08:00 and a Wednesday zone at 07:30–08:15 as one logical recurring series. The existing `RecurrenceRule` (`frequency`/`interval`/`daysOfWeek`) applies one rule uniformly across every occurrence — it has no per-occurrence override mechanism, and stretching it to fit would violate its own "not a persisted entity of its own, deliberately small" design (see the Recurring Tasks section above). This most likely means a `Zone` series needs its own, separately materialized-instance model (real per-day `Zone` rows, sharing a `recurrenceId`-style series link, each with its own `startTime`/`endTime`) rather than one shared `RecurrenceRule` value object — same "materialized instances, not virtual expansion" philosophy as recurring tasks, but the rule itself needs to live per-instance instead of only on the template. Needs its own dedicated design pass before building; flagged here so it isn't silently assumed away.
- **Dragging a zone (with its contained tasks) and cascading zones are deferred, out of scope for the first build.** Structurally similar to the existing task-level cascade-push algorithm (see SCOPE.md), but not the same code: moving a zone has to move every assigned task in lockstep, decide what happens to a task's own explicit `scheduledAt` if it had one (move it by the same delta? re-anchor to the new zone-relative position?), and the non-overlap constraint applies at the zone level while the existing cascade reasons at the task level. Real future work, not assumed to fall out of the existing cascade code for free.

Additive and inert when unused, same guarantee as `TrackedBehavior`: `zoneId` stays null everywhere until a Zone UI exists, and `Task`'s existing lifecycle (Inbox, scheduling, recurrence, notifications) is unaffected by an unset `zoneId`.

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
