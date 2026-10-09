// 0:15 The answer. Daylight, and the phone rises showing the same day as a
// calm spatial Timeline: "Amble is built for changing one."
(function (F) {
  const { M, D, S } = F;
  let promise = null;

  function build() {
    promise = F.copy.make(D.copy.promise, 't-hero');
  }

  function render(t, ft) {
    F.ui.stage.sky('paper', M.ease.inOutSine(M.span(t, 0, 0.8)));
    const rise = M.spring(t - 0.15, 1.1, 0.16);
    const cam = { x: S.CAM.x, y: M.lerp(1600, S.CAM.y, rise), s: 1, ry: M.lerp(-16, 0, rise) };
    S.shell(ft, 'days', cam);
    F.day.render({ scroll: 520, now: F.clockAt(ft) });
    S.dayDock();
    F.copy.timed(promise, { ...S.COPY, y: 445 }, t, 0.9, 4.95);
    F.copy.clock(ft, 1);
  }

  F.onBuild(build);
  F.register('reveal', render);
})((window.Film = window.Film || {}));
