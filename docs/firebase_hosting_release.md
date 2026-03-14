# Firebase Hosting Release Guide

This project deploys its Flutter web build to Firebase Hosting on the Spark plan.

## 1. One-time setup

1. Install Firebase CLI.
   - `npm install -g firebase-tools`
2. Log in.
   - `firebase login`
3. Point the repo to your Firebase project.
   - Replace `replace-with-your-firebase-project-id` in [.firebaserc](../.firebaserc)
   - Or run `firebase use --add` and keep the generated `.firebaserc`
4. Initialize Hosting once if this machine has never used Firebase in this repo.
   - `firebase init hosting`
   - Use these answers:
     - existing project: select your Firebase project
     - public directory: `build/web`
     - single-page app: `Yes`
     - GitHub deploy setup: `No`
     - overwrite `build/web/index.html`: `No`
5. Prepare the production env file.
   - Copy [app.web.prod.json.example](../env/app.web.prod.json.example) to `env/app.web.prod.json`
   - Fill `SUPABASE_URL` and `SUPABASE_ANON_KEY`
   - Keep `TRANSLATE_PROVIDER` as `deepl`
   - Keep `USE_LOCAL_STATIC_CONTENT` as `false`
6. Run the preflight check before your first deploy.
   - `powershell -ExecutionPolicy Bypass -File .\scripts\check_firebase_hosting_ready.ps1`

## 2. Why the prune step exists

The web build currently includes large local sqlite assets by default:

- `assets/db/app_content.db`
- `assets/db/dictionary_local.sqlite`
- web sqlite worker and wasm support files

Production web runs in remote-first mode, so these files are unnecessary on Firebase Hosting. The release scripts remove them from `build/web` before deploy to keep the free-tier bundle lean and to prevent the browser from touching local web sqlite code paths.

Important:

- Do not prefer raw `firebase deploy --only hosting` as the default release path.
- Use the PowerShell release scripts in this repo so the build is validated and pruned first.
- `firebase.json` now also ignores the local sqlite and drift worker artifacts as a safety net, but the scripts remain the primary release path.
- Release versioning is part of the deploy contract.
- Before every live deploy, update:
  - `packages/shared_core/lib/src/workspace_info.dart`
  - `packages/shared_core/lib/src/release/release_catalog.dart`
  - `docs/release/CHANGELOG.md`
  - `apps/student_app/pubspec.yaml`
  - `apps/admin_console/pubspec.yaml`
- Validate both release entry points against the same metadata source:
  - wide web sidebar version chip
  - narrow/mobile `Profil/Giris` release card
- The build script should fail if the current release version is missing from the changelog or if app pubspec versions drift from the shared release metadata.

## 3. Build only

Use this when you want a validated production bundle without deploying:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_web_firebase.ps1 -EnvironmentFile env\app.web.prod.json
```

What it does:

- runs `flutter analyze`
- runs the targeted widget tests
- builds release web
- validates the shared release version and changelog contract
- rewrites `version.json` with the shared release version metadata
- prunes sqlite/db debug artifacts from `build/web`
- verifies the required production artifacts still exist

## 4. Build and deploy

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_web_firebase.ps1 -EnvironmentFile env\app.web.prod.json
```

What it does:

- runs the build script
- starts a local static server smoke test
- checks `/`, `/index.html`, `/main.dart.js`, `/flutter_bootstrap.js`, `/version.json`
- checks `/changelog`
- checks route refresh behavior with `/readings/example`
- deploys with `firebase deploy --only hosting`

After deploy, you can capture a five-screen live smoke set with:

```powershell
npm install --prefix temp\playwright-runner playwright
$env:NODE_PATH = "$PWD\temp\playwright-runner\node_modules"
node .\scripts\live_smoke_playwright.js https://<project-id>.web.app artifacts\live_smoke
```

For a local smoke-only run without pushing a release:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_web_firebase.ps1 -EnvironmentFile env\app.web.prod.json -SkipDeploy
```

## 4.1. Android release APK

Android release APK icin desteklenen tek yol repo icindeki env-dogrulamali script'tir:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_android_release.ps1 -EnvironmentFile env\app.web.prod.json
```

Bu script:

- `env/app.web.prod.json` dosyasini okur
- `SUPABASE_URL` ve `SUPABASE_ANON_KEY` alanlarini build oncesi zorunlu olarak dogrular
- `student_app` icin `android-arm64` release APK uretir
- `--split-per-abi`, `--obfuscate` ve `--split-debug-info` kullanir
- ciktiyi `apps/student_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` altina yazar

Onemli:

- Duz `flutter build apk ...` komutunu release icin kullanmayin.
- `--dart-define-from-file=env/app.web.prod.json` olmadan uretilen APK, Supabase env degerleri bos kalacagi icin preview auth yuzeyine duser.
- Web deploy tamamlandiktan sonra Android APK ayri olarak bu script ile uretilmelidir.

## 4.2. Fast preflight checklist

Run this any time before deploy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check_firebase_hosting_ready.ps1
```

It checks:

- Firebase CLI is installed
- Firebase CLI is logged in
- `.firebaserc` no longer contains the placeholder project id
- `firebase.json` exists
- `env/app.web.prod.json` exists
- build and deploy scripts exist

## 5. Acceptance checks after deploy

Open your default hosting URL:

- `https://<project-id>.web.app`
- `https://<project-id>.firebaseapp.com`

Verify:

- app opens without a config error
- anonymous auth session is created
- `Ana Sayfa`, `Kelime`, `Okuma`, `Gramer` flows open
- wide web sidebar version chip shows the current shared version and opens `/changelog`
- narrow/mobile `Profil/Giris` screen shows the same shared version and opens `/changelog`
- route refresh does not return `404`
- browser network does not request:
  - `app_content.db`
  - `dictionary_local.sqlite`
  - `sqlite3.wasm`
  - `drift_worker.dart.js`

## 6. Rollback

Use Firebase Hosting release history in the Firebase Console to roll back to the previous successful release.
