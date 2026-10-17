# Work order: "Connect to Claude" (local AI access on the Mac app)

Written 2026-10-10 for follow-up agents. Self-contained: read this file, then
the files it names. Do the phases in order, one per session, and stop at each
**Stop** for review. Phase 0 is a gate: nothing after it starts until its
results are recorded here and the user has answered the open decisions.

## Goal

A person who has never heard of MCP can let Claude (the desktop app) read their
Amble plan and, if they allow it, add and move tasks. For example: *"Find me
four one-hour slots this week"*, then *"Add them as Deep work"*.

**Setup should take three clicks, with no copying, no config files and no
terminal:** Amble → Settings → Claude → **Connect to Claude**, then **Install**
in Claude's own dialog, then the first question.

## Reassessment: what changed from the first sketch, and why

The earlier sketch (chat, 2026-10-10) had the user turn on a switch, copy an
address and a secret token, and paste them into Claude, with Amble open the
whole time. Each of those steps loses non-technical users:

| Friction in the first sketch | Replacement in this plan |
| --- | --- |
| Copy an address and token into an assistant | Amble builds a one-click **Claude extension file** (`.mcpb`, "MCP Bundle", formerly `.dxt`) with the secret already inside and hands it to Claude Desktop, which shows its own Install dialog. The user never sees a token. |
| Edit Claude Desktop's config file | Not needed: Claude installs and launches the extension itself. |
| Amble must be open | The extension's small helper **starts Amble in the background** when Claude needs it. |
| Technical words (MCP, server, localhost, token) | The UI says "Claude", "see your plan", "add and move tasks", "Disconnect". The technical details sit behind an **Advanced** disclosure for Claude Code / Cursor users. |
| Unclear what the AI did | An **activity list** in Settings, plus an "Added by Claude · Undo" toast when the window is visible. |
| Permission all-or-nothing | Two plain choices: **See my plan** (default) or **See and update my plan**. |

The architecture itself is unchanged in principle: **the server lives inside the
running Amble app**, because Hive is a single-writer store. A second process
opening the same boxes would hold a stale cache and compete on writes; the
iOS App Intents work hit the same constraint and solved it with one shared
engine (see `docs/IOS_APP_INTENTS.md`). The helper is a dumb pipe and never
touches data.

## Architecture

```
Claude Desktop
  └─ launches (stdio) ─► amble-mcp helper  (inside the .mcpb, ~a few hundred lines)
                          • reads port + secret from its env (set by the bundle)
                          • if Amble is not answering: `open -g -j -b <bundle id>`, retry ~10 s
                          └─ HTTP POST ─► 127.0.0.1:<port>/mcp  (inside Amble, while running)
                                           • rejects: wrong secret, any Origin header,
                                             Host not 127.0.0.1/localhost, feature off
                                           • MCP JSON-RPC: initialize, tools/list, tools/call, ping
                                           └─ tool handlers ─► existing providers/repositories
                                                               (TaskList.createTask, rescheduleTask,
                                                                zone list, external events)
```

- **In-app server:** `dart:io` `HttpServer` bound to the loopback address only.
  No new Dart dependency. The MCP subset is small enough to implement by hand.
- **Helper:** a Swift command-line tool, built by the macOS Xcode project. The
  bundle carries a copy. No Dart, no Node, no Python runtime for the user to
  install.
- **Bundle generation:** native Swift on the Mac side. It writes `manifest.json`
  plus the helper into a temp folder and zips it with
  `NSFileCoordinator(.forUploading)`, so there is no zip dependency. It then
  opens the `.mcpb` with Claude Desktop via `NSWorkspace`.
- **Advanced path:** the same HTTP endpoint is directly usable by clients that
  accept a local URL (Claude Code: `claude mcp add --transport http …`). Show
  this only under **Advanced**.

## Rules (from CLAUDE.md files; violating these is a stop-and-ask)

- Read, in order: `CLAUDE.md`, `docs/CONSTITUTION.md`, `docs/SCOPE.md`,
  `docs/ARCHITECTURE.md`, `docs/ERROR_LOG.md`, `docs/DECISIONS.md`. For UI also
  `docs/COMPONENT_GUIDE.md` → `docs/DESIGN_SYSTEM.md`.
- **Memento** (project "Rios"): preview context for the phase before coding; submit
  an agent change report after. Subjects: Timeline, Calendar, Wide layout, or
  propose an "AI access" subject. The repo wins over Memento on conflict.
- **No Hive outside `shared/repositories/`.** Tool handlers call the same
  providers the UI calls, so validation, notifications and live UI updates
  come for free. Never write to boxes directly.
- **No new dependencies** (Dart or native) without a stop-and-ask case. None are
  planned; if one turns out to be needed, stop and write a one-paragraph case.
- **No `Material*`/`Cupertino*` imports in `features/`.** Use the adaptive widgets
  in `core/`.
- **Check real APIs before use.** That covers the MCP spec version, the
  Streamable HTTP rules, the MCPB manifest format, and Claude Desktop's bundle
  id and file handling. Read the current specs
  (modelcontextprotocol.io; the MCPB repo) at implementation time and record
  the versions you used in `docs/DECISIONS.md`. Do not code from memory or
  from this file's examples.
- `dart format` **only the files you changed, by name**. Never a whole directory
  (2026-10-10 incident: 34 unrelated files reformatted). No broad
  `git checkout`/`reset`: other uncommitted work lives in this tree.
- Before reporting done, run `flutter analyze` (baseline **15 issues**, must not
  grow) and `flutter test` (baseline **19 failures in 8 files**:
  `app_swipe_actions`, `app_view_transition`, `spatial_label_icon_alignment`,
  `timeline_capsule_preview`, `zone_grid_edit_screen_merge`,
  `zone_grid_screen`, `floating_nav_pill`, `timeline_nav_consolidation`; no new
  file may fail). For native changes, also run `flutter build macos --debug`.
- Write user-facing copy in plain words. Never show "MCP", "server",
  "localhost", "port", "token" or "JSON" outside **Advanced**.
- Log each session in `docs/PROGRESS_LOG.md`, and add to `DECISIONS.md` and
  `ERROR_LOG.md` as they apply.

## Open decisions (the user answers before Phase 1)

| # | Decision | Recommendation |
| --- | --- | --- |
| D1 | Scope: approving this plan moves "MCP server" in `docs/SCOPE.md` from *deferred* to *in scope (macOS, Claude Desktop first)*. | Approve; update SCOPE.md in Phase 1. |
| D2 | Mac distribution: Developer ID (outside the App Store) or Mac App Store. This affects signing, notarisation and sandbox rules for the helper. | Developer ID for the first release; revisit MAS later. |
| D3 | Default permission when connecting. | **See my plan** (read only). Updating is one tap away. |
| D4 | Whether writes need an extra confirmation inside Amble. | No. Claude already asks before each tool call by default; Amble shows an Undo toast and the activity list instead. |
| D5 | Real bundle identifier. `macos/Runner/Configs/AppInfo.xcconfig` still says `com.example.amble`. The helper launches Amble by bundle id. | Set the real id before Phase 3. |

---

## Phase 0: Spike on a real Mac (throwaway branch, no product code)

**Goal:** prove the four assumptions this plan rests on. Record results in the
"Spike results" section at the bottom of this file.

1. **One-click install.** Hand-build a minimal `.mcpb` (manifest + a trivial
   "hello" binary server). Confirm that double-clicking it, or
   `NSWorkspace.open` from a **sandboxed** app, opens Claude Desktop's install
   dialog, and that the tool appears in Claude.
2. **Secret in the bundle.** Confirm the manifest can pass fixed environment
   values (port, secret) to the server without asking the user anything.
3. **Helper runs.** A Developer-ID-signed Swift CLI inside the bundle launches
   under Gatekeeper when Claude starts it. Note any quarantine or notarisation
   requirement.
4. **Loopback from the sandbox.** A sandboxed Flutter app with
   `com.apple.security.network.server` accepts connections on 127.0.0.1 from
   the helper.
5. **Background launch.** `open -g -j -b <bundle id>` from the helper starts
   Amble without stealing focus, and the server is reachable within 10 s.

**Decision rule:**
- If 1 or 2 fails, fall back to a guided manual setup: an Amble screen with
  **Copy setup** and **Open Claude's settings** plus three illustrated steps.
  Write up the fallback UX and stop for the user.
- If 3 fails, record what signing or notarisation needs.
- If 4 fails, try a Unix domain socket inside an app-group container instead,
  and record the result.

**Stop.**

## Phase 1: Pure core — free time and tool logic (no networking, no UI)

**Files (new):**
- `lib/shared/services/availability.dart`
- `lib/shared/services/assistant_tools.dart`
- tests under `test/shared/services/`

1. `computeFreeWindows({tasks, externalEvents, zones, from, to, dayStart,
   dayEnd, minMinutes})`: a pure function. Busy time is tasks (any status except
   `skipped`) plus imported calendar events. Each window reports which zone(s)
   it falls in. Day bounds come from a setting or default (agent: find whether
   the Timeline already has a visible-hours range and reuse it). Times are local.
2. A tool layer that is independent of transport. Each tool has a name, an
   LLM-facing description, a JSON input schema and a handler returning a
   result (structured JSON plus a one-line human summary). v1 tools:
   - **Read:**
     - `get_day(date)`
     - `list_tasks(from, to, important_only?)`
     - `get_availability(from, to, min_minutes, zone_name?)`
     - `list_zones()`
     - `list_categories()`
   - **Write** (only when permission is "update"):
     - `add_task(title, start, duration_minutes, category_name?, important?)` via `TaskList.createTask`
     - `move_task(task_id, new_start)` via `TaskList.rescheduleTask`
   - **No delete in v1.** No series or recurrence edits, no zone edits.
3. Errors are friendly and specific: unknown task id; time in the past; trial
   expired (`createTask` throws `TrialExpiredException`); permission is
   read-only; ambiguous category name (return the options).
4. Writes are recorded in an in-memory `AssistantActivity` list: time, tool,
   summary, and the undo action. It is session-only in v1; persisting it is a
   later decision.
5. Update `docs/SCOPE.md` per D1.

**Tests:**
- Free windows: empty day, back-to-back tasks, an overlapping event, a window
  shorter than `minMinutes`, crossing midnight, a zone tag, and the
  "four one-hour slots this week" case.
- Every tool's happy path and error paths.
- Write tools refused when read-only.

**Acceptance:** analyze and test at baseline, plus the new tests. **Stop.**

## Phase 2: In-app local endpoint (Dart, behind a setting)

**Files (new):** `lib/shared/services/assistant_server.dart` plus a
controller provider. **Also:** add `com.apple.security.network.server` to
`macos/Runner/Release.entitlements`.

1. Use `HttpServer.bind(InternetAddress.loopbackIPv4, port)`. Persist the port
   in preferences (new `PreferenceKeys` entries). If the saved port is busy,
   pick a free one and mark the connection "needs reconnect".
2. Implement the MCP Streamable HTTP subset, checked against the current spec:
   `initialize`, `notifications/initialized`, `ping`, `tools/list`,
   `tools/call`. Reply with `application/json`; no SSE stream in v1 if the spec
   allows it.
3. **Security** (all mandatory, all tested):
   - Bind to loopback only.
   - Require `Authorization: Bearer <secret>`, compared in constant time.
   - Reject any request with an `Origin` header.
   - Reject a `Host` that is not `127.0.0.1:<port>` or `localhost:<port>`.
   - Reject requests when the feature is off.
   - Generate the secret with `Random.secure`, store it via the preferences
     repository, and rotate it on Disconnect.
4. The server starts only on macOS, only when connected, and stops on
   Disconnect or app exit.
5. Add `tool/assistant_smoke.dart`, a script that hits a running endpoint with
   initialize → tools/list → `get_availability`, so the manual check is a
   command, not prose.

**Tests:** a real `HttpServer` on an ephemeral port inside `flutter test`. Cover:
auth missing, auth wrong, an `Origin` present, a bad `Host`, feature off,
`tools/list` shape, and a write while read-only.

**Acceptance:** baseline plus the new tests, and `flutter build macos --debug`
succeeds. **Stop.**

**Status 2026-10-10:** Phases 1–4 done; see DECISIONS.md. D5 = `com.panta.panta`. Phase 3 changed the helper from a Swift CLI to a Node script run by Claude's built-in Node (no signing or Gatekeeper for the helper).

## Phase 3: Helper and one-click bundle (native macOS)

**Files:**
- `macos/AmbleMcpHelper/` (Swift CLI target added to the Xcode project)
- `macos/Runner/ClaudeConnectBridge.swift`
- `macos/Runner/MainFlutterWindow.swift`
- `macos/Runner.xcodeproj/project.pbxproj`
- a Dart service for the channel `com.amble/claude_connect`

1. **Helper:**
   - Reads newline-delimited JSON-RPC on stdin and POSTs each message to the
     local endpoint with the secret.
   - Writes responses to stdout and logs only to stderr.
   - If the connection is refused, launches Amble hidden and retries with
     backoff for up to about 10 s.
   - If Amble is still unreachable, returns a JSON-RPC error with plain
     wording: "Amble isn't running. Open Amble and try again."
2. **Bridge methods:**
   - `isClaudeInstalled` (Claude Desktop by bundle id, verified in Phase 0).
   - `connect(port, secret)`: writes the manifest and helper into a temp
     folder, zips it to `Amble.mcpb`, opens it with Claude. Returns opened /
     not-installed / failed.
   - `openClaudeDownloadPage`.
3. The manifest's name is "Amble", with a plain description, an icon, and the
   tool list mirrored from Phase 1 for Claude's install screen.

**Verification:**
- `flutter build macos --debug` succeeds.
- The helper has its own minimal Swift test target, or a scripted
  stdin/stdout round-trip against `tool/assistant_smoke.dart`'s server.
- A manual end-to-end run on a real Mac with Claude Desktop, recorded in
  PROGRESS_LOG with what was observed.

**Stop.**

## Phase 4: Settings › Claude (the non-technical UX)

**Files (new):** `lib/features/settings/claude_settings_screen.dart` plus an
entry row in the Settings list. Desktop (wide layout / macOS) only, like the
Week task style panel.

**Screen states and copy** (final wording can be tuned; keep it this plain):

1. **Not connected**
   - Title: "Claude"
   - Body: "Let Claude see your plan and answer questions like 'Find me four
     one-hour slots this week'."
   - Choice:
     - **See my plan** (default): "Claude can read your tasks, zones and free
       time."
     - **See and update my plan**: "Claude can also add and move tasks. It
       can't delete anything."
   - Button: **Connect to Claude**.
2. **Claude not installed**
   - Body: "Claude's desktop app is needed."
   - Buttons: **Get Claude**, then **I've installed it**.
3. **Waiting**
   - Body: "Claude is open. Click **Install** in its window to finish."
   - After the first successful call from the helper, the screen moves on by
     itself.
4. **Connected**
   - Status: "Connected to Claude · See my plan" with **Change**.
   - "Try asking" chips, tap to copy:
     - "Find me four one-hour slots this week"
     - "What's important today?"
     - "Move my 3pm to the first free hour tomorrow"
   - **Activity**: "Today 14:02 · Claude added 'Deep work', Tue 10:00 ·
     Undo".
   - Button: **Disconnect**, which rotates the secret and stops the server.
     Claude's copy of the extension stops working.
5. **Needs reconnect** (port changed, secret rotated, Amble reinstalled)
   - Body: "Claude lost its connection." Button: **Reconnect**.
6. **Advanced** (collapsed)
   - Local address and a **Copy for Claude Code** snippet. This is the only
     place technical words appear.

**Also:**
- When the window is visible, a write from Claude shows the existing
  `AppUndoToast`: "Claude added 'Deep work' · Undo".
- Use existing components only: settings panels, `AppButton`,
  `AppSelectableChip`, the undo toast. No new tokens.

**Tests:**
- Each state renders.
- Connect calls the bridge, using a fake bridge.
- Disconnect rotates the secret and stops the server.
- The permission choice is persisted and enforced (a write while read-only is
  refused).
- The Undo toast appears after an assistant write.
- The screen is hidden on phone width.

**Stop.**

## Phase 5: Hardening and handover

**First live run (a person at the Mac, about five minutes):**
1. `flutter run -d macos` (bundle id `com.panta.panta`; this is a fresh container, so the app starts empty: add a task or two).
2. Settings › Claude › choose **See and update my plan** › **Connect to Claude**.
3. In Claude's window: **Install**. Amble should move from "Almost there" to "Connected" on its own, and `~/Downloads/Amble.mcpb` should disappear.
4. In a new Claude chat: "Find me four one-hour slots this week", then "Add the first one as Deep work". Expect Claude's own permission prompt, then an "Claude: Added … · Undo" toast in Amble and a row under "What Claude has done".
5. Quit Amble, ask Claude "What's on today?". Amble should start in the background and answer.
6. Settings › Claude › **Disconnect**, then ask Claude again. Expect "Reconnect Claude in Amble".
If a step fails, `tool/assistant_smoke.dart --port <port> --secret <secret>` (port and secret are under **Advanced**) separates "Amble's endpoint" from "Claude's extension".


1. Run the whole flow end to end on a clean macOS user account:
   - install
   - ask the four-slots question
   - add the slots
   - undo one
   - disconnect
   - confirm that Claude now fails politely

   Record the results in PROGRESS_LOG.
2. Update `docs/ARCHITECTURE.md` (the "Assistant access" section and the
   diagram), `docs/CONSTITUTION.md` (read/write boundary for assistants:
   create and move only; never delete; never touch series or zones), and
   `docs/DECISIONS.md` (spec versions used, D1–D5 answers).
3. List follow-ups without building them:
   - persistent activity log
   - menu-bar "keep running"
   - Windows/Linux helpers
   - phone and web assistants (these need the deferred cloud backend; see
     SCOPE.md)

## Out of scope (do not build)

- **Phone, Claude web/mobile, ChatGPT and other remote-only assistants.** They
  can't reach a local app; they need a hosted endpoint with accounts and sync.
- **Delete tools, zone edits, and category creation** by the assistant.
  (Series/recurrence edits were added on 2026-10-10 at the user's request:
  `edit_task`; see DECISIONS.md.)
- **Windows/Linux helpers.** The design stays portable (loopback HTTP), but
  only macOS ships in this order.

## Risks to watch

- **Claude Desktop's bundle handling or manifest format may have changed.**
  Phase 0 exists for this; re-read the spec at each phase.
- **Gatekeeper/notarisation of the helper inside the bundle** (Phase 0 step 3,
  depends on D2).
- **Trial gating.** `createTask` throws when the trial has ended; the tool must
  say so plainly rather than fail.
- **A large free-time range.** Cap `get_availability` at 31 days and say so in
  its description.

---

## Spike results (fill in during Phase 0)

| Check | Result | Notes (versions, commands, screenshots path) |
| --- | --- | --- |
| 1 One-click install | **Partly confirmed (static)** | Claude Desktop 2.31226.1 (`com.anthropic.claudefordesktop`) registers `.mcpb` and `.dxt` as "Desktop Extension" document types in its Info.plist. The Install dialog itself was not opened: that needs a person at the Mac. |
| 2 Secret via manifest env | **Supported by spec** | MCPB `manifest_version` 0.3 (MANIFEST.md, updated 2025-12-02): `server.type: "binary"`, `mcp_config.command` / `args` / `env`, with `${__dirname}` substitution; spec examples use literal `env` values. Not yet tried live. |
| 3 Helper under Gatekeeper | **Blocked** | This Mac has only an "Apple Development" identity; the Xcode project signs ad hoc (`CODE_SIGN_IDENTITY = "-"`). Needs a Developer ID certificate (D2) to test distribution. A locally built helper runs without Gatekeeper prompts. |
| 4 Loopback from sandbox | **Deferred to Phase 2** | Verified naturally when the in-app endpoint exists (Release entitlements still lack `network.server`). |
| 5 Background launch | **Deferred to Phase 3** | Needs the helper and the real bundle id (D5). |

**2026-10-10 user answer:** "Execute". Taken as approval of the plan (D1 scope) and of the recommended answers for D2 (Developer ID first), D3 (read-only default) and D4 (no extra in-app confirmation). D5 (real bundle id) is still open and blocks Phase 3 only.
