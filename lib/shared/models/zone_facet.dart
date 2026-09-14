import 'package:uuid/uuid.dart';

/// A reusable name, never a schedule or a set of defaults.
class ZoneFacet {
  const ZoneFacet({required this.id, required this.name, this.schemaVersion = 1});
  factory ZoneFacet.create(String name) => ZoneFacet(id: const Uuid().v4(), name: name.trim());
  final String id;
  final String name;
  final int schemaVersion;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'schemaVersion': schemaVersion};
  factory ZoneFacet.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String || (json['id'] as String).isEmpty ||
        json['name'] is! String || (json['name'] as String).trim().isEmpty ||
        json['schemaVersion'] != 1) {
      throw const FormatException('Invalid zone name');
    }
    return ZoneFacet(id: json['id'] as String, name: json['name'] as String);
  }
}
