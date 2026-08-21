/**
 * Horizontal-overflow check.
 *
 * "No page may scroll horizontally" is in the pre-ship checklist, and until now
 * it was checked by eye at whatever width the window happened to be. This walks
 * every route at every width the checklist names, scrolls each page so lazy
 * images lay out, and names the first few elements that stick out past the
 * viewport when one does.
 *
 *   node scripts/audit-widths.mjs [baseUrl]
 *
 * Exits non-zero on any overflow.
 */
import { chromium } from 'playwright';

const BASE = process.argv[2] ?? 'http://localhost:3000';
const ROUTES = ['/', '/voice', '/languages', '/privacy', '/support', '/terms'];
const WIDTHS = [320, 360, 390, 430, 768, 1024, 1280, 1440, 1728];

const browser = await chromium.launch();
const problems = [];

for (const width of WIDTHS) {
  const context = await browser.newContext({ viewport: { width, height: 900 } });
  const page = await context.newPage();

  for (const route of ROUTES) {
    await page.goto(BASE + route, { waitUntil: 'load' });
    const measured = await page.evaluate(async () => {
      document.querySelectorAll('.reveal').forEach((el) => el.classList.add('isIn'));
      document.querySelectorAll('img').forEach((i) => (i.loading = 'eager'));
      const height = document.documentElement.scrollHeight;
      for (let y = 0; y < height; y += 800) {
        window.scrollTo(0, y);
        await new Promise((r) => setTimeout(r, 20));
      }
      await new Promise((r) => setTimeout(r, 200));
      const de = document.documentElement;
      const over = Array.from(document.querySelectorAll('body *'))
        .filter((el) => el.getBoundingClientRect().right > de.clientWidth + 1)
        .slice(0, 3)
        .map((el) => `${el.tagName}.${el.className}`.slice(0, 70));
      return { scrollWidth: de.scrollWidth, clientWidth: de.clientWidth, over };
    });

    if (measured.scrollWidth > measured.clientWidth + 1) {
      problems.push(
        `${width}px ${route}: scrollWidth ${measured.scrollWidth} > ${measured.clientWidth} :: ${measured.over.join(' | ')}`
      );
    }
  }

  await context.close();
}

await browser.close();

if (problems.length) {
  console.error(problems.join('\n'));
  process.exit(1);
}
console.log(`OK — no horizontal overflow at ${WIDTHS.join(' / ')}px across ${ROUTES.length} routes.`);
