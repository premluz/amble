// AppContextDock as drawn in the reference renders: glass panes 48 px tall,
// 40 px buttons, centred 24 px above the bottom clearance.
(function (F) {
  const { M, dom } = F;
  const PANES = {
    views: { x: 9, w: 90 },
    edit: { x: 108, w: 48 },
    star: { x: 164, w: 48 },
    mic: { x: 270, w: 48 },
    add: { x: 334, w: 48 },
    close: { x: 334, w: 48 },
    voice: { x: 40, w: 286 },
  };
  const BARS = 24;
  let ui = null;

  function pane(name, cls = '') {
    const node = dom.el('div', `pane ${cls}`.trim(), F.phone.dock);
    dom.vars(node, { x: dom.px(PANES[name].x), w: dom.px(PANES[name].w) });
    return node;
  }

  function button(parent, iconName, bx = 4, cls = '') {
    const node = dom.el('div', `dbtn ${cls}`.trim(), parent);
    dom.icon(iconName, node);
    dom.set(node, 'bx', dom.px(bx));
    return node;
  }

  function build() {
    const views = pane('views');
    const slide = dom.el('div', 'sel-slide', views);
    const timeline = button(views, 'timeline', 4);
    const list = button(views, 'list', 46);
    const star = pane('star');
    const starOff = button(star, 'starOutline', 4, 'lit');
    const starOn = button(star, 'star', 4);
    starOn.dataset.sel = '1';
    const voice = pane('voice');
    const pause = button(voice, 'pause', 4);
    const wave = dom.el('div', 'wave', voice);
    const bars = Array.from({ length: BARS }, () => dom.el('i', '', wave));
    const submit = button(voice, 'arrowUp', 242, 'accent');
    const mic = pane('mic');
    const micBtn = button(mic, 'mic', 4);
    ui = {
      views, slide, timeline, list, star, starOff, starOn, voice, pause, bars, submit, mic, micBtn,
      edit: pane('edit'), add: pane('add', 'solid'), close: pane('close'),
    };
    button(ui.edit, 'edit');
    button(ui.add, 'add');
    button(ui.close, 'close');
    F.onReset(() => {
      for (const key of ['views', 'edit', 'star', 'mic', 'add', 'close', 'voice']) dom.show(ui[key], false);
    });
  }

  function showPane(node, o = 1, s = 1) {
    dom.show(node, o > 0);
    dom.vars(node, { o: String(o), s: String(s) });
  }

  // AppLiquidSlide: the leading edge springs fast, the tail catches up.
  function views({ toList = 0, t = 0, o = 1 }) {
    showPane(ui.views, o);
    const lead = toList ? M.spring(t, 0.3, 0.25) : 1;
    const trail = toList ? M.spring(t, 0.48, 0.15) : 1;
    const left = toList ? 4 + 42 * trail : 4;
    const right = toList ? 44 + 42 * lead : 44;
    dom.vars(ui.slide, { sl: dom.px(left), sw: dom.px(right - left) });
    const onList = toList && t > 0.12;
    ui.timeline.dataset.sel = onList ? '0' : '1';
    ui.list.dataset.sel = onList ? '1' : '0';
  }

  function star({ on = 0, o = 1, s = 1 }) {
    showPane(ui.star, o, s);
    dom.set(ui.starOff, 'bo', String(1 - on));
    dom.set(ui.starOn, 'bo', String(on));
    dom.set(ui.starOff, 'lit', `${Math.round(on * 100)}%`);
  }

  // Voice toolbar morphing out of the mic pane (AppPaneMorph): open 0..1.
  function voice({ open, keysT = 0, level = () => 0, submitPress = 0 }) {
    const from = PANES.mic;
    const to = PANES.voice;
    const w = M.lerp(from.w, to.w, open);
    const x = M.lerp(from.x + from.w, to.x + to.w, open) - w;
    const contentO = M.clamp((open - 0.35) / 0.4);
    showPane(ui.voice, open > 0 ? 1 : 0, 1);
    dom.vars(ui.voice, { x: dom.px(x), w: dom.px(w) });
    dom.set(ui.pause, 'bo', String(contentO));
    dom.set(ui.submit, 'bo', String(contentO));
    dom.set(ui.submit, 'bx', dom.px(w - 44));
    dom.set(ui.submit, 'bs', String(1 - 0.1 * submitPress));
    showPane(ui.mic, open < 0.6 ? 1 - open / 0.6 : 0);
    dom.set(ui.micBtn, 'bo', String(1 - M.clamp(open * 3)));
    waveform(keysT, level, contentO);
  }

  // 24 keys rise left to right on their own springs, then track the level.
  function waveform(keysT, level, opacity) {
    ui.bars.forEach((bar, i) => {
      const key = M.spring(keysT - 0.018 * i, 0.38, 0.55);
      const shape = 0.45 + 0.55 * Math.sin((Math.PI * (i + 0.5)) / BARS);
      const h = 4 + 28 * shape * level(i);
      dom.vars(bar, { k: String(key * opacity), bh: dom.px(h) });
    });
  }

  F.dock = {
    build, views, star, voice,
    edit: (o = 1, s = 1) => showPane(ui.edit, o, s),
    add: (o = 1, s = 1) => showPane(ui.add, o, s),
    mic: (o = 1, s = 1) => showPane(ui.mic, o, s),
    close: (o = 1, s = 1) => showPane(ui.close, o, s),
  };
})((window.Film = window.Film || {}));
