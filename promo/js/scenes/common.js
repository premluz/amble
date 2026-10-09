// Shared scene vocabulary: the resting camera, the copy column, taps, and
// the schedule after "Push all" (it persists for the rest of the film).
(function (F) {
  const { M, D } = F;
  const CAM = { x: 1330, y: 540, s: 1 };
  const COPY = { x: 150, y: 400, w: 920 };
  // The rigid calendar of scene 2: hour rules from 9:00, 140 px apart.
  const GRID = { x0: 860, x1: 1780, y0: 190, hour: 140, first: 9 };
  const gridY = (minutes) => GRID.y0 + ((minutes - GRID.first * 60) / 60) * GRID.hour;

  // A finger: arrives, presses for `hold` seconds at `at`, lifts, leaves.
  function tap(t, at, hold = 0.18) {
    const o = M.span(t, at - 0.22, at - 0.1) * (1 - M.span(t, at + hold + 0.18, at + hold + 0.32));
    const press = M.span(t, at, at + 0.06) * (1 - M.span(t, at + hold, at + hold + 0.08));
    return { o, press };
  }

  // Tasks moved by computeCascadeMoves, interpolated by p (0..1).
  function pushed(p = 1) {
    const out = {};
    for (const id in D.cascade) {
      const task = D.tasks.find((x) => x.id === id);
      out[id] = { start: M.lerp(task.start, D.cascade[id], p) };
    }
    return out;
  }

  function merge(...maps) {
    const out = {};
    for (const map of maps) {
      for (const id in map) out[id] = { ...(out[id] || {}), ...map[id] };
    }
    return out;
  }

  // The shell around a page at film time `ft`.
  function shell(ft, page, cam = CAM, dark = 0) {
    F.phone.camera(cam);
    F.phone.theme(dark);
    F.phone.status(F.clockAt(ft));
    F.phone.page(page);
  }

  function dayDock({ toList = 0, switchT = 0, star = 0 } = {}) {
    F.dock.views({ toList, t: switchT });
    F.dock.edit();
    F.dock.star({ on: star });
    F.dock.add();
  }

  // A cut between two moments of the day dips the screen to its page colour
  // (in for the first 0.22 s, out over the last 0.12 s) instead of jumping.
  function cut(t, id, { inbound = true, outbound = true } = {}) {
    const [start, end] = D.scenes[id];
    const length = end - start;
    const arrive = inbound ? 1 - M.span(t, 0, 0.22) : 0;
    const leave = outbound ? M.span(t, length - 0.12, length) : 0;
    F.phone.veil(Math.max(arrive, leave));
  }

  // Blend two cameras.
  function camLerp(a, b, p) {
    return { x: M.lerp(a.x, b.x, p), y: M.lerp(a.y, b.y, p), s: M.lerp(a.s, b.s, p), ry: M.lerp(a.ry || 0, b.ry || 0, p) };
  }

  F.S = { CAM, COPY, GRID, gridY, tap, pushed, merge, shell, dayDock, camLerp, cut };
})((window.Film = window.Film || {}));
