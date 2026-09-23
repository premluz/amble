import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_modal_route.dart';
import '../../shared/models/onboarding_profile.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/services/onboarding_materializer.dart';
import 'onboarding_profile_browse_screen.dart';

/// Shows the quiz's top-matched [OnboardingProfile] and offers three
/// outcomes: choose it (materializes the bundle, marks onboarding done),
/// browse every profile instead (pushes [OnboardingProfileBrowseScreen]),
/// or skip entirely (marks onboarding done with nothing materialized).
///
/// A plain result screen rather than folding this into the quiz screen
/// itself — the quiz's own job is asking questions; this one's job is
/// presenting an answer and asking for a decision, matching this
/// codebase's existing "each screen has one job" convention (see
/// CONSTITUTION.md's Zone section for the same principle applied
/// elsewhere).
class OnboardingProfileResultScreen extends ConsumerStatefulWidget {
  const OnboardingProfileResultScreen({super.key, required this.topMatch});

  final OnboardingProfile topMatch;

  @override
  ConsumerState<OnboardingProfileResultScreen> createState() =>
      _OnboardingProfileResultScreenState();
}

class _OnboardingProfileResultScreenState
    extends ConsumerState<OnboardingProfileResultScreen> {
  bool _isMaterializing = false;

  Future<void> _choose(OnboardingProfile profile) async {
    setState(() => _isMaterializing = true);
    try {
      await materializeOnboardingProfile(ref, profile);
      await ref.read(hasCompletedOnboardingProvider.notifier).markDone();
    } finally {
      if (mounted) setState(() => _isMaterializing = false);
    }
  }

  Future<void> _browseOthers() async {
    final chosen = await Navigator.of(context).push<OnboardingProfile>(
      instantRoute((context) => const OnboardingProfileBrowseScreen()),
    );
    if (chosen == null || !mounted) return;
    // The browse screen already materializes on its own "Use this
    // profile" tap (see its own doc comment) and returns the chosen
    // profile purely so this screen knows to mark onboarding done too,
    // rather than materializing twice.
    await ref.read(hasCompletedOnboardingProvider.notifier).markDone();
  }

  Future<void> _skip() async {
    await ref.read(hasCompletedOnboardingProvider.notifier).markDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final profile = widget.topMatch;

    return Scaffold(
      backgroundColor: theme.colorSurfacePrimary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacingScreenPadding,
            vertical: theme.spacingLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your best match',
                style: theme.textBody.copyWith(color: theme.colorTextSecondary),
              ),
              SizedBox(height: theme.spacingXs),
              Text(
                profile.title,
                style: theme.textHeadline.copyWith(
                  color: theme.colorTextPrimary,
                ),
              ),
              SizedBox(height: theme.spacingSm),
              Text(
                profile.description,
                style: theme.textBody.copyWith(color: theme.colorTextSecondary),
              ),
              SizedBox(height: theme.spacingLg),
              _ProfileBundleSummary(theme: theme, profile: profile),
              const Spacer(),
              AppButton(
                label: 'Use this profile',
                size: AppButtonSize.lg,
                shape: AppButtonShape.pill,
                isLoading: _isMaterializing,
                onPressed: _isMaterializing ? null : () => _choose(profile),
              ),
              SizedBox(height: theme.spacingSm),
              AppButton(
                label: 'See other profiles',
                variant: AppButtonVariant.secondary,
                shape: AppButtonShape.pill,
                onPressed: _isMaterializing ? null : _browseOthers,
              ),
              SizedBox(height: theme.spacingSm),
              AppButton(
                label: 'Skip',
                variant: AppButtonVariant.secondary,
                shape: AppButtonShape.pill,
                onPressed: _isMaterializing
                    ? null
                    : () async {
                        await _skip();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain-text summary of what "Use this profile" will actually create —
/// so the choice isn't a blind commitment. Deliberately just counts, not
/// a full preview of every title (that's what the browse screen's own
/// detail view is for).
class _ProfileBundleSummary extends StatelessWidget {
  const _ProfileBundleSummary({required this.theme, required this.profile});

  final AmbleTheme theme;
  final OnboardingProfile profile;

  @override
  Widget build(BuildContext context) {
    final lines = [
      if (profile.zones.isNotEmpty) '${profile.zones.length} zones',
      if (profile.templates.isNotEmpty)
        '${profile.templates.length} task templates',
      if (profile.tasks.isNotEmpty) '${profile.tasks.length} tasks today',
      if (profile.trackedBehaviors.isNotEmpty)
        '${profile.trackedBehaviors.length} tracked behaviors',
      if (profile.notes.isNotEmpty) '${profile.notes.length} inbox notes',
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorSurfaceSecondary,
        borderRadius: BorderRadius.circular(theme.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacingXs),
              child: Text(
                line,
                style: theme.textBody.copyWith(color: theme.colorTextPrimary),
              ),
            ),
        ],
      ),
    );
  }
}
