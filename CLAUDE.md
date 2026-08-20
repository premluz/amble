# Amble

Flutter app (iOS + Android, single codebase). Local-first task/timeline planner, MVP scope.

## Read before doing anything

Always read these, in this order, before starting any task in this repo:

1. `docs/CONSTITUTION.md` — locked stack, data-model non-negotiables, design principles. Rarely changes. Violating anything here is a stop-and-ask, not a judgment call.
2. `docs/SCOPE.md` — what's in the MVP and what's explicitly deferred. If a task doesn't map to something in here, stop and confirm before building.
3. `docs/ARCHITECTURE.md` — layered architecture, token system, folder structure, the capsule timeline block note.
4. `docs/ERROR_LOG.md` — known gotchas. Check before debugging something that may have already been solved.
5. `docs/DECISIONS.md` — smaller settled choices, so they don't get silently re-opened.

After finishing a task, before ending the session:

6. Append a short entry to `docs/PROGRESS_LOG.md` — what happened, what shipped, what's still open. Don't skip this even for small sessions.
7. If a new mistake/gotcha was hit and fixed, add it to `docs/ERROR_LOG.md`.
8. If a new small decision was made that isn't in the Constitution, add it to `docs/DECISIONS.md`.

## Non-negotiable rules (see CONSTITUTION.md for full detail)

- Never call Hive directly outside `shared/repositories/`. All data access goes through repository interfaces.
- IDs are client-generated UUIDs, never Hive auto-increment.
- `status` is the enum (`pending | completed | skipped | rescheduled`), never a plain bool.
- No direct `Cupertino*`/`Material*` widget imports in `features/` — use the adaptive widget layer in `core/`.
- No new top-level dependency without flagging it as a decision first — don't add packages silently.

## Every task

- Run `flutter analyze` and `flutter test` before reporting a task done. Both must be clean.
- Work orders are scoped intentionally — stick to the stated task and non-goals. Don't opportunistically build ahead into a later phase from `docs/PROJECT_PLAN.md`.
- If a task's exit criteria (per `docs/PROJECT_PLAN.md`) includes test coverage, don't report done without it — "compiles and runs" is not the same as "done" for anything past Phase 0.
