// 0:33 Done. Close on "Call with Ana": swipe left uncovers the check, the
// release squeezes the badge, bubbles rise, hairline rings spread.
(function (F) {
  const { M, D, S } = F;
  const RELEASE = 1.6;
  const SWIPE = -110;
  let headline = null;

  function build() {
    headline = F.copy.make(D.copy.done, 't-hero');
  }

  function swipeAt(t) {
    if (t < RELEASE) return SWIPE * M.ease.standard(M.span(t, 0.95, 1.55));
    return SWIPE * (1 - M.spring(t - RELEASE, 0.35, 0.1));
  }

  function camera(t, rowY) {
    const close = F.phone.focus(210, rowY, 1330, 560, 1.9);
    const zoomIn = M.ease.filmInOut(M.span(t, 0.05, 0.9));
    const zoomOut = M.ease.filmInOut(M.span(t, 3.0, 3.9));
    return S.camLerp(S.camLerp(S.CAM, close, zoomIn), S.CAM, zoomOut);
  }

  function render(t, ft) {
    F.ui.stage.sky('paper', 1);
    const swipe = swipeAt(t);
    const ana = {
      swipe, arm: swipe < -80, done: M.span(t, RELEASE, RELEASE + 0.3),
      pulse: M.pulse(t - RELEASE, M.pulses.complete),
    };
    F.list.render({ now: F.clockAt(ft), tasks: S.merge(S.pushed(1), { ana }) });
    const y = F.list.rowY('ana');
    S.shell(ft, 'days', camera(t, y));
    S.dayDock({ toList: 1, switchT: 9 });
    const finger = S.tap(t, 0.95, RELEASE - 0.95);
    const fingerX = 300 + SWIPE * M.ease.standard(M.span(t, 0.95, 1.55));
    F.phone.touch(fingerX, y, finger.o, finger.press);
    F.fx.bubbles(t - RELEASE, 130, y - 12, 24);
    F.fx.ripple(t - RELEASE, { x: 118, y: y - 12, w: 24, h: 24, r: 12 });
    F.copy.timed(headline, { ...S.COPY, y: 492 }, t, 0.2, 3.95);
    S.cut(t, 'done');
    F.copy.clock(ft, 1);
  }

  F.onBuild(build);
  F.register('done', render);
})((window.Film = window.Film || {}));
