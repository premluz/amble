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

- **User-extensible categories (implemented, v2 this round)** — categories are a persisted `Category` row via `CategoryList.createCategory`, not a fixed enum. v1 was create + list only; **this round adds rename, recolor (constrained to the existing 12-swatch palette, no free picker), and reorder**, via Settings → Categories → list → edit, mirroring the existing Settings → Zones pattern. Delete remains deferred — orphaned-`categoryId` question still unresolved. See `docs/CONSTITUTION.md`'s "Category" section for the full model shape.
- **Voice dictation for Quick Capture** — a tap-to-talk mic button using on-device speech-to-text (`speech_to_text` package, wrapping `SFSpeechRecognizer`/Android `SpeechRecognizer`). Not a new parsing path: dictated text lands in the same `_titleController` and goes through the exact same `parseQuickCapture` → `taskListProvider` pipeline as typed input. Highlighting is applied only once the full transcript lands (no progressive/partial-result highlighting for the first pass).
- **Automatic morning summary to a user-configured Slack Incoming Webhook (implemented, 2026-09-03)** — a separate, opt-in delivery path for the "today's plan" summary above, distinct from the in-app view: once enabled in Settings, a background task (Android WorkManager / iOS BGTaskScheduler, via the `workmanager` package) posts a plain-text summary of the day's tasks directly from the device to a Slack Incoming Webhook URL the user pastes in themselves. Fully local-only in spirit even though it's the first feature where data leaves the device: no backend, no Amble-managed Slack connection/OAuth, and nothing is sent anywhere except the literal webhook URL the user provided. A "Send test message now" button triggers the same send path on demand, since background timing is best-effort (especially on iOS — a real, accepted platform constraint, not a bug). See `docs/CONSTITUTION.md`'s locked stack ("no cloud sync") for why this was confirmed as an explicit scope addition before building, and `docs/DECISIONS.md` for the background-task/isolate-Hive-initialization approach and observed iOS reliability.

## Scoped for later: splash/landing, carousel, and onboarding

Two related but separate features, sequenced deliberately:

**Splash/landing + carousel** (building first): acquisition-focused first-launch screen — logo/background image, a swipeable carousel of key value-prop messages, CTA into the app/onboarding. Presentational only, no data-model impact. Relevant both for real first-launch on mobile and for the portfolio/web-deploy context.

**Onboarding flow** (scoped, not yet started): a short question flow after the splash — wake-up time and wind-down/sleep time (each paired with a short "science tip" explaining why, e.g. regular wake times regulate hormones), a goals question (multi-select from preset options), and a preset-activities picker (curated list, filtered/ordered by the goal selections) the user can add to their schedule immediately.

Wake-up/wind-down answers create special anchor tasks with a confirmed but not-yet-fully-specified lock behavior: **time is editable, duration is not shown, category icon is not shown** (a distinct visual treatment from an ordinary capsule block — more like a marker than a task pill). These should ride on the existing recurring-task architecture (daily recurrence, materialized instances) rather than a new persistence system. Still open, to be settled when this phase actually starts: whether these anchor tasks are deletable at all, or permanent-but-hideable via Settings.

Architecturally: onboarding completion state and goal selections belong in `PreferencesRepository` (Phase 13a) — built generically for exactly this. The preset-activity list is static content (code/assets), not user data — selecting one just calls the existing `Task.create()` path.

## Deferred beyond MVP, explicitly

- "Edit all future occurrences" for recurring tasks (MVP only supports editing a single materialized instance)
- Monthly/yearly recurrence, or complex recurrence patterns beyond daily/weekly + interval + days-of-week

## Zone (time-boxed task containers) — implemented, ungated

A `Zone` is a named time window (e.g. "Morning ritual," 07:00–08:00) that tasks can optionally be assigned into via a nullable `Task.zoneId`, independent of whether the task also has its own `scheduledAt`. See `docs/CONSTITUTION.md`'s "Zone" section for the full model shape.

**Live in every build, including release** — Settings → Zones → list → add/edit (near-full-screen, matching the real task-creation modal's visual language). `FeatureFlags.zoneEnabled` defaults `true`, confirmed directly; still overridable off for testing (`--dart-define=zone=false`). Zone-to-zone overlap is enforced in the add/edit form. Capacity-exceeded behavior is calculated (`calculateZoneCapacity`) but not enforced by any UI.

**Simple recurrence + notifications implemented (2026-09-02)**: a Zone can optionally repeat via the same `RecurrenceRule` shape `Task` uses (one rule, same start/end time on every occurrence — no per-occurrence override), and can optionally fire a start-time alert (`notificationsEnabled`, default on) via `NotificationService.scheduleForZone`, a one-shot next-occurrence alert re-resolved on every save rather than a true recurring OS alarm. See CONSTITUTION.md's Zone section and docs/DECISIONS.md for the full shape and judgment calls.

Three real forks remain open, deliberately not resolved yet: (1) what happens when a zone's assigned-task durations exceed its own capacity — hard block, warning, or silent overflow; (2) zone recurrence needs per-occurrence-adjustable start/end times (a Monday zone and a Wednesday zone in the same series can differ) — the simple, uniform-rule version above is implemented, but this harder per-occurrence version is still deferred and likely needs its own per-instance model rather than the one shared `RecurrenceRule`; (3) dragging a zone with its contained tasks, and cascading zones, are structurally similar to the existing task-level cascade-push but not the same code, and are explicitly deferred. Each of these needs its own confirm-first pass before implementation. There is also currently no UI for *assigning* a task to a zone (setting `Task.zoneId`) — only creating/editing zones themselves.

## TaskTemplate (reusable task blueprints) — new, ungated

A `TaskTemplate` is a reusable blueprint for tasks created repeatedly (e.g.
"Take a walk") — title, category, optional default duration, optional link to
a `TrackedBehavior`. Never itself schedulable or completable; exists only to
be copied into a real `Task` via `Task.create()`. See `docs/CONSTITUTION.md`'s
"TaskTemplate" section for the full model shape.

**v1 scope: create, list, edit, delete** — unlike `Category`/`Zone`, templates
are freely deletable since nothing depends on a template's continued existence
once it has spawned a task (no orphaned-reference problem). Surfaced via a
second Inbox tab ("Templates") and a frequency-ranked quick-drop chip row
below the task-creation title field, alongside `TrackedBehavior` chips.

Ungated — free functionality, same tier as `Category`, not behind
`FeatureFlags.trackedBehaviorEnabled`.

## TrackedBehavior (persistent tracked objects) — model implemented, UI scoped this round

A separate architectural layer — persistent objects with a target that
accumulates evidence across many scheduled `Task` instances over time (e.g.
"Exercise, 60 min, 3x/week"). See `CONSTITUTION.md` for the data-model shape
(`TrackedBehavior` entity, `Task.behaviorId`/`Task.actualAmount`).

**This round adds real UI**: a dedicated 4th bottom-nav tab ("Tracked") for
create/list/edit of `TrackedBehavior` rows directly, plus the same quick-drop
chip surfacing `TaskTemplate` gets. `FeatureFlags.trackedBehaviorEnabled`
remains the gating seam and is the intended future pro/paid-tier boundary —
`Category` and `TaskTemplate` are explicitly NOT gated behind it.

**Still explicitly deferred**: history view, calibration suggestions, weekly
review screen. This round is container + basic create/list/attach only — no
rollup/analytics UI yet, unchanged from the original MVP posture.


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

## Navigation structure

Bottom nav: **Inbox / Timeline / Tracked / Settings** (4 tabs, updated this round from the original 3 — "Tracked" is the new TrackedBehavior nav destination; see CONSTITUTION.md). No separate "Places," "Saved," or "Notes" sections — if these appear anywhere in the codebase or a work order, they're a scaffold mismatch, not a planned Amble feature.
