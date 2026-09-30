import '../../shared/models/recurrence_frequency.dart';
import '../../shared/models/recurrence_rule.dart';

/// The repeat days chosen in a task sheet as a rule: all seven is daily,
/// otherwise weekly on those days (Monday if none).
RecurrenceRule recurrenceRuleFromDays(Set<int> days) {
  final picked = days.isEmpty ? {DateTime.monday} : days;
  if (picked.length == 7) {
    return RecurrenceRule(frequency: RecurrenceFrequency.daily);
  }
  return RecurrenceRule(
    frequency: RecurrenceFrequency.weekly,
    daysOfWeek: picked.toList()..sort(),
  );
}

/// The inverse: which day chips an existing rule selects.
Set<int> daysFromRecurrenceRule(RecurrenceRule rule) {
  if (rule.frequency == RecurrenceFrequency.daily) {
    return {for (var day = DateTime.monday; day <= DateTime.sunday; day++) day};
  }
  return rule.daysOfWeek!.toSet();
}
