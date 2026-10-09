// Playback engine. A frame = reset every layer, then let each scene whose
// window contains t paint it. Nothing else holds state, so seeking is exact.
(function (F) {
  const { M, D, dom } = F;
  const scenes = [];
  const resets = [];
  const ui = {};
  let time = 0;
  let playing = false;
  let lastStamp = null;

  F.register = (id, render) => {
    const [start, end] = D.scenes[id];
    scenes.push({ id, start, end, render });
  };

  F.onReset = (fn) => resets.push(fn);

  // Scenes build their own sets once the stage, phone and screens exist.
  const builds = [];
  F.onBuild = (fn) => builds.push(fn);
  F.buildScenes = () => builds.forEach((build) => build());

  F.clockAt = (t) => {
    const keys = D.clock;
    if (t <= keys[0][0]) return keys[0][1];
    for (let i = 1; i < keys.length; i++) {
      const [t1, v1] = keys[i];
      if (t > t1) continue;
      const [t0, v0] = keys[i - 1];
      return M.lerp(v0, v1, M.ease.inOutSine((t - t0) / (t1 - t0)));
    }
    return keys[keys.length - 1][1];
  };

  F.frame = (t) => {
    time = M.clamp(t, 0, D.duration - 1e-4);
    for (const reset of resets) reset();
    for (const scene of scenes) {
      if (time >= scene.start && time < scene.end) scene.render(time - scene.start, time);
    }
    sync();
  };

  function sync() {
    if (!ui.range) return;
    ui.range.value = String(time);
    const fmt = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
    dom.text(ui.time, `${fmt(time)} / ${fmt(D.duration)}`);
    ui.play.setAttribute('aria-label', playing ? 'Pause' : 'Play');
    dom.show(ui.overlay, !playing);
    document.body.classList.toggle('is-playing', playing);
  }

  function tick(stamp) {
    if (!playing) return;
    if (lastStamp !== null) F.frame(time + (stamp - lastStamp) / 1000);
    lastStamp = stamp;
    if (time >= D.duration - 1e-3) {
      pause();
      return;
    }
    requestAnimationFrame(tick);
  }

  function play() {
    if (time >= D.duration - 0.05) time = 0;
    playing = true;
    lastStamp = null;
    sync();
    requestAnimationFrame(tick);
  }

  function pause() {
    playing = false;
    sync();
  }

  const toggle = () => (playing ? pause() : play());

  function bindControls() {
    ui.play = document.getElementById('play');
    ui.range = document.getElementById('scrub');
    ui.time = document.getElementById('time');
    ui.overlay = document.getElementById('poster-play');
    ui.range.max = String(D.duration);
    ui.play.addEventListener('click', toggle);
    ui.overlay.addEventListener('click', play);
    document.getElementById('restart').addEventListener('click', () => {
      F.frame(0);
      play();
    });
    ui.range.addEventListener('input', () => {
      pause();
      F.frame(Number(ui.range.value));
    });
    document.addEventListener('keydown', (event) => {
      if (event.code !== 'Space' || event.target.closest('input, button')) return;
      event.preventDefault();
      toggle();
    });
  }

  function fitStage() {
    const frame = document.querySelector('.frame');
    const fit = () => dom.set(frame, 'fit', String(frame.clientWidth / D.stage.w));
    new ResizeObserver(fit).observe(frame);
    fit();
  }

  F.start = () => {
    const capture = new URLSearchParams(location.search).has('capture');
    document.body.classList.toggle('capture', capture);
    fitStage();
    if (!capture) bindControls();
    window.__film = {
      duration: D.duration,
      fps: D.fps,
      ready: document.fonts.ready,
      seek: (t) => {
        F.frame(t);
        return new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done)));
      },
    };
    F.frame(capture ? 0 : D.poster);
  };
})((window.Film = window.Film || {}));
