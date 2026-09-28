import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

/// RevenueCat public SDK API keys. The iOS key ships as a real default so
/// an ordinary `flutter build ipa`/Xcode archive has purchases working with
/// no flags — **2026-09-28**, reversing the earlier "no default, must be
/// supplied via `--dart-define` every build" posture after it was pointed
/// out directly: an Xcode archive doesn't go through a `flutter build`
/// invocation this repo controls, so there was no way to attach the define
/// to it at all, and every archived build silently shipped with purchases
/// disabled. `--dart-define=REVENUECAT_IOS_API_KEY=...` still overrides the
/// default when one is needed (e.g. a different RevenueCat project).
///
/// This is the App Store PUBLIC SDK key (`appl_` prefix) — RevenueCat's own
/// model treats this as safe to embed client-side, unlike a secret key
/// (`sk_`, never committed) or the Test Store key (`test_`, debug-only —
/// see [keyForCurrentPlatformOrNull]'s own assert).
///
/// The Android key is unchanged — still `--dart-define`-only, no default,
/// since Android isn't shipping yet. See docs/DECISIONS.md for why this
/// lives here instead of `core/dev_config.dart` (that file is `kDebugMode`
/// scratch config; this is real, required-in-every-build config).
///
/// A missing/empty key resolves to [RevenueCatConfig.isAvailable] reporting
/// "purchases unavailable" — the app then runs normally without them
/// rather than failing to start. See
/// [RevenueCatConfig.keyForCurrentPlatformOrNull] for why this degrades
/// instead of throwing.
abstract final class RevenueCatConfig {
  static const String _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: 'appl_sbyrPnVlPLjIPVJDNuGphjWRQDk',
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
    // Debug-only guard against a wrong key prefix landing in the default
    // or a `--dart-define` override — e.g. RevenueCat's Test Store key
    // (`test_`) or a secret key (`sk_`) where the App Store public key
    // (`appl_`) belongs. Asserts strip from release builds, so this
    // catches the mistake in development; it is not what keeps a wrong
    // key out of a shipped build — the default value itself is.
    assert(
      key.isEmpty || key.startsWith('appl_') || key.startsWith('goog_'),
      'Wrong RevenueCat key prefix for $defaultTargetPlatform: $key',
    );
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
