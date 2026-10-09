import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/trial_providers.dart' show trialLengthDays;
import 'splash_carousel_screen.dart' show SplashLogo;

/// One-off first-launch splash: logo, a short value-prop headline, and a
/// single CTA straight into the app — no carousel, no swiping. Requested
/// directly as a dev-toggle-gated alternative to [SplashCarouselScreen]/
/// [OnboardingQuizScreen] (see `DevNewSplashEnabled` in
/// `core/dev_config.dart`), reusing the exact same [SplashLogo] widget
/// (now rendering `assets/branding/logo.svg`) rather than a second logo
/// treatment of its own.
///
/// Shares [HasSeenSplash]/[PreferenceKeys.hasSeenSplash] with the carousel
/// rather than a second "seen" flag: the two are mutually exclusive
/// first-launch experiences picked by a dev toggle, never shown together,
/// so one persisted "have we shown A first-launch splash" flag is
/// sufficient for either.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key, required this.onFinished});

  /// Called after the "seen" preference is persisted — see
  /// [SplashCarouselScreen.onFinished]'s own doc comment for why this
  /// exists alongside the provider watch that already rebuilds `main.dart`.
  final VoidCallback onFinished;

  Future<void> _start(WidgetRef ref) async {
    await ref.read(hasSeenSplashProvider.notifier).markSeen();
    onFinished();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // Material, not a bare Container — this screen is handed directly to
    // MaterialApp.home with no Scaffold/Material ancestor anywhere above
    // it. Without one, every Text here falls back to MaterialApp's own
    // `_errorTextStyle` (framework/material/app.dart) — a deliberate
    // yellow double-underline meant to flag exactly this mistake, not an
    // OS spell-checker artifact (an earlier diagnosis in this file's own
    // history, before the framework source was actually checked). `type:
    // MaterialType.transparency` so this Material adds no elevation/tint
    // of its own — `color` on the Container below still owns the visible
    // background.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: theme.colorSurfacePrimary,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacingScreenPadding,
              vertical: theme.spacingLg,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SplashLogo(theme: theme),
                        SizedBox(height: theme.spacingXl),
                        Text(
                          'Less time planning,\nmore time living.',
                          textAlign: TextAlign.center,
                          style: theme.textTitle.copyWith(
                            color: theme.colorTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: theme.spacingSm),
                        Text(
                          'A life-first planner for days that change.',
                          textAlign: TextAlign.center,
                          style: theme.textBody.copyWith(
                            color: theme.colorTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  '$trialLengthDays days free.\nNo account required.',
                  textAlign: TextAlign.center,
                  style: theme.textCaption.copyWith(
                    color: theme.colorTextTertiary,
                  ),
                ),
                SizedBox(height: theme.spacingLg),
                AppButton(
                  label: 'Start now',
                  size: AppButtonSize.lg,
                  shape: AppButtonShape.pill,
                  onPressed: () => _start(ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
