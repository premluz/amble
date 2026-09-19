import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../shared/models/onboarding_profile.dart';
import '../../shared/providers/onboarding_profile_catalog.dart';
import '../../shared/services/onboarding_materializer.dart';

/// Opens the plain list of every bundled [OnboardingProfile] — the
/// "browse and choose a whole starting point" surface, reused in two
/// places rather than built twice (per the work order's own point 5):
/// - Onboarding's result screen ("See other profiles"), where choosing
///   one here materializes it and pops back with the chosen profile so
///   the caller can mark onboarding done.
/// - Settings, at any later time, for a user who skipped onboarding or
///   wants a second bundle — this screen materializes on tap either way,
///   the caller-side "what happens after" is the only thing that differs.
///
/// A plain list, not a second quiz — the work order's own instruction was
/// "your call which is simpler," and a list needs no scoring mechanism at
/// all for a user who already knows they just want to look at every
/// option themselves.
Future<OnboardingProfile?> showOnboardingProfileBrowseScreen(
  BuildContext context,
) {
  return Navigator.of(context).push<OnboardingProfile>(
    MaterialPageRoute(
      builder: (context) => const OnboardingProfileBrowseScreen(),
    ),
  );
}

class OnboardingProfileBrowseScreen extends ConsumerStatefulWidget {
  const OnboardingProfileBrowseScreen({super.key});

  @override
  ConsumerState<OnboardingProfileBrowseScreen> createState() =>
      _OnboardingProfileBrowseScreenState();
}

class _OnboardingProfileBrowseScreenState
    extends ConsumerState<OnboardingProfileBrowseScreen> {
  String? _materializingId;

  Future<void> _choose(OnboardingProfile profile) async {
    setState(() => _materializingId = profile.id);
    try {
      await materializeOnboardingProfile(ref, profile);
      if (mounted) Navigator.of(context).pop(profile);
    } finally {
      if (mounted) setState(() => _materializingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final catalogAsync = ref.watch(onboardingProfileCatalogProvider);

    return Scaffold(
      backgroundColor: theme.colorSurfacePrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(theme.spacingScreenPadding),
              child: Row(
                children: [
                  AppButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                    shape: AppButtonShape.circle,
                  ),
                  SizedBox(width: theme.spacingMd),
                  Expanded(child: Text('All profiles', style: theme.textTitle)),
                ],
              ),
            ),
            Expanded(
              child: catalogAsync.when(
                data: (profiles) => ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacingScreenPadding,
                  ),
                  itemCount: profiles.length,
                  separatorBuilder: (context, _) =>
                      SizedBox(height: theme.spacingSm),
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    return _ProfileCard(
                      theme: theme,
                      profile: profile,
                      isLoading: _materializingId == profile.id,
                      onTap: () => _choose(profile),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Could not load profiles.',
                    style: theme.textBody.copyWith(
                      color: theme.colorTextSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.theme,
    required this.profile,
    required this.isLoading,
    required this.onTap,
  });

  final AmbleTheme theme;
  final OnboardingProfile profile;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(theme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusXl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.title,
                    style: theme.textBody.copyWith(
                      color: theme.colorTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: theme.spacingXs),
                  Text(
                    profile.description,
                    style: theme.textBody.copyWith(
                      color: theme.colorTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                width: theme.spacingLg,
                height: theme.spacingLg,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorTextSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
