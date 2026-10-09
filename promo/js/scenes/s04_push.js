// 0:20 Running late. Long-press arms "Launch deck", a drag lifts it 30 min,
// the drop opens the real Overlap / Push all / Trim menu, Push all cascades.
(function (F) {
  const { M, D, S } = F;
  const SCROLL = 520;
  const PPM = 1.5;
  const DECK = D.tasks.find((task) => task.id === 'deck');
  const RAIL_X = 130;
  const GRAB_Y = 150 + (DECK.start - SCROLL) * PPM + 35;
  const DROP = 45;
  const MENU_AT = 3.15;
  const PUSH_AT = 4.45;
  let late = null;
  let push = null;

  function build() {
    late = F.copy.make(D.copy.late, 't-hero');
    push = F.copy.make(D.copy.push, 't-hero');
  }

  function camera(t) {
    const close = F.phone.focus(205, 330, 1330, 560, 1.32);
    const zoomIn = M.ease.filmInOut(M.span(t, 0.5, 1.4));
    const zoomOut = M.ease.filmInOut(M.span(t, 5.0, 6.0));
    return S.camLerp(S.camLerp(S.CAM, close, zoomIn), S.CAM, zoomOut);
  }

  function drag(t) {
    const dy = DROP * M.ease.standard(M.span(t, 2.0, 3.0));
    return { dy, start: DECK.start + Math.round(dy / PPM / 5) * 5 };
  }

  function dayState(t, ft) {
    const d = drag(t);
    const arm = M.span(t, 1.5, 1.65) * (1 - M.span(t, PUSH_AT, PUSH_AT + 0.15));
    const lift = M.span(t, 2.0, 2.15) * (1 - M.span(t, 3.1, 3.25));
    const deck = {
      start: d.start, sel: t >= 1.5 && t < PUSH_AT, arm, lift,
      pulse: M.pulse(t - 1.5, M.pulses.select),
    };
    const cascade = M.ease.standard(M.span(t, PUSH_AT, PUSH_AT + 0.4));
    return {
      scroll: SCROLL, now: F.clockAt(ft),
      tasks: S.merge(S.pushed(cascade), { deck }),
      ghost: t > 2.0 && t < MENU_AT ? { start: DECK.start, dur: DECK.dur } : null,
      edges: [{ min: d.start, o: arm }, { min: d.start + DECK.dur, o: arm }],
    };
  }

  function overlays(t) {
    const hold = S.tap(t, 1.0, 2.1);
    F.phone.touch(RAIL_X, GRAB_Y + drag(t).dy, hold.o, hold.press);
    const anchorY = GRAB_Y + DROP;
    const choose = S.tap(t, 4.15, 0.2);
    if (choose.o > 0) F.phone.touch(RAIL_X, anchorY + 14 + 4 + 48 + 24, choose.o, choose.press);
    F.fx.menu({
      x: RAIL_X, y: anchorY, t: t - MENU_AT,
      out: M.span(t, 4.4, 4.6), hlRow: 1, hlO: M.span(t, 4.15, 4.25),
    });
    F.fx.toast(M.span(t, 4.65, 5.05), M.span(t, 7.3, 7.6));
  }

  function render(t, ft) {
    F.ui.stage.sky('paper', 1);
    S.shell(ft, 'days', camera(t));
    F.day.render(dayState(t, ft));
    S.dayDock();
    overlays(t);
    F.copy.timed(late, { ...S.COPY, y: 492 }, t, 0.2, 4.7);
    F.copy.timed(push, { ...S.COPY, y: 445 }, t, 4.9, 7.95);
    S.cut(t, 'push', { inbound: false });
    F.copy.clock(ft, 1);
  }

  F.onBuild(build);
  F.register('push', render);
})((window.Film = window.Film || {}));
