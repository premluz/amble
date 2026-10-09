// Things (Inbox) and voice mode. Rows sit 48 px apart from y 221; spoken
// lines sit 40 px apart from y 214 and fly into the top of the Inbox.
(function (F) {
  const { M, D, dom } = F;
  const ROW0 = 221;
  const STEP = 48;
  const SEG0 = 214;
  const SEG_STEP = 40;
  let ui = null;

  function row(parent, text, withRing = false) {
    const node = dom.el('div', 'irow', parent);
    const ring = withRing ? dom.el('div', 'iring', node) : null;
    dom.el('div', 'idot', node);
    const label = dom.el('div', 'ititle', node, text);
    return { node, ring, label };
  }

  function build() {
    const page = F.phone.pages.things;
    const tabs = dom.el('div', 'subtabs', page);
    dom.el('b', '', tabs, 'All');
    dom.el('span', '', tabs, 'Unfiled');
    dom.icon('add', tabs);
    const section = dom.el('div', 'isection', page, 'Today');
    const existing = D.inbox.map((text) => row(page, text));
    const arrived = D.spoken.map((text) => row(page, text));
    const voice = dom.el('div', 'voice', F.phone.screen);
    const vpage = dom.el('div', 'v-page', voice);
    const glow = dom.el('div', 'v-glow', voice);
    const hint = dom.el('div', 'v-hint', voice);
    dom.el('small', '', hint, 'Try saying');
    dom.el('strong', '', hint, '“Plan holidays”');
    dom.el('span', '', hint, 'You can add multiple tasks at once.');
    const segs = D.spoken.map(() => row(voice, '', true));
    ui = { page, tabs, section, existing, arrived, voice, vpage, glow, hint, segs };
    F.onReset(() => dom.show(voice, false));
  }

  // AppSweepFade: fade by screen position, bottom first out, top first back.
  function sweep(y, s, returning) {
    const u = y / 844;
    const lead = returning ? u : 1 - u;
    return 1 - M.clamp((s - lead * 0.6) / 0.4);
  }

  function paintInbox(state) {
    const s = state.sweep || 0;
    const back = Boolean(state.returning);
    dom.set(ui.tabs, 'o', String(sweep(119, s, back)));
    dom.set(ui.section, 'o', String(sweep(185, s, back)));
    const room = state.room || 0;
    ui.existing.forEach(({ node }, i) => {
      const y = ROW0 + STEP * (i + D.spoken.length * room);
      dom.vars(node, { y: dom.px(y), o: String(sweep(y, s, back)) });
    });
    ui.arrived.forEach(({ node }, i) => {
      const landed = (state.landed || [])[i] || 0;
      dom.show(node, landed > 0);
      dom.vars(node, { y: dom.px(ROW0 + STEP * i), o: String(landed) });
    });
  }

  function paintSegment({ node, ring, label }, seg, i) {
    dom.show(node, Boolean(seg && seg.o > 0));
    if (!seg) return;
    dom.text(label, seg.text);
    const from = { x: 16, y: SEG0 + SEG_STEP * i };
    const to = { x: 16, y: ROW0 + STEP * i };
    const f = M.ease.standard(seg.flight || 0);
    const depth = seg.flight > 0 ? M.emerge(seg.flight * 0.8) : { scale: 1 };
    dom.vars(node, {
      y: dom.px(M.lerp(from.y, to.y, f)), o: String(seg.o),
      dx: dom.px(M.lerp(from.x, to.x, f) - 16), ds: String(depth.scale),
    });
    dom.vars(ring, { ring: String(seg.ring || 0), rp: `${Math.round((seg.trace || 0) * 100)}%` });
  }

  function paintVoice(v) {
    dom.show(ui.voice, v.open > 0 || (v.segs || []).some((seg) => seg && seg.o > 0));
    dom.set(ui.vpage, 'vp', String(0.92 * M.clamp(v.open * 2)));
    const drift = Math.sin((v.t || 0) * ((2 * Math.PI) / 18)) * 27;
    dom.vars(ui.glow, { vg: String(v.glow), gy: dom.px((1 - v.glow) * 320), drift: dom.px(drift) });
    dom.vars(ui.hint, { o: String(v.hint || 0), s: String(1 - 0.04 * (v.hintOut || 0)) });
    ui.segs.forEach((seg, i) => paintSegment(seg, (v.segs || [])[i], i));
  }

  function render(state) {
    paintInbox(state);
    if (state.voice) paintVoice(state.voice);
  }

  F.things = { build, render };
})((window.Film = window.Film || {}));
