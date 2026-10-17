import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../layout_width.dart';
import '../tokens/component_tokens.dart';

/// On macOS the window has no separate title bar strip: the app paints to
/// the top edge, under the window buttons (`MainFlutterWindow.swift`). This
/// reports the title bar's height as a top safe area, as a phone's status
/// bar is, so `SafeArea` and `MediaQuery.paddingOf` keep content below the
/// buttons while backgrounds still fill the space.
///
/// On web, at phone width, a browser tab reports no status-bar/home-
/// indicator inset at all — see [ShellLayoutTokens.webMobileTopInset]'s own
/// doc comment — so this reserves stand-in top and bottom insets there
/// too. Web at [isWideLayout] width (the desktop web experience) and every
/// native platform are untouched.
class AppWindowInsets extends StatelessWidget {
  const AppWindowInsets({super.key, required this.child});

  final Widget child;

  static bool get _macTitleBar =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final inset = windowInsetFor(
      isMacTitleBar: _macTitleBar,
      isWeb: kIsWeb,
      isWideLayout: isWideLayout(context),
    );
    if (inset == EdgeInsets.zero) return child;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          top: media.padding.top > inset.top ? media.padding.top : inset.top,
          bottom: media.padding.bottom > inset.bottom
              ? media.padding.bottom
              : inset.bottom,
        ),
        viewPadding: media.viewPadding.copyWith(
          top: media.viewPadding.top > inset.top
              ? media.viewPadding.top
              : inset.top,
          bottom: media.viewPadding.bottom > inset.bottom
              ? media.viewPadding.bottom
              : inset.bottom,
        ),
      ),
      child: child,
    );
  }
}

/// The stand-in top/bottom inset [AppWindowInsets] reserves, given the
/// three platform facts that decide it — pulled out as a pure function (no
/// `BuildContext`, no `kIsWeb`/`defaultTargetPlatform` reads of its own) so
/// the decision table is unit-testable: `flutter test`'s VM always reports
/// `kIsWeb == false`, so the widget's own real web branch can never run
/// under test, but the logic that WOULD apply once it does can still be
/// checked directly by passing `isWeb: true`.
@visibleForTesting
EdgeInsets windowInsetFor({
  required bool isMacTitleBar,
  required bool isWeb,
  required bool isWideLayout,
}) {
  if (isMacTitleBar) {
    return const EdgeInsets.only(top: ShellLayoutTokens.macTitleBarHeight);
  }
  if (isWeb && !isWideLayout) {
    return const EdgeInsets.only(
      top: ShellLayoutTokens.webMobileTopInset,
      bottom: ShellLayoutTokens.webMobileBottomInset,
    );
  }
  return EdgeInsets.zero;
}
