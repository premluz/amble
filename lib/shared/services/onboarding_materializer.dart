import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feature_flags.dart';
import '../models/behavior_target_type.dart';
import '../models/category.dart';
import '../models/onboarding_profile.dart';
import '../providers/category_providers.dart';
import '../providers/task_providers.dart';
import '../providers/task_template_providers.dart';
import '../providers/tracked_behavior_providers.dart';
import '../providers/zone_providers.dart';

/// Materializes an [OnboardingProfile]'s bundle into real, independent Hive
/// rows — called exactly once, at the moment a user chooses that profile
/// (quiz result or the browse-all-profiles screen), never on app launch.
///
/// Mirrors the reasoning already established for individual presets: the
/// catalog itself (`onboarding_profile_catalog.dart`) is read-only content
/// shipped in the app bundle, never persisted as-is. Every entry in
/// [profile] goes through the SAME create path every other route into that
/// entity type already uses — `ZoneList.paintWeeklyZones`,
/// `TaskTemplateList.createTemplate`, `TaskList.createTask`/`captureTask`,
/// `TrackedBehaviorList.createBehavior` — so a materialized row is
/// indistinguishable from one the user created by hand: same validation,
/// same notification scheduling, same recurrence handling.
///
/// [trackedBehaviorEnabled] defaults to `FeatureFlags.trackedBehaviorEnabled`
/// — overridable only for tests, mirroring how every other call site in
/// this codebase gates that feature. When off, [profile.trackedBehaviors]
/// is skipped entirely rather than silently creating rows behind a flag a
/// user can't yet see any UI for.
///
/// Takes [WidgetRef] — checked directly rather than assumed: unlike some
/// other Riverpod APIs, [WidgetRef] does NOT extend the plain [Ref] this
/// function's own `ref.read(...)` calls would otherwise be satisfied by,
/// so a real screen's `ConsumerState.ref` is the only thing that type-checks
/// here. A widget test drives this the same way any real screen does.
Future<void> materializeOnboardingProfile(
  WidgetRef ref,
  OnboardingProfile profile, {
  DateTime? firstDay,
  bool trackedBehaviorEnabled = FeatureFlags.trackedBehaviorEnabled,
}) async {
  final day = firstDay ?? DateTime.now();
  final today = DateTime(day.year, day.month, day.day);

  // Categories are resolved by NAME once, up front — every entry in this
  // profile references one of the 5 built-in categories by name (see
  // OnboardingTemplateEntry's own doc comment on why: built-in ids are
  // stable per install but a raw UUID string in the bundled asset would
  // be fragile to depend on, and a name self-documents intent).
  final categoriesByName = <String, Category>{
    for (final category in ref.read(categoryListProvider))
      _builtInNameFor(category.id): category,
  }..removeWhere((name, _) => name.isEmpty);
  String categoryIdFor(String name) {
    final category = categoriesByName[name];
    if (category == null) {
      throw StateError(
        'Onboarding profile "${profile.id}" references unknown built-in '
        'category "$name" — expected one of general/health/work/personal/'
        'admin.',
      );
    }
    return category.id;
  }

  for (final zone in profile.zones) {
    await ref
        .read(zoneListProvider.notifier)
        .paintWeeklyZones(
          title: zone.title,
          weekdays: zone.weekdays,
          startMinutes: zone.startMinutes,
          endMinutes: zone.endMinutes,
        );
  }

  for (final template in profile.templates) {
    await ref
        .read(taskTemplateListProvider.notifier)
        .createTemplate(
          title: template.title,
          categoryId: categoryIdFor(template.categoryName),
          durationMinutes: template.durationMinutes,
          notes: template.notes,
        );
  }

  for (final task in profile.tasks) {
    await ref
        .read(taskListProvider.notifier)
        .createTask(
          title: task.title,
          categoryId: categoryIdFor(task.categoryName),
          scheduledAt: today.add(Duration(minutes: task.startMinutes)),
          durationMinutes: task.durationMinutes,
        );
  }

  if (trackedBehaviorEnabled) {
    for (final behavior in profile.trackedBehaviors) {
      await ref
          .read(trackedBehaviorListProvider.notifier)
          .createBehavior(
            title: behavior.title,
            targetType: BehaviorTargetType.values.byName(behavior.targetType),
            targetAmount: behavior.targetAmount,
            timesPerWeek: behavior.timesPerWeek,
            customUnitLabel: behavior.customUnitLabel,
          );
    }
  }

  for (final note in profile.notes) {
    await ref.read(taskListProvider.notifier).captureTask(note);
  }
}

/// Reverses [BuiltInCategoryIds]'s fixed-id map back to the plain name the
/// catalog's JSON entries use — the exact inverse of
/// `onboarding_materializer.dart`'s own `categoryIdFor` lookup direction.
/// Empty string for a genuinely custom (non-built-in) category, which this
/// profile catalog never references (see [OnboardingTemplateEntry]'s own
/// doc comment) — filtered out by the caller.
String _builtInNameFor(String categoryId) => switch (categoryId) {
  BuiltInCategoryIds.general => 'general',
  BuiltInCategoryIds.health => 'health',
  BuiltInCategoryIds.work => 'work',
  BuiltInCategoryIds.personal => 'personal',
  BuiltInCategoryIds.admin => 'admin',
  _ => '',
};
