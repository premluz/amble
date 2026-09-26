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
import 'core/tokens/type_primitives.dart';
import 'core/widgets/app_bottom_dock.dart';
import 'core/widgets/app_shell_chrome.dart';
import 'core/widgets/app_shell_header.dart';
import 'core/widgets/app_top_nav.dart';
import 'core/widgets/app_view_transition.dart';
import 'core/widgets/what_matters_motion.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/onboarding/onboarding_quiz_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/splash_carousel_screen.dart';
import 'features/timeline/selected_date_provider.dart';
import 'features/timeline/edit_mode_provider.dart';
import 'features/timeline/pending_task_draft_provider.dart';
import 'features/timeline/timeline_screen.dart';
import 'features/tracked_behavior/tracked_behavior_list_screen.dart';
import 'features/zone_grid/zone_grid_screen.dart';
import 'hive_registrar.g.dart';
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
import 'shared/providers/tracked_behavior_providers.dart';
import 'shared/providers/zone_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<Task>(taskBoxName);
  // Opened but unused until the TrackedBehavior UI exists (gated behind
  // FeatureFlags.trackedBehaviorEnabled) — the box must be open for
  // trackedBehaviorRepositoryProvider to resolve if anything ever reads it.
  await Hive.openBox<TrackedBehavior>(trackedBehaviorBoxName);
  // Opened but unused until a Zone UI exists (gated behind
  // FeatureFlags.zoneEnabled) — same "additive, inert data layer" pattern
  // as trackedBehaviorBoxName above.
  await Hive.openBox<Zone>(zoneBoxName);
  await HiveZoneFacetRepository.initialize();
  // The user-extensible category entity — seeded with 5 built-in rows and
  // backfilled onto existing tasks below, once, at launch.
  await Hive.openBox<Category>(categoryBoxName);
  // User-created Inbox folders — no seeding, every Section is user-made.
  await Hive.openBox<Section>(sectionBoxName);
  // Reusable task blueprints, surfaced on the Inbox's "Templates" tab —
  // ungated (free functionality, same tier as Category), see
  // CONSTITUTION.md's "TaskTemplate" section.
  await Hive.openBox<TaskTemplate>(taskTemplateBoxName);
  // Small key-value store for app preferences (theme mode today, more
  // later). Untyped box: it holds heterogeneous primitive/adapter values by
  // design — see PreferencesRepository.
  await Hive.openBox<dynamic>(preferencesBoxName);
  // Tracks device-calendar event ids created by Feature 2's manual sync-out
  // — see CONSTITUTION.md's "Calendar" section and SyncedCalendarEvent's
  // own doc comment for why this can't just live in `preferences`.
  await Hive.openBox<SyncedCalendarEvent>(syncedCalendarEventBoxName);

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
  final purchasesConfigured = await container
      .read(purchasesRepositoryProvider)
      .configure();
  if (purchasesConfigured) {
    container.read(pantaCustomerInfoProvider); // starts the listener
    await container.read(pantaCustomerInfoProvider.notifier).refresh();
  } else {
    debugPrint(
      'RevenueCat not configured — purchases disabled for this build. '
      'Pass --dart-define=REVENUECAT_IOS_API_KEY=... and/or '
      '--dart-define=REVENUECAT_ANDROID_API_KEY=... to enable them.',
    );
  }

  final notificationService = container.read(notificationServiceProvider);
  await notificationService.initialize(
    onNotificationTap: (taskId) =>
        container.read(notificationTapProvider.notifier).set(taskId),
  );
  await notificationService.handleColdStartLaunch(
    onNotificationTap: (taskId) =>
        container.read(notificationTapProvider.notifier).set(taskId),
  );

  // One-time migration: an existing user's single `TaskSize` choice seeds
  // the newly-independent `TaskFontSize` setting, by name, exactly once —
  // see `TaskFontSizeSetting.migrateIfNeeded`'s own doc comment for why
  // this happens here (an explicit, awaited launch step) rather than as a
  // side effect of that provider's own `build()`.
  await container.read(taskFontSizeSettingProvider.notifier).migrateIfNeeded();

  // Seed the 5 built-in categories and backfill every pre-existing task's
  // deprecated `category` enum onto the new `categoryId`. Launch-only,
  // gated by PreferenceKeys.categoriesSeeded so it only actually runs
  // once per install — see docs/DECISIONS.md.
  await container
      .read(categoryListProvider.notifier)
      .seedBuiltInsAndBackfillIfNeeded();

  // Backfill `Task.createdAt` for every pre-existing row saved before
  // that field existed. Launch-only, gated by
  // PreferenceKeys.taskCreatedAtBackfilled, same "once per install"
  // shape as the category backfill just above — see
  // `TaskList.backfillCreatedAtIfNeeded`'s own doc comment and
  // docs/DECISIONS.md.
  await container.read(taskListProvider.notifier).backfillCreatedAtIfNeeded();

  // Top up each recurring series' rolling window. Launch-only by design
  // (see docs/DECISIONS.md) — the Timeline stays a pure reader, and the
  // 8-week window means a session would have to stay open for weeks before
  // running dry. Idempotent, so this never duplicates existing instances.
  await container.read(taskListProvider.notifier).materializeDueRecurrences();
  // Collapses duplicate same-titled Zone series into one, and detaches
  // any orphaned series (rows carrying a recurrenceId whose template no
  // longer exists). Runs BEFORE the top-up below, so materialization
  // never re-fills a series that is about to be removed. Idempotent and a
  // no-op on healthy data — see `ZoneList.repairDuplicateZoneSeries`.
  //
  // Needed because two now-fixed bugs could mint parallel series for one
  // zone (see docs/ERROR_LOG.md); this repairs installs that already
  // accumulated them, which a code fix alone cannot do.
  await container.read(zoneListProvider.notifier).migrateToWeeklySchedule();
  // Same rolling-window top-up, for Zone's own materialized recurring
  // instances (see docs/DECISIONS.md — Zone materialization session).
  // Mirrors the Task call above exactly, including trigger point (app
  // open, before notification refresh) and idempotency.
  await container.read(zoneListProvider.notifier).materializeDueRecurrences();

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
  unawaited(() async {
    await container
        .read(taskListProvider.notifier)
        .refreshScheduledNotifications();
    await container
        .read(zoneListProvider.notifier)
        .refreshScheduledNotifications();
  }());

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
    Workmanager()
        .initialize(backgroundTaskDispatcher)
        .then(
          (_) => registerMorningSummaryTask(
            enabled: container.read(slackSummaryEnabledSettingProvider),
          ),
        ),
  );

  // Native Siri calls wait for this handshake, not for a visible UI frame.
  // The iOS host and its eventual scene share this engine and these boxes.
  unawaited(registerAppIntentChannel(container));

  runApp(
    UncontrolledProviderScope(container: container, child: const AmbleApp()),
  );
}

class AmbleApp extends ConsumerWidget {
  const AmbleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeSettingProvider);
    final hasSeenSplash = ref.watch(hasSeenSplashProvider);
    // A separate step from the splash/carousel above, not folded into it
    // — confirmed directly: "we need to keep carousel and separately
    // onboarding slides." Only consulted once hasSeenSplash is already
    // true; the carousel's own CTA is completely unchanged.
    final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);
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
    var lightTheme = _resolvePillSize(AmbleTheme.light, taskSize);
    var darkTheme = _resolvePillSize(AmbleTheme.dark, taskSize);
    lightTheme = _resolveFontSize(lightTheme, taskFontSize);
    darkTheme = _resolveFontSize(darkTheme, taskFontSize);
    lightTheme = _resolvePillShape(lightTheme, pillShape);
    darkTheme = _resolvePillShape(darkTheme, pillShape);

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
        debugShowCheckedModeBanner: false,
        title: 'Amble',
        theme: _themeDataFor(lightTheme, Brightness.light),
        darkTheme: _themeDataFor(darkTheme, Brightness.dark),
        themeMode: toFlutterThemeMode(themeMode),
        // Three-way gate, both provider-watched so each CTA's write
        // triggers an immediate rebuild with no separate Navigator.push:
        // splash/carousel first (HasSeenSplash), then the onboarding
        // Profile quiz (HasCompletedOnboarding) as its own distinct step
        // — confirmed directly, "keep carousel and separately onboarding
        // slides" — then the real app. Skipping the quiz still calls
        // markDone(), so it can never be re-shown after either a genuine
        // choice or an explicit skip.
        home: !hasSeenSplash
            ? SplashCarouselScreen(onFinished: () {})
            : !hasCompletedOnboarding
            ? const OnboardingQuizScreen()
            : const AmbleHome(),
      ),
    );
  }
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

  /// **2026-09-20 — top nav replaces the bottom `NavigationBar` as the
  /// primary section switcher.** Requested directly, as a deliberate
  /// reversal of conventional mobile navigation: "Top: choose the part of
  /// Panta. Bottom: choose how to work with your day." Day/Inbox/Tracked
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
  /// not a fourth quiet label indistinguishable from Day/Inbox/Tracked.
  ///
  /// "Tracked" is present when [FeatureFlags.trackedBehaviorEnabled] is on
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
  List<Widget> _screens(bool trackedTabVisible, TimelineDisplayMode mode) => [
    TimelineScreen(mode: mode),
    const InboxScreen(),
    if (trackedTabVisible) const TrackedBehaviorListScreen(),
    const SettingsScreen(),
  ];

  /// The top nav's own quiet text labels — "Day" (renamed from the old
  /// icon-only "Timeline" destination's tooltip, matching the spec's own
  /// naming), "Inbox", and "Tracked" when visible. Kept in the SAME order
  /// as [_screens]'s first three entries; Settings (index 3) is
  /// deliberately excluded — see [_screens]'s own doc comment.
  List<String> _topNavLabels(bool trackedTabVisible) => [
    'Day',
    'Inbox',
    if (trackedTabVisible) 'Tracked',
  ];

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
    final screens = _screens(trackedTabVisible, timelineMode);
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
        key: '$activeIndex:$activeViewId:${timelineMode.name}:$trackedTabVisible',
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
    // never itself be removed by this toggle (only "Tracked" can), so it's
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
      final task = ref.read(taskByIdProvider(taskId));
      final scheduledAt = task?.scheduledAt;
      if (scheduledAt != null) {
        ref.read(selectedDateProvider.notifier).goTo(scheduledAt);
      }
      // Spatial, not Zone view — a tapped notification's task has a real
      // scheduled time, and spatial is the mode with a time axis to show
      // it against (Zone view has none). Forces the merged Timeline
      // destination into spatial mode even if the user had it in Zone
      // view, same as switching tabs used to do outright.
      ref.read(zoneViewEnabledSettingProvider.notifier).set(false);
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
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacingScreenPadding,
                theme.spacingSm,
                theme.spacingScreenPadding,
                theme.spacingSm,
              ),
              child: AppShellHeader(controller: _chromeController, child: AppTopNav(
                destinations: _topNavLabels(trackedTabVisible),
                // **Real bug, fixed 2026-09-22**: this used to fall back
                // to `0` whenever `_selectedIndex` was Settings' own
                // index (out of range for `destinations`, which never
                // includes it) — which made "Day" light up as active
                // while Settings was actually open. `_TopNavLabel`'s own
                // `i == selectedIndex` comparison never matches `i`
                // against Settings' index anyway (`destinations` only
                // ever runs 0..settingsIndex-1), so passing the real
                // index through unclamped correctly leaves every label
                // unselected — `settingsSelected` below is what now
                // carries the "Settings is active" signal instead, onto
                // the gear icon.
                selectedIndex: _selectedIndex,
                settingsSelected: _selectedIndex == screens.length - 1,
                // Tapping the Day destination (index 0) again while it's
                // already selected toggles spatial/Zone view — the
                // nav-tap half of "1 nav item, but when tapped again it
                // switches view," mirrored by `AppCalendarHeader`'s own
                // switcher button reaching the same provider.
                onDestinationSelected: (index) {
                  if (index == 0 && _selectedIndex == 0) {
                    ref
                        .read(zoneViewEnabledSettingProvider.notifier)
                        .set(!zoneViewEnabled);
                    return;
                  }
                  setState(() {
                    _pageMotionForward = index > _selectedIndex;
                    _selectedIndex = index;
                  });
                },
                onSettingsTap: () {
                  final settingsIndex = screens.length - 1;
                    final wasAlreadyOnSettings =
                        _selectedIndex == settingsIndex;
                  setState(() {
                    _pageMotionForward = settingsIndex > _selectedIndex;
                    _selectedIndex = settingsIndex;
                  });
                  // Only on an actual transition INTO Settings, not on a
                  // repeated tap while already there — `onSettingsTap` fires
                  // on every tap regardless of current tab, unlike
                  // `onDestinationSelected`'s own already-selected check
                  // above.
                  if (!wasAlreadyOnSettings &&
                      FeatureFlags.subscriptionEnabled &&
                      RevenueCatConfig.isAvailable) {
                    unawaited(
                      ref
                          .read(purchasesRepositoryProvider)
                          .presentPaywallIfNeeded(
                            RevenueCatConfig.pantaProEntitlementId,
                          ),
                    );
                  }
                },
              )),
            ),
            Expanded(
              child: AppShellChromeScope(
                controller: _chromeController,
                child: Stack(
                  children: [
                    Navigator(
                      key: _contentNavigatorKey,
                      onGenerateRoute: (_) => PageRouteBuilder<void>(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ValueListenableBuilder<_ShellScene?>(
                              valueListenable: _sceneNotifier,
                              builder: (context, scene, child) => scene == null
                                  ? const SizedBox.shrink()
                                  : AppViewTransition(
                                      viewId: scene.viewId,
                                      slide: true,
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
                          padding: EdgeInsets.all(theme.spacingMd),
                          child: AppBottomDock(
                            activeView: zoneViewEnabled
                                ? AppBottomDockView.list
                                : AppBottomDockView.timeline,
                            onSelectView: (view) => ref
                                .read(zoneViewEnabledSettingProvider.notifier)
                                .set(view == AppBottomDockView.list),
                            onEditTap: () => showEditScreen(
                              context,
                              navigator: _contentNavigatorKey.currentState,
                            ),
                            whatMattersEnabled: ref.watch(
                              whatMattersEnabledSettingProvider,
                            ),
                            onWhatMattersTap: () => ref
                                .read(
                                  whatMattersEnabledSettingProvider.notifier,
                                )
                                .set(
                                  !ref.read(whatMattersEnabledSettingProvider),
                                ),
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
            ],
          ),
        ),
      ),
    );
  }
}
