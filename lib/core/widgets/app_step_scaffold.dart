import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_button.dart';
import 'app_press_feedback.dart';
import 'app_top_scroll_fade.dart';

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
    this.footerContent,
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

  /// Extra content pinned above the primary button, below [errorMessage]
  /// — e.g. the recurring-edit scope toggle ("Affect future instances")
  /// task_detail_sheet.dart shows only while a start-time/duration change
  /// on a recurring task is pending. Null renders nothing; every existing
  /// caller predates this and keeps its unchanged footer layout.
  final Widget? footerContent;

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
                    // Title-bearing case bumped from `spacingXl + spacingMd`
                    // to `spacingXl + spacingLg` — requested directly,
                    // alongside the Inbox/Tracked screen headings' own
                    // identical bump: "same for sheets heading."
                    height: headerContent == null
                        ? theme.spacingXl +
                              (modalTitle == null
                                  ? theme.spacingLg
                                  : theme.spacingXl + theme.spacingLg)
                        : null,
                    decoration: BoxDecoration(
                      // Plain-title case: the header's OWN background IS
                      // the gradient — colorSurfaceSecondary at the top,
                      // blending down into the body's own colorSurfaceBase
                      // at the header's bottom edge, so there's no hard
                      // seam where the two meet. A flat colorSurfaceSecondary
                      // FILL with a separate `AppTopScrollFade` painted on
                      // top of it (the previous shape) never actually blended
                      // anything — that fade goes colorSurfaceSecondary-to-
                      // transparent, which is invisible against a layer
                      // that's already solid colorSurfaceSecondary underneath
                      // it, so it read as a flat block with an abrupt colour
                      // change against the body, not a gradient. Reported
                      // directly: "heading not have nice gradient... sheet
                      // heading section different color than body."
                      gradient: headerContent == null
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.colorSurfaceSecondary,
                                theme.colorSurfaceBase,
                              ],
                            )
                          : null,
                      color: headerContent == null ? null : headerColor,
                      // Rounded bottom corner is only right for the
                      // colored `headerContent` banner, which reads as a
                      // floating panel — the plain-title header sits flush
                      // against the body below it, same as before this
                      // case had a background at all.
                      borderRadius: headerContent == null
                          ? null
                          : BorderRadius.vertical(
                              bottom: Radius.circular(theme.radiusModal),
                            ),
                    ),
                    // ClipRect confines the fade strictly to THIS
                    // container's own bounds — moved here from the body
                    // below, requested directly: "the shade on the
                    // sheets' title should not expand beyond the title
                    // container. This [fade] should be just within, so
                    // it doesn't push the content too much down." A
                    // fade in the body needed extra top padding on every
                    // sheet's own content to clear it; living inside the
                    // header instead needs none, since the header
                    // already reserves its own height.
                    child: ClipRect(
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
                  ),
                  Expanded(
                    // No surface of its own: the header strip and the body
                    // are one continuous level-0 ground.
                    child: Stack(
                      children: [
                        body,
                        // Top fade at the header/body seam — reported
                        // directly: "the header on pages like Tasks...is
                        // not a smooth gradient. The content slides
                        // through underneath, and the header cuts the
                        // content with a hard edge." The header's own
                        // gradient (above) only ever blends ITS OWN fixed
                        // background down to colorSurfaceBase — it says
                        // nothing about the body's actual scrolling
                        // content, which had no fade at all here and so
                        // hit the Expanded's top edge with a hard cut, the
                        // same bug already fixed on the Inbox/Tracked
                        // pages (see docs/DECISIONS.md). Only for the
                        // plain-title header (which blends into
                        // colorSurfaceBase); the colored `headerContent`
                        // banner case is a deliberately floating panel
                        // with a rounded bottom corner, not something body
                        // content should visually blend into.
                        if (headerContent == null)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: AppTopScrollFade(
                              color: theme.colorSurfaceBase,
                            ),
                          ),
                        // Mirrored bottom fade — requested directly:
                        // "use same at the bottom." Painted BEFORE the
                        // primary-button footer below (so the footer
                        // paints on top and stays crisp; only the
                        // scrolling body content behind it fades).
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: AppTopScrollFade(
                            color: theme.colorSurfaceBase,
                            fromBottom: true,
                          ),
                        ),
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
                                if (footerContent != null) ...[
                                  footerContent!,
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
    return AppPressFeedback(
      onTap: onTap,
      shape: BoxShape.circle,
      // Rides on the icon's own color, so the wash stays visible whether
      // this button sits on the neutral field fill (its default) or on a
      // caller-supplied colored header banner.
      rippleColor: iconColor ?? theme.colorTextPrimary,
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
