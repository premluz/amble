// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'synced_calendar_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncedCalendarEventAdapter extends TypeAdapter<SyncedCalendarEvent> {
  @override
  final typeId = 10;

  @override
  SyncedCalendarEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncedCalendarEvent(
      taskId: fields[0] as String,
      deviceEventId: fields[1] as String,
      deviceCalendarId: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SyncedCalendarEvent obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.taskId)
      ..writeByte(1)
      ..write(obj.deviceEventId)
      ..writeByte(2)
      ..write(obj.deviceCalendarId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncedCalendarEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
