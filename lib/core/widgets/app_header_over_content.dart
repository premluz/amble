import 'package:flutter/widgets.dart';

/// A header above page content, laid out like a `Column` (content starts
/// where the header ends) but painted AFTER the content, so a floating
/// header pane's shadow falls over the page instead of being covered by it.
class AppHeaderOverContent extends StatelessWidget {
  const AppHeaderOverContent({
    super.key,
    required this.header,
    required this.content,
  });

  final Widget header;
  final Widget content;

  @override
  Widget build(BuildContext context) => CustomMultiChildLayout(
    delegate: _HeaderOverContentLayout(),
    children: [
      LayoutId(id: _Slot.content, child: content),
      LayoutId(id: _Slot.header, child: header),
    ],
  );
}

enum _Slot { header, content }

class _HeaderOverContentLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final header = layoutChild(
      _Slot.header,
      BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        maxHeight: size.height,
      ),
    );
    positionChild(_Slot.header, Offset.zero);
    final contentHeight = size.height - header.height;
    layoutChild(
      _Slot.content,
      BoxConstraints.tight(
        Size(size.width, contentHeight < 0 ? 0 : contentHeight),
      ),
    );
    positionChild(_Slot.content, Offset(0, header.height));
  }

  @override
  bool shouldRelayout(_HeaderOverContentLayout oldDelegate) => false;
}
