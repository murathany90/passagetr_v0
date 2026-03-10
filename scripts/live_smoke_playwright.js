const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const studentBaseUrl = process.argv[2] || 'https://passagetr-fef48.web.app';
const outDir = path.resolve(process.argv[3] || 'artifacts/live_smoke');
const adminBaseUrl = process.argv[4] || '';

const studentScenarios = [
  {
    route: '/',
    file: '01-student-home.png',
    title: 'PASSAGETR | Ana Sayfa',
  },
  {
    route: '/words',
    file: '02-student-words.png',
    title: 'PASSAGETR | Kelimeler',
  },
  {
    route: '/readings',
    file: '03-student-readings.png',
    title: 'PASSAGETR | Okuma Odası',
  },
  {
    route: '/grammar',
    file: '04-student-grammar.png',
    title: 'PASSAGETR | Gramer Modülleri',
  },
  {
    route: '/profile',
    file: '05-student-profile.png',
    title: 'PASSAGETR | Profil',
  },
  {
    route: '/admin',
    file: '06-student-admin.png',
    title: 'PASSAGETR | Admin launcher',
  },
];

async function waitForFlutterSurface(page) {
  await page.waitForFunction(
    () => Boolean(document.querySelector('flt-glass-pane, flutter-view, canvas')),
    undefined,
    { timeout: 30000 }
  );
}

async function capture(page, fileName) {
  await page.screenshot({
    path: path.join(outDir, fileName),
    fullPage: true,
  });
}

async function runStudentSmoke(browser) {
  for (const scenario of studentScenarios) {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
      serviceWorkers: 'block',
    });

    const page = await context.newPage();
    const url = new URL(scenario.route, studentBaseUrl).toString();

    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForLoadState('networkidle');
    await page.waitForFunction(
      (expectedPath) => window.location.pathname === expectedPath,
      scenario.route,
      { timeout: 30000 }
    );
    await waitForFlutterSurface(page);
    await page.waitForTimeout(2500);

    const title = await page.title();
    if (title !== scenario.title) {
      throw new Error(
        `Unexpected title for ${scenario.route}. Expected "${scenario.title}", received "${title}".`
      );
    }

    await capture(page, scenario.file);
    await context.close();
  }
}

async function runAdminSmoke(browser) {
  if (!adminBaseUrl || !adminBaseUrl.trim()) {
    return;
  }

  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    serviceWorkers: 'block',
  });
  const page = await context.newPage();

  await page.goto(new URL('/login', adminBaseUrl).toString(), {
    waitUntil: 'domcontentloaded',
  });
  await page.waitForLoadState('networkidle');
  await page.waitForFunction(
    () => window.location.pathname === '/login',
    undefined,
    { timeout: 30000 }
  );
  await waitForFlutterSurface(page);
  await page.waitForTimeout(2500);
  await capture(page, '07-admin-login.png');

  await page.goto(new URL('/', adminBaseUrl).toString(), {
    waitUntil: 'domcontentloaded',
  });
  await page.waitForLoadState('networkidle');
  await page.waitForFunction(
    () => window.location.pathname === '/login',
    undefined,
    { timeout: 30000 }
  );
  await waitForFlutterSurface(page);
  await page.waitForTimeout(2500);
  await capture(page, '08-admin-root-redirect.png');

  await context.close();
}

async function main() {
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.launch({
    channel: 'chrome',
    headless: true,
  });

  try {
    await runStudentSmoke(browser);
    await runAdminSmoke(browser);
  } finally {
    await browser.close();
  }

  console.log(`live smoke passed -> ${outDir}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
