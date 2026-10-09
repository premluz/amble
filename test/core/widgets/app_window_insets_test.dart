import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/widgets/app_window_insets.dart';

/// On macOS the app paints under its transparent title bar, so the bar's
/// height is reported as a top safe area; elsewhere nothing changes.
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

  testWidgets(
    'macOS reports the title bar as a top inset',
    (tester) async {
      expect(await topInset(tester), ShellLayoutTokens.macTitleBarHeight);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'other platforms are unchanged',
    (tester) async => expect(await topInset(tester), 0),
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
}
