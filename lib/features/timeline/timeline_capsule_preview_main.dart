// SCAFFOLDING entry point — launches TimelineCapsulePreview standalone for
// visual review. Not part of the real app; run with:
//   flutter run -t lib/features/timeline/timeline_capsule_preview_main.dart
import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import 'timeline_capsule_preview.dart';

void main() {
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: const Scaffold(body: SafeArea(child: TimelineCapsulePreview())),
    );
  }
}
