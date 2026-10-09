import 'behavior_target_type.dart';
import 'field_override.dart';
import 'local_date.dart';

/// A tracked behavior's target as it applied from [effectiveFrom] onward.
///
/// Results are judged against the target that applied on the occurrence's
/// ORIGINAL date — not when the outcome was recorded — so changing a target
/// from 60 to 30 never rewrites earlier results, including omitted ones that
/// have no stored data (contract §5, scenario S22).
class BehaviorTargetRevision {
  const BehaviorTargetRevision({
    required this.behaviorId,
    required this.effectiveFrom,
    required this.targetType,
    this.targetAmount,
    this.minimumAmount,
    this.unitLabel,
  });

  final String behaviorId;
  final LocalDate effectiveFrom;
  final BehaviorTargetType targetType;
  final num? targetAmount;
  final num? minimumAmount;
  final String? unitLabel;

  String get storageKey => '$behaviorId|${effectiveFrom.toIso()}';

  Map<String, dynamic> toJson() => {
    'behaviorId': behaviorId,
    'effectiveFrom': effectiveFrom.toIso(),
    'targetType': targetType.name,
    'targetAmount': targetAmount,
    'minimumAmount': minimumAmount,
    'unitLabel': unitLabel,
  };

  factory BehaviorTargetRevision.fromJson(Map<String, dynamic> json) {
    final unitLabel = json['unitLabel'];
    return BehaviorTargetRevision(
      behaviorId: decodeString(json['behaviorId']),
      effectiveFrom: LocalDate.parse(decodeString(json['effectiveFrom'])),
      targetType: _decodeTargetType(json['targetType']),
      targetAmount: _optionalNum(json['targetAmount']),
      minimumAmount: _optionalNum(json['minimumAmount']),
      unitLabel: unitLabel == null ? null : decodeString(unitLabel),
    );
  }
}

/// The target that applied to [behaviorId] on [date]; null if none had been
/// recorded yet.
BehaviorTargetRevision? behaviorTargetOn(
  Iterable<BehaviorTargetRevision> revisions, {
  required String behaviorId,
  required LocalDate date,
}) {
  BehaviorTargetRevision? applicable;
  for (final revision in revisions) {
    if (revision.behaviorId != behaviorId) continue;
    if (revision.effectiveFrom.isAfter(date)) continue;
    if (applicable == null ||
        revision.effectiveFrom.isAfter(applicable.effectiveFrom)) {
      applicable = revision;
    }
  }
  return applicable;
}

BehaviorTargetType _decodeTargetType(Object? raw) {
  for (final value in BehaviorTargetType.values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Unknown behavior target type "$raw"');
}

num? _optionalNum(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw;
  throw FormatException('Expected a number, got $raw');
}
