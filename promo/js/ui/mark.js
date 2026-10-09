// The ≋ mark drawn from task pills. Each pill is a round-capped stroke that
// swings from vertical to horizontal, stretches, and bends into one wave of
// assets/branding/Logo_on_light.svg (centred, in logo units).
(function (F) {
  const { M, dom } = F;
  const WAVE = [[-42.467, 0.618], [-14.103, 10.948], [8.825, -8.044], [42.467, -0.618]];
  const HALF = 42.467;
  const STROKE = 10.9422;
  const GAP = 27.65;
  const SCALE = 3;
  const CENTER = { x: 685, y: 520 };
  let ui = null;

  function build() {
    const svg = dom.svg('svg', { class: 'mark-svg', width: 1920, height: 1080, viewBox: '0 0 1920 1080' }, F.stage.front);
    const paths = [1, 2, 3].map((k) => {
      const path = dom.svg('path', {}, svg);
      dom.vars(path, { to: `var(--mark-${k})`, from: `var(--pill-from-${k})` });
      return path;
    });
    ui = { svg, paths };
    F.onReset(() => dom.show(svg, false));
  }

  function pathFor(from, k, p) {
    const len = M.lerp(from.len, 2 * HALF * SCALE, p.travel);
    const angle = M.lerp(Math.PI / 2, 0, p.travel);
    const cx = M.lerp(from.x, CENTER.x, p.travel);
    const cy = M.lerp(from.y, CENTER.y + (k - 1) * GAP * SCALE, p.travel);
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);
    const pts = WAVE.map(([wx, wy], i) => {
      const x = M.lerp((-0.5 + i / 3) * len, (wx / HALF) * (len / 2), p.bend);
      const y = p.bend * (wy / HALF) * (len / 2);
      return `${(cx + x * cos - y * sin).toFixed(2)} ${(cy + x * sin + y * cos).toFixed(2)}`;
    });
    return `M${pts[0]} C${pts[1]} ${pts[2]} ${pts[3]}`;
  }

  // froms: where each pill sits on stage at lift-off ({x, y, len}).
  function render(froms, liftAt, t) {
    dom.show(ui.svg, t >= liftAt);
    ui.paths.forEach((path, k) => {
      const at = liftAt + 0.12 * k;
      const p = {
        travel: M.spring(t - at, 1.15, 0.16),
        bend: M.ease.inOutCubic(M.span(t, at + 0.5, at + 1.5)),
      };
      const tone = Math.round(100 * M.span(t, at + 0.15, at + 1.15));
      const glow = 18 * Math.sin(Math.PI * M.span(t, at, at + 1.6));
      dom.attr(path, 'd', pathFor(froms[k], k, p));
      dom.vars(path, {
        sw: dom.px(M.lerp(24, STROKE * SCALE, Math.min(1, p.travel))),
        mix: `${tone}%`,
        glow: dom.px(glow),
      });
    });
  }

  F.mark = { build, render };
})((window.Film = window.Film || {}));
