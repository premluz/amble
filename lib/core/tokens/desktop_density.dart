import 'package:flutter/material.dart';

import 'semantic_theme.dart';
import 'spacing_primitives.dart';
import 'type_primitives.dart';

/// The wide layout's density: every button-height rung one step down (xl
/// 56→48, lg 48→40, md 40→32, sm 32→28, xs 28→24, shapes unchanged), and
/// the reading sizes one step down (body 16→14, label 14→13, title 20→18,
/// headline 32→24), matching the ~13–14pt UI text and ~22pt page titles
/// measured in the references. Caption, task and time sizes (11–12) already
/// match them and stay. Requested directly against Notion Calendar, Linear and
/// Devin: "size of buttons on desktop, not shape". A pointer needs a
/// smaller target than a thumb, and everything that aligns to the button
/// scale (tab switches, chips, the dock, nav rows) shrinks with it.
///
/// Applied once, around the wide shell; phones never see it.
abstract final class DesktopDensity {
  static AmbleTheme compact(AmbleTheme theme) => theme.copyWith(
    sizeButtonXs: SpacingPrimitives.space7,
    sizeButtonSm: SpacingPrimitives.space7Point5,
    sizeButtonMd: SpacingPrimitives.space8,
    sizeButtonLg: SpacingPrimitives.space9,
    sizeButtonXl: SpacingPrimitives.space9Point5,
    textHeadline: theme.textHeadline.copyWith(fontSize: TypePrimitives.size5),
    textTitle: theme.textTitle.copyWith(fontSize: TypePrimitives.size3Point5),
    textBody: theme.textBody.copyWith(fontSize: TypePrimitives.size2),
    textBodyMono: theme.textBodyMono.copyWith(fontSize: TypePrimitives.size2),
    textLabel: theme.textLabel.copyWith(fontSize: TypePrimitives.size1Point5),
  );

  /// [child] with [compact] in place of the ambient [AmbleTheme].
  static Widget apply(BuildContext context, Widget child) {
    final data = Theme.of(context);
    final theme = data.extension<AmbleTheme>()!;
    return Theme(
      data: data.copyWith(
        extensions: [
          ...data.extensions.values.where((e) => e is! AmbleTheme),
          compact(theme),
        ],
      ),
      child: child,
    );
  }
}
