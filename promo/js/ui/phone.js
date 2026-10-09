// The device and the shell chrome around Amble's pages. Screen coordinates
// are the app's logical pixels; the camera maps them onto the 1920×1080 stage.
(function (F) {
  const { dom } = F;
  const SCREEN_INSET = 12;
  const DEVICE_CENTER = { x: 207, y: 434 };
  const TABS = [
    ['days', 'Days'],
    ['things', 'Things'],
    ['patterns', 'Patterns'],
  ];

  function statusIcons(parent) {
    const svg = dom.svg('svg', { width: 77, height: 13, viewBox: '0 0 77 13', fill: 'currentColor' }, parent);
    [3, 5.5, 8, 10.5].forEach((h, i) =>
      dom.svg('rect', { x: i * 5, y: 12 - h, width: 3.2, height: h, rx: 0.8 }, svg));
    const wifi = 'M28 4.2a11 11 0 0 1 15 0l-1.5 1.6a8.8 8.8 0 0 0-12 0Zm3 3.2a6.5 6.5 0 0 1 9 0l-1.6 1.6a4.2 4.2 0 0 0-5.8 0Zm4.5 4.6-2.3-2.3a3.2 3.2 0 0 1 4.6 0Z';
    dom.svg('path', { d: wifi }, svg);
    dom.svg('rect', { x: 49, y: 0.5, width: 24, height: 12, rx: 3.6, fill: 'none', stroke: 'currentColor', 'stroke-opacity': 0.4 }, svg);
    dom.svg('rect', { x: 51, y: 2.5, width: 18, height: 8, rx: 2 }, svg);
    dom.svg('rect', { x: 74.5, y: 4.5, width: 1.6, height: 4, rx: 0.8, 'fill-opacity': 0.4 }, svg);
  }

  function buildChrome(screen) {
    const status = dom.el('div', 'status', screen);
    const time = dom.el('div', 'status-time', status);
    dom.el('div', 'island', status);
    statusIcons(dom.el('div', 'status-icons', status));
    const nav = dom.el('div', 'nav', screen);
    const tabs = {};
    for (const [id, label] of TABS) tabs[id] = dom.el('span', 'tab', nav, label);
    dom.icon('settings', nav, 'gear');
    return { time, tabs };
  }

  function build() {
    const rig = dom.el('div', 'rig', F.stage.rigSlot);
    const device = dom.el('div', 'device', rig);
    dom.el('div', 'device-btn', device);
    dom.el('div', 'device-btn right', device);
    const screen = dom.el('div', 'screen app', device);
    const pages = {};
    for (const [id] of TABS) pages[id] = dom.el('div', `page page-${id}`, screen);
    const chrome = buildChrome(screen);
    const dock = dom.el('div', 'dock', screen);
    const ovl = dom.el('div', 'ovl', screen);
    const touchDot = dom.el('div', 'touch', ovl);
    const veilNode = dom.el('div', 'veil', screen);
    F.phone = {
      rig, screen, pages, dock, ovl, chrome, touchDot, veilNode,
      camera, focus, theme, status, nav, page, touch, veil,
    };
    F.onReset(reset);
  }

  function reset() {
    dom.show(F.phone.rig, false);
    dom.show(F.phone.touchDot, false);
    veil(0);
    for (const id in F.phone.pages) dom.show(F.phone.pages[id], false);
  }

  function veil(opacity) {
    dom.set(F.phone.veilNode, 'veil', String(opacity));
  }

  function camera({ x, y, s = 1, ry = 0, o = 1 }) {
    const rig = F.phone.rig;
    dom.show(rig, o > 0);
    dom.vars(rig, { cx: dom.px(x), cy: dom.px(y), cs: String(s), cry: `${ry}deg`, co: String(o) });
  }

  // Camera that puts screen point (fx, fy) at stage point (X, Y) at scale s.
  function focus(fx, fy, X, Y, s) {
    return {
      x: X - s * (fx + SCREEN_INSET - DEVICE_CENTER.x),
      y: Y - s * (fy + SCREEN_INSET - DEVICE_CENTER.y),
      s,
    };
  }

  function theme(darkMix) {
    dom.set(F.phone.screen, 'dm', `${Math.round(darkMix * 1000) / 10}%`);
  }

  function status(minutes) {
    dom.text(F.phone.chrome.time, dom.statusTime(minutes));
  }

  function nav(selected) {
    for (const id in F.phone.chrome.tabs) {
      F.phone.chrome.tabs[id].dataset.sel = id === selected ? '1' : '0';
    }
  }

  function page(id, offsetX = 0) {
    const node = F.phone.pages[id];
    dom.show(node, true);
    dom.set(node, 'px', dom.px(offsetX));
    nav(id);
  }

  // Touch dot (AppTouchVisualizer): 44 px, text colour at 16% with a ring.
  function touch(x, y, opacity, press = 0) {
    const node = F.phone.touchDot;
    dom.show(node, opacity > 0);
    dom.vars(node, { tx: dom.px(x), ty: dom.px(y), to: String(opacity), ts: String(1 - 0.14 * press) });
  }

  F.ui.phone = { build };
})((window.Film = window.Film || {}));
