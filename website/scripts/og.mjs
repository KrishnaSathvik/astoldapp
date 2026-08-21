/**
 * Rebuilds `public/og.png` from `scripts/og.html`.
 *
 *   npm run build && npx next start -p 3100     # in another shell
 *   node scripts/og.mjs http://localhost:3100
 *
 * The template is copied into `public/` for the length of the render so it can
 * load the real app icon and the real home-screen capture over http, exactly as
 * a browser would, and is removed again afterwards.
 */
import { chromium } from 'playwright';
import { copyFileSync, rmSync } from 'node:fs';

const BASE = process.argv[2] ?? 'http://localhost:3000';
const TEMP = 'public/__og.html';

copyFileSync('scripts/og.html', TEMP);
try {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 });
  await page.goto(`${BASE}/__og.html`, { waitUntil: 'load' });
  await page.evaluate(async () => {
    await Promise.all(Array.from(document.images).map((i) => (i.complete ? null : i.decode())));
    await new Promise((r) => setTimeout(r, 300));
  });
  await page.screenshot({ path: 'public/og.png' });
  await browser.close();
  console.log('public/og.png written (1200×630)');
} finally {
  rmSync(TEMP, { force: true });
}
