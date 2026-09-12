// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracked_behavior_view_mode.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackedBehaviorViewModeAdapter
    extends TypeAdapter<TrackedBehaviorViewMode> {
  @override
  final typeId = 13;

  @override
  TrackedBehaviorViewMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TrackedBehaviorViewMode.weekly;
      case 1:
        return TrackedBehaviorViewMode.monthly;
      case 2:
        return TrackedBehaviorViewMode.sixMonthly;
      default:
        return TrackedBehaviorViewMode.weekly;
    }
  }

  @override
  void write(BinaryWriter writer, TrackedBehaviorViewMode obj) {
    switch (obj) {
      case TrackedBehaviorViewMode.weekly:
        writer.writeByte(0);
      case TrackedBehaviorViewMode.monthly:
        writer.writeByte(1);
      case TrackedBehaviorViewMode.sixMonthly:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackedBehaviorViewModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
