// Patterns (tracked behaviours): one card per habit, seven day cells for the
// week. Cells are 40 px, 7.67 px apart, inset 16 px inside a 358 px card.
(function (F) {
  const { M, D, dom } = F;
  const CARD_TOP = 177;
  const CARD_STEP = 111;
  const CELL_STEP = 47.67;
  let ui = null;

  function build() {
    const page = F.phone.pages.patterns;
    dom.el('div', 'week', page, D.week);
    const cards = D.habits.map((habit, i) => {
      const card = dom.el('div', 'hcard', page);
      dom.set(card, 'y', dom.px(CARD_TOP + CARD_STEP * i));
      dom.el('b', '', card, habit.title);
      card.cells = habit.days.map((_, d) => {
        const cell = dom.el('i', '', card);
        dom.set(cell, 'x', dom.px(16 + CELL_STEP * d));
        return cell;
      });
      return card;
    });
    ui = { cards };
  }

  // fills[habit][day]: seconds since that cell completed (null = not done).
  function render(fills) {
    D.habits.forEach((habit, h) => {
      ui.cards[h].cells.forEach((cell, d) => {
        const since = fills[h][d];
        const done = since != null && since >= 0;
        const fill = done ? M.ease.standard(M.clamp(since / 0.25)) : 0;
        const pulse = done ? M.pulse(since, M.pulses.complete) : { sx: 1, sy: 1 };
        dom.vars(cell, { fillp: `${Math.round(fill * 100)}%`, sx: String(pulse.sx), sy: String(pulse.sy) });
      });
    });
  }

  F.patterns = { build, render };
})((window.Film = window.Film || {}));
