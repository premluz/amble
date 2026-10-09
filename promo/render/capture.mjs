// Frame-exact capture: every frame is seeked (the film is a pure function of
// time), so output never depends on machine speed. Fails on any page error.
//
//   PLAYWRIGHT_CORE=<path to an installed playwright-core> \
//     node render/capture.mjs frames <url> <outDir>          # every frame, JPEG
//     node render/capture.mjs stills <url> <outDir> 1.5,17.6  # chosen seconds, PNG
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';

const require = createRequire(import.meta.url);

function usage(message) {
  console.error(`${message}\nusage: node render/capture.mjs frames|stills <url> <outDir> [seconds,...]`);
  process.exit(2);
}

function loadChromium() {
  const path = process.env.PLAYWRIGHT_CORE;
  if (!path) usage('PLAYWRIGHT_CORE is not set (path to an installed playwright-core).');
  return require(path).chromium;
}

async function openFilm(chromium, url) {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  const errors = [];
  page.on('pageerror', (error) => errors.push(`pageerror: ${error.message}`));
  page.on('console', (msg) => msg.type() === 'error' && errors.push(`console: ${msg.text()}`));
  page.on('requestfailed', (req) => errors.push(`requestfailed: ${req.url()} ${req.failure()?.errorText}`));
  const sep = url.includes('?') ? '&' : '?';
  await page.goto(`${url}${sep}capture`, { waitUntil: 'networkidle' });
  await page.evaluate(() => window.__film.ready);
  await page.evaluate(() => document.fonts.ready);
  const meta = await page.evaluate(() => ({ duration: window.__film.duration, fps: window.__film.fps }));
  return { browser, page, errors, meta };
}

async function shoot(page, t, path, type) {
  await page.evaluate((time) => window.__film.seek(time), t);
  const options = type === 'jpeg' ? { path, type, quality: 92 } : { path, type };
  await page.screenshot(options);
}

async function captureFrames(film, outDir) {
  const total = Math.round(film.meta.duration * film.meta.fps);
  for (let i = 0; i < total; i++) {
    await shoot(film.page, i / film.meta.fps, join(outDir, `${String(i).padStart(5, '0')}.jpg`), 'jpeg');
    if (i % 150 === 0) console.log(`frame ${i}/${total}`);
  }
  return total;
}

async function captureStills(film, outDir, list) {
  const seconds = (list || '').split(',').filter(Boolean).map(Number);
  if (!seconds.length || seconds.some(Number.isNaN)) usage('stills needs comma-separated seconds.');
  for (const t of seconds) await shoot(film.page, t, join(outDir, `still-${t.toFixed(2)}.png`), 'png');
  return seconds.length;
}

async function main() {
  const [mode, url, outDir, list] = process.argv.slice(2);
  if (!['frames', 'stills'].includes(mode) || !url || !outDir) usage('Missing arguments.');
  mkdirSync(outDir, { recursive: true });
  const film = await openFilm(loadChromium(), url);
  try {
    const count = mode === 'frames' ? await captureFrames(film, outDir) : await captureStills(film, outDir, list);
    if (film.errors.length) throw new Error(`page reported errors:\n${film.errors.join('\n')}`);
    console.log(`captured ${count} ${mode} to ${outDir}`);
  } finally {
    await film.browser.close();
  }
}

main().catch((error) => {
  console.error(error.stack || String(error));
  process.exit(1);
});
