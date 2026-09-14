import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/zone_grid/zone_paint_selection.dart';
void main() {
  test('reverse diagonal painting resolves the same weekdays and hours', () {
    final forward=ZonePaintSelection.between(1,420,6,645);
    final reverse=ZonePaintSelection.between(6,645,1,420);
    expect(reverse.weekdays,forward.weekdays); expect(reverse.startMinutes,forward.startMinutes);
    expect(reverse.endMinutes,forward.endMinutes);
  });
  test('paint stays inside the week and midnight, with a nonzero duration', () {
    final paint=ZonePaintSelection.between(-2,1440,10,1500);
    expect(paint.weekdays,{1,2,3,4,5,6,7}); expect(paint.startMinutes,1435);expect(paint.endMinutes,1440);
  });
}
