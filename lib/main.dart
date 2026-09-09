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
import 'core/tokens/color_primitives.dart';
import 'core/tokens/semantic_theme.dart';
import 'core/tokens/type_primitives.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/splash_carousel_screen.dart';
import 'features/timeline/edit_mode_provider.dart';
import 'features/timeline/pending_task_draft_provider.dart';
import 'features/timeline/selected_date_provider.dart';
import 'features/timeline/timeline_screen.dart';
import 'features/tracked_behavior/tracked_behavior_list_screen.dart';
import 'hive_registrar.g.dart';
import 'shared/models/app_theme_mode.dart';
import 'shared/models/category.dart';
import 'shared/models/synced_calendar_event.dart';
import 'shared/models/task.dart';
import 'shared/models/task_size.dart';
import 'shared/models/task_template.dart';
import 'shared/models/tracked_behavior.dart';
import 'shared/models/zone.dart';
import 'shared/providers/calendar_providers.dart';
import 'shared/providers/category_providers.dart';
import 'shared/providers/notification_providers.dart';
import 'shared/providers/notification_tap_provider.dart';
import 'shared/providers/task_providers.dart';
import 'shared/providers/task_template_providers.dart';
import 'shared/providers/preferences_providers.dart';
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
  // The user-extensible category entity — seeded with 5 built-in rows and
  // backfilled onto existing tasks below, once, at launch.
  await Hive.openBox<Category>(categoryBoxName);
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
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.initialize(
    onNotificationTap: (taskId) =>
        container.read(notificationTapProvider.notifier).set(taskId),
  );
  await notificationService.handleColdStartLaunch(
    onNotificationTap: (taskId) =>
        container.read(notificationTapProvider.notifier).set(taskId),
  );

  // Seed the 5 built-in categories and backfill every pre-existing task's
  // deprecated `category` enum onto the new `categoryId`. Launch-only,
  // gated by PreferenceKeys.categoriesSeeded so it only actually runs
  // once per install — see docs/DECISIONS.md.
  await container
      .read(categoryListProvider.notifier)
      .seedBuiltInsAndBackfillIfNeeded();

  // Top up each recurring series' rolling window. Launch-only by design
  // (see docs/DECISIONS.md) — the Timeline stays a pure reader, and the
  // 8-week window means a session would have to stay open for weeks before
  // running dry. Idempotent, so this never duplicates existing instances.
  await container.read(taskListProvider.notifier).materializeDueRecurrences();
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
  unawaited(
    container.read(taskListProvider.notifier).refreshScheduledNotifications(),
  );
  // Same reasoning as the task refresh above, for Zone's own notifications
  // — now each materialized instance schedules against its own real
  // `anchorDate`, replacing the former one-shot, re-resolved-on-save
  // workaround (see docs/DECISIONS.md). Without this launch-time pass, an
  // instance that later moves into the horizon would never pick up an
  // alarm until its zone happened to be re-saved.
  unawaited(
    container.read(zoneListProvider.notifier).refreshScheduledNotifications(),
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
    // One global rung (sm/md/lg) resolved onto BOTH light and dark
    // palettes here, once, before either reaches MaterialApp — every
    // existing call site (TaskCapsuleBlock, ZoneContainerBlock,
    // OverlapClusterBlock) keeps reading the same `sizeTaskBadge`/
    // `textTaskTitle` fields it always has, with no per-call-site changes.
    // Requested directly: "it's not per view, it's a setting, that when
    // set affects all."
    final taskSize = ref.watch(taskSizeSettingProvider);
    final lightTheme = _resolveTaskSize(AmbleTheme.light, taskSize);
    final darkTheme = _resolveTaskSize(AmbleTheme.dark, taskSize);

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
        // First launch shows the splash/carousel once — HasSeenSplash
        // defaults to false until its CTA calls markSeen(), at which point
        // this rebuild (the provider is watched, not read) swaps straight
        // to the real app with no separate Navigator.push, matching
        // "route straight into the existing app" per docs/SCOPE.md rather
        // than introducing a stub onboarding step.
        home: hasSeenSplash
            ? const AmbleHome()
            : SplashCarouselScreen(onFinished: () {}),
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

/// Resolves the ACTIVE `sizeTaskBadge`/`textTaskTitle` fields on [palette]
/// to whichever fixed rung [size] selects — see `TaskSizeSetting`'s own
/// doc comment. Every real call site reads `theme.sizeTaskBadge`/
/// `theme.textTaskTitle` directly and has no idea this setting exists;
/// this is the one place the mapping happens.
AmbleTheme _resolveTaskSize(AmbleTheme palette, TaskSize size) {
  return switch (size) {
    TaskSize.sm => palette.copyWith(
      sizeTaskBadge: palette.sizeTaskBadgeSm,
      textTaskTitle: palette.textTaskTitleSm,
    ),
    TaskSize.md => palette.copyWith(
      sizeTaskBadge: palette.sizeTaskBadgeMd,
      textTaskTitle: palette.textTaskTitleMd,
    ),
    TaskSize.lg => palette.copyWith(
      sizeTaskBadge: palette.sizeTaskBadgeLg,
      textTaskTitle: palette.textTaskTitleLg,
    ),
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
    scaffoldBackgroundColor: palette.colorSurfacePrimary,
    // App-wide font fallback — every text style built from `AmbleTheme`'s
    // own tokens already carries `TypePrimitives.fontFamily` explicitly
    // (see semantic_theme.dart), but this covers default Material text
    // that ISN'T one of ours (an AlertDialog action, a SnackBar) so
    // nothing on screen falls back to the platform default font.
    fontFamily: TypePrimitives.fontFamily,
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

class _AmbleHomeState extends ConsumerState<AmbleHome> {
  int _selectedIndex = 1;

  /// Inbox / Timeline / [Tracked] / Settings, per docs/SCOPE.md's
  /// navigation structure. "Tracked" is present when
  /// [FeatureFlags.trackedBehaviorEnabled] is on (default true) AND — in a
  /// debug build only — the `DevTrackedTabInCycle` dev toggle
  /// (`core/dev_config.dart`) hasn't been switched off; the flag omits the
  /// destination entirely rather than showing a disabled one.
  ///
  /// Deliberately inserted AFTER Timeline, not before it: the
  /// notification-tap handler below hardcodes `_selectedIndex = 1` for
  /// "switch to the Timeline", so anything added ahead of Timeline would
  /// silently redirect every notification tap to the wrong screen. Same
  /// reasoning the Phase 7 "Backup" tab was placed after Timeline for —
  /// see docs/DECISIONS.md.
  ///
  /// Computed per-build (not `static final`) now that visibility can
  /// change at runtime via the dev toggle — `ref.watch`ing
  /// `devTrackedTabInCycleProvider` needs a live rebuild, which a
  /// once-computed static list can never give. The `isDevConfigAvailable`
  /// guard (a `kDebugMode` re-export) means this collapses back to the
  /// plain flag check in release, exactly like `TimelineScreen`'s own
  /// `zoneViewEnabled` resolution already does for `DevZoneViewInCycle`.
  List<Widget> _screens(bool trackedTabVisible) => [
    const InboxScreen(),
    const TimelineScreen(),
    if (trackedTabVisible) const TrackedBehaviorListScreen(),
    const SettingsScreen(),
  ];

  /// The nav destinations, kept in the SAME order as [_screens] — the two
  /// are indexed by one shared `_selectedIndex`, so a divergence between
  /// them would silently show the wrong screen for a tapped tab.
  List<NavigationDestination> _destinations(bool trackedTabVisible) => [
    const NavigationDestination(
      icon: Icon(Icons.inbox_rounded),
      // "Inbox" -> "Manage" — matches the in-screen heading, requested
      // directly alongside adding the Zones/Categories sub-tabs.
      label: 'Manage',
    ),
    const NavigationDestination(
      icon: Icon(Icons.view_day_rounded),
      label: 'Timeline',
    ),
    if (trackedTabVisible)
      const NavigationDestination(
        icon: Icon(Icons.track_changes_rounded),
        label: 'Tracked',
      ),
    const NavigationDestination(
      icon: Icon(Icons.settings_rounded),
      label: 'Settings',
    ),
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
    final screens = _screens(trackedTabVisible);

    // The dev toggle can shrink the tab list at runtime (unlike the
    // compile-time flag, which can't change after launch) — if the
    // currently-selected index no longer exists, fall back to Timeline
    // rather than crashing IndexedStack/NavigationBar on an out-of-range
    // index. Mirrors `DevZoneViewInCycle`'s own "don't strand the user in
    // a mode the toggle just removed" reasoning.
    if (_selectedIndex >= screens.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = 1);
      });
    }

    ref.listen(notificationTapProvider, (previous, taskId) {
      if (taskId == null) return;
      final task = ref.read(taskByIdProvider(taskId));
      final scheduledAt = task?.scheduledAt;
      if (scheduledAt != null) {
        ref.read(selectedDateProvider.notifier).goTo(scheduledAt);
      }
      setState(() => _selectedIndex = 1);
      ref.read(notificationTapProvider.notifier).consume();
    });

    // Timeline is always index 1 in `_screens`/`_destinations` (see their
    // own doc comments — the tracked tab only ever inserts AFTER it), so
    // this checks "is Timeline the visible tab" without needing to derive
    // the index from `trackedTabVisible`. Hidden entirely (not just
    // disabled) while Edit Mode is active on that tab — requested
    // directly: "in edit mode we don't see main menu and days and view
    // switching." Reported directly as a real gap: the task edit sheet's
    // OWN full-screen route already covers this bar for free (a separate,
    // unrelated feature), which is not true here — Edit Mode is a toggle
    // on the same already-visible TimelineScreen, not a pushed route, so
    // nothing hid this bar until now.
    // Same reasoning as the Edit Mode case just above — the quick-create
    // overlay's own small sheet is meant to cover the nav bar's own
    // screen real estate (reported directly, from a screenshot: "should
    // cover main nav currently it opens above main nav"), and like Edit
    // Mode, it's a state on the already-visible TimelineScreen rather
    // than a pushed route, so nothing else hides this bar for it.
    final hideBottomNav =
        _selectedIndex == 1 &&
        (ref.watch(editModeEnabledProvider) ||
            ref.watch(pendingTaskDraftProvider) != null);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex < screens.length ? _selectedIndex : 1,
        children: screens,
      ),
      bottomNavigationBar: hideBottomNav
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex < screens.length
                  ? _selectedIndex
                  : 1,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              backgroundColor: theme.colorSurfacePrimary,
              // Material 3's NavigationBar applies its own surfaceTintColor
              // overlay by default (derived from ColorScheme.fromSeed), which
              // paints OVER an explicit backgroundColor rather than being
              // overridden by it — a real, pre-existing dark-mode bug found
              // while verifying this session's splash screen: the nav bar
              // stayed white in dark mode despite backgroundColor already being
              // wired to theme.colorSurfacePrimary at Phase 5. Zeroing the tint
              // out makes backgroundColor the only thing that paints. See
              // docs/DECISIONS.md.
              surfaceTintColor: ColorPrimitives.transparent,
              destinations: _destinations(trackedTabVisible),
            ),
    );
  }
}
