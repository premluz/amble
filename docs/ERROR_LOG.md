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

## Overriding `TextField.onEditingComplete` silently drops Flutter's own keyboard-dismiss behavior

`AppSegmentedTimeField` wired `onEditingComplete: _commit` — the keyboard's "Done"/complete action committed the typed value correctly (visible in the field's own state and the caller's `onChanged`), but the on-screen keyboard never closed. Reported directly: "keyboard 'complete' is pressed should close keyboard with that value set."

The cause: `TextField`'s default `onEditingComplete` implementation calls `_focusNode.unfocus()` internally as part of what it does. Supplying a custom `onEditingComplete` callback REPLACES that default entirely rather than running alongside it — so a callback that only commits a value (and never explicitly unfocuses) silently loses the dismiss behavior, even though nothing about the commit logic itself was wrong.

**Fix**: any custom `onEditingComplete` must explicitly call `unfocus()` itself if it wants the keyboard to close — `_commit()` then `_focusNode.unfocus()`, in that order.

**Lesson:** overriding a Flutter callback with a "no-args side effect" default (`onEditingComplete`, similarly `onTap` on some widgets) means auditing what the DEFAULT implementation did before assuming a narrower custom callback is a safe drop-in replacement. A callback that appears to only need to do the domain thing (commit a value) can silently owe the framework a housekeeping call the default was doing for free.

## Forcing a field's caret to a fixed position on every focus-gain also fires on a genuine tap, overriding where the user actually tapped

`AppSegmentedTimeField`'s `_handleFocusChange` forced the caret to offset 0 (the hour segment) whenever focus was gained and the caret was at the text's end — intended to fix the case where opening the field via something OTHER than a direct tap (opening the sheet, tabbing in) dropped the caret into the minutes by Flutter's own end-of-text default. But the same `atEnd` condition is also true when the user taps directly into (or near) the minutes segment on purpose: Flutter resolves that tap to the correct offset first, and this widget's post-frame callback then unconditionally stomped it back to 0. Reported directly: tapping into minutes visibly snapped the caret to the start, requiring a second tap to actually land where intended.

**Fix**: added a `_pendingTextTap` flag set by the `TextField`'s own `onTap` (which fires before the resulting focus-gain is processed) and consumed by `_handleFocusChange` — the forced reset now only runs when focus arrived WITHOUT a preceding direct tap on the text, leaving Flutter's own tap-resolved caret position alone otherwise.

**Lesson:** "caret landed at the end of the text" is not a reliable signal for "the user didn't choose this position" — a genuine tap at or near the end produces the identical signal. When a focus-gain heuristic needs to distinguish "the platform's own default" from "the user's actual input," that distinction has to be tracked explicitly (a flag set by the input event itself), not inferred from the resulting state alone.

## A whole test suite (6 widget tests, all passing) exercised a retired form that no real UI ever calls — masking a real bug in the live edit flow it never touched

Reported directly: "editing task and changing repeat settings... doesn't update it... only when creating new task." `task_detail_sheet.dart`'s live edit entry point is `showTaskDetailSheet` → `_TaskDetailFlow`/`_TaskDetailFlowState` (this is what `task_action_sheet.dart`'s "Edit task" actually calls). But the ONLY recurrence-editing widget test in the repo (`edit_schedule_repeats_test.dart`, six thorough tests covering "turn on"/"change days"/"turn off"/"edit from a non-template instance") called `showEditScheduleSheet` → `_EditScheduleForm`/`_EditScheduleFormState` — a second, structurally near-identical form documented in its own doc comment as "kept as an unreferenced backup" after an earlier redesign, reachable ONLY from dev scaffolds (`*_main.dart` files), never from any real screen.

The two forms had duplicated (not shared) recurrence-editing logic: `_EditScheduleFormState` had the full, correct three-way branch (`updateTaskWithNewRecurrence`/`updateTaskWithChangedRecurrence`/`disableTaskRecurrence`, each seeded from `task.isRecurring` at open time). `_TaskDetailFlowState` had the SAME-NAMED fields (`_repeats`, `_selectedDays`) but they were never seeded from the task being edited (`_repeats` always started `false`), and its `_save()`'s `existing != null` branch called plain `updateTask` unconditionally — never touching the recurrence provider methods at all. All six tests against the *other* form passed the whole time, giving 100% false confidence: they tested code nothing in the app could reach.

**Fix**: ported the seeding (`_wasRecurring`, `_selectedDays` from `findSeriesTemplate`) and the three-way save branch from `_EditScheduleFormState` into `_TaskDetailFlowState`, plus the matching `_hasUnconfirmedChanges` check (so leaving Repeats changed and closing without saving now correctly prompts). Retargeted `edit_schedule_repeats_test.dart` at `showTaskDetailSheet` instead of `showEditScheduleSheet` — all six tests pass against the real live flow after adding `tester.ensureVisible` before each tap (the live form's schedule stage is a real `SingleChildScrollView`; the retired form's fields all fit in the default test viewport without scrolling, which is part of why this swap wasn't caught by a bare re-point earlier).

**Lesson:** a widget test's `showXSheet(...)`/entry-point call is not self-evidently "the real one" just because it looks like the obvious name for the feature under test — when two similarly-named forms/flows exist in the same file (a redesign that kept the old version "as a backup"), grep for the tested entry point's OWN real call sites (`grep -rn "showEditScheduleSheet" lib/`) before trusting that a passing suite proves the live path works. A passing test against dead code is strictly worse than no test at all: it actively suppresses the "we have no coverage here" signal that would otherwise prompt someone to check.

## Adding a loading spinner to a button broke `pumpAndSettle()` in every widget test that taps it — a perpetual animation never settles

After adding `AppButton.isLoading` (a `CircularProgressIndicator`/`CupertinoActivityIndicator` shown while a save is in flight) and wiring it into `_TaskDetailFlowState._save`, two previously-passing test files (`edit_schedule_repeats_test.dart`, `exit_confirmation_test.dart`) started failing with `pumpAndSettle timed out`, plus a downstream `HiveError: Box has already been closed` in some cases and unrelated-looking assertion failures (`Expected: false, Actual: true`; `Expected: non-empty, Actual: []`) in others — the real cause was the same in every case, just surfaced differently depending on where in the pump sequence the timeout landed.

Both files' shared `_tapAndSettle` helper called `await tester.tap(finder); await tester.pumpAndSettle();` immediately after the tap. Once the tapped button (or any button still in the widget tree behind a dialog, for `exit_confirmation_test.dart`'s "Save task" case) sets `_isSaving = true` and starts animating a spinner, `pumpAndSettle()` — which works by pumping frames until two consecutive frames produce no new frames scheduled — never sees that quiescent state, because the spinner itself schedules a new frame every pump for as long as the save is in flight. It hangs until Flutter's own internal timeout fires. Everything downstream of that (the Hive write never got the chance to actually run and complete before the surrounding `runAsync` block and test wound down) then failed as a side effect.

**Fix**: replaced the post-tap `pumpAndSettle()` in both files' `_tapAndSettle` with a single bounded `await tester.pump()` (drains just the tap's own frame) followed by the existing real-I/O delay, followed by a final `pumpAndSettle()` — which now only runs AFTER the save has actually completed and `_isSaving` has gone back to `false`, so there's no longer a perpetually-animating spinner in the tree when it's called.

**Lesson:** any widget with a continuously-animating state (a loading spinner, a shimmer, a marquee) makes `pumpAndSettle()` inherently unsafe to call while that state is active — not just slow, but a hang, since "settle" is defined as "no new frames scheduled" and a perpetual animation schedules one every time. Any test that taps something which can trigger such a state needs a bounded `pump()` (or `pump(duration)`) across the window where the animation might be live, and can only fall back to `pumpAndSettle()` once that window has closed.

## The bounded-pump fix for a spinner-hang bug has a specific required shape — a plausible variant that moves calls across the `runAsync` boundary silently hangs instead of failing fast

A new widget test for `AddCategoryModal` (Category feature build) hit the exact same "tap Save then `pumpAndSettle()` hangs on the spinner" class of bug the entry above already documents and fixed twice. The FIRST fix attempt here looked correct — tap, a single `pump()`, then `await tester.runAsync(() => Future<void>.delayed(...))` for the real-I/O delay, then a final `pumpAndSettle()` — but it hung indefinitely (confirmed by two separate stalls of 2+ minutes each with the process's CPU time genuinely flat, not by reasoning about it or a fast error).

The already-working version of this pattern (`edit_schedule_repeats_test.dart`'s `_tapAndSettle`, `exit_confirmation_test.dart`'s own copy) wraps `tap`, `pump`, the real-I/O delay, AND the final `pumpAndSettle()` all inside **one single `runAsync` block**. The broken variant split them: `tap`/`pump` ran in the normal test zone, only the raw `Future.delayed` was wrapped in its own separate `runAsync` call, and the final `pumpAndSettle()` ran back in the test zone again. Three separate zone transitions instead of one.

**Fix**: match the established shape exactly — one `runAsync(() async { tap; pump; delay; pumpAndSettle; })`, nothing outside it except the preceding `ensureVisible`/`pump()` (which are pure widget-tree operations, not real I/O, and correctly stay outside per the original pattern's own comment).

**Lesson:** when copying an established test-infrastructure workaround for a known class of bug, copy its *shape*, not just its ingredients. "Tap, pump, delay, settle, and wrap the real-I/O part in `runAsync`" sounds like a complete description of the pattern, but WHERE the `runAsync` boundary sits is load-bearing — Hive's real disk I/O hanging under `flutter_test`'s synchronous pump-based zone (the reason `runAsync` exists at all here, see the two entries above and `exit_confirmation_test.dart`'s own top-of-file comment) means a call that's supposed to be inside the real-time zone but ends up straddling the boundary can race or deadlock silently, with no assertion failure and no timeout message to point at the cause — it just hangs. When in doubt, copy the exact working helper verbatim rather than reconstructing it from a description of what it does.

## A widget test overriding `taskRepositoryProvider` with a real Hive box still needs `categoryRepositoryProvider` overridden the same way — a plain `ProviderScope` override doesn't stand in for every provider uniformly

After `Task.categoryId` was introduced and `_TaskDetailFlowState`/both category pickers started reading `categoryListProvider` on every build, four previously-passing widget-test files (`edit_schedule_repeats_test.dart`, `create_flow_initial_modal_test.dart`, `exit_confirmation_test.dart`, `task_action_sheet_remove_test.dart`) started failing with `HiveError: Box not found. Did you forget to call Hive.openBox()?`, thrown from `categoryRepository` (`category_providers.dart`) during the very first build of the sheet.

Each of these tests' `_pumpHost`-style helper already overrode `taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box))` — a real, test-local Hive box the test itself opens and closes. It looked like that same shape should cover any provider the widget tree reads, but `categoryRepositoryProvider` was never overridden at all, so Riverpod fell through to its real implementation, which calls `Hive.box<Category>(categoryBoxName)` directly — and no test ever opened a box under that name.

**Fix**: added a shared helper, `test/support/seeded_category_box.dart`'s `openSeededCategoryBox(name)`, which opens a uniquely-named `Box<Category>` and seeds it with the same 5 built-in rows `main.dart`'s real seed function would produce (deliberately bypassing that function's own `PreferenceKeys.categoriesSeeded` gate and `Task`-backfill loop, since those are launch-once production concerns these tests don't need). Every affected test's setup now opens this box, its `_pumpHost` overrides `categoryRepositoryProvider.overrideWithValue(HiveCategoryRepository(categoryBox))` alongside the existing task-repository override, and teardown closes it.

**Lesson:** adding a new provider that a widely-shared UI tree reads on every build (here, `categoryListProvider` inside `_TaskDetailFlowState.build`) is a real, silent breaking change to every widget test that mounts that tree — `flutter analyze` won't catch it (the code compiles fine), and the failure only shows up at `flutter test` runtime, as a Hive box error that looks unrelated to whatever the test is actually checking. When a new provider is added to a widget already covered by tests, grep for that widget's existing `_pumpHost`/`ProviderScope` test helpers and check whether the new provider needs the same override treatment as the ones already there — don't assume an existing override list is exhaustive just because it worked before the new provider existed.

## A bare `await` on real Hive I/O hangs under `flutter_test`'s synchronous zone even when it's NOT reached through a widget tap — a direct notifier/repository call in test setup needs `runAsync` too

`test/features/zones/zone_form_screen_test.dart` (new, for the Zone add/edit UI) hit the "Hive real disk I/O hangs under `flutter_test`'s pump-based zone" issue this codebase has already documented several times — but in a form that didn't match any of the prior write-ups, because the call causing it was never a widget tap. Two of the file's three tests hung indefinitely (confirmed by two separate ~1-2 minute stalls with the process's CPU time genuinely flat, not fast failures): one called `container.read(zoneListProvider.notifier).createZone(...)` directly (bypassing the UI entirely, deliberately, to avoid coupling the test to `AppSegmentedTimeField`'s own input mechanics), the other called `box.put(zone.id, zone)` directly in test setup to seed an existing zone before opening the edit screen.

Every prior write-up of this bug (see the two entries above) was about a `tester.tap(...)` triggering a save that then needed `runAsync`. Neither of these two calls involved a tap at all — they were plain `await someRealIoCall()` statements, written the way any other test setup line is written, with no reason to suspect they needed special handling. The actual rule is broader than "wrap the tap": ANY real Hive I/O in a widget test — regardless of how it's invoked (a tap-triggered save, a direct notifier call, a raw `box.put` in setup) — needs to run inside `tester.runAsync(...)`, because the thing that hangs is the I/O itself hitting `flutter_test`'s synchronous pump-based zone, not the specific code path that reached it.

**Fix**: wrapped both bare calls in `tester.runAsync(() => ...)`.

**Lesson**: when writing a NEW test in a codebase with this Hive-real-I/O gotcha, don't only pattern-match "is this a tap that triggers a save" — audit every real repository/Hive call in the test file (direct notifier method calls, raw `box.put`/`box.get` in setup, anything that isn't a pure in-memory operation) and wrap each one in `runAsync`, even when it looks like ordinary test setup rather than the thing under test.

## Every task save took 3-4 seconds on a real Android device — Android's 500-concurrent-alarm cap, hit by materialized recurring series, surfaced as a slow PlatformException on the save path

User-reported: editing a task and saving it — even saving with no edits at all — showed the button's spinner for 3-4 seconds before the modal closed. Not reproducible in tests (which stub the notification service), and invisible to `flutter analyze`.

Instrumented the save path with `Stopwatch` probes on a real device (moto g54, Android 14) rather than guessing. The Hive write was 18ms and the provider refresh 7ms — both irrelevant. The time was inside `zonedSchedule`, and the logcat output showed why:

```
java.lang.IllegalStateException: Maximum limit of concurrent alarms 500
reached for uid: u0a618, callingPackage: com.example.amble
```

Android caps an app at **500 concurrent alarms**. Past that, every `zonedSchedule` call throws — and building/marshalling that deeply-nested `PlatformException` across the platform channel is what took the 3-4 seconds. Every save paid it, because `TaskList`'s mutators all call `syncForTask`.

Three separate defects compounded:

1. **The alarm count was unbounded.** `_materializeSeries` scheduled an alarm for every materialized instance, and recurring series materialize an 8-week rolling window (`recurrenceWindowWeeks`). One daily series is ~56 alarms; a handful of series blows the cap. The launch-time `materializeDueRecurrences()` made this worse by re-running the whole loop on every cold start — the burst of probe output at launch is what exposed it.
2. **The save blocked on the notification sync.** `updateTask` awaited `_syncNotificationSafely`, and the detail modal only pops once that future resolves — so a side effect that is explicitly allowed to fail (the callee catches and logs) was on the critical path of the user-visible save.
3. **Nothing ever cleared stale alarms.** An install that had already hit the cap stayed wedged: the 500 slots were still occupied at launch, so every new schedule kept throwing.

**Fix** (all three, since fixing only the blocking would leave notifications silently broken):

- `_syncNotificationInBackground` — the ten mutator call sites now fire the sync without awaiting it (`unawaited`), so the modal pops as soon as the write and refresh are done. Errors are still caught and `debugPrint`ed by the callee; dropping the future means nobody waits, not that failure goes unseen.
- `notificationHorizonDays = 14` — `scheduleForTask` no-ops for anything further out, via a pure, testable `isWithinSchedulingHorizon`. Tasks are still *stored* 8 weeks ahead (the Timeline needs them); only the near window holds an OS alarm.
- `refreshScheduled` at launch calls `cancelAll()` first, then re-registers only the in-horizon tasks. The blanket cancel is what rolls the window forward *and* reclaims the slots on an already-wedged install. `_materializeSeries` no longer schedules per instance at all.

**Lesson:** a platform API's failure path can be dramatically more expensive than its success path, so an error that is correctly caught and logged can still be a severe *performance* bug — "we handle this failure gracefully" says nothing about what handling it costs. Also: a side effect that the code itself treats as optional (wrapped in try/catch, allowed to fail, not affecting the primary write) should not be awaited on a user-visible path. If it were important enough to wait for, it would be important enough to surface a failure for; since it isn't, the user should never be made to wait for it. Finally, this class of bug is only visible on real hardware with real accumulated state — a fresh test install has few enough alarms that it never trips the cap.

## [2026-09-02] Reported: recurring-task edit produced a duplicate on the same day (UNREPRODUCED — logged, not fixed)

**Reported directly**: created a task with Repeats = everyday, no category selected. Edited it afterward to set a category, saved — this produced a second task on the SAME day. The two rows could then have their durations changed independently, but changing category on one changed both. The duplicate did NOT carry the "repeats every day" rule (a one-off, unlike the original).

**Investigation this session**: traced every recurrence-editing code path (`updateTaskWithChangedRecurrence`, `updateTaskWithNewRecurrence`, `_materializeSeries`, `generateRecurrenceInstances`, `duplicateTask`) and reproduced the reported sequence — create daily/no-category, edit category only, save — at the provider level (`ProviderContainer` + real Hive box) and via a real widget test driving `showTaskDetailSheet`. **Could not reproduce the duplicate in either harness**: `updateTaskWithChangedRecurrence` consistently left exactly one row on the edited day, with the category change applied correctly. Also tried live on a real simulator with the task repository instrumented (`developer.log` on every `saveTask`/`deleteTask`, with caller stack trace) — the user could not reproduce it on that attempt either. Instrumentation was reverted (see `hive_task_repository.dart` — back to its plain, uninstrumented form) rather than left in, since it never caught the bug and doesn't belong in shipped code.

**A related, DEFINITE bug was found along the way (separate from the reported duplicate, not yet fixed)**: `TaskList.createTask` (`task_providers.dart:106`) and `TaskList.updateTaskWithNewRecurrence` (`task_providers.dart:255`) both assign `recurrenceId: _uuid.v4()` — a freshly random UUID — when starting a new series. But `findSeriesTemplate`'s own doc comment (`task_providers.dart:24-29`) and `Zone`'s own analogous pattern both assert **"a series is identified by its template's own id"**, i.e. `recurrenceId` should equal `task.id` for the template row. The current code instead gives the template a `recurrenceId` that matches NO task's own `id` — every instance (including the template) shares that series id, but nothing about the id is derived from or equal to the template's `id`. This doesn't currently break lookups (`findSeriesTemplate` searches by `recurrenceId == seriesId && isRecurrenceTemplate`, which doesn't need `recurrenceId == id` to work), but it contradicts the code's own documented invariant and is worth fixing or re-documenting — flagged, not fixed, since it's very likely unrelated to the reported duplicate (the duplicate had a real second `Task.id`, not a template/id mismatch) and the reported bug takes priority.

**A second, real, confirmed bug was found and IS worth prioritizing next**: editing a single instance of a recurring series (not the template) currently **loses that edit**. `updateTaskWithChangedRecurrence`'s own `_deleteUntouchedFutureInstances` deletes any future instance that is still `pending` with `originalScheduledAt == null` — which describes the exact instance the user just edited (editing category alone doesn't touch either field). Reproduced directly: edit a non-template instance's category, save via `updateTaskWithChangedRecurrence` → the edited row is deleted and a **freshly regenerated** row takes its slot, with the category reverted to the template's original value. This may be the real mechanism behind "category change didn't stick" reports, even if it doesn't explain the duplicate-row symptom on its own.

**Status: logged per direct instruction ("let's log issue and see if it happens again"), not fixed this session.** If it recurs, capture: (1) which screen was used to edit (full detail sheet vs. an action-sheet path), (2) whether the edited task was the template (first occurrence) or a later instance, (3) the two rows' ids/`recurrenceId`s directly from Settings' backup export (Export backup → inspect the JSON), which would immediately show whether the duplicate shares the original's `id` (impossible, Hive is keyed by id) or is a genuinely new `Task.create`-produced row (confirming `duplicateTask`, `createTask`, or `updateTaskWithNewRecurrence` fired unexpectedly).

## [2026-09-02] Follow-up: the "second, real, confirmed bug" above — FIXED

**Reported directly, independently, in different words**: "future instances if changing category, not taking effect. Only can change through original instance — but duration on the other hand updates from all instances even future ones would update the original instance." Confirmed via repository-level repro (`ProviderContainer` + real Hive box, `flutter test` on a scratch file — the environment's `flutter` CLI lock was contended by 3 live `flutter run` sessions for a long stretch this session, which had to be pointed out to the user and cleared before a run would even start) that this is exactly the bug logged above, for BOTH fields, same mechanism: `_deleteUntouchedFutureInstances` deleted the just-edited future instance (still "untouched" by the method's own `pending`/`originalScheduledAt == null` definition — editing a plain field sets neither) immediately after it was saved with the new value, and `_materializeSeries` silently regenerated a fresh copy from the template's OLD value at the same slot. The "duration updates the original instance" phrasing was the same bug seen from the other side: the edit never stuck anywhere, so every visible row — including what looked like "the original" — kept showing the template's unchanged value.

**Fix**: `_deleteUntouchedFutureInstances(template, {Task? alsoSpare})` — a new optional param, additive to the existing template exclusion, not a redesign. `updateTaskWithChangedRecurrence` now passes `alsoSpare: task` (the instance actually being edited), so the row just saved with the new field value is never a deletion candidate. `disableTaskRecurrence`'s own call site is deliberately left without `alsoSpare` — its whole documented job is "which would remove future instances" when turning Repeats off, so the instance being edited SHOULD be swept up with its untouched siblings there; sparing it there would be a behavior change nobody asked for, not a fix.

Verified before/after with a repository-level repro (edit a future instance's category, then a different future instance's duration, checking the edited row's id survives and its new value sticks) — confirmed the bug before the fix (edited row's id changed, value reverted, for both fields) and confirmed the fix (edited row's id and value both survive, template's own fields untouched either way). Added a permanent regression test, `updateTaskWithChangedRecurrence on a FUTURE instance keeps that instance's own field edits...` in `test/shared/providers/task_providers_test.dart`'s `editing recurrence from Task Detail` group.

`dart format`/`flutter analyze`: clean (same 2 pre-existing unrelated warnings only). `flutter test`: 363/363 passing (362 pre-existing + 1 new).

## [2026-09-02] "Bad state: No element" after removing a recurring template as a single occurrence — orphaned series, FIXED

**Reported directly**: "I created a task with all days repeated, and then editing and saving it duplicates. I removed the original as a single instance and have a read error, but state no element."

The second half reproduced immediately and is a real, separate bug. `removeTask`'s `RemoveScope.thisInstance` branch calls plain `TaskList.deleteTask`, which had no notion of series structure at all. Deleting the row that happens to be the series TEMPLATE therefore left every other instance still carrying the series' `recurrenceId` — so each still reported `isRecurring == true` — with **no row carrying the rule**. `findSeriesTemplate` resolves the template with a bare `firstWhere`, which throws `Bad state: No element` when nothing matches, so the next open of ANY surviving instance crashed — including from `_TaskDetailFlowState.initState`, which seeds its Repeats panel via `findSeriesTemplate(...).recurrenceRule!`. That makes every remaining occurrence impossible to even open, not just to edit.

Reproduced at the repository level: a daily series anchored today produced 57 rows; deleting the template left **56 orphans, 0 templates**, and both `findSeriesTemplate` and `updateTaskWithChangedRecurrence` threw `Bad state: No element` on the first survivor.

**Fix**: `deleteTask` now checks whether the row being deleted `isRecurrenceTemplate` and, if so, hands its `recurrenceRule` to the earliest surviving instance of the same series (`_promoteSuccessorTemplate`) before deleting. No-op when it is the series' last row, so deleting a lone template is still a plain delete. Promotion — rather than detaching every instance, or refusing the delete — preserves both the user's intent ("remove just this occurrence") and the series' own invariant that exactly one row carries the rule. `deleteTaskSeries` already handled its own equivalent case correctly (it resolves the template with an `orElse` and explicitly detaches a surviving past template), so it needed no change; this was specifically the single-occurrence path.

Two regression tests added to `task_providers_test.dart`: one asserting exactly one template survives, that it is the earliest survivor carrying the original rule, and that `findSeriesTemplate` `returnsNormally` afterwards; one asserting deleting a series' last remaining row is still a plain delete.

**Still NOT reproduced: the duplication half of the same report.** Tried, at the repository level, with the anchor both today and in the past: an all-days weekly rule (`daysOfWeek: [1..7]`) created then edited+saved with the same rule; a daily rule likewise; and a daily rule saved back as an all-7-days weekly rule (the case where the sheet rebuilds its rule from day-chips and emits `weekly[1..7]` where `daily` went in). Every variant left exactly one row on the anchor day. Note the orphan state above is now a strong candidate mechanism worth re-testing against: before this fix, a user who had ever removed a template as a single occurrence was left with a series that could not resolve a template, and any subsequent recurrence-editing path on those rows threw mid-write — after some writes had already landed. If duplication recurs AFTER this fix, capture a Settings backup export while both rows are visible and compare their `id`/`recurrenceId`/`recurrenceRule`/`originalScheduledAt`.

## [2026-09-02] Android system back gesture on task creation only closed the keyboard, not the modal — FIXED

**Reported directly**: "on task creation when nothing added no letter and swipe is done it closes keyboard only but should actually close both keyboard and modal same as Done does it in the similar scenario we have conditions for this scenario when no letter in input Done closes entire flow."

Root cause: `_TaskDetailFlow` (the live create/edit screen, pushed via a plain `Navigator.push`/`PageRouteBuilder` with no `PopScope`) had no back-gesture handling at all. The Android system back (edge swipe) reaches `Navigator.maybePop`, which pops the route directly — bypassing `_handleClose()` entirely, the same method the header's close (X) button and stage 1's "Done" both already route through. On stage 1 with an empty name, the platform's own first-back-dismisses-IME behavior swallowed the gesture at the keyboard level before it even reached the route, so only the keyboard closed.

**Fix**: wrapped the screen's `StepScaffold` in `PopScope(canPop: false, onPopInvokedWithResult: ...)`, routing every pop attempt — gesture, hardware back button, OS predictive-back — through the identical `_handleClose()` the close button uses. An empty, untouched stage-1 draft now closes silently on back, matching Done; a named/changed draft still prompts "Discard this task?" on back, matching the close button's own behavior exactly.

Only `_TaskDetailFlow` was touched — the two other classes with their own `_handleClose` copies (`_EditDetailsFormState`, `_EditScheduleFormState`) are unreferenced by the shipped app (only reachable from dev-scaffold `_main.dart` files), so out of scope.

Two new widget tests added to `exit_confirmation_test.dart`, driving the gesture via `NavigatorState.maybePop()` (the same call the system back gesture ultimately triggers): one confirming an empty stage-1 back-gesture closes the whole sheet with no dialog, one confirming a named draft's back-gesture still prompts to discard.

`dart format .`: clean. `flutter analyze`: clean (same 2 pre-existing unrelated warnings only). `flutter test`: 367/367 passing (365 pre-existing + 2 new).

## [2026-09-02] Inbox quick-capture: "Add" renamed to "Done", matching Task creation's empty-input and shape behavior

**Reported directly**: "Same on add Inbox done > Lets change add to Done and done closes entire thing and swipe native back also if not letter... button add should be rounded same as Done in adding task."

Three parts:
1. **Button relabeled "Add" -> "Done"**, confirmed via AskUserQuestion that an empty Done should behave exactly like Task creation's stage-1 Done on an empty name: closes the sheet, captures nothing, rather than the previous no-op (tapping Add with empty text just sat there). `_submit()` now pops immediately on an empty trimmed input instead of returning early with nothing.
2. **Button shape fixed to pill**, matching Task creation's own Done (`StepScaffold`'s primary button, `AppButtonShape.pill`) — the quick-capture button was using `AppButton`'s plain default (`AppButtonShape.rounded`, `theme.radiusMd`), a visibly smaller corner radius than the pill shape (`theme.radiusTaskPill`) the other Done uses. Genuinely two different shapes, not the same value read two ways — confirmed by reading both call sites before changing anything.
3. **Native swipe-back already closed correctly and needed no code change.** Unlike Task creation's screen (a plain `PageRouteBuilder` push with no back-gesture handling at all, fixed in the entry above), Quick Capture is presented via `AppSheet.show` -> `showModalBottomSheet`, whose default `isDismissible`/`enableDrag` already register the sheet as poppable by the system back gesture through Flutter's own route machinery — confirmed by reading `app_sheet.dart` rather than assumed. A swipe on an empty field was already equivalent to closing; nothing new to add.

3 new widget tests in `test/features/inbox/quick_capture_sheet_test.dart` (new file/directory — Inbox had no widget test coverage yet): button label+shape, empty-Done closes without capturing, non-empty Done still captures and closes.

`dart format .`: clean. `flutter analyze`: clean (same 2 pre-existing unrelated warnings only). `flutter test`: 370/370 passing (367 pre-existing + 3 new).

## [2026-09-02] Zone container position/style unified between Zone view and Task view

**Reported directly, three parts**: "Zone position and style should be uniform also between zone spatial and task spatial fiwes atm jumps sligtely / zone title sohuld be grey style as is the time from to / scroll level should be remembered across 2 spatial views (zone and task)... and then would be list (which is not spatial so can't replicate) and scrolling here would not affect the scroll level in memory for spatial."

1. **Position jump, fixed.** `ZoneDayTimeline`'s own zone container previously positioned at the zone's STRICT time/column position (`top: topForZoneStart(zone)`, `left: hourGutterWidth`, no inset), while `ZoneBackgroundBlock` (the same zone's rendering on the Task view) insets both by `-zoneBackgroundOffset` and trims the trailing edge by `zoneBackgroundGap` — genuinely two different formulas for the same zone. `_PositionedContainer` now applies the identical `-zoneBackgroundOffset` inset on top/left and `zoneBackgroundGap` trim on the right, reusing both constants directly from `zone_background_block.dart` rather than re-deriving them, so a change to either stays in sync automatically. New widget test `zone_day_timeline_position_test.dart` asserts the container's rendered `top`/`left` match `ZoneBackgroundBlock`'s own formula for the same zone/day/scale.
2. **Title color, fixed.** `ZoneContainerBlock`'s header title used `colorTextPrimary` while the time-range text on the same row already used `colorTextSecondary` (grey) — now both use `colorTextSecondary`, confirmed as the requested match rather than a new third color.
3. **Scroll-position scoping across List/Zone/Task, verified already correct — no change needed.** Checked `_reportViewedMinutes`/`_scrollToCurrentHourCentered` (`timeline_screen.dart`) directly: both already early-return on `!widget.showHourLabels`, which is List view's own flag — so List view never reads OR writes the shared `viewedTimeProvider`, exactly as requested. Only Task view (`showHourLabels: true`) and Zone view read/write it, matching "scrolling in list would not affect the scroll level in memory for spatial."

`dart format .`: clean. `flutter analyze`: clean (same 2 pre-existing unrelated warnings only). `flutter test`: 371/371 passing (370 pre-existing + 1 new).

## [2026-09-03] `workmanager`'s background callback runs in a fresh isolate/context with no Hive init — confirmed by deliberately triggering the failure

**Symptom (deliberately reproduced during development, not hit blind in production)**: an early draft of the morning-summary background task read `Hive.box<Task>(taskBoxName)` directly inside the `@pragma('vm:entry-point')` callback `Workmanager` invokes for a background dispatch. Threw `HiveError: Box not found. Did you forget to call Hive.openBox()?` even though `main.dart` opens that exact box on every ordinary app launch.

**Cause**: `Workmanager`'s background callback runs in a separate Dart isolate on Android, and an equivalent fresh execution context on iOS — neither one has gone through `main()`, so none of `main.dart`'s own init sequence (`Hive.initFlutter()`, `Hive.registerAdapters()`, every `Hive.openBox<T>(...)` call, the `ProviderContainer`/Riverpod tree) carries over. This is the same class of gotcha as `flutter_test`'s own real-Hive-I/O-in-a-synchronous-zone hang (see the 2026-08-20 entry above) — a background execution context that superficially looks like "just more Dart code" but is actually missing foundational setup a normal screen never has to think about.

**Fix**: the background entry point (`backgroundTaskDispatcher` → `_sendMorningSummary`, `core/background/background_tasks.dart`) redoes exactly the subset of `main.dart`'s init sequence this task actually needs — `Hive.initFlutter()`, `Hive.registerAdapters()` (guarded by `isAdapterRegistered` in case a future change makes this callback re-run without a fresh isolate), and `Hive.openBox` for only the `tasks` and `preferences` boxes (not `categories`/`zones`/`trackedBehaviors`, which this task never reads) — then reads through `HiveTaskRepository`/`HivePreferencesRepository` exactly like the main isolate does, never a raw `Hive.box<T>()` call outside a repository, matching CONSTITUTION.md's access-pattern rule even in a context with no provider tree to enforce it automatically.

**Prevent next time**: any future background-execution entry point (`workmanager`, a native background-fetch callback, an isolate spawned via `Isolate.spawn`) must NOT assume main-isolate state (Hive boxes, Riverpod providers, anything set up in `main()`) is available — re-derive exactly what that entry point needs, explicitly, and verify by deliberately triggering the failure once (comment/remove the re-init temporarily) rather than trusting "it compiles" as proof it works.

## [2026-09-03] `adb shell input tap` silently stopped registering on ANY button mid-session — an emulator/tooling issue, confirmed by reproducing it on an already-shipped, unrelated button

**Symptom**: while verifying the new Slack Settings panel on the `Amble_Test_API34` emulator, `adb shell input tap` at the correct, screenshot-confirmed coordinates for "Send test message now" produced no visible effect — no status text, no logcat output, nothing. Read as a possible real bug (bad tap coordinates, a hit-testing issue with `AppButtonVariant.secondary`'s text-only visual treatment, or a genuine failure in the button's `onPressed` wiring).

**Cause, confirmed rather than assumed**: tapping the pre-existing, already-shipped, unrelated "Export backup" button (`AppButtonVariant.primary`, a solid filled button, unambiguous target) produced the SAME non-response — no share sheet opened. Since that button has worked in every prior session (see multiple PROGRESS_LOG.md entries confirming it), this ruled out anything specific to the new Slack code and confirmed the input-delivery pipeline itself (`adb shell input tap` → the emulator → Flutter's gesture layer) had stopped working partway through the session, for reasons not further diagnosed (possibly related to the earlier `flutter run` background process losing its stdout pipe — see the session's own tool-use history — though this was not conclusively traced to a root cause).

**Fix**: stopped attempting further on-device tap verification once the pattern was confirmed environmental, and used a deterministic Flutter widget test instead (`test/features/settings/slack_summary_settings_test.dart`) — which is this project's own established stronger-evidence path anyway (see the Phase 6 entry: "a real bug found via testing, not screenshots"). The widget test drives the real widget tree, real Hive-backed repositories, and proved both the validation-error and the real-HTTP-round-trip paths work correctly, without depending on the emulator's input pipeline at all.

**Prevent next time**: when an on-device tap produces literally no observable effect — no UI change, no logcat output at all, not even from an exception — test the SAME interaction against an already-shipped, previously-verified button before concluding the new code is broken. A tooling/environment regression that silently drops touch events is indistinguishable from "my new button's onPressed is wired wrong" from the screenshot evidence alone; the differentiator is whether a KNOWN-GOOD control also stops responding at the same time.

## [2026-09-03] Zone view's "now" line invisible, and scroll position desyncing between the spatial views

Three separate bugs from one report, plus a correction to an earlier entry.

**1. Zone view's `CurrentTimeIndicator` was present but never visible.** Added in an earlier session as the SECOND child of `ZoneDayTimeline`'s Stack (right after `TaskBoundaryMarkers`). A Stack paints in child-list order, so every zone container and task capsule added after it painted straight over the line. Reported as "the zone spatial view lacks the current time line" — accurate as a symptom; the widget was there, just buried. Fixed by moving it late in the child list (just before the floating drag visual), matching the Task view's own ordering, where `CurrentTimeIndicator` likewise sits near the end.

**Prevent next time:** when a widget "isn't rendering" but is definitely in the tree, check paint order before checking the widget itself — in a Stack, position in the child list IS the z-order, and a correct widget in the wrong slot is invisible with no error anywhere.

**2. Scroll position reset after visiting List view.** `_DayTimeline` is SHARED by List view and Task view (only `showHourLabels` differs), so switching between them never remounts and `initState` never re-runs. Both the report and restore paths early-return while `showHourLabels` is false — which correctly stops List view from WRITING the shared time, but nothing restored it on the way back, so Task view simply inherited whatever raw pixel offset List view's own scrolling had left in the shared controller. Fixed in `didUpdateWidget`: re-run `_scrollToCurrentHourCentered()` when `showHourLabels` flips back ON.

**This corrects an earlier claim in this project's own logs.** A previous session recorded "scroll-position scoping across List/Zone/Task, verified already correct — no change needed," reasoning that the `showHourLabels` guards handled it. The guards do prevent List view corrupting the stored VALUE, but that was only half the requirement — nothing restored from that value afterwards, so the observable behavior was still broken. The verification checked the guard existed, not that a real List -> Task round trip preserved the position.

**3. Scroll position drifting between Task view and Zone view.** `_reportViewedMinutes` computed its base as `rangeStart.hour * 60 + rangeStart.minute`. That reads 0 in the normal case (range starts at midnight) and is silently correct — but when anything widens the range past midnight, `rangeStart` moves into the PREVIOUS day and the same expression reads 1410 (23:30) instead of -30, injecting a ~24h error into the shared value. Compounding it, the two views widen their ranges from different inputs — Task view from tasks only, Zone view from zones AND tasks — so they can genuinely disagree about `rangeStart` and therefore about what the shared number means. Fixed by anchoring both views on `rangeStart.difference(startOfSelectedDay).inMinutes`, which is correct for a negative offset and removes the coupling to each view's own range-widening rules.

**A wrong diagnosis worth recording, because the test is what caught it:** the first suspected cause was the scroll view's own 24px top padding (`theme.spacingLg`) being missing from both directions — plausible, since it converts to a different number of MINUTES at each view's own pixels-per-minute (24/1.5 = 16min vs 24/3.0 = 8min). A regression test written to prove that drift instead proved the opposite: the padding cancels itself out across a report/restore round trip, and the old formulas returned the correct minute. The padding term was kept anyway (so the reported minute matches what's actually centered on screen rather than being 24px off), but it was NOT the bug. Writing the failing-case assertion first is what prevented shipping a confident, wrong root-cause writeup.

## [2026-09-03] `initialViewedMinutes` watched instead of read — a rebuild feedback loop causing three visible symptoms at once

**Symptom, reported as three separate things**: (1) scroll position still reset going List -> Task despite an earlier fix; (2) task capsules visibly slid down from the top when switching List -> Task; (3) a "flash" switching Task -> Zone view even though the same zones/tasks were already on screen.

**Cause**: `TimelineScreen` passed the shared scroll position into both `_DayTimeline`/`ZoneDayTimeline` via `ref.watch(viewedTimeProvider)`. Every scroll event calls `onViewedMinutesChanged`, which writes that same provider — so watching it meant every scroll rebuilt the ENTIRE `TimelineScreen`, which pushed a fresh `initialViewedMinutes` value back down and re-ran `didUpdateWidget` on the child mid-scroll. That explains all three: the constant rebuild corrupted the timing of the List->Task restore (symptom 1); the rebuilds fed `AnimatedPositioned` a stream of layout changes it dutifully tweened between, reading as capsules sliding into place (symptom 2); and the same rebuild churn on the Zone side read as a flash (symptom 3, though Zone view's flash also had a second, independent cause — see below).

**Fix**: changed `initialViewedMinutes` from a plain watched value to a `readViewedMinutes: int? Function()` callback, read (`ref.read`, not `ref.watch`) only once, and called by the child only at the exact moment it needs to restore a position (mount, or a mode switch). The provider is now completely out of `TimelineScreen`'s own build graph — writing it never triggers a rebuild of anything upstream.

**Prevent next time:** a piece of "starting state" that a child reports back changes to (scroll position, form draft, anything with a write path feeding back into the same provider the parent reads) should be READ once by the parent, not WATCHED — watching it wires the child's own writes into the parent's rebuild trigger, and every write becomes a rebuild of everything downstream, not just the one thing that changed. Pass a lazy accessor (a callback) instead of the live value if the child needs to re-check it after its own last read.

## [2026-09-03] List<->Task view switch animates capsules sliding in — a real layout change wrongly treated as motion worth showing

**Cause**: `_DayTimeline` (the shared widget behind BOTH List view and Task view — only `showHourLabels` differs) positions every task capsule via `AnimatedPositioned`. List view's collapsed-stack layout and Task view's real time-axis layout compute completely different `top` values for the same task, and because switching between the two modes never remounts this widget (same element, same key), `AnimatedPositioned` correctly did its job — it tweened smoothly between two literally unrelated layouts, which reads as every capsule sliding down from the top.

**Fix**: `_DraggableTaskBlockState` now tracks a `isDraggable` change (which IS the List/Task mode signal, already threaded down as `widget.showHourLabels` at the call site) in `didUpdateWidget`, and suppresses the position animation (`duration: Duration.zero`) for exactly the one frame the mode changes on, restoring the normal eased duration immediately after via a post-frame callback. A genuine reposition within the same mode (drag, cascade push) is unaffected.

**Prevent next time:** `AnimatedPositioned`/`AnimatedContainer` et al. animate ANY change to their target values, including one caused by a structural layout-mode switch that has nothing to do with the kind of motion the animation was built for (drag settling, a cascade push). When a widget can be repositioned by two conceptually different reasons — real motion worth showing, vs. "the whole layout mode changed" — the animation needs to know which one just happened and skip itself for the latter.

## [2026-09-03] Zone view's fresh mount pops in abruptly — added a one-shot fade-in

`ZoneDayTimeline` is a genuinely separate widget from `_DayTimeline` (no shared element across the Task/List <-> Zone switch), so switching to it is always a real mount with no prior frame to ease from — every zone container, task capsule, and the hour gutter appear on the same frame. Reported as a "flash," since the content is materially the same tasks/zones Task view was just showing, so an abrupt swap read as a rendering glitch rather than an intentional view change. Fixed with a `TweenAnimationBuilder`-driven one-shot fade-in (`theme.motionNormal`, `Curves.easeOut`) wrapping the view's whole `SingleChildScrollView` — plays once on insertion into the tree, same one-shot-animation shape `TaskCapsuleBlock` already uses elsewhere in this codebase, not a toggled `AnimatedOpacity` with an ongoing target to react to.

## [2026-09-04] `flutter test` hangs past the 10-minute default timeout — two distinct causes, both toolchain-level, neither in app/test code

Hit repeatedly while trying to get a clean test run for the List-mode-clustering change. Worth its own entry since it burned most of a session and could easily be misattributed to the code under test.

**Cause 1 — a live `flutter run` holds the global tool lockfile.** Flutter's CLI serializes ALL `flutter` commands (including `--version`) behind a single lockfile at `flutter/bin/cache/lockfile`; a `flutter run` process left active in another terminal (confirmed via `lsof` on the lockfile, matching the holding PID) means every `flutter test` invocation in that same working directory queues silently — no error, no timeout message until the outer test-runner's own 10-minute cap fires — for as long as the `run` session stays open. `ps` shows the queued process as genuinely idle (0% CPU, no growth over repeated checks 6-8s apart), which looks identical to a real deadlock from the outside.

**Cause 2 — a real, reproducible self-deadlock in Dart's `hooks_runner` native-assets tooling.** Independently of cause 1, a `.dart_tool/hooks_runner/shared/objective_c/.lock` file (native-assets/build-hooks machinery for the transitive `objective_c` package) was twice observed held by the SAME `flutter test`/`dartvm` process that was itself blocked waiting on it — confirmed via `lsof` on the lock file, showing "last acquired by" the very PID stuck at 0% CPU. Clearing the lock (`find .dart_tool -iname "*.lock" -delete`) and retrying reproduced the identical hang each time under an otherwise clean, single-process environment, so this isn't just stale-lock leftover from a killed process (the project's existing documented gotcha) — it's a live self-deadlock, most likely triggered by running two `flutter test`/`flutter run` processes against the same package version concurrently (this repo's working directory is used by more than one active session).

**Prevent next time**: before diagnosing a `flutter test` hang as an app/test bug, run `ps aux | grep -i "dartvm\|flutter_tools"` and, if anything is running, `lsof` on `flutter/bin/cache/lockfile` and any `.dart_tool/hooks_runner/*/*/​.lock` file it's holding — a genuinely idle (0% CPU across repeated checks) process holding its own lock, or a `flutter run` from another terminal holding the global lock, both look externally identical to a real code-level deadlock but require zero code changes to fix. Do not kill a `flutter run` process found this way without confirming with the user first — it may be someone's live dev session.

## [2026-09-04] Recurring-series same-day duplicate after editing a non-anchor instance's own hour

**Symptom:** Editing an existing recurring task's scheduled TIME (not the day) via the detail form, with Repeats left on, occasionally left a second task on the same calendar day — same title, different hour. Not reproducible from a plain-task-turning-on-Repeats scenario (that path was independently verified correct via a passing regression test); only from editing an already-recurring, non-template instance's hour.
**Cause:** `_TaskDetailFlowState._save` (task_detail_sheet.dart) assigns `existing.scheduledAt = scheduledAt` directly on an edit, without ever touching `originalScheduledAt` — unlike the drag-reschedule paths (`TaskList.rescheduleTask`/`rescheduleTaskWithZone`), which always set `originalScheduledAt ??= task.scheduledAt` before moving a task. `generateRecurrenceInstances`' dedup check (`takenStarts`, recurrence_generator.dart) is keyed on `originalScheduledAt ?? scheduledAt` per existing instance — so an instance whose hour moved via the detail form left its OLD slot looking unaccounted-for. The next materialization pass (`updateTaskWithChangedRecurrence` → `_materializeSeries`, task_providers.dart) then regenerated a fresh row at the series' original anchor hour for that same day, alongside the user's actually-edited row at its new hour.
**Fix:** `_TaskDetailFlowState._save` now sets `existing.originalScheduledAt ??= existing.scheduledAt` immediately before overwriting `scheduledAt`, but only when `existing.isRecurring` and the time is actually changing — mirroring `rescheduleTask`'s own `??=` pattern, minus its drag-specific `status = rescheduled` side effect (irrelevant to a plain form edit).
**Prevent next time:** Any code path that assigns `Task.scheduledAt` directly on an already-persisted, possibly-recurring task must set `originalScheduledAt ??= <old value>` first — this is a Constitution-level invariant `generateRecurrenceInstances` depends on for its dedup check, not just a drag-and-drop nicety. A plain-field-only edit (category, duration, notes) does NOT need this — only a `scheduledAt` change does.

## [2026-09-04] Recurring task duplicated at the SAME time after an edit — a moved instance claimed only its vacated slot

**Symptom:** Editing a recurring task produced a second task at the same time on the same day. The original survived unchanged and the clone was new. Intermittent, and not reproducible from the paths investigated in two earlier rounds (turning Repeats on, no-op rule saves, double-tapping Save, the create flow) — all of which were tested and cleared.

**Cause:** `generateRecurrenceInstances`' dedup set, `takenStarts`, was built as `originalScheduledAt ?? scheduledAt` — one slot per instance. That field exists so a MOVED instance still claims the slot the series generated it for, stopping the vacated time being refilled. But an instance that has been moved occupies *two* slots conceptually, and only the vacated one was claimed: its NEW `scheduledAt` read as an unfilled occurrence. So moving an instance onto a time the rule also generates (e.g. nudging a daily task onto the next day's own slot) made the generator materialize a fresh instance directly on top of the task the user had just moved there.

Note this was *latent* until the same-day fix earlier that day, which started setting `originalScheduledAt` on detail-form time edits — before that, form edits left it null and the instance claimed its new slot via the `??` fallback. That fix was correct; it just exposed this second half of the invariant.

**Fix:** `takenStarts` now claims BOTH slots per instance (`originalScheduledAt` and `scheduledAt`, both null-guarded). An unmoved instance has a null `originalScheduledAt` and simply claims its own `scheduledAt`, which the Set collapses — so nothing changes for the ordinary case.

**Prevent next time:** `originalScheduledAt` is a "where this row CAME FROM" marker, not a replacement for where it is. Any code reasoning about which occurrence slots are occupied must consider both fields, not choose between them. Reproduced with a failing test first, and re-verified by reverting the fix and watching it fail again.

## [2026-09-04] Zone form Save button didn't enable while typing the name

**Symptom:** With start/end times already set, typing the zone name kept Save disabled until focus moved elsewhere (e.g. tapping back into the name field), reported directly: "need to put cursor back in focus in Name to enable btn."

**Cause:** `_canSave` (in `zone_form_screen.dart`) reads `_titleController.text`, but nothing rebuilt the widget when that text changed. The start/end `AppSegmentedTimeField`s call `setState` from their own `onChanged`, and the name field's `onFocusChanged` happens to call `setState` too — so `_canSave` only got re-evaluated as a side effect of one of those, never from typing itself. `AppTextField` has no `onChanged` callback of its own.

**Fix:** Added a listener on `_titleController` in `initState` that calls `setState(() {})`, so every keystroke re-evaluates `_canSave` directly, matching how the time fields already behave.

**Prevent next time:** Any `_canSave`-style gate that reads a `TextEditingController`'s `.text` needs either a controller listener or an `onChanged` callback wired to `setState` — a coincidental rebuild from an unrelated field is not a reliable trigger.

## [2026-09-05] `task_providers_test.dart`'s weekday-narrowing test fails on Saturday/Sunday

**Symptom:** "updateTaskWithChangedRecurrence narrowing daily down to 5 weekdays removes the now-excluded untouched future instances" fails with a leftover weekend instance in the result, but only when the test suite is run on a Saturday or Sunday.

**Cause:** The test anchors its daily-series template to `DateTime.now()` (deliberately, per its own comment, since `_deleteUntouchedFutureInstances` filters on real wall-clock time). When `now` itself falls on a Saturday/Sunday, the TEMPLATE row is anchored to that weekend day. `_deleteUntouchedFutureInstances` never deletes the template itself (`task.id != template.id`), so after narrowing the rule to Mon–Fri, the template still exists as a real, undeleted weekend-dated row — the test's own "no weekend instances survive" assertion then finds it.

**Not yet fixed** — surfaced and confirmed pre-existing (reproduces identically on unmodified `main`) while investigating an unrelated add-category-modal change; flagged rather than fixed in that session to stay in scope. Fixing it would need either the test to anchor to a known non-weekend day, or `updateTaskWithChangedRecurrence`'s own semantics for "the template's own day is now excluded by its new rule" to be decided first (currently undefined — the template is a special row that always survives regardless of rule, so this may be working as designed and the test's assertion may be the thing that's wrong).

**Prevent next time:** Any test claiming to be anchored to "the real current day" to properly exercise wall-clock-dependent logic should also account for which weekday that lands on if the logic under test treats weekdays differently — or accept the anchor day as a parameter and run it across a fixed set of weekdays in CI rather than whatever day happens to be current.

## [2026-09-05] Resting task pill's left corners still showed the old (16px) rounding after the 8px pill-radius change

**Symptom:** "all corners on elevated drag drop is ok but not on [resting] view top left and bottom left still older rounding" — the pill's rail looked correctly rounded (8px) while lifted/dragging, but its top-left and bottom-left corners looked like the old, larger rounding while resting.

**Cause:** `TaskCapsuleBlock`'s frosted lift wrapper (`Container` → `ClipRRect` → `BackdropFilter`) is ALWAYS present in the tree — a deliberate, documented choice, since building it conditionally on `isLifted` tore down the drag `GestureDetector`'s render objects mid-gesture (see this widget's own tree-shape comment, from an earlier session's "double drag needed" bug). Its `ClipRRect` was hard-coded to `radiusXl` (16), the LIFTED shape, regardless of `isLifted`. While resting the pill's rail sits flush against this wrapper's own left edge with zero padding (padding only appears as `t` animates toward 1), so the wrapper's 16px clip landed directly on top of the pill's own, now-8px (`radiusMd`) rail corner and overrode it. The right side never showed the same problem because the row's text content sits between the pill's right edge and the wrapper's own right edge, so the outer clip has nothing to visibly cut into there. This was likely already happening before the pill's radius changed to 8, just invisible: a stadium-shaped (999-radius) pill clipped at 16 still reads as "a rounded rail," so nobody noticed until the pill's own intended corner became sharper than the wrapper's fixed clip.

**Fix:** The wrapper's own radius is now animated by the same `t` (0→1 lift progress) already driving its shadow/blur/padding — `radiusMd` at `t=0` (matching the pill's own resting shape) up to `radiusXl` at `t=1` (the lifted shape). One `BorderRadius` value shared by both the `Container`'s `BoxDecoration` and the inner `ClipRRect`, so they can't drift apart.

**Prevent next time:** An always-present wrapper animating multiple properties by one interpolation value (here `t`) needs EVERY property that has a different rest-vs-lifted shape to be driven by that same value — a property left as a hardcoded constant "for the lifted case" silently also applies at rest, where it may not belong. Reproduced with a real widget test asserting the `ClipRRect`'s own `borderRadius` at both `isLifted: false` and `true`, not just a visual/golden diff — confirmed failing without the fix, passing with it.

## [2026-09-05] Bottom trim applied correctly, but landed on the wrong edge to be visible

**Symptom:** After adding `TaskCapsuleBlock.bottomTrim` (shrinking a task's pill when its end lands exactly on its zone's end, mirroring the existing top-start inset), an on-device screenshot still showed the pill flush against the zone's bottom with no visible gap — despite `bottomTrim` being correctly wired end-to-end and covered by passing widget tests. User confirmed on-device that the task's and zone's saved times were genuinely identical, ruling out the "maybe they don't actually match" theory.

**Cause:** `ZoneBackgroundBlock`'s own rendered bottom edge is already `zoneBackgroundGap` pixels above the zone's real end time (the inter-zone spacing convention — see that constant's own doc comment). The task was being trimmed by `zoneBackgroundOffset` alone, which is the SAME value as `zoneBackgroundGap` (both 4.0) — so the task's newly-trimmed bottom landed exactly on the band's already-raised edge. Both edges moved by the same amount; the gap between them stayed zero. The top case has no equivalent trap: the band's TOP lands exactly on its own start time with nothing subtracted, so insetting the task by `zoneBackgroundOffset` alone creates a real, visible gap there.

**Fix:** `_zoneTaskBottomTrim` (`timeline_screen.dart`) now trims by `zoneBackgroundOffset + zoneBackgroundGap`, matching the band's actual rendered edge rather than the zone's nominal end time.

**Prevent next time:** When mirroring a "gap against edge A" fix onto edge B of the SAME decorative container, check whether the container's OWN rendering already offsets that specific edge before assuming the same single constant will produce the same visible result — verify against the container's real rendered rect (as this fix's regression test now does: two widgets, both real, measured against each other), not just against the nominal time/value the edge is supposed to represent. Two independently-named constants sharing a numeric value by coincidence (here `zoneBackgroundOffset` and `zoneBackgroundGap`, both 4.0) makes this kind of bug especially easy to miss by code inspection alone, since `x - offset` and `x - offset - gap` don't visibly look wrong until you work through which pixel each one actually lands on.

## [2026-09-05] Pill-radius token drift recurred after the token itself was intentionally changed

**Symptom:** After the [2026-09-05] "resting task pill's left corners" fix above shipped (wrapper animates `radiusMd` at rest up to `radiusXl` lifted, matching the pill rail's own `radiusMd`), the user separately edited the pill rail's own radius token from `radiusMd` to `radiusSm` (a legitimate design change — smaller rounding, requested directly). Reported again immediately after: "affected 3 corners sometimes t2, but not top left and bottom left corner (still larger than set)" — the exact same symptom as the original bug, on the same two corners.

**Cause:** The wrapper's own `t=0` anchor (`theme.radiusMd`) was a hardcoded value copied from the pill rail's radius AT THE TIME of the original fix, not a live reference to whatever the pill rail actually uses. When the pill rail's own token later changed to `radiusSm`, the wrapper's anchor didn't move with it — silently reintroducing the identical "wrapper's clip radius disagrees with the pill's own corner" mismatch the original fix existed to prevent, just between two different token names instead of two different corners. A separate, second bug in the same expression compounded this: the interpolation slope read `theme.radiusXl - theme.radiusSm` instead of `theme.radiusXl - theme.radiusMd` — correct at `t=0` by coincidence (the formula's base term was `radiusMd`, canceling the slope's `-radiusSm` only at the specific old values in play) but wrong at `t=1` regardless, undershooting the intended lifted radius.

**Fix:** Both anchor and slope in the wrapper's radius formula now read `theme.radiusSm` (matching the pill rail's own current token exactly), so `t=0` = pill's own radius and `t=1` = `radiusXl`, whatever either token's value happens to be.

**Prevent next time:** Any place that copies "the pill's own radius" as a literal token name into a SECOND location (here, the frosted wrapper's rest-state anchor) is a duplicate that can drift the moment the first location's token changes — there's no compiler error for this, only a re-report of the same visual bug. When intentionally changing a token used in one place specifically because another place is documented as "must match," grep for every other reference to the old token in the same file/class before considering the edit done. The regression test added for the original bug (asserting the wrapper's rest radius against a literal `theme.radiusMd`) still passed right up until this report, because it hardcoded the SAME stale token the production code did — updated now to read `theme.radiusSm`, matching the fix.

## [2026-09-05] List mode's split layout showed no time at all — a flag whose old meaning outlived its old use case

**Symptom:** After wiring List mode's task rows to use the same split layout (icon rail + shared text column) Task view already has, the time was completely invisible in List mode — "U sure time is shown? cant see it (on list mode)."

**Cause:** `TaskCapsuleTextRow` (the shared text column both views' split layout render into) has always hidden its ENTIRE time-range text — not just the `(Xm)` duration suffix — whenever its `durationVisible` param is false, per an explicit, deliberate design documented in its own doc comment: "the time and duration columns disappear together... the title then takes the full width (the mock's left-hand screen)." That was written for one specific old Task-view mock where hiding time entirely was the intended look. `durationVisible` is driven by `DevTimelineTaskDurationVisible`, a dev-scratch toggle whose default was separately changed to `false` in an earlier session ("no duration shown — requested directly"), with nobody at the time realizing that flag's `false` state fully blanked the time text too, not just a duration suffix — because until this List-mode change, nothing exercised `TaskCapsuleTextRow` with that default active in a context where losing the time was actually a problem. The moment List mode started using the same shared component, its "no timeline axis at all — time is the only place a schedule reads" requirement collided with a years-old, differently-scoped default.

**Fix:** Added a separate `alwaysShowTime` param to `TaskCapsuleTextRow` (default false, preserving Task view's existing behavior exactly) that forces the time range visible regardless of `durationVisible` — the duration suffix itself stays independently gated by `durationVisible` alone, now correctly split into its own `if` rather than sharing the outer one. Wired `alwaysShowTime: widget.compactText` at the one call site in `timeline_screen.dart` (`compactText` is `_DraggableTaskBlock`'s own existing "true in List mode" signal), rather than changing `durationVisible`'s meaning for both views — confirmed directly, since Task view's split layout should keep its current dev-toggle-driven look unchanged.

**Prevent next time:** A boolean parameter's name ("durationVisible") can quietly mean something broader than it says ("also hides the time it's supposedly independent of") when it was written for one specific caller/mock and later reused by a different one with different requirements. Before wiring an existing shared widget into a NEW context, read what each of its flags actually gates in the widget's own body — not just what its name and doc comment claim at a glance — especially when that widget's doc comment cross-references "the mock" as the source of truth for a design choice that may not apply to the new caller at all.

## `AppSelectableChip` stretches to full width inside a `Wrap`

**Symptom** (found on-device, not by any test): the TaskTemplate form's category chips rendered one per row, each spanning the full pane width, instead of flowing onto shared lines — even though the task detail sheet's own Category pane, using the same `Wrap` inside the same `AppPane`, wraps correctly.

**Cause**: `AppSelectableChip`'s inner `Container` sets a height and `alignment: Alignment.center` but no width. Under LOOSE constraints — which is exactly what a `Wrap` hands its children — an aligned `Container` expands to the full available width. Every pre-existing caller places the chip inside a `Row` (day-of-week chips wrapped in `Expanded`, duration presets intrinsic), where that never happens, so the component's own doc comment ("no fixed width … leave it intrinsic") is true for `Row` and misleading for `Wrap`. The task detail sheet's Category pane does not hit this because it uses its own `_CategoryTag`, not `AppSelectableChip`.

**Fix**: wrap each chip in `IntrinsicWidth` at the `Wrap` call site (`features/inbox/task_template_form_panes.dart`), sizing it to its label. Deliberately fixed at the call site rather than by changing `AppSelectableChip` itself — every existing `Row` caller depends on the current expand-to-fill behaviour, and altering the shared component to suit one new caller would have been a change well outside this session's scope.

**Lesson**: a shared widget verified only in one layout parent is not verified for a different one. Constraint behaviour (`Row` tight/flex vs. `Wrap` loose) is exactly the kind of assumption that survives the first dataset and breaks on the second — the same pattern CLAUDE.md's "verify against a SECOND, genuinely different dataset" rule names.

**Also noted, not a bug**: an early attempt at this blamed a nested `SingleChildScrollView` (the form added one inside `AppSheetSize.half`, which already provides its own). Removing the redundant nesting was correct on its own merits and was kept, but it was not the cause — the chips still stretched afterwards. Recorded so a future session doesn't re-chase that explanation.

## `AppSheet` does not account for the keyboard — a focused field or the Save button can sit under the IME

**Symptom** (found on-device while verifying the TrackedBehavior form): with the soft keyboard up, the sheet's lower fields ("Minimum", "Times per week") and the Save button are covered by the IME, with no way to scroll them into view. On a form long enough to reach under the keyboard, it cannot be completed without dismissing the keyboard first — and dismissing it via the system back gesture closes the whole sheet, losing the entry.

**Cause**: `AppSheet.show` sizes its content purely from `MediaQuery.sizeOf(context).height` (`* 0.5` for `AppSheetSize.half`, `- spacingXl` for `nearFull`) and never reads `MediaQuery.viewInsets.bottom`. The sheet therefore keeps its full height while the keyboard overlays the bottom of it, and `AppSheetSize.small` — which sizes to its child with no scroll view at all — has no way to reveal the covered part either.

**Status: NOT fixed.** `AppSheet` is a shared core widget with many callers (the tracked-behavior form, the TaskTemplate form, the category picker, the duration modal, the remove-scope sheet), so changing its sizing affects every one of them and is a change well outside the scope of the session that found it. Flagged for a dedicated pass rather than patched as a drive-by.

**Whoever fixes it**: the shape is a `viewInsets.bottom` padding on the sheet's content plus a scroll view for the `small` size, verified against every existing caller — a short sheet must not gain a scrollbar or change height when the keyboard is closed. Worth checking the TaskTemplate form (`features/inbox/task_template_form.dart`) at the same time: it has the same field-count profile and almost certainly the same problem.

**Lesson**: a form verified only with pre-seeded data, or only in a widget test, is not verified for real entry — the keyboard is part of the layout on a device and part of nothing in a test. This one was invisible until a real typing pass on a real emulator.

## Timeline widget tests with fixed-hour task fixtures are time-of-day flaky

**Symptom**: `multi_task_selection_test.dart`, `multi_task_group_move_test.dart`, and `multi_task_group_resize_test.dart` (10 tests total) fail with `tester.tap()`/`tester.drag()` hit-test misses, or wrong-value assertions, depending on what real wall-clock time the suite happens to run at (first observed failing at 16:54 local time; passes at other times of day).

**Cause**: these tests build fixture tasks at hardcoded hours (`hour: 9`, `12`, `13`) and never supply `readViewedMinutes` to pin the timeline's scroll position. `TimelineScreen`'s real `_scrollToCurrentHourCentered` (`timeline_screen.dart`) centers the initial scroll on `DateTime.now()`'s time of day, by design ("should always lead to the current hour being in the center" for a fresh day). When "now" is far from the fixture hours, the fixture tasks land off-screen and any tap/drag against them misses.

**Not caused by** the same-day `DevZoneViewInCycle`/`DevMultiTaskEditMode` default flips (see DECISIONS.md) — confirmed by temporarily shifting the fixture hours to near the real current time, which made all 6 `multi_task_selection_test.dart` cases pass unchanged otherwise, then reverting that probe edit. These tests would have failed identically at this same time of day with both flags at their old defaults too.

**Status: NOT fixed.** Pre-existing test-fixture bug, out of scope for the session that found it (a two-line default flip). Whoever picks this up should have `pumpTimeline` supply a fixed `readViewedMinutes` (or an injectable "now") so fixture hours and scroll-centering can't drift apart — same shape as `zone_move_end_to_end_test.dart`'s own zone, which sidesteps this by anchoring to the current real hour instead of a fixed one.

**Prevent next time:** a widget test asserting on-screen visibility of a fixture built at a fixed clock hour is implicitly asserting something about the real wall-clock time the suite runs at, whenever the screen under test has any "scroll/center on now" behavior. Either anchor fixtures to `DateTime.now()` (like the zone test does) or pin whatever reads "now" for that screen.

**Wider than first scoped**: recurred again later the same day, running at 23:44 local time instead of 16:54 — this time hitting `zone_move_end_to_end_test.dart`/`zone_task_view_move_resize_test.dart` (both anchor their own zone to the CURRENT real hour, `now.hour * 60`, specifically to avoid the fixed-hour version of this bug — but `+ 60 minutes` off a zone anchored at 23:00 overflows past `24 * 60`, the day's own hard boundary, and the move/resize commit's existing "never past midnight" guard silently rejects it) and `notification_service_test.dart`'s `scheduleForZone` "upcoming" cases (a fixed hour assumed to be later than "now" stops being true once that hour has already passed today). Same root cause family — a fixture's relationship to "now" was assumed stable but isn't — just a different collision (day-boundary overflow, "upcoming" no longer being upcoming) than the original scroll-centering one. None of these are caused by whatever feature work happened to be running when the clock crossed the trigger point; each is a pre-existing, dormant bug in the fixture's own assumptions about wall-clock time, confirmed by checking the exact failing values (e.g. `startMinutes: 1380`/`endMinutes: 1440` — 23:00/midnight) against the real system clock at run time.

## Changing a recurring task's TIME silently created a whole parallel series

**Symptom** (reported directly, found on-device): "see duplicates, sometimes even 2" — the same recurring task appearing two or three times on a single day, despite Duplicate being a hidden feature. Reported triggers: "perhaps restarting app", "used to hapepen after saving", "perhps moving things around".

**Diagnosed from a real exported backup** (`amble-backup-2026-09-07T01-50-30-105345.json`), not reproduced by guesswork:
- 651 tasks, all IDs unique — genuinely distinct rows, so not a rendering bug.
- 117 groups sharing one `recurrenceId` on one calendar day; 232 extra rows.
- One daily series ("Stretching", a single `recurrenceId`) held **three complete parallel 56-day generations** at 05:00 / 06:30 / 07:05, all spanning the same date range. "Walk" likewise, at 04:25 / 05:00 / 05:15.
- Every stranded row was `pending` with `originalScheduledAt == null` — i.e. fully prunable, so the prune simply never ran on the path that created them.
- Simulating the generator against the real data: one 07:05 → 08:00 template edit yields **59 occurrences, 59 unclaimed → 59 brand-new rows**, zero overlap with the existing 175.

**Cause — two faults compounding:**

1. `generateRecurrenceInstances` (`recurrence_generator.dart`) decided "is this occurrence already materialized?" by matching an exact `DateTime` against a `Set` of existing `scheduledAt`/`originalScheduledAt` values, while the occurrence grid itself is anchored to `template.scheduledAt`'s **time of day**. Move that time and every slot shifts, so *none* of the already-materialized rows match any more and the entire window regenerates.

2. `updateTaskWithChangedRecurrence` (`task_providers.dart`) updated `template.recurrenceRule` but **never `template.scheduledAt`**. So an "all future occurrences" time edit never reached the series: the template stayed at the old time, `_materializeSeries` regenerated the window back at that old time, and the edited instance was left stranded at the new one. Its own doc comment even claimed a same-days save "round-trips harmlessly" — true only if the time hadn't changed.

`materializeDueRecurrences` (called from `main.dart` on every launch) then re-ran `_materializeSeries` with **no prune at all**, so any anchor drift refilled the whole window again on each restart — which is why it looked like restarting caused it.

A third, smaller fault fed the same machine: `_EditScheduleFormState._save` overwrote `existing.scheduledAt` with no prior capture, so `updateTaskThisInstanceOnly`'s `originalScheduledAt ??= scheduledAt` recorded the **new** time as the "original". The vacated slot then went unclaimed and got refilled. Three rows in the backup carry this signature (`originalScheduledAt == scheduledAt`). The other save path (`_TaskDetailFlowState`) already had the correct guard — the two copies of this logic had drifted apart.

**Fix:**
- Generator now matches occupancy **per calendar day per series**, not per exact `DateTime`. A day already occupied by any instance can never be refilled, whatever time its occupant sits at — which also makes the prune-free launch top-up structurally safe. Valid because `RecurrenceFrequency` is only `daily | weekly` and sub-daily is deferred in SCOPE.md; flagged in-code that a future twice-daily rule would need `(day, occurrence-index)` instead.
- `updateTaskWithChangedRecurrence` now detects a re-anchor (time-of-day or duration differing from what the series currently generates) and rewrites the template's own time/duration, then realigns every occurrence from the edited day forward via `_deleteFutureInstancesForRealign`.
- Re-anchor detection compares against **sibling instances**, not the template's own stored fields: Hive's `get` returns the same live object the caller already mutated, and the edited task is very often the template itself — so any before/after comparison against it trivially reads "unchanged" and the realign would never fire. This was caught by a test that failed for exactly this reason, not by inspection.
- `_EditScheduleFormState._save` gained the missing capture guard.

**Data repair**: `tool/dedupe_recurring_backup.py` repairs an exported backup (dry-run by default). Keeps completed/skipped rows first, then genuinely moved ones, then the row matching the template's anchor. On the real backup: 651 → 419 tasks, 232 removed, 0 duplicates left, all 14 non-recurring tasks and all categories/zones preserved.

**Prevent next time:** a dedup key must be as coarse as the thing it protects against. Keying occupancy on an exact `DateTime` silently assumes the occurrence grid never moves — but the grid is derived from a field the user can edit, so the key and the generator disagreed the moment anyone changed a time. When a "does this already exist?" check is derived from mutable input, the check has to be invariant to the mutations that input actually undergoes. Equally: two copies of the same save logic (`_TaskDetailFlowState` and `_EditScheduleFormState`) drifted apart, and only one had the guard — the duplicated logic is itself the defect.

## Imported-event titles sat 56px left of native task titles — a test that agreed with the bug

**Symptom** (reported directly, from an on-device screenshot): imported calendar events' titles and pills did not line up with native tasks' on the Spatial Task View, despite the widget having been built specifically to match them.

**Cause**: `ExternalEventCapsuleBlock` returned an outer `Positioned(left: 0, right: 0)` spanning the full row, then placed the rail at an absolute `left` and the text at a bare `textColumnLeft`. The native path (`_DraggableTaskBlock._buildSplit`) instead uses ONE outer box at `left` (the hour gutter's width, 56) with both the rail and the text column positioned *relative* to it. So the rail landed correctly by coincidence — `0 + left` happens to equal `left` — while every title lost the gutter offset entirely and rendered 56px too far left.

**Why the existing test missed it**: the cross-widget alignment test pumped `TaskCapsuleTextRow` at a bare `Positioned(left: textColumnLeft)` — i.e. it reproduced the *same wrong origin* on the native side too. Both sides were 56px off, they agreed, and the test passed. It was asserting that the widget honours the value handed to it, never what the real caller actually supplies. The other positioning test was weaker still: it asserted on `Positioned.left` **widget properties** rather than rendered geometry, which cannot see a wrong parent origin at all.

**Fix**: `ExternalEventCapsuleBlock` now mirrors the native structure — outer `Positioned(left: left, right: 0)`, rail at `left: 0`, text at `left: textColumnLeft`. Both tests were rewritten to assert **absolute on-screen positions** via `tester.getTopLeft`, and the cross-widget one now replicates the native path's real nesting. Verified by reverting the fix: both tests fail without it, pass with it.

**Prevent next time:** a test that constructs both sides of a comparison by hand can encode the same mistake into both and still pass. When asserting that two widgets agree, at least one side must be built the way production actually builds it — otherwise the test proves only that the two fixtures match each other. And assert on rendered geometry (`getTopLeft`), not on layout-widget properties: `Positioned.left` is an input to layout, not the result of it, so it says nothing about where a subtree's origin actually is.

## [2026-09-07] External calendar events had their own parallel positioning pipeline, hiding a stacking-parity gap

**Symptom:** Reported directly: "the imported tasks should also stack in the same way as native tasks... They just can't be moved, changed, or have their duration, time, or name updated, but otherwise exactly the same, with different styling." An overlapping task and imported event rendered independently, each unaware of the other — no shared lane, no shared cluster — even though the pure layout algorithms (`layoutOverlappingTasks`, `detectOverlapClusters`) looked like the obvious place stacking already happened.
**Cause:** Earlier in this project's Calendar feature work, external events were deliberately routed around those two algorithms via a second, fully independent pipeline inside `timeline_screen.dart`: their own top/height computation, their own List-mode stacking-cursor entries, their own render loop (`for (final event in widget.externalEvents) ExternalEventCapsuleBlock(...)`). That was a reasonable choice at the time (events needed no lane/cluster awareness, since nothing required them to interact with tasks positionally) — but it meant the two pure algorithms being `Task`-only was never actually the whole story; genuine parity required deleting that second pipeline outright, not just generalizing the algorithms' input type.
**Fix:** Introduced a minimal `ScheduledBlock` interface (`id`, `scheduledStart`, `scheduledEnd`) implemented by both `Task` and `ExternalCalendarEvent` — deliberately narrow (positioning only, no status/category/completion), so implementing it does not make an event editable. Generalized `TaskLayoutSlot`/`layoutOverlappingTasks` and `OverlapCluster`/`detectOverlapClusters` from `List<Task>` to `List<ScheduledBlock>` (keeping `.task`/`.tasks` as nullable/filtered convenience getters so every task-only call site kept compiling). Then deleted the old parallel event pipeline entirely and routed events through the same `slots`/`clusters` tasks use — including `_collapsedTops`, which changed from returning two separate maps (`taskTops`/`externalEventTops`) to one unified map, since a shared stacking cursor can no longer be split back apart after the fact.
**Prevent next time:** When a new block type is added to Timeline that deliberately reuses only PART of a task's behavior (styling but not interaction, e.g.), check whether it was given its own parallel pipeline for positioning rather than sharing the real one — a working "position it independently" implementation can look complete while quietly excluding that type from every task-only layout algorithm. If two types are ever asked to visually coexist (shared lanes, shared clusters), a parallel pipeline is the wrong shape from the start; a shared interface covering only the properties actually needed (here, just start/end/id) is safer than either duplicating the algorithm or wrapping the foreign type in a fake `Task`.

## [2026-09-07] A test's `Positioned` wrapper duplicated a widget's own internal positioning, colliding two different `top` computations

**Symptom:** Self-caught before running: the first draft of the unified event-slot render branch in `timeline_screen.dart` wrapped `ExternalEventCapsuleBlock` in an outer `Positioned(top: blockTops[event.id]!, ...)`.
**Cause:** `ExternalEventCapsuleBlock` already builds its own outer `Positioned` internally, computing `top` from either `collapsedTop` (List mode) or real elapsed-time math (Task view) — never from the caller-supplied `blockTops` map at all. The redundant outer wrapper's `top` and the widget's own internal `top` disagreed silently (no error, no exception — just two nested `Positioned`s, the inner one winning), which would have been very hard to notice from a screenshot alone since the values are close for a normally-scheduled event.
**Fix:** Removed the outer `Positioned`; the render branch now configures `ExternalEventCapsuleBlock` directly (key, `left`, `collapsedTop`, etc.) and lets it position itself, exactly like every other caller already does.
**Prevent next time:** Before wrapping any widget in a fresh `Positioned`/layout wrapper "to be safe," read that widget's own `build()` first — a widget that already returns its own top-level `Positioned` (common for anything absolutely placed inside a `Stack`) should never be wrapped in a second one; pass position data through its own parameters instead.

## [2026-09-07] An event's lane offset baked into the outer box shifted its title too, not just its rail

**Symptom:** Reported directly from a screenshot after shipping task/event lane-sharing parity: "text not aligned wit hnative tasks. all tasks text should be aligned to same x." A task's title and an overlapping event's title, both meant to share one text column, landed at visibly different x positions.
**Cause:** `ExternalEventCapsuleBlock`'s `left` parameter was computed as `hourGutterWidth + pillBoxLeftForColumn(column: slot.column, ...)` — the lane offset baked directly into the outer box's position. Since the widget's text column (`textColumnLeft`) is positioned RELATIVE to that same outer box, an event landing in a non-zero lane (e.g. because it now overlaps a task, per the new stacking parity) dragged its title along with it. `_DraggableTaskBlock` (the real task's own equivalent) never has this problem: its outer box's `left` is always the FIXED day-column origin (`hourGutterWidth`), and the lane offset is applied only to the inner rail via a separate `columnOffset`, leaving the text column's absolute x untouched regardless of lane.
**Fix:** Added a `columnOffset` parameter to `ExternalEventCapsuleBlock`, applied only to the rail's own `Positioned`, and reverted `left` to the fixed day-column origin — mirroring `_DraggableTaskBlock`'s own `left`/`columnOffset` split exactly. `timeline_screen.dart`'s call site updated to pass the two separately instead of pre-combining them.
**Prevent next time:** When a widget's box carries both a "shared, lane-independent" child (a text column meant to line up with every sibling regardless of overlap) and a "per-lane" child (a rail/pill that must shift with its own column), the lane offset must be applied to ONLY the per-lane child's own position — never folded into the outer box's origin, even though that looks equivalent for a lane-0 item. The existing alignment tests for this widget passed throughout, because every one of them used `columnOffset`-equivalent 0 (an unclustered event) — a test asserting title-x invariance specifically across DIFFERENT lane offsets (not just different `textColumnLeft` values) is the only kind that would have caught this before a screenshot did.

## [2026-09-07] A pushed Navigator route can never leave the route below it interactive, no matter how it's configured

**Symptom:** Building the tap-empty-space quick-create feature, a small (~25%-height) sheet was pushed as a `Navigator` route with `barrierColor: null` (no scrim), reasoning that with no barrier, Timeline underneath — including a draggable placeholder pill — should stay interactive. It didn't: a widget test driving a drag on the pill while the small sheet was "open" silently did nothing (`onVerticalDragUpdate`/`onPanUpdate` never fired), with no error or warning.
**Cause:** Confirmed via a real hit-test trace (`tester.tap(..., warnIfMissed: true)` reporting a hit-test miss with the render chain printed): a `RenderAbsorbPointer` was swallowing the pointer at the pill's exact location. This is `ModalRoute`/`_ModalScopeState`'s own machinery — every route below the topmost one in the `Navigator`'s stack is unconditionally wrapped in an `AbsorbPointer`, entirely independent of that route's own `barrierColor`/`opaque`/`barrierDismissible` settings. There is no route-level configuration that opts out of it — `opaque: false` only affects whether the route paints behind it (visually see-through), not whether pointer events reach behind it.
**Fix:** The small sheet was rewritten as a plain in-tree overlay widget (`QuickCreateOverlay`) living directly inside the same widget subtree as the pill (Timeline's own `Stack`), with no `Navigator.push` involved at all until the user actually expands it — at which point a REAL route push is correct and wanted (matching every other entry point into that flow). Only once promoted does `AbsorbPointer` correctly kick in.
**Prevent next time:** If a design ever calls for "a modal-looking panel that still lets you interact with what's behind it," that is fundamentally incompatible with `Navigator.push`/`ModalRoute` — pick a plain overlay (a `Stack` child, an `OverlayEntry`, or app state gating what renders) instead, regardless of how tempting it is to reach for a route with a transparent/null barrier. A widget test asserting a gesture doesn't fire is easy to misread as "my callback logic is wrong" — when a drag/tap genuinely produces zero effect with zero errors, check `tester.tap(..., warnIfMissed: true)`'s hit-test trace for an unexpected `AbsorbPointer`/`IgnorePointer` before suspecting the gesture-handling code itself.

## [2026-09-07] A move-drag GestureDetector missing `onVerticalDragStart` didn't reliably win the gesture arena against a scrollable ancestor

**Symptom:** `PendingTaskPill`'s own move-drag `GestureDetector` (`onVerticalDragUpdate`/`onVerticalDragEnd`, no `onVerticalDragStart`) worked fine in an isolated widget test, but inside the real `TimelineScreen` (where the pill sits inside a `SingleChildScrollView`, the scrollable day column), a manual test gesture sequence (`startGesture`/`moveBy`/`up`) produced `onVerticalDragEnd` but NEVER `onVerticalDragUpdate` — no error, the callback simply never fired, even though the exact same gesture shape worked in isolation.
**Cause:** The real `_DraggableTaskBlock` (dragging an actual task) wires all three — `onDragStart`/`onDragUpdate`/`onDragEnd` — onto its own move detector. `PendingTaskPill`'s detector had only update/end. Missing `onVerticalDragStart` changed how the `GestureDetector`'s underlying `VerticalDragGestureRecognizer` claimed the gesture arena early against the `Scrollable`'s own competing vertical-drag recognizer (the day column it's nested inside) — without a start callback, the recognizer didn't accept the drag decisively enough, and the scrollable effectively absorbed the move phase while still allowing the end event through.
**Fix:** Added `onMoveStart` (even a no-op `(_) {}` at the call site) to `PendingTaskPill`, wired to `onVerticalDragStart` on the same detector — matching `_DraggableTaskBlock`'s own three-callback shape exactly.
**Prevent next time:** Any new draggable widget nested inside a `Scrollable`/`SingleChildScrollView` should wire all three vertical-drag callbacks (`start`/`update`/`end`), not just update/end, even if `start` has nothing to do — omitting it is a silent, hard-to-diagnose gesture-arena loss against the scrollable ancestor, not a compile-time or runtime error.

## [2026-09-07] `flutter test`'s synthetic gesture sequence needs a `pump()` between EVERY step against a live TimelineScreen, not just before release

**Symptom:** A widget test driving a manual drag (`tester.startGesture` → `gesture.moveBy` → `gesture.up`) against the real `TimelineScreen` produced `onVerticalDragStart`/`onVerticalDragEnd` but never `onVerticalDragUpdate` — even after fixing the missing-`onVerticalDragStart` gotcha above. The identical sequence against an isolated single-widget test (no surrounding `TimelineScreen` tree) worked correctly with just one `pump()` between the move and the release.
**Cause:** Not fully root-caused, but empirically: in the full `TimelineScreen` tree (many more concurrently-ticking things — `EditModeWiggle`'s continuous animation, a `Timer.periodic` for the current-time indicator, multiple nested scrollables/`AnimatedBuilder`s), a single `moveBy` call without an interleaved `pump()` immediately after it did not get processed into a delivered `onVerticalDragUpdate` before the subsequent `up()` call effectively finished the gesture out from under it.
**Fix:** Interleave `await tester.pump()` after `startGesture`, after every individual `moveBy` call, and after `up()` — not just once before checking assertions. Splitting one large `moveBy` into a few smaller ones (each followed by its own `pump()`) made the fix reliable; a single big `moveBy` even with a pump immediately after did not.
**Prevent next time:** When writing a new widget test that manually drives a drag gesture against the real, full `TimelineScreen` (not an isolated single-widget harness), default to pumping after every single gesture call (down, each move, up) rather than assuming the isolated-widget-test pattern (one `pump()` before release) will transfer unchanged — it doesn't reliably. `tester.drag()`'s own internal implementation has this same gap (no pumps between its internal steps), so it isn't automatically safer than a manual sequence in this specific context.

## Geometry assertions are meaningless on a zero-inset test viewport

**Symptom**: a regression test for "the mini sheet doesn't reach the bottom edge" passed both with AND without the fix.

**Cause**: the default `flutter_test` viewport has a zero bottom safe-area inset. The bug was a doubled `SafeArea` on the bottom edge, so with no inset it added zero padding and the sheet was flush either way. The bug only reproduces on a device with a home indicator.

**Fix**: set a real inset before pumping, and reset it after:
```dart
tester.view.viewPadding = const FakeViewPadding(bottom: 34);
tester.view.padding = const FakeViewPadding(bottom: 34);
addTearDown(() { tester.view.resetViewPadding(); tester.view.resetPadding(); });
```

**Rule**: any assertion about safe areas, insets, or bottom/top-edge geometry must run against a viewport that actually has the inset. Always confirm such a test fails with the fix reverted — a geometry test that has never been seen red is not evidence.

## "Known flaky" absorbed a real regression for two sessions

**Symptom**: two `multi_task_group_resize_test.dart` tests failed every run; two consecutive PROGRESS_LOG entries recorded them as "pre-existing flaky `multi_task_group_*` failures, zero regressions."

**Cause**: they were a genuine break introduced by the top-edge resize handle. `handleFor()` found a handle via `find.byType(ResizeHandle)`, which matched one widget until a second (top) handle began rendering; `tester.drag` then threw on the ambiguity before any resize ran. The failures showed as durations simply never changing — which reads like "the feature did nothing," not like flake.

**Fix**: target `.last` (the bottom handle — `TaskCapsuleBlock` renders top-first); group resize is bottom-edge-only by decision.

**Rule**: re-verify a "known flaky" label whenever the code beneath it changes, and read the failure before reusing the label. A test failing identically across sessions is a real defect until someone actually reads the output. When adding a second instance of an existing widget, grep the suite for `byType(<Widget>)` finders that assumed exactly one.

## A Hive write inside a widget test hangs the test — or its teardown

**Symptom**: a widget test that seeded a template produced no output and never returned. No exception, no failure — just a hang, which reads as a stuck runner rather than a test bug.

**Cause**: a Hive write started inside a widget test's own fake-async zone never completes. `await box.put(...)` in the test body hangs on the spot. Dropping the await (`unawaited(...)`) does NOT fix it — it just relocates the hang to teardown, where `box.close()` waits on that same pending write. Both were observed here, one after the other.

**Fix**: wrap the write in `tester.runAsync`, which escapes the fake clock:
```dart
await tester.runAsync(() => templateBox.put(template.id, template));
```
`create_flow_template_browser_test.dart` already did exactly this; `template_list_view_test.dart` gets away with a bare `await` only because it seeds outside a `testWidgets` body.

**Rule**: any real async I/O inside `testWidgets` goes through `tester.runAsync`. Also: seed providers that read at build time (`taskTemplateListProvider` calls `getAll()` in `build()`) BEFORE pumping — a row written afterwards never appears.

## The meta-lesson: accepting evidence that can't distinguish working from broken

Four separate defects in the quick-create work traced to one root cause — a check was run, it came back green, and the green could not have gone red even if the code were wrong. Recorded together because the individual entries below each read as unrelated bad luck, and they are not.

The instances:
1. **A pushed route was assumed non-modal** because it was configured to look that way. One hit-test trace disproved it (`AbsorbPointer`, see that entry). Reasoning about framework behaviour stood in for testing it.
2. **A bottom-inset regression test passed with the fix reverted** — the default test viewport has a zero bottom inset, so the doubled `SafeArea` added zero padding either way.
3. **Two genuinely-broken tests were labelled "known flaky" for two sessions** and written up that way in PROGRESS_LOG twice, without the failure output being read once.
4. **Suite results were written into PROGRESS_LOG before the suite exited**, twice, and had to be corrected.

The rule, in the order worth applying it:
- **Before trusting a test, make it fail.** Revert the fix, watch it go red, restore. A test that has only ever been green is an assertion about nothing. This is cheap and catches (2) and most of (1).
- **An environment-dependent assertion must run in an environment that has the thing.** Insets, safe areas, keyboards, time zones, device pixel ratios — the default test surface has none of them.
- **"Known flaky" expires whenever the code under it changes.** A test failing *identically* every run is a defect; flake is random. Read the output before reusing the label.
- **Never write a verification result before the command exits.** Not "it'll pass," not "it passed last time."

Related: CLAUDE.md's rule about verifying an inferred rule against a second, genuinely different dataset. Same shape — a check that has only ever seen one environment is not yet a check.

## A widget test's own save-reveal timers outlive the save

**Symptom**: a test that triggers a real task creation fails with "A Timer is still pending" even though the task saved correctly and every assertion about it passes.

**Cause**: creating a task starts Timeline's reveal animations — `_DayTimelineState._revealSavedTask` (900ms) and `_DraggableTaskBlockState._scheduleReveal` (500ms). They outlive the save itself, so a test that pumps only enough for the write to land still ends with timers queued.

**Fix**: pump past both after the save completes:
```dart
await tester.pump(const Duration(milliseconds: 1000));
await tester.pump(const Duration(milliseconds: 600));
```

**Rule**: read the pending-timer stack trace — it names the widget and duration that queued it. The failure is about teardown, not about the assertion immediately above it, so debugging the assertion is wasted effort.

## Adding a second instance of a widget breaks every `byType` finder that assumed one

**Symptom**: `tester.drag(find.byType(ResizeHandle))` throws on ambiguity, so the drag never runs, and the test fails with the value it was supposed to change simply unchanged — which reads as "the feature silently does nothing," not as a finder problem.

**Cause**: the finder matched exactly one widget until a second (top-edge) handle started rendering.

**Fix**: disambiguate with `.first`/`.last`, and comment which is which and why — here group resize is bottom-edge-only by decision, so `.last` is load-bearing, not cosmetic.

**Rule**: when adding a second instance of an existing widget, grep the whole suite for `byType(<Widget>)` before running anything. It's one command and it finds every site at once.

## `multi_task_group_resize_test`'s floor case is load-sensitive (2026-09-08)

**Symptom**: "a selected task already at the resize floor stays there..." failed once in a full-suite run (`Expected: a value less than <60>, Actual: <60>` — the resize did not happen), then passed on an immediate re-run of the identical code, and passes in isolation.

**What is known**: the test drags the handle of a 5-minute task. That is exactly the case where `resizeHandleHeightFor` shrinks the handle to preserve a move band, so the hit target is at its smallest. A synthetic drag landing on a small target under full-suite scheduling pressure is a plausible cause, but this has NOT been proven — one observed failure is not a diagnosis.

**Deliberately NOT labelled "known flaky" and moved on from.** This project has already had a real regression hide under that label for two sessions (see the entry above). What is recorded here is the observation, not a conclusion. If it recurs: check whether the drag is landing on the handle at all (assert the callback fired, not just the resulting duration) before assuming timing.

## An isolated-widget test can confirm a layout formula the real screen contradicts

**Symptom**: the quick-add placeholder's title rendered one hour-gutter width (56px) left of every real task's name, and a widget test asserting "the title sits at the shared text column" passed anyway.

**Cause, two layers.** The code used `left: textColumnLeft - left`, double-correcting: `textColumnLeft` is expressed relative to the block's own box (which already starts at `left`), exactly as `_buildSplit` uses it for a real task. The test then supplied BOTH values itself (`left: 56`, `textColumnLeft: 120`) and asserted the result equalled a bare `120` — which the buggy formula also satisfies, since 56 + (120 − 56) = 120. **Both formulas agreed at that single point**, so the test could not tell them apart.

**Fix**: assert the SUM (`left + textColumnLeft` = 176), which the two formulas disagree on — and, more importantly, add the assertion in a real `TimelineScreen` comparing the placeholder's name x against an actual task's name x. That version fails with 80.0 vs 136.0, i.e. the exact 56px the user reported.

**Rule**: a geometry test whose inputs are supplied by the test itself can encode the same arithmetic error as the code. For anything positioned relative to shared layout, assert against a REAL sibling that uses the same layout ("the draft's name is at the same x as a task's name"), not against a number the test chose. A relationship between two real things cannot be satisfied by a wrong formula the way a hand-picked constant can.

## `edit_schedule_repeats_test.dart`/`affect_future_instances_test.dart` fail intermittently, with a different specific test each run

**Symptom**: running these two files (alone, or as part of `test/features/task_detail/`) fails 0-3 tests per run, with the SPECIFIC failing test changing between otherwise-identical runs of unmodified code. Traced to `HiveError: Box has already been closed`, thrown asynchronously "after the test had completed" — i.e. the test's own teardown closed the box while a still-in-flight write from `TaskList._materializeSeries`/`updateTaskWithChangedRecurrence` was mid-`putAll`.

**Cause**: the same family as the already-documented "Hive write inside a widget test hangs" entry above — real async Hive I/O racing the test framework's own fake-async/teardown timing — but manifesting as a race lost sometimes rather than a deterministic hang. Confirmed NOT caused by any of this session's changes (adding `Task.isImportant`'s create/edit-flow UI, `TaskTemplate.isImportant`): re-ran these two files back-to-back four times, watched a different specific test fail each time (or none), and every failure carried the identical "Box has already been closed" stack trace regardless of which test it landed on.

**Status: pre-existing, NOT fixed.** Whoever picks this up should look at whether these two files' own recurrence-materialization tests need the same `tester.runAsync` + poll-until-settled pattern the quick-create suite already adopted for its own Hive writes (see the entry above), rather than a fixed-duration `pump()` budget racing real disk I/O.

**Rule for this session and future ones**: before attributing directory-wide test failures to a change just made, re-run the SAME files against the SAME (or even prior) code more than once. A failure that moves to a different test name between identical runs is infrastructure flakiness, not a regression — and confirming that takes one extra run, not a revert-and-diff.

## `tap_empty_space_quick_create_test.dart`'s overlap-refusal test failed only after ~19:00

**Symptom**: "Schedule refuses to create an overlapping task..." failed both in the full gate and standalone, with `taskBox.values` holding 2 tasks instead of the expected 1 — i.e. the overlap it was supposed to test wasn't happening, so the create went through unrefused.

**Cause**: the test hardcoded its "existing task" to a fixed `9:00`-`19:00` clock span, but the tap position it uses (`Offset(220, 400)`, same fixed offset every test in this file uses) lands wherever the Timeline's initial scroll — which centres on `DateTime.now()` — happens to place it. The two only overlapped when the suite ran before 19:00; run at 19:48, the tap landed at 19:15, just past the fixed task's end, so no overlap existed and the second task was correctly created rather than refused.

**Fix**: anchor the existing task at `now.subtract(Duration(hours: 5))` (same 10h span) instead of a fixed clock hour, so it always covers wherever `now` — and therefore the tap — actually lands, regardless of wall-clock time.

**Rule**: this is a 4th member of the time-of-day-dependent fixture family (alongside the three already documented above) — but a different flavor: the earlier three vary in whether they pass, this one varies in whether it tests what it claims to. Any test in this file that hardcodes a task's clock time rather than anchoring it off `DateTime.now()` (the way the tap position already implicitly does) is a latent version of this same bug waiting for the right time of day to expose it.

## `armed_edit_task_test.dart` — even a `DateTime.now()`-relative offset can wrap past midnight

**Symptom**: `makeTask('Standup', hourOffset: 1)` (relative to `now`) produced a task that never appeared on the Timeline at all — `tap(find.text('Standup'))` found 0 widgets — even though the fixture was already anchored off `DateTime.now()`, the fix pattern from the entry just above.

**Cause**: anchoring off `now` fixes the "is this task inside the visible SCROLL window" problem, but not a second, different problem: the Timeline always opens on TODAY's calendar day. `DateTime.now().add(Duration(hours: 1))` run at 23:48 doesn't just move the clock time forward — it also rolls the DATE over to tomorrow, so the resulting task is scheduled on a day the Timeline isn't even showing. Confirmed empirically: a plain `+40 minutes` at 23:48 landed at 00:28 the *next* day.

**Fix**: compute minutes-since-midnight from `now`, apply the offset, then `clamp(0, 24*60 - 1)` before converting back to a `DateTime` built from `now`'s own year/month/day — the offset shrinks near either edge of the day instead of ever carrying the date over.

**Rule**: "anchor relative to `now`" is necessary but not sufficient near a day boundary — any test that also needs the result to stay on `now`'s own CALENDAR DAY (not just near `now`'s clock time) needs the day-boundary clamp too, not just the anchor.

## [2026-09-09] Restored Android emulator Activity is not a cold-launch test

During App Actions verification, `adb shell am start -W` reported delivery to an already running top-most Activity after the emulator restored its snapshot. That does not verify process startup or Hive initialization. Used `am force-stop com.example.amble` before the next action and confirmed `LaunchState: COLD`; the persisted survivor of an earlier deletion was still offered. Do not use `pm clear` for this check: it would erase the data whose persistence is being tested. Android's existing exact-alarm permission screen can also cover the result during startup notification refresh; return to Amble before inspecting its picker or treating the action as missing.
