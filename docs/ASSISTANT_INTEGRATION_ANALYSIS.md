# Siri / Google Assistant integration — analysis (2026-09-19)

Snapshot of what's actually implemented today, captured so later sessions
don't re-derive it from scratch. See `docs/IOS_APP_INTENTS.md` and
`docs/ANDROID_APP_ACTIONS.md` for the original implementation write-ups;
this is a cross-platform summary plus a specific idea evaluated against it.

## What's implemented today

Both platforms are at feature parity — 5 actions, one shared Dart handler
(`AppIntentService.handle` in `lib/core/app_intents/app_intent_service.dart`),
one `MethodChannel("com.amble/app_intents")`.

| Action | Create/Edit/Remove | What it does |
|---|---|---|
| Add Task | Create | Runs quick-capture parser on spoken text; falls back to a plain note if not "confident" |
| Add Note | Create | Captures a note directly |
| Add Zone | Create | Creates a timeline zone (title + start/end), validated against overlap rules |
| Day Summary | Read | Spoken/text summary of today + next 13 days, built from live Hive data |
| Remove Task | Remove | Finds matching task(s) by title, disambiguates if multiple, deletes (recurrence-aware) |

**No Edit action exists** — nothing lets Siri/Assistant modify an existing
task's time, title, category, or completion state. Only create, read, delete.

### Platform mechanics

- **iOS**: native `AppIntents` framework (iOS 16+), no Intents extension —
  everything runs in the main Runner target via a shared headless
  `FlutterEngine` (`AmbleFlutterHost.swift`). Disambiguation (e.g. picking
  which task to remove) is handled natively by Apple's `AppEntity`/
  `EntityStringQuery` — no custom UI needed.
- **Android**: static shortcuts (`shortcuts.xml`) + explicit `Intent`s +
  a hand-rolled `AlertDialog` chooser (`AssistantDialogs.kt`), since Android
  has no OS-level disambiguation equivalent. Optional offline TTS speaks
  the result.
- **"Phrases"**: the fixed sentence templates the OS matches voice input
  against, with parameter slots. iOS: `AmbleShortcutsProvider` in
  `AmbleShortcuts.swift` (e.g. "Add a task in Amble", "Remove `$task` in
  Amble"). Android: `queryPatterns` in `assistant_queries.xml` (e.g. "add a
  task `$text`"). Both are static, declared at build time — neither platform
  does open-ended NL parsing at the OS level.
- **"Capabilities"** (Android term): the declared contract bundling phrase
  patterns + the intent fired, in `shortcuts.xml`. iOS's equivalent is the
  `AppIntent` struct itself.

### Testing status

- 24 Dart tests (iOS-related) + 26 Dart tests (Android-related) pass —
  but these only exercise shared Dart logic, not native glue.
- **Neither platform has ever been tested against a real Siri phrase or
  real Google Assistant phrase.** Android verified via direct emulator
  intent-fulfillment (bypassing real Assistant voice recognition); iOS
  blocked at the time by an unrelated Xcode/SDK mismatch.
- No native XCTest/instrumented-test coverage on either side.
- Source: `docs/DECISIONS.md` (2026-09-09 entries), `docs/PROGRESS_LOG.md`
  (2026-09-09 entries).

### Known regression risk (unaddressed as of this writing)

The `applicationId` rename (`com.example.amble` → `com.panta.panta`, in
`android/app/build.gradle.kts`) is not reflected in Android's assistant
wiring: `shortcuts.xml`'s `targetPackage` and `AssistantActions.kt`'s
`PREFIX` constant still hardcode `com.example.amble`. Since Android
resolves shortcut/capability intents against the actual installed
application ID, this will likely break Android App Actions on any build
using the new applicationId. Not yet logged as a decision or fixed.

### What else the platforms support (not built, just available)

- Edit existing task (reschedule, rename, mark complete) — same pattern
  as existing actions, reusing `TaskList` methods already in the Dart layer.
- Query intents beyond Day Summary (e.g. "What's my next task?").
- Siri Spotlight/widget surfacing of `ScheduledTaskEntity` (already an
  `AppEntity` — no extra work needed for basic Spotlight visibility).
- Interactive Snippets (iOS 16+) — a rich visual card Siri can show after
  fulfilling an intent, instead of just speaking a result.

### Can Siri narrate something longer based on live Amble data?

Yes, in principle — `ReadDaySummaryIntent` already does this today: a
non-scripted spoken response assembled per-request from live Hive data
(`buildIntentDaySummary` in `intent_task_queries.dart`). Constraints on
going longer: Apple's guidelines discourage multi-paragraph spoken
responses (feels bad as TTS); no native iOS test has ever confirmed how a
longer summary actually sounds spoken, since real Siri phrases have never
been tested end-to-end. For a genuinely long narration (e.g., "walk me
through my whole week"), a **Snippet** (visual card) alongside a shorter
spoken summary is the better-fit pattern than a long spoken monologue.

---

## Idea evaluated: multi-turn voice "log progress" flow

**The idea, as posed:** a screen (not built, not requested — this section
is analysis only) for bulk end-of-day completion logging — one screen,
checkboxes per task, per-task note + completion status or % complete,
no per-task sheet-opening. Question raised alongside it: could Siri/Google
Assistant drive this as a multi-turn voice conversation — "Let's log
progress in Amble" → assistant reads each unchecked task aloud ("Walking,
tracked — how did you do today?") → user answers ("completed, 20%" or
"2km") → assistant asks "any comments?" → user answers or declines →
assistant moves to the next task, and so on?

**Verdict: not currently buildable as a true multi-turn voice loop, on
either platform, with the frameworks this app already uses.**

Reasoning:

1. **Apple's `AppIntents` framework is fundamentally single-turn.** An
   `AppIntent.perform()` runs once per invocation, returns one result, and
   the interaction ends. There is no supported mechanism for it to
   "pause," ask a follow-up question, wait for a spoken answer, and
   continue a loop over N tasks — Siri's App Intents model isn't built for
   held conversational state across multiple back-and-forth turns per
   invocation. The pattern that *is* supported is a `DisambiguationIntent`
   or a single set of `@Parameter`s Siri asks about one at a time — a
   fixed, known-in-advance set of blanks to fill for *one* action, not an
   open-ended loop over a dynamically-sized task list.
2. **Google Assistant's classic App Actions (what this app uses) has the
   same ceiling.** True multi-turn dialog management on Android is what
   Conversational Actions / Actions on Google used to provide, but that
   platform was deprecated by Google — it no longer exists as a target.
   The successor path (Gemini treating installed apps' declared
   AppFunctions as tools) is closer to genuinely conversational, but per
   `docs/DECISIONS.md`'s 2026-09-09 entry, that requires Android 16+ and
   was in restricted preview when this app's Assistant integration was
   built — the reason classic App Actions was chosen instead. That
   constraint may have loosened since; worth re-checking if this
   direction becomes a real priority.
3. **What *is* realistically buildable today, on the existing
   architecture:** a single voice command ("Log progress in Amble") that
   *opens the bulk-completion screen* (the UI half of the ask) rather than
   conducting the loop by voice. That's a normal, well-supported App
   Intent — same shape as the existing 5 actions, just one more entry that
   deep-links to a screen instead of mutating data directly. The
   conversational, one-task-at-a-time voice walkthrough would need to
   happen *inside the app's own UI* (e.g., a guided on-screen flow with
   text-to-speech read-aloud and the device's built-in dictation for
   input), not through Siri/Assistant's own intent-invocation model. That
   would be building conversational UX yourself on top of standard
   platform speech APIs, not something Siri/App Actions grants for free.

**Bottom line:** the emotionally satisfying version of this ("just talk to
Siri and log your whole day hands-free, end to end") isn't something
either platform's assistant framework directly supports here, given a
single-shot `perform()`/`Intent` model. The buildable version is: voice
opens the screen; the screen itself could offer a hands-free/read-aloud
mode if that's wanted, built with the app's own logic rather than the
assistant frameworks.
