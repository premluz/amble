// Headlines (word-staggered rise, Apple-style) and the film's day clock,
// which borrows the app's own "now" marker: dot, line, time.
(function (F) {
  const { M, dom } = F;
  const blocks = [];
  const WORD_STAGGER = 0.14;
  const IN_SECONDS = 1.0;
  const OUT_SECONDS = 0.45;
  let clock = null;

  function make(lines, cls) {
    const node = dom.el('div', `copy-block ${cls}`, F.stage.copy);
    const words = [];
    for (const line of [].concat(lines)) {
      const ln = dom.el('span', 'ln', node);
      const parts = line.split(' ');
      parts.forEach((word, i) => {
        words.push(dom.el('span', 'wd', ln, word));
        if (i < parts.length - 1) ln.appendChild(document.createTextNode(' '));
      });
    }
    const block = { node, words };
    blocks.push(block);
    return block;
  }

  // p: entrance progress (0..1), out: exit progress (0..1).
  function place(block, pos, p, out = 0) {
    const visible = p > 0 && out < 1;
    dom.show(block.node, visible);
    if (!visible) return;
    block.node.classList.toggle('on-dark', Boolean(pos.dark));
    const leave = M.ease.film(out);
    dom.vars(block.node, {
      x: dom.px(pos.x),
      y: dom.px(pos.y),
      w: dom.px(pos.w || 760),
      align: pos.align || 'left',
      o: String(1 - M.ease.inOutSine(out)),
      dy: dom.px(-14 * leave),
    });
    const n = block.words.length;
    block.words.forEach((word, i) => {
      const local = M.clamp(p * (1 + WORD_STAGGER * (n - 1)) - WORD_STAGGER * i);
      const e = M.ease.film(local);
      dom.vars(word, { wo: String(e), wy: dom.px((1 - e) * 30), wb: dom.px((1 - e) * 8) });
    });
  }

  // In from `a`, out ending at `b` (film-local seconds).
  function timed(block, pos, t, a, b) {
    place(block, pos, M.span(t, a, a + IN_SECONDS), M.span(t, b - OUT_SECONDS, b));
  }

  function buildClock() {
    clock = dom.el('div', 'film-clock', F.stage.node);
    dom.el('i', '', clock);
    dom.el('s', '', clock);
    clock.label = dom.el('span', '', clock);
  }

  function showClock(t, opacity, dark = false) {
    dom.show(clock, opacity > 0);
    dom.set(clock, 'o', String(opacity));
    dom.set(clock, 'clock', dark ? 'var(--f-on-dark-muted)' : 'var(--f-faint)');
    dom.text(clock.label, dom.filmClock(F.clockAt(t)));
  }

  function build() {
    buildClock();
    F.onReset(() => {
      for (const block of blocks) dom.show(block.node, false);
      dom.show(clock, false);
    });
  }

  F.copy = { build, make, place, timed, clock: showClock };
})((window.Film = window.Film || {}));
