const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const baseUrl = process.argv[2] || 'http://127.0.0.1:8150';
const appName = process.argv[3] || 'student_app';
const outDir = path.resolve(process.argv[4] || 'artifacts/responsive_smoke');

function scenariosFor(app) {
  if (app === 'admin_console') {
    return [
      {
        label: '01-dashboard-desktop',
        route: '/',
        viewport: { width: 1440, height: 900 },
      },
      {
        label: '02-settings-tablet',
        route: '/settings',
        viewport: { width: 1024, height: 900 },
      },
    ];
  }

  return [
    {
      label: '01-home-mobile',
      route: '/',
      viewport: { width: 390, height: 844 },
    },
    {
      label: '02-home-desktop',
      route: '/',
      viewport: { width: 1440, height: 900 },
    },
    {
      label: '03-profile-desktop',
      route: '/profile',
      viewport: { width: 1440, height: 900 },
    },
  ];
}

async function main() {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({ headless: true });

  try {
    for (const scenario of scenariosFor(appName)) {
      const context = await browser.newContext({
        viewport: scenario.viewport,
        serviceWorkers: 'block',
      });
      const page = await context.newPage();
      const url = new URL(scenario.route, baseUrl).toString();

      await page.goto(url, { waitUntil: 'domcontentloaded' });
      await page.waitForLoadState('networkidle');
      await page.waitForFunction(
        (expectedPath) => window.location.pathname === expectedPath,
        scenario.route,
        { timeout: 30000 }
      );
      await page.waitForFunction(
        () => Boolean(document.querySelector('flt-glass-pane, flutter-view, canvas')),
        undefined,
        { timeout: 30000 }
      );
      await page.waitForTimeout(3000);
      await page.screenshot({
        path: path.join(outDir, `${scenario.label}.png`),
        fullPage: true,
      });

      await context.close();
    }
  } finally {
    await browser.close();
  }

  console.log(`responsive smoke passed: ${appName} -> ${outDir}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
