# Faz 10 - Production UI Hardening

## 1. Faz Amaci
Production student web regressions, profil/dev tooling ayrimi, encoding/UI butunlugu ve browser/emulator smoke sertlestirmesini tamamlamak.

## 2. Kapsam
- Student web route/render hardening
- `/profile` ve `/dev-access` ayrimi
- User-facing string ve title butunlugu
- Local + live browser smoke akislari
- Android emulator preflight ve manuel smoke checklist'i

## 3. Kapsam Disi
- Admin oturum timeout hardening
- Dark mode token derinlestirmesi
- Faz 2 ustu offline cache/sync yeniden tasarimi
- Yeni schema veya migration degisikligi

## 4. Yapilacak Isler
- [x] Faz 10 kapsam ve kabul kriterlerini sabitle
- [x] Production ve local release student web icin route mismatch regresyonunu yeniden uret
- [x] Student web icin path-based route acilisini sertlestir
- [x] Student shell ve detail shell icin route-specific browser title ekle
- [x] `/profile` ekranindan debug/test panelini cikar
- [x] Yeni internal `/dev-access` route ve sayfasini ekle
- [x] User-facing auth sheet'i seed hesap presetlerinden arindir
- [x] Student route widget testlerini route-specific title ve access gate icin guncelle
- [x] Browser smoke scriptlerini local/live route assertion'lari ile guncelle
- [x] Android emulator readiness scriptini ekle
- [x] Faz 10 verification README ve kanit ekran goruntulerini olustur

## 5. Teknik Kararlar
- Student web path route acilisi `usePathUrlStrategy()` ile sabitlenecek.
- Browser smoke assertion kaynagi student tarafta `document.title` olacak.
- `/dev-access` navigation item olarak eklenmeyecek; yalniz direct route ile acilacak.
- `/profile` user-facing kalacak; test hesap presetleri ve role/claim preview yalniz `/dev-access` altina tasinacak.
- Local smoke, deploy edilen hosting bundle ile ayni `build/hosting/student_app` cikisini kullanacak.

## 6. Bagimliliklar
- Faz 09 production deploy ve hosting target yapisi
- Mevcut seeded test hesaplari
- Supabase auth/claim akisi

## 7. Riskler
- Web route fixi service worker veya cache nedeniyle gec gorulebilir.
- Flutter web canvas render'i DOM text assertion'larini sinirladigi icin smoke scriptleri title ve screenshot odakli kalir.
- Emulator ortaminda `adb` veya AVD eksigi olabilir.

## 8. Test ve Kabul Kriterleri
- `flutter analyze` temiz gecer.
- `flutter test apps/student_app` ve `flutter test apps/admin_console` temiz gecer.
- Local student route smoke `/`, `/words`, `/readings`, `/grammar`, `/profile`, `/admin` icin gecer.
- Live smoke `https://passagetr-fef48.web.app` ve `https://passagetr-admin.web.app` uzerinde gecer.
- Production student web'de `/words`, `/readings`, `/grammar`, `/profile` direct load sonrasi ana sayfa degil ilgili sayfa acilir.
- `/profile` artik test presetleri veya dev paneli gostermez.
- `/dev-access` user rolunde kapali, admin/developer rolunde acik olur.

## 9. Ilerleme Durumu
- Durum: Tamamlandi
- Son guncelleme: 2026-03-09

## 10. Tamamlananlar / Notlar
- Diger agent raporundaki `P2` maddeler backlog olarak disarida birakildi.
- Root beyaz ekran ve `tum route'larda ayni dashboard` bulgulari yeniden uretildi; kok neden student web router'inin bootstrap sirasinda `/` konumuna resetlenmesi olarak kapatildi.
- Student web `GoRouter` artik auth state degisikliginde yeniden kurulmaz; access gate'ler widget seviyesinde izlenir.
- Student ve admin web `usePathUrlStrategy()` ile path-based route acilisini korur.
- Student ve admin bootstrap ekranlari artik gecici `MaterialApp` ile route'u ezmez; uygulama router'i ilk frame'den itibaren aktif kalir.
- Local smoke kanitlari `docs/verification/phase10_production_ui_hardening/local/` altinda olusturuldu.
- Live smoke kanitlari `docs/verification/phase10_production_ui_hardening/live/` altinda olusturuldu.
- Android emulator readiness scripti `local.properties` altindaki `sdk.dir` yolunu da okuyacak sekilde sertlestirildi.
- Android kaniti `docs/verification/phase10_production_ui_hardening/emulator/android_student_app_phase10.png` olarak kaydedildi.
- Faz disinda birakilan `P2` oneriler `docs/reports/phase10_p2_backlog.md` dosyasina tasindi.
