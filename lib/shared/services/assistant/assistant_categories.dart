import '../../models/category.dart';
import 'assistant_backend.dart';
import 'assistant_tool.dart';

/// The id of the category the assistant named (case-insensitive), or
/// General when it named none. An unknown or ambiguous name is an error
/// that lists the real choices.
String resolveCategoryId(AssistantBackend backend, String? name) {
  if (name == null) return BuiltInCategoryIds.general;
  final all = backend.categories();
  final matches = [
    for (final c in all)
      if (c.name.trim().toLowerCase() == name.toLowerCase()) c,
  ];
  if (matches.length == 1) return matches.single.id;
  final options = [for (final c in all) c.name].join(', ');
  throw AssistantToolError(
    matches.isEmpty
        ? 'No category is called "$name". Choose one of: $options.'
        : 'More than one category is called "$name". Choose one of: $options.',
  );
}
