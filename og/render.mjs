// Renders og.html to docs/og.png, the 1200 x 630 card shown when the link is texted.
// Playwright lives in the Breckenridge app, so point PLAYWRIGHT at it:
//   PLAYWRIGHT=file:///E:/exodus-price-sync/tripapp/node_modules/playwright/index.mjs node E:/Birthday/og/render.mjs
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const { chromium } = await import(process.env.PLAYWRIGHT || 'playwright');

const here = path.dirname(fileURLToPath(import.meta.url));
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
await page.goto(pathToFileURL(path.join(here, 'og.html')).href, { waitUntil: 'networkidle' });
await page.evaluate(() => document.fonts.ready);
await page.locator('#card').screenshot({ path: path.join(here, '..', 'docs', 'og.png') });
await browser.close();
console.log('wrote docs/og.png');
