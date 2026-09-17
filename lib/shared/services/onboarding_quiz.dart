import '../models/onboarding_profile.dart';

/// One quiz question — a single-select prompt whose chosen option
/// contributes a fixed set of scoring tags toward whichever
/// [OnboardingProfile.quizTags] it overlaps.
///
/// Kept deliberately simple per the work order: a small tag-overlap
/// function over plain Dart data, no external dependency, no ML. Question
/// wording/count is a judgment call, flagged here rather than assumed
/// final — see docs/DECISIONS.md's onboarding entry.
class OnboardingQuizQuestion {
  const OnboardingQuizQuestion({required this.prompt, required this.options});

  final String prompt;
  final List<OnboardingQuizOption> options;
}

class OnboardingQuizOption {
  const OnboardingQuizOption({required this.label, required this.tags});

  final String label;

  /// The tags this answer contributes toward scoring — matched against
  /// each [OnboardingProfile.quizTags] by plain set overlap (see
  /// [scoreOnboardingProfiles]).
  final Set<String> tags;
}

/// **3 questions — schedule shape, what's felt neglected, and energy
/// pattern.** Chosen to distinguish the 4 shipped example profiles
/// (Student/Remote Worker/New Parent/Shift Worker) along the axes that
/// actually separate them: how fixed the day's structure is, what kind of
/// support is missing, and whether tiredness/overload is a factor — not
/// an attempt at a general psychographic quiz. Flagged as a judgment call,
/// not assumed final.
const onboardingQuizQuestions = [
  OnboardingQuizQuestion(
    prompt: 'What does your week look like?',
    options: [
      OnboardingQuizOption(
        label: 'A fixed daily schedule (classes, a 9-to-5)',
        tags: {'fixed_schedule'},
      ),
      OnboardingQuizOption(
        label: 'It changes a lot — shifts, or someone else\'s schedule',
        tags: {'unpredictable_schedule', 'irregular_hours'},
      ),
      OnboardingQuizOption(
        label: 'Mostly caregiving — a baby or young kids',
        tags: {'unpredictable_schedule', 'caregiving', 'family'},
      ),
    ],
  ),
  OnboardingQuizQuestion(
    prompt: 'What\'s felt hardest to protect lately?',
    options: [
      OnboardingQuizOption(
        label: 'Focus time and getting real work done',
        tags: {'desk_job', 'focus', 'study'},
      ),
      OnboardingQuizOption(
        label: 'Actual rest and sleep',
        tags: {'tired', 'physical_job'},
      ),
      OnboardingQuizOption(
        label: 'Time for people I care about',
        tags: {'social', 'family'},
      ),
    ],
  ),
  OnboardingQuizQuestion(
    prompt: 'How does most of your day feel?',
    options: [
      OnboardingQuizOption(
        label: 'Busy but manageable',
        tags: {'young', 'desk_job'},
      ),
      OnboardingQuizOption(
        label: 'Stretched thin, running on empty',
        tags: {'overworked', 'tired'},
      ),
      OnboardingQuizOption(
        label: 'Unpredictable — I go where the day takes me',
        tags: {'unpredictable_schedule', 'irregular_hours'},
      ),
    ],
  ),
];

/// Scores every [profiles] entry by how many of its own [OnboardingProfile
/// .quizTags] appear among [answeredTags] — a plain tag-overlap count, per
/// the work order's explicit "keep the scoring mechanism simple" request.
/// Returns profiles sorted highest-score-first; a caller wanting "top
/// match" takes [.first], "top 2" takes [.take(2)]. Ties keep the
/// catalog's own original order — `List.sort` is NOT guaranteed stable
/// per Dart's own docs, so ties are broken explicitly by original index
/// (a decorate-sort-undecorate pass) rather than relying on sort-algorithm
/// behavior that could silently change between Dart versions. No new
/// dependency (`package:collection`'s `mergeSort` would need one) for
/// what a manual tiebreaker already solves in a few lines.
List<OnboardingProfile> scoreOnboardingProfiles(
  List<OnboardingProfile> profiles,
  Set<String> answeredTags,
) {
  final indexed = profiles.indexed.toList();
  indexed.sort((a, b) {
    final scoreA = a.$2.quizTags.intersection(answeredTags).length;
    final scoreB = b.$2.quizTags.intersection(answeredTags).length;
    final byScore = scoreB.compareTo(scoreA);
    // Tie -> original catalog order, via the preserved index.
    return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
  });
  return [for (final (_, profile) in indexed) profile];
}
