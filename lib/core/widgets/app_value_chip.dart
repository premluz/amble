import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_button.dart' show AppButton, AppButtonSize, appButtonHeightFor;
import 'app_press_feedback.dart';

/// Whether an [AppValueChip] paints a fill or only an outline at rest.
///
/// Both variants signal a set value with the SAME [AppButton.subtleTint]
/// fill — confirmed via AskUserQuestion ("outlined gains a subtle fill when
/// set"), so [outlined] is an at-REST distinction, not a permanent one. An
/// outlined chip keeps its border in both states; a filled chip never has
/// one.
enum AppValueChipVariant { filled, outlined }

/// A compact, pill-shaped button that stands in for ONE value the user
/// picks elsewhere — it shows a [placeholder] until something is chosen,
/// then the chosen value itself. The row of "Today / hh:mm / duration"
/// controls under a task composer is the reference: each opens its own
/// sheet, and each reads at a glance as either "still unset" or "set to
/// this".
///
/// **Not [AppSelectableChip].** That widget is a TOGGLE — its `selected`
/// flag is the whole state, and its label never changes. This one carries
/// a value: [hasValue] drives the placeholder/value styling, while [label]
/// changes to whatever was picked. A day-of-week chip is the former; a
/// "start time" chip is the latter.
///
/// **Hand-rolled, not Material's `RawChip`/`InputChip`.** Those ship an
/// opaque `Material` ancestor, which is exactly what broke the glass look
/// in [AppContextMenu] and forced a custom `PopupRoute` there — a
/// translucent [AppButton.subtleTint] fill under a `BackdropFilter` can't
/// sit on top of one. Their own padding model, `showCheckmark` and avatar
/// slots would all need overriding too. This instead composes the same
/// primitives every other pill in the app already uses
/// ([AppPressFeedback], `theme.radiusPill`, [AppButton.subtleTint]), so it
/// tracks the live "Pill shape" setting and the shared secondary-surface
/// tint for free. Per docs/CONSTITUTION.md design principle 4 this IS the
/// adaptive layer — feature screens consume this, never a raw chip.
///
/// Tapping a chip that already has a value just reopens its picker;
/// there is deliberately no inline clear affordance (confirmed via
/// AskUserQuestion), so the footprint never changes between states and
/// clearing stays the picker's own concern.
class AppValueChip extends StatelessWidget {
  const AppValueChip({
    super.key,
    required this.label,
    required this.hasValue,
    required this.onTap,
    this.icon,
    this.variant = AppValueChipVariant.filled,
    this.size = AppValueChipSize.sm,
  });

  /// What the chip reads right now — the chosen value when [hasValue], or
  /// the placeholder ("hh:mm", "Duration") when not. One field rather than
  /// separate `value`/`placeholder` props: the caller already has to
  /// format its value for display, and this keeps the empty-state copy
  /// next to it at the call site instead of split across two arguments.
  final String label;

  /// Whether [label] is a real chosen value (styled as set) rather than a
  /// placeholder (styled as empty).
  final bool hasValue;

  final VoidCallback onTap;

  /// Optional leading glyph — the clock/stopwatch/flag icons the reference
  /// row pairs with some of its chips. Omitted for a text-only chip.
  final IconData? icon;

  final AppValueChipVariant variant;
  final AppValueChipSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final radius = BorderRadius.circular(theme.radiusPill);
    final isOutlined = variant == AppValueChipVariant.outlined;

    // A set value reads at full strength; a placeholder recedes to
    // secondary, the same empty-vs-filled contrast `AppTextField`'s own
    // hint already uses. Never tertiary: these are tap targets, and a
    // placeholder still has to be readable enough to tell you WHICH
    // picker the chip opens.
    final foreground = hasValue
        ? theme.colorTextPrimary
        : theme.colorTextSecondary;

    final height = appButtonHeightFor(theme, _buttonSize);
    // Horizontal padding scales with the rung so a 28px chip doesn't carry
    // a 40px chip's roomy inset — half the height reads as a balanced pill
    // end-cap at every rung, and it keeps the value/placeholder swap from
    // shifting the text's optical position.
    final horizontalPadding = height / 3;

    // `Alignment.center` is deliberately NOT set here: on a `Container`
    // with no width, an alignment makes it expand to every pixel the
    // parent offers (a real bug caught by a size probe — the chip
    // rendered 800px wide inside a `Center`). A chip must hug its
    // content so a row of them packs tightly; the `Row` below centers
    // the label vertically on its own via the fixed `height`.
    final content = Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        // Filled-and-unset is the only case that paints a flat opaque
        // fill. A SET chip's fill comes from the `BackdropFilter` wrap
        // below in BOTH variants, so this stays null there — an opaque
        // color painted here would sit on top of that blur and hide it
        // (the same trap `AppSelectableChip` documents).
        color: hasValue || isOutlined ? null : theme.colorSurfaceTimeline,
        borderRadius: radius,
        border: isOutlined
            ? Border.all(
                color: hasValue ? theme.colorTextPrimary : theme.colorBorder,
                width: theme.borderWidthHairline,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final glyph?) ...[
            Icon(glyph, size: _iconSize(theme), color: foreground),
            SizedBox(width: theme.spacingXs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _textStyle(theme).copyWith(
                color: foreground,
                // A set value is the content; a placeholder is a prompt.
                // Weight, not just color, so the difference survives a
                // glance at a dense row of these.
                fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    return AppPressFeedback(
      onTap: onTap,
      borderRadius: radius,
      // The wash rides on the chip's own foreground — same reasoning as
      // AppButton's and AppSelectableChip's own `rippleColor`.
      rippleColor: foreground,
      child: hasValue
          ? ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: theme.blurOverlaySigma,
                  sigmaY: theme.blurOverlaySigma,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppButton.subtleTint(theme),
                    borderRadius: radius,
                  ),
                  child: content,
                ),
              ),
            )
          : content,
    );
  }

  AppButtonSize get _buttonSize => switch (size) {
    AppValueChipSize.xs => AppButtonSize.xs,
    AppValueChipSize.sm => AppButtonSize.sm,
    AppValueChipSize.md => AppButtonSize.md,
  };

  TextStyle _textStyle(AmbleTheme theme) => switch (size) {
    AppValueChipSize.xs || AppValueChipSize.sm => theme.textCaption,
    AppValueChipSize.md => theme.textLabel,
  };

  double _iconSize(AmbleTheme theme) => _textStyle(theme).fontSize! * 1.2;
}

/// The rungs [AppValueChip] ships, a deliberate SUBSET of [AppButtonSize]'s
/// own `xs…xl` — confirmed via AskUserQuestion. A chip is a compact
/// control by definition; `lg`/`xl` have no caller and would be untested
/// surface area, so they're omitted rather than exposed on faith. Maps
/// onto the shared button height tokens rather than inventing its own, so
/// a chip and a button on the same row line up exactly.
enum AppValueChipSize { xs, sm, md }
