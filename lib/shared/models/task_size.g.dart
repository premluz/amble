// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_size.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskSizeAdapter extends TypeAdapter<TaskSize> {
  @override
  final typeId = 11;

  @override
  TaskSize read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskSize.sm;
      case 1:
        return TaskSize.md;
      case 2:
        return TaskSize.lg;
      default:
        return TaskSize.sm;
    }
  }

  @override
  void write(BinaryWriter writer, TaskSize obj) {
    switch (obj) {
      case TaskSize.sm:
        writer.writeByte(0);
      case TaskSize.md:
        writer.writeByte(1);
      case TaskSize.lg:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskSizeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskFontSizeAdapter extends TypeAdapter<TaskFontSize> {
  @override
  final typeId = 15;

  @override
  TaskFontSize read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskFontSize.sm;
      case 1:
        return TaskFontSize.md;
      case 2:
        return TaskFontSize.lg;
      default:
        return TaskFontSize.sm;
    }
  }

  @override
  void write(BinaryWriter writer, TaskFontSize obj) {
    switch (obj) {
      case TaskFontSize.sm:
        writer.writeByte(0);
      case TaskFontSize.md:
        writer.writeByte(1);
      case TaskFontSize.lg:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskFontSizeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
