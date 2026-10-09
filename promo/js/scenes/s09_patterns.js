// 0:50 Patterns. The week's dots: today's run and reading fill in, with the
// same completion squeeze the task pills use. No streak counter anywhere.
(function (F) {
  const { M, D, S } = F;
  const FILLED_LONG_AGO = 9;
  const COMPLETES = [1.0, 1.45];
  let title = null;
  let sub = null;

  function build() {
    title = F.copy.make(D.copy.patterns, 't-hero');
    sub = F.copy.make(D.copy.patternsSub, 't-sub');
  }

  function fills(t) {
    return D.habits.map((habit, h) =>
      habit.days.map((state) => {
        if (state === 1) return FILLED_LONG_AGO;
        if (state === 2) return t - COMPLETES[h];
        return null;
      }));
  }

  function render(t, ft) {
    F.ui.stage.sky('paper', 1);
    S.shell(ft, 'patterns', { ...S.CAM, s: 1 + 0.03 * M.ease.inOutSine(M.span(t, 0, 4.2)) });
    F.patterns.render(fills(t));
    F.copy.timed(title, { ...S.COPY, y: 470 }, t, 0.2, 3.95);
    F.copy.timed(sub, { ...S.COPY, y: 582 }, t, 0.6, 3.95);
    S.cut(t, 'patterns');
    F.copy.clock(ft, 1);
  }

  F.onBuild(build);
  F.register('patterns', render);
})((window.Film = window.Film || {}));
