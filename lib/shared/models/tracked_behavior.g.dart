// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracked_behavior.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackedBehaviorAdapter extends TypeAdapter<TrackedBehavior> {
  @override
  final typeId = 3;

  @override
  TrackedBehavior read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrackedBehavior(
      id: fields[0] as String,
      title: fields[1] as String,
      targetType: fields[2] as BehaviorTargetType,
      targetAmount: fields[3] as num?,
      minimumAmount: fields[4] as num?,
      timesPerWeek: (fields[5] as num).toInt(),
      schemaVersion: fields[6] == null ? 1 : (fields[6] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, TrackedBehavior obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.targetType)
      ..writeByte(3)
      ..write(obj.targetAmount)
      ..writeByte(4)
      ..write(obj.minimumAmount)
      ..writeByte(5)
      ..write(obj.timesPerWeek)
      ..writeByte(6)
      ..write(obj.schemaVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackedBehaviorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
