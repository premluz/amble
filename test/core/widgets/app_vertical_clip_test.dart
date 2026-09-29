import 'package:amble/core/widgets/app_vertical_clip.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('clips only top and bottom: the sides stay open so items can '
      'trail past a sliding page\'s edge', (tester) async {
    await tester.pumpWidget(
      const AppVerticalClip(child: SizedBox(width: 100, height: 200)),
    );
    final clip = tester
        .widget<ClipRect>(find.byType(ClipRect))
        .clipper!
        .getClip(const Size(100, 200));
    expect(clip.top, 0);
    expect(clip.bottom, 200);
    expect(clip.left, lessThanOrEqualTo(-100), reason: 'a page width of room');
    expect(clip.right, greaterThanOrEqualTo(200));
  });
}
