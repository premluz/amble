# Amble — MVP Scope

This is the authoritative feature list. If a work order or a session's output doesn't map to something below, stop and check before building on it — this file exists specifically to catch scope drift (e.g. a stray "Places/Saved/Notes" structure that doesn't belong to this app).

## Core (must-have for v1)

- **Timeline view** — vertical day view, tasks/events as colored time blocks, current-time indicator
- **Task/event creation** — title, time block (start + duration), icon/color, optional notes
- **Inbox** — capture unscheduled tasks/thoughts, move into timeline when ready
- **Completion tracking** — mark done, with `completedAt` + status enum (see Constitution)
- **Manual reschedule** — drag-to-move a task to a new time; `originalScheduledAt` preserved
- **Day navigation** — swipe/tap between days, jump to today
- **Local notifications** — basic alert at task start time
- **Export / import** — JSON export via share sheet, import via file picker (doubles as backup)
- **Recurring tasks** — daily/weekly repeat via materialized instances; see Constitution for the model shape. Editing/deleting for MVP affects a single instance only, never the whole series.

## Nice-to-have (still v1 if time allows, not a separate phase)

- Simple categories/colors as a lightweight tagging system
- Basic "today's plan" summary view (in-app only, not an OS widget)

## Scoped for later: splash/landing, carousel, and onboarding

Two related but separate features, sequenced deliberately:

**Splash/landing + carousel** (building first): acquisition-focused first-launch screen — logo/background image, a swipeable carousel of key value-prop messages, CTA into the app/onboarding. Presentational only, no data-model impact. Relevant both for real first-launch on mobile and for the portfolio/web-deploy context.

**Onboarding flow** (scoped, not yet started): a short question flow after the splash — wake-up time and wind-down/sleep time (each paired with a short "science tip" explaining why, e.g. regular wake times regulate hormones), a goals question (multi-select from preset options), and a preset-activities picker (curated list, filtered/ordered by the goal selections) the user can add to their schedule immediately.

Wake-up/wind-down answers create special anchor tasks with a confirmed but not-yet-fully-specified lock behavior: **time is editable, duration is not shown, category icon is not shown** (a distinct visual treatment from an ordinary capsule block — more like a marker than a task pill). These should ride on the existing recurring-task architecture (daily recurrence, materialized instances) rather than a new persistence system. Still open, to be settled when this phase actually starts: whether these anchor tasks are deletable at all, or permanent-but-hideable via Settings.

Architecturally: onboarding completion state and goal selections belong in `PreferencesRepository` (Phase 13a) — built generically for exactly this. The preset-activity list is static content (code/assets), not user data — selecting one just calls the existing `Task.create()` path.

## Deferred beyond MVP, explicitly

- "Edit all future occurrences" for recurring tasks (MVP only supports editing a single materialized instance)
- Monthly/yearly recurrence, or complex recurrence patterns beyond daily/weekly + interval + days-of-week

## Deferred, flagged feature: TrackedBehavior (persistent tracked objects)

A separate architectural layer — persistent objects with a target that accumulates evidence across many scheduled `Task` instances over time (e.g. "Exercise, 60 min, 3x/week," logged as Done/Partial/Skipped with an actual amount). See `CONSTITUTION.md` for the data-model shape (`TrackedBehavior` entity, `Task.behaviorId`/`Task.actualAmount`).

This is explicitly **not** part of the initial MVP build-out, but the data model is included now (Phase 10) because retrofitting the `Task.behaviorId` link after tasks already exist without it is far more disruptive than including a nullable field today. The feature is additive and inert when unused — no existing behavior changes if it's never surfaced in the UI. Treat it as feature-flagged: build the model/repository layer now, gate any UI entry points (creating a tracked behavior, a history/calibration view) behind a flag, default off. This avoids forking the app into a second product while still being honest that Amble may grow in this direction later — see the two research documents this decision is based on for the full future-state thinking (persistent behavior objects, target-vs-actual calibration, habit-formation science) — none of which is MVP scope yet.

## Cascade replanning — drag-to-reschedule push (implemented)

When "Prevent overlapping tasks" (Settings) is on and a task is dragged onto a slot that overlaps another scheduled task, the drop no longer rejects — it pushes. The overlapped task's nearer edge (start or end) to the dragged task's new start decides direction: if the dragged task's new start is closer to the existing task's end, the existing task shifts earlier so its end touches the dragged task's new start; if closer to the existing task's start, it shifts later so its start touches the dragged task's new end — in both cases the pushed task keeps its own original duration. If that push in turn overlaps a third task, that task is pushed the same way, chaining in whichever direction the cascade extends (capped at the day's task count as a cycle guard). If applying the full chain would push any task's start before 00:00 or end after 24:00 of the day being viewed, the entire cascade aborts and the drag snaps back as if it never happened — nothing partially applies. Every pushed task (not just the dragged one) goes through the same reschedule semantics as an ordinary drag (`originalScheduledAt` set once, `status` becomes `rescheduled`). Scope is drag-only: the create wizard and edit-time modal still reject-and-show-inline-error on overlap, since neither has a drag context to compute a push direction from. Implemented this session — see `docs/DECISIONS.md` for the algorithm and worked examples.

## Explicitly out of scope for MVP

- Calendar import/sync
- Supabase / cloud sync / auth
- AI task decomposition
- Apple Watch app, home/lock screen widgets
- Energy/rhythm/capacity features
- Any analytics dashboard UI (data fields exist for this per the Constitution; no screen yet)
- TrackedBehavior UI surfaces (history view, calibration suggestions, weekly review) — model exists, UI is flagged off by default; see above

## Navigation structure

Bottom nav: **Inbox / Timeline / Settings**. (No separate "Places," "Saved," or "Notes" sections — if these appear anywhere in the codebase or a work order, they're a scaffold mismatch, not a planned Amble feature.)
