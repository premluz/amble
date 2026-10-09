// 0:28 Zones. Morning, Work and Evening settle in behind the tasks; then the
// dock's Timeline | List switch slides the same day into its zone cards.
(function (F) {
  const { M, D, S } = F;
  const SWITCH_AT = 2.5;
  let title = null;
  let sub = null;

  function build() {
    title = F.copy.make(D.copy.zones, 't-hero');
    sub = F.copy.make(D.copy.zonesSub, 't-sub');
  }

  function render(t, ft) {
    F.ui.stage.sky('paper', 1);
    S.shell(ft, 'days');
    const since = t - SWITCH_AT;
    const slide = M.ease.standard(M.span(since, 0, 0.5));
    const now = F.clockAt(ft);
    F.day.render({
      scroll: 380, now, tasks: S.pushed(1),
      zones: M.ease.inOutSine(M.span(t, 0.5, 1.8)), vx: -390 * slide,
    });
    if (since > 0) {
      F.list.render({ vx: 390 * (1 - slide), now, tasks: S.pushed(1), follow: { t: since } });
    }
    S.dayDock({ toList: since > 0 ? 1 : 0, switchT: since });
    const tap = S.tap(t, SWITCH_AT - 0.12, 0.16);
    F.phone.touch(75, 778, tap.o, tap.press);
    F.copy.timed(title, { ...S.COPY, y: 470 }, t, 0.2, 5.45);
    F.copy.timed(sub, { ...S.COPY, y: 582 }, t, 0.7, 5.45);
    S.cut(t, 'zones');
    F.copy.clock(ft, 1);
  }

  F.onBuild(build);
  F.register('zones', render);
})((window.Film = window.Film || {}));
