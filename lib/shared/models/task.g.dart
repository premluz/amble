// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String,
      title: fields[1] as String,
      notes: fields[2] as String?,
      scheduledAt: fields[3] as DateTime?,
      durationMinutes: (fields[4] as num?)?.toInt(),
      originalScheduledAt: fields[5] as DateTime?,
      status: fields[6] == null ? TaskStatus.pending : fields[6] as TaskStatus,
      completedAt: fields[7] as DateTime?,
      category: fields[8] as TaskCategory,
      schemaVersion: fields[9] == null ? 1 : (fields[9] as num).toInt(),
      behaviorId: fields[10] as String?,
      actualAmount: fields[11] as num?,
      recurrenceId: fields[12] as String?,
      recurrenceRule: fields[13] as RecurrenceRule?,
      notificationsEnabled: fields[14] == null ? true : fields[14] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.notes)
      ..writeByte(3)
      ..write(obj.scheduledAt)
      ..writeByte(4)
      ..write(obj.durationMinutes)
      ..writeByte(5)
      ..write(obj.originalScheduledAt)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.completedAt)
      ..writeByte(8)
      ..write(obj.category)
      ..writeByte(9)
      ..write(obj.schemaVersion)
      ..writeByte(10)
      ..write(obj.behaviorId)
      ..writeByte(11)
      ..write(obj.actualAmount)
      ..writeByte(12)
      ..write(obj.recurrenceId)
      ..writeByte(13)
      ..write(obj.recurrenceRule)
      ..writeByte(14)
      ..write(obj.notificationsEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
