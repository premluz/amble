import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_sheet.dart';
import '../../shared/models/external_calendar_event.dart';

/// Read-only background block for one [ExternalCalendarEvent] on the
/// Timeline — Feature 1 of CONSTITUTION.md's "Calendar" section.
///
/// Deliberately reuses `ZoneBackgroundBlock`'s exact visual language (a
/// light, low-chroma, rounded background block using the same
/// time-to-pixel math as task capsules) rather than `TaskCapsuleBlock` —
/// an external event is not an editable Amble object and must never look
/// like one. Unlike `ZoneBackgroundBlock`, this is NOT `IgnorePointer`ed:
/// a tap shows a minimal read-only info sheet (title/time only — no edit,
/// no complete, no drag, no delete, no category), the one interaction
/// Feature 1 is scoped to allow. Deliberately excluded from
/// `detectOverlapClusters`/`OverlapClusterBlock` — see CONSTITUTION.md's
/// "Calendar" section for why — so this always renders as its own
/// always-visible layer, independent of whatever task clustering is doing
/// underneath.
/// The shortest this block can render without its title clipping under its
/// own time line — two lines of [AmbleTheme.textCaption] plus the block's
/// own vertical padding (spacingXs on each edge, matching the [Padding]
/// this widget wraps its content in below). Exposed so every caller
/// computing this block's height (real time-to-pixel math in Task/Zone
/// view, the stacking-cursor math in List view) applies the SAME floor —
/// real bug, reported directly ("but same line"): a short event's
/// duration-based height could land under two real text lines' combined
/// height, and a `Positioned` box shorter than its content doesn't grow to
/// fit it — the two lines rendered squeezed together rather than genuinely
/// stacked. `TaskCapsuleBlock` avoids this a different way (no fixed
/// `height` from its own caller — see its own file), but this block's
/// caller needs to know a definite height AHEAD of building it, to
/// position whatever comes after it in the stack — so the fix here is
/// raising the floor high enough that two lines always fit, not letting
/// the box grow freely.
///
/// Includes a small explicit safety margin above the literal
/// `fontSize * height` arithmetic: a real rendered line's height (font
/// ascent/descent/leading) can exceed that simple multiplication by a
/// fraction of a pixel depending on the platform's font metrics — confirmed
/// directly by a real `RenderFlex overflowed by 0.8 pixels` failure with no
/// margin. `spacingXs` itself (already a real token, not a new magic
/// number) is reused as that margin rather than inventing a separate one.
///
/// [compactText] — see [ExternalEventBlock.compactText] — needs only ONE
/// line's worth of floor, since time+title share a row in that mode
/// instead of stacking.
double externalEventBlockMinHeight(
  AmbleTheme theme, {
  bool compactText = false,
}) =>
    theme.textCaption.fontSize! *
        theme.textCaption.height! *
        (compactText ? 1 : 2) +
    theme.spacingXs * 2 +
    theme.spacingXs;

class ExternalEventBlock extends StatelessWidget {
  const ExternalEventBlock({
    super.key,
    required this.theme,
    required this.event,
    required this.rangeStart,
    required this.pixelsPerMinute,
    required this.left,
    required this.width,
    this.collapsedTop,
    this.collapsedHeight,
    this.compactText = false,
  });

  final AmbleTheme theme;
  final ExternalCalendarEvent event;

  /// Same coordinate space every other time-positioned Timeline element
  /// shares — see `ZoneBackgroundBlock`'s own doc comment. Ignored (along
  /// with [pixelsPerMinute]'s use for positioning) when [collapsedTop] is
  /// set — see its own doc comment.
  final DateTime rangeStart;
  final double pixelsPerMinute;
  final double left;
  final double width;

  /// List (collapsed) mode's own `top`, from the Timeline's stacking
  /// cursor rather than real elapsed-time math — collapsed mode has no
  /// time axis, so `event.start.difference(rangeStart)` would place this
  /// block somewhere disconnected from where the stacked task rows
  /// actually sit. Null (the default) keeps the ordinary Task/Zone view
  /// behavior, positioning by [rangeStart]/[pixelsPerMinute] as usual.
  /// Requested directly, alongside the same List/Zone view coverage.
  final double? collapsedTop;

  /// Paired with [collapsedTop] — collapsed mode's own duration-proportional
  /// height (see `_DayTimelineState._collapsedExternalEventHeight`), not
  /// the real-time-math height. Both null or both set; never one without
  /// the other.
  final double? collapsedHeight;

  /// True in List (collapsed) mode — matches [TaskCapsuleBlock.compactText]/
  /// [OverlapClusterBlock.compactText] exactly: puts the time and title on
  /// ONE line instead of two, so an external event's row reads at the same
  /// shape as the real task rows around it in that mode. Requested
  /// directly ("also inportent tasks not seeing in one line.. hour with
  /// title") — the time-in-front change above landed, but List mode kept
  /// this block's own always-stacked two-`Text` layout regardless, unlike
  /// the other two blocks which already branch on this flag. Defaults to
  /// false (current Task/Zone view stacked look).
  final bool compactText;

  @override
  Widget build(BuildContext context) {
    final top =
        collapsedTop ??
        event.start.difference(rangeStart).inMinutes * pixelsPerMinute;
    final height =
        collapsedHeight ??
        math.max(
          event.end.difference(event.start).inMinutes * pixelsPerMinute,
          externalEventBlockMinHeight(theme, compactText: compactText),
        );

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => showExternalCalendarEventInfo(
          context: context,
          theme: theme,
          event: event,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorZoneBackground,
            borderRadius: BorderRadius.circular(theme.radiusXl),
            border: Border.all(
              color: event.sourceCalendarColor ?? theme.colorTextSecondary,
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacingSm,
              vertical: theme.spacingXs,
            ),
            child: compactText
                ? Text.rich(
                    // List (collapsed) mode: time then title on ONE line —
                    // matching TaskCapsuleBlock's/OverlapClusterBlock's own
                    // compactText inline layout exactly. Requested directly
                    // ("also inportent tasks not seeing in one line.. hour
                    // with title").
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${TimeOfDay.fromDateTime(event.start).format(context)} – '
                              '${TimeOfDay.fromDateTime(event.end).format(context)}  ',
                          style: theme.textCaption.copyWith(
                            color: theme.colorTextSecondary,
                          ),
                        ),
                        TextSpan(
                          text: event.title,
                          style: theme.textCaption.copyWith(
                            color: theme.colorTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Time shown on the block itself, not just inside the
                      // tap sheet — requested directly ("we need time in
                      // front of the important tasks on list view"),
                      // matching TaskCapsuleBlock's own always-visible time
                      // line so a real Amble task and an external event
                      // read the same way at a glance.
                      Text(
                        '${TimeOfDay.fromDateTime(event.start).format(context)} – '
                        '${TimeOfDay.fromDateTime(event.end).format(context)}',
                        style: theme.textCaption.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        event.title,
                        style: theme.textCaption.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The tap-for-info read-only sheet every [ExternalCalendarEvent] display
/// site shows — title/time/source calendar only, no edit/complete/drag/
/// delete, per CONSTITUTION.md's "Calendar" section. Extracted to a
/// top-level function (not left as [ExternalEventBlock]'s own private
/// method) so `_ZoneExternalEventRow` (`zone_container_block.dart`, the
/// in-zone-container read-only row) can show the exact same sheet rather
/// than a duplicated copy.
void showExternalCalendarEventInfo({
  required BuildContext context,
  required AmbleTheme theme,
  required ExternalCalendarEvent event,
}) {
  AppSheet.show(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(event.title, style: theme.textTitle),
        SizedBox(height: theme.spacingSm),
        Text(
          '${TimeOfDay.fromDateTime(event.start).format(context)} – '
          '${TimeOfDay.fromDateTime(event.end).format(context)}',
          style: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
        if (event.sourceCalendarName != null) ...[
          SizedBox(height: theme.spacingXs),
          Text(
            event.sourceCalendarName!,
            style: theme.textCaption.copyWith(color: theme.colorTextSecondary),
          ),
        ],
      ],
    ),
  );
}
