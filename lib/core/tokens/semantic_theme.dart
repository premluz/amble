import 'package:flutter/material.dart';

import 'color_primitives.dart';
import 'motion_primitives.dart';
import 'radius_primitives.dart';
import 'spacing_primitives.dart';
import 'type_primitives.dart';

/// Semantic task category. Fixed taxonomy, not a free color picker —
/// see docs/DECISIONS.md ("Task colors are semantic categories").
enum TaskCategoryToken { health, work, personal, admin }

/// Tier 2 — semantic tokens, meaning-bound references to Tier 1.
/// This is the layer widgets actually consume; never reference
/// [ColorPrimitives] etc. directly from a widget.
@immutable
class AmbleTheme extends ThemeExtension<AmbleTheme> {
  const AmbleTheme({
    required this.colorSurfacePrimary,
    required this.colorSurfaceSecondary,
    required this.colorSurfaceTimeline,
    required this.colorTextPrimary,
    required this.colorTextSecondary,
    required this.colorBorder,
    required this.colorAccent,
    required this.colorTaskCompleted,
    required this.colorTaskSkipped,
    required this.colorTaskAlert,
    required this.categoryColors,
    required this.spacingXs,
    required this.spacingSm,
    required this.spacingMd,
    required this.spacingLg,
    required this.spacingXl,
    required this.spacingBlockGap,
    required this.spacingScreenPadding,
    required this.radiusControl,
    required this.radiusCard,
    required this.radiusTaskPill,
    required this.radiusSheet,
    required this.borderWidthHairline,
    required this.textHeadline,
    required this.textTitle,
    required this.textBody,
    required this.textLabel,
    required this.textCaption,
    required this.motionFast,
    required this.motionNormal,
    required this.motionSlow,
    required this.curveStandard,
  });

  // Surfaces
  final Color colorSurfacePrimary;
  final Color colorSurfaceSecondary;
  final Color colorSurfaceTimeline;

  // Text
  final Color colorTextPrimary;
  final Color colorTextSecondary;

  // Structure
  final Color colorBorder;
  final Color colorAccent;

  // Task status
  final Color colorTaskCompleted;
  final Color colorTaskSkipped;
  final Color colorTaskAlert;

  /// Fixed task-category taxonomy → color. See [TaskCategoryToken].
  final Map<TaskCategoryToken, Color> categoryColors;

  // Spacing
  final double spacingXs;
  final double spacingSm;
  final double spacingMd;
  final double spacingLg;
  final double spacingXl;
  final double spacingBlockGap;
  final double spacingScreenPadding;

  // Radii
  final double radiusControl;
  final double radiusCard;
  final double radiusTaskPill;
  final double radiusSheet;

  /// Hairline stroke/line width — thin connectors, dividers, borders.
  final double borderWidthHairline;

  // Type
  final TextStyle textHeadline;
  final TextStyle textTitle;
  final TextStyle textBody;
  final TextStyle textLabel;
  final TextStyle textCaption;

  // Motion
  final Duration motionFast;
  final Duration motionNormal;
  final Duration motionSlow;
  final Curve curveStandard;

  static final light = AmbleTheme(
    colorSurfacePrimary: ColorPrimitives.sand50,
    colorSurfaceSecondary: ColorPrimitives.sage100,
    colorSurfaceTimeline: ColorPrimitives.sand100,
    colorTextPrimary: ColorPrimitives.slate900,
    colorTextSecondary: ColorPrimitives.slate500,
    colorBorder: ColorPrimitives.sand300,
    colorAccent: ColorPrimitives.sage500,
    colorTaskCompleted: ColorPrimitives.sage500,
    colorTaskSkipped: ColorPrimitives.slate300,
    colorTaskAlert: ColorPrimitives.coral500,
    categoryColors: {
      TaskCategoryToken.health: ColorPrimitives.clay500,
      TaskCategoryToken.work: ColorPrimitives.ochre500,
      TaskCategoryToken.personal: ColorPrimitives.periwinkle500,
      TaskCategoryToken.admin: ColorPrimitives.berry500,
    },
    spacingXs: SpacingPrimitives.space2,
    spacingSm: SpacingPrimitives.space3,
    spacingMd: SpacingPrimitives.space5,
    spacingLg: SpacingPrimitives.space7,
    spacingXl: SpacingPrimitives.space9,
    spacingBlockGap: SpacingPrimitives.space3,
    spacingScreenPadding: SpacingPrimitives.space7,
    radiusControl: RadiusPrimitives.radius2,
    radiusCard: RadiusPrimitives.radius4,
    radiusTaskPill: RadiusPrimitives.radiusFull,
    radiusSheet: RadiusPrimitives.radius6,
    borderWidthHairline: SpacingPrimitives.space1,
    textHeadline: TextStyle(
      fontSize: TypePrimitives.size6,
      fontWeight: TypePrimitives.weightBold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.slate900,
    ),
    textTitle: TextStyle(
      fontSize: TypePrimitives.size4,
      fontWeight: TypePrimitives.weightSemibold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.slate900,
    ),
    textBody: TextStyle(
      fontSize: TypePrimitives.size3,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate900,
    ),
    textLabel: TextStyle(
      fontSize: TypePrimitives.size2,
      fontWeight: TypePrimitives.weightMedium,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate700,
    ),
    textCaption: TextStyle(
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.slate500,
    ),
    motionFast: const Duration(milliseconds: MotionPrimitives.durationFastMs),
    motionNormal: const Duration(
      milliseconds: MotionPrimitives.durationNormalMs,
    ),
    motionSlow: const Duration(milliseconds: MotionPrimitives.durationSlowMs),
    curveStandard: const Cubic(0.4, 0.0, 0.2, 1.0),
  );

  static final dark = AmbleTheme(
    colorSurfacePrimary: ColorPrimitives.slate900,
    colorSurfaceSecondary: ColorPrimitives.sage700,
    colorSurfaceTimeline: ColorPrimitives.slate700,
    colorTextPrimary: ColorPrimitives.sand50,
    colorTextSecondary: ColorPrimitives.sand500,
    colorBorder: ColorPrimitives.slate700,
    colorAccent: ColorPrimitives.sage300,
    colorTaskCompleted: ColorPrimitives.sage300,
    colorTaskSkipped: ColorPrimitives.slate500,
    colorTaskAlert: ColorPrimitives.coral300,
    categoryColors: {
      TaskCategoryToken.health: ColorPrimitives.clay500,
      TaskCategoryToken.work: ColorPrimitives.ochre500,
      TaskCategoryToken.personal: ColorPrimitives.periwinkle500,
      TaskCategoryToken.admin: ColorPrimitives.berry500,
    },
    spacingXs: SpacingPrimitives.space2,
    spacingSm: SpacingPrimitives.space3,
    spacingMd: SpacingPrimitives.space5,
    spacingLg: SpacingPrimitives.space7,
    spacingXl: SpacingPrimitives.space9,
    spacingBlockGap: SpacingPrimitives.space3,
    spacingScreenPadding: SpacingPrimitives.space7,
    radiusControl: RadiusPrimitives.radius2,
    radiusCard: RadiusPrimitives.radius4,
    radiusTaskPill: RadiusPrimitives.radiusFull,
    radiusSheet: RadiusPrimitives.radius6,
    borderWidthHairline: SpacingPrimitives.space1,
    textHeadline: TextStyle(
      fontSize: TypePrimitives.size6,
      fontWeight: TypePrimitives.weightBold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.sand50,
    ),
    textTitle: TextStyle(
      fontSize: TypePrimitives.size4,
      fontWeight: TypePrimitives.weightSemibold,
      height: TypePrimitives.lineHeightTight,
      color: ColorPrimitives.sand50,
    ),
    textBody: TextStyle(
      fontSize: TypePrimitives.size3,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand50,
    ),
    textLabel: TextStyle(
      fontSize: TypePrimitives.size2,
      fontWeight: TypePrimitives.weightMedium,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand300,
    ),
    textCaption: TextStyle(
      fontSize: TypePrimitives.size1,
      fontWeight: TypePrimitives.weightRegular,
      height: TypePrimitives.lineHeightNormal,
      color: ColorPrimitives.sand500,
    ),
    motionFast: const Duration(milliseconds: MotionPrimitives.durationFastMs),
    motionNormal: const Duration(
      milliseconds: MotionPrimitives.durationNormalMs,
    ),
    motionSlow: const Duration(milliseconds: MotionPrimitives.durationSlowMs),
    curveStandard: const Cubic(0.4, 0.0, 0.2, 1.0),
  );

  @override
  AmbleTheme copyWith({
    Color? colorSurfacePrimary,
    Color? colorSurfaceSecondary,
    Color? colorSurfaceTimeline,
    Color? colorTextPrimary,
    Color? colorTextSecondary,
    Color? colorBorder,
    Color? colorAccent,
    Color? colorTaskCompleted,
    Color? colorTaskSkipped,
    Color? colorTaskAlert,
    Map<TaskCategoryToken, Color>? categoryColors,
    double? spacingXs,
    double? spacingSm,
    double? spacingMd,
    double? spacingLg,
    double? spacingXl,
    double? spacingBlockGap,
    double? spacingScreenPadding,
    double? radiusControl,
    double? radiusCard,
    double? radiusTaskPill,
    double? radiusSheet,
    double? borderWidthHairline,
    TextStyle? textHeadline,
    TextStyle? textTitle,
    TextStyle? textBody,
    TextStyle? textLabel,
    TextStyle? textCaption,
    Duration? motionFast,
    Duration? motionNormal,
    Duration? motionSlow,
    Curve? curveStandard,
  }) {
    return AmbleTheme(
      colorSurfacePrimary: colorSurfacePrimary ?? this.colorSurfacePrimary,
      colorSurfaceSecondary:
          colorSurfaceSecondary ?? this.colorSurfaceSecondary,
      colorSurfaceTimeline: colorSurfaceTimeline ?? this.colorSurfaceTimeline,
      colorTextPrimary: colorTextPrimary ?? this.colorTextPrimary,
      colorTextSecondary: colorTextSecondary ?? this.colorTextSecondary,
      colorBorder: colorBorder ?? this.colorBorder,
      colorAccent: colorAccent ?? this.colorAccent,
      colorTaskCompleted: colorTaskCompleted ?? this.colorTaskCompleted,
      colorTaskSkipped: colorTaskSkipped ?? this.colorTaskSkipped,
      colorTaskAlert: colorTaskAlert ?? this.colorTaskAlert,
      categoryColors: categoryColors ?? this.categoryColors,
      spacingXs: spacingXs ?? this.spacingXs,
      spacingSm: spacingSm ?? this.spacingSm,
      spacingMd: spacingMd ?? this.spacingMd,
      spacingLg: spacingLg ?? this.spacingLg,
      spacingXl: spacingXl ?? this.spacingXl,
      spacingBlockGap: spacingBlockGap ?? this.spacingBlockGap,
      spacingScreenPadding: spacingScreenPadding ?? this.spacingScreenPadding,
      radiusControl: radiusControl ?? this.radiusControl,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusTaskPill: radiusTaskPill ?? this.radiusTaskPill,
      radiusSheet: radiusSheet ?? this.radiusSheet,
      borderWidthHairline: borderWidthHairline ?? this.borderWidthHairline,
      textHeadline: textHeadline ?? this.textHeadline,
      textTitle: textTitle ?? this.textTitle,
      textBody: textBody ?? this.textBody,
      textLabel: textLabel ?? this.textLabel,
      textCaption: textCaption ?? this.textCaption,
      motionFast: motionFast ?? this.motionFast,
      motionNormal: motionNormal ?? this.motionNormal,
      motionSlow: motionSlow ?? this.motionSlow,
      curveStandard: curveStandard ?? this.curveStandard,
    );
  }

  @override
  AmbleTheme lerp(ThemeExtension<AmbleTheme>? other, double t) {
    if (other is! AmbleTheme) return this;
    return AmbleTheme(
      colorSurfacePrimary: Color.lerp(
        colorSurfacePrimary,
        other.colorSurfacePrimary,
        t,
      )!,
      colorSurfaceSecondary: Color.lerp(
        colorSurfaceSecondary,
        other.colorSurfaceSecondary,
        t,
      )!,
      colorSurfaceTimeline: Color.lerp(
        colorSurfaceTimeline,
        other.colorSurfaceTimeline,
        t,
      )!,
      colorTextPrimary: Color.lerp(
        colorTextPrimary,
        other.colorTextPrimary,
        t,
      )!,
      colorTextSecondary: Color.lerp(
        colorTextSecondary,
        other.colorTextSecondary,
        t,
      )!,
      colorBorder: Color.lerp(colorBorder, other.colorBorder, t)!,
      colorAccent: Color.lerp(colorAccent, other.colorAccent, t)!,
      colorTaskCompleted: Color.lerp(
        colorTaskCompleted,
        other.colorTaskCompleted,
        t,
      )!,
      colorTaskSkipped: Color.lerp(
        colorTaskSkipped,
        other.colorTaskSkipped,
        t,
      )!,
      colorTaskAlert: Color.lerp(colorTaskAlert, other.colorTaskAlert, t)!,
      categoryColors: t < 0.5 ? categoryColors : other.categoryColors,
      spacingXs: _lerpDouble(spacingXs, other.spacingXs, t),
      spacingSm: _lerpDouble(spacingSm, other.spacingSm, t),
      spacingMd: _lerpDouble(spacingMd, other.spacingMd, t),
      spacingLg: _lerpDouble(spacingLg, other.spacingLg, t),
      spacingXl: _lerpDouble(spacingXl, other.spacingXl, t),
      spacingBlockGap: _lerpDouble(spacingBlockGap, other.spacingBlockGap, t),
      spacingScreenPadding: _lerpDouble(
        spacingScreenPadding,
        other.spacingScreenPadding,
        t,
      ),
      radiusControl: _lerpDouble(radiusControl, other.radiusControl, t),
      radiusCard: _lerpDouble(radiusCard, other.radiusCard, t),
      radiusTaskPill: _lerpDouble(radiusTaskPill, other.radiusTaskPill, t),
      radiusSheet: _lerpDouble(radiusSheet, other.radiusSheet, t),
      borderWidthHairline: _lerpDouble(
        borderWidthHairline,
        other.borderWidthHairline,
        t,
      ),
      textHeadline: TextStyle.lerp(textHeadline, other.textHeadline, t)!,
      textTitle: TextStyle.lerp(textTitle, other.textTitle, t)!,
      textBody: TextStyle.lerp(textBody, other.textBody, t)!,
      textLabel: TextStyle.lerp(textLabel, other.textLabel, t)!,
      textCaption: TextStyle.lerp(textCaption, other.textCaption, t)!,
      motionFast: t < 0.5 ? motionFast : other.motionFast,
      motionNormal: t < 0.5 ? motionNormal : other.motionNormal,
      motionSlow: t < 0.5 ? motionSlow : other.motionSlow,
      curveStandard: t < 0.5 ? curveStandard : other.curveStandard,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
