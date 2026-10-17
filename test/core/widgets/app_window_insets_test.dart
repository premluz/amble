import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/widgets/app_window_insets.dart';

/// On macOS the app paints under its transparent title bar, so the bar's
/// height is reported as a top safe area; elsewhere nothing changes. On
/// web at phone width, a browser has no status-bar/home-indicator inset
/// of its own to report, so stand-in top AND bottom insets are reserved —
/// requested directly against the web preview: "add top bottom padding,
/// because I think OS UI is not accounted for and looks too close to
/// edge... ONLY in web render, do not change for iOS or Android or
/// desktop, only web mobile."
///
/// `flutter test`'s VM always reports `kIsWeb == false`, so
/// [AppWindowInsets] itself can never actually take its web branch under
/// test — `windowInsetFor` is the pure decision table pulled out of it
/// specifically so that branch's logic is still checked directly, with
/// `isWeb` passed in rather than read from the real constant.
void main() {
  Future<double> topInset(WidgetTester tester) async {
    late double top;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: AppWindowInsets(
          child: Builder(
            builder: (context) {
              top = MediaQuery.paddingOf(context).top;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return top;
  }

  testWidgets('macOS reports the title bar as a top inset', (tester) async {
    expect(await topInset(tester), ShellLayoutTokens.macTitleBarHeight);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'other platforms are unchanged',
    (tester) async => expect(await topInset(tester), 0),
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );

  group('windowInsetFor', () {
    const narrow = false; // not wide — phone-width web
    const wide = true;

    test('mac title bar wins regardless of web/width', () {
      expect(
        windowInsetFor(isMacTitleBar: true, isWeb: true, isWideLayout: narrow),
        const EdgeInsets.only(top: ShellLayoutTokens.macTitleBarHeight),
      );
    });

    test('web at phone width reserves top AND bottom insets', () {
      expect(
        windowInsetFor(isMacTitleBar: false, isWeb: true, isWideLayout: narrow),
        const EdgeInsets.only(
          top: ShellLayoutTokens.webMobileTopInset,
          bottom: ShellLayoutTokens.webMobileBottomInset,
        ),
      );
    });

    test('web at wide (desktop) width is untouched', () {
      expect(
        windowInsetFor(isMacTitleBar: false, isWeb: true, isWideLayout: wide),
        EdgeInsets.zero,
      );
    });

    test('non-web (a real iOS/Android app) is untouched regardless of '
        'width', () {
      expect(
        windowInsetFor(
          isMacTitleBar: false,
          isWeb: false,
          isWideLayout: narrow,
        ),
        EdgeInsets.zero,
      );
      expect(
        windowInsetFor(isMacTitleBar: false, isWeb: false, isWideLayout: wide),
        EdgeInsets.zero,
      );
    });
  });
}
