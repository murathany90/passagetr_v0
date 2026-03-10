# Phase 10 Verification

Bu klasor Faz 10 browser ve emulator smoke kanitlarini toplar.

## Beklenen artefact'lar
- `local/01-student-home.png`
- `local/02-student-words.png`
- `local/03-student-readings.png`
- `local/04-student-grammar.png`
- `local/05-student-profile.png`
- `local/06-student-admin.png`
- `live/01-student-home.png`
- `live/02-student-words.png`
- `live/03-student-readings.png`
- `live/04-student-grammar.png`
- `live/05-student-profile.png`
- `live/06-student-admin.png`
- `live/07-admin-login.png`
- `live/08-admin-root-redirect.png`
- `emulator/android_student_app_phase10.png`

## Komutlar

Local student route smoke:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke_local_student_routes.ps1 -EnvironmentFile env/app.web.prod.json
```

Live browser smoke:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke_live_ui.ps1
```

Android emulator readiness:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check_android_emulator_ready.ps1
```

Android debug APK:

```powershell
flutter build apk --debug --dart-define-from-file=..\..\env\app.web.prod.json
```

## Sonuc
- Local student route smoke gecti.
- Live production smoke gecti.
- Android emulator readiness gecti.
- Guncel APK emulator uzerine kurulup ekran goruntusu alindi.

## Manuel emulator checklist
- Student app aciliyor
- Ana Sayfa route'u gorunuyor
- Kelime paketine tiklaninca detay aciliyor
- Okuma detayinda ceviri ac/kapa calisiyor
- Profil ekraninda login/logout calisiyor
- Admin launcher yeni sekmede `admin_console` adresine gider
