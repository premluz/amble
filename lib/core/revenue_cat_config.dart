import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

/// RevenueCat public SDK API keys, read at build time via `--dart-define`
/// rather than committed as string literals — RevenueCat's iOS and Android
/// keys are distinct even for one project, so both are declared and the
/// right one is picked per platform. See docs/DECISIONS.md for why this
/// lives here instead of `core/dev_config.dart` (that file is `kDebugMode`
/// scratch config; this is real, required-in-every-build config).
///
/// A missing define resolves to an empty string, which
/// [RevenueCatConfig.isAvailable] reports as "purchases unavailable" — the
/// app then runs normally without them rather than failing to start. See
/// [RevenueCatConfig.keyForCurrentPlatformOrNull] for why this degrades
/// instead of throwing.
///
/// ```
/// flutter run \
///   --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx \
///   --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx
/// ```
abstract final class RevenueCatConfig {
  static const String _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
  );

  static const String _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );

  /// The public SDK key for the running platform, or null when there is
  /// none to use — either the matching `--dart-define` was not supplied,
  /// or this platform has no RevenueCat SDK at all (only iOS and Android
  /// do; the repo also builds macOS, and widget tests run on neither).
  ///
  /// **Nullable rather than throwing** (2026-09-21). This used to throw a
  /// [StateError], on the reasoning that failing loud beats silently
  /// configuring an empty key. But its one caller is awaited in
  /// `main.dart` BEFORE `runApp`, so the throw never reached a user as a
  /// message — it killed the app to a black screen before any UI existed,
  /// on every desktop run and on any mobile run missing the defines.
  /// Purchases are not load-bearing for the rest of the app, so an
  /// unconfigured build now degrades to "no purchases" and stays usable;
  /// see [isAvailable] and `main.dart`'s own guard.
  static String? get keyForCurrentPlatformOrNull {
    final key = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => _iosApiKey,
      TargetPlatform.android => _androidApiKey,
      _ => '',
    };
    return key.isEmpty ? null : key;
  }

  /// Whether purchases can work at all in this build. False on an
  /// unsupported platform or a build with no API key defined — callers
  /// use it to skip configuration and to show an "unavailable" state
  /// rather than a broken paywall.
  static bool get isAvailable => keyForCurrentPlatformOrNull != null;

  /// The `panta_pro` entitlement identifier, as configured in the
  /// RevenueCat dashboard. A named constant rather than a string literal at
  /// each call site — see CLAUDE.md's "no magic values" rule.
  static const String pantaProEntitlementId = 'panta_pro';
}
