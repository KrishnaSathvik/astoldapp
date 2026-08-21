/**
 * Screenshot integrity check.
 *
 * A screenshot on this site is evidence that the app does what the copy claims,
 * so no device may be masked, clipped, or covered by another device. Both of
 * those shipped once and were caught only by looking at full-resolution crops —
 * a bottom fade was eating the numbered list out of the structured-note shot, and a device
 * overlap was hiding the calendar's back button and its whole Sunday column.
 *
 *   node scripts/audit-shots.mjs [baseUrl] [outDir]
 *
 * Exits non-zero on any violation, and writes a full-resolution crop of every
 * device and pair so they can actually be looked at.
 */
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const BASE = process.argv[2] ?? 'http://localhost:3000';
const OUT = process.argv[3] ?? '.shot-audit';
const ROUTES = ['/', '/voice', '/languages'];

mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const problems = [];

for (const route of ROUTES) {
  // `load`, not `networkidle`: a dev server holds an HMR socket open, so the
  // network never goes quiet and networkidle just times out. The image wait
  // below is what actually matters here.
  await page.goto(BASE + route, { waitUntil: 'load' });
  await page.addStyleTag({ content: 'html{scroll-behavior:auto!important}' });
  await page.evaluate(async () => {
    document.querySelectorAll('.reveal').forEach((el) => el.classList.add('isIn'));
    document.querySelectorAll('img').forEach((i) => (i.loading = 'eager'));
    const h = document.documentElement.scrollHeight;
    for (let y = 0; y < h; y += 500) {
      window.scrollTo(0, y);
      await new Promise((r) => setTimeout(r, 30));
    }
    window.scrollTo(0, 0);
    await Promise.all(Array.from(document.images).map((i) => (i.complete ? null : i.decode().catch(() => null))));
    await new Promise((r) => setTimeout(r, 400));
  });

  const found = await page.evaluate(() => {
    const devices = Array.from(document.querySelectorAll('[class*="PhoneShot_phone"]')).map((el) => {
      const img = el.querySelector('img');
      const box = el.getBoundingClientRect();
      const pic = img.getBoundingClientRect();
      const cs = getComputedStyle(el);
      // Walk up looking for an ancestor that crops this device.
      let clippedBy = null;
      for (let a = el.parentElement; a && a !== document.body; a = a.parentElement) {
        const acs = getComputedStyle(a);
        if (acs.overflow === 'hidden' || acs.overflowY === 'hidden') {
          const ar = a.getBoundingClientRect();
          if (box.bottom > ar.bottom + 1 || box.top < ar.top - 1) clippedBy = a.className;
        }
      }
      return {
        label: img.getAttribute('src').replace(/^.*shots%2F/, '').replace(/\.webp.*$/, ''),
        masked: (cs.maskImage && cs.maskImage !== 'none') || (cs.webkitMaskImage && cs.webkitMaskImage !== 'none'),
        selfClips: cs.overflow === 'hidden' && pic.height > box.height + 1,
        clippedBy,
        loaded: img.naturalWidth > 0,
        rect: { l: box.left, r: box.right, t: box.top + scrollY, b: box.bottom + scrollY },
        crop: { x: box.left + scrollX, y: box.top + scrollY, w: box.width, h: box.height },
      };
    });

    const collisions = [];
    for (let i = 0; i < devices.length; i++) {
      for (let j = i + 1; j < devices.length; j++) {
        const a = devices[i].rect;
        const b = devices[j].rect;
        if (a.l < b.r && b.l < a.r && a.t < b.b && b.t < a.b) {
          collisions.push(`${devices[i].label} is overlapping ${devices[j].label}`);
        }
      }
    }
    return { devices, collisions };
  });

  const name = route === '/' ? 'home' : route.slice(1);
  for (const [i, d] of found.devices.entries()) {
    if (d.masked) problems.push(`${route}: ${d.label} is masked`);
    if (d.selfClips) problems.push(`${route}: ${d.label} is clipped by its own box`);
    if (d.clippedBy) problems.push(`${route}: ${d.label} is clipped by an ancestor (${d.clippedBy})`);
    if (!d.loaded) problems.push(`${route}: ${d.label} did not load`);
    const pad = 14;
    await page.screenshot({
      path: `${OUT}/${name}-${String(i).padStart(2, '0')}-${d.label}.png`,
      clip: {
        x: Math.max(0, d.crop.x - pad),
        y: Math.max(0, d.crop.y - pad),
        width: d.crop.w + pad * 2,
        height: d.crop.h + pad * 2,
      },
      fullPage: true,
    });
  }
  found.collisions.forEach((c) => problems.push(`${route}: ${c}`));
  console.log(`${route}: ${found.devices.length} devices checked`);
}

await browser.close();

if (problems.length) {
  console.error('\nScreenshot integrity FAILED:');
  problems.forEach((p) => console.error('  - ' + p));
  process.exit(1);
}
console.log(`\nOK — no device is masked, clipped, or overlapped. Crops written to ${OUT}/`);
