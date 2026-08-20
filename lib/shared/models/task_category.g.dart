// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskCategoryAdapter extends TypeAdapter<TaskCategory> {
  @override
  final typeId = 2;

  @override
  TaskCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskCategory.health;
      case 1:
        return TaskCategory.work;
      case 2:
        return TaskCategory.personal;
      case 3:
        return TaskCategory.admin;
      default:
        return TaskCategory.health;
    }
  }

  @override
  void write(BinaryWriter writer, TaskCategory obj) {
    switch (obj) {
      case TaskCategory.health:
        writer.writeByte(0);
      case TaskCategory.work:
        writer.writeByte(1);
      case TaskCategory.personal:
        writer.writeByte(2);
      case TaskCategory.admin:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
