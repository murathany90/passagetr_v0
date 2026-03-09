# Faz 2 Kanit - Sync Remote + Connectivity

## Ozet
- Faz 2 icinde remote content delta pull, pending/failed outbox flush, lokal outbox conflict resolver ve mobil baglanti geri geldiginde otomatik sync tetigi acildi.
- Bu klasor build, manuel test yuzeyi ve ekran goruntusu kanitlarini toplar.

## Hazir Manuel Test Yuzeyi
- Student web: `http://127.0.0.1:8151/`
- Student profil: `http://127.0.0.1:8151/profile`
- Admin web: `http://127.0.0.1:8152/`
- APK: `apps/student_app/build/app/outputs/flutter-apk/app-debug.apk`
- Android paket: `com.passagetrv2.student_app`

## Bu Turda Dogrulananlar
- `flutter analyze`
- `flutter test packages/shared_data`
- `flutter test apps/student_app`
- `flutter test apps/admin_console`
- `flutter build apk --debug --dart-define-from-file=C:\yazilim_projeler\passagetr_v0\env\app.web.json`
- `flutter build web --release --dart-define-from-file=C:\yazilim_projeler\passagetr_v0\env\app.web.json`
- `flutter build web --release --dart-define-from-file=C:\yazilim_projeler\passagetr_v0\env\app.web.json` (`apps/admin_console`)

## Ekran Goruntuleri
- `student_web_home.png`
- `student_web_profile.png`
- `admin_web_home.png`
- `android_student_app_home.png`

## Faz 2 Olarak Kapanan Teknik Isler
- `content_delta_cache` lokal aynasi
- Supabase tabanli `SyncRemoteClient`
- `pull_content_changes` -> lokal cache baglantisi
- pending/failed outbox -> ilgili RPC flush akisi
- reading/bookmark/favorite event'leri icin lokal outbox merge kurali
- mobilde baglanti geri geldiginde yeniden sync tetigi

## Faz 2 Icinde Hala Acik Isler
- `content_delta_cache` uzerinden gercek lokal content mirror repository'leri
- `user_word_progress` ve `user_grammar_progress` event semantiklerinin genisletilmesi
- reconnect/backoff ve background retry sertlestirmesi
