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

These apply to every persisted entity (Task, Event, and anything added later):

- **IDs are client-generated UUIDs from day one.** Never rely on Hive auto-increment. This avoids an ID-remapping migration if/when a backend is added.
- **`status` is an enum**, not a boolean: `pending | completed | skipped | rescheduled`. A skipped or rescheduled task is analytically different from one the user simply never engaged with — collapsing this to `completed: bool` loses information that can't be recovered later.
- **`completedAt` is a separate timestamp from `scheduledAt`.** This is what makes lateness/earliness and any future recovery analytics possible.
- **`originalScheduledAt` is preserved on reschedule.** Without this, replanning behavior is invisible after the fact.
- **`schemaVersion` is present on every persisted object and every export file.** Required for safe future migrations and for import validation.

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
