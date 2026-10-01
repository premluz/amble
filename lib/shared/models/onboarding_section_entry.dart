/// An Inbox section (a Things group such as "Work" or "Someday") and the
/// Things captured into it when a profile is chosen.
class OnboardingSectionEntry {
  const OnboardingSectionEntry({required this.name, required this.things});

  factory OnboardingSectionEntry.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('OnboardingSectionEntry: missing "name"');
    }
    return OnboardingSectionEntry(
      name: name,
      things: (json['things'] as List? ?? const [])
          .map((thing) => thing as String)
          .toList(),
    );
  }

  final String name;
  final List<String> things;
}
