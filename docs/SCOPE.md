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

**Splash/landing + carousel** (building first): acquisition-focused first-launch screen — logo/background image, a swipeable carousel of key value-prop messages, CTA into the app/onboarding. Presentational only, no data-model impact. Relevant both for real first-launch on mobile and for the portfolio/web-deploy context. Both the carousel and the personalization step below are independently skippable — skipping either (or both) never results in an empty app; see pre-population below.

**Onboarding flow — question steps** (scoped, not yet started): a short question flow after the splash — wake-up time and wind-down/sleep time (each paired with a short "science tip" explaining why, e.g. regular wake times regulate hormones), and a goals question (multi-select from preset options, e.g. health/work/personal — mapped to `Category`/`Category`-tagged presets, not a separate taxonomy).

Wake-up/wind-down answers create special anchor tasks with a confirmed but not-yet-fully-specified lock behavior: **time is editable, duration is not shown, category icon is not shown** (a distinct visual treatment from an ordinary capsule block — more like a marker than a task pill). These should ride on the existing recurring-task architecture (daily recurrence, materialized instances) rather than a new persistence system. Still open, to be settled when this phase actually starts: whether these anchor tasks are deletable at all, or permanent-but-hideable via Settings.

**Onboarding flow — pre-population (2026-09-06, new)**: the goal of onboarding is to reach a populated, usable day immediately, not an empty Timeline the user has to fill themselves.

- **Built-in presets, seeded like `Category`'s built-ins**: a curated set of `TaskTemplate` rows (`isBuiltIn: true`, fixed UUIDs, idempotent re-seed — same pattern as `BuiltInCategoryIds`) framed around the product's actual positioning — things that make someone leave more of their life, not just do more tasks (e.g. "Take a walk," "Relax"). A parallel curated set of built-in `Zone` rows (`isBuiltIn: true`), deliberately coarse, covering the routines that are close to universal — Morning routine, Work, Evening wind-down — not granular enough to need personalization to feel right.
- **Personalization filters, doesn't gate to empty**: the goals question filters which built-in presets/zones are *offered* by `categoryId` — skip health goals, don't show health-tagged presets. A baseline subset of presets/zones (not goal-dependent) is always included regardless of any answer.
- **Skipping onboarding or personalization still seeds the baseline default set.** Confirmed directly: never an empty Timeline on first open, regardless of how much the user skips. This is the anchor requirement — personalization only adds to or narrows the offered set beyond this baseline, it never subtracts down to nothing.
- **Whether tapping a preset during onboarding spawns a live Task immediately (in addition to being available as a Template) versus only adding it to the Templates tab for the user to place themselves is still an open brainstorm, not decided.** Do not build against either assumption without confirming first.
- **The last onboarding step doubles as Edit Mode's introduction**: rather than a separate tutorial screen explaining drag/resize/remove, onboarding lands the user on their own pre-populated day already in Edit Mode (see `docs/CONSTITUTION.md`'s "Edit Mode" section) — discovery happens through direct manipulation of real (if generated) content, not an explanation screen in front of it.

Architecturally: onboarding completion state and goal selections belong in `PreferencesRepository` (Phase 13a) — built generically for exactly this.

## Deferred beyond MVP, explicitly

- "Edit all future occurrences" for recurring tasks (MVP only supports editing a single materialized instance)
- Monthly/yearly recurrence, or complex recurrence patterns beyond daily/weekly + interval + days-of-week

## Zone — weekly placements and reusable names (2026-09-14)

**Current scope supersedes the historical description below:** Settings manages name-only facets. The usual-week grid paints independent weekday/time placements, previews phantom zones, and names them on release; single taps create one placement, horizontal fill extends an existing placement in edit mode. Names never carry times. The future-instance toggle is gone. Migration retains dated history, exceptions and IDs; unsupported legacy recurrence remains compatible. New exception authoring and analytics are deferred. See the Constitution’s “Current contract — weekly painting” section.

A `Zone` is a named time window (e.g. "Morning ritual," 07:00–08:00) that tasks can optionally be assigned into via a nullable `Task.zoneId`, independent of whether the task also has its own `scheduledAt`. See `docs/CONSTITUTION.md`'s "Zone" section for the full model shape.

**Live in every build, including release** — Settings → Zones → list → add/edit (near-full-screen, matching the real task-creation modal's visual language). `FeatureFlags.zoneEnabled` defaults `true`, confirmed directly; still overridable off for testing (`--dart-define=zone=false`). Zone-to-zone overlap is enforced in the add/edit form. Capacity-exceeded behavior is calculated (`calculateZoneCapacity`) but not enforced by any UI.

**Recurrence: materialized per-occurrence instances (2026-09-09), superseding the earlier single-row/live-rule design.** A recurring Zone is now real, persisted per-day rows sharing a `recurrenceId` — the same "materialized instances, not virtual expansion" philosophy `Task` already uses — not one shared row with a rule evaluated on the fly. Each instance can optionally fire a start-time alert (`notificationsEnabled`, default on) resolved directly against its own `anchorDate`/`startMinutes`, topped up on launch alongside `Task`'s own notification refresh. See `docs/CONSTITUTION.md`'s Zone section and docs/DECISIONS.md's 2026-09-09 entry for the full shape.

**Resize implemented as of Edit Mode (2026-09-06); reposition/cascade implemented same day.** See `docs/CONSTITUTION.md`'s "Edit Mode" section. Both now operate on same-day materialized instances (day-filtered), not a shared rule.

**Weekly Zone Authoring Grid (2026-09-13, new)** — a full-screen destination showing every zone across all 7 days of the week at once (day columns × hour axis), reached from a new icon in the Timeline's shared calendar header. Multiselect across zones and days, group move/resize with per-column non-overlap checking, no color coding (label text only). See `docs/CONSTITUTION.md`'s own "Weekly Zone Authoring Grid" section for the full spec, including the confirmed judgment calls (all-or-nothing group commit, group-wide "affect future instances" toggle) and what's still deferred (the Events tab; the toggle's ON state, which needs a not-yet-built Zone series re-anchor path).

Real forks remain open, deliberately not resolved yet: (1) what happens when a zone's assigned-task durations exceed its own capacity — hard block, warning, or silent overflow; (2) a Zone-level equivalent of `TaskList.updateTaskWithChangedRecurrence` (prune + re-anchor a whole series) does not exist — the per-occurrence-adjustable-times fork this section used to flag as deferred is now reachable per-instance (edit one materialized row), but there is no "re-anchor the whole series to a new uniform time" edit path yet; this is what the weekly grid's "affect future instances" toggle needs once it's built. There is also currently no UI for *assigning* a task to a zone (setting `Task.zoneId`) — only creating/editing zones themselves, and no zone-delete UI anywhere.

## TaskTemplate (reusable task blueprints) — new, ungated

A `TaskTemplate` is a reusable blueprint for tasks created repeatedly (e.g. "Take a walk") — title, category, optional default duration, optional link to a `TrackedBehavior`. Never itself schedulable or completable; exists only to be copied into a real `Task` via `Task.create()`. See `docs/CONSTITUTION.md`'s "TaskTemplate" section for the full model shape.

**v1 scope: create, list, edit, delete** — unlike `Category`/`Zone`, templates are freely deletable since nothing depends on a template's continued existence once it has spawned a task (no orphaned-reference problem). Surfaced via a second Inbox tab ("Templates"), a frequency-ranked quick-drop chip row below the task-creation title field, and Edit Mode's drawer (same data, second entry point).

**Add Task sheet's own template browser (implemented, 2026-09-07)** is the first of these three to ship — a plain list under the Name section (stage 1 only), each row the same `TemplateRow` the Inbox's own Templates tab uses, minus its Edit/Delete affordance. Requested directly: "let's list the templates ... under Task Name." Confirmed via direct follow-up as templates only, not a second Tasks tab (see `docs/CONSTITUTION.md`'s own entry for why). **Not yet the frequency-ranked chip row** described above — this is a straightforward list in saved order, and `Task.templateId` (recorded on save) is what a future frequency-ranking pass would read.

A curated built-in subset (`isBuiltIn: true`) is seeded at first launch for onboarding pre-population — see the onboarding section above.

Ungated — free functionality, same tier as `Category`, not behind `FeatureFlags.trackedBehaviorEnabled`.

## TrackedBehavior (persistent tracked objects) — model implemented, UI scoped this round

A separate architectural layer — persistent objects with a target that accumulates evidence across many scheduled `Task` instances over time (e.g. "Exercise, 60 min, 3x/week"). See `CONSTITUTION.md` for the data-model shape (`TrackedBehavior` entity, `Task.behaviorId`/`Task.actualAmount`).

**This round adds real UI**: a dedicated 4th bottom-nav tab ("Tracked") for create/list/edit of `TrackedBehavior` rows directly, plus the same quick-drop chip surfacing `TaskTemplate` gets, including in Edit Mode's drawer. `FeatureFlags.trackedBehaviorEnabled` remains the gating seam and is the intended future pro/paid-tier boundary — `Category` and `TaskTemplate` are explicitly NOT gated behind it.

**Still explicitly deferred**: history view, calibration suggestions, weekly review screen. This round is container + basic create/list/attach only — no rollup/analytics UI yet, unchanged from the original MVP posture.

## Edit Mode — direct Timeline manipulation (new, 2026-09-06)

A permanent, toggleable Timeline mode — not onboarding-only, though onboarding's last step introduces it on a pre-populated first day (see onboarding section above). Full spec in `docs/CONSTITUTION.md`'s "Edit Mode" section: entry via two-finger long-press or a top-right "Edit" link, resize handles on both Tasks and Zones, unchanged move-drag, drag-to-delete-target for Tasks (YouTube-PiP-dismiss style, bypasses the cascade-push algorithm entirely), and the same Templates/TrackedBehavior quick-drop drawer as a second entry point. Zone delete and zone reposition are explicitly not included this round.

## Cascade replanning — drag-to-reschedule push (implemented)

When "Prevent overlapping tasks" (Settings) is on and a task is dragged onto a slot that overlaps another scheduled task, the drop no longer rejects — it pushes. The overlapped task's nearer edge (start or end) to the dragged task's new start decides direction: if the dragged task's new start is closer to the existing task's end, the existing task shifts earlier so its end touches the dragged task's new start; if closer to the existing task's start, it shifts later so its start touches the dragged task's new end — in both cases the pushed task keeps its own original duration. If that push in turn overlaps a third task, that task is pushed the same way, chaining in whichever direction the cascade extends (capped at the day's task count as a cycle guard). If applying the full chain would push any task's start before 00:00 or end after 24:00 of the day being viewed, the entire cascade aborts and the drag snaps back as if it never happened — nothing partially applies. Every pushed task (not just the dragged one) goes through the same reschedule semantics as an ordinary drag (`originalScheduledAt` set once, `status` becomes `rescheduled`). Scope is drag-only: the create wizard and edit-time modal still reject-and-show-inline-error on overlap, since neither has a drag context to compute a push direction from. Edit Mode's drag-to-delete drop path explicitly bypasses this algorithm entirely — see `docs/CONSTITUTION.md`'s "Edit Mode" section.

## Important flag (display-only) — implemented

`Task.isImportant` marks a handful of tasks as mattering most on a given day. **Purely visual**: a calm marker glyph before the task's title, with no effect on cascade, overlap, validation, or any limit on how many can be marked. Toggled from the task action sheet ("Mark important" / "Remove important"). Per-instance for recurring tasks, like every other single-instance edit.

Confirmed directly as narrower than its first draft, which also proposed cascade-anchor priority and a soft cap warning past 3 per day — both dropped ("actually.. no restrictions"). See `docs/CONSTITUTION.md`'s "Important flag" section.

## Explicitly out of scope for MVP

- Calendar import/sync
- Supabase / cloud sync / auth
- AI task decomposition
- Apple Watch app, home/lock screen widgets
- Energy/rhythm/capacity features
- Any analytics dashboard UI (data fields exist for this per the Constitution; no screen yet)
- TrackedBehavior UI surfaces (history view, calibration suggestions, weekly review) — model exists, basic UI is in scope this round; see above
- Zone delete
- ~~Zone reposition/cascade~~ — reversed 2026-09-06 (confirmed directly, "zones should never overlap... perhaps cascading... that doesn't block user intention"); see docs/CONSTITUTION.md's "Edit Mode" section and docs/DECISIONS.md for the shipped design.

## Navigation structure

Bottom nav: **Inbox / Timeline / Tracked / Settings** (4 tabs, updated 2026-09-06 from the original 3 — "Tracked" is the new TrackedBehavior nav destination; see CONSTITUTION.md). No separate "Places," "Saved," or "Notes" sections — if these appear anywhere in the codebase or a work order, they're a scaffold mismatch, not a planned Amble feature.

## Siri / Google Assistant integration — scoped, ready to build

On-device voice-assistant integration (iOS App Intents, Android App
Actions/App Functions) — add task, add note, add zone, read a templated
day summary, and remove task via fuzzy title match. No server, no new
architecture; reuses the existing repository layer and the already-scoped
NLP quick-capture parser. Full spec in `docs/CONSTITUTION.md`'s "Siri /
Google Assistant integration" section. Real native Swift/Kotlin work
required per platform, distinct from most of the app's Dart-only build so
far.


## MCP server — deferred, depends on the (still undecided) desktop build

Not scoped for implementation. MCP doesn't strictly require a hosted cloud
backend — it supports a local stdio transport — but it does need a
persistent running process for an AI client to connect to, which a
sandboxed mobile OS doesn't offer. Amble's real data lives on the phone
today; there is no desktop build. This isn't really "build an MCP server,"
it's "build the desktop app, and an MCP server becomes possible once it
exists" — the same open fork already on record from the earlier
desktop/web discussion, not a new decision.

What it would add once unblocked, worth remembering rather than re-deriving
later: unlike Siri/Assistant's fixed intent slots, an MCP-connected LLM can
reason open-endedly over real data ("what's a good 30-minute gap for a walk
today") — a genuinely different capability from the Track 1 integration
above, not a redundant second path to the same thing.



