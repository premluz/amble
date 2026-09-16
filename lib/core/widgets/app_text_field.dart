import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_field_shell.dart';

/// How an [AppTextField] presents itself.
enum AppTextFieldVariant {
  /// The standard filled field chrome (see [AppFieldShell]) — a rounded
  /// fill that deepens on focus, with an inline floating label.
  filled,

  /// Bare text with no fill, no border and no floating label: the value
  /// simply reads as text, sized like a heading, and is editable in
  /// place. Requested directly for entity NAMES — "we need one that is
  /// just text and, on top, can be edited... also, smaller sizes" — and
  /// then confirmed as the style for "the input of any entity: task
  /// name, note, behavior, zone."
  ///
  /// The [AppTextField.label] becomes ordinary placeholder text here,
  /// shown only while the field is empty, rather than a label that
  /// floats out of the way.
  bare,
}

/// A single- or multi-line text input — the app's only entry point for
/// free-text entry. Screens must not reach for
/// `TextField`/`CupertinoTextField` directly, per docs/CONSTITUTION.md
/// design principle 4.
///
/// Wears the standard field chrome ([AppFieldShell]) by default, or bare
/// editable text via [AppTextFieldVariant.bare] — see that value's own
/// doc comment.
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
    this.selectAllOnFocus = false,
    this.variant = AppTextFieldVariant.filled,
  });

  /// See [AppTextFieldVariant]. Defaults to the filled chrome every
  /// existing caller already renders.
  final AppTextFieldVariant variant;

  final TextEditingController controller;

  /// Inline label — floats up on focus or once text is entered. There is
  /// no separate `hint`: the resting label *is* the placeholder, which is
  /// what keeps a column of fields visually quiet.
  ///
  /// Under [AppTextFieldVariant.bare] this is plain placeholder text
  /// instead, shown only while the field is empty.
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

  /// True selects the entire current value the instant this field gains
  /// focus — for a field pre-filled with a placeholder-as-real-value
  /// default (e.g. quick-create's "New task"), so the first keystroke
  /// replaces the whole thing in one motion instead of the user having to
  /// clear it manually first. Default false: every other caller's typed
  /// text is left exactly where the user last put it.
  final bool selectAllOnFocus;

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
    if (_focusNode.hasFocus && widget.selectAllOnFocus) {
      widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.length,
      );
    }
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
        if (widget.variant == AppTextFieldVariant.bare) {
          return TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            maxLines: widget.maxLines,
            autofocus: widget.autofocus,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            // `textTitle`, the one size every page and sheet title in the
            // app already uses — this variant IS the title of whatever is
            // being created, so it reads as that title rather than as a
            // form control.
            style: theme.textTitle.copyWith(color: theme.colorTextPrimary),
            cursorColor: theme.colorTextPrimary,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              // A real hint here, unlike the filled variant: with no
              // shell there is no floating label to double it up.
              hintText: widget.label,
              hintStyle: theme.textTitle.copyWith(
                color: theme.colorTextSecondary,
              ),
            ),
          );
        }
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
