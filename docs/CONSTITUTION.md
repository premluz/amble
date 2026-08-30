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
