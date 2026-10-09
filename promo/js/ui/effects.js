// Overlays drawn above the page: the anchored glass menu (Overlap / Push all
// / Trim), the undo toast, completion bubbles + ripple, the What Matters ring.
(function (F) {
  const { M, dom } = F;
  const MENU = { w: 196, h: 152, droplet: 28 };
  const BUBBLES = 6;
  let ui = null;

  function build() {
    const ovl = F.phone.ovl;
    const menu = dom.el('div', 'menu', ovl);
    const rows = dom.el('div', 'rows', menu);
    const hl = dom.el('div', 'hl', rows);
    for (const [icon, label] of [['layers', 'Overlap'], ['arrowForward', 'Push all'], ['cut', 'Trim']]) {
      const row = dom.el('div', 'row', rows);
      dom.icon(icon, row);
      dom.el('span', '', row, label);
    }
    const toast = dom.el('div', 'toast', ovl);
    dom.el('span', '', toast, 'Moved 3 task(s)');
    dom.el('span', 'undo', toast, 'Undo');
    const bubbles = Array.from({ length: BUBBLES }, () => dom.el('div', 'bub', ovl));
    const rings = [0, 1].map(() => dom.el('div', 'ring', ovl));
    const wm = dom.el('div', 'wm-ring', ovl);
    ui = { menu, rows, hl, toast, bubbles, rings, wm };
    F.onReset(() => {
      for (const node of [menu, toast, wm, ...bubbles, ...rings]) dom.show(node, false);
    });
  }

  // AppLiquidMorph.popover from the touch point; the clip never overshoots,
  // the content scale carries the spring's overshoot.
  function menu({ x, y, t, out = 0, hlRow = null, hlO = 0 }) {
    dom.show(ui.menu, t > 0 && out < 1);
    const left = M.clamp(x - MENU.w / 2, 8, 390 - 8 - MENU.w);
    const top = y + 14;
    const w = Math.min(1, M.spring(t, 0.25, 0.4));
    const h = Math.min(1, M.spring(t, 0.32, 0.45));
    const pw = M.lerp(MENU.droplet, MENU.w, w);
    const ph = M.lerp(MENU.droplet, MENU.h, h);
    const pl = M.lerp(x - MENU.droplet / 2, left, w);
    const pt = M.lerp(y - MENU.droplet / 2, top, h);
    dom.vars(ui.menu, {
      mx: dom.px(pl), my: dom.px(pt), mw: dom.px(pw), mh: dom.px(ph),
      mr: dom.px(Math.min(20, ph / 2)), o: String(1 - out),
    });
    dom.vars(ui.rows, {
      rx: dom.px(left - pl), ry: dom.px(top - pt),
      cs: String(M.lerp(0.6, 1, M.spring(t, 0.25, 0.4))), co: String(M.clamp(t / 0.08)),
      ox: dom.px(x - left), oy: '0px',
    });
    dom.vars(ui.hl, { hy: dom.px(4 + 48 * (hlRow ?? 0)), ho: String(hlO) });
  }

  function toast(p, out = 0) {
    dom.show(ui.toast, p > 0 && out < 1);
    const e = M.ease.film(p);
    dom.vars(ui.toast, { o: String(e * (1 - out)), dy: dom.px((1 - e) * 24 + out * 12) });
  }

  const hash = (n) => {
    const s = Math.sin(n * 127.1) * 43758.5453;
    return s - Math.floor(s);
  };

  // BubbleBurstSpec defaults: three lanes, rise ~1.8 pill widths, shrink, fade.
  function bubbles(t, x, y, width) {
    ui.bubbles.forEach((node, k) => {
      const birth = 0.035 * k + 0.25 * hash(k + 1) * 0.65;
      const life = 0.8 * (1 + 0.3 * (hash(k + 7) - 0.5));
      const u = (t - birth) / life;
      dom.show(node, u > 0 && u < 1);
      if (u <= 0 || u >= 1) return;
      const lane = (k % 3) - 1;
      const travel = width * 1.8 * (0.7 + 0.6 * hash(k + 3));
      const d = 2 * width * 0.07 * (0.65 + 0.5 * hash(k + 5)) * (1 - 0.8 * u);
      const bx = x + lane * width * 0.35 + (hash(k + 9) - 0.5) * width * 0.65 * u;
      const fade = Math.min(1, u / 0.1) * (1 - u);
      dom.vars(node, { x: dom.px(bx), y: dom.px(y - travel * M.ease.decel(u)), d: dom.px(d), o: String(fade) });
    });
  }

  // AppWaterRipple: two hairline rings leave the shape's outline.
  function ripple(t, rect) {
    ui.rings.forEach((node, i) => {
      const u = (t - 0.14 * i) / 0.9;
      dom.show(node, u > 0 && u < 1);
      if (u <= 0 || u >= 1) return;
      const spread = 22 * (1 - 0.25 * i) * M.ease.decel(u);
      dom.vars(node, {
        x: dom.px(rect.x - spread), y: dom.px(rect.y - spread),
        w: dom.px(rect.w + spread * 2), h: dom.px(rect.h + spread * 2),
        r: dom.px(rect.r + spread), o: String(0.22 * Math.min(1, u / 0.12) * (1 - u)),
      });
    });
  }

  function wmRing(t, x, y) {
    const u = t / 0.9;
    dom.show(ui.wm, u > 0 && u < 1);
    if (u <= 0 || u >= 1) return;
    const e = M.ease.decel(u);
    dom.vars(ui.wm, { x: dom.px(x), y: dom.px(y), d: dom.px(M.lerp(48, 980, e)), bw: dom.px(M.lerp(3, 0.5, e)), o: String(0.9 * (1 - u)) });
  }

  F.fx = { build, menu, toast, bubbles, ripple, wmRing };
})((window.Film = window.Film || {}));
