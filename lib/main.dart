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
import 'core/tokens/spacing_primitives.dart';
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
import 'shared/models/pill_shape.dart';
import 'shared/models/task_size.dart';
import 'shared/models/task_template.dart';
import 'shared/models/tracked_behavior.dart';
import 'shared/models/zone.dart';
import 'shared/repositories/zone_facet_repository.dart';
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
  await HiveZoneFacetRepository.initialize();
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
    // One global rung (sm/md/lg) resolved onto BOTH light and dark
    // palettes here, once, before either reaches MaterialApp — every
    // existing call site (TaskCapsuleBlock, ZoneContainerBlock,
    // OverlapClusterBlock) keeps reading the same `sizeTaskBadge`/
    // `textTaskTitle` fields it always has, with no per-call-site changes.
    // Requested directly: "it's not per view, it's a setting, that when
    // set affects all."
    final taskSize = ref.watch(taskSizeSettingProvider);
    // Same "resolve once, here, before MaterialApp" mechanism as taskSize
    // above — see PillShapeSetting's own doc comment. Requested directly:
    // "this should affect globally, in edit tasks etc."
    final pillShape = ref.watch(pillShapeSettingProvider);
    var lightTheme = _resolveTaskSize(AmbleTheme.light, taskSize);
    var darkTheme = _resolveTaskSize(AmbleTheme.dark, taskSize);
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
///
/// **Decoupled 2026-09-10** (requested directly): each named option now
/// pairs a badge rung with a font rung ONE STEP SMALLER, rather than the
/// matching-named rung — "Current medium size but with font size from
/// small should be small... Current large but with the font size medium
/// should be medium... large should be larger task pill but font size
/// same as medium." Exact pairing:
/// - sm: badge md (24) + font sm (12) — was badge sm (20) + font sm (12).
/// - md: badge lg (28) + font md (14) — was badge md (24) + font md (14).
/// - lg: badge xl (32, new) + font md (14) — was badge lg (28) + font lg
///   (16); lg's own font rung is no longer used by this mapping at all,
///   kept only as a named token in case a future rung needs it.
AmbleTheme _resolveTaskSize(AmbleTheme palette, TaskSize size) {
  return switch (size) {
    TaskSize.sm => palette.copyWith(
      sizeTaskBadge: palette.sizeTaskBadgeMd,
      textTaskTitle: palette.textTaskTitleSm,
      // Zone view's own title font is always one rung up from the active
      // one — see AmbleTheme.textTaskTitleZone's own doc comment.
      // Requested directly: "Size of text in zone view (task name one
      // scale up)."
      textTaskTitleZone: palette.textTaskTitleMd,
    ),
    TaskSize.md => palette.copyWith(
      sizeTaskBadge: palette.sizeTaskBadgeLg,
      textTaskTitle: palette.textTaskTitleMd,
      textTaskTitleZone: palette.textTaskTitleLg,
    ),
    // **2026-09-12** — was `textTaskTitleMd` (a deliberate "large should
    // be a larger pill but font size same as medium" decision, confirmed
    // directly at the time). Reversed on THIS session's own direct
    // request ("reduce 1 scale down" across all 3 settings, confirmed via
    // AskUserQuestion that lg should get its own genuine one-step
    // reduction rather than stay paired with md): `textTaskTitleLg` now
    // renders at its own size (14, one step down from its old 16) instead
    // of borrowing md's.
    TaskSize.lg => palette.copyWith(
      sizeTaskBadge: palette.sizeTaskBadgeXl,
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
  int _selectedIndex = 0;

  /// Shorter than Material's own `NavigationBar` default (80px) —
  /// reported directly against a reference screenshot: "it is too big
  /// height." Sized off `spacingXl` (40px) rather than a new literal, so
  /// it stays a real token multiple. Back down from `* 1.6` to `* 1.4`
  /// now that both nav icon states render at the same size again (see
  /// the icon theme below) — the taller ratio was only ever needed to
  /// give a since-reverted larger SELECTED icon room to breathe.
  static const double _navBarHeight = SpacingPrimitives.space9 * 1.4;

  /// **2026-09-12 — restructured**, requested directly with a reference
  /// screenshot: Task view / Timeline / Inbox / [Tracked] / Settings. Task
  /// view (the spatial layout) and Timeline (the Zone-organized layout)
  /// were previously ONE tab with an in-screen switcher
  /// (`ZoneViewEnabledSetting`, cycled by `DayStrip`'s own button, both
  /// removed) — they're now two permanent, separate destinations, both
  /// backed by the same `TimelineScreen` widget forced into one
  /// `TimelineDisplayMode` each (see that enum's own doc comment).
  ///
  /// "Tracked" is present when [FeatureFlags.trackedBehaviorEnabled] is on
  /// (default true) AND — in a debug build only — the
  /// `DevTrackedTabInCycle` dev toggle (`core/dev_config.dart`) hasn't
  /// been switched off; the flag omits the destination entirely rather
  /// than showing a disabled one.
  ///
  /// Task view is index 0 now (was Inbox) — the notification-tap handler
  /// below switches to it directly rather than via a stored index,
  /// avoiding the exact "adding a tab ahead silently redirects every
  /// notification tap" trap the previous ordering's own doc comment
  /// warned about.
  ///
  /// Computed per-build (not `static final`) now that visibility can
  /// change at runtime via the dev toggle — `ref.watch`ing
  /// `devTrackedTabInCycleProvider` needs a live rebuild, which a
  /// once-computed static list can never give.
  List<Widget> _screens(bool trackedTabVisible) => [
    const TimelineScreen(mode: TimelineDisplayMode.spatial),
    const TimelineScreen(mode: TimelineDisplayMode.zone),
    const InboxScreen(),
    if (trackedTabVisible) const TrackedBehaviorListScreen(),
    const SettingsScreen(),
  ];

  /// The nav destinations, kept in the SAME order as [_screens] — the two
  /// are indexed by one shared `_selectedIndex`, so a divergence between
  /// them would silently show the wrong screen for a tapped tab.
  ///
  /// No text labels — requested directly, matching the reference
  /// screenshot's own icon-only nav. `NavigationBar`'s own default label
  /// behavior (always visible) is overridden per-destination via
  /// `NavigationDestinationLabelBehavior.alwaysHide` at the `NavigationBar`
  /// call site rather than here, since that's a display-mode setting of
  /// the bar itself, not a property of any one destination.
  List<NavigationDestination> _destinations(bool trackedTabVisible) => [
    const NavigationDestination(
      icon: Icon(Icons.view_timeline_outlined),
      label: 'Task view',
    ),
    const NavigationDestination(
      icon: Icon(Icons.grid_view_rounded),
      label: 'Timeline',
    ),
    const NavigationDestination(
      icon: Icon(Icons.inbox_rounded),
      // Back to "Inbox", matching the in-screen heading again — requested
      // directly ("header manage > should change to inbox actually").
      // This label has always tracked that heading; it was "Manage" only
      // for as long as the heading was.
      label: 'Inbox',
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
    // currently-selected index no longer exists, fall back to Task view
    // rather than crashing IndexedStack/NavigationBar on an out-of-range
    // index. Mirrors `DevZoneViewInCycle`'s own "don't strand the user in
    // a mode the toggle just removed" reasoning. Task view (index 0) can
    // never itself be removed by this toggle (only "Tracked" can), so it's
    // always a safe fallback.
    if (_selectedIndex >= screens.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = 0);
      });
    }

    ref.listen(notificationTapProvider, (previous, taskId) {
      if (taskId == null) return;
      final task = ref.read(taskByIdProvider(taskId));
      final scheduledAt = task?.scheduledAt;
      if (scheduledAt != null) {
        ref.read(selectedDateProvider.notifier).goTo(scheduledAt);
      }
      // Task view, not Timeline — a tapped notification's task has a real
      // scheduled time, and Task view is the tab with a time axis to show
      // it against (Timeline/Zone view has none).
      setState(() => _selectedIndex = 0);
      ref.read(notificationTapProvider.notifier).consume();
    });

    // Task view AND Timeline are BOTH `TimelineScreen` now (indices 0/1),
    // so this bar hides on either — not just one hardcoded index — while
    // Edit Mode or a quick-create draft is active on whichever of the two
    // is currently showing. Requested directly: "in edit mode we don't
    // see main menu and days and view switching." Reported directly as a
    // real gap: the task edit sheet's OWN full-screen route already
    // covers this bar for free (a separate, unrelated feature), which is
    // not true here — Edit Mode is a toggle on the same already-visible
    // TimelineScreen, not a pushed route, so nothing hid this bar until
    // now.
    // Same reasoning as the Edit Mode case just above — the quick-create
    // overlay's own small sheet is meant to cover the nav bar's own
    // screen real estate (reported directly, from a screenshot: "should
    // cover main nav currently it opens above main nav"), and like Edit
    // Mode, it's a state on the already-visible TimelineScreen rather
    // than a pushed route, so nothing else hides this bar for it.
    final hideBottomNav =
        (_selectedIndex == 0 || _selectedIndex == 1) &&
        (ref.watch(editModeEnabledProvider) ||
            ref.watch(pendingTaskDraftProvider) != null);

    // Which elevation direction the floating nav pane below uses — dark
    // mode separates by getting lighter than the page, light mode by
    // casting a shadow onto it.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex < screens.length ? _selectedIndex : 0,
        children: screens,
      ),
      // A fully-rounded (stadium, not just rounded-corner) floating pill,
      // margined on every side — reworked 2026-09-12 from the previous
      // bottom-flush, bottom-corners-only pane (which used to connect to
      // `AppBottomExtensionBar` stacked directly above it) into a
      // genuinely standalone floating element, matching a reference
      // screenshot: "match aesthetics and nav is just 5 items + its
      // outside" (the "+" is no longer part of this bar at all — see
      // `AppFloatingCreateButton`, positioned independently by each
      // screen). Reported directly as a follow-up, comparing against the
      // same reference: "make it full round not just round corners... it
      // is too big height."
      //
      // Dark mode paints `colorSurfaceOverlay` (ink650, the LIGHTEST
      // surface in the ramp). This corrects a real inversion: the bar
      // used to paint `colorSurfacePrimary`, which in dark mode is
      // `ink900` — the same value as the page background — so the
      // topmost floating element was simultaneously the darkest thing on
      // screen. Light mode keeps a white fill and separates with
      // `shadowPane` instead, since its base is already near-white and
      // "lighter" isn't available as a depth cue there.
      bottomNavigationBar: hideBottomNav
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.spacingMd,
                  0,
                  theme.spacingMd,
                  theme.spacingSm,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorSurfaceOverlay,
                    // A value well past half of _navBarHeight so the
                    // engine clamps it to a true stadium shape (fully
                    // round ends) regardless of the pill's own height,
                    // the same way CSS's `border-radius: 9999px` works —
                    // rather than a fixed token that only happens to look
                    // "full" at one specific height.
                    borderRadius: BorderRadius.circular(999),
                    // No border, per direct request. The earlier hairline
                    // is gone: with the re-anchored ink ramp the overlay
                    // surface is already the lightest step, and that
                    // lightness difference against a near-black page is
                    // what separates the pane — a drawn edge on top of it
                    // read as a hard box rather than a floating surface.
                    // Light mode still gets the shadow, which is its only
                    // available depth cue on a near-white base.
                    boxShadow: isDark ? null : theme.shadowPane,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    // **2026-09-12 — reverted the size bump.** An earlier
                    // pass grew the SELECTED icon specifically (reported,
                    // at the time, as "selected item too small"), but a
                    // screenshot then showed the real effect: with a
                    // bigger icon inside it, Material's own circular
                    // indicator stretches into an oval/pill to fit —
                    // "active icon should not enlarge... ask was to
                    // change color, not [size/shape]." Both states now
                    // render at the SAME size (Material's own flat
                    // default, all icons drawn at `spacingLg`, 24px) —
                    // the indicator's `CircleBorder` below stays a clean
                    // circle once it isn't being stretched to contain a
                    // larger icon. A local `NavigationBarThemeData`
                    // override (rather than the app's own `ThemeData`)
                    // still applies just `colorTextPrimary`, since a
                    // Theme wrapper is still needed for the indicator
                    // color/shape overrides below.
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        navigationBarTheme: NavigationBarThemeData(
                          iconTheme: WidgetStateProperty.all(
                            IconThemeData(
                              size: theme.spacingLg,
                              color: theme.colorTextPrimary,
                            ),
                          ),
                        ),
                      ),
                      child: NavigationBar(
                        // Shorter than Material's own 80px default —
                        // reported directly alongside the shape fix
                        // above.
                        height: _navBarHeight,
                        selectedIndex: _selectedIndex < screens.length
                            ? _selectedIndex
                            : 0,
                        onDestinationSelected: (index) =>
                            setState(() => _selectedIndex = index),
                        // No text labels under the icons — requested
                        // directly, matching the reference screenshot's
                        // own icon-only nav. Each destination's own
                        // `label` (above) is kept regardless, for
                        // accessibility (screen readers still announce
                        // it) and as the tooltip Material shows on
                        // long-press.
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysHide,
                        // A filled circle behind the active icon only —
                        // matches the reference. `colorSurfaceField`, NOT
                        // `colorSurfaceSecondary` (corrected 2026-09-12,
                        // follow-up report: "wrong surface (selected has
                        // darker surface > should have ligher)" —
                        // `colorSurfaceSecondary` is `ink700` in dark
                        // mode, which is actually DARKER than this pane's
                        // own `colorSurfaceOverlay` fill (`ink650`,
                        // already the lightest step in that ramp), the
                        // exact inversion reported. `colorSurfaceField`
                        // sits one genuine step lighter than
                        // `colorSurfaceOverlay` in dark mode and one step
                        // toward the base (a visible, but not stacked-on-
                        // top-of-two-jumps) shift in light mode — also
                        // addresses "surface jump too big... if 2 jumps,
                        // reduce to 1": this is a single perceptual step
                        // off the pill's own fill, not two chained hops
                        // from the page background.
                        indicatorColor: theme.colorSurfaceField,
                        indicatorShape: const CircleBorder(),
                        // Transparent so the DecoratedBox above is what
                        // paints — the pane owns its own fill now.
                        backgroundColor: ColorPrimitives.transparent,
                        // Material 3's NavigationBar applies its own
                        // surfaceTintColor overlay by default (derived
                        // from ColorScheme.fromSeed), which paints OVER
                        // an explicit backgroundColor rather than being
                        // overridden by it — a real, pre-existing
                        // dark-mode bug found while verifying the splash
                        // screen: the nav bar stayed white in dark mode
                        // despite backgroundColor already being wired to
                        // a theme token at Phase 5. Zeroing the tint out
                        // is still required, now so the transparent fill
                        // stays genuinely transparent. See
                        // docs/DECISIONS.md.
                        surfaceTintColor: ColorPrimitives.transparent,
                        destinations: _destinations(trackedTabVisible),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
