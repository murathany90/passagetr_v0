const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const baseUrl = process.argv[2] || 'https://passagetr-fef48.web.app';
const outDir = path.resolve(process.argv[3] || 'artifacts/live_smoke');

async function capture(page, fileName) {
  await page.screenshot({
    path: path.join(outDir, fileName),
    fullPage: true,
  });
}

async function main() {
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.launch({
    channel: 'chrome',
    headless: true,
  });

  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    serviceWorkers: 'block',
  });

  const page = await context.newPage();
  await page.goto(baseUrl, { waitUntil: 'networkidle' });
  await page.waitForTimeout(6000);
  await capture(page, '01-home.png');

  const tabs = [
    { y: 135, file: '02-kelime.png' },
    { y: 242, file: '03-okuma.png' },
    { y: 296, file: '04-gramer.png' },
    { y: 350, file: '05-profil.png' },
  ];

  for (const tab of tabs) {
    await page.mouse.click(44, tab.y);
    await page.waitForTimeout(2500);
    await capture(page, tab.file);
  }

  await browser.close();
  console.log(outDir);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
