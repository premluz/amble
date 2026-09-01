import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_field_shell.dart';

/// A single- or multi-line text input wearing the standard field chrome
/// (see [AppFieldShell]) — the app's only entry point for free-text entry.
/// Screens must not reach for `TextField`/`CupertinoTextField` directly,
/// per docs/CONSTITUTION.md design principle 4.
///
/// Owns exactly one piece of state — whether it currently has focus — and
/// derives everything else from the [controller] it is given, so callers
/// keep owning their own text without this widget duplicating it.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.onFocusChanged,
  });

  final TextEditingController controller;

  /// Inline label — floats up on focus or once text is entered. There is
  /// no separate `hint`: the resting label *is* the placeholder, which is
  /// what keeps a column of fields visually quiet.
  final String label;

  /// 1 for a single-line field (Name); higher for a notes-style box.
  final int maxLines;

  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Fired whenever this field gains or loses focus — e.g. a caller that
  /// wants to collapse itself back to a summary/link once the field is
  /// blurred (see the create flow's "Add description" reveal).
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus == _isFocused) return;
    setState(() => _isFocused = _focusNode.hasFocus);
    widget.onFocusChanged?.call(_focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // Rebuilds on every keystroke so the label knows whether the field is
    // empty. Listening to the controller (rather than tracking the text in
    // local state) keeps the caller's controller the single source of
    // truth — including when the caller sets text programmatically.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final hasValue = widget.controller.text.isNotEmpty;
        return AppFieldShell(
          label: widget.label,
          isFocused: _isFocused,
          isFloating: _isFocused || hasValue,
          // Tapping anywhere in the fill focuses the input — without this,
          // the strip of padding beside the text is dead space.
          onTap: _focusNode.requestFocus,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            maxLines: widget.maxLines,
            autofocus: widget.autofocus,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            style: theme.textBody.copyWith(color: theme.colorTextPrimary),
            cursorColor: theme.colorTextPrimary,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              // No hintText: AppFieldShell's resting label is the
              // placeholder, and a hint would double it up.
            ),
          ),
        );
      },
    );
  }
}
