// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskTemplateAdapter extends TypeAdapter<TaskTemplate> {
  @override
  final typeId = 12;

  @override
  TaskTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskTemplate(
      id: fields[0] as String,
      title: fields[1] as String,
      categoryId: fields[2] as String,
      durationMinutes: (fields[3] as num?)?.toInt(),
      notes: fields[4] as String?,
      behaviorId: fields[5] as String?,
      schemaVersion: fields[6] == null ? 1 : (fields[6] as num).toInt(),
      isImportant: fields[7] == null ? false : fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TaskTemplate obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.categoryId)
      ..writeByte(3)
      ..write(obj.durationMinutes)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.behaviorId)
      ..writeByte(6)
      ..write(obj.schemaVersion)
      ..writeByte(7)
      ..write(obj.isImportant);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
