// 0:54 Evening. The sky goes to dusk and night, the phone follows into dark
// mode; then the three starred pills leave the screen and become the mark.
(function (F) {
  const { M, D, S } = F;
  const LIFT = 4.6;
  const SCROLL = 540;
  const PPM = 1;
  const RAIL_CENTER = 130;
  const STARRED = D.tasks.filter((task) => task.star);
  let ui = null;

  function build() {
    ui = {
      change: F.copy.make(D.copy.change, 't-hero'),
      letThem: F.copy.make(D.copy.letThem, 't-hero'),
      word: F.copy.make(D.product, 't-word'),
      tagline: F.copy.make(D.copy.tagline, 't-sub'),
    };
    F.mark.build();
  }

  // Each starred pill's centre and straight length on stage, resting camera.
  function froms() {
    const starts = S.pushed(1);
    return STARRED.map((task) => {
      const start = (starts[task.id] || {}).start ?? task.start;
      const h = Math.max(task.dur * PPM, 24);
      const screenY = 150 + (start - SCROLL) * PPM + h / 2;
      const p = F.phone.focus(RAIL_CENTER, screenY, 0, 0, 1);
      return { x: S.CAM.x - p.x, y: S.CAM.y - p.y, len: h - 24 };
    });
  }

  function phone(t, ft) {
    const sink = M.ease.inOutCubic(M.span(t, LIFT, LIFT + 1.2));
    const cam = { ...S.CAM, y: S.CAM.y + 140 * sink, s: 1 - 0.06 * sink, o: 1 - M.span(t, LIFT + 0.1, LIFT + 1.0) };
    S.shell(ft, 'days', cam, M.ease.inOutSine(M.span(t, 1.2, 2.6)));
    const tasks = S.pushed(1);
    for (const task of D.tasks) {
      const lifted = task.star && t >= LIFT;
      tasks[task.id] = { ...(tasks[task.id] || {}), done: 1, fall: task.star ? 0 : 1, railO: lifted ? 0 : 1 };
    }
    F.day.render({ scroll: SCROLL, ppm: PPM, now: F.clockAt(ft), tasks, wm: 1, zones: 1 });
    S.dayDock({ star: 1 });
  }

  function skies(t) {
    const dusk = M.span(t, 0.2, 1.8);
    F.ui.stage.sky('paper', 1 - dusk);
    F.ui.stage.sky('dusk', dusk * (1 - M.span(t, 2.4, 4.2)));
    F.ui.stage.sky('night', M.span(t, 2.4, 4.2));
  }

  function render(t, ft) {
    skies(t);
    if (t < LIFT + 1.0) {
      phone(t, ft);
      S.cut(t, 'close', { outbound: false });
    }
    F.mark.render(froms(), LIFT, t);
    const dark = t > 0.9;
    F.copy.timed(ui.change, { ...S.COPY, y: 400, dark }, t, 0.9, LIFT);
    F.copy.timed(ui.letThem, { ...S.COPY, y: 505, dark }, t, 2.3, LIFT);
    F.copy.timed(ui.word, { x: 868, y: 430, w: 760, dark: true }, t, LIFT + 1.5, 99);
    F.copy.timed(ui.tagline, { x: 0, y: 664, w: 1920, align: 'center', dark: true }, t, LIFT + 2.3, 99);
    F.copy.clock(ft, 1 - M.span(t, 4.1, 4.5), dark);
  }

  F.onBuild(build);
  F.register('close', render);
})((window.Film = window.Film || {}));
