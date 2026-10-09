// DOM plumbing: nodes are built once, then each frame only writes CSS custom
// properties (cached, so unchanged values cost nothing).
(function (F) {
  const SVG_NS = 'http://www.w3.org/2000/svg';

  function el(tag, cls, parent, text) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text != null) node.textContent = text;
    if (parent) parent.appendChild(node);
    return node;
  }

  function svg(tag, attrs, parent) {
    const node = document.createElementNS(SVG_NS, tag);
    for (const key in attrs) node.setAttribute(key, attrs[key]);
    if (parent) parent.appendChild(node);
    return node;
  }

  function set(node, name, value) {
    const cache = node.__v || (node.__v = {});
    if (cache[name] === value) return;
    cache[name] = value;
    node.style.setProperty('--' + name, value);
  }

  function vars(node, map) {
    for (const key in map) set(node, key, map[key]);
  }

  function attr(node, name, value) {
    const cache = node.__a || (node.__a = {});
    if (cache[name] === value) return;
    cache[name] = value;
    node.setAttribute(name, value);
  }

  function show(node, on) {
    const value = on ? '1' : '0';
    if (node.dataset.on !== value) node.dataset.on = value;
  }

  function text(node, value) {
    if (node.textContent !== value) node.textContent = value;
  }

  const px = (n) => `${Math.round(n * 100) / 100}px`;

  // [font, codepoint] — Material Icons (Flutter SDK) and Tabler 3.46.0,
  // the exact glyphs the app draws (see lib/core/widgets/app_bottom_dock.dart).
  const ICONS = {
    add: ['mi', 0xf537], check: ['mi', 0xf636], close: ['mi', 0xf647],
    mic: ['mi', 0xf8bb], edit: ['mi', 0xf00d], star: ['mi', 0xf01d4],
    starOutline: ['mi', 0xf01cf], settings: ['mi', 0xf36e],
    chevronDown: ['mi', 0xf82b], pause: ['mi', 0xf0056], arrowUp: ['mi', 0xf57e],
    editNote: ['mi', 0xf030f], layers: ['mi', 0xf157], arrowForward: ['mi', 0xf57a],
    cut: ['mi', 0xf66d], timeline: ['ti', 0xffa3], list: ['ti', 0xf074],
    heart: ['ti', 0xeabe], home: ['ti', 0xeac1], briefcase: ['ti', 0xea46],
    users: ['ti', 0xebf2], book: ['ti', 0xea39],
  };

  function icon(name, parent, cls = '') {
    const [font, codepoint] = ICONS[name];
    return el('span', `ic ${font} ${cls}`.trim(), parent, String.fromCodePoint(codepoint));
  }

  const pad = (n) => String(n).padStart(2, '0');
  const parts = (min) => {
    const m = ((Math.round(min) % 1440) + 1440) % 1440;
    return { h: Math.floor(m / 60), m: m % 60 };
  };

  // lib/core/timeline_clock.dart, 12-hour: "9 am", "9:30am".
  function clockText(min) {
    const { h, m } = parts(min);
    const hour = h % 12 === 0 ? 12 : h % 12;
    const period = h >= 12 ? 'pm' : 'am';
    return m === 0 ? `${hour} ${period}` : `${hour}:${pad(m)}${period}`;
  }

  // TimeOfDay.format with the app's lower-case am/pm: "10:00 am".
  function timeText(min) {
    const { h, m } = parts(min);
    const hour = h % 12 === 0 ? 12 : h % 12;
    return `${hour}:${pad(m)} ${h >= 12 ? 'pm' : 'am'}`;
  }

  // formatDurationLabel: whole hours "1h", otherwise total minutes "90m".
  const durationText = (dur) => (dur % 60 === 0 ? `${dur / 60}h` : `${dur}m`);

  function statusTime(min) {
    const { h, m } = parts(min);
    return `${h % 12 === 0 ? 12 : h % 12}:${pad(m)}`;
  }

  function filmClock(min) {
    const { h, m } = parts(min);
    return `${pad(h)}:${pad(m)}`;
  }

  F.dom = {
    el, svg, set, vars, attr, show, text, px, icon,
    clockText, timeText, durationText, statusTime, filmClock,
  };
})((window.Film = window.Film || {}));
