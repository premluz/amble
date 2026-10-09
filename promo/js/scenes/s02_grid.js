// 0:06 The problem. A conventional calendar fills up, one meeting runs long,
// columns squeeze, conflicts pile up, and then the grid turns liquid.
(function (F) {
  const { M, D, dom, S } = F;
  const G = S.GRID;
  const BLOCKS = [
    { id: 'standup', title: 'Standup', start: 540, dur: 30, c: 'blue', at: 0.7 },
    { id: 'deck', title: 'Launch deck', start: 570, dur: 90, c: 'violet', at: 0.85 },
    { id: 'ana', title: 'Call with Ana', start: 660, dur: 30, c: 'green', at: 1.0 },
    { id: 'lunch', title: 'Lunch with Sam', start: 690, dur: 60, c: 'orange', at: 1.15 },
    { id: 'dentist', title: 'Dentist', start: 810, dur: 30, c: 'green', at: 1.3 },
    { id: 'client', title: 'Client call', start: 675, dur: 45, c: 'red', at: 4.4 },
  ];
  // [col, cols] per phase: one column, then two, then three.
  const PHASES = [
    { at: 0, slots: {} },
    { at: 3.2, slots: { deck: [0, 2], ana: [1, 2], lunch: [1, 2] } },
    { at: 4.4, slots: { deck: [0, 3], client: [1, 3], ana: [2, 3], lunch: [2, 3] } },
  ];
  const CONFLICTED = ['deck', 'client', 'ana', 'lunch'];
  let ui = null;

  function build() {
    const root = dom.el('div', 'grid-scene', F.stage.back);
    const bg = dom.el('div', 'g-bg', root);
    const svg = dom.svg('svg', { class: 'g-rules', width: 1920, height: 1080 }, root);
    const rules = Array.from({ length: 6 }, () => dom.svg('path', {}, svg));
    const hours = Array.from({ length: 6 }, (_, i) => dom.el('div', 'g-hour', root, `${G.first + i}:00`));
    const blocks = {};
    for (const block of BLOCKS) {
      const node = dom.el('div', 'gblock', root);
      dom.set(node, 'c', `var(--g-${block.c})`);
      dom.el('b', '', node, block.title);
      node.time = dom.el('span', '', node);
      blocks[block.id] = node;
    }
    const badge = dom.el('div', 'gbadge', root, '3 conflicts');
    ui = {
      root, bg, svg, rules, hours, blocks, badge,
      happens: F.copy.make(D.copy.happens, 't-hero'),
      problem: F.copy.make(D.copy.problem, 't-hero'),
    };
    F.onReset(() => dom.show(root, false));
  }

  const hm = (min) => `${Math.floor(min / 60)}:${String(min % 60).padStart(2, '0')}`;

  function slot(id, t) {
    let geo = null;
    for (const phase of PHASES) {
      const [col, cols] = phase.slots[id] || [0, 1];
      const w = (G.x1 - G.x0 - 8) / cols;
      const next = { x: G.x0 + 8 + col * w, w: w - 8 };
      const p = geo ? M.ease.standard(M.span(t, phase.at, phase.at + 0.35)) : 1;
      geo = geo ? { x: M.lerp(geo.x, next.x, p), w: M.lerp(geo.w, next.w, p) } : next;
    }
    return geo;
  }

  function paintBlock(block, t, melt) {
    const node = ui.blocks[block.id];
    const appear = M.spring(t - block.at, 0.55, 0.3);
    const dur = block.id === 'deck' ? block.dur + 50 * M.spring(t - 2.6, 0.7, 0.2) : block.dur;
    const geo = slot(block.id, t);
    const y = S.gridY(block.start);
    const alarm = CONFLICTED.includes(block.id) && t > 5.2 ? 2 + Math.sin((t - 5.2) * 9) : 0;
    const toPhone = M.ease.inOutCubic(melt);
    dom.show(node, t > block.at);
    dom.vars(node, {
      x: dom.px(geo.x), y: dom.px(y), w: dom.px(geo.w), h: dom.px((dur / 60) * G.hour - 6),
      o: String(M.clamp(appear * 1.4) * (1 - toPhone)), dy: dom.px((1 - appear) * -26),
      tx: dom.px((1330 - geo.x - geo.w / 2) * toPhone * 0.6), s: String(1 - 0.5 * toPhone),
      r: dom.px(10 + 30 * toPhone), alarm: dom.px(alarm),
    });
    dom.text(node.time, `${hm(block.start)} – ${hm(block.start + Math.round(dur / 5) * 5)}`);
  }

  function paintRules(t, wave) {
    ui.rules.forEach((path, i) => {
      const y = G.y0 + i * G.hour;
      const draw = M.ease.film(M.span(t, 0.05 * i, 0.6 + 0.05 * i));
      const x1 = M.lerp(G.x0, G.x1, draw);
      let d = `M${G.x0} ${y}`;
      for (let k = 1; k <= 40; k++) {
        const x = M.lerp(G.x0, x1, k / 40);
        d += ` L${x.toFixed(1)} ${(y + wave * 38 * Math.sin(x / 120 + i * 1.3 + t * 3)).toFixed(1)}`;
      }
      dom.attr(path, 'd', d);
      dom.vars(ui.hours[i], { y: dom.px(y), o: String(draw * (1 - wave)) });
    });
  }

  function render(t, ft) {
    dom.show(ui.root, true);
    const wave = M.ease.inOutSine(M.span(t, 8.3, 9.3));
    const melt = M.span(t, 8.5, 9.4);
    const shake = t > 6 ? 9 * Math.exp(-6 * (t - 6)) * Math.sin(40 * (t - 6)) : 0;
    dom.vars(ui.root, { shx: dom.px(shake), o: String(1 - M.span(t, 9.1, 9.6)) });
    dom.set(ui.bg, 'bo', String(M.span(t, 0, 0.6) * (1 - M.span(t, 8.7, 9.5))));
    dom.set(ui.svg, 'ro', String(1 - M.span(t, 9.0, 9.5)));
    paintRules(t, wave);
    for (const block of BLOCKS) paintBlock(block, t, melt);
    const pop = M.spring(t - 5.2, 0.5, 0.45);
    dom.vars(ui.badge, { o: String(M.clamp(pop * 2) * (1 - melt)), s: String(0.6 + 0.4 * pop) });
    F.copy.timed(ui.happens, { ...S.COPY, w: 640 }, t, 0.5, 4.8);
    F.copy.timed(ui.problem, { ...S.COPY, y: 396, w: 660 }, t, 5.0, 9.4);
    F.copy.clock(ft, M.span(t, 0.2, 0.8) * (1 - M.span(t, 9.0, 9.6)));
  }

  F.onBuild(build);
  F.register('grid', render);
})((window.Film = window.Film || {}));
