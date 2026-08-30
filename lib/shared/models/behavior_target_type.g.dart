// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'behavior_target_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BehaviorTargetTypeAdapter extends TypeAdapter<BehaviorTargetType> {
  @override
  final typeId = 4;

  @override
  BehaviorTargetType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BehaviorTargetType.duration;
      case 1:
        return BehaviorTargetType.count;
      case 2:
        return BehaviorTargetType.binary;
      default:
        return BehaviorTargetType.duration;
    }
  }

  @override
  void write(BinaryWriter writer, BehaviorTargetType obj) {
    switch (obj) {
      case BehaviorTargetType.duration:
        writer.writeByte(0);
      case BehaviorTargetType.count:
        writer.writeByte(1);
      case BehaviorTargetType.binary:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BehaviorTargetTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
