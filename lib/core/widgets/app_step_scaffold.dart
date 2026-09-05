import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_button.dart';

/// The near-full-screen slide-up chrome shared by every task-detail-family
/// modal (create wizard, edit-details, edit-schedule) — colored header
/// banner (or none), close/back buttons, and a primary button pinned to
/// the bottom. Promoted out of `task_detail_sheet.dart` (where it was
/// originally private, `_StepScaffold`) so a second, unrelated feature
/// (Zone add/edit) can reuse the exact same "add task modal" visual
/// language it was built to mirror, rather than duplicating ~250 lines of
/// layout or building a bespoke, only-visually-similar header. Every
/// existing caller inside `task_detail_sheet.dart` was repointed at this
/// public version with no behavior change.
///
/// Present via a route matching [PageRouteBuilder]'s slide-up-from-bottom,
/// non-opaque, scrim-barrier shape — see `task_detail_sheet.dart`'s
/// `_pushDetailRoute` for the canonical example; not [AppSheet], whose
/// fixed white-background contract doesn't fit this scaffold's colored,
/// edge-to-edge header (see docs/DECISIONS.md, Phase 4).
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.theme,
    required this.headerColor,
    this.modalTitle,
    this.titleAlignment = TextAlign.center,
    this.headerContent,
    required this.onClose,
    required this.onBack,
    required this.body,
    required this.primaryLabel,
    this.onPrimaryPressed,
    this.errorMessage,
    this.isPrimaryLoading = false,
    this.onSecondaryAction,
    this.secondaryActionIcon,
  });

  final AmbleTheme theme;
  final Color headerColor;

  /// Null renders no coloured header banner at all — just the close/back
  /// buttons on the page's own background. Every caller with real header
  /// content (a category-colored task summary, a zone's own accent) still
  /// passes a real header.
  final Widget? headerContent;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final Widget body;

  /// The modal's own title ("Create task", "New zone"), shown in the
  /// header beside the close button. Null on single-step edit modals
  /// reached from an entity that already names itself.
  final String? modalTitle;

  /// [TextAlign.center] (matching the create wizard) or [TextAlign.left]
  /// (a single-screen flow whose title reads as a page heading, with no
  /// back arrow to balance against).
  final TextAlign titleAlignment;

  final String primaryLabel;

  /// Null disables the primary button (matches [AppButton.onPressed]'s own
  /// nullable-means-disabled contract).
  final VoidCallback? onPrimaryPressed;

  /// Shown inline just above the primary button — e.g. a validation
  /// rejection message. Null when there's nothing to report.
  final String? errorMessage;

  /// Shows a spinner on the primary button and disables it for the
  /// duration of an in-flight save — see [AppButton.isLoading].
  final bool isPrimaryLoading;

  /// A circular icon button on the same row as the primary button,
  /// leading it — null renders nothing, and the primary button stays
  /// full-width. Generic (not "delete" specifically) since this scaffold
  /// is shared across features (task edit, Zone add/edit): a caller with
  /// no use for it simply never passes it, so the shared layout doesn't
  /// carry a task-specific concept. [secondaryActionIcon] must be
  /// non-null whenever this is.
  final VoidCallback? onSecondaryAction;
  final IconData? secondaryActionIcon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent, NOT the level-0 ground: the sheet is inset from the
      // screen edges so its corners are actually visible, which only
      // reads if whatever is behind it shows through.
      backgroundColor: Colors.transparent,
      // Edge to edge horizontally and offset only from the top, so the
      // sheet reads as a panel pulled up over the screen.
      body: Padding(
        padding: EdgeInsets.only(top: theme.spacingXl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorSurfaceBase,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radiusModal),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radiusModal),
            ),
            child: SafeArea(
              // Top handled by the offset above; the sheet owns that edge.
              top: false,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: headerContent == null
                        ? theme.spacingXl +
                              (modalTitle == null
                                  ? theme.spacingLg
                                  : theme.spacingXl + theme.spacingMd)
                        : null,
                    decoration: headerContent == null
                        ? null
                        : BoxDecoration(
                            color: headerColor,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(theme.radiusModal),
                            ),
                          ),
                    child: Stack(
                      children: [
                        if (modalTitle != null)
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left:
                                    onBack != null ||
                                        titleAlignment == TextAlign.center
                                    ? theme.spacingXl + theme.spacingLg
                                    : theme.spacingLg,
                                right: theme.spacingXl + theme.spacingLg,
                              ),
                              child: Align(
                                alignment: titleAlignment == TextAlign.center
                                    ? Alignment.center
                                    : Alignment.centerLeft,
                                child: Text(
                                  modalTitle!,
                                  textAlign: titleAlignment,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textHeadline.copyWith(
                                    color: theme.colorTextPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (headerContent != null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              onBack != null
                                  ? theme.spacingXl + theme.spacingLg
                                  : theme.spacingLg,
                              theme.spacingXl + theme.spacingSm,
                              theme.spacingXl + theme.spacingLg,
                              theme.spacingLg,
                            ),
                            child: headerContent,
                          ),
                        if (onBack != null)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: theme.spacingLg,
                            child: Center(
                              child: HeaderCircleButton(
                                theme: theme,
                                icon: Icons.arrow_back_rounded,
                                onTap: onBack!,
                              ),
                            ),
                          ),
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: theme.spacingLg,
                          child: Center(
                            child: HeaderCircleButton(
                              theme: theme,
                              icon: Icons.close_rounded,
                              onTap: onClose,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    // No surface of its own: the header strip and the body
                    // are one continuous level-0 ground.
                    child: Stack(
                      children: [
                        body,
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: theme.spacingLg,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: theme.spacingLg,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (errorMessage != null) ...[
                                  Text(
                                    errorMessage!,
                                    style: theme.textBody.copyWith(
                                      color: theme.colorTaskAlert,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: theme.spacingSm),
                                ],
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Fixed circle size (matching
                                    // AppIconButton's own established
                                    // standalone-icon-button size) rather
                                    // than trying to match AppButton's own
                                    // padding-driven height via intrinsic
                                    // sizing — that combination (
                                    // IntrinsicHeight + AspectRatio inside
                                    // a Row) let the circle's computed
                                    // size run away past the sheet's own
                                    // bounds (reported directly, from an
                                    // on-device screenshot: the circle
                                    // overflowed the left edge).
                                    if (onSecondaryAction != null) ...[
                                      GestureDetector(
                                        onTap: onSecondaryAction,
                                        child: Container(
                                          width: theme.spacingXl * 1.5,
                                          height: theme.spacingXl * 1.5,
                                          decoration: BoxDecoration(
                                            color: theme.colorTaskAlert,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            secondaryActionIcon!,
                                            color: theme.colorSurfacePrimary,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: theme.spacingSm),
                                    ],
                                    Expanded(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            theme.radiusTaskPill,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.colorTextPrimary
                                                  .withValues(alpha: 0.18),
                                              blurRadius: theme.spacingMd,
                                              offset: Offset(
                                                0,
                                                theme.spacingXs,
                                              ),
                                            ),
                                          ],
                                        ),
                                        child: AppButton(
                                          label: primaryLabel,
                                          size: AppButtonSize.large,
                                          shape: AppButtonShape.pill,
                                          onPressed: onPrimaryPressed,
                                          isLoading: isPrimaryLoading,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular header button (back/close) on the sheet's own level-0
/// ground — works in either palette since its glyph comes from a TEXT
/// token, never a surface one (surface/text tokens invert in opposite
/// directions between light/dark, so a surface-sourced glyph can
/// disappear in one palette).
class HeaderCircleButton extends StatelessWidget {
  const HeaderCircleButton({
    super.key,
    required this.theme,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  final AmbleTheme theme;
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: theme.spacingXl,
        height: theme.spacingXl,
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorSurfaceField,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? theme.colorTextPrimary),
      ),
    );
  }
}
