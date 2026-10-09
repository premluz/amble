// Deterministic motion maths: every value is a pure function of time, so any
// frame can be rendered in isolation (scrubbing, frame capture).
(function (F) {
  const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
  const lerp = (a, b, t) => a + (b - a) * t;
  const span = (t, a, b) => clamp((t - a) / (b - a));

  function bezier(x1, y1, x2, y2) {
    const cx = 3 * x1;
    const bx = 3 * (x2 - x1) - cx;
    const ax = 1 - cx - bx;
    const cy = 3 * y1;
    const by = 3 * (y2 - y1) - cy;
    const ay = 1 - cy - by;
    const sx = (t) => ((ax * t + bx) * t + cx) * t;
    const sy = (t) => ((ay * t + by) * t + cy) * t;
    const dx = (t) => (3 * ax * t + 2 * bx) * t + cx;
    return (x) => {
      if (x <= 0) return 0;
      if (x >= 1) return 1;
      let lo = 0;
      let hi = 1;
      let t = x;
      for (let i = 0; i < 24; i++) {
        const err = sx(t) - x;
        if (Math.abs(err) < 1e-6) break;
        const d = dx(t);
        const next = Math.abs(d) > 1e-6 ? t - err / d : NaN;
        if (err > 0) hi = t;
        else lo = t;
        t = next > lo && next < hi ? next : (lo + hi) / 2;
      }
      return sy(t);
    };
  }

  // Amble's own curves (MotionPrimitives) plus two film-only eases.
  const ease = {
    standard: bezier(0.4, 0, 0.2, 1),
    decel: bezier(0, 0, 0.2, 1),
    accel: bezier(0.4, 0, 1, 1),
    film: bezier(0.22, 1, 0.36, 1),
    filmInOut: bezier(0.65, 0, 0.35, 1),
    inOutCubic: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
    outQuart: (t) => 1 - Math.pow(1 - t, 4),
    inOutSine: (t) => -(Math.cos(Math.PI * t) - 1) / 2,
    inQuad: (t) => t * t,
  };

  // Step response of SpringDescription.withDurationAndBounce (the SwiftUI
  // duration/bounce model the app uses): damping ratio = 1 - bounce.
  function spring(t, duration, bounce = 0) {
    if (t <= 0) return 0;
    const w0 = (2 * Math.PI) / duration;
    if (bounce <= 0) return 1 - Math.exp(-w0 * t) * (1 + w0 * t);
    const z = 1 - bounce;
    const wd = w0 * Math.sqrt(1 - z * z);
    const decay = Math.exp(-z * w0 * t);
    return 1 - decay * (Math.cos(wd * t) + ((z * w0) / wd) * Math.sin(wd * t));
  }

  // LiquidPulseSpec presets, copied from lib/core/tokens/liquid_pulse_spec.dart.
  const pulses = {
    select: { depth: 0.06, compress: 0.09, springS: 0.42, bounce: 0.5, squash: 0.45 },
    surface: { depth: 0.025, compress: 0.09, springS: 0.45, bounce: 0.45, squash: 0.5 },
    complete: { depth: 0.14, compress: 0.11, springS: 0.6, bounce: 0.7, squash: 0.6 },
  };

  // Squeeze, then spring past rest once and settle at identity.
  function pulse(t, spec) {
    if (t <= 0) return { sx: 1, sy: 1 };
    const k =
      t < spec.compress
        ? spec.depth * ease.decel(t / spec.compress)
        : spec.depth * (1 - spring(t - spec.compress, spec.springS, spec.bounce));
    return { sx: 1 - k * spec.squash, sy: 1 - k };
  }

  // AppDepthShape: from 30% and transparent, larger, smaller, then actual.
  function emerge(t) {
    if (t <= 0) return { scale: 0.3, opacity: 0 };
    return { scale: 0.3 + 0.7 * spring(t, 0.5, 0.45), opacity: clamp(t / 0.15) };
  }

  // AppLiquidMorph.popover: a droplet spreads into the shape; height lags.
  function morph(t, droplet = 28) {
    return {
      w: spring(t, 0.25, 0.4),
      h: spring(t, 0.32, 0.45),
      droplet,
      content: clamp(t / 0.0625),
      scale: lerp(0.6, 1, spring(t, 0.25, 0.4)),
    };
  }

  // In over `inDur` from `a`, out over `outDur` ending at `b`.
  function window_(t, a, b, inDur = 0.5, outDur = 0.4) {
    return Math.min(span(t, a, a + inDur), 1 - span(t, b - outDur, b));
  }

  F.M = { clamp, lerp, span, bezier, ease, spring, pulses, pulse, emerge, morph, window: window_ };
})((window.Film = window.Film || {}));
