import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root modals retain the launching route's overrides and local theme.
WidgetBuilder rootModalBuilder(BuildContext context, WidgetBuilder builder) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final scope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>();
  final container = scope == null ? null : ProviderScope.containerOf(context, listen: false);
  return (modalContext) {
    final content = themes.wrap(Builder(builder: builder));
    return container == null
        ? content
        : UncontrolledProviderScope(container: container, child: content);
  };
}
