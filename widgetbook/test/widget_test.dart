import 'package:flutter_test/flutter_test.dart';

import 'package:amble_widgetbook/main.dart';

void main() {
  testWidgets('Widgetbook gallery starts', (tester) async {
    await tester.pumpWidget(const AmbleWidgetbookApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
