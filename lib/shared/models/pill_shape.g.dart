// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pill_shape.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PillShapeAdapter extends TypeAdapter<PillShape> {
  @override
  final typeId = 14;

  @override
  PillShape read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PillShape.small;
      case 1:
        return PillShape.rounded;
      case 2:
        return PillShape.full;
      default:
        return PillShape.small;
    }
  }

  @override
  void write(BinaryWriter writer, PillShape obj) {
    switch (obj) {
      case PillShape.small:
        writer.writeByte(0);
      case PillShape.rounded:
        writer.writeByte(1);
      case PillShape.full:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PillShapeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
