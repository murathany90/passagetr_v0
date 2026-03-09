# Faz 7 Verification

- Student responsive smoke ekranlari bu klasore kopyalandi
- Admin responsive smoke ekranlari bu klasore kopyalandi
- Kullanilan komutlar:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\smoke_web_responsive.ps1 -AppName student_app -EnvironmentFile env/app.web.json`
  - `powershell -ExecutionPolicy Bypass -File .\scripts\smoke_web_responsive.ps1 -AppName admin_console -EnvironmentFile env/app.web.json -Port 8161`
- Kaydedilen ekranlar:
  - `01-home-mobile.png`
  - `02-home-desktop.png`
  - `03-profile-desktop.png`
  - `01-dashboard-desktop.png`
  - `02-settings-tablet.png`
