# Delivery Verification - 2026-03-09

## Ozet

Bu klasor, 2026-03-09 tarihli manuel teslim dogrulama kanitlarini icerir.

## Kanitlar

- `android_student_app_emulator.png`
  - Guncel debug APK emulatorde acildi.
- `student_web_preview.png`
  - Guncel web preview deploy acildi.

## Build Ciktilari

- APK:
  - `apps/student_app/build/app/outputs/flutter-apk/app-debug.apk`
- Web bundle:
  - `build/web`

## Web Linkleri

- Firebase preview:
  - `https://passagetr-fef48--student-web-20260309-25ypdgug.web.app`
- Profil rotasi:
  - `https://passagetr-fef48--student-web-20260309-25ypdgug.web.app/profile`

## Not

Firebase CLI deploy sirasinda preview domainini Firebase Auth'a otomatik ekleyemedi.
Bu nedenle preview linkinde auth akislarinda domain kaynakli ek ayar gerekebilir.
Ana sayfa ve profil rotasi HTTP 200 ile dogrulandi.
