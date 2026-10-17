import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'core/background/background_tasks.dart';
import 'core/app_intents/app_intent_channel.dart';
import 'core/app_intents/intent_notification_service.dart';
import 'core/dev_config.dart';
import 'core/feature_flags.dart';
import 'core/revenue_cat_config.dart';
import 'core/tokens/color_primitives.dart';
import 'core/tokens/semantic_theme.dart';
import 'core/tokens/component_tokens.dart';
import 'core/tokens/desktop_density.dart';
import 'core/tokens/type_primitives.dart';
import 'core/widgets/app_context_menu.dart';
import 'core/widgets/app_bottom_dock.dart';
import 'core/widgets/app_shell_chrome.dart';
import 'core/amble_material_localizations.dart';
import 'core/layout_width.dart';
import 'core/widgets/app_time_format.dart';
import 'core/widgets/app_header_over_content.dart';
import 'core/widgets/app_shell_header.dart';
import 'core/widgets/app_side_nav.dart';
import 'core/widgets/app_top_nav.dart';
import 'core/widgets/app_view_transition.dart';
import 'core/widgets/what_matters_motion.dart';
import 'core/widgets/app_touch_visualizer.dart';
import 'core/widgets/app_window_insets.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/onboarding/onboarding_quiz_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/task_detail/task_inspector_panel.dart';
import 'features/splash/splash_carousel_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/timeline/selected_date_provider.dart';
import 'features/timeline/armed_edit_task_provider.dart';
import 'features/timeline/edit_selection_provider.dart';
import 'features/timeline/edit_mode_provider.dart';
import 'features/timeline/pending_task_draft_provider.dart';
import 'features/calendar/desktop_days_host.dart';
import 'features/timeline/timeline_screen.dart';
import 'features/tracked_behavior/tracked_behavior_list_screen.dart';
import 'features/zone_grid/zone_grid_screen.dart';
import 'hive_registrar.g.dart';
import 'features/calendar/calendar_auto_refresh.dart';
import 'features/assistant/assistant_undo_toaster.dart';
import 'shared/providers/assistant_providers.dart';
import 'shared/models/app_theme_mode.dart';
import 'shared/models/category.dart';
import 'shared/models/synced_calendar_event.dart';
import 'shared/models/task.dart';
import 'shared/models/pill_shape.dart';
import 'shared/models/section.dart';
import 'shared/models/task_size.dart';
import 'shared/models/task_template.dart';
import 'shared/models/tracked_behavior.dart';
import 'shared/models/zone.dart';
import 'shared/repositories/zone_facet_repository.dart';
import 'shared/providers/calendar_providers.dart';
import 'shared/providers/category_providers.dart';
import 'shared/providers/notification_providers.dart';
import 'shared/providers/notification_tap_provider.dart';
import 'shared/providers/section_providers.dart';
import 'shared/providers/task_providers.dart';
import 'shared/providers/task_template_providers.dart';
import 'shared/providers/preferences_providers.dart';
import 'shared/providers/purchases_providers.dart';
import 'shared/providers/occurrence_store.dart';
import 'shared/providers/series_providers.dart';
import 'shared/models/occurrence_alert.dart';
import 'shared/providers/tracked_behavior_providers.dart';
import 'shared/providers/trial_providers.dart';
import 'shared/providers/zone_providers.dart';

final _rootContextMenuNavigatorObserver = AppContextMenuNavigatorObserver();

// TEMPORARY diagnostic instrumentation — added to track down a reported
// "white launch screen, then full black screen, app unresponsive" on both
// Simulator and a physical device. main() runs a long chain of awaited
// Hive/RevenueCat/notification setup steps before `runApp`; an uncaught
// exception anywhere in that chain kills the app before the Flutter engine
// paints a first frame, which is indistinguishable on-device from a hang.
// This wraps every step with a timestamped START/DONE/ERROR log (stack
// trace preserved, then rethrown — never swallowed) so the real failure
// point can be read from `flutter logs`/Console.app, rather than guessed
// at again. Remove once the real cause is found and fixed.
Future<T> _step<T>(String label, Future<T> Function() body) async {
  final start = DateTime.now();
  debugPrint('[startup] START $label @ $start');
  try {
    final result = await body();
    debugPrint(
      '[startup] DONE  $label (+${DateTime.now().difference(start).inMilliseconds}ms)',
    );
    return result;
  } catch (error, stackTrace) {
    debugPrint('[startup] ERROR $label: $error');
    debugPrint('$stackTrace');
    rethrow;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TEMPORARY diagnostic — see `_step`'s own doc comment above. Flutter's
  // own framework errors (a failed build/layout) normally show as an
  // on-screen red error box in debug, but that box is itself a `Text`
  // needing a real frame to paint — if the very FIRST frame's build
  // throws, there may be nothing on screen to show it at all. Logging
  // here guarantees the error reaches the console regardless.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    debugPrint(
      '[startup] FlutterError.onError: ${details.exceptionAsString()}',
    );
    debugPrint('${details.stack}');
    previousOnError?.call(details);
  };
  await _step('Hive.initFlutter', () => Hive.initFlutter());
  await _step('Hive.registerAdapters', () async => Hive.registerAdapters());
  await _step('Hive.openBox<Task>', () => Hive.openBox<Task>(taskBoxName));
  // Opened but unused until the TrackedBehavior UI exists (gated behind
  // FeatureFlags.trackedBehaviorEnabled) — the box must be open for
  // trackedBehaviorRepositoryProvider to resolve if anything ever reads it.
  await _step(
    'Hive.openBox<TrackedBehavior>',
    () => Hive.openBox<TrackedBehavior>(trackedBehaviorBoxName),
  );
  // Opened but unused until a Zone UI exists (gated behind
  // FeatureFlags.zoneEnabled) — same "additive, inert data layer" pattern
  // as trackedBehaviorBoxName above.
  await _step('Hive.openBox<Zone>', () => Hive.openBox<Zone>(zoneBoxName));
  await _step(
    'HiveZoneFacetRepository.initialize',
    () => HiveZoneFacetRepository.initialize(),
  );
  // The user-extensible category entity — seeded with 5 built-in rows and
  // backfilled onto existing tasks below, once, at launch.
  await _step(
    'Hive.openBox<Category>',
    () => Hive.openBox<Category>(categoryBoxName),
  );
  // User-created Inbox folders — no seeding, every Section is user-made.
  await _step(
    'Hive.openBox<Section>',
    () => Hive.openBox<Section>(sectionBoxName),
  );
  // Reusable task blueprints, surfaced on the Inbox's "Templates" tab —
  // ungated (free functionality, same tier as Category), see
  // CONSTITUTION.md's "TaskTemplate" section.
  await _step(
    'Hive.openBox<TaskTemplate>',
    () => Hive.openBox<TaskTemplate>(taskTemplateBoxName),
  );
  // Small key-value store for app preferences (theme mode today, more
  // later). Untyped box: it holds heterogeneous primitive/adapter values by
  // design — see PreferencesRepository.
  await _step(
    'Hive.openBox<dynamic>(preferences)',
    () => Hive.openBox<dynamic>(preferencesBoxName),
  );
  // Tracks device-calendar event ids created by Feature 2's manual sync-out
  // — see CONSTITUTION.md's "Calendar" section and SyncedCalendarEvent's
  // own doc comment for why this can't just live in `preferences`.
  await _step(
    'Hive.openBox<SyncedCalendarEvent>',
    () => Hive.openBox<SyncedCalendarEvent>(syncedCalendarEventBoxName),
  );
  await _step('openSeriesModelBoxes', openSeriesModelBoxes);

  final container = ProviderContainer(
    overrides: [
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)
        notificationServiceProvider.overrideWithValue(
          IntentNotificationService(),
        ),
    ],
  );
  // Registers the panta_pro entitlement listener (build() below) and fetches
  // the current CustomerInfo once, so the first frame already has real
  // entitlement data instead of waiting for a later change to arrive on the
  // listener feed. Must run before runApp — same "resolve before first
  // frame" posture as the notification service just below.
  //
  // Skipped entirely when purchases are unavailable — an unsupported
  // platform (only iOS/Android have the SDK; this repo also builds macOS)
  // or a build without the `--dart-define` keys. This block runs BEFORE
  // `runApp`, so anything thrown here kills the app to a black screen
  // with no UI to report it; purchases are not load-bearing for the rest
  // of the app, so an unconfigured build runs normally without them and
  // `isPantaProProvider` simply stays false. The Subscription screen
  // shows its own "unavailable" state rather than a broken paywall.
  final purchasesConfigured = await _step(
    'purchasesRepository.configure',
    () => container.read(purchasesRepositoryProvider).configure(),
  );
  if (purchasesConfigured) {
    container.read(pantaCustomerInfoProvider); // starts the listener
    await _step(
      'pantaCustomerInfo.refresh',
      () => container.read(pantaCustomerInfoProvider.notifier).refresh(),
    );
  } else {
    debugPrint(
      'RevenueCat not configured — purchases disabled for this build. '
      'Pass --dart-define=REVENUECAT_IOS_API_KEY=... and/or '
      '--dart-define=REVENUECAT_ANDROID_API_KEY=... to enable them.',
    );
  }

  final notificationService = container.read(notificationServiceProvider);
  await _step(
    'notificationService.initialize',
    () => notificationService.initialize(
      onNotificationTap: (taskId) =>
          container.read(notificationTapProvider.notifier).set(taskId),
    ),
  );
  await _step(
    'notificationService.handleColdStartLaunch',
    () => notificationService.handleColdStartLaunch(
      onNotificationTap: (taskId) =>
          container.read(notificationTapProvider.notifier).set(taskId),
    ),
  );

  // Records this install's first-launch timestamp, once — powers the
  // 21-day free trial that gates new-task creation without `panta_pro`
  // (requested directly: "lock behind 21 day trial ability to add new
  // tasks via any route"). Must run before anything below could possibly
  // create a task, so the trial clock is never absent when
  // `canCreateTaskProvider` is first read. See `trial_providers.dart`.
  await _step(
    'installDate.recordIfNeeded',
    () => container.read(installDateProvider.notifier).recordIfNeeded(),
  );

  // One-time migration: an existing user's single `TaskSize` choice seeds
  // the newly-independent `TaskFontSize` setting, by name, exactly once —
  // see `TaskFontSizeSetting.migrateIfNeeded`'s own doc comment for why
  // this happens here (an explicit, awaited launch step) rather than as a
  // side effect of that provider's own `build()`.
  await _step(
    'taskFontSizeSetting.migrateIfNeeded',
    () =>
        container.read(taskFontSizeSettingProvider.notifier).migrateIfNeeded(),
  );

  // Seed the 5 built-in categories and backfill every pre-existing task's
  // deprecated `category` enum onto the new `categoryId`. Launch-only,
  // gated by PreferenceKeys.categoriesSeeded so it only actually runs
  // once per install — see docs/DECISIONS.md.
  await _step(
    'categoryList.seedBuiltInsAndBackfillIfNeeded',
    () => container
        .read(categoryListProvider.notifier)
        .seedBuiltInsAndBackfillIfNeeded(),
  );

  // Backfill `Task.createdAt` for every pre-existing row saved before
  // that field existed. Launch-only, gated by
  // PreferenceKeys.taskCreatedAtBackfilled, same "once per install"
  // shape as the category backfill just above — see
  // `TaskList.backfillCreatedAtIfNeeded`'s own doc comment and
  // docs/DECISIONS.md.
  await _step(
    'taskList.backfillCreatedAtIfNeeded',
    () => container.read(taskListProvider.notifier).backfillCreatedAtIfNeeded(),
  );

  // Collapses duplicate same-titled Zone series into one, and detaches
  // any orphaned series (rows carrying a recurrenceId whose template no
  // longer exists). Runs BEFORE the top-up below, so materialization
  // never re-fills a series that is about to be removed. Idempotent and a
  // no-op on healthy data — see `ZoneList.repairDuplicateZoneSeries`.
  //
  // Needed because two now-fixed bugs could mint parallel series for one
  // zone (see docs/ERROR_LOG.md); this repairs installs that already
  // accumulated them, which a code fix alone cannot do.
  await _step(
    'zoneList.migrateToWeeklySchedule',
    () => container.read(zoneListProvider.notifier).migrateToWeeklySchedule(),
  );
  // Same rolling-window top-up, for Zone's own materialized recurring
  // instances (see docs/DECISIONS.md — Zone materialization session).
  // Mirrors the Task call above exactly, including trigger point (app
  // open, before notification refresh) and idempotency.
  await _step(
    'zoneList.materializeDueRecurrences',
    () => container.read(zoneListProvider.notifier).materializeDueRecurrences(),
  );

  // Roll the notification window forward. Materialization above writes rows
  // 8 weeks out but deliberately schedules no alarms; this registers them
  // for the near window only, keeping the app well under Android's
  // 500-concurrent-alarm cap. See docs/ERROR_LOG.md.
  //
  // Deliberately NOT awaited: this is a batch of native platform calls, and
  // blocking `runApp` on it would trade a slow save for a slow cold start.
  // Alerts are a side effect of data that is already persisted, so they can
  // finish registering after the first frame.
  // Task refresh owns cancelAll; zone registration must follow it.
  unawaited(
    _step('notifications.refresh (background)', () async {
      await container
          .read(taskListProvider.notifier)
          .refreshScheduledNotifications();
      await container
          .read(zoneListProvider.notifier)
          .refreshScheduledNotifications();
      // The task refresh cancelled every alert, occurrence alerts included,
      // so their recorded state is stale — clear it and re-register.
      await container.read(occurrenceAlertStateRepositoryProvider).clear();
      await recordDeviceZone(container);
      await container.read(occurrenceStoreProvider.notifier).reconcileAlerts();
    }),
  );

  // Morning-summary background task: re-registered (or cancelled) on every
  // launch against the CURRENT setting value, same reasoning as the
  // notification refreshes above — the toggle may have changed since the
  // last launch, and a stale registration should never be trusted to
  // still be correct. `initialize` must run before any
  // register/cancel call; `callbackDispatcher` is the one AOT entry point
  // the native side invokes for every dispatch, on both platforms.
  //
  // Deliberately NOT awaited, same reasoning as the notification refreshes
  // above: this is a batch of native platform calls with no bearing on the
  // first frame.
  unawaited(
    _step(
      'Workmanager.initialize (background)',
      () => Workmanager()
          .initialize(backgroundTaskDispatcher)
          .then(
            (_) => registerMorningSummaryTask(
              enabled: container.read(slackSummaryEnabledSettingProvider),
            ),
          ),
    ),
  );

  // Native Siri calls wait for this handshake, not for a visible UI frame.
  // The iOS host and its eventual scene share this engine and these boxes.
  unawaited(
    _step(
      'registerAppIntentChannel (background)',
      () => registerAppIntentChannel(container),
    ),
  );

  debugPrint('[startup] START runApp');
  runApp(
    UncontrolledProviderScope(container: container, child: const AmbleApp()),
  );
  debugPrint('[startup] DONE  runApp (returned — does not mean painted yet)');
}

class AmbleApp extends ConsumerWidget {
  const AmbleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TEMPORARY diagnostic — see `_step`'s own doc comment above `main()`.
    debugPrint('[startup] AmbleApp.build entered');
    final themeMode = ref.watch(themeModeSettingProvider);
    final use24Hour = ref.watch(timeFormatSettingProvider).use24Hour;
    final hasSeenSplash = ref.watch(hasSeenSplashProvider);
    // Keeps Claude's local endpoint running for the session while an
    // assistant is connected (Settings › Claude); listening, not watching,
    // so a status change never rebuilds the app.
    ref.listen(assistantServerProvider, (_, _) {});
    // A separate step from the splash/carousel above, not folded into it
    // — confirmed directly: "we need to keep carousel and separately
    // onboarding slides." Only consulted once hasSeenSplash is already
    // true; the carousel's own CTA is completely unchanged.
    final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);
    // Dev toggles deciding WHICH first-launch presentation (if any) the
    // gate below can show — see `core/dev_config.dart`'s own doc comments.
    // Requested directly: "put onboarding carousel and questionnaire
    // behind dev toggles, as default we hide them" plus a new one-off
    // splash, "also under dev toggle."
    final newSplashEnabled = ref.watch(devNewSplashEnabledProvider);
    final legacyCarouselEnabled = ref.watch(
      devLegacyOnboardingCarouselEnabledProvider,
    );
    final onboardingQuizEnabled = ref.watch(devOnboardingQuizEnabledProvider);
    // One global rung (sm/md/lg) resolved onto BOTH light and dark
    // palettes here, once, before either reaches MaterialApp — every
    // existing call site (TaskCapsuleBlock, ZoneContainerBlock,
    // OverlapClusterBlock) keeps reading the same `sizeTaskBadge`/
    // `textTaskTitle` fields it always has, with no per-call-site changes.
    // Requested directly: "it's not per view, it's a setting, that when
    // set affects all."
    //
    // `taskSize` (pill/badge diameter) and `taskFontSize` (title font) are
    // now TWO independent settings, not one — requested directly:
    // "Settings in appearance separately font size and separately pill
    // size, let's split this, and should affect all pills its text."
    // Resolved as two separate passes for the same reason `pillShape`
    // already is below: each setting owns exactly the fields it controls.
    final taskSize = ref.watch(taskSizeSettingProvider);
    final taskFontSize = ref.watch(taskFontSizeSettingProvider);
    // Same "resolve once, here, before MaterialApp" mechanism as taskSize
    // above — see PillShapeSetting's own doc comment. Requested directly:
    // "this should affect globally, in edit tasks etc."
    final pillShape = ref.watch(pillShapeSettingProvider);
    // Developer → "Show touches": dots under each finger, for recordings.
    final showTouches =
        isDevConfigAvailable && ref.watch(devShowTouchesProvider);
    // Dev-settings knob: off collapses the dual-font split (mono tokens ->
    // DM Sans) app-wide — see `DualFontSetting`'s own doc comment.
    final dualFontEnabled = ref.watch(dualFontSettingProvider);
    var lightTheme = _resolvePillSize(AmbleTheme.light, taskSize);
    var darkTheme = _resolvePillSize(AmbleTheme.dark, taskSize);
    lightTheme = _resolveFontSize(lightTheme, taskFontSize);
    darkTheme = _resolveFontSize(darkTheme, taskFontSize);
    lightTheme = _resolvePillShape(lightTheme, pillShape);
    darkTheme = _resolvePillShape(darkTheme, pillShape);
    lightTheme = _resolveDualFont(lightTheme, dualFontEnabled);
    darkTheme = _resolveDualFont(darkTheme, dualFontEnabled);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Status/navigation bar icons must contrast with our surface, and
      // nothing else sets them: the app has no AppBar anywhere (which would
      // normally manage this automatically), so without this the dark theme
      // renders dark status-bar icons on a near-black surface — invisible.
      //
      // Resolved against the *effective* brightness, not the stored setting,
      // so `system` mode follows the OS correctly. `statusBarBrightness` is
      // iOS-only and `statusBarIconBrightness`/`systemNavigationBar*` are
      // Android-only; both are set here because Flutter ignores the
      // irrelevant ones per platform rather than erroring, so one
      // declaration covers both without a Platform check.
      value: _overlayStyleFor(_effectiveBrightness(context, themeMode)),
      child: MaterialApp(
        navigatorObservers: [_rootContextMenuNavigatorObserver],
        debugShowCheckedModeBanner: false,
        title: 'Amble',
        theme: _themeDataFor(lightTheme, Brightness.light),
        darkTheme: _themeDataFor(darkTheme, Brightness.dark),
        themeMode: toFlutterThemeMode(themeMode),
        // Lower-case am/pm everywhere a time is formatted (see
        // AmbleMaterialLocalizations); the framework's own defaults are
        // appended after it.
        localizationsDelegates: const [AmbleMaterialLocalizations.delegate],
        // 12/24-hour time (Settings → Appearance), imposed once at the root
        // so every `TimeOfDay.format` in every screen, sheet and overlay
        // follows it. Null leaves the device's own setting in place.
        builder: (context, child) {
          final app = child;
          if (app == null) {
            throw StateError('MaterialApp built without a navigator child');
          }
          return AppWindowInsets(
            child: AppTouchVisualizer(
              enabled: showTouches,
              child: AppTimeFormat(use24Hour: use24Hour, child: app),
            ),
          );
        },
        // Gate, provider-watched so each CTA's write triggers an immediate
        // rebuild with no separate Navigator.push. The one-off SplashScreen
        // and the legacy carousel/quiz are independently dev-toggle-gated
        // (see `core/dev_config.dart`) and share `hasSeenSplash`/
        // `hasCompletedOnboarding` as their own "already shown" state, so
        // toggling a dev switch never re-shows something already seen —
        // only what a fresh, unseen install would reach.
        // Under the Navigator so its "Claude added … · Undo" toast has an
        // overlay to show in.
        home: CalendarAutoRefresh(
          child: AssistantUndoToaster(
            child: _loggedHome(
              hasSeenSplash: hasSeenSplash,
              newSplashEnabled: newSplashEnabled,
              legacyCarouselEnabled: legacyCarouselEnabled,
              hasCompletedOnboarding: hasCompletedOnboarding,
              onboardingQuizEnabled: onboardingQuizEnabled,
            ),
          ),
        ),
      ),
    );
  }
}

// TEMPORARY diagnostic — see `_step`'s own doc comment above `main()`.
// Logs which branch of the home gate was actually selected, and schedules
// a log for the first real painted frame (`addPostFrameCallback` fires
// once per frame; `WidgetsBinding.instance.firstFrameRasterized` is the
// more specific signal, but this callback alone already tells us whether
// the engine reaches "a frame was scheduled and drawn" at all).
Widget _loggedHome({
  required bool hasSeenSplash,
  required bool newSplashEnabled,
  required bool legacyCarouselEnabled,
  required bool hasCompletedOnboarding,
  required bool onboardingQuizEnabled,
}) {
  final Widget home;
  final String label;
  if (!hasSeenSplash && newSplashEnabled) {
    label = 'SplashScreen';
    home = SplashScreen(onFinished: () {});
  } else if (!hasSeenSplash && legacyCarouselEnabled) {
    label = 'SplashCarouselScreen';
    home = SplashCarouselScreen(onFinished: () {});
  } else if (!hasCompletedOnboarding && onboardingQuizEnabled) {
    label = 'OnboardingQuizScreen';
    home = const OnboardingQuizScreen();
  } else {
    label = 'AmbleHome';
    home = const AmbleHome();
  }
  debugPrint('[startup] home gate selected: $label');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('[startup] first frame callback fired (home: $label)');
  });
  return home;
}

/// The brightness actually in effect, resolving [AppThemeMode.system]
/// against the platform setting.
Brightness _effectiveBrightness(BuildContext context, AppThemeMode mode) =>
    switch (mode) {
      AppThemeMode.light => Brightness.light,
      AppThemeMode.dark => Brightness.dark,
      AppThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };

/// System bar styling for a given surface brightness.
///
/// Note the inversion that trips people up: `statusBarIconBrightness` and
/// `statusBarBrightness` describe *opposite* things. The former is the icon
/// colour (Android), the latter is the background the icons sit on (iOS) —
/// so a dark surface needs `Brightness.light` icons but is declared as
/// `Brightness.dark` for iOS.
SystemUiOverlayStyle _overlayStyleFor(Brightness surface) {
  final isDark = surface == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: ColorPrimitives.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: isDark
        ? AmbleTheme.dark.colorSurfacePrimary
        : AmbleTheme.light.colorSurfacePrimary,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
  );
}

/// Resolves the ACTIVE `sizeTaskBadge` field on [palette] to whichever
/// fixed rung [size] selects — see `TaskSizeSetting`'s own doc comment.
/// Every real call site reads `theme.sizeTaskBadge` directly and has no
/// idea this setting exists; this is the one place the mapping happens.
///
/// **Split from font size** (requested directly: "Settings in appearance
/// separately font size and separately pill size, let's split this") —
/// this used to also resolve `textTaskTitle`/`textTaskTitleZone` in the
/// same switch, paired to the badge rung by a historical "one step
/// smaller" rule (see docs/DECISIONS.md and [_resolveFontSize]'s own doc
/// comment for that rule, now applied independently). Splitting this
/// function changes NOTHING about what badge size each named option
/// resolves to — only which setting controls it.
AmbleTheme _resolvePillSize(AmbleTheme palette, TaskSize size) {
  return switch (size) {
    TaskSize.sm => palette.copyWith(sizeTaskBadge: palette.sizeTaskBadgeMd),
    TaskSize.md => palette.copyWith(sizeTaskBadge: palette.sizeTaskBadgeLg),
    TaskSize.lg => palette.copyWith(sizeTaskBadge: palette.sizeTaskBadgeXl),
  };
}

/// Resolves the ACTIVE `textTaskTitle`/`textTaskTitleZone` fields on
/// [palette] to whichever fixed rung [size] selects — see
/// `TaskFontSizeSetting`'s own doc comment. Every real call site reads
/// `theme.textTaskTitle` directly and has no idea this setting exists;
/// this is the one place the mapping happens.
///
/// Mirrors the EXACT font rung [_resolvePillSize]'s own [TaskSize]
/// mapping historically paired with each badge rung (see that function's
/// own doc comment on the "one step smaller" rule this preserves,
/// unchanged, now that the two are independent controls) — `sm`->font sm,
/// `md`->font md, `lg`->font lg (its own genuine rung, not md's, per the
/// 2026-09-12 reversal already on record).
AmbleTheme _resolveFontSize(AmbleTheme palette, TaskFontSize size) {
  return switch (size) {
    TaskFontSize.sm => palette.copyWith(
      textTaskTitle: palette.textTaskTitleSm,
      // Zone view's own title font is always one rung up from the active
      // one — see AmbleTheme.textTaskTitleZone's own doc comment.
      // Requested directly: "Size of text in zone view (task name one
      // scale up)."
      textTaskTitleZone: palette.textTaskTitleMd,
    ),
    TaskFontSize.md => palette.copyWith(
      textTaskTitle: palette.textTaskTitleMd,
      textTaskTitleZone: palette.textTaskTitleLg,
    ),
    TaskFontSize.lg => palette.copyWith(
      textTaskTitle: palette.textTaskTitleLg,
      // No rung larger than lg exists, so Zone view stays at lg's own
      // size too — it simply can't go any further up.
      textTaskTitleZone: palette.textTaskTitleLg,
    ),
  };
}

/// Resolves the ACTIVE `radiusPill` field on [palette] to whichever fixed
/// rung [shape] selects — see `PillShapeSetting`'s own doc comment. Every
/// real call site reads `theme.radiusPill` directly and has no idea this
/// setting exists; this is the one place the mapping happens. Mirrors
/// [_resolveTaskSize]'s own shape exactly.
AmbleTheme _resolvePillShape(AmbleTheme palette, PillShape shape) {
  return switch (shape) {
    PillShape.small => palette.copyWith(radiusPill: palette.radiusPillSmall),
    PillShape.rounded => palette.copyWith(
      radiusPill: palette.radiusPillRounded,
    ),
    PillShape.full => palette.copyWith(radiusPill: palette.radiusPillFull),
  };
}

/// Resolves every mono-bound text token on [palette]
/// (`textBodyMono`/`textCaptionMono`/`textZoneName`/`textTaskEdgeTime`/
/// `textTaskTitleZone` — see `TypePrimitives.fontFamily`'s own doc comment
/// for the full list and why each is mono) to DM Sans when [enabled] is
/// false, so the whole app reads as one font. When [enabled] is true this
/// is a no-op — [palette] already carries the dual-font split baked in at
/// construction. Every real call site keeps reading its own token
/// (`theme.textZoneName`, etc.) with no idea this setting exists; this is
/// the one place the collapse happens, mirroring [_resolvePillSize]/
/// [_resolveFontSize]/[_resolvePillShape]'s own "resolve once, here, before
/// MaterialApp" shape.
AmbleTheme _resolveDualFont(AmbleTheme palette, bool enabled) {
  if (enabled) return palette;
  const sans = TypePrimitives.fontFamilySans;
  return palette.copyWith(
    textBodyMono: palette.textBodyMono.copyWith(fontFamily: sans),
    textCaptionMono: palette.textCaptionMono.copyWith(fontFamily: sans),
    textZoneName: palette.textZoneName.copyWith(fontFamily: sans),
    textTaskEdgeTime: palette.textTaskEdgeTime.copyWith(fontFamily: sans),
    textTaskTitleZone: palette.textTaskTitleZone.copyWith(fontFamily: sans),
  );
}

/// Builds the Material [ThemeData] wrapper around one of our [AmbleTheme]
/// palettes.
///
/// The seed and scaffold colors are read *from the palette* rather than
/// hardcoded — they were previously literal hex values (`0xFF5B6F52`,
/// `0xFFF7F5F0`), which both violated the no-magic-values rule and meant
/// the Material surface underneath our own tokens could silently disagree
/// with them. Now a palette change propagates automatically, and dark mode
/// can't end up with a light scaffold peeking through.
ThemeData _themeDataFor(AmbleTheme palette, Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.colorAccent,
      brightness: brightness,
    ),
    // `colorSurfaceTimeline`, NOT `colorSurfaceBase` (corrected
    // 2026-09-12) — every real screen (Timeline, Inbox, Tracked,
    // Settings) already paints its own full-bleed `colorSurfaceTimeline`
    // background, so this scaffold color is only ever actually visible
    // in the margin gap around the now-floating nav pill/"+" button. In
    // dark mode `colorSurfaceBase` (`ink900`, #121110) is a visibly
    // DARKER value than that gap's surrounding `colorSurfaceTimeline`
    // (`ink800`) — reported directly as an unwanted extra patch of
    // background color ("some other bg that is unnecessary... 121110").
    // `colorSurfaceBase` was originally chosen here to fix a DIFFERENT,
    // earlier bug (light-mode scaffold and the white floating nav were
    // byte-identical, #FFFFFF vs #FFFFFF) — `colorSurfaceTimeline`
    // (`cream1`) still isn't `colorSurfaceOverlay` (`creamOverlay`,
    // white) in light mode, so that original distinction still holds;
    // only the specific TOKEN changed, to one that also matches every
    // screen's own body now that a margin gap exists to expose the
    // mismatch. See the elevation tests in test/core/tokens/.
    scaffoldBackgroundColor: palette.colorSurfaceTimeline,
    // App-wide font fallback — every text style built from `AmbleTheme`'s
    // own tokens already carries an explicit `TypePrimitives.fontFamily`/
    // `fontFamilySans` (see semantic_theme.dart), but this covers default
    // Material text that ISN'T one of ours (an AlertDialog action, a
    // SnackBar) so nothing on screen falls back to the platform default
    // font.
    //
    // **2026-09-21 — fontFamilySans (DM Sans), not fontFamily (mono).**
    // Per the dual-font policy, un-tokenized text defaults to sans —
    // nothing un-tokenized in this app is inherently numeric/temporal, so
    // there is no risk of silently defaulting a value display to the
    // wrong font.
    fontFamily: TypePrimitives.fontFamilySans,
    extensions: [palette],
  );
}

/// The app's root nav shell — Inbox, Timeline, Settings, per
/// docs/SCOPE.md's final Inbox/Timeline/Settings nav structure. Settings
/// (Phase 8) replaces the temporary "Backup" tab from Phase 7 — see
/// docs/DECISIONS.md. Placed after Timeline so the tap-to-open index below
/// (1) still lands correctly.
///
/// Also the single place that reacts to [notificationTapProvider] — tapping
/// a task-start notification switches to the Timeline tab and jumps to that
/// task's day, then consumes the pending tap so it doesn't re-fire on a
/// later rebuild.
class AmbleHome extends ConsumerStatefulWidget {
  const AmbleHome({super.key});

  @override
  ConsumerState<AmbleHome> createState() => _AmbleHomeState();
}

class _ShellScene {
  const _ShellScene({
    required this.key,
    required this.viewId,
    required this.forward,
    required this.child,
  });

  final String key;
  final String viewId;
  final bool forward;
  final Widget child;
}

class _AmbleHomeState extends ConsumerState<AmbleHome> {
  int _selectedIndex = 0;
  bool _pageMotionForward = true;
  final _contentNavigatorKey = GlobalKey<NavigatorState>();
  final _contentContextMenuNavigatorObserver =
      AppContextMenuNavigatorObserver();
  final _sceneNotifier = ValueNotifier<_ShellScene?>(null);
  final _chromeController = AppShellChromeController();

  @override
  void dispose() {
    _sceneNotifier.dispose();
    _chromeController.dispose();
    super.dispose();
  }

  void _publishScene(_ShellScene scene) {
    final current = _sceneNotifier.value;
    if (current?.key == scene.key) return;
    if (current == null) {
      _sceneNotifier.value = scene;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _sceneNotifier.value?.key != scene.key) {
        _sceneNotifier.value = scene;
      }
    });
  }

  void _clearTimelineSelections() {
    ref.read(editSelectionProvider.notifier).clear();
    ref.read(zoneEditSelectionProvider.notifier).clear();
    ref.read(armedEditTaskProvider.notifier).clear();
  }

  /// **2026-09-20 — top nav replaces the bottom `NavigationBar` as the
  /// primary section switcher.** Requested directly, as a deliberate
  /// reversal of conventional mobile navigation: "Top: choose the part of
  /// Panta. Bottom: choose how to work with your day." Days/Things/Habits
  /// are quiet text-label destinations at the TOP now ([AppTopNav]);
  /// Settings moved out of the destination row entirely into that same
  /// top nav's own separate icon (confirmed directly — Tracked keeps its
  /// existing screen with no bottom dock of its own, and "Today" is the
  /// existing merged Timeline tab, unchanged in substance). The bottom
  /// dock (List/Timeline/Edit/What Matters, contextual to the Day screen)
  /// is a SEPARATE, not-yet-built piece — Edit Mode's pen icon and the
  /// rest of `AppCalendarHeader` are untouched by this stage.
  ///
  /// Settings is index 3, reached only via [AppTopNav.onSettingsTap] —
  /// it deliberately has NO entry in [_topNavLabels]/`AppTopNav`'s own
  /// destination row, matching "Settings as separate icon on far right,"
  /// not a fourth quiet label indistinguishable from Days/Things/Habits.
  ///
  /// "Habits" is present when [FeatureFlags.trackedBehaviorEnabled] is on
  /// (default true) AND — in a debug build only — the
  /// `DevTrackedTabInCycle` dev toggle (`core/dev_config.dart`) hasn't
  /// been switched off; the flag omits the destination entirely rather
  /// than showing a disabled one.
  ///
  /// The merged Timeline tab is index 0 (was Task view) — the
  /// notification-tap handler below switches to it directly rather than
  /// via a stored index, avoiding the exact "adding a tab ahead silently
  /// redirects every notification tap" trap the previous ordering's own
  /// doc comment warned about.
  ///
  /// Computed per-build (not `static final`) now that visibility can
  /// change at runtime via the dev toggle — `ref.watch`ing
  /// `devTrackedTabInCycleProvider` needs a live rebuild, which a
  /// once-computed static list can never give.
  List<Widget> _screens(
    bool trackedTabVisible,
    TimelineDisplayMode mode, {
    required bool wide,
  }) => [
    // Wide windows add a Day / Week / Month switch above the Days page.
    if (wide) DesktopDaysHost(mode: mode) else TimelineScreen(mode: mode),
    const InboxScreen(),
    if (trackedTabVisible) const TrackedBehaviorListScreen(),
    const SettingsScreen(),
  ];

  /// The top nav's own quiet text labels — "Days" (renamed from the old
  /// icon-only "Timeline" destination's tooltip, matching the spec's own
  /// naming), "Things", and "Habits" when visible. Kept in the SAME order
  /// as [_screens]'s first three entries; Settings (index 3) is
  /// deliberately excluded — see [_screens]'s own doc comment.
  List<String> _topNavLabels(bool trackedTabVisible) => [
    'Days',
    'Things',
    if (trackedTabVisible) 'Patterns',
  ];

  /// A nav destination tap — shared by [AppTopNav] and [AppSideNav].
  /// Tapping Days (index 0) again while it's already selected toggles
  /// spatial/Zone view — the nav-tap half of "1 nav item, but when tapped
  /// again it switches view," mirrored by `AppCalendarHeader`'s own
  /// switcher button reaching the same provider.
  void _selectDestination(int index, {required bool zoneViewEnabled}) {
    if (index == 0 && _selectedIndex == 0) {
      _clearTimelineSelections();
      ref.read(zoneViewEnabledSettingProvider.notifier).set(!zoneViewEnabled);
      return;
    }
    if (index != _selectedIndex) _clearTimelineSelections();
    setState(() {
      _pageMotionForward = index > _selectedIndex;
      _selectedIndex = index;
    });
  }

  /// The Settings gear — shared by [AppTopNav] and [AppSideNav].
  void _openSettings(int settingsIndex) {
    final wasAlreadyOnSettings = _selectedIndex == settingsIndex;
    if (!wasAlreadyOnSettings) _clearTimelineSelections();
    setState(() {
      _pageMotionForward = settingsIndex > _selectedIndex;
      _selectedIndex = settingsIndex;
    });
    // Only on an actual transition INTO Settings, not on a repeated tap
    // while already there — the gear fires on every tap regardless of the
    // current tab, unlike a destination's own already-selected check.
    if (!wasAlreadyOnSettings &&
        FeatureFlags.subscriptionEnabled &&
        RevenueCatConfig.isAvailable) {
      unawaited(
        ref
            .read(purchasesRepositoryProvider)
            .presentPaywallIfNeeded(RevenueCatConfig.pantaProEntitlementId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // Same "flag AND (release OR dev-toggle-still-on)" resolution
    // `TimelineScreen`'s own `zoneViewEnabled` uses for
    // `DevZoneViewInCycle` — `isDevConfigAvailable` is a `kDebugMode`
    // re-export, so this collapses to the plain flag in release builds.
    final trackedTabVisible =
        FeatureFlags.trackedBehaviorEnabled &&
        (!isDevConfigAvailable || ref.watch(devTrackedTabInCycleProvider));
    final zoneViewEnabled = ref.watch(zoneViewEnabledSettingProvider);
    final timelineMode = zoneViewEnabled
        ? TimelineDisplayMode.zone
        : TimelineDisplayMode.spatial;
    // Wide windows (desktop, web, iPad landscape) swap the top nav for a
    // left sidebar beside the content — see ShellLayoutTokens.
    final wide = isWideLayout(context);
    final screens = _screens(trackedTabVisible, timelineMode, wide: wide);
    final activeIndex = _selectedIndex < screens.length ? _selectedIndex : 0;
    final activeViewId = activeIndex == 0
        ? 'day'
        : activeIndex == 1
        ? 'inbox'
        : trackedTabVisible && activeIndex == 2
        ? 'tracked'
        : 'settings';
    _publishScene(
      _ShellScene(
        key:
            // `wide`: crossing the breakpoint swaps the Days page itself
            // (Day / Week / Month host vs. the phone Timeline).
            '$activeIndex:$activeViewId:${timelineMode.name}:'
            '$trackedTabVisible:$wide',
        viewId: activeViewId,
        forward: _pageMotionForward,
        child: screens[activeIndex],
      ),
    );

    // The dev toggle can shrink the tab list at runtime (unlike the
    // compile-time flag, which can't change after launch) — if the
    // currently-selected index no longer exists, fall back to Timeline
    // rather than crashing IndexedStack/NavigationBar on an out-of-range
    // index. Mirrors `DevZoneViewInCycle`'s own "don't strand the user in
    // a mode the toggle just removed" reasoning. Timeline (index 0) can
    // never itself be removed by this toggle (only "Habits" can), so it's
    // always a safe fallback.
    if (_selectedIndex >= screens.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _pageMotionForward = false;
            _selectedIndex = 0;
          });
        }
      });
    }

    ref.listen(notificationTapProvider, (previous, taskId) {
      if (taskId == null) return;
      // A series-occurrence alert carries its key; open the day it is on
      // now (it may have been moved).
      final occurrenceKey = occurrenceKeyFromPayload(taskId);
      final scheduledAt = occurrenceKey == null
          ? ref.read(taskByIdProvider(taskId))?.scheduledAt
          : ref
                .read(occurrenceStoreProvider.notifier)
                .currentTask(occurrenceKey)
                .scheduledAt;
      if (scheduledAt != null) {
        ref.read(selectedDateProvider.notifier).goTo(scheduledAt);
      }
      // Spatial, not Zone view — a tapped notification's task has a real
      // scheduled time, and spatial is the mode with a time axis to show
      // it against (Zone view has none). Forces the merged Timeline
      // destination into spatial mode even if the user had it in Zone
      // view, same as switching tabs used to do outright.
      ref.read(zoneViewEnabledSettingProvider.notifier).set(false);
      _clearTimelineSelections();
      setState(() {
        _pageMotionForward = _selectedIndex == 0;
        _selectedIndex = 0;
      });
      ref.read(notificationTapProvider.notifier).consume();
    });

    // **2026-09-20 — Edit Mode and quick-create no longer hide a bottom
    // nav bar**, since there isn't one any more; the top nav is a small,
    // static row (unlike the old floating pill, it doesn't compete for
    // the same screen real-estate a full-screen Edit Mode or a
    // bottom-docked quick-create sheet needs), so it always stays put.
    // (The bottom DOCK described in the nav spec — List/Timeline/Edit/
    // What Matters — is a separate, not-yet-built stage; when it lands it
    // will need its own hide-during-Edit-Mode-and-quick-create handling,
    // matching what this bar used to do.)
    return WhatMattersScene(
      enabled: ref.watch(whatMattersEnabledSettingProvider),
      visible: _selectedIndex == 0,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          // The wide layout takes the top inset inside each pane instead,
          // so the panes' backgrounds reach the window's top edge.
          top: !wide,
          bottom: false,
          // Header painted after the page, so its floating pane's shadow falls
          // over the page rather than under it.
          child: _withSideNav(
            wide: wide,
            sideNav: AppSideNav(
              destinations: _topNavLabels(trackedTabVisible),
              selectedIndex: _selectedIndex,
              settingsSelected: _selectedIndex == screens.length - 1,
              onDestinationSelected: (index) =>
                  _selectDestination(index, zoneViewEnabled: zoneViewEnabled),
              onSettingsTap: () => _openSettings(screens.length - 1),
            ),
            child: AppHeaderOverContent(
              // No side padding here: the header's elements inset themselves
              // (the nav text, and the route pane with its own tighter inset).
              header: _wideAwareHeader(
                wide: wide,
                header: Padding(
                  padding: EdgeInsets.only(bottom: theme.spacingSm),
                  child: AppShellHeader(
                    controller: _chromeController,
                    child: wide
                        ? const SizedBox.shrink()
                        : AppTopNav(
                            destinations: _topNavLabels(trackedTabVisible),
                            // **Real bug, fixed 2026-09-22**: this used to fall back
                            // to `0` whenever `_selectedIndex` was Settings' own
                            // index (out of range for `destinations`, which never
                            // includes it) — which made "Days" light up as active
                            // while Settings was actually open. `_TopNavLabel`'s own
                            // `i == selectedIndex` comparison never matches `i`
                            // against Settings' index anyway (`destinations` only
                            // ever runs 0..settingsIndex-1), so passing the real
                            // index through unclamped correctly leaves every label
                            // unselected — `settingsSelected` below is what now
                            // carries the "Settings is active" signal instead, onto
                            // the gear icon.
                            selectedIndex: _selectedIndex,
                            settingsSelected:
                                _selectedIndex == screens.length - 1,
                            onDestinationSelected: (index) =>
                                _selectDestination(
                                  index,
                                  zoneViewEnabled: zoneViewEnabled,
                                ),
                            onSettingsTap: () =>
                                _openSettings(screens.length - 1),
                          ),
                  ),
                ),
              ),
              content: AppShellChromeScope(
                controller: _chromeController,
                child: Stack(
                  children: [
                    Navigator(
                      key: _contentNavigatorKey,
                      observers: [_contentContextMenuNavigatorObserver],
                      onGenerateRoute: (_) => PageRouteBuilder<void>(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ValueListenableBuilder<_ShellScene?>(
                              valueListenable: _sceneNotifier,
                              builder: (context, scene, child) => scene == null
                                  ? const SizedBox.shrink()
                                  : AppViewTransition(
                                      viewId: scene.viewId,
                                      // Fade by default; the slide (with
                                      // trailing items) is a dev toggle.
                                      slide: ref.watch(
                                        devPageSlideMotionProvider,
                                      ),
                                      forward: scene.forward,
                                      child: scene.child,
                                    ),
                            ),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          // Sides match the bottom gap (safe area + clearance).
                          padding: EdgeInsets.only(
                            left: DockTokens.edgeInset(
                              theme,
                              MediaQuery.viewPaddingOf(context),
                            ),
                            right: DockTokens.edgeInset(
                              theme,
                              MediaQuery.viewPaddingOf(context),
                            ),
                            bottom: theme.spacingBottomClearance,
                          ),
                          child: AppBottomDock(
                            activeView: zoneViewEnabled
                                ? AppBottomDockView.list
                                : AppBottomDockView.timeline,
                            onSelectView: (view) {
                              _clearTimelineSelections();
                              ref
                                  .read(zoneViewEnabledSettingProvider.notifier)
                                  .set(view == AppBottomDockView.list);
                            },
                            onEditTap: () {
                              _clearTimelineSelections();
                              showEditScreen(
                                context,
                                navigator: _contentNavigatorKey.currentState,
                              );
                            },
                            whatMattersEnabled: ref.watch(
                              whatMattersEnabledSettingProvider,
                            ),
                            onWhatMattersTap: () {
                              _clearTimelineSelections();
                              ref
                                  .read(
                                    whatMattersEnabledSettingProvider.notifier,
                                  )
                                  .set(
                                    !ref.read(
                                      whatMattersEnabledSettingProvider,
                                    ),
                                  );
                            },
                            visible:
                                activeIndex == 0 &&
                                ref.watch(pendingTaskDraftProvider) == null &&
                                !ref.watch(editModeEnabledProvider),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The shell header. In the wide layout the nav lives in the sidebar, so
  /// the header only takes space while a screen has claimed it (e.g. the
  /// Edit screen's Things | Zones switch) — otherwise the content starts at
  /// the top instead of under an empty nav-height band.
  Widget _wideAwareHeader({required bool wide, required Widget header}) => wide
      ? ListenableBuilder(
          listenable: _chromeController,
          builder: (context, _) => _chromeController.header == null
              ? const SizedBox.shrink()
              : header,
        )
      : header;

  /// The wide layout puts [sideNav] left of the shell and the create/edit
  /// panel ([TaskInspectorPanel], zero-width while closed) right of it;
  /// narrower windows keep the phone layout ([child] alone, with its own
  /// top nav, and tasks open in bottom sheets).
  Widget _withSideNav({
    required bool wide,
    required Widget sideNav,
    required Widget child,
  }) => wide
      // Pointer-sized controls: every button rung one step smaller.
      ? DesktopDensity.apply(
          context,
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sideNav,
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top,
                  ),
                  child: child,
                ),
              ),
              const TaskInspectorPanel(),
            ],
          ),
        )
      : child;
}
