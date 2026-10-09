// 0:00 Dawn. Three dots stretch into lines and flow like a river (the ≋
// mark's colours), then flatten into the rules of a rigid calendar.
(function (F) {
  const { M, D, dom, S } = F;
  const TONES = ['var(--mark-1)', 'var(--mark-2)', 'var(--mark-3)'];
  const FLAT_Y = [S.gridY(600), S.gridY(660), S.gridY(720)];
  let svg = null;
  let paths = [];
  let headline = null;

  function build() {
    svg = dom.svg('svg', { class: 'river', width: 1920, height: 1080, viewBox: '0 0 1920 1080' }, F.stage.back);
    paths = TONES.map(() => dom.svg('path', {}, svg));
    headline = F.copy.make(D.copy.dawn, 't-hero');
    F.onReset(() => dom.show(svg, false));
  }

  // One river line: a slow double sine; `flat` straightens it onto a rule.
  function line(i, t, flat) {
    const base = M.lerp(430 + i * 92, FLAT_Y[i], flat);
    const amp = 52 * (1 - flat);
    const x0 = M.lerp(170 + 46 * i, S.GRID.x0, flat);
    const x1 = M.lerp(2000, S.GRID.x1, flat);
    let d = '';
    let length = 0;
    let prev = null;
    for (let k = 0; k <= 72; k++) {
      const x = M.lerp(x0, x1, k / 72);
      const wave = Math.sin(x / 270 + t * 0.6 + i * 1.7) * (0.62 + 0.38 * Math.sin(x / 640 - t * 0.35 + i));
      const y = base + amp * wave;
      if (prev) length += Math.hypot(x - prev[0], y - prev[1]);
      prev = [x, y];
      d += `${d ? ' L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`;
    }
    return { d, length };
  }

  function paintLine(path, i, t) {
    const flat = M.ease.inOutCubic(M.span(t, 4.7, 6.1));
    const { d, length } = line(i, t, flat);
    const grow = M.ease.film(M.span(t, 0.9 + 0.22 * i, 2.9 + 0.22 * i));
    const dot = M.span(t, 0.25 + 0.22 * i, 0.45 + 0.22 * i);
    const width = M.lerp(20, 2, M.ease.inOutCubic(M.span(t, 5.0, 6.1)));
    const grey = Math.round(100 * M.span(t, 5.2, 6.1));
    dom.attr(path, 'd', d);
    dom.vars(path, {
      len: String(length.toFixed(1)),
      off: String((length * (1 - grow) - (grow > 0 ? 0 : 0.5)).toFixed(1)),
      sw: dom.px(width),
      tone: `color-mix(in oklab, var(--g-line) ${grey}%, ${TONES[i]})`,
      glow: dom.px(16 * (1 - grey / 100)),
      lo: String(dot),
    });
  }

  function render(t, ft) {
    F.ui.stage.sky('dawn', 1 - M.span(t, 5.7, 6.5), { rise: String(M.ease.inOutSine(M.span(t, 0, 6.6))) });
    dom.show(svg, true);
    paths.forEach((path, i) => paintLine(path, i, t));
    F.copy.timed(headline, { x: 0, y: 190, w: 1920, align: 'center', dark: true }, t, 1.2, 5.3);
    F.copy.clock(ft, M.span(t, 0.4, 1.2) * (1 - M.span(t, 5.5, 5.9)), true);
  }

  F.onBuild(build);
  F.register('dawn', render);
})((window.Film = window.Film || {}));
