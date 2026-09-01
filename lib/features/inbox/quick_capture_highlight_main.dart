// SCAFFOLDING entry point — renders the SAME live-highlighting mechanism
// quick_capture_sheet.dart uses (a TextEditingController overriding
// buildTextSpan around parseQuickCapture), with sample text PRE-FILLED
// into the controller — no tap-injection tool is available in this
// environment to simulate real typing, so this is how the highlighted
// spans get demonstrated for a screenshot. The controller subclass here
// is a copy of the private one in quick_capture_sheet.dart (that one is
// intentionally private — this scaffold isn't meant to become a second
// production entry point), not a second implementation of the parsing
// logic itself, which stays in the one shared `parseQuickCapture`. Not
// part of the real app. Run with:
//   flutter run -t lib/features/inbox/quick_capture_highlight_main.dart
import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/services/quick_capture_parser.dart';

void main() {
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: const _HighlightPreviewScreen(),
    );
  }
}

class _HighlightPreviewScreen extends StatefulWidget {
  const _HighlightPreviewScreen();

  @override
  State<_HighlightPreviewScreen> createState() =>
      _HighlightPreviewScreenState();
}

class _HighlightPreviewScreenState extends State<_HighlightPreviewScreen> {
  late final _PreviewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _PreviewController(theme: () => AmbleTheme.light)
      ..text = 'Call client tomorrow at 10:30 for 30 mins every monday';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AmbleTheme.light;

    return Scaffold(
      backgroundColor: theme.colorSurfacePrimary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(theme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add to Inbox', style: theme.textTitle),
              SizedBox(height: theme.spacingMd),
              TextField(
                controller: _controller,
                style: theme.textBody,
                maxLines: null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.colorSurfaceSecondary,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: theme.spacingMd,
                    vertical: theme.spacingMd,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A byte-for-byte copy of quick_capture_sheet.dart's private
/// `_QuickCaptureTextEditingController` — see this file's own top comment
/// for why a copy, not an import.
class _PreviewController extends TextEditingController {
  _PreviewController({required this.theme});

  final AmbleTheme Function() theme;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final input = text;
    if (input.isEmpty) {
      return TextSpan(style: style, text: input);
    }

    final result = parseQuickCapture(
      input,
      now: DateTime.now(),
      categories: const [],
    );
    if (result.tokens.isEmpty) {
      return TextSpan(style: style, text: input);
    }

    final t = theme();
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final token in result.tokens) {
      if (token.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, token.start)));
      }
      spans.add(
        TextSpan(
          text: input.substring(token.start, token.end),
          style: TextStyle(
            color: _highlightColor(t, token.kind),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = token.end;
    }
    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }

    return TextSpan(style: style, children: spans);
  }

  Color _highlightColor(AmbleTheme t, QuickCaptureTokenKind kind) =>
      switch (kind) {
        QuickCaptureTokenKind.dateTime => t.colorAccent,
        QuickCaptureTokenKind.duration =>
          t.categoryIconColors[TaskCategoryToken.work]!,
        QuickCaptureTokenKind.recurrence => t.colorTaskAlert,
        QuickCaptureTokenKind.category =>
          t.categoryIconColors[TaskCategoryToken.personal]!,
      };
}
