# Rios signature motion · v16

A configurable JavaScript/SVG motion study for the Rios mark. The three colored lanes move as a coordinated river, gather into the logo, reveal the wordmark, and flow out again. The studio runs locally in a browser and exports settings plus SVG and PNG still frames.

## Open the studio

Open `index.html` directly, or use `standalone.html` as a single-file version. The studio starts the animation automatically unless reduced motion is enabled. Use the timeline to scrub, preview, and tune the controls.

The preview stays in view while the settings rail scrolls independently. Use **Full screen** to expand the preview; press **Space** to play or pause. Space is ignored while a button, slider, select, or text field has focus. Press Escape to leave full screen.

## Logo lockup controls

- **Mark to wordmark gap** adjusts the horizontal distance from the mark to the first letter.
- **Wordmark font weight** adjusts the SVG font weight from 400 to 900.
- **Wordmark letter spacing** adjusts the distance between letters.
- **Logo size** drives formation and the final lockup together. It begins scaling as the mark forms and reaches the chosen size as formation finishes, so the assembled logo does not need a second resize.
- **Wordmark font** offers system font stacks: System UI, Arial, Helvetica Neue, Georgia, Trebuchet MS, and Courier New. The chosen font is used in the studio, JSON settings, and SVG export.

The wordmark is live SVG text using Arial/Helvetica. The reconstructed Rios glyph spacing is tuned for the letters R-i-o-s.

## Appearance

Choose **Dark**, **Light**, or **Custom**. Dark uses a charcoal background and warm off-white lettering; Light uses warm white and charcoal lettering. In Custom, set the background and wordmark colors independently. The three lane colors are independently editable in every mode. The theme and colors are included in JSON and SVG exports.

## Motion sequence

1. Three lanes with distinct lengths travel across the frame on related wave paths. Tapered dots follow each lane.
2. A second river pass approaches the center. Formation begins before arrival according to **Formation lead-in**; each lane settles and scales down with its own stagger.
3. Right-side bubbles emit only while the mark settles and the wordmark appears. Their lifetime, emission, spacing, travel, spread, and randomness are configurable.
4. The letters reveal with a small stagger and a longer fade. The assembled logo can then scale as one lockup.
5. On flow-out, letters fade in reverse order while each lane continues its wave motion and leaves the frame. Text exit timing can be offset from the waves.

Timing controls are score-relative. `duration` scales the full score. `frame().timing` exposes its derived timing points. The seeded bubble paths are repeatable when scrubbing to the same time and settings.

## Studio controls and defaults

| Control | Default | Studio range |
|---|---:|---:|
| Duration | 11.2s | 5–14s |
| Bend depth | 24px | 15–90px |
| Lane spacing | 40px | 14–40px |
| Line weight | 14px | 4–14px |
| Individuality | 0.6 | 0–1 |
| Tail opacity | 0.75 | 0–1 |
| Tail dots | 4 | 0–6 |
| Tail spacing | 35px | 10–35px |
| First dot size | 9px | 2–9px |
| Tail taper | 0.9 | 0–0.9 |
| Dot stagger | 0.13s | 0–0.18s |
| Wave exit stagger | 0.16s | 0–0.3s |
| Logo hold | 1 | 0.5–1.5 |
| Formation stagger | 0.12 | 0–0.3 |
| Scale-down stagger | 0.06 | 0–0.3 |
| Letter stagger | 0.05s | 0–0.15s |
| Letter fade | 0.8s | 0.25–1.2s |
| Right-side dots | 0.65 | 0–1 |
| Tail follow delay | 0.3s | 0–1.2s |
| Entrance waves / screen | 2.5 | 1–6 |
| Exit waves / screen | 3.5 | 1–6 |
| Exit bend depth | 7px | 4–70px |
| Tail emission frequency | 6/s | 0–6/s; 0 uses fixed dots |
| Formation lead-in | 0.8 | 0–1.6 |
| Formation duration | 0.85 | 0.35–1.3 |
| Dispersion duration | 3.5 | 1.2–4 |
| Text reveal during settling | 0.75 | 0–1.6 |
| Text exit offset vs waves | 0 | −0.6–0.6 |
| Text exit fade | 0.65 | 0.2–1.4s |
| Settling bubbles: lifetime | 3s | 0.5–3s |
| Bubbles: emission window | 0.7s | 0.2–3s |
| Bubbles: emission rate | 6/s | 1–12/s |
| Bubbles: lane stagger | 0.6 | 0–0.6 |
| Bubbles: randomness | 1 | 0–1 |
| Bubble travel distance | 135px | 25–220px |
| Bubble dispersion | 95px | 0–160px |
| Mark to wordmark gap | 26px | 0–80px |
| Wordmark font weight | 600 | 400–900 |
| Wordmark letter spacing | 0px | −2–10px |
| Logo size (formation and lockup) | 1× | 0.6–1.5× |
| Wordmark font | Arial | 6 system font stacks |

Default lane colors are violet `#9950E9`, periwinkle `#91A5FF`, and teal `#19A59F`. Dark mode uses background `#191919` and text `#F3F0EB`; light mode uses background `#F3F1EF` and text `#242321`.

## JavaScript integration

```html
<div id="rios"></div>
<script src="rios-motion.js"></script>
<script>
  const animation = new RiosMotion(document.querySelector('#rios'), {
    ending: 'hold',
    logoGap: 32,
    fontWeight: 700,
    fontFamily: 'system',
    letterSpacing: 1,
    assembledLogoScale: 1.1
  });
  animation.play();
</script>
```

API: `play()`, `pause()`, `replay()`, `seek(seconds)`, `configure(options)`, `svg()`, and `destroy()`. Callbacks: `onupdate(time, frame)` and `onplaystate(false)`. The component does not autoplay; the studio does. Integrations should honor reduced motion and pause offscreen.

`RiosMotionTools.frame(time, options)` returns deterministic path geometry, dots, letter positions, font weight and family, letter spacing, and the lockup transform (`logoCenter`, `logoSize`). `RiosMotionTools.svgAt(time, options)` returns a complete SVG frame.

## Export and verification

The studio exports JSON configuration, editable SVG still frames, and 1920×1080 PNG still frames. Load a saved JSON object with `configure(parsedSettings)`. SVG text remains editable; outline it in a design tool if a fixed vector wordmark is needed. These are still-frame exports, not animated SVG, video, or Lottie.

Run `node verify-v4.cjs` for geometry, timing, theme, and logo control checks. Files include the engine, studio UI and styles, standalone preview, documentation, and verification script.
