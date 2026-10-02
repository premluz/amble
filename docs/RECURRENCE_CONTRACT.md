# Recurrence & Occurrence — Behavioral Contract

**Status: specification only — revision 2 (2026-10-02).** Nothing here is
implemented. `CONSTITUTION.md`'s "materialized instances" section stays
authoritative for current code until a storage option is approved against
this contract.

**Purpose.** Define what repeating tasks must *do*, independent of storage.
Two candidate designs will be compared against it:

- **Option A** — dedicated `Series` entity; occurrences stored as rows.
- **Option B** — dedicated `Series`; occurrences computed; per-occurrence data
  stored only where something differs or happened.

Either option may use any internal representation (version lists, snapshots,
per-row copies) as long as every requirement and scenario below holds. Rules
are marked **Confirmed** (decided by the product owner) or **Proposed**
(recommended, still open). §13's scenarios are the acceptance tests.

**Revision 2 changes:** occurrence identity no longer includes start time;
migration policy states its ambiguity instead of claiming no loss; storage
choices moved out of requirements; D4 split into three rules; target
versioning resolved by occurrence date; credit attribution, omission deadline,
travel, resolver merging, stranded records and conflict-safe undo added;
completion separated from streak success.

---

## 1. Terms

| Term | Meaning |
|---|---|
| **Series** | One repeating thing ("Run, weekdays 07:00"). Owns its rule independently of any occurrence — deleting an occurrence can never delete or orphan the rule. |
| **Revision** | The rule and default fields of a series *as they applied from a given date*. A behavioral concept: the series must be able to answer "what applied on date X". How this is stored is per option. |
| **Occurrence** | One expected instance of a series. |
| **Occurrence key** | Stable identity of an occurrence (§3). Never changes when the occurrence is moved or its series time changes. |
| **Occurrence data** | What is known about one occurrence beyond its revision: field overrides, outcome, value, note, outcome timestamp. |
| **Outcome** | What happened to an occurrence (§5). Separate from where it is scheduled. |
| **Plan** | Where and when occurrences are expected. Moving an occurrence changes the plan, never the outcome. |

---

## 2. Confirmed decisions

| # | Decision |
|---|---|
| D1 | **Adding a note never freezes an occurrence.** Only fields the user edits directly override the series. |
| D2 | **Future times are "where I am"** (floating local time) by default. The model must allow a fixed zone later. |
| D3 | **Cancelled occurrences never count against streaks.** |
| D4a | **Automatic series changes never change the past.** Past dates keep the expectations *and* context (title, category, duration, time, behavior, target) that applied on that date. |
| D4b | **Changing history requires an explicit correction action.** None is being built; if one ever is, it is a separate, named action, never a side effect of a series edit. |
| D4c | **Outcomes may be recorded after the fact** (marking yesterday done today), with the time they were recorded kept (§5). |
| D5 | **Streak foundation, not streaks.** Data must distinguish omitted, skipped, done, and a measured value, each with or without a note. No streak success policy is decided here. |
| D6 | **Undo reverses the data, and patterns reflect it.** An undone "done" stops counting everywhere. |
| D7 | **Current state, not every write.** Each occurrence's data holds its latest state, written when it changes. Undo uses the state captured just before the write. No per-write log. |
| D8 | **Credit: store both dates.** An occurrence keeps its original date (its key) and, when completed, the local date it was completed. Each future metric chooses which to use. |
| D9 | **Omitted at the end of its day, but never before its end.** An occurrence with no outcome becomes omitted at the later of: midnight after its start date, or its scheduled end. (23:00–01:00 becomes omitted at 01:00.) |
| D10 | **"All occurrences" edits reach the future only.** Past occurrences keep their title, category and other context (consistent with D4a). |

---

## 3. Occurrence identity

- **Proposed — key = series id + original local date + same-day ordinal.**
  The ordinal is 1 for Amble's own series (at most one occurrence per day per
  series). Start time is **not** part of the key, so changing a series from
  07:00 to 08:00 keeps every occurrence's identity and its data (note,
  cancellation, completion, notification, external link) attached.
- **Imported series with several occurrences on one day** get ordinals by
  original start order; the source's own identifier (iCalendar
  `RECURRENCE-ID`) is kept on the external link, not used as the key.
- **Weekday changes have no correspondence.** Mon/Wed/Fri → Tue/Thu does not
  map Monday's occurrence onto Tuesday. Data on dates the new revision no
  longer expects follows §9.
- Identity must survive unchanged: occurrence data first being stored; series
  time or duration changes; "this and following" edits; notification taps
  (payload carries the key); undo; export/restore; external links.
- **At most one occurrence data item per key.** A second write updates it,
  never creates a parallel one.

---

## 4. Field inheritance

Every overridable plan field of an occurrence is in exactly one state:

| State | Meaning | Later series edit affects it? |
|---|---|---|
| **Inherited** | Value comes from the revision applying on the occurrence's date. | Yes (future occurrences only — D4a) |
| **Overridden** | User set a value for this occurrence. | No |
| **Cleared** | User explicitly removed the value for this occurrence. | No |

- Inherited and cleared must be distinguishable.
- **Overridable plan fields — Proposed:** start time, duration, title,
  description, category, zone, notifications on/off, important.
- **Never inherited (belong to the occurrence):** outcome, value, note,
  outcome timestamp, completion date.
- **Confirmed (D1):** setting a note, outcome or value never changes any plan
  field's state.
- **Proposed:** "reset to series" returns every plan field to inherited and
  keeps outcome, value and note.

---

## 5. Outcomes (streak foundation)

Outcome is separate from plan. The current `TaskStatus.rescheduled` value
mixes the two and is not an outcome in the new model.

| State | How it arises | Counts as expected? | Completed? |
|---|---|---|---|
| **Upcoming** | No outcome, before its omission deadline (D9) | Not yet due | No |
| **Omitted** | No outcome, past its omission deadline | Yes | No |
| **Skipped** | User explicitly skipped | Yes | No |
| **Done** | User marked done | Yes | Yes |
| **Cancelled** | User removed this one occurrence, or an imported event was cancelled | **No** (D3) | No |
| **Series ended** | Series end date / deletion | No occurrences exist after the end | — |

- **Value is independent of completion.** A measured value (e.g. 30 min) can
  exist with or without "done". Whether 30 of a 60-minute target counts as
  streak success is a **future streak policy**, deliberately not decided
  (D5). The data must allow any policy: completion flag, value, and the target
  and minimum that applied (below).
- **Notes are orthogonal.** A note can exist on any state, including upcoming
  and omitted, without changing that state.
- **Credit (D8):** completion stores the local date it happened; the key keeps
  the original date. Monday's occurrence moved to Friday and done Friday:
  original date Monday, completion date Friday.
- **Target versioning — Proposed:** a tracked behavior's target, minimum, unit
  and identity are resolved **as they applied on the occurrence's original
  date** — not when the outcome is recorded. This must work for omitted
  occurrences, which have no stored data. Requires the behavior itself to keep
  its history of targets (representation per option).
- **Cancellation vs deletion.** Cancellation is a fact kept about one
  occurrence. Permanent deletion (a whole series with its history, or a
  privacy erase) removes data under its own retention rules.

---

## 6. Current state, undo, and what history can answer

- **Confirmed (D7):** occurrence data holds current state only.
- **This is not a historical daily snapshot.** The data answers "what does the
  corrected record say now", not "what did the app believe last Tuesday".
  Revisions (§7) keep past *expectations* reproducible; they do not record
  what the user saw at the time. Intentional; a full event log would be a
  separate proposal.
- **Accepted limit:** "marked done then undone" is not recoverable.

**Conflict-safe undo — Proposed.**
- Undo reverts only the fields its command changed, and only if each still
  holds the value that command wrote. If any of them changed since (e.g. a
  note was edited after a completion), undo is refused with a message, never
  partially applied and never overwriting the newer change.
- Fields the command did not touch are never altered by undo (adding a note
  after "done" survives undoing "done").
- Undoing a series edit is refused if a later series edit exists, or if
  occurrence data written afterwards depends on it.
- If undo leaves an occurrence with no overrides, outcome, value or note, it is
  indistinguishable from a never-touched occurrence (Option B removes its
  stored data; Option A keeps an unmarked row — either is acceptable).
- Single-step and immediate, matching `AppUndoToast`.

---

## 7. Historical meaning

- **Confirmed (D4a):** past dates resolve against the revision that applied on
  that date — rule, defaults and tracked-behavior target.
- **Requirement:** past expectations remain reproducible after any series
  edit. Changing a daily series to weekly after three months keeps those
  three months' expected/omitted/done exactly as they were.
- **Proposed:** a series edit applied today does not alter today's occurrence
  if it already has an outcome; otherwise it applies.
- **Proposed:** "this and following" started from a past occurrence takes
  effect from today, not from that past date — anything else would be a
  historical correction (D4b).

**Time zones and history — Proposed.**
- Once an occurrence's omission deadline (D9) has passed, its date, omitted
  state and credit are fixed in the time zone that applied then. Travelling
  later never turns an omitted occurrence back into upcoming, nor moves a past
  occurrence to another date.
- Future occurrences float (D2). How the zone per past day is known is per
  option (e.g. recorded once per day of use).

---

## 8. Edit scopes

| Scope | Behaviour |
|---|---|
| **This occurrence** | Overrides on that occurrence (§4). |
| **This and following** | New revision from the occurrence's date (or today, if that date is past — §7). Series id and occurrence keys unchanged. |
| **All occurrences** | New revision from today (D10). Past context untouched. |
| **Delete this occurrence** | Cancels it (§5). |
| **Delete series** | Ends it from today. Past occurrence data kept unless the user chooses permanent deletion. |

Still open:
1. Interval rules (every other week) — **Proposed:** cadence stays anchored
   to the series start, not the revision start.
2. How a remaining occurrence count transfers to a new revision.
3. A moved occurrence with a note, under a new time revision — **Proposed:**
   keeps its moved time (overridden), note intact.

---

## 9. Data on dates no longer expected

When a revision stops expecting a future date (e.g. weekday change), existing
occurrence data on that date:

| Data present | Proposed rule |
|---|---|
| Done, value, skip, or note | **Kept and shown** on its date, marked as outside the current plan. Not counted as expected. Done/value still recorded as facts. |
| Plan overrides only (e.g. moved, nothing else) | Dropped from the plan, kept in the series edit's undo data. |
| Cancellation only | Dropped (nothing left to cancel), kept in undo data. |

Undoing that series edit restores all of it.

---

## 10. Resolving a date range

For a range, the resolver:

1. Generates expected occurrence keys from the revisions applying in the
   range, widened by one day each side (for items crossing midnight).
2. Collects occurrence data whose key date is in that widened range, **or**
   whose current scheduled interval overlaps the range (moved in from
   elsewhere).
3. **Merges by key** — each key appears at most once. Data enriches its
   expected occurrence; it never adds a second one.
4. Applies overrides, then keeps only items whose current interval overlaps
   the range (moved-out items disappear from their original day).
5. Removes cancelled items (unless a view explicitly asks for them).
6. Adds data for keys no longer expected (§9) that has content.
7. Adds one-off tasks in the range.

Queries are always bounded; open-ended lookups ("next occurrence") have an
explicit expansion limit.

---

## 11. Time

- **Confirmed (D2):** future occurrences use floating local time.
- **Proposed — spring-forward gap** (02:30 doesn't exist): starts at the first
  valid time after the gap.
- **Proposed — fall-back repeat** (01:30 twice): the earlier one.
- **Proposed — duration** is elapsed minutes.
- **Proposed — all-day items** are a date range, not start + minutes. Not
  built; the model must not prevent them.

---

## 12. Commands and failure

- **Proposed:** each user action is one command with a persisted id; retrying
  the same id never applies twice.
- **Proposed:** each series and occurrence data item has a version; a command
  states the version it expects and is rejected if it changed (prevents two
  callers — UI and Siri — overwriting each other).
- **Proposed:** a write that saves but whose notification or calendar side
  effect fails is retried by reconciliation, never by repeating the write.
- **Known limit:** reminders are scheduled for a bounded window, refreshed at
  launch and after writes; they stop if the app is unopened beyond it.
  Addressed separately.

---

## 13. Acceptance scenarios

**Identity & resolution**
- **S1** Move Monday's occurrence to Friday → shown Friday only; key stays
  Monday's.
- **S2** 23:00–01:00 occurrence → appears on both days, once each.
- **S3** Notification tap for a moved occurrence opens that occurrence.
- **S4** Export, wipe, restore → every key, outcome, value, note, override and
  completion date identical.
- **S5** Note on Thursday's 07:00 occurrence; series changed to 08:00 → same
  occurrence, at 08:00, note intact.
- **S6** Same as S5 with Thursday cancelled, then with Thursday done → still
  cancelled / still done, same key.
- **S7** Series Mon/Wed/Fri → Tue/Thu from today; a future Monday had a note →
  note kept and shown on Monday, marked outside the plan; Tuesday is a new,
  separate occurrence.
- **S8** Note-only occurrence → resolver returns one item, not two.
- **S9** Cancelled occurrence → not returned, including via the "moved in"
  path.

**Inheritance (D1)**
- **S10** Thursday title overridden; series title changed → Thursday keeps its
  title.
- **S11** Thursday description cleared; series description changed → Thursday
  stays empty.

**Outcomes & streak foundation (D3, D5, D8, D9)**
- **S12** One week: Mon done; Tue 30 min recorded, not marked done; Wed
  skipped; Thu cancelled; Fri untouched and past deadline → stored facts:
  done / value 30 not done / skipped / cancelled / omitted. Expected = 4
  (Thu excluded). No success count asserted.
- **S13** Note on Friday (omitted) → still omitted, note stored.
- **S14** Monday moved to Friday, done Friday → original date Monday,
  completion date Friday.
- **S15** 23:00–01:00, no outcome → upcoming at 00:30, omitted at 01:00.

**Undo (D6, D7)**
- **S16** Done → undo → back to upcoming/omitted; counts as before.
- **S17** Value 30 → changed to 45 → undo → 30.
- **S18** Done → note added → undo "done" → no longer done; note kept (undo
  touches only the field it changed, which is still unchanged).
- **S19** Done → done edited again by Siri → undo the first → refused.
- **S20** Series edit → undo → previous revision and §9 data restored in one
  step; refused if a later series edit exists.

**Historical meaning (D4a, D10)**
- **S21** Daily for 3 months, mostly untouched → weekly → past
  expected/omitted/done unchanged.
- **S22** Behavior target 60 on Monday, changed to 30 Tuesday, Monday marked
  done Wednesday → Monday judged against 60.
- **S23** Rename series "Run" → "Morning run" (all occurrences) → past
  occurrences still titled "Run".
- **S24** Travel east after an omitted day → it stays omitted, same date.

**Edit scopes**
- **S25** Every-other-week series, time changed from week 5 → cadence
  unchanged.

**Time (D2)**
- **S26** 02:30 on a spring-forward day → first valid time after the gap.
- **S27** Travel → future 07:00 occurrences show at 07:00 local.

**Failure & concurrency**
- **S28** Command retried after a timeout → applied once.
- **S29** UI and Siri write the same occurrence with the same expected version
  → one succeeds, the other is rejected; never two data items.

**Migration (§14)**
- **S30** Future pending row whose title differs from the series default →
  title overridden after migration.
- **S31** Future pending row equal to defaults → inherited; original row kept
  in the migration backup.
- **S32** Past row → every field kept as it was, regardless of current
  defaults.
- **S33** Migration interrupted → next launch resumes or restores; no row
  lost, no duplicate.

---

## 14. Migration

**The ambiguity, stated plainly.** Existing data cannot distinguish a field a
user deliberately set to the same value as the series default from one simply
copied from the default. No comparison recovers that intent.

**Chosen policy — Proposed.**
- **Past rows** (before migration day): kept exactly as they are, every field,
  as historical context. Nothing inherits current defaults (D4a).
- **Future rows:** fields equal to the current series default become
  inherited; differing fields become overridden; outcome, value and note
  always carry over.
- **Why this is acceptable:** today's series edits already regenerate future
  pending rows from the template (`_deleteFutureInstancesForRealign`,
  `_deleteUntouchedFutureInstances` in `task_providers.dart`), so a future row
  that merely equals the default was never protected from series edits.
  Treating it as inherited keeps today's behavior, while differing fields gain
  protection they did not have.
- **Original rows are kept** in a full migration backup.

**Existing defect this exposes.** Today, an "all future" time/duration edit
or a rule change deletes future pending rows including any notes on them —
contrary to D1. Not fixed here; migration must not reproduce it.

**Mechanics.** No inference of "untouched". Steps are resumable, validated
before the new model is switched on, and have a tested restore path. The
backup must include every entity — today's export omits templates, tracked
behaviors and sections.

---

## 15. Out of scope

Monthly/yearly rules, `.ics` import (including how re-imports apply updates),
the AI/tool-facing data format, a full event log, moving zones onto the series
engine, two-way calendar sync, and streaks themselves. Each is a separate
proposal building on this contract.
