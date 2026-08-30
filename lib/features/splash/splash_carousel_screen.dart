import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../shared/providers/preferences_providers.dart';

/// First-launch acquisition screen: a brief splash, then a swipeable
/// value-proposition carousel, then a CTA that routes straight into the
/// real app. Shown once — [HasSeenSplash] gates whether `main.dart` routes
/// here at all; this screen itself doesn't re-check that flag, it just
/// marks it seen when the CTA is pressed.
///
/// **Placeholder content**, flagged per the work order rather than treated
/// as final: the logo is a live-drawn version of the same diagonal
/// line-and-dot mark used for the Phase 9 placeholder app icon (see
/// docs/DECISIONS.md), not a new asset. The carousel copy in
/// [_slides] is draft value-proposition text for review, not signed off.
///
/// No onboarding logic lives here — the CTA on the final slide goes
/// directly to [onFinished] (wired to the real app in `main.dart`), per
/// docs/SCOPE.md's explicit sequencing of splash/carousel before
/// onboarding.
class SplashCarouselScreen extends ConsumerStatefulWidget {
  const SplashCarouselScreen({super.key, required this.onFinished});

  /// Called after the "seen" preference is persisted (see [_finish]), in
  /// case a caller needs to do something in addition to that write —
  /// `main.dart`'s real usage needs nothing further, since it watches
  /// [hasSeenSplashProvider] and rebuilds to `AmbleHome` automatically
  /// once the flag flips, but a dev scaffold might want to observe the
  /// CTA firing without depending on that rebuild.
  final VoidCallback onFinished;

  @override
  ConsumerState<SplashCarouselScreen> createState() =>
      _SplashCarouselScreenState();
}

class _SplashCarouselScreenState extends ConsumerState<SplashCarouselScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _showingSplash = true;
  Timer? _splashTimer;

  static const _splashDuration = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    // Timer, not Future.delayed — a bare delayed Future has no cancelable
    // handle, so it fires its callback (harmlessly, given the `mounted`
    // guard) even after this widget is gone. flutter_test's
    // AutomatedTestWidgetsFlutterBinding actively asserts no timer is left
    // pending when a test's widget tree is torn down, which a bare
    // Future.delayed can't satisfy — cancel() in dispose() below is what
    // makes that assertion pass.
    _splashTimer = Timer(_splashDuration, () {
      if (mounted) setState(() => _showingSplash = false);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(hasSeenSplashProvider.notifier).markSeen();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Container(
      color: theme.colorSurfacePrimary,
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: theme.motionNormal,
          child: _showingSplash
              ? _SplashLogo(key: const ValueKey('splash'), theme: theme)
              : _Carousel(
                  key: const ValueKey('carousel'),
                  theme: theme,
                  controller: _pageController,
                  page: _page,
                  onPageChanged: (page) => setState(() => _page = page),
                  onFinish: _finish,
                ),
        ),
      ),
    );
  }
}

/// The splash mark shown briefly before the carousel — see the class doc
/// on [SplashCarouselScreen] for why this is a placeholder, not final
/// branding.
class _SplashLogo extends StatelessWidget {
  const _SplashLogo({super.key, required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrandMark(theme: theme, size: theme.spacingXl * 3),
          SizedBox(height: theme.spacingLg),
          Text('Amble', style: theme.textHeadline),
        ],
      ),
    );
  }
}

/// Live-drawn version of the same diagonal line-and-dot mark used for the
/// placeholder app icon (Phase 9) — reused here rather than a new asset,
/// so the splash stays visually consistent with the launcher icon while
/// still being clearly a placeholder pending real branding.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.theme, required this.size});

  final AmbleTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorAccent,
        borderRadius: BorderRadius.circular(theme.radiusXl),
      ),
      child: CustomPaint(
        painter: _BrandMarkPainter(color: theme.colorSurfacePrimary),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = size.shortestSide * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final start = Offset(size.width * 0.28, size.height * 0.72);
    final mid = Offset(size.width * 0.46, size.height * 0.54);
    final end = Offset(size.width * 0.72, size.height * 0.28);

    canvas.drawLine(start, mid, stroke);
    canvas.drawLine(mid, end, stroke);
    canvas.drawCircle(start, size.shortestSide * 0.05, Paint()..color = color);
    canvas.drawCircle(end, size.shortestSide * 0.07, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SlideContent {
  const _SlideContent({
    required this.icon,
    required this.category,
    required this.headline,
    required this.body,
  });

  final IconData icon;

  /// Which category's pastel tint/icon-color pair this slide borrows —
  /// purely for visual variety across slides, no connection to the
  /// user's actual task categories.
  final TaskCategoryToken category;
  final String headline;
  final String body;
}

/// Draft value-proposition copy — flagged as a placeholder for review, not
/// final. Reflects Amble's positioning as established across this build:
/// calm/visual day planning, the plan-is-provisional-not-a-verdict
/// principle, and frictionless capture (CONSTITUTION.md design principles
/// 1 and 2).
const _slides = [
  _SlideContent(
    icon: Icons.calendar_view_day_rounded,
    category: TaskCategoryToken.personal,
    headline: 'See your day, not just your list',
    body:
        'A calm, visual timeline for your day — tasks laid out in time, '
        'not buried in a list.',
  ),
  _SlideContent(
    icon: Icons.inbox_rounded,
    category: TaskCategoryToken.work,
    headline: 'Capture first, plan later',
    body:
        'Jot a thought down in seconds. Decide when it fits in — now, '
        'later, or never — on your own time.',
  ),
  _SlideContent(
    icon: Icons.update_rounded,
    category: TaskCategoryToken.health,
    headline: 'Plans change. That\'s the plan.',
    body:
        'Missed a task? Reschedule it in one drag. Nothing is marked as a '
        'failure — a plan is a guess you\'re allowed to revise.',
  ),
  _SlideContent(
    icon: Icons.lock_outline_rounded,
    category: TaskCategoryToken.admin,
    headline: 'Your data stays yours',
    body:
        'Amble works entirely on your device — no account, no cloud sync '
        'required. Export a backup any time.',
  ),
];

class _Carousel extends StatelessWidget {
  const _Carousel({
    super.key,
    required this.theme,
    required this.controller,
    required this.page,
    required this.onPageChanged,
    required this.onFinish,
  });

  final AmbleTheme theme;
  final PageController controller;
  final int page;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onFinish;

  bool get _isLastSlide => page == _slides.length - 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacingScreenPadding,
        vertical: theme.spacingLg,
      ),
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: controller,
              onPageChanged: onPageChanged,
              children: [
                for (final slide in _slides)
                  _SlideView(theme: theme, slide: slide),
              ],
            ),
          ),
          SizedBox(height: theme.spacingLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _slides.length; i++)
                _PageDot(theme: theme, isActive: i == page),
            ],
          ),
          SizedBox(height: theme.spacingLg),
          AppButton(
            label: _isLastSlide ? 'Get started' : 'Next',
            size: AppButtonSize.large,
            shape: AppButtonShape.pill,
            onPressed: _isLastSlide
                ? onFinish
                : () => controller.nextPage(
                    duration: theme.motionNormal,
                    curve: theme.curveStandard,
                  ),
          ),
          if (!_isLastSlide) ...[
            SizedBox(height: theme.spacingSm),
            AppButton(
              label: 'Skip',
              variant: AppButtonVariant.secondary,
              shape: AppButtonShape.pill,
              onPressed: onFinish,
            ),
          ],
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.theme, required this.slide});

  final AmbleTheme theme;
  final _SlideContent slide;

  @override
  Widget build(BuildContext context) {
    final tint = theme.categoryColors[slide.category]!;
    final iconColor = theme.categoryIconColors[slide.category]!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: theme.spacingXl * 3,
          height: theme.spacingXl * 3,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          child: Icon(
            slide.icon,
            size: theme.spacingXl * 1.5,
            color: iconColor,
          ),
        ),
        SizedBox(height: theme.spacingXl),
        Text(
          slide.headline,
          textAlign: TextAlign.center,
          style: theme.textTitle.copyWith(color: theme.colorTextPrimary),
        ),
        SizedBox(height: theme.spacingSm),
        Text(
          slide.body,
          textAlign: TextAlign.center,
          style: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
      ],
    );
  }
}

class _PageDot extends StatelessWidget {
  const _PageDot({required this.theme, required this.isActive});

  final AmbleTheme theme;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: theme.motionFast,
      curve: theme.curveStandard,
      margin: EdgeInsets.symmetric(horizontal: theme.spacingXs / 2),
      width: isActive ? theme.spacingLg : theme.spacingXs,
      height: theme.spacingXs,
      decoration: BoxDecoration(
        color: isActive ? theme.colorAccent : theme.colorBorder,
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
    );
  }
}
