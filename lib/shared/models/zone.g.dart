// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zone.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ZoneAdapter extends TypeAdapter<Zone> {
  @override
  final typeId = 9;

  @override
  Zone read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Zone(
      id: fields[0] as String,
      title: fields[1] as String,
      startMinutes: (fields[2] as num).toInt(),
      endMinutes: (fields[3] as num).toInt(),
      schemaVersion: fields[4] == null ? 1 : (fields[4] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Zone obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.startMinutes)
      ..writeByte(3)
      ..write(obj.endMinutes)
      ..writeByte(4)
      ..write(obj.schemaVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZoneAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
