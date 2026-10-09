// 0:37 Voice. The mic pane stretches into the toolbar, the glow rises, each
// spoken line becomes a row, and on submit the rows fly into the Inbox.
(function (F) {
  const { M, D, S } = F;
  const OPEN = 0.85;
  const EXIT = 6.15;
  const SPEECH = [
    { words: [2.4, 2.7, 3.0], commit: 3.4 },
    { words: [3.5, 3.8, 4.05, 4.3], commit: 4.7 },
    { words: [4.8, 5.05, 5.3, 5.5], commit: 5.9 },
  ];
  const MIC = { x: 294, y: 778 };
  const SUBMIT = { x: 302, y: 778 };
  let headline = null;

  function build() {
    headline = F.copy.make(D.copy.voice, 't-hero');
  }

  const exitU = (t) => M.span(t, EXIT, EXIT + 0.8);
  const flightOf = (t, i) => M.span(exitU(t), 0.05 + 0.09 * i, 0.62 + 0.09 * i);

  // AppPaneMorph: firm spring out; back home hard by 55% of the exit.
  function openness(t) {
    if (t < EXIT) return Math.min(1.02, M.spring(t - OPEN, 0.5, 0.12));
    return M.ease.outQuart(1 - Math.min(1, exitU(t) / 0.55));
  }

  function segment(i, t) {
    const sp = SPEECH[i];
    if (t < sp.words[0]) return null;
    const count = sp.words.filter((at) => t >= at).length;
    const last = sp.words[sp.words.length - 1];
    const flight = flightOf(t, i);
    return {
      text: D.spoken[i].split(' ').slice(0, count).join(' '),
      o: flight >= 1 ? 0 : 1,
      ring: M.span(t, sp.words[0], sp.words[0] + 0.32) * (1 - M.span(t, sp.commit, sp.commit + 0.42)),
      trace: M.span(t, last + 0.12, sp.commit),
      flight,
    };
  }

  function level(t) {
    const speaking = SPEECH.some((sp) => t >= sp.words[0] && t < sp.commit - 0.1);
    return (i) =>
      speaking
        ? 0.25 + 0.75 * Math.abs(Math.sin(t * 13 + i * 0.7) * Math.sin(t * 5.3 + i * 1.9))
        : 0.06 + 0.04 * Math.abs(Math.sin(t * 3 + i));
  }

  function dock(t) {
    // Edit and star sit under the voice route while it is open.
    const covered = 1 - M.clamp(Math.max(0, openness(t)) * 2);
    F.dock.edit(covered);
    F.dock.star({ o: covered });
    const u = t - OPEN;
    if (t < EXIT) {
      const swell = u < 0.15 ? 1 + 0.15 * M.clamp(u / 0.15) : 1.15 * (1 - M.span(u, 0.15, 0.5));
      F.dock.add(1 - M.span(u, 0.15, 0.5), u < 0 ? 1 : swell);
    } else {
      const back = M.emerge(t - EXIT);
      F.dock.add(back.opacity, back.scale);
    }
    const close = M.emerge(t - OPEN - 0.1);
    F.dock.close(close.opacity * (1 - M.span(exitU(t), 0, 0.3)), close.scale);
    F.dock.voice({
      open: Math.max(0, openness(t)), keysT: t - OPEN - 0.52,
      level: level(t), submitPress: S.tap(t, 6.05, 0.15).press,
    });
  }

  function thingsState(t) {
    const u = exitU(t);
    const entering = t < EXIT;
    return {
      sweep: entering ? M.span(t, OPEN, OPEN + 0.35) : 1 - M.span(u, 0, 0.45),
      returning: !entering,
      room: M.ease.standard(M.span(u, 0.1, 0.7)),
      landed: [0, 1, 2].map((i) => (flightOf(t, i) >= 1 ? 1 : 0)),
      voice: {
        t, open: Math.max(0, openness(t)),
        glow: entering ? M.ease.inOutSine(M.span(t, OPEN, OPEN + 0.7)) : 1 - M.ease.inOutSine(M.span(u, 0, 0.45)),
        hint: M.span(t, 1.35, 1.65) * (1 - M.span(t, 2.25, 2.6)),
        hintOut: M.span(t, 2.25, 2.6),
        segs: [0, 1, 2].map((i) => segment(i, t)),
      },
    };
  }

  // Push in while the lines are spoken; both the rows and the toolbar stay in frame.
  function camera(t) {
    const close = F.phone.focus(195, 480, 1330, 540, 1.28);
    const zoomIn = M.ease.filmInOut(M.span(t, 1.2, 2.4));
    const zoomOut = M.ease.filmInOut(M.span(t, 6.2, 7.0));
    return S.camLerp(S.camLerp(S.CAM, close, zoomIn), S.CAM, zoomOut);
  }

  function render(t, ft) {
    F.ui.stage.sky('paper', 1);
    S.shell(ft, 'things', camera(t));
    F.things.render(thingsState(t));
    dock(t);
    const mic = S.tap(t, OPEN - 0.1, 0.12);
    const submit = S.tap(t, 6.05, 0.15);
    const finger = submit.o > 0 ? [SUBMIT, submit] : [MIC, mic];
    F.phone.touch(finger[0].x, finger[0].y, finger[1].o, finger[1].press);
    F.copy.timed(headline, { ...S.COPY, y: 492 }, t, 0.2, 6.95);
    S.cut(t, 'voice');
    F.copy.clock(ft, 1);
  }

  F.onBuild(build);
  F.register('voice', render);
})((window.Film = window.Film || {}));
