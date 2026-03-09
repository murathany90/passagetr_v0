# Production Cutover - 2026-03-09

## Ozet
- `student_app` v2, Firebase Hosting production kanalina deploy edildi.
- Canli adres: `https://passagetr-fef48.web.app`
- Bu deploy ile onceki v1 production web yayini degistirildi.
- `admin_console` da ayri Hosting target'i ile `https://passagetr-admin.web.app` adresine deploy edildi.

## Kullanilan ortam dosyasi
- `env/app.web.prod.json`
  - `SUPABASE_URL`: `https://qretfjzaolpdguggcqfg.supabase.co`
  - `ADMIN_CONSOLE_URL`: `https://passagetr-admin.web.app`
  - `USE_LOCAL_STATIC_CONTENT`: `false`

## Calistirilan komutlar
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_web_firebase.ps1 -AppName student_app -EnvironmentFile env/app.web.prod.json -SkipAnalyze -SkipTests -SkipDeploy
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_web_firebase.ps1 -AppName student_app -EnvironmentFile env/app.web.prod.json -SkipAnalyze -SkipTests
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_web_firebase.ps1 -AppName admin_console -EnvironmentFile env/app.web.prod.json
```

## Canli dogrulama
```powershell
Invoke-WebRequest -UseBasicParsing "https://passagetr-fef48.web.app/"
Invoke-WebRequest -UseBasicParsing "https://passagetr-fef48.web.app/profile"
Invoke-WebRequest -UseBasicParsing "https://passagetr-admin.web.app/"
Invoke-WebRequest -UseBasicParsing "https://passagetr-admin.web.app/login"
```

## Sonuclar
- `https://passagetr-fef48.web.app/`
  - `HTTP 200`
  - `flutter_bootstrap.js` bulundu
- `https://passagetr-fef48.web.app/profile`
  - `HTTP 200`
  - route refresh SPA rewrite ile calisiyor
- `https://passagetr-admin.web.app/`
  - `HTTP 200`
  - `flutter_bootstrap.js` bulundu
- `https://passagetr-admin.web.app/login`
  - `HTTP 200`
  - route refresh SPA rewrite ile calisiyor

## Not
- `scripts/deploy_web_firebase.ps1` build alt sureci hata verirse artik deploy/smoke akisi devam etmeyecek sekilde sertlestirildi.
- Firebase Hosting konfigi coklu target yapisina cekildi:
  - `student_app` -> `passagetr-fef48`
  - `admin_console` -> `passagetr-admin`
