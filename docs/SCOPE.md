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

## Nice-to-have (still v1 if time allows, not a separate phase)

- Recurring tasks (daily/weekly repeat)
- Simple categories/colors as a lightweight tagging system
- Basic "today's plan" summary view (in-app only, not an OS widget)

## Explicitly out of scope for MVP

- Calendar import/sync
- Supabase / cloud sync / auth
- Cascade replanning logic (automatic reflow when a task runs over)
- AI task decomposition
- Apple Watch app, home/lock screen widgets
- Energy/rhythm/capacity features
- Any analytics dashboard UI (data fields exist for this per the Constitution; no screen yet)

## Navigation structure

Bottom nav: **Inbox / Timeline / Settings**. (No separate "Places," "Saved," or "Notes" sections — if these appear anywhere in the codebase or a work order, they're a scaffold mismatch, not a planned Amble feature.)
