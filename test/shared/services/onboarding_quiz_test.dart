import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/onboarding_profile.dart';
import 'package:amble/shared/services/onboarding_quiz.dart';

OnboardingProfile _profile(String id, Set<String> tags) => OnboardingProfile(
  id: id,
  title: id,
  description: '',
  quizTags: tags,
  zones: const [],
  templates: const [],
  tasks: const [],
  trackedBehaviors: const [],
  notes: const [],
);

void main() {
  group('scoreOnboardingProfiles', () {
    test('the profile with the most tag overlap sorts first', () {
      final profiles = [
        _profile('low', {'a'}),
        _profile('high', {'a', 'b', 'c'}),
        _profile('mid', {'a', 'b'}),
      ];

      final scored = scoreOnboardingProfiles(profiles, {'a', 'b', 'c'});

      expect(scored.map((p) => p.id).toList(), ['high', 'mid', 'low']);
    });

    test('a profile with zero overlapping tags still appears, ranked last', () {
      final profiles = [
        _profile('matches', {'a'}),
        _profile('no_match', {'z'}),
      ];

      final scored = scoreOnboardingProfiles(profiles, {'a'});

      expect(scored.map((p) => p.id).toList(), ['matches', 'no_match']);
    });

    test('a tie keeps the catalog\'s own original order', () {
      final profiles = [
        _profile('first', {'a'}),
        _profile('second', {'a'}),
        _profile('third', {'a'}),
      ];

      final scored = scoreOnboardingProfiles(profiles, {'a'});

      expect(scored.map((p) => p.id).toList(), ['first', 'second', 'third']);
    });

    test(
      'no answers at all still returns every profile, in original order',
      () {
        final profiles = [
          _profile('a', {'x'}),
          _profile('b', {'y'}),
        ];

        final scored = scoreOnboardingProfiles(profiles, {});

        expect(scored.map((p) => p.id).toList(), ['a', 'b']);
      },
    );

    test('onboardingQuizQuestions has real questions with at least 2 options '
        'each', () {
      expect(onboardingQuizQuestions, isNotEmpty);
      for (final question in onboardingQuizQuestions) {
        expect(question.prompt, isNotEmpty);
        expect(question.options.length, greaterThanOrEqualTo(2));
        for (final option in question.options) {
          expect(option.label, isNotEmpty);
          expect(option.tags, isNotEmpty);
        }
      }
    });
  });
}
