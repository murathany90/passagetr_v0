# Faz 9 Verification

- Release preflight scripti: `scripts/release_preflight.ps1`
- Freeze kaydi: `docs/release/release_freeze_2026-03-09.md`
- Basarili artifact'lar:
  - Auth smoke ekranlari bu klasore kopyalandi
  - Student release preflight ekranlari bu klasore kopyalandi
  - Admin release preflight ekranlari bu klasore kopyalandi
  - `apps/student_app/build/app/outputs/flutter-apk/app-release.apk`
- Kopyalanan screenshot kanitlari:
  - `01-anonymous-auth.png`
  - `02-sign-out.png`
  - `01-home-mobile.png`
  - `02-home-desktop.png`
  - `03-profile-desktop.png`
  - `01-dashboard-desktop.png`
  - `02-settings-tablet.png`
- Kullanilan komut:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\release_preflight.ps1 -EnvironmentFile env/app.web.json`
