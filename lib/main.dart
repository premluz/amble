import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'core/tokens/color_primitives.dart';
import 'core/tokens/semantic_theme.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/splash_carousel_screen.dart';
import 'features/timeline/selected_date_provider.dart';
import 'features/timeline/timeline_screen.dart';
import 'hive_registrar.g.dart';
import 'shared/models/app_theme_mode.dart';
import 'shared/models/task.dart';
import 'shared/models/tracked_behavior.dart';
import 'shared/providers/notification_providers.dart';
import 'shared/providers/notification_tap_provider.dart';
import 'shared/providers/task_providers.dart';
import 'shared/providers/preferences_providers.dart';
import 'shared/providers/tracked_behavior_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<Task>(taskBoxName);
  // Opened but unused until the TrackedBehavior UI exists (gated behind
  // FeatureFlags.trackedBehaviorEnabled) — the box must be open for
  // trackedBehaviorRepositoryProvider to resolve if anything ever reads it.
  await Hive.openBox<TrackedBehavior>(trackedBehaviorBoxName);
  // Small key-value store for app preferences (theme mode today, more
  // later). Untyped box: it holds heterogeneous primitive/adapter values by
  // design — see PreferencesRepository.
  await Hive.openBox<dynamic>(preferencesBoxName);

  final container = ProviderContainer();
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.initialize(
    onNotificationTap: (taskId) =>
        container.read(notificationTapProvider.notifier).set(taskId),
  );
  await notificationService.handleColdStartLaunch(
    onNotificationTap: (taskId) =>
        container.read(notificationTapProvider.notifier).set(taskId),
  );

  // Top up each recurring series' rolling window. Launch-only by design
  // (see docs/DECISIONS.md) — the Timeline stays a pure reader, and the
  // 8-week window means a session would have to stay open for weeks before
  // running dry. Idempotent, so this never duplicates existing instances.
  await container.read(taskListProvider.notifier).materializeDueRecurrences();

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
        theme: _themeDataFor(AmbleTheme.light, Brightness.light),
        darkTheme: _themeDataFor(AmbleTheme.dark, Brightness.dark),
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

  static const _screens = [InboxScreen(), TimelineScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

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

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_rounded),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_day_rounded),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
