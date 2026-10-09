// Day page, spatial Timeline. Scenes pass a state object; every frame is laid
// out from it (minutes → px at `ppm`, relative to the viewport top `scroll`).
(function (F) {
  const { M, D, dom } = F;
  const STAR_PATH =
    'M12 17.27l4.15 2.51c.76.46 1.69-.22 1.49-1.08l-1.1-4.72 3.67-3.18c.67-.58.31-1.68-.57-1.75l-4.83-.41-1.89-4.46c-.34-.81-1.5-.81-1.84 0L9.19 8.63l-4.83.41c-.88.07-1.24 1.17-.57 1.75l3.67 3.18-1.1 4.72c-.2.86.73 1.54 1.49 1.08l4.15-2.5z';
  const VIEWPORT = 694;
  const BADGE = 24;
  let ui = null;

  function star(parent, cls) {
    const svg = dom.svg('svg', { class: cls, viewBox: '0 0 24 24' }, parent);
    dom.svg('path', { d: STAR_PATH, class: 'star-shape' }, svg);
    return svg;
  }

  function buildRow(parent, task, ghost = false) {
    const row = dom.el('div', 'task', parent);
    const card = dom.el('div', 'card', row);
    const rail = dom.el('div', 'rail', row);
    const icon = D.categories[task.cat].icon;
    const glyph = dom.el('div', 'glyph', rail);
    if (icon && !ghost) dom.icon(icon, glyph);
    const starNode = task.star && !ghost ? star(rail, 'star') : null;
    dom.el('div', 'hdot top', rail);
    dom.el('div', 'hdot bottom', rail);
    const title = ghost ? null : dom.el('div', 'title', row, task.title);
    const when = ghost ? null : dom.el('div', 'when', row);
    return { row, card, rail, starNode, title, when, task };
  }

  // TaskImportantStar's gradient: softened primary text easing into accent.
  function starGradient(parent) {
    const holder = dom.svg('svg', { class: 'defs', width: 0, height: 0 }, parent);
    const defs = dom.svg('defs', {}, holder);
    const grad = dom.svg('linearGradient', { id: 'amble-star', x1: 0, y1: 0, x2: 1, y2: 1 }, defs);
    dom.svg('stop', { offset: 0, class: 'star-a' }, grad);
    dom.svg('stop', { offset: 1, class: 'star-b' }, grad);
  }

  function build() {
    const page = F.phone.pages.days;
    starGradient(F.phone.screen);
    const date = dom.el('div', 'date-row', page);
    dom.el('span', '', date, D.date);
    dom.icon('chevronDown', date);
    dom.el('div', 'grip', page);
    const tl = dom.el('div', 'tl', page);
    const glow = dom.el('div', 'wm-glow', tl);
    const body = dom.el('div', 'tl-body', tl);
    const hours = Array.from({ length: 25 }, (_, h) => dom.el('div', 'hour', body, dom.clockText(h * 60)));
    const zones = D.zones.map((zone) => {
      const band = dom.el('div', 'zone-band', body);
      band.label = dom.el('div', 'zlabel', band, zone.title);
      return band;
    });
    // The now line paints under the pills, as on the Timeline.
    const now = dom.el('div', 'now', body);
    now.label = dom.el('b', '', now);
    dom.el('i', '', now);
    dom.el('s', '', now);
    const deck = D.tasks.find((task) => task.id === 'deck');
    const ghost = buildRow(body, deck, true);
    const rows = Object.fromEntries(D.tasks.map((task) => [task.id, buildRow(body, task)]));
    const edges = [0, 1].map(() => dom.el('div', 'edge', body));
    ui = { tl, glow, body, hours, zones, ghost, rows, now, edges };
    F.onReset(() => dom.show(body, false));
  }

  const fillFor = (cat, done) =>
    `color-mix(in srgb, var(--cat-${cat}) ${Math.round(100 - 72 * done)}%, var(--a-base))`;

  function paintRow(view, s, y, ppm) {
    const { task } = view;
    const done = s.done ?? (task.done ? 1 : 0);
    const fall = s.fall || 0;
    const h = Math.max(s.dur * ppm, BADGE);
    dom.show(view.row, !s.hidden && y > -h - 40 && y < VIEWPORT + 40);
    dom.vars(view.row, {
      y: dom.px(y), h: dom.px(h), o: String((s.o ?? 1) * (1 - fall)),
      fy: dom.px(40 * fall * fall), fs: String(1 - 0.025 * fall), lift: String(s.lift || 0),
    });
    const pulse = s.pulse || { sx: 1, sy: 1 };
    dom.vars(view.rail, {
      fill: fillFor(task.cat, done), sx: String(pulse.sx), sy: String(pulse.sy),
      glyph: done < 0.5 ? 'var(--glyph-on-dark)' : 'color-mix(in srgb, var(--a-text) 25%, transparent)',
      hd: String(s.arm || 0), ro: String(s.railO ?? 1),
    });
    view.rail.dataset.sel = s.sel ? '1' : '0';
    // The primary (selected or lifted) task paints above its neighbours.
    view.row.dataset.top = s.sel || s.lift > 0 ? '1' : '0';
    if (view.starNode) dom.set(view.starNode, 'so', String(done < 0.5 ? 1 : 0.42));
    if (!view.title) return;
    const base = task.star ? 'var(--a-important)' : 'var(--a-text)';
    dom.vars(view.title, {
      tx: dom.px(M.lerp(166, 150, s.lift || 0)),
      title: done < 0.5 ? base : 'var(--a-done-title)',
      strike: done < 0.5 ? 'none' : 'line-through',
      to: String(1 - 0.35 * Math.sin(Math.PI * done)),
    });
    const end = s.start + s.dur;
    dom.text(view.when, `${dom.timeText(s.start)} - ${dom.timeText(end)} (${dom.durationText(s.dur)})`);
  }

  function paintZones(state, y0) {
    D.zones.forEach((zone, i) => {
      const band = ui.zones[i];
      const o = M.clamp((state.zones || 0) * 1.6 - i * 0.3);
      dom.show(band, o > 0);
      const y = y0(zone.start);
      const h = (zone.end - zone.start) * state.ppm;
      const top = Math.max(y, 0);
      const bottom = Math.min(y + h, VIEWPORT - 90);
      dom.vars(band, { y: dom.px(y), h: dom.px(h), o: String(o), ly: dom.px((top + bottom) / 2 - y) });
    });
  }

  function paintHoursAndNow(state, y0) {
    const nowY = state.now == null ? null : y0(state.now);
    ui.hours.forEach((node, h) => {
      const y = y0(h * 60);
      const near = nowY !== null && Math.abs(y - nowY) < 16;
      dom.vars(node, { y: dom.px(y), o: near || y < -20 || y > VIEWPORT ? '0' : '1' });
    });
    dom.show(ui.now, nowY !== null);
    if (nowY === null) return;
    dom.set(ui.now, 'y', dom.px(nowY));
    dom.text(ui.now.label, dom.clockText(state.now));
  }

  function paintEdges(state, y0) {
    ui.edges.forEach((node, i) => {
      const edge = (state.edges || [])[i];
      dom.show(node, Boolean(edge && edge.o > 0));
      if (!edge) return;
      dom.vars(node, { y: dom.px(y0(edge.min)), o: String(edge.o) });
      dom.text(node, dom.clockText(edge.min));
    });
  }

  function render(state) {
    const ppm = state.ppm || 1.5;
    const y0 = (min) => (min - state.scroll) * ppm;
    dom.show(ui.body, true);
    dom.set(ui.body, 'vx', dom.px(state.vx || 0));
    dom.set(ui.glow, 'wm', String(state.wm || 0));
    paintZones({ ...state, ppm }, y0);
    paintHoursAndNow(state, y0);
    for (const task of D.tasks) {
      const s = { start: task.start, dur: task.dur, ...(state.tasks || {})[task.id] };
      paintRow(ui.rows[task.id], s, y0(s.start), ppm);
    }
    const ghost = state.ghost;
    dom.show(ui.ghost.row, Boolean(ghost));
    if (ghost) paintRow(ui.ghost, { start: ghost.start, dur: ghost.dur, railO: 0.2 }, y0(ghost.start), ppm);
    paintEdges(state, y0);
  }

  F.day = { build, render, star };
})((window.Film = window.Film || {}));
