// The film's layer stack: skies, a back slot for scene sets, the phone, a
// front slot, headlines, the day clock, grain.
(function (F) {
  const { dom } = F;
  const SKIES = ['dawn', 'paper', 'dusk', 'night'];

  // Seeded value noise so every render (and every capture) has the same grain.
  function grainTexture() {
    const size = 256;
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    const image = ctx.createImageData(size, size);
    let seed = 1337;
    for (let i = 0; i < image.data.length; i += 4) {
      seed = (seed * 1664525 + 1013904223) >>> 0;
      const v = seed >>> 24;
      image.data[i] = v;
      image.data[i + 1] = v;
      image.data[i + 2] = v;
      image.data[i + 3] = 255;
    }
    ctx.putImageData(image, 0, 0);
    return `url(${canvas.toDataURL('image/png')})`;
  }

  function build() {
    const stage = document.getElementById('stage');
    const skies = {};
    for (const name of SKIES) skies[name] = dom.el('div', `layer sky-${name}`, stage);
    const back = dom.el('div', 'layer slot', stage);
    const rigSlot = dom.el('div', 'layer slot', stage);
    const front = dom.el('div', 'layer slot', stage);
    const copy = dom.el('div', 'copy', stage);
    const grain = dom.el('div', 'grain', stage);
    dom.set(grain, 'noise', grainTexture());
    for (const slot of [back, rigSlot, front]) dom.set(slot, 'o', '1');
    F.stage = { node: stage, skies, back, rigSlot, front, copy };
    F.onReset(() => {
      for (const name of SKIES) sky(name, 0);
    });
  }

  // Opacity of one sky; `vars` feeds its own animated parameters.
  function sky(name, opacity, vars) {
    const node = F.stage.skies[name];
    dom.show(node, opacity > 0);
    dom.set(node, 'o', String(opacity));
    if (vars) dom.vars(node, vars);
  }

  F.ui = F.ui || {};
  F.ui.stage = { build, sky };
})((window.Film = window.Film || {}));
