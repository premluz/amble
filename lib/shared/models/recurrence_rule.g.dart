// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurrence_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurrenceRuleAdapter extends TypeAdapter<RecurrenceRule> {
  @override
  final typeId = 5;

  @override
  RecurrenceRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurrenceRule(
      frequency: fields[0] as RecurrenceFrequency,
      interval: fields[1] == null ? 1 : (fields[1] as num).toInt(),
      daysOfWeek: (fields[2] as List?)?.cast<int>(),
      endDate: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, RecurrenceRule obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.frequency)
      ..writeByte(1)
      ..write(obj.interval)
      ..writeByte(2)
      ..write(obj.daysOfWeek)
      ..writeByte(3)
      ..write(obj.endDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurrenceRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
