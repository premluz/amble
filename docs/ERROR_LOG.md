# Amble — Error Log

Append-only. One entry per real gotcha (not every typo) — the point is to catch recurring platform quirks before they cost time twice, especially since Flutter/Dart is newer terrain than TS.

Format per entry:

```
## [YYYY-MM-DD] Short title
**Symptom:**
**Cause:**
**Fix:**
**Prevent next time:**
```

---

## [2026-08-20] hive_generator compatibility conflict

**Symptom:** `flutter pub add --dev hive_generator` fails version solving: `riverpod_generator >=3.0.0 depends on source_gen >=3.0.0 <5.0.0` while `hive_generator >=1.0.1 depends on source_gen ^1.0.0` (and `<1.0.1` predates null safety). Classic `hive`/`hive_flutter` + `hive_generator` cannot coexist with our pinned `riverpod_generator ^4.0.8` in one pubspec.
**Cause:** Dart resolves one `analyzer`/`source_gen` version for the whole pubspec's dev_dependencies. `hive_generator` is unmaintained and stuck on `source_gen ^1.0.0`. Switching to `hive_ce_generator` (the maintained fork) fixes the `source_gen` conflict, but introduces a second, narrower one: `riverpod_generator ^4.0.8` requires `analyzer ^13.0.0`, and no published `hive_ce_generator` version targets `analyzer ^13.x` — the package jumps `^12.0.0` (v1.11.2) straight to `^14.0.0` (v1.11.3), skipping 13 entirely. Downgrading `riverpod_generator` to match `analyzer ^12.0.0` (v4.0.4) cascades into needing an older `riverpod_annotation` (4.0.3), which in turn is incompatible with our pinned `flutter_riverpod ^3.4.2` — not a viable fix without touching Riverpod itself, which is out of scope.
**Fix:** Replaced `hive` / `hive_flutter` with `hive_ce ^2.16.0` / `hive_ce_flutter ^2.3.4` (drop-in API-compatible fork, same `@HiveType`/`@HiveField` annotations). Added `hive_ce_generator: 1.11.2` (dev) pinned exactly, plus a `dependency_overrides: analyzer: ^13.0.0` to bridge the one-version caret gap — `hive_ce_generator 1.11.2` declares `analyzer ^12.0.0` but analyzer's generator-facing API is stable across this adjacent bump, confirmed by a clean `flutter pub get`, `dart run build_runner build`, `flutter analyze`, and `flutter test` (all green). `build_runner` also needed a version compatible with the overridden analyzer range: left at `^2.16.0` since the override makes the resolved analyzer 13.3.0, which build_runner 2.16.0 already accepts (`>=13.3.0 <15.0.0`).
**Working version combo:** `hive_ce: ^2.16.0`, `hive_ce_flutter: ^2.3.4`, `hive_ce_generator: 1.11.2` (exact pin — do not loosen to `^1.11.2`, since `1.11.3` jumps to `analyzer ^14.0.0` and would reopen the gap), `build_runner: ^2.16.0`, `riverpod_generator: ^4.0.8`, `dependency_overrides: { analyzer: ^13.0.0 }`.
**Prevent next time:** Before bumping `riverpod_generator` or `hive_ce_generator` in the future, re-check both packages' declared `analyzer` ranges actually overlap before touching the override — this gap closes/reopens with every release of either package.

## [2026-08-20] `flutter test` hangs indefinitely on real Hive disk I/O triggered from a widget interaction

**Symptom:** A `testWidgets` test that taps a button whose handler eventually calls a Riverpod notifier method that awaits a real `Hive` box write (`box.put`/`saveTask`) hangs forever — no exception, no timeout, just never completes, even with `--reporter expanded` showing the test as "started" and never progressing. Confirmed via repeated isolated bisection (single-test runs, minimal reproductions with no UI at all) that the hang is real, not an artifact of leftover stray processes from earlier interrupted runs (though those *also* independently caused hangs via stale `.lock` files in `.dart_tool/test_hive_*/` — see "Prevent next time" below, a second, compounding gotcha from the same debugging session).
**Cause:** `flutter_test`'s default `AutomatedTestWidgetsFlutterBinding` runs on a synchronous, frame-based pump loop — `pumpAndSettle()` polls for pending *frames*/animations, not arbitrary real-zone `Future`s. Hive's box writes are genuine `dart:io` disk operations completing on the real event loop, not tied to Flutter's frame scheduler. A bare `await tester.tap(...)` / `await tester.pumpAndSettle()` sequence can return before that real I/O (and its `then`/`await` continuation, e.g. a provider's post-save `_refresh()`) has actually resolved — in the worst case the real Future's completion is starved indefinitely inside the test binding's synchronous zone.
**Fix:** Wrap any interaction that triggers real Hive I/O in `WidgetTester.runAsync(() async { ... })`, which forks a real (non-fake-async) zone for its duration. Inside that same `runAsync` block, after the tap and `pumpAndSettle()`, add `await Future<void>.delayed(Duration.zero)` to drain any continuation still queued behind the I/O (e.g. a provider's `_refresh()` call) *before* the block — and the test — returns. Without that trailing drain, the continuation can resolve later, after `tearDown` has already disposed the test's `ProviderContainer`, throwing a `UnmountedRefException`/`Ref` "after test completed" error that looks unrelated to the real cause. See `test/features/task_detail/exit_confirmation_test.dart`'s `_tapAndSettle` helper for the working pattern.
**Prevent next time:** Any new `testWidgets` test that exercises a save/delete/mutate path backed by the real `HiveTaskRepository` (not a fake/mock) needs this `runAsync` + trailing zero-delay-drain pattern — plain `pumpAndSettle()` alone is not sufficient once real disk I/O is involved, even though it works fine for pure-widget-state tests. Separately: never `kill -9` a `flutter test`/`flutter_tester` process mid-run — it leaves stale `.lock` files in `.dart_tool/test_hive_*/` directories that make the *next* `Hive.openBox` call in that directory hang too, compounding the diagnosis. If a test run needs to be aborted, prefer letting it finish or use `TaskStop`/normal signal termination, and if a hang is ever suspected afterward, check for and delete stale `.dart_tool/test_hive_*/**/*.lock` files before re-diagnosing.

## [2026-08-21] `xcrun simctl terminate` right after scheduling a notification made delivery look silently broken

**Symptom:** Scheduled a real `zonedSchedule` notification 90 seconds out on the iOS Simulator, then ran `xcrun simctl terminate <device> <bundle-id>` to background the app (standing in for a real "press the home button"). Waited well past the scheduled time — no banner ever appeared on the home screen, in two separate screenshots taken ~30s apart. Looked exactly like a scheduling bug (wrong time computed, permission not actually granted, `zonedSchedule` silently failing).
**Cause:** `simctl terminate` kills the app's process outright, which is a materially different action from the user backgrounding the app (home button / app-switcher) — it is not confirmed here that this is *always* the cause of a missed simulator notification (Apple doesn't document simulator notification-delivery internals precisely), but relaunching with the exact same code and instead backgrounding via `xcrun simctl launch <device> com.apple.mobilesafari` (launching a different real app, leaving the target app suspended rather than killed) produced a successful, confirmed delivery on the very next attempt. The notification *had* actually fired during the earlier `terminate`-based attempt too, according to `~/Library/Developer/CoreSimulator/Devices/<udid>/data/Library/UserNotifications/<container>/DeliveredNotifications.plist` (a real per-app-container archive Apple/the simulator writes on delivery) — the banner had simply already been dismissed/expired by the time each screenshot was taken, since iOS banners are transient (a few seconds) unless pulled down into Notification Center. So the actual root cause of "nothing visible in the screenshot" was screenshot timing relative to the transient banner, not `simctl terminate` itself — but `terminate` made this harder to distinguish from a real scheduling failure, since a killed process gives no other signal to correlate against.
**Fix:** To verify a scheduled local notification actually fired on iOS Simulator, don't rely solely on a screenshot taken sometime after the expected fire time — banners are transient and a screenshot can easily miss the window. Instead (or additionally) inspect `DeliveredNotifications.plist` directly: `find ~/Library/Developer/CoreSimulator/Devices/<udid> -iname DeliveredNotifications.plist`, then `plutil -p <path>` on each (there's one per app-container UUID; the one with real content beyond `"$objects": ["$null"]` is the one that received something) — the decoded keyed-archiver payload includes `AppNotificationTitle`, `AppNotificationMessage` (the body), `RequestDate`/the delivery `NS.time`, and critically `payload` (our own `zonedSchedule(payload: ...)` value), which is enough to confirm both that it fired and that it fired with the right content.
**Prevent next time:** When manually verifying simulator notification delivery, background the app with `xcrun simctl launch <device> <a-different-real-app-bundle-id>` (e.g. `com.apple.mobilesafari`) rather than `simctl terminate` — it's the more faithful stand-in for a real user backgrounding the app, and it doesn't destroy the one process whose state you're trying to observe. If a screenshot check comes back empty, check `DeliveredNotifications.plist` before concluding scheduling failed — the notification may well have fired and simply already be gone from the transient banner by screenshot time.

## [2026-08-21] Android build failed: `flutter_local_notifications` requires core library desugaring, never enabled

**Symptom:** First real `flutter build apk`/`flutter run` for Android (this project's Phase 6 notifications work had only ever been exercised on iOS Simulator) failed at `:app:checkDebugAarMetadata` with: `Dependency ':flutter_local_notifications' requires core library desugaring to be enabled for :app.`
**Cause:** `flutter_local_notifications` uses `java.time` APIs internally, which aren't natively available below Android API 26 — this project's `minSdk` is 24 (Flutter's own default). Without desugaring enabled, AGP's metadata check refuses to link the dependency at all; this is a hard build failure, not a runtime warning, so it would have blocked *any* Android build the moment the plugin was added, whether or not notifications were ever actually scheduled.
**Fix:** In `android/app/build.gradle.kts`, added `isCoreLibraryDesugaringEnabled = true` inside the `compileOptions` block, plus `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` in a `dependencies { }` block — both taken directly from the plugin's own README (search "desugar" in `~/.pub-cache/hosted/pub.dev/flutter_local_notifications-<version>/README.md`), not guessed. This is a build-tool-side Gradle dependency, not a pub package, so it isn't subject to the "flag new pub dependencies" rule, but is still worth naming since it's new build-time surface.
**Prevent next time:** Any Flutter project adding `flutter_local_notifications` (or likely other plugins using `java.time`/desugared APIs) needs this Gradle change *before* the first Android build is attempted — don't assume "iOS Simulator works" means the Android side is configured correctly too. Since this project's `android/` config had never been exercised by a real build until this session, it's worth treating a brand-new plugin's Android build as genuinely unverified until `flutter build apk` (or `flutter run` on a real Android target) has actually succeeded at least once.

## [2026-08-21] Cancelling an Android NDK/system-image download mid-transfer leaves a silently corrupted install that fails later with an unrelated-looking error

**Symptom:** A prior session's `flutter build apk` was cancelled mid-download (Android NDK was ~800MB into what turned out to be a ~2.8GB extracted install). The *next* session's build, run against that same NDK directory, failed with a CMake error building an unrelated native dependency (`jni-1.0.3`, a transitive package): `CMake Error ... The CMAKE_C_COMPILER: .../toolchains/llvm/prebuilt/darwin-x86_64/bin/clang is not a full path to an existing compiler tool.` The error read like a toolchain/architecture mismatch (Apple Silicon vs. an x86_64-named directory), not a corrupted download — `darwin-x86_64` is in fact the correct, only prebuilt directory name NDK ships (it runs fine under Rosetta on Apple Silicon), so that red herring cost real diagnosis time.
**Cause:** `clang` in that directory was a broken symlink (`clang -> clang-19`) pointing at a `clang-19` binary that had never actually been written to disk — the interrupted download/extraction from the prior session left every *small* support file in place (`clang-format`, `clangd`, `clang-check`) but the large main compiler binary (~170MB) was truncated or never extracted, since Gradle/AGP's NDK installer doesn't appear to atomically verify a complete extraction before leaving the directory in place for future builds to reuse.
**Fix:** `rm -rf ~/Library/Android/sdk/ndk/<version>/` and let the next build (or a direct `sdkmanager "ndk;<version>"` install) re-download and re-extract cleanly from scratch. Confirmed integrity this time by checking the binary directly before rebuilding: `file .../bin/clang-19` should report a real Mach-O executable, not a missing/zero-byte file, and `du -sh` on the NDK directory should land near its known full size (~2.8GB for NDK 28.2.13676358), not a partial fraction of it.
**Prevent next time:** Never cancel an Android SDK/NDK/system-image download mid-transfer if it can be avoided — per CLAUDE.md's build/verification guidance, let a first-time large download run to completion rather than killing it to "save time," since an interrupted install can silently corrupt state that only surfaces as a confusing, unrelated-looking error in a *later* session. If a build ever produces a compiler-toolchain error that looks architecture-related but the directory naming looks correct, check whether the referenced binary actually exists and is a complete, valid file before assuming it's a configuration problem.

## [2026-08-21] `flutter build apk`/`flutter run` backgrounded without a TTY can silently stall forever on an SDK-component auto-install step

**Symptom:** A backgrounded `flutter build apk` invocation (via a shell tool with no TTY attached) appeared to hang indefinitely at the same log line (`WARNING: The SDK Manager CLI tool (sdkmanager) is deprecated...`) with zero CPU growth on the Gradle daemon for 5+ minutes, right after a fresh NDK directory had just been deleted to fix the corruption gotcha above. Looked exactly like the download itself was stalled (same symptom category as the two gotchas above), but was actually a different cause entirely.
**Cause:** Flutter's Gradle plugin auto-installs missing SDK components (the NDK, in this case) via a native `android-cli` helper process that can prompt/spool for confirmation depending on invocation context. Run with no controlling TTY and no piped stdin, that step doesn't error out — it just never proceeds, and neither Gradle's own log output nor the parent `flutter build` process gives any indication that it's blocked waiting on something rather than genuinely computing. Direct process inspection (`lsof -p <pid>` on the Gradle daemon) showed no open socket/file handle for a download at all during the stall, confirming it wasn't mid-transfer.
**Fix:** Ran the SDK component install as its own explicit, separate command with `yes |` piped into it (`yes | sdkmanager "ndk;<version>"`) rather than relying on `flutter build`'s implicit auto-install to handle any prompts on its own. That direct invocation showed real download progress immediately (confirmed by watching `~/Library/Android/sdk/.sdk/arch/*.part` grow) and completed normally; the subsequent `flutter build apk` then succeeded immediately since the component was already present.
**Prevent next time:** When a backgrounded Flutter/Gradle build might need to auto-install an SDK component it doesn't have yet (first Android build in a new environment, or after deleting a corrupted component), pre-install that component explicitly and non-interactively first (`yes | sdkmanager "<package>"`) rather than trusting the build's own auto-install path to handle a possible confirmation prompt correctly when run without a TTY.

## [2026-08-21] iOS Simulator's native share sheet outlives the Flutter app that opened it — relaunching a new scaffold app underneath it produces a misleading screenshot

**Symptom:** After screenshotting a `SharePlus.instance.share(...)` share sheet from one dev-scaffold app, stopped that `flutter run` process and launched a *different* scaffold app (a wipe-and-import verification) on the same simulator. A screenshot taken right after the new app's "ready" log line still showed the old app's share sheet on top, with stale data ("3 task(s)" from the old app's state) — looked exactly like the new scaffold had failed to wipe/reset data, or like a leftover process was interfering.
**Cause:** On iOS, `UIActivityViewController` (the native share sheet `share_plus` wraps) is presented by the *system*, not by the requesting app's process — it survives independently of whether that app's process is still running underneath it. Stopping the Flutter tooling process (`flutter run`'s CLI) does not terminate the app on the simulator, and even the app being backgrounded/replaced by a new app launch doesn't dismiss a system-level sheet that was never explicitly closed. The new app was in fact wiped and correct the whole time; the screenshot was just showing an unrelated stale system overlay from the previous session.
**Fix:** `xcrun simctl terminate <device> <bundle-id>` before trusting a screenshot when the previous verification step opened any native OS-level UI (share sheet, document picker, system alert) that a plain app relaunch might not dismiss. After terminating and confirming the underlying state (screenshot came back showing the actual new-app state, e.g. "Exported 3 task(s)." status text from the *previous* run, then a clean relaunch showing the real post-wipe/import state), the verification could proceed correctly.
**Prevent next time:** Any dev-scaffold session that exercises `share_plus`, `file_picker`, or similar OS-chrome-presenting APIs should assume that chrome can persist across the *next* `flutter run` on the same simulator/device. Terminate the previous app explicitly (not just stop the `flutter run` process) before screenshotting a fresh scaffold launch, or treat an unexpectedly-stale-looking screenshot as a signal to check for lingering system UI before concluding the new run is broken.

## [2026-08-21] Android's own share sheet also outlives its launching app — same gotcha as iOS, confirmed independently

**Symptom:** After screenshotting the real Android share sheet from `settings_export_main.dart`, stopped that `flutter run` and launched `settings_import_main.dart` on the same emulator. The next screenshot still showed the *previous* run's Android share sheet, with the previous export's filename still visible — looked exactly like the new scaffold had failed to launch or was stuck.
**Cause:** Same root cause as the iOS entry above, confirmed independently on Android: the system share sheet (`ACTION_SEND` chooser) is presented by the OS, not owned by the requesting app's process, and outlives a `flutter run` stop/relaunch on the same emulator.
**Fix:** `adb shell input keyevent KEYCODE_BACK` (or `am force-stop <package>`) before trusting a screenshot after any run that opened native OS chrome (share sheet, file picker). Confirms the iOS-side entry's "prevent next time" guidance generalizes to Android rather than being iOS-specific.
**Prevent next time:** Treat this as a cross-platform rule, not an iOS-only one: any dev-scaffold session that exercises `share_plus`/`file_picker` should force-dismiss/force-stop before the next screenshot on either platform's emulator/simulator.

## [2026-08-21] Android scoped storage blocks a dev-scaffold from reading `/sdcard/Download` directly via `dart:io.File`

**Symptom:** Reused the existing `settings_import_main.dart` scaffold pattern (works on iOS Simulator: read a known file path straight off disk via `File(path).readAsString()`) on Android by pushing a real exported backup to `/sdcard/Download/` via `adb push` and pointing the scaffold's hardcoded path constant at it. Failed immediately: `PathAccessException: Cannot open file, path = '/sdcard/Download/amble_import_test.json' (OS Error: Permission denied, errno = 13)`.
**Cause:** Android's scoped storage (enforced since API 29+, this project's `targetSdk` is well above that) blocks an app's `dart:io.File` from directly reading files in shared storage locations like `/sdcard/Download/` unless accessed through the Storage Access Framework (which is exactly what `file_picker`'s real picker UI does correctly) or a legacy broad storage permission this app deliberately doesn't request. This is not a bug in the real import feature — `file_picker`'s actual picker flow is unaffected — it only broke the dev-scaffold's shortcut of bypassing the picker UI and reading a path directly.
**Fix:** Pushed the file into the app's own private storage instead (`adb shell run-as <package> sh -c 'cat /data/local/tmp/<file> > files/<file>'`, then pointed the scaffold's path constant at `/data/user/0/<package>/files/<file>`, which every Android app can always read/write without special permissions. Reverted the scaffold's path constant back to the iOS scratchpad path afterward, since it's a `dart:io` absolute path with no platform branching — one hardcoded value can't serve both platforms at once, and the iOS path is what every other session in this project has used.
**Prevent next time:** The "read a known path directly, bypassing the real picker" dev-scaffold pattern is iOS-Simulator-specific as written. On Android, either (a) temporarily point the scaffold's path constant at the target app's own private `files/` directory (`/data/user/0/<package>/files/...`, reachable via `adb shell run-as <package> ...`) for the duration of the Android verification run, or (b) give the scaffold a `Platform.isAndroid` branch with two path constants from the start if this pattern will be reused across platforms more than once — not done this session since it was a one-off verification, but worth it if a third Android verification session needs the same pattern.

## [2026-08-21] Bottom nav "missing" on a real iPhone — stale Xcode install, not a code bug

**Symptom:** User reported the bottom nav (Inbox/Timeline/Settings) was completely absent when running the real app (`main.dart`) on their physical iPhone via Xcode/USB, even though the exact same code rendered the nav bar correctly on iOS Simulator.
**Cause:** The phone had an older build installed from before Phase 5 (when `AmbleHome` was still `Scaffold(body: TimelineScreen())` with no bottom nav at all — see Phase 4's DECISIONS.md entry). An incremental `Product > Run` from Xcode can overwrite app contents without always fully replacing a stale build/cache, so the old no-nav shell kept showing.
**Fix:** Deleted the app from the iPhone entirely (long-press icon → Remove App), then did a clean `Product > Run` from Xcode for a true fresh install. Nav bar appeared correctly afterward, confirmed by the user's own screenshot.
**Prevent next time:** When a real-device build shows behavior that doesn't match a simulator run of the same code — especially "old UI structure still showing" symptoms — suspect a stale install before suspecting a code/layout bug. A full delete-and-reinstall (not just re-running from Xcode) is the fast way to rule this out, and should be the first troubleshooting step suggested, before digging into layout/safe-area/screen-size theories.

## [2026-08-21] "Tap Continue while editing, nothing happens" — an unguarded notification-sync call could abort a save entirely

**Symptom:** User reported tapping Continue on the task detail form's edit flow appeared to do nothing — the sheet stayed open, no visible error, no save.
**Cause:** `TaskList`'s mutators (`createTask`, `scheduleTask`, `updateTask`, `rescheduleTask`, `toggleComplete`) each called `NotificationService.syncForTask(task)` immediately after the repository write, with no error handling. `syncForTask` → `scheduleForTask` calls `_plugin.zonedSchedule(...)`, a real native platform-channel call that can throw for reasons unrelated to the task data (a platform-channel hiccup, a timezone-database edge case, permission-state timing). Any such exception propagated all the way up through `_save()` in `task_detail_sheet.dart`, which never reached its trailing `Navigator.of(context).pop()` — so the task write may or may not have already succeeded (it usually had, since `saveTask` runs *before* `syncForTask`), but the UI gave zero indication either way. Reproduced directly: a dev scaffold that skipped `NotificationService.initialize()` (unlike `main.dart`, which always calls it before `runApp`) hit exactly this failure mode via a `LateInitializationError` from the `timezone` package, proving the failure class is real even though that specific scaffold gap wasn't the production trigger.
**Fix:** Added `TaskList._syncNotificationSafely(task)`, wrapping the `syncForTask` call in try/catch — a scheduling failure is now logged via `debugPrint` (surfaced, not silently swallowed, per CLAUDE.md's "fail loud" rule) but never blocks the caller. All five mutators that sync notifications now go through this helper instead of calling `syncForTask` directly; `deleteTask`'s `cancelForTask` call got the same treatment. The task write itself (`saveTask`) was never the problem — it's `syncForTask` failing to fail *quietly enough* that broke the caller.
**Prevent next time:** Any code path that runs a real native platform-channel call (notifications, file I/O, share sheets) as a "side effect" of a user-facing action (save, delete, complete) should not let that side effect's failure block the primary action's completion — wrap it, log it, move on. This is the same shape of bug as import/export's error handling (which already validates and reports rather than crashing), just not previously applied to the notification-sync side effect. Regression tests added: `test/shared/providers/task_providers_test.dart`'s "notification sync failures never block the task write" group, using a new `ThrowingNotificationService` test double (`test/support/`) that always throws — proves `createTask`/`updateTask`/`deleteTask` still complete and refresh state.

## [2026-08-21] "Nav disappeared" on the simulator — a leftover dev-scaffold had replaced the real app

**Symptom:** User reported the bottom nav (Inbox/Timeline/Settings) had disappeared on the iOS Simulator. A screenshot confirmed it: a real-looking Timeline screen, correct fonts/colors/tokens, no nav bar, and an empty day.
**Cause:** Not a bug. Every dev-scaffold entry point (`flutter run -t lib/features/.../*_main.dart`) installs over the *same bundle ID* as the real app (`com.example.amble`), replacing it on the device. Most scaffolds deliberately render `Scaffold(body: SomeScreen())` directly, bypassing `AmbleHome` (the nav shell) entirely so a single screen can be isolated for verification — so they have no bottom nav *by design*. The last scaffold run in that session (`edit_save_repro_main.dart`, for the "Continue does nothing" investigation) was still installed. Confirmed by checking the installed bundle's mtime (`xcrun simctl get_app_container <device> <bundle-id>`), which matched the exact minute that scaffold was launched. Compounding the confusion: every scaffold set `debugShowCheckedModeBanner: false`, making a scaffold build visually **indistinguishable** from the real app.
**Fix:** Re-ran `flutter run -t lib/main.dart` to reinstall the real app — nav returned immediately, confirming nothing was broken. Then removed `debugShowCheckedModeBanner: false` from all 16 `*_main.dart` scaffolds (leaving it in place in `lib/main.dart`), so any scaffold build now shows Flutter's DEBUG banner and is instantly identifiable on-device. The banner will appear in scaffold screenshots from now on — an accepted, deliberate trade.
**Prevent next time:** After any dev-scaffold verification session, reinstall the real app (`flutter run -t lib/main.dart`) before leaving the device for the user, or expect "the app looks wrong" reports. When a UI-missing report comes in, check *which build is actually installed* (bundle mtime vs. when scaffolds were run) before investigating layout code — this is the second "app looks wrong but the code is fine" incident in two days (the first was a stale pre-Phase-5 build on the physical iPhone), so treat "is the user looking at the build I think they are?" as the first question, not the last.

## [2026-08-21] `pkill`-ing the Android emulator leaves a stale lock that makes the next start fail with a misleading "experimental feature" error

**Symptom:** After `pkill -f "qemu-system"` to stop the emulator, the next `emulator -avd Amble_Test_API34` appeared to start normally — the process stayed alive for 8+ minutes with no errors in its log — but `adb devices` never listed it and `adb ... getprop sys.boot_completed` returned `device 'emulator-5554' not found` indefinitely. Restarting the adb server (`adb kill-server && adb start-server`) changed nothing. Looked exactly like an emulator that was simply booting very slowly, or an adb daemon that had lost track of it.
**Cause:** The emulator writes `~/.android/avd/<name>.avd/multiinstance.lock` while running and removes it on a *clean* shutdown. `pkill` terminates it without that cleanup, so the lock survives. On the next start the emulator detects the lock, assumes a second instance of the same AVD is being launched, and aborts with `FATAL | Running multiple emulators with the same AVD is an experimental feature. Please use -read-only flag to enable this feature.` — a message about a feature flag, which reads nothing like "there's a stale lock from a killed process." The abort also happens *after* the process has already printed its normal startup banner, so the log looks healthy unless read to the very end.
**Fix:** `rm -f ~/.android/avd/<name>.avd/*.lock`, then start the emulator normally. It booted immediately afterward.
**Prevent next time:** Delete the lock before starting, as the reliable step. Note that `adb -s <serial> emu kill` — the "clean" shutdown — is **not** sufficient on its own: verified at the end of this session that after `emu kill` reported `OK` and the qemu process had genuinely exited, `hardware-qemu.ini.lock` was removed but **`multiinstance.lock` was still present** 8+ seconds later. So the lock can outlive even a graceful stop, and `rm -f ~/.android/avd/<name>.avd/*.lock` before launching is the step that actually prevents the failure, regardless of how the previous instance was stopped. If an emulator ever appears to start but never registers with adb, read the **end** of its log for `FATAL` before assuming a slow boot. This is the same shape as the stale Hive `.lock` gotcha already in this log: a leftover lock making the *next* run fail in a way that doesn't name the real cause.

## Cascade reschedule: multiple simultaneous conflicts collapsed onto the same slot

**Reported directly**, with a screenshot: "Prevent overlapping tasks" on, but dragging a new task on top of a dense cluster produced a broken layout — many overlapping-column pills crushed together with Flutter's own RenderFlex overflow banner visible (rotated 90°, reading as vertical red-striped text next to the personal-category person icons).

**Root cause, confirmed by reproduction before touching any code**: `computeCascadeMoves` processes one "mover" per outer-queue iteration. When MULTIPLE existing tasks overlapped that single mover simultaneously, each was pushed independently — computed only from its own distance to the mover's edges, never checked against the other tasks being pushed in the same pass. Three same-direction pushes could (and did, in the repro) land on the exact identical slot. A second, subtler layer of the same root cause: even after fixing same-mover conflicts to chain sequentially, a LATER mover's push could still collide with a slot an EARLIER mover's pass had already placed, since neither pass re-checked against tasks outside its own immediate conflict set.

Reproduced standalone (a throwaway `dart run` script, not committed) with 4 tasks 15 minutes apart before touching the algorithm — confirmed 3 tasks collapsed onto one identical slot. Fixed both layers: (1) tasks overlapping the same mover are now grouped by push direction (unchanged: still decided by distance to the mover's edges) and chained against EACH OTHER in position order, each one's target computed from the previous push's edge rather than independently from the mover; (2) every computed push is additionally checked against the full table of already-`visited` (finalized) slots via a new `_firstOccupiedOverlap` helper, and walked further out if it would land on one — catching cross-mover-pass collisions the direction-grouping alone couldn't.

Existing "cycle guard" test only asserted the algorithm terminates, never that a successful result was actually overlap-free — the exact property this bug violated would have passed that test. Strengthened it, and added two new regression tests (`_expectNoOverlaps` helper) reproducing both layers directly: same-mover simultaneous conflicts, and a later-pass collision with an earlier pass's placement.

`flutter analyze`: clean. `flutter test` not run this session — a live `flutter run` dev session was active throughout (confirmed with the architect it was their own manual verification); running `flutter test` alongside a live `flutter run` deadlocks both on a shared incremental-compiler cache (see the previous session's Repeats-settings entry). Verified with a standalone `dart run` reproduction script instead (written, confirmed the bug, confirmed the fix, deleted — never committed).

## Drop flicker: block rendered at the raw finger position, committed at the snapped one

**Reported directly**: "a flicker of item appearing abruptly higher than actual drop zone, and then disappearing showing in the drop zone."

**Root cause**: `_DraggableTaskBlockState.build` positioned the block at `baseTop + _dragOffset` — the RAW, unsnapped drag offset. But `onDragEnd` committed `_previewStartsAt`, which is derived from `_snappedMinutesDelta`. So the two disagreed by up to half a snap interval (5min snap at 1.5px/min = up to ~3.75px): at release the block was drawn at the finger's exact position, then jumped to the snapped slot once the async write round-tripped and `baseTop` updated. Not a rendering or timing bug — a genuine mismatch between what was drawn and what was saved.

**Fix**: new `_isSettling` flag, set the instant the finger lifts and cleared after the settle animation has played. While set, the block renders at the snapped offset instead of the raw one, so the correction happens immediately at release and is *animated* rather than jumping. The block's root became `AnimatedPositioned` with a zero duration only while the finger is actually down (1:1 tracking, no lag) and `motionNormal` easing otherwise.

`_endSettle()` is deliberately a separate step rather than clearing `_isSettling` alongside `_dragOffset`: the block must still be in animated mode during the frame where `baseTop` updates and the offset resets, since those two changes cancel out positionally and would otherwise expose a one-frame jump.

## Drop jump, second cause: element re-creation from an unkeyed sibling + mid-animation reorder

**Reported directly** after the snapped-offset fix (above) landed: the block still animated to a position HIGHER than the drop, then eased back down to the real one — a two-phase move, and happening on any task, not just the day's earliest.

That ruled out the obvious suspect: `_visibleRange` is derived from task times (`rangeStart = earliest task − 30min`), so dragging the earliest task later shifts the whole coordinate space. Real, but it can only fire for the earliest/latest task — the architect confirmed the jump happens on any task, so this was NOT the cause. Recorded because it looks like a match and would otherwise be re-investigated.

**Actual cause, two interacting parts:**
1. The drag "ghost" (a faded copy at the original position, rendered as a conditional `Positioned` sibling) had **no key**. Its removal at release shifted Flutter's element matching for the keyed block right after it, so the real block's element could be re-created rather than updated — resetting its `AnimatedPositioned` to animate from the ghost's (higher) position.
2. `_dragLastOrder` keyed its reordering off `_draggingTaskId`, which clears the instant the finger lifts. So the block ALSO jumped back to its natural Stack index mid-settle, a second reorder while its animation was still running.

**Fix:** gave the ghost a `ValueKey('ghost-<taskId>')`, and split the parent's tracking into `_draggingTaskId` (ghost visibility, cleared on release) and `_settlingTaskId` (Stack ordering, cleared only via a new `onSettled` callback once the settle animation finishes). The two now have deliberately different lifetimes. `onSettled` ignores stale fires — a different task holding the pin, or the same task re-dragged before its previous drop finished.

**Method note:** the first diagnosis (snapped-vs-raw offset) was correct but incomplete — it fixed one of two independent causes of the same visible symptom. Worth remembering that "the flicker is still there" after a confirmed-correct fix can mean a second cause, not a wrong one.

## Popping a sheet invalidates its own BuildContext before the next sheet opens

Hit while adding the remove-scope sheet. The natural shape —
`Navigator.of(context).pop(); if (context.mounted) showNextSheet(context);` —
looks correct but silently does nothing: `context` inside a sheet's builder
belongs to that sheet, so popping it unmounts it and the `mounted` guard
skips the follow-up every time. It fails *quietly*, which is what makes it
worth recording.

Fix: capture `Navigator.of(context)` BEFORE the pop and push the next sheet
onto `navigator.context`, which outlives the sheet being closed.

`task_action_sheet.dart`'s existing `_duplicate` was flagged here as
"likely affected the same way." **That flag was wrong** — later verified by
widget test: `_duplicate`, `_editDetails` and `_editSchedule` all work
fine. The difference is the async gap. Those three touch `context`/`ref`
*synchronously* in the same frame as the pop, while the element is still
alive; only `_remove` had a real `await` (the scope sheet) before its
`ref.read`, by which point the sheet had unmounted. Pop-then-use is safe;
pop-then-**await**-then-use is not.

## Day-of-week chips overflowed their row by 40px

Caught by a widget test the first time the suite could actually run (a live
`flutter run` had blocked `flutter test` for several sessions — see the note
at the end of this entry).

`_RecurrencePanel`'s seven `_DayChip`s were each a fixed
`theme.spacingXl * 1.25` (~46.9px) wide inside a `Row`. Seven of those is
~328px against ~310px of available panel width, so the row overflowed by
about 40px — on-device this shows as the yellow/black striped overflow
banner. Not a test artifact: the test simply rendered at a realistic phone
width and surfaced a genuine production layout bug.

Fix: each chip is now `Expanded` (with an explicit `spacingXs` gap between
them) and `_DayChip` no longer sets its own width — height stays fixed so
they keep their pill shape. They now share whatever width the sheet has.

## Hardcoded calendar dates in tests that assert relative-to-today behaviour

Same test run surfaced four failures in `edit_schedule_repeats_test.dart`
that had nothing to do with the code under test. The tests used fixed dates
(Aug 20 – Sep 3, 2026) and asserted series-pruning behaviour, but the
pruning rules only touch instances scheduled **today or later**. Those dates
were future when written and had since become past, so the "future
instance was deleted" assertions failed for a purely calendrical reason.

Fix: a `_daysFromToday(days, {hour})` helper anchored to `DateTime.now()`,
plus deriving the expected weekday from the task's own date rather than
hardcoding `DateTime.thursday`. Any test asserting behaviour defined
relative to "now" must build its fixtures relative to "now" too, or it
silently rots.

A second, unrelated harness bug in the same file: `_tapAndSettle`'s
`Duration.zero` drain was written when the save path was a single write. The
series-editing paths await several repository round-trips in sequence
(prune → write template → re-materialize → refresh), so a zero-duration
drain only cleared the first hop and `tearDown` closed the Hive box
mid-flight ("Box has already been closed"). Raised to a real 100ms delay.

**Process note:** these three bugs sat undetected across several sessions
because `flutter test` could not be run while a `flutter run` session held
the shared incremental-compiler cache. `flutter analyze` stayed clean
throughout and caught none of them — analyze does not render widgets or
evaluate assertions. Worth running the suite at the first opportunity after
any stretch of analyze-only verification.

## "Remove not working": three stacked bugs, only findable by running the widget test

Reported directly. Tapping Remove did nothing. Three independent causes,
each hiding the next — worth recording because each alone would have been
enough to break the feature, and `flutter analyze` was clean throughout.

**1. `_ActionRow`'s label overflowed the row (56px).** The `Text` had no
flex, so it sized to its natural width. The original action labels were
short enough to fit; the remove-scope sheet's longer ones ("Remove this
occurrence") pushed it over. A layout exception during the tap aborted the
handler, so the delete never ran. Fixed with `Expanded` + ellipsis.

**2. `AppSheet.show` built its content with the CALLER's context.**
`builder(context)` was invoked eagerly before pushing the route, so a
builder calling `Navigator.of(ctx).pop(value)` popped the caller's route
instead of the sheet — the sheet never closed and `show()` never returned.
A latent flaw in the shared primitive, invisible until a caller needed a
return value (every previous caller was fire-and-forget). Fixed by
deferring the build to the route builder and passing the sheet's own
context.

**3. `ref` used after the sheet unmounted.** `_remove` popped its own
sheet, awaited the scope choice, then called `ref.read(...)` — but `ref` is
bound to the now-unmounted sheet element, which throws
("Using 'ref' when a widget is about to or has been unmounted is unsafe").
The throw happened inside an async gap, so it surfaced as nothing
happening. Fixed by capturing the notifier alongside the navigator, before
the pop.

**The rule that ties 2 and 3 together:** pop-then-use is safe; pop-then-
**await**-then-use is not. Anything needed after an async gap —
`BuildContext`, `ref`, a notifier — must be captured while the widget is
still mounted. `_duplicate`/`_editDetails`/`_editSchedule` look identical
but are fine precisely because they have no await before their use.

## A hand-picked scale silently flattened the durations it was meant to distinguish

While building collapsed mode I picked `_collapsedPixelsPerMinute = 0.45`
by eye, reasoning only that it should be lower than the timeline's 1.5 so a
2h task wouldn't dominate the screen. `flutter analyze` was clean and the
code read correctly.

Rendering the actual range showed 15m, 30m **and 60m** as an identical
circle. `TaskCapsuleBlock` floors a pill at its badge size (~33.8px), and
at 0.45 that floor isn't cleared until 75 minutes — so the single most
important comparison ("is this an hour or half an hour?") was invisible,
which defeated the entire point of proportional heights.

The fix was to derive the rate from the requirement instead of guessing:
the anchor is "30m is the circle," so the rate is exactly `badge ÷ 30`
(≈1.125). 30m sits on the floor, 1h is 2×, 2h is 4×.

**Lesson:** when a constant exists to make a visual *relationship* legible,
the relationship is the specification — derive the constant from it and
render the range to confirm. A plausible-looking number plus a clean
analyze proves nothing about whether the thing is actually distinguishable.

## A `TextEditingController` listener driving auto-advance-focus can misdirect typed input into the wrong field

Building the new numeric Hour/Minute entry boxes (`_NumericTimeField`, replacing the old scroll-wheel/slider), the first box needed to auto-advance focus to the second once two digits were typed — a normal time-entry UX. The first attempt wired this via `_firstController.addListener(() { if (_firstController.text.length >= 2) _secondFocus.requestFocus(); })` in `initState`.

Typing "02" into the Duration-hours box sometimes landed the value in the Duration-**minutes** box instead, producing a preview like `22:00 - 22:02 (2m)` instead of the expected 2-hour duration. Reproduced deterministically in an isolated minimal 2-`TextField` widget (outside the app file, since the real class is library-private) before trusting the diagnosis — a lesson from an earlier misdiagnosis this session.

**Root cause**: a `TextEditingController` listener fires for *any* write to the controller — not just genuine user keystrokes, but also programmatic writes (`WidgetTester.enterText` in tests, and by extension any synthetic/external `.text =` assignment). Calling `FocusNode.requestFocus()` from inside that listener races with the underlying text-delivery/IME mechanism that's still in the middle of delivering the typed value, so the value can end up committed to whichever field the focus change lands on, not the field it was actually typed into.

**Fix**: don't drive focus changes from a controller listener. Use `TextField.onChanged` instead — it fires only for genuine user-driven edits, never for external `.text =` writes — and only on the *first* box (nothing to advance to from the second). Added a `ValueChanged<String>?` parameter to the shared `_digitBox` helper so only the first box wires an advance callback.

**Lesson**: `TextEditingController.addListener` answers "did this controller's value change," not "did the user type something" — those are different questions, and only `onChanged` answers the second one. Any focus-changing side effect belongs on `onChanged`, never on a controller listener.

## A masked text field can't judge "was this a deletion?" by string length

Building `AppSegmentedTimeField`'s formatter, the first version decided between the insert and delete paths with `newValue.text.length < oldValue.text.length`. Every typed value silently vanished — the field stayed at `00 : 00`.

The cause only shows up in a MASKED field. `enterText` (and a paste, or autofill) replaces the whole string at once, so the formatter sees `new="0930"` — 4 characters — against `old="00 : 00"` — 7 characters, because the mask's separator is part of the old string but not the new one. A length comparison reads that as a deletion and throws the typed digits away.

**Fix**: judge deletion on DIGIT count (`newDigits.length < oldDigits.length`), not string length. Digits are the field's actual content; the separator is presentation, and any check that counts it will be wrong whenever the two sides are formatted differently.

## ...and it can't judge "was this one keystroke?" by digit count either

The exact mirror of the bug above, introduced by its fix. With deletion now decided on digit count, the insert path used the same measure to tell a single keypress from a bulk replacement. Typing `1`, `4`, `3`, `0` one key at a time produced `10 : 00` — only the first digit landed.

A segmented time field is always FULL (a time always shows four digits), so a keystroke doesn't lengthen the digit string, it overwrites a slot. Digit count is therefore identical before and after a keypress, and the diff-based "which digits are new" logic finds nothing — while a 5-digit intermediate gets truncated back to 4 and misread as a fresh full replacement starting at slot 0.

**Fix**: the two questions need two different measures. Deletion is judged on digit count; a single insert is judged on STRING length (`newValue.text.length == oldValue.text.length + 1`), and the inserted character is read directly at the caret offset rather than diffed out of the digit string.

**The shared lesson:** in a masked field there are two representations — the raw digits and the formatted string — and they disagree about length in different directions depending on the edit. Every decision in a formatter has to name which representation it is asking about. Both of these bugs were clean under `flutter analyze` and both were caught only by driving real keystrokes through the widget; the second was introduced by the fix for the first, which is exactly why the test covers the bulk path AND the one-key-at-a-time path separately.

## A field that builds its input conditionally has no input to focus

`AppFieldShell`'s first version only rendered `child` when the label was floated, reasoning that a resting label already reads as the placeholder so an empty input underneath would double the hint. Correct visually, wrong structurally: an empty, unfocused field then contains no `TextField` at all, so `autofocus` had nothing to attach to and the whole flow failed at the first `enterText` with "Bad state: No element".

**Fix**: keep the input in the tree always and animate only its HEIGHT (`AnimatedAlign` + `heightFactor`, clipped). Same visual result — the input is invisible while the label rests over it — without removing the element that focus, the keyboard, and every finder depend on.

**Lesson:** "don't show it" and "don't build it" are different instructions. Anything focusable, measurable, or findable must stay in the tree and be hidden by layout, not by a conditional in `build`.

## A glyph colored from a SURFACE token inverts the wrong way in dark mode

The task-detail header's back/close buttons defaulted both their circle and their icon to `colorSurfacePrimary`. That was correct while they sat on a coloured banner — a white glyph on a saturated category colour. Once the banner was removed and the buttons moved onto the sheet's own ground, dark mode rendered them near-black on a dark background: effectively invisible.

`colorSurfacePrimary` is white in light mode and `ink900` (near-black) in dark. A *surface* token tracks the background and therefore inverts in the SAME direction as the thing behind it; a glyph needs to invert in the OPPOSITE direction to stay legible. They coincide only when the glyph is deliberately sitting on a third, palette-independent colour — which the coloured banner was, and the plain sheet is not.

**Fix**: `colorTextPrimary` for the glyph, `colorSurfaceField` for the circle.

**Lesson:** a foreground colour must come from a text/content token, never a surface one, even when a surface token happens to look right in the palette you are currently viewing. If a glyph is colored from a surface token, it is only correct by coincidence in one palette.

## Capacity and display width are different numbers in a masked field

`AppSegmentedTimeField` takes `firstDigits` to size its hour segment — 2 for a time of day, 3 for an uncapped duration. That single number was used for two unrelated jobs: how many digits the mask can HOLD, and how wide the value is DISPLAYED.

The result was a duration of 2h30m rendering as `000 : 30`. The padding was advertising the field's maximum rather than showing the value, and it looked like a bug in the value itself.

**Fix**: separate the two. Display width is derived from the value (`max(2, digitsInValue)`), so an ordinary duration reads `02 : 30` and a long one still reads `120 : 00`; `firstDigits` continues to govern only the mask's capacity and the caret arithmetic. The placeholder likewise stays `hh : mm` rather than mirroring the capacity — a hint describes what to type, and nobody types a leading zero triple.

**Lesson:** when one parameter is read in two places for two different purposes, check that they actually want the same number. Here "how much can this hold" and "how wide does this look" happened to coincide for time-of-day (both 2) and only diverged for the second consumer — which is the same shape as the general rule that a heuristic derived from one dataset must be checked against a genuinely different one before it's trusted.

## In a masked field, "is this a replacement?" must be judged by SHAPE, not length

Adding the hour-first caret reset broke typing entirely: the field accepted no input at all. With the caret at offset 0, `enterText("093")` against `"00 : 00"` produced FEWER digits than the old value, so the digit-count deletion check classified a replacement as a delete and threw the input away.

The earlier length-based check had already been replaced with a digit-count one for the opposite bug (a paste misread as a delete, because the separator lives in the old string but not the new one). Both checks share the same flaw: they assume something about WHERE the caret is.

**Fix**: judge a full replacement by shape. A replacement arrives as bare digits with no separator at all; a real edit always leaves the separator in the string, because a user can only remove one character at a time from a formatted value. That test holds regardless of caret position.

**Lesson:** this is the third bug in this formatter from inferring the KIND of an edit from a measurement (string length, then digit count) rather than from a structural property. Each measurement worked for the cases in front of it and broke on the next genuinely different one. A structural property — "does the text still contain the mask?" — does not depend on the caret, the length, or the direction of the change.

## A caret reset scheduled post-frame fires after every keystroke, not just on focus

The same caret change also dragged the caret back to position 0 mid-typing. `addPostFrameCallback` inside a focus listener sounds like "once, when focused", but the listener runs on any focus notification and the callback runs after whatever frame follows — including the frame after each keystroke.

**Fix**: gate on the focus TRANSITION (`hasFocus && !_wasFocused`), and skip the reset if the caret is no longer where the platform's default put it.

**Lesson:** "on focus" and "while focused" are different conditions, and a post-frame callback registered from a listener silently converts the first into the second.

## A tap that "does nothing" in a widget test may be missing the target entirely

Chasing a report that the wheel picker didn't write its value back, a probe showed the confirm button present, on-screen, and returning a sensible rect — yet tapping it never fired `onPressed`.

The cause was the default 800px-tall test surface. The sheet renders taller than that viewport, so the button's rendered position and its hit-test position disagreed: `tester.getRect` reported y=572 while the hit test at that point resolved to a widget at y=320. The tap landed on whatever was actually there.

Setting a real device viewport (`tester.view.physicalSize = Size(390, 844)`) made the same code pass first time.

**Lesson:** before concluding that a handler is not wired, confirm the tap is reaching it — compare `getRect` against `hitTestOnBinding` at the same point. Anything full-height (a sheet, a scaffold, a bottom-anchored button) needs a realistic viewport in tests, or the geometry silently diverges and every interaction with it becomes unreliable. The bug reported here was in the TEST, and the product code was correct throughout.

## CupertinoPicker paints its selection overlay over the values, not behind them

`selectionOverlay` sounds like a backdrop for the selected row. It is drawn ON TOP of the picker's children, so giving it an opaque fill hides the exact value it exists to highlight — which is what made a chosen time invisible inside its own highlight bar.

**Fix**: low alpha (0.4), so it reads as a highlight and the number shows through. Anything opaque there needs to be a background painted behind the picker instead.

## "Don't overwrite a focused field" is the wrong guard when the control lives inside the field

`AppSegmentedTimeField` refused external value updates while focused, to stop a resync fighting live typing. Reasonable in isolation — and wrong here, because the field's own picker button is rendered inside it. Tapping that button doesn't blur the field, so every value chosen on the wheel arrived while focused and was discarded.

The symptom reported was "it doesn't update when a value is already set", which pointed at value-comparison logic. The actual variable was focus: from an empty field the user hasn't tapped in yet, so the guard isn't active and the picker appears to work.

**Fix**: guard on the precise condition instead of the proxy. The thing to avoid is re-applying the user's OWN edit (which would move their caret), so compare the incoming value against what is currently displayed and skip only on a match. A genuine external change is honoured whether or not the field has focus.

**Lesson:** focus is a proxy for "the user is mid-edit", and proxies break where the assumption behind them does — here, that anything changing the value from outside must also have taken focus away. When a guard uses a proxy, check every path that reaches it: an in-field control is exactly the case that violates this one. Note also that two existing tests passed against this bug because each happened to blur the field first; a test that never exercises the guarded state cannot catch a bug in the guard.

## A `showModalBottomSheet` route doesn't unmount the screen behind it — a bare `find.byType(...).first` can silently target the wrong screen

Writing tests for the new per-field modals (Name/Category, Start time, Duration — each a `showModalBottomSheet`-based sheet opened over the single main create screen), `find.byType(TextField).first` kept typing into the wrong field. The typed text simply never appeared anywhere.

The cause: `showModalBottomSheet` pushes a route ON TOP of the current one — it does not remove the underlying screen from the widget tree. The main screen's own `TextField`s (Time, Duration) stay mounted the whole time the modal is open, and in this app's tree they come FIRST in traversal order, ahead of the modal's own fields. `find.byType(TextField).first` therefore matched the *background* screen's field, not the modal's, even though the modal was the only thing visible on screen.

**Fix**: scope every finder to the modal's own subtree — `find.descendant(of: find.byType(TaskNameCategoryModal), matching: find.byType(TextField))` — rather than a bare type search across the whole tree.

**Lesson:** a `find.byType(...).first` is only safe when you can be sure only one screen's worth of that type is mounted. Any modal, dialog, or overlay stacked over another screen breaks that assumption, because the tree usually keeps the covered screen alive underneath. Scope to the topmost/relevant widget's own subtree by default when a modal is involved, rather than assuming visual coverage implies tree isolation.

## Diagnosing "it does nothing" bugs quickly: reproduce in the smallest isolated widget first, not the full flow

Two real bugs during this session's modal work both first appeared as vague full-flow test failures ("StartTimeModal never opens", "field stays empty") that gave almost no signal about WHERE the problem was. Both resolved fast once isolated: a minimal widget test with the exact same three or four lines of interaction (tap, type, tap Done) reproduced or DISPROVED the bug in isolation before touching the real multi-screen test at all. The disproof was as useful as the reproduction — one isolated probe showed the auto-advance chain itself was fine, which correctly redirected the search to the test's OWN finder scoping instead of the app code.

**Lesson:** when a full end-to-end test fails in a way that's hard to explain from the stack trace alone, don't keep patching the full test and re-running it. Write the smallest possible reproduction of just the suspected mechanism first — it either confirms the bug cheaply, or clears that mechanism and narrows the search, in either case faster than iterating on the full flow.
