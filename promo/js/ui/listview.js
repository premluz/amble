// List (zone) view: zone cards stacked by time, rows inside, the now marker
// as its own row after every started row. Spacing from the reference render.
(function (F) {
  const { M, D, dom } = F;
  const L = { top: 21, head: 19, first: 56, step: 48, tail: 33, gap: 5, now: 24 };
  const TL_TOP = 150;
  let ui = null;

  function zoneLength(zone) {
    const m = zone.end - zone.start;
    const h = Math.floor(m / 60);
    return `${zone.title} ${h ? `${h}h` : ''}${m % 60 ? ` ${m % 60}m` : ''}`.trim();
  }

  function buildRow(parent, task) {
    const row = dom.el('div', 'lrow', parent);
    const act = dom.el('div', 'swipe-act', row);
    dom.icon('check', act);
    const badge = dom.el('div', 'badge', row);
    const icon = D.categories[task.cat].icon;
    if (icon) dom.icon(icon, badge);
    if (task.star) F.day.star(badge, 'star');
    const title = dom.el('div', 'ltitle', row, task.title);
    const time = dom.el('div', 'lt', parent);
    return { row, act, badge, title, time, task };
  }

  function build() {
    const tl = F.phone.pages.days.querySelector('.tl');
    const list = dom.el('div', 'tl-list', tl);
    const cards = D.zones.map((zone) => {
      const card = dom.el('div', 'zcard', list);
      dom.el('div', 'zhead', card, zoneLength(zone));
      return card;
    });
    const rows = Object.fromEntries(D.tasks.map((task) => [task.id, buildRow(list, task)]));
    const now = dom.el('div', 'now', list);
    now.label = dom.el('b', '', now);
    dom.el('i', '', now);
    dom.el('s', '', now);
    ui = { list, cards, rows, now, screenY: {} };
    F.onReset(() => dom.show(list, false));
  }

  // Screen y of a row's centre as of the last render (for camera framing).
  const rowY = (id) => ui.screenY[id];

  // Rows grouped by the zone whose window contains their start time.
  function layout(starts, nowMin) {
    const items = [];
    let y = L.top;
    D.zones.forEach((zone, zi) => {
      const members = D.tasks
        .filter((t) => starts[t.id] >= zone.start && starts[t.id] < zone.end)
        .sort((a, b) => starts[a.id] - starts[b.id]);
      const top = y;
      let center = top + L.first - L.step;
      members.forEach((task, k) => {
        center += L.step;
        const nowHere = nowMin != null && items.nowY == null && k > 0 && starts[task.id] > nowMin;
        if (nowHere) {
          items.nowY = center - L.step + 36;
          center += L.now;
        }
        items.push({ id: task.id, y: center });
      });
      items.push({ card: zi, y: top, h: center + L.tail - top });
      y = center + L.tail + L.gap;
    });
    return items;
  }

  function paintRow(view, s, y, scroll) {
    const done = s.done ?? (view.task.done ? 1 : 0);
    const fill = `color-mix(in srgb, var(--cat-${view.task.cat}) ${Math.round(100 - 72 * done)}%, var(--a-base))`;
    const pulse = s.pulse || { sx: 1, sy: 1 };
    const swipe = Math.min(0, s.swipe || 0);
    dom.vars(view.row, { y: dom.px(y - scroll), dx: dom.px(swipe + (s.follow || 0)), o: String(s.o ?? 1) });
    dom.vars(view.act, { aw: dom.px(-swipe), arm: String(s.arm ? 1.15 : 1) });
    dom.vars(view.badge, {
      fill, sx: String(pulse.sx), sy: String(pulse.sy),
      glyph: done < 0.5 ? 'var(--glyph-on-dark)' : 'color-mix(in srgb, var(--a-text) 25%, transparent)',
    });
    const base = view.task.star ? 'var(--a-important)' : 'var(--a-text)';
    dom.vars(view.title, {
      title: done < 0.5 ? base : 'var(--a-done-title)',
      strike: done < 0.5 ? 'none' : 'line-through',
    });
    dom.vars(view.time, { y: dom.px(y - scroll), o: String(s.o ?? 1) });
    dom.text(view.time, dom.clockText(s.start));
  }

  function render(state) {
    const over = state.tasks || {};
    const starts = Object.fromEntries(D.tasks.map((t) => [t.id, (over[t.id] || {}).start ?? t.start]));
    const items = layout(starts, state.now);
    const scroll = state.scroll || 0;
    dom.show(ui.list, true);
    dom.set(ui.list, 'vx', dom.px(state.vx || 0));
    items.forEach((item, i) => {
      const follow = state.follow ? (1 - M.spring(state.follow.t - 0.03 * i, 0.55, 0.25)) * 28 : 0;
      if (item.card != null) {
        dom.vars(ui.cards[item.card], { y: dom.px(item.y - scroll), h: dom.px(item.h) });
        return;
      }
      const s = { start: starts[item.id], ...over[item.id], follow };
      paintRow(ui.rows[item.id], s, item.y, scroll);
      ui.screenY[item.id] = TL_TOP + item.y - scroll;
    });
    dom.show(ui.now, items.nowY != null);
    if (items.nowY == null) return;
    dom.set(ui.now, 'y', dom.px(items.nowY - scroll));
    dom.text(ui.now.label, dom.clockText(state.now));
  }

  F.list = { build, render, rowY };
})((window.Film = window.Film || {}));
