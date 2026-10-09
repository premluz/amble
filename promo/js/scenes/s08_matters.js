// 0:44 What Matters. Zoomed out to the whole afternoon; the star in the dock
// lets every unstarred task fall away while a soft glow rises.
(function (F) {
  const { M, D, S } = F;
  const ON = 0.9;
  const STAR = { x: 188, y: 778 };
  const DONE_BY_THREE = ['deck', 'ana', 'lunch', 'dentist'];
  // WhatMattersTokens: 800 ms enter, release between 1/6 and 13/18 of it.
  const ENTER = 0.8;
  let tooMuch = null;
  let matters = null;

  function build() {
    tooMuch = F.copy.make(D.copy.tooMuch, 't-hero');
    matters = F.copy.make(D.copy.matters, 't-hero');
  }

  function tasks(release) {
    const out = S.pushed(1);
    for (const id of DONE_BY_THREE) out[id] = { ...out[id], done: 1 };
    for (const task of D.tasks) {
      if (!task.star) out[task.id] = { ...(out[task.id] || {}), fall: release };
    }
    return out;
  }

  function render(t, ft) {
    F.ui.stage.sky('paper', 1);
    const cam = { ...S.CAM, s: 1 + 0.05 * M.ease.inOutSine(M.span(t, 1.2, 5.7)) };
    S.shell(ft, 'days', cam);
    const u = t - ON;
    const release = M.span(u, ENTER / 6, (ENTER * 13) / 18);
    F.day.render({
      scroll: 550, ppm: 1, now: F.clockAt(ft), tasks: tasks(release), zones: 1,
      wm: M.ease.inOutSine(M.span(u, 0, ENTER)),
    });
    S.dayDock({ star: M.span(u, 0, 0.15) });
    F.fx.wmRing(u, STAR.x, STAR.y);
    const tap = S.tap(t, ON - 0.1, 0.14);
    F.phone.touch(STAR.x, STAR.y, tap.o, tap.press);
    F.copy.timed(tooMuch, { ...S.COPY, y: 492 }, t, 0.2, 1.75);
    F.copy.timed(matters, { ...S.COPY, y: 445 }, t, 1.9, 5.45);
    S.cut(t, 'matters');
    F.copy.clock(ft, 1);
  }

  F.onBuild(build);
  F.register('matters', render);
})((window.Film = window.Film || {}));
