import 'package:amble/core/widgets/app_header_over_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('content starts where the header ends, and the header paints '
      'LAST so a floating pane\'s shadow falls over the page', (tester) async {
    const header = ValueKey('header');
    const content = ValueKey('content');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AppHeaderOverContent(
          header: SizedBox(key: header, height: 48),
          content: ColoredBox(key: content, color: Color(0xFF000000)),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(content)).dy, 48);
    expect(tester.getBottomLeft(find.byKey(content)).dy, 600);

    final layout = tester.renderObject<RenderCustomMultiChildLayoutBox>(
      find.byType(CustomMultiChildLayout),
    );
    final last = layout.lastChild!;
    final parentData = last.parentData! as MultiChildLayoutParentData;
    expect(parentData.id.toString(), contains('header'));
  });
}
