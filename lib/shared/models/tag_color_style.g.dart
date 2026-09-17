// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_color_style.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TagColorStyleAdapter extends TypeAdapter<TagColorStyle> {
  @override
  final typeId = 16;

  @override
  TagColorStyle read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TagColorStyle.pill;
      case 1:
        return TagColorStyle.iconOnly;
      default:
        return TagColorStyle.pill;
    }
  }

  @override
  void write(BinaryWriter writer, TagColorStyle obj) {
    switch (obj) {
      case TagColorStyle.pill:
        writer.writeByte(0);
      case TagColorStyle.iconOnly:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagColorStyleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
