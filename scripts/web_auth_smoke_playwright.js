const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const baseUrl = process.argv[2] || 'http://127.0.0.1:8140';
const outDir = path.resolve(process.argv[3] || 'artifacts/web_auth_smoke');

async function hasSupabaseSession(page) {
  return await page.evaluate(() => {
    return Object.values(window.localStorage).some((value) => {
      if (typeof value !== 'string') {
        return false;
      }

      return value.includes('access_token') || value.includes('refresh_token');
    });
  });
}

function buildSmokeUrl(action) {
  const url = new URL(baseUrl);
  url.searchParams.set('smoke', action);
  return url.toString();
}

async function main() {
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.launch({
    headless: true,
  });

  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    serviceWorkers: 'block',
  });

  const page = await context.newPage();

  page.on('console', (message) => {
    console.log(`browser:${message.type()}:${message.text()}`);
  });

  await page.goto(buildSmokeUrl('anonymous-auth'), {
    waitUntil: 'domcontentloaded',
  });
  await page.waitForLoadState('networkidle');
  await page.screenshot({
    path: path.join(outDir, '01-anonymous-auth.png'),
    fullPage: true,
  });

  await page.waitForFunction(
    () =>
      Object.values(window.localStorage).some((value) => {
        if (typeof value !== 'string') {
          return false;
        }

        return value.includes('access_token') || value.includes('refresh_token');
      }),
    undefined,
    { timeout: 30000 }
  );

  const signedIn = await hasSupabaseSession(page);
  if (!signedIn) {
    throw new Error('Anonymous auth smoke failed: no Supabase session found in localStorage.');
  }

  await page.goto(buildSmokeUrl('sign-out'), {
    waitUntil: 'domcontentloaded',
  });
  await page.waitForLoadState('networkidle');
  await page.screenshot({
    path: path.join(outDir, '02-sign-out.png'),
    fullPage: true,
  });

  await page.waitForFunction(
    () =>
      !Object.values(window.localStorage).some((value) => {
        if (typeof value !== 'string') {
          return false;
        }

        return value.includes('access_token') || value.includes('refresh_token');
      }),
    undefined,
    { timeout: 30000 }
  );

  const signedOut = await hasSupabaseSession(page);
  if (signedOut) {
    throw new Error('Sign-out smoke failed: Supabase session is still present in localStorage.');
  }

  await browser.close();
  console.log(`web auth smoke passed: ${outDir}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
