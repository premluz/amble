import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../tokens/component_tokens.dart';

/// On macOS the window has no separate title bar strip: the app paints to
/// the top edge, under the window buttons (`MainFlutterWindow.swift`). This
/// reports the title bar's height as a top safe area, as a phone's status
/// bar is, so `SafeArea` and `MediaQuery.paddingOf` keep content below the
/// buttons while backgrounds still fill the space. Elsewhere it does
/// nothing.
class AppWindowInsets extends StatelessWidget {
  const AppWindowInsets({super.key, required this.child});

  final Widget child;

  static bool get _macTitleBar =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (!_macTitleBar) return child;
    final media = MediaQuery.of(context);
    const top = ShellLayoutTokens.macTitleBarHeight;
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          top: media.padding.top > top ? media.padding.top : top,
        ),
        viewPadding: media.viewPadding.copyWith(
          top: media.viewPadding.top > top ? media.viewPadding.top : top,
        ),
      ),
      child: child,
    );
  }
}
