import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_modal_route.dart';
import '../../shared/providers/onboarding_profile_catalog.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/services/onboarding_quiz.dart';
import 'onboarding_profile_result_screen.dart';

/// The onboarding Profile quiz — a short, skippable question flow shown
/// once, AFTER the existing splash/carousel finishes (see `main.dart`'s
/// `home:` wiring) and BEFORE the real app. A separate step from the
/// carousel, not folded into it — confirmed directly: "we need to keep
/// carousel and separately onboarding slides."
///
/// Answers are scored against the bundled Profile catalog
/// (`onboarding_profile_catalog.dart`) via [scoreOnboardingProfiles];
/// finishing the quiz pushes [OnboardingProfileResultScreen] with the top
/// match. Skipping (the header's own close button, always present) marks
/// onboarding done with nothing materialized — per docs/SCOPE.md's
/// "onboarding is skippable, never blocking" rule, mirrored exactly by
/// [HasCompletedOnboarding] covering both a finished quiz and an explicit
/// skip with the same "done" flag.
class OnboardingQuizScreen extends ConsumerStatefulWidget {
  const OnboardingQuizScreen({super.key});

  @override
  ConsumerState<OnboardingQuizScreen> createState() =>
      _OnboardingQuizScreenState();
}

class _OnboardingQuizScreenState extends ConsumerState<OnboardingQuizScreen> {
  int _questionIndex = 0;
  final _answeredTags = <String>{};

  bool get _isLastQuestion =>
      _questionIndex == onboardingQuizQuestions.length - 1;

  Future<void> _skip() async {
    await ref.read(hasCompletedOnboardingProvider.notifier).markDone();
  }

  void _answer(OnboardingQuizOption option) {
    setState(() {
      _answeredTags.addAll(option.tags);
      if (_isLastQuestion) {
        _showResult();
      } else {
        _questionIndex++;
      }
    });
  }

  Future<void> _showResult() async {
    final catalog = await ref.read(onboardingProfileCatalogProvider.future);
    if (!mounted) return;
    final scored = scoreOnboardingProfiles(catalog, _answeredTags);
    await Navigator.of(context).push<void>(
      instantRoute(
        (context) => OnboardingProfileResultScreen(topMatch: scored.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final question = onboardingQuizQuestions[_questionIndex];

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_questionIndex + 1} of '
                    '${onboardingQuizQuestions.length}',
                    style: theme.textBody.copyWith(
                      color: theme.colorTextSecondary,
                    ),
                  ),
                  AppButton(
                    label: 'Skip',
                    variant: AppButtonVariant.secondary,
                    shape: AppButtonShape.pill,
                    size: AppButtonSize.md,
                    onPressed: () async {
                      await _skip();
                    },
                  ),
                ],
              ),
              SizedBox(height: theme.spacingXl),
              Text(
                question.prompt,
                style: theme.textTitle.copyWith(color: theme.colorTextPrimary),
              ),
              SizedBox(height: theme.spacingLg),
              for (final option in question.options) ...[
                _AnswerCard(
                  theme: theme,
                  label: option.label,
                  onTap: () => _answer(option),
                ),
                SizedBox(height: theme.spacingSm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  final AmbleTheme theme;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(theme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusXl),
        ),
        child: Text(
          label,
          style: theme.textBody.copyWith(color: theme.colorTextPrimary),
        ),
      ),
    );
  }
}
