const { test, expect } = require('playwright/test');

const baseUrl = process.env.LIVE_SMOKE_URL || 'https://passagetr-fef48.web.app';
const outDir = 'artifacts/live_smoke_round2';

async function settle(page, ms = 6000) {
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(ms);
}

test('capture live web desktop screens', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });

  await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });
  await settle(page, 7000);
  await expect(page.getByText('Ana Sayfa')).toBeVisible();
  await page.screenshot({ path: `${outDir}/01-home.png`, fullPage: true });

  await page.getByText('Kelime').nth(1).click();
  await settle(page, 4000);
  await expect(page.getByText('Kelime / Sozluk Arama')).toBeVisible();
  await page.screenshot({ path: `${outDir}/02-kelime.png`, fullPage: true });

  await page.getByText('Okuma').nth(1).click();
  await settle(page, 4000);
  await expect(page.getByText('Okuma Deneyimi')).toBeVisible();
  await page.screenshot({ path: `${outDir}/03-okuma.png`, fullPage: true });

  await page.getByText('Gramer').nth(1).click();
  await settle(page, 4000);
  await expect(page.getByText('Gramer Kutuphanesi')).toBeVisible();
  await page.screenshot({ path: `${outDir}/04-gramer.png`, fullPage: true });

  await page.getByText('Profil').nth(1).click();
  await settle(page, 4000);
  await expect(page.getByText('Anonim Ogrenci')).toBeVisible();
  await page.screenshot({ path: `${outDir}/05-profil.png`, fullPage: true });
});
