# PASSAGETR v2

PASSAGETR v2, PASSAGETR v1 ürününün kontrollü yeniden yazım reposudur.

Bu repo greenfield değildir.

Mevcut çalışma yaklaşımı, v1 veri alanlarını ve ürün domainlerini koruyarak:

- mimariyi modernleştirmek
- mobil ve web uygulamalarını ayrıştırmak
- ortak paketleri belirginleştirmek
- Supabase merkezli veri akışını sürdürülebilir hale getirmek
- Android ve Web için farklı veri davranışları uygulamak

olarak özetlenebilir.

Bu README, proje hakkında hızlı özet vermek için değil, yeni gelen bir geliştiricinin veya operasyon sorumlusunun repo içindeki gerçek durumu uçtan uca anlayabilmesi için hazırlanmıştır.

İçerik mümkün olduğunca açıklayıcı tutulmuştur.

Bu nedenle:

- ürün amacı
- monorepo yapısı
- uygulama ayrımı
- faz geçmişi
- build ve deploy akışları
- smoke testler
- önemli scriptler
- troubleshooting notları
- canlı ortam bilgileri

tek doküman içinde toplanmıştır.

## 1. Hızlı Özet

Bugünkü teknik tablo şöyledir:

- repo adı: `passagetr_v0`
- ürün adı: `PASSAGETR v2`
- mimari: aynı monorepo içinde iki Flutter uygulaması
- backend: Supabase
- student mobile stratejisi: offline-first
- student web stratejisi: remote-first
- admin panel stratejisi: ayrı web uygulaması
- production student URL: `https://passagetr-fef48.web.app`
- production admin URL: `https://passagetr-admin.web.app`
- current release label: `v2.0.3`
- current student app semantic version: `2.0.3+3`
- current changelog route: `/changelog`
- current student version manifest: `https://passagetr-fef48.web.app/version.json`
- current admin version manifest: `https://passagetr-admin.web.app/version.json`

Release discipline note:

- web sidebar altindaki surum etiketi repo icindeki release metadata'dan gelir
- etiket tiklandiginda student web icinde `/changelog` sayfasi acilir
- dar layout ve APK tarafinda ayni release metadata kaynagi `Profil/Giris` ekranindaki surum kartinda da gosterilir
- her canli deploy oncesi `packages/shared_core/lib/src/workspace_info.dart` icindeki `appVersion` ve `buildNumber` guncellenmelidir
- ayni deployda `packages/shared_core/lib/src/release/release_catalog.dart`, `docs/release/CHANGELOG.md`, `apps/student_app/pubspec.yaml` ve `apps/admin_console/pubspec.yaml` da ayni surume cekilmelidir
- release scriptleri bu senkronu dogrulamak icin kullanilir; `firebase deploy` tek basina varsayilan yol olmamalidir
- shared student UI degisiklikleri genelde web ve Android yuzlerini birlikte etkiler; ancak web remote-first, Android offline-first oldugu icin canli veri gorunurlugu ve tazelik ayni anda degismeyebilir

Mevcut `v2.0.3` release odaklari:

- okuma detay ekranindaki gereksiz yardim notlari kaldirildi
- sentence kartlari kelime bazli inline sozluk etkilesimi kazandi
- uzun basista ayni sentence icinde Turkce ceviri acilir hale geldi
- mobile ve web release metadata kaynaklari ayni shared catalog ile eslendi

Bu repo içinde iki ayrı uygulama bulunur:

1. `apps/student_app`
2. `apps/admin_console`

Ortak kodlar ise paketler altında toplanır:

1. `packages/shared_core`
2. `packages/shared_domain`
3. `packages/shared_data`
4. `packages/shared_ui`

## 2. Temel Kararlar

Projede sabit kabul edilen ana kararlar şunlardır:

- v1 veri modeli yok sayılmaz
- şema yeniden icat edilmez
- migration-first yaklaşımı korunur
- Supabase ana backend olmaya devam eder
- `service_role` istemciye taşınmaz
- Android tarafında offline-first yaklaşımı kullanılır
- Web tarafında remote-first yaklaşımı kullanılır
- student ve admin ayrı uygulama olarak kalır
- admin panel student uygulamasına gömülmez
- `main` dalı arşiv olarak değerlendirilir
- aktif yeniden yazım hattı `v2-rewrite-foundation` olarak ilerler

## 3. Proje Nedir

PASSAGETR v2 bir dil öğrenme ürünüdür.

Ürün ana olarak şu yüzeylerden oluşur:

- kelime paketleri
- flashcard çalışması
- mini test
- okuma parçaları
- okuma detay, sentence translation ve kelime bazli sozluk etkilesimi
- gramer modülleri
- profil ve plan yönetimi
- admin içerik yönetimi

Bu ürün yalnız bir mobil uygulama değildir.

Aynı kod tabanı üzerinden:

- Android APK
- student web uygulaması
- admin web uygulaması

üretilmektedir.

## 4. Neden v2

v1 ürününde işe yarayan domain bilgisi korunurken şu alanlarda yeniden yapılandırma hedeflenmiştir:

- monolitik yapıdan daha net modüler yapıya geçiş
- student ve admin ayrımının netleşmesi
- çevrimdışı veri stratejisinin Android için sistematik hale gelmesi
- web yayın hattının production kalitesine çekilmesi
- UI parity, smoke ve release disiplininin repo içinde dokümante edilmesi

Bu yüzden v2 yalnızca görsel güncelleme değildir.

Aynı zamanda:

- veri erişim modeli
- ortak kod organizasyonu
- deploy süreçleri
- kalite kapıları

yeniden ele alınmıştır.

## 5. Canlı Ortamlar

Güncel production yüzeyleri:

- Student web: `https://passagetr-fef48.web.app`
- Admin web: `https://passagetr-admin.web.app`

Canlı ortamda dikkat edilmesi gerekenler:

- student ve admin aynı site değildir
- admin uygulaması ayrı Firebase Hosting site üzerinden açılır
- student içindeki Admin menüsü, gerçek admin uygulamasına launcher görevi görür
- canlı route smoke Phase 10 sonrası title ve ekran bazlı doğrulanmıştır

## 6. Repo Modeli

Repo, Flutter monorepo yaklaşımıyla düzenlenmiştir.

Kök yapı:

```text
apps/
  student_app/
  admin_console/
packages/
  shared_core/
  shared_domain/
  shared_data/
  shared_ui/
assets/
docs/
env/
scripts/
supabase/
```

Kısa anlamları:

- `apps/`: ürün uygulamaları
- `packages/`: ortak teknik ve görsel katmanlar
- `assets/`: ortak veya üretim girdileri
- `docs/`: yol haritası, fazlar, verification ve yardımcı teknik belgeler
- `env/`: örnek veya kullanılan environment tanımları
- `scripts/`: build, deploy, smoke, import ve kalite scriptleri
- `supabase/`: migration ve Supabase ile ilgili içerik

## 7. Uygulama Ayrımı

### 7.1 Student App

`apps/student_app` son kullanıcı ürünüdür.

Bu uygulama:

- Android’de APK olarak çalışır
- Web’de student sitesi olarak yayınlanır

Student yüzeyi şunları içerir:

- ana sayfa
- kelimeler
- okuma
- gramer
- profil
- premium yüzeyleri
- admin launcher

### 7.1.1 Student yuzeyinin bugunku davranis ozeti

Bu alt baslik, uygulama ekranlarinin su anki gercek durumunu kisa ama operasyonel bir dille sabitler.

Ana navigasyon:

- genis web layoutta surum etiketi sidebar altinda gorunur
- dar layout ve APK tarafinda surum/changelog girisi `Profil/Giris` ekranindaki release kartindan acilir
- anonim kullanicida son navigation slotu `Giris` olarak gorunur
- kimlikli kullanicida ayni slot `Profil` olarak degisir
- kelimeler nav badge sayisi artik web ve Android yuzlerinde gosterilmez

Profil ve auth:

- anonim kullanici `/profile` route'una geldiginde gercek profil yerine auth surface gorur
- anonim kullaniciya sahte isim veya sahte e-posta gosterilmez
- kayitli kullanicida profil ayarlari, display name guncelleme ve hesap yonetimi aksiyonlari acilir
- web genis layoutta cikis aksiyonu sidebar akisi icinde gorunur

Okuma kutuphanesi:

- okuma listesi 21 kartlik sayfalama ile calisir
- free kullanici Pro okumalari listede gorur ama detay icerigi kilitlidir
- sure bilgisi artik okuma kartlarinda ve okuma detay bilgi panelinde gosterilmez

Okuma detayi:

- baslik altindaki ceviri yardim notu kaldirildi
- sol bilgi kartindaki placeholder ozet notu gizlenir
- sentence kartlarinda `Turkce Ceviriyi Goster/Gizle` satiri yoktur
- sentence kartlarinda `Bolum n` etiketi yoktur
- kelimeye kisa basista inline sozluk anlami acilir
- kelimeye uzun basista ayni sentence kartinda Turkce ceviri acilir

Kelime ve gramer:

- words ekranindaki ozet kartlari ortak provider snapshot'undan beslenir
- `0` kelimelik pack'ler student listesinde gizlenir
- grammar modulleri free yuzeyde acilabilir; eski seed-temelli premium kilidi kaldirilmistir

### 7.2 Admin Console

`apps/admin_console` yönetim panelidir.

Bu uygulama:

- ayrı web uygulaması olarak çalışır
- CMS ve operasyon paneli görevini görür

Admin yüzeyi şunları içerir:

- dashboard
- kullanıcılar
- içerik yönetimi
- ayarlar
- login ve access guard

### 7.2.1 Admin console bugunku davranis ozeti

Admin auth ve router:

- `AdminAuthState` / `AdminAuthStatus` ile `bootstrapping`, `authenticated`, `unauthenticated`, `unauthorized`, `sessionExpired` ve `busy` durumlari ayrildi
- router bootstrap tamamlanmadan redirect vermez; protected shell sayfalari loading gate ile acilir
- login akisi tek butonla calisir; basarili email login sonrasi bir kez otomatik session refresh yapilir
- yetkisiz kullanici deterministik hata ile oturumdan dusurulur; manuel `Claimleri Yenile` butonu kaldirilmistir
- session dususu, refresh failure ve idle timeout durumlarinda `/login` redirect + mesaj akisi vardir

Kullanicilar, ayarlar ve dashboard:

- `/users` server-side pagination, filtreleme, checkbox secim, bulk rol/plan guncelleme ve invite dialog destekler
- invite akisinda istemciye `service_role` tasinmaz; `supabase/functions/admin_invite_users` edge function'i davet + access atamasi yapar
- `/settings` artik `public.app_settings` tablosuna bagli kalici product config panelidir
- dashboard `7 / 30 / 90 gun` pencereleri, delta kartlari, trend chart ve sistem durumu paneli ile calisir

CMS parity ve operasyon:

- `/content/words` ve `/content/readings` server-side paged listeleme kullanir; paketler full-list kalir
- icerik satirlari `created_at`, `updated_at`, `updated_by` ve publish bilgilerini gosterir
- publish scheduling kolonlari (`publish_at`, `unpublish_at`) migration seviyesinde eklendi
- admin web build/deploy scriptleri `-WebRenderer` parametresini kabul eder; mevcut Flutter toolchain explicit `html/canvaskit` argumanini desteklemiyorsa script varsayilan renderer ile devam eder

### 7.3 Neden Ayrı

Admin panelin ayrı tutulmasının sebebi:

- güvenlik sınırlarını net tutmak
- student bundle boyutunu şişirmemek
- route karmaşıklığını azaltmak
- CMS ekranlarını son kullanıcı uygulamasından ayırmak
- release ve smoke test kapsamlarını ayrıştırmak

## 8. Ortak Paketler

### 8.1 `shared_core`

Bu paket çekirdek teknik tipleri ve uygulama temelini taşır.

Örnek sorumluluklar:

- `AppConfig`
- result ve failure tipleri
- auth session
- access context
- RBAC ile ilgili temel tipler
- çevreye göre davranış belirleme

### 8.2 `shared_domain`

Bu paket iş alanı sözleşmelerini tutar.

Örnek sorumluluklar:

- entity tanımları
- repository interface’leri
- plan ve rol tipleri
- progress domain modelleri

### 8.3 `shared_data`

Bu paket veri erişimini uygular.

Örnek sorumluluklar:

- Supabase erişimi
- preview repository’ler
- local sync store
- Drift tabanlı katmanlar
- progress repository implementasyonları
- sync ve outbox davranışları

- dictionary lookup repository'leri
- mobile local sqlite ve web remote dictionary davranisi

### 8.4 `shared_ui`

Bu paket ortak UI katmanıdır.

Örnek sorumluluklar:

- tema
- token’lar
- kart bileşenleri
- shell yapıları
- responsive sınırlar
- access gate yüzeyleri

## 9. Veri ve Backend Stratejisi

Projede backend ana omurgası Supabase’tir.

Temel ilkeler:

- auth Supabase üzerinden ilerler
- veri otoritesi Supabase’tir
- migration-first yaklaşım kullanılır
- production web doğrudan ağır local DB’ye dayanmaz
- client tarafına yalnız güvenli istemci anahtarları gider

Bu repo için kesin yasak:

- `service_role` key’i istemciye koymak

Dictionary runtime notu:

- web tarafinda dictionary lookup mevcut `public.dictionary_entries` tablosundan remote olarak okunur
- Android tarafinda `assets/db/dictionary_local.sqlite` lazy-copy ile writable app directory'ye alinip local lookup icin kullanilir
- student reading detail ekrani bu iki kaynagi ayni repository sozlesmesi altinda kullanir

## 10. Platform Stratejileri

### 10.1 Android

Android için yaklaşım:

- offline-first
- local persistence
- arka planda sync
- reconnect sonrası syncIfStale

Bu yaklaşım, ağ zayıf olduğunda öğrenme akışının tamamen kırılmamasını hedefler.

### 10.2 Web

Web için yaklaşım:

- remote-first
- TTL cache
- lazy/deferred page loading
- production hosting bundle

Web tarafı özellikle canlı yayın ve rota açılışı açısından Phase 10’da sertleştirilmiştir.

## 11. Faz Geçmişi

Repo faz bazlı yürütülmüştür.

Faz belgeleri `docs/phases/` altında tutulur.

Mevcut faz dosyaları:

- `phase_00_kesif_kurulum_teknik_iskelet.md`
- `phase_01_auth_oturum_yonetimi_rbac.md`
- `phase_02_offline_first_veri_katmani.md`
- `phase_03_cekirdek_ogrenme_modulleri.md`
- `phase_04_okuma_ceviri_gramer.md`
- `phase_04_5_student_ui_parity_polish.md`
- `phase_05_admin_cms_icerik_operasyonlari.md`
- `phase_05_5_admin_console_hardening.md`
- `phase_06_analytics_streak_pro_paketleme.md`
- `phase_07_web_responsive_yayin_hazirligi.md`
- `phase_08_test_kalite_operasyonel_sertlestirme.md`
- `phase_09_canliya_alma_son_optimizasyon.md`
- `phase_10_production_ui_hardening.md`

### 11.1 Fazların Kısa Anlamı

Faz 0:

- monorepo iskeleti
- workspace
- temel kurulum

Faz 1:

- auth
- session
- RBAC
- Supabase bağlantısı

Faz 2:

- offline-first foundation
- local sync
- outbox temeli

Faz 3:

- kelime modülleri
- flashcard
- mini test

Faz 4:

- okuma
- çeviri
- gramer

Faz 4.5:

- student UI parity polish

Faz 5:

- admin CMS

Faz 5.5:

- admin auth/router hardening
- users/settings/dashboard P1/P2 parity
- paged CMS ve session sertlestirmesi

Faz 6:

- analytics
- streak
- premium yüzeyleri

Faz 7:

- web responsive yayın hazırlığı

Faz 8:

- kalite kapıları
- test sertleştirme

Faz 9:

- production release hazırlığı

Faz 10:

- production UI hardening
- route/render stabilizasyonu
- profile/dev split
- canlı smoke sertleştirmesi

### 11.2 Faz 5.5 Sonucu

Phase 5.5 ile admin console icin su basliklar kapatilmistir:

- login sonrasi redirect loop ve stale-claim problemi
- manuel claim refresh ihtiyaci
- `/users` ekranindaki pagination ve bulk action eksigi
- `/settings` ekraninin read-only env ozetine sikismasi
- dashboard trend/delta ve sistem durumu boslugu
- `/content/words` ve `/content/readings` listelerinde metadata/pagination eksigi

Bu fazin detay dosyasi:

- `docs/phases/phase_05_5_admin_console_hardening.md`

### 11.3 Faz 10 Sonucu

Phase 10 ile özellikle şu kritik problemler kapatılmıştır:

- student web root beyaz ekran regresyonu
- tüm route’ların ana sayfa gibi render olması
- `/profile` içinde debug kalıntıları
- browser smoke’un yalnız HTTP 200’e bakması
- Android emulator readiness kontrolünün eksik olması

P2 seviyesinde geleceğe bırakılan maddeler için ayrı backlog tutulur:

- `docs/reports/phase10_p2_backlog.md`

## 12. Doküman Haritası

Repo içindeki önemli belgeler:

- yol haritası: `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
- agent çalışma çerçevesi: `docs/prompt.md`
- encoding kuralları: `docs/ENCODING.md`
- Firebase release notları: `docs/firebase_hosting_release.md`
- dictionary foundation notları: `docs/dictionary_foundation_phase1.md`
- dictionary asset notları: `docs/dictionary_prebuilt_asset.md`
- static content pipeline: `docs/static_content_pipeline.md`
- Supabase CSV import: `docs/supabase_csv_import.md`
- Supabase readings import: `docs/supabase_readings_import.md`
- UI audit dosyaları: `docs/ui_audit/`
- Figma ve ekran taslakları: `docs/ui_tasarim/`
- verification çıktıları: `docs/verification/`
- release kayıtları: `docs/release/`

## 13. UI ve Tasarım Kaynakları

UI parity ve görsel kararlar için iki ana kaynak kullanılmıştır:

1. `docs/ui_tasarim/`
2. Figma analiz çıktıları ve diğer agent raporları

Ek yardımcı dosyalar:

- `docs/verification/other_agent_live_test/results.md`
- `docs/reports/other_agent_product_improvement_suggestions.md`
- `docs/verification/other_agent_live_test/prompts.md`
- `docs/verification/other_agent_live_test/README.md`

Bu dosyalar özellikle canlı sistem QA ve UI parity karşılaştırmalarında kullanılmıştır.

## 14. Environment Dosyaları

`env/` klasörü altında şu dosyalar bulunur:

- `app.dev.json.example`
- `app.web.json`
- `app.web.prod.json`
- `app.web.prod.json.example`

### 14.1 Ne İçerir

Bu dosyalarda tipik olarak şu anahtarlar yer alır:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `ADMIN_CONSOLE_URL`
- `TRANSLATE_PROVIDER`
- bazı ortamlarda `USE_LOCAL_STATIC_CONTENT`

### 14.2 Dikkat

- örnek dosyalar referans içindir
- production dosyası deploy süreçlerinde kullanılır
- öğrenci ve admin web deploy’larında aynı production env dosyası kullanılabilir
- relative path verirken komutu hangi klasörde çalıştırdığın önemlidir

## 15. Geliştirme Ortamı Gereksinimleri

Projeyle rahat çalışmak için önerilen araçlar:

- Flutter stable
- Android Studio
- Firebase CLI
- Supabase CLI
- PowerShell
- Chrome
- Android SDK
- Node.js

Opsiyonel ama faydalı araçlar:

- Playwright
- Melos

## 16. İlk Kurulum

### 16.1 Repo Kopyalama

```powershell
git clone <repo-url>
cd C:\yazilim_projeler\passagetr_v0
```

### 16.2 UTF-8 Hook Kurulumu

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_git_hooks.ps1
```

### 16.3 Manuel UTF-8 Kontrolü

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ensure_utf8.ps1
```

### 16.4 Flutter Bağımlılıkları

Repo kökünde root Flutter uygulaması yoktur.

Bu yüzden tipik çalışma yaklaşımı şöyledir:

```powershell
cd apps\student_app
flutter pub get

cd ..\admin_console
flutter pub get
```

Gerekirse paketlerde de:

```powershell
cd packages\shared_core
flutter pub get
```

Aynı mantık diğer package klasörleri için de geçerlidir.

## 17. Melos Notu

Repo içinde `melos.yaml` bulunur.

Mevcut tanımlar:

- analyze
- test

Basit haliyle yapılandırılmıştır.

İleride daha kapsamlı bootstrap veya exec akışları tanımlanabilir.

Mevcut örnek:

```yaml
name: passagetr_v2
packages:
  - apps/**
  - packages/**
```

## 18. Student App’i Lokal Çalıştırma

Kök script ile:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_flutter_dev.ps1 -ConfigFile env/app.web.json
```

Doğrudan uygulama klasöründen:

```powershell
cd apps\student_app
flutter run --dart-define-from-file=..\..\env\app.web.json
```

Chrome ile örnek:

```powershell
cd apps\student_app
flutter run -d chrome --web-port 8151 --dart-define-from-file=..\..\env\app.web.json
```

## 19. Admin Console’ı Lokal Çalıştırma

```powershell
cd apps\admin_console
flutter run -d chrome --web-port 8152 --dart-define-from-file=..\..\env\app.web.json
```

Bu durumda tipik lokal URL’ler:

- student: `http://127.0.0.1:8151`
- admin: `http://127.0.0.1:8152`

## 20. Student APK Build Alma

Debug APK:

```powershell
cd apps\student_app
flutter build apk --debug --dart-define-from-file=..\..\env\app.web.prod.json
```

Release APK:

```powershell
cd apps\student_app
flutter build apk --release --dart-define-from-file=..\..\env\app.web.prod.json
```

ABI bazlı release:

```powershell
cd apps\student_app
flutter build apk --release --split-per-abi --dart-define-from-file=..\..\env\app.web.prod.json
```

## 21. Emülatör Hazırlığı

Android readiness scripti:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check_android_emulator_ready.ps1
```

Bu script:

- `adb` yolunu bulur
- `emulator` yolunu bulur
- `local.properties` içindeki `sdk.dir` değerini de okur
- bağlı cihazları listeler
- AVD listesini gösterir

## 22. Web Build Alma

Student web build:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_web_firebase.ps1 -AppName student_app -EnvironmentFile env/app.web.prod.json -WebRenderer auto
```

Admin web build:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_web_firebase.ps1 -AppName admin_console -EnvironmentFile env/app.web.prod.json -WebRenderer html
```

Hosting bundle çıktıları:

- `build/hosting/student_app`
- `build/hosting/admin_console`

## 23. Firebase Deploy

Student deploy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_web_firebase.ps1 -AppName student_app -EnvironmentFile env/app.web.prod.json
```

Admin deploy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_web_firebase.ps1 -AppName admin_console -EnvironmentFile env/app.web.prod.json -WebRenderer html
```

Renderer notu:

- mevcut Flutter toolchain explicit `--web-renderer html` bayragini desteklemiyorsa script uyumluluk mesaji basar ve varsayilan renderer ile devam eder
- `-WebRenderer wasm` secimi desteklenirse `--wasm` flag'i eklenir

Deploy öncesi readiness kontrolü:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check_firebase_hosting_ready.ps1
```

## 24. Firebase Hosting Yapısı

Kök `firebase.json` iki target içerir:

- `student_app`
- `admin_console`

Kök `.firebaserc` eşleşmeleri:

- `student_app` -> `passagetr-fef48`
- `admin_console` -> `passagetr-admin`

Bu ayrım önemlidir.

Çünkü student ve admin artık ayrı site olarak yayınlanmaktadır.

## 25. Quality Gate ve Release

Kalite kapısı:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\quality_gate.ps1 -EnvironmentFile env/app.web.json
```

Release preflight:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release_preflight.ps1 -EnvironmentFile env/app.web.prod.json
```

Bu akışlar:

- analyze
- test
- build
- bazı smoke doğrulamaları

gibi adımları toplu çalıştırmak için kullanılır.

## 26. Test Komutları

Kök analiz:

```powershell
flutter analyze
```

Student test:

```powershell
cd apps\student_app
flutter test
```

Admin test:

```powershell
cd apps\admin_console
flutter test
```

Melos üstünden:

```powershell
melos run analyze
melos run test
```

## 27. Smoke Testler

### 27.1 Web Auth Smoke

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke_web_auth.ps1 -AppName student_app -EnvironmentFile env/app.web.json
```

### 27.2 Responsive Smoke

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke_web_responsive.ps1 -AppName student_app -EnvironmentFile env/app.web.json
```

### 27.3 Local Student Route Smoke

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke_local_student_routes.ps1 -EnvironmentFile env/app.web.prod.json
```

### 27.4 Live UI Smoke

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke_live_ui.ps1
```

## 28. Verification Klasörleri

Önemli doğrulama klasörleri:

- `docs/verification/phase01_supabase_connection/`
- `docs/verification/phase02_offline_foundation/`
- `docs/verification/phase02_sync_connectivity/`
- `docs/verification/phase07_web_responsive/`
- `docs/verification/phase08_quality_gate/`
- `docs/verification/phase09_release_preflight/`
- `docs/verification/phase10_production_ui_hardening/`

Phase 10 kanıt seti özellikle önemlidir.

İçerdiği örnekler:

- local student route screenshot’ları
- live student screenshot’ları
- live admin screenshot’ları
- emulator student screenshot’ı

## 29. Supabase ile İlgili Scriptler

Kullanılan başlıca yardımcılar:

- `seed_supabase_phase1_test_accounts.ps1`
- `verify_supabase_rls.ps1`
- `import_static_content_supabase.py`
- `upload_grammar.ps1`

Bunlar:

- test kullanıcıları
- RLS doğrulaması
- statik içerik import
- gramer upload

gibi amaçlarla kullanılır.

## 30. Dictionary ve Static Content Scriptleri

Öne çıkan scriptler:

- `build_dictionary_asset.py`
- `import_dictionary.py`
- `build_app_content_db.py`
- `static_content_common.py`

Destekleyen belgeler:

- `docs/dictionary_foundation_phase1.md`
- `docs/dictionary_prebuilt_asset.md`
- `docs/static_content_pipeline.md`

## 31. Admin Launcher Davranışı

Student app içindeki Admin menüsü gerçek admin panel değildir.

Bu yüzey:

- access gate ile korunur
- uygun rolde launcher görünür
- gerçek admin site adresini açar

Production’da hedef adres:

- `https://passagetr-admin.web.app`

## 32. `/profile` ve `/dev-access`

Phase 10 sonrası ayrım şu şekildedir:

- `/profile`: son kullanıcıya dönük profil ekranı
- `/dev-access`: internal debug ve test erişim ekranı

Kural:

- `/dev-access` navigation menüsünde görünmez
- yalnız admin/developer erişim bağlamında açılır

## 33. Encoding ve Türkçe Karakter Politikası

Repo geçmişinde mojibake ve UTF-8 sorunları yaşandığı için bu konu kritiktir.

Temel kurallar:

- dosyaları UTF-8 olarak tut
- bozuk Türkçe karakter dizilerini commit etme
- hook kurulumunu atlama

Kontrol scripti:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ensure_utf8.ps1
```

Ayrıntı:

- `docs/ENCODING.md`

## 34. Güvenlik Notları

Bu repoda özellikle dikkat edilmesi gerekenler:

- `service_role` istemciye gitmez
- production anon key dikkatli kullanılır
- admin panel student içine gömülmez
- auth ve RBAC kararları dokümana bağlı yürütülür

## 35. Route ve Web Davranışı

Web tarafında Phase 10 ile sabitlenen noktalar:

- path-based route açılışı korunur
- root route beyaz ekran vermez
- `/words`, `/readings`, `/grammar`, `/profile` direct load ile doğru sayfa açılır
- browser title route bazında ayrışır

Bu doğrulama:

- local smoke
- live smoke
- screenshot kanıtı

ile kilitlenmiştir.

## 36. Android Notları

Android build tarafında kullanılan temel yaklaşım:

- Flutter APK build
- emulator readiness scripti
- debug APK ile hızlı smoke

Emülatörde son sürümü kurmak için tipik akış:

1. readiness scriptini çalıştır
2. debug APK build al
3. `adb install -r` ile kur
4. `am start` ile aç
5. screenshot al

## 37. Sık Kullanılan Dosyalar

Sürekli bakılan dosyalar:

- `README.md`
- `melos.yaml`
- `firebase.json`
- `.firebaserc`
- `env/app.web.prod.json`
- `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
- `docs/phases/*.md`

## 38. Sık Karşılaşılan Sorunlar

### 38.1 `Environment file not found`

Sebep:

- komutu yanlış klasörde çalıştırmak
- relative path’i yanlış vermek

Çözüm:

- kökten script çalıştır
- app klasöründeysen `..\..\env\...` kullan

### 38.2 `adb bulunamadi`

Sebep:

- SDK path env değişkenlerinde yok
- ama `local.properties` içinde olabilir

Çözüm:

- `scripts/check_android_emulator_ready.ps1` çalıştır
- `apps/student_app/android/local.properties` içindeki `sdk.dir` değerini doğrula

### 38.3 Route açılıyor ama ana sayfaya düşüyor

Bu Phase 10 öncesi kritik regresyondu.

Şimdi tekrar görülürse:

- önce canlı smoke çalıştır
- sonra local route smoke ile karşılaştır
- deploy edilen bundle eski olabilir
- tarayıcı cache temizliği gerekebilir

### 38.4 Firebase deploy yanlış siteye gidiyor

Kontrol et:

- `firebase.json`
- `.firebaserc`
- `deploy_web_firebase.ps1`

Student ve admin target’larının karışmaması gerekir.

### 38.5 Türkçe karakterler bozuk görünüyor

Kontrol et:

- dosya encoding’i
- commit öncesi `ensure_utf8.ps1`
- terminal codepage yerine gerçek dosya içeriği

## 39. Diğer Agent ile QA Akışı

Repo içinde başka agent’ların browser ve emulator üzerinden test yapabilmesi için özel dosyalar bulunur.

Başlıcaları:

- `docs/verification/other_agent_live_test/README.md`
- `docs/verification/other_agent_live_test/prompts.md`
- `docs/verification/other_agent_live_test/results.md`
- `docs/reports/other_agent_product_improvement_suggestions.md`

Bu akışın amacı:

- dış gözle production smoke almak
- UI parity bulgularını kanıtla toplamak
- iyileştirme önerilerini ayrı backlog’a dönüştürmek

## 40. Backlog ve Gelecek Sertleştirme Alanları

Phase 10 sonrası kapsam dışı bırakılan alanlar:

- admin session expiry hardening
- dark mode token polish
- offline cache enhancement
- web performance polish
- admin bulk actions

Kaynak dosya:

- `docs/reports/phase10_p2_backlog.md`

## 41. Repo İçinde Bilerek Kalan Ayrımlar

Bazı şeyler bilerek böyledir:

- admin ayrı uygulamadır
- student içindeki admin yüzeyi launcher’dır
- production env script bazlı yönetilir
- docs klasörü büyük tutulmuştur
- faz dosyaları yaşayan doküman mantığıyla kalır

## 42. Tavsiye Edilen Günlük Çalışma Sırası

Yeni bir geliştirme veya düzeltme yapacaksan önerilen sıra:

1. ilgili faz dosyasını aç
2. mevcut davranışı doğrula
3. gerekiyorsa smoke veya screenshot al
4. kodu değiştir
5. analyze çalıştır
6. ilgili app testlerini çalıştır
7. gerekiyorsa web build veya APK build al
8. verification kanıtını dokümana işle

## 43. Commit Disiplini

Repo geçmişinde encoding ve otomasyon tabanlı çok sayıda dosya değiştiği için commit atarken dikkat et:

- bozuk Türkçe karakter bırakma
- build çıktıları ile kaynak dosyaları karıştırma
- geçici artefact ile kalıcı dokümanı ayır
- deploy öncesi smoke almadan production’a çıkma

## 44. Branch ve Arşiv Bilgisi

Kavramsal olarak:

- `main`: v1 arşiv yaklaşımı
- `v2-rewrite-foundation`: v2 aktif hat

Ek not:

- v1 uygulama implementasyonu bu dalda bilinçli olarak temizlenmiştir
- v1 geri getirme stratejisi izlenmez
- amaç kontrollü rewrite’tır

## 45. Sonuç

PASSAGETR v2 şu anda:

- student web
- admin web
- Android APK

üretebilen, faz bazlı olarak ilerlemiş, production yayın almış bir Flutter monorepo’dur.

Bu README’nin amacı yalnız giriş metni sunmak değil, repo ile ilgili kararları, akışları ve operasyonel bilgileri tek yerden anlaşılır hale getirmektir.

Yeni bir ekip üyesi için en doğru başlangıç sırası şudur:

1. bu README’yi oku
2. `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md` dosyasını oku
3. ilgili faz dokümanını aç
4. `docs/verification/` altındaki kanıtları incele
5. sonra kod veya deploy akışına geç

## 46. Hızlı Link Özeti

- Yol haritası: `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
- Fazlar: `docs/phases/`
- Verification: `docs/verification/`
- Release notları: `docs/release/`
- UI audit: `docs/ui_audit/`
- Production student: `https://passagetr-fef48.web.app`
- Production admin: `https://passagetr-admin.web.app`
- Student version manifest: `https://passagetr-fef48.web.app/version.json`
- Admin version manifest: `https://passagetr-admin.web.app/version.json`
- Student changelog route: `https://passagetr-fef48.web.app/changelog`

## 47. Mart 2026 Guncel Durum Notu

Bu ek bolum, onceki satirlari silmeden repo icindeki eski kalma riskini azaltmak icin eklendi.

Guncel release:

- aktif release etiketi `v2.0.4`
- student ve admin pubspec surumu `2.0.4+4`
- changelog kaynagi `packages/shared_core/lib/src/release/release_catalog.dart` ve `docs/release/CHANGELOG.md`
- web canli deploy sonrasi `version.json` uzerinden dogrulama zorunludur

Reading detay iyilestirmeleri:

- placeholder ozet notu artik gosterilmez
- baslik altindaki ceviri yardim notu kaldirilmistir
- eski `Turkce Ceviriyi Goster/Gizle` satiri bulunmaz
- eski `Bolum n` etiketi bulunmaz
- kelimeye kisa basista inline sozluk paneli acilir
- kelimeye uzun basista sentence cevirisi ayni kart icinde acilir
- web lookup `dictionary_entries`, Android lookup `dictionary_local.sqlite` kaynagini kullanir

Profil ve navigation guncel durumu:

- anonim kullanici icin `Profil` yerine `Giris` gorunur
- `/profile` route'u anonim kullanicida auth surface, kimlikli kullanicida profil yonetimi acilir
- mobil/dar layoutta release karti `Profil/Giris` ekraninda gorunur
- genis web layoutta release/changelog girisi sidebar altindaki surum etiketiyle verilir

Okuma ve ogrenme modulu guncel durumu:

- reading listesi 21 kayitlik sayfalama kullanir
- free kullanici Pro okumayi listede gorur ama tam detay kilitlidir
- kelimeler nav badge'i kaldirilmistir
- words summary kartlari ortak provider snapshot'i kullanir
- student listesinde `0` kelimelik pack gosterilmez
- grammar yuzeyi free akisla calisir; menu ve detay ekranlari gercek DB modulleri ile render edilir

APK ve deploy operasyon notlari:

- release APK build komutu ile uretilen paket semantic version olarak `2.0.4+4` tasimalidir
- emulatore hizli kurulum icin `flutter install --use-application-binary ...` yolu desteklenir
- web deploy scriptleri analyze, test, build, smoke ve hosting release adimlarini tek akista calistirir
- dogrudan `firebase deploy` yerine repo scriptleri tercih edilmelidir

## 48. Son Not

Bu doküman düzenli olarak güncellenmelidir.

Özellikle şu durumlarda README güncellemesi yapılması önerilir:

- yeni faz açılırsa
- production URL değişirse
- deploy scriptleri değişirse
- workspace yapısı değişirse
- yeni smoke veya quality gate eklendiyse

README ile faz dosyalarının çelişmemesi temel kuraldır.



Repo içinde açıkça tanımlı seeded test hesapları bunlar:

phase1.admin@passagetr.dev / PassageTR#2026!
phase1.free@passagetr.dev / PassageTR#2026!
phase1.pro@passagetr.dev / phase1.pro@passagetr.dev
phase1.developer@passagetr.dev / PassageTR#2026!
Admin panel için doğrudan kullanmanız gereken hesap:

phase1.admin@passagetr.dev
PassageTR#2026!

## 49. Mart 2026 Release Snapshot - v2.0.6

Bu bolum, ustteki daha eski ozetleri silmeden, bugunku release durumunu tek yerde sabitlemek icin eklenmistir.

Guncel release kimligi:

- release etiketi: `v2.0.6`
- build number: `6`
- student semantic version: `2.0.6+6`
- admin semantic version: `2.0.6+6`
- student production manifest: `https://passagetr-fef48.web.app/version.json`
- admin production manifest: `https://passagetr-admin.web.app/version.json`

Release metadata kaynaklari:

- `packages/shared_core/lib/src/workspace_info.dart`
- `packages/shared_core/lib/src/release/release_catalog.dart`
- `docs/release/CHANGELOG.md`
- `apps/student_app/pubspec.yaml`
- `apps/admin_console/pubspec.yaml`

Bu release'te kapanan ana basliklar:

- student weekly progress kartinda veri kaynagi seffaflastirildi
- haftalik ilerleme line chart yerine bar chart oldu
- reading detail odak kelime popup deneyimi sertlestirildi
- reading detail icinde onceki/sonraki parca gecisi eklendi
- admin tarafinda reading focus word auto-link SQL ve bulk action akisi eklendi
- grammar menu ve detail zinciri gercek DB ile hizalandi
- admin reading satirlarinda odak kelime sayisi ve preview gorunur hale geldi

Bu release'te dikkat edilmesi gerekenler:

- student web remote-first oldugu icin production deploy sonrasi yeni veri daha hizli gorunur
- Android APK offline-first oldugu icin content cache stale ise gorunur veride gecikme olabilir
- admin panel web-only oldugu icin production degisiklikleri dogrudan hosting bundle ile gorulur
- analytics verisi remote bulunursa gercek, bulunmazsa tahmini olarak etiketlenir

Release dogrulama minimumu:

1. `version.json` acilacak
2. `display_version` ve `build_number` kontrol edilecek
3. `student web /readings` acilacak
4. `student web /grammar` acilacak
5. `admin web /content/readings` acilacak
6. Android emulatorde release APK foreground dogrulanacak

## 50. Student App Mimarisi - Operasyonel Gorunum

`apps/student_app` bugun yalniz bir UI kabugu degildir.

Asagidaki katmanlar gercek urun davranisini birlikte olusturur:

- route ve shell katmani
- feature ekranlari
- Riverpod provider zinciri
- shared domain kontratlari
- shared data repository implementasyonlari
- offline local DB ve sync katmani
- Supabase remote istemcileri

Student uygulamasinda ana feature bloklari:

- home
- words
- readings
- grammar
- profile
- premium
- auth giris akislari

Home davranisi:

- haftalik ilerleme karti artik haftalik toplamlari kullanir
- veri kaynagi gercek analytics ise normal gorunum verilir
- fallback analytics ise `Tahmini veri` uyarisi cikar
- chart painter line yerine bar cizer

Words davranisi:

- paketler listelenir
- sifir elemanli paketler student listesinde gosterilmez
- free/pro ayrimi paket ve kart bazli devam eder
- lookup akislari platforma gore farkli veri kaynagi kullanabilir

Readings davranisi:

- liste sayfali calisir
- detay ekraninda sentence bazli ceviri ve inline etkileim vardir
- odak kelimeler paneli artik DB tabanli olabilir
- reading detail icinde onceki/sonraki passage kisa yolu vardir
- odak kelime popup'i hem metin icinden hem panelden acilabilir

Grammar davranisi:

- menu seed/mock yerine DB modullerini kullanir
- siralama `sira` alanina gore yapilir
- kullaniciya gosterilen index normalize edilir
- detail ekraninda `icerik_html`, ornekler ve testler gercek tablolardan gelir

Profile davranisi:

- kimliksiz kullanici icin auth girisi
- kimlikli kullanici icin plan, release ve profile surface
- release bilgisi dar layoutta burada gorunur

## 51. Student App Veri Stratejisi

PASSAGETR v2 student tarafinda tek veri modeli kullanmaz.

Platforma gore davranis degisir.

Android:

- offline-first
- local DB birinci kaynak olabilir
- stale sync penceresi vardir
- content degisikligi her zaman anlik gorunmeyebilir
- force refresh gerektiren ekranlar kritik yerlerde eklenir

Web:

- remote-first
- Supabase veya live RPC sonuclari onceliklidir
- local persistence varsa bile ana strateji canli veridir
- deploy sonrasi bundle dogrulamasi gerekir

Bu farkin sonucu olarak:

- ayni kullanici web ve Android'de ayni saniyede ayni listeyi gormeyebilir
- ozellikle grammar ve readings gibi content odakli ekranlarda cache etkisi gorulebilir
- hata analizinde once platform ayrimi yapilmalidir

Veri tazeligi icin bakilacak basliklar:

- local DB dolu mu
- sync stale window doldu mu
- route force refresh tetikliyor mu
- provider invalidate zinciri mutasyon sonrasi dogru mu
- production manifest yeni bundle'i isaret ediyor mu

## 52. Admin Console - Bugunku Kapsam

`apps/admin_console` artik yalniz temel CRUD denemesi degildir.

Gercek operasyon kapsami:

- login ve role gate
- users listesi
- invite akisi
- settings paneli
- dashboard analytics
- packs / words / readings / grammar yonetimi
- publish / draft mutasyonlari
- reading focus word auto-link aksiyonlari

Admin auth davranisi:

- admin role yoksa panel icine alinmaz
- login sonrasi claim refresh / role kontrol akisi vardir
- bootstrap cozulmeden route redirect etmez
- session expiry durumunda login'e geri doner

Users yuzeyi:

- liste server-side query ile gelir
- row action menu vardir
- invite istekleri edge function uzerinden gecer
- bulk rol veya plan degisiklikleri roadmap'te degerli alan olmaya devam eder

Readings yuzeyi:

- paged liste vardir
- row bazli auto-assign focus words vardir
- toolbar uzerinde tum reading'ler icin bulk auto-assign vardir
- satirda `odak N` chip'i ve preview vardir

Grammar yuzeyi:

- liste gercek DB kayitlariyla gelir
- durum filtreleri vardir
- child records iceren detail akisi mevcuttur

Settings yuzeyi:

- app settings RPC'leri ile calisir
- product config niteligindedir
- secret saklama katmani degildir

## 53. Shared Paketler - Kime Ne Ait

Bu repo icinde ortak kodun nerede tutuldugu nettir.

`packages/shared_core`

- release metadata
- ortak sabitler
- temel runtime bilgi yapilari
- uygulamalar arasi paylasilan teknik yardimci kod

`packages/shared_domain`

- entity tipleri
- repository kontratlari
- business-level data shape'leri
- uygulama ile data katmani arasindaki resmi sozlesme

`packages/shared_data`

- Supabase ve local DB repository implementasyonlari
- sync istemcileri
- remote/local bridge davranisi
- test fixture ve migration contract dogrulamalari

`packages/shared_ui`

- ortak widget parcalari
- ortak tema veya reusable UI bloklari
- iki app arasinda paylasilan gorsel yuzeyler

Kural:

- uygulama seviyesindeki feature karari `apps/*` altinda kalir
- veri okuma ve yazma implementasyonu `shared_data` altinda kalir
- tip ve kontrat `shared_domain` altinda tanimlanir
- release metadata gibi urun capinda ortak bilgi `shared_core` altina gider

## 54. Supabase Yuzeyleri - Operasyonel Envanter

Supabase repo icinde yalniz migration klasoru olarak dusunulmemelidir.

Kapsam:

- tablo semalari
- RPC fonksiyonlari
- edge function'lar
- RLS ve auth davranislari
- content degisim loglari

Bu projede sik dokunulan tablo aileleri:

- `words`
- `reading_passages`
- `reading_passage_sentences`
- `reading_passage_words`
- `reading_sentence_translations`
- `gramer_modulleri`
- `gramer_sayfalari`
- `gramer_ornekler`
- `gramer_testler`
- `user_daily_stats`
- `audit_logs`
- `app_settings`
- `entitlements`

Reading odak kelime akisi icin kritik tablo:

- `reading_passage_words`

Bu tablo:

- passage ile word karti arasindaki iliskiyi tutar
- sozluk sonucu degil kart iliskisi temsil eder
- admin panelden manuel veya otomatik doldurulabilir
- student reading detail paneli tarafindan kullanilir

Grammar akisi icin kritik tablolar:

- `gramer_modulleri`
- `gramer_sayfalari`
- `gramer_ornekler`
- `gramer_testler`

Analytics akisi icin kritik yuzey:

- `user_daily_stats`
- `fetch_user_daily_stats` benzeri RPC helper'lari

Admin tarafi icin kritik edge function:

- `admin_invite_users`

## 55. Reading Odak Kelime Mantigi

Odak kelime sistemi sozluk tabanli degildir.

Temel ilke:

- kaynak `public.words`
- iliski `reading_passage_words`
- panelde gorunenler passage'a baglanmis kartlardir

Bu nedenle:

- bir kelime passage metninde geciyor olabilir ama linklenmemisse panelde cikmaz
- bir kelime panelde gorunuyorsa, arkada gercek kart kaydi vardir
- popup'ta gosterilen anlam ve ornekler kart verisinden gelir

V2 auto-link mantigi:

- stop-word dislar
- function-word POS ailelerini dislar
- `n.`, `v.`, `adj.`, `adv.` gibi ogretim degeri daha yuksek kartlari oncelikler
- ayni `pack_id` baglamini avantaja cevirir
- passage basina maksimum 10 kart atar

Admin tarafinda iki otomasyon vardir:

- tekil passage icin auto-assign
- tum passage'lar icin only-missing bulk auto-assign

Only-missing politikasi ne demek:

- mevcut manuel linkler korunur
- zaten linki olan passage tekrar yazilmaz
- hic linki olmayanlar doldurulmaya calisilir

Student tarafi odak kelime popup davranisi:

- word uzerine tiklayinca popup acilir
- popup disina tiklayinca kapanir
- sag ustte carpiyla kapanir
- synonym veya antonym chip'ine tiklanirsa once kart aranir
- kart yoksa dictionary/fallback ceviri akisi devreye girer

## 56. Grammar Modulu - Gercek Veri Kurallari

Grammar modulu artik seed/mock fallback ile acilmamasi gereken yuzeylerden biridir.

Liste ekraninda:

- moduller `sira` alanina gore siralanir
- kullaniciya ham `id` gosterilmez
- yayinli filtrelenmis liste uzerinden 1-based gorunur sira uretilir
- kilit akisi su an yoktur

Detay ekraninda:

- sayfa basliklari `gramer_sayfalari` tablosundan gelir
- `icerik_html` rich content olarak render edilir
- ornekler `gramer_ornekler` tablosundan gelir
- quiz/test kayitlari `gramer_testler` tablosundan gelir
- progress kaydinda gercek `page_id` kullanilir

Progress acisindan dikkat:

- eski kayitlarda yanlis `page_id` bulunabilir
- resume mantigi once `lastPageNo` ile dogru sayfayi bulmaya calisir
- yeni progress yazildikca veri normalize olur

Admin tarafindan grammar guncellerken:

- sistem alanlari read-only tutulmalidir
- child record save mantigi snapshot replace olarak dusunulmelidir
- `toplam_sayfa` gibi turetilen alanlar UI'da manuel giris olmamalidir

## 57. Analytics ve Haftalik Ilerleme

Ana sayfadaki haftalik ilerleme karti artik asagidaki kurallarla okunmalidir.

Veri kaynagi kurali:

- authenticated + remote analytics var => gercek veri
- remote yok veya hata var => tahmini veri

Kartta degisenler:

- line chart yerine bar chart kullanilir
- haftalik toplam kelime sayisi gosterilir
- haftalik session/gun tamamlama odagi netlestirilir
- tahmini veri ise kullaniciya yazili olarak belirtilir

Bu degisiklik neden onemli:

- onceki sessiz fallback kullanicinin gercek aktiviteyi gordugunu varsaydiriyordu
- artik kalite acisindan daha dogru bir dil kullaniliyor
- operasyon tarafinda da log ile fallback sebebi gorulebiliyor

Analytics hatasi incelerken sirayla kontrol et:

1. kullanici login mi
2. Supabase aktif session var mi
3. analytics RPC veri donuyor mu
4. `user_daily_stats` dolu mu
5. UI tahmini veri etiketi gosteriyor mu

## 58. Script Envanteri - Kisa Aciklamali Liste

Bu bolum script adlarini tek tek aciklayarak repo icinde neyin ne ise yaradigini sabitler.

`build_app_content_db.py`

- local veya paketli content DB olusturma yardimcisi

`build_dictionary_asset.py`

- dictionary asset uretilmesi icin kullanilan script

`build_web_firebase.ps1`

- web build odakli script
- student veya admin hedefi icin kullanilir

`check_android_emulator_ready.ps1`

- Android emulator ve adb hazirlik kontrolu

`check_firebase_hosting_ready.ps1`

- Firebase hosting deploy oncesi ortam kontrolu

`deploy_web_firebase.ps1`

- analyze, test, build ve deploy adimlarini tek akista toplar

`ensure_utf8.ps1`

- dosya encoding kalitesini kontrol etmeye yardim eder

`import_dictionary.py`

- dictionary veri akislari icin import scripti

`import_static_content_supabase.py`

- statik icerigin Supabase tarafina alinmasinda kullanilabilir

`install_git_hooks.ps1`

- lokal hook kurulum yardimcisi

`live_smoke_playwright.js`

- canli smoke scriptlerinden biri

`live_smoke_playwright.spec.js`

- Playwright tabanli smoke spesifikasyonu

`load_figma_env.ps1`

- Figma bagli ortamlarda gereken env yukleme yardimcisi

`local_responsive_smoke_playwright.js`

- lokal responsive smoke senaryolari

`quality_gate.ps1`

- kalite adimlarini tek komutta calistirma araci

`release_preflight.ps1`

- release oncesi temel kontrol akisi

`run_flutter_dev.ps1`

- gelistirme ortaminda belirli app hedeflerini baslatma yardimcisi

`seed_supabase_phase1_test_accounts.ps1`

- seeded test hesaplarini hazirlama veya role fix akislari

`serve_static_web.ps1`

- lokal web servis etme yardimcisi

`smoke_live_ui.ps1`

- canli UI smoke scripti

`smoke_local_student_routes.ps1`

- lokal student route smoke

`smoke_web_auth.ps1`

- web auth akisi smoke

`smoke_web_responsive.ps1`

- responsive smoke

`upload_grammar.ps1`

- grammar icerigi yukleme/yardim akisi

`verify_supabase_rls.ps1`

- RLS dogrulama ve kritik guvenlik kontrolleri

`web_auth_smoke_playwright.js`

- web auth icin Playwright tabanli test akisi

`write_utf8.ps1`

- UTF-8 yazim/duzeltme yardimcisi

## 59. Faz Dosyalari - Ne Icin Varlar

Repo icindeki faz dosyalari yalniz tarihsel arsiv degildir.

Gercek amaclari:

- hangi karar hangi sirayla alindi gormek
- neden bu mimari tercih edildi anlamak
- verification path'lerini izlemek
- backlog'tan ayrisan tamamlanmis kapsami sabitlemek

Bugun gorulmesi gereken ana fazlar:

- `phase_00_kesif_kurulum_teknik_iskelet.md`
- `phase_01_auth_oturum_yonetimi_rbac.md`
- `phase_02_offline_first_veri_katmani.md`
- `phase_03_cekirdek_ogrenme_modulleri.md`
- `phase_04_okuma_ceviri_gramer.md`
- `phase_04_5_student_ui_parity_polish.md`
- `phase_05_admin_cms_icerik_operasyonlari.md`
- `phase_05_5_admin_console_hardening.md`
- `phase_06_analytics_streak_pro_paketleme.md`
- `phase_07_web_responsive_yayin_hazirligi.md`
- `phase_08_test_kalite_operasyonel_sertlestirme.md`
- `phase_09_canliya_alma_son_optimizasyon.md`
- `phase_10_production_ui_hardening.md`

Yeni bir issue alindiginda tavsiye edilen faz okuma sirasi:

1. ilgili domain fazi
2. onu etkileyen parity veya hardening fazi
3. verification kayitlari
4. mevcut kod

## 60. Student Web Deploy Runbook

Student web deploy tek komutla yapilabilir ama runbook zihinde net olmalidir.

Hazirlik:

- branch dogru mu
- release metadata guncel mi
- `pubspec.yaml` surumu arttirildi mi
- changelog eklendi mi
- gerekiyorsa smoke route'lari belirli mi

Calistirilacak tipik komut:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy_web_firebase.ps1 -AppName student_app -EnvironmentFile env/app.web.prod.json
```

Deploy sonrasi minimum dogrulama:

- `https://passagetr-fef48.web.app/version.json`
- `https://passagetr-fef48.web.app/`
- `https://passagetr-fef48.web.app/readings`
- `https://passagetr-fef48.web.app/grammar`
- `https://passagetr-fef48.web.app/changelog`

Beklenenler:

- yeni `version.json`
- route'lar 200
- kritik feature regression yok
- cache nedeniyle eski bundle gorunuyorsa hard refresh ile tekrar dene

Deploy sonrasi not dusulmesi gereken yerler:

- `docs/release/CHANGELOG.md`
- gerekiyorsa verification dosyalari
- gerekiyorsa ilgili faz veya report belgesi

## 61. Admin Web Deploy Runbook

Admin deploy student'tan ayri dusunulmelidir.

Temel fark:

- farkli hosting target
- farkli login surface
- role gate sebebiyle post-deploy smoke auth gerektirebilir

Ornek komut:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy_web_firebase.ps1 -AppName admin_console -EnvironmentFile env/app.web.prod.json
```

Deploy sonrasi bakilacaklar:

- `https://passagetr-admin.web.app/version.json`
- `/`
- `/users`
- `/content/readings`
- `/content/grammar`
- `/settings`

Admin deploy sonrasi ek kontrol:

- seeded admin hesapla login dene
- users listesi remote veri gosteriyor mu
- readings satirinda `odak N` chip'i gorunuyor mu
- bulk auto-assign diyalogu aciliyor mu

## 62. Android APK Release Runbook

Student Android APK release almak icin tipik yol:

```powershell
cd apps/student_app
flutter build apk --release --dart-define-from-file=..\\..\\env\\app.web.prod.json
```

Artefact yeri:

- `apps/student_app/build/app/outputs/flutter-apk/app-release.apk`

Emulator veya cihaza kurulum:

```powershell
flutter install -d emulator-5554 --use-application-binary build\\app\\outputs\\flutter-apk\\app-release.apk
```

Dogrulama:

- uygulama kuruldu mu
- app name beklenen sekilde mi
- ana ekran aciliyor mu
- readings ve grammar ekranlari aciliyor mu
- gerekiyorsa `adb shell dumpsys activity activities` ile foreground kontrol edilir

APK release sonrasi dikkat:

- Android offline-first oldugu icin content cache davranisi web ile birebir degildir
- grammar veya readings degisikliklerinde force refresh mantigi yoksa stale gorunum olabilir
- build numarasi ve release metadata UI'da dogru mu kontrol edilmelidir

## 63. Quality Gate Onerilen Sira

Her task ayni agirlikta degildir.

Ama production'a yakin her degisiklikte tavsiye edilen check zinciri su sekildedir:

1. hedef paket veya uygulama icin `dart analyze`
2. ilgili widget/unit testler
3. gerekiyorsa tum app test paketi
4. route smoke
5. canli smoke
6. deploy
7. deploy sonrasi smoke

Sik kullanilan komutlar:

```powershell
dart analyze apps/student_app packages/shared_domain packages/shared_data
flutter test apps/student_app
flutter test apps/admin_console
flutter test packages/shared_data
```

Admin tarafi icin ek contract kontrolu:

- migration contract testleri
- RPC shape degisikligi varsa repository mapping testleri

Student tarafi icin ek davranis kontrolleri:

- route aciliyor mu
- release metadata gozukuyor mu
- readings ve grammar gercek veriyle doluyor mu
- popup ve inline interaction'lar bozulmadi mi

## 64. Troubleshooting - Yeni Donem Notlari

### 64.1 Reading odak kelimeler gorunmuyor

Kontrol et:

- `reading_passage_words` tablosu dolu mu
- admin tarafinda ilgili passage satirinda `odak N` sifir mi
- student provider stale veri mi okuyor
- popup icin gereken word kartinda anlam/ornek alanlari mevcut mu

Muhtemel nedenler:

- hic link kaydi yok
- old bundle veya stale cache
- admin tarafinda bulk auto-assign henuz kosmadi
- ilgili kart `words` tablosunda publish edilmemis

### 64.2 Grammar modulu beklenen sayida gelmiyor

Kontrol et:

- `gramer_modulleri.is_published`
- `sira` alanlari
- student cache stale mi
- mobile force refresh tetikleniyor mu

### 64.3 Haftalik ilerleme supheli gorunuyor

Kontrol et:

- kartta `Tahmini veri` var mi
- kullanici login mi
- `user_daily_stats` dolu mu
- analytics RPC hata veriyor mu

### 64.4 Admin reading listesi bos veya hatali

Kontrol et:

- ilgili paged RPC hata veriyor mu
- preview fallback sessizce devreye girmemis olmali
- network error UI'da yuzeye cikmali
- auth/session durumu gecerli mi

### 64.5 Invite mail gitmiyor

Kontrol et:

- edge function deploy edildi mi
- Supabase auth mailer konfiguru mu
- rate limit dolu mu
- sender domain SPF/DKIM durumlari dogru mu

## 65. Test Hesaplari ve Yetki Duzeyleri

Repo icinde seeded hesaplar acikca tanimlidir.

Bugun tekrar listelenmesinin nedeni operasyon sirasinda README'nin tek kaynak olarak kullanilabilmesidir.

Hesaplar:

- `phase1.admin@passagetr.dev / PassageTR#2026!`
- `phase1.free@passagetr.dev / PassageTR#2026!`
- `phase1.pro@passagetr.dev / PassageTR#2026!`
- `phase1.developer@passagetr.dev / PassageTR#2026!`

Roller:

- `admin`: admin web operasyonu
- `free`: free user davranisi
- `pro`: premium/pro behavior smoke
- `developer`: yuksek yetkili teknik islemler

Notlar:

- admin web icin dogrudan `phase1.admin@passagetr.dev` kullanilmalidir
- role bozulursa seed script ile tekrar duzeltilebilir
- stale entitlements veya revoked role durumlari ayri kontrol edilmelidir

## 66. README Bakim Protokolu

Bu README buyuk tutuluyor.

Bu bilincli bir karar.

Sebep:

- repo fazla faz biriktirdi
- production ve rewrite ayni anda aciklanmak zorunda
- yeni gelen kisi yalniz kisa bir quickstart ile resmi anlayamaz

README guncellenirken su kurallar tercih edilmelidir:

- mevcut satirlari sebepsiz silme
- eski notlarin ustune yeni guncel snapshot ekle
- surum degisirse release snapshot bolumu ekle
- script adi degisirse runbook'u da guncelle
- canli URL degisirse hem bas kisimda hem hizli link ozetinde guncelle
- phase ve backlog belgeleriyle celiski birakma

Ne zaman guncelleme zorunludur:

- semantic version degistiginde
- yeni deploy scripti geldiyse
- auth veya role gate degistiyse
- analytics, reading, grammar gibi ana modullerden biri farkli calismaya basladiysa
- canli smoke akisi degistiyse

README ile sync tutulmasi gereken dosyalar:

- `PROJECT_CONTEXT.md`
- ilgili faz dosyalari
- `docs/release/CHANGELOG.md`
- kritik verification notlari

## 67. Student Feature Checklist - Ayrintili

Bu liste, student app tarafinda bugunku ozellik setinin pratik kontrol listesi olarak kullanilabilir.

Home:

- haftalik ilerleme karti aciliyor mu
- chart bar chart mi
- tahmini veri etiketi dogru yerde mi
- premium kartlar beklenen durumda mi

Words:

- paket listesi geliyor mu
- sifir elemanli paketler gizli mi
- free/pro ayrimi calisiyor mu
- kart popup veya drilldown mantigi bozulmadi mi

Readings:

- reading listesi aciliyor mu
- detay ekraninda sentence bloklari gorunuyor mu
- inline kelime vurgusu var mi
- popup acilip kapanabiliyor mu
- onceki/sonraki passage gecisi calisiyor mu
- odak kelimeler paneli dolu mu

Grammar:

- menu gercek konulari gosteriyor mu
- ham `57.` benzeri id gorunmuyor mu
- detail sayfasi aciliyor mu
- testler render oluyor mu
- progress bir sonraki sayfaya akiyor mu

Profile:

- anonim durumda giris ekranina gidiyor mu
- kimlikli durumda release karti gorunuyor mu
- changelog route'u aciliyor mu

## 68. Admin Feature Checklist - Ayrintili

Login:

- admin olmayan kullanici iceri alinmiyor mu
- session expiry sonrasi login'e donuyor mu

Users:

- liste dolu mu
- filtreler calisiyor mu
- row action menu aciliyor mu
- invite diyalogu hata yuzeyini dogru gosteriyor mu

Content Words:

- arama filtreleri calisiyor mu
- status filtresi calisiyor mu
- satir mutasyonlari ayni ekranda yansiyor mu

Content Readings:

- paged liste geliyor mu
- `odak N` satirda gorunuyor mu
- tekil auto-assign calisiyor mu
- bulk auto-assign diyalogu aciliyor mu
- auto-assign sonrasi liste refresh oluyor mu

Content Grammar:

- durum filtresi calisiyor mu
- liste gercek kayitlari gosteriyor mu
- detail kayit akisi child record'larda tutarli mi

Settings:

- tablar arasi gecis sorunsuz mu
- dirty state save/reset davranisi net mi
- kayit sonrasi optimistic feedback var mi

Dashboard:

- 7/30/90 gun filtreleri gorunuyor mu
- KPI delta badge'leri dolu mu
- sistem durum karti beklenen degerleri gosteriyor mu

## 69. Canli Smoke Oneri Seti

Canli deploy sonrasi minimum smoke her zaman ayni agirlikta olmayabilir.

Ama asagidaki set dengeli bir baseline verir.

Student smoke:

1. `/`
2. `/readings`
3. ilk reading detail
4. odak kelime popup ac-kapat
5. `/grammar`
6. ilk grammar detail
7. `/profile`
8. `/changelog`

Admin smoke:

1. `/`
2. login
3. `/users`
4. `/content/readings`
5. tek reading auto-assign
6. `/content/grammar`
7. `/settings`

APK smoke:

1. app launch
2. home acilisi
3. readings detaya git
4. grammar ac
5. profile ac

Smoke sirasinda en degerli kanitlar:

- screenshot
- `version.json`
- test cikti ozeti
- deploy komutu sonucu

## 70. Bilinen Sinirlar ve Acik Alanlar

Bu README buyudugu icin acik alanlari da net yazmak gerekir.

Bugun hala dikkat isteyen noktalar:

- Android stale cache davranislari belirli ekranlarda kullanici tarafindan gec gorulebilir
- invite email akisi Supabase mailer/rate limit bagimliligi tasir
- admin bulk operasyonlari daha da zenginlestirilebilir
- reading focus word secimi heuristik bazlidir, pedagogik manuel review her zaman daha kaliteli sonuc verebilir
- analytics fallback hala urun icin gereklidir; tam remote-guaranteed model degildir

Bunlar bug mutlaka vardir anlamina gelmez.

Ama teknik gerceklik olarak bilinmelidir.

## 71. Onboarding - Ilk 90 Dakika

Yeni gelen gelistirici icin onerilen hizli uyum akisi:

Ilk 15 dakika:

- README oku
- repo yapisini gez
- aktif branch'i gor

15-30 dakika:

- faz dosyalarini tara
- changelog ve release metadata'yi kontrol et

30-45 dakika:

- student app ve admin app klasorlerini incele
- shared paketlerin gorev dagilimini not al

45-60 dakika:

- quality gate veya analyze calistir
- lokal route smoke mantigini oku

60-75 dakika:

- student web veya admin web lokal ac
- provider -> repository -> Supabase akisini izle

75-90 dakika:

- kucuk bir issue sec
- mevcut davranisi reproduse et
- sonra kod degisikligine gec

## 72. Ayrintili Komut Notlari

Student analyze:

```powershell
dart analyze apps/student_app packages/shared_domain packages/shared_data
```

Admin analyze:

```powershell
dart analyze apps/admin_console packages/shared_domain packages/shared_data
```

Student test:

```powershell
flutter test apps/student_app
```

Admin test:

```powershell
flutter test apps/admin_console
```

Shared data test:

```powershell
flutter test packages/shared_data
```

Student web deploy:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy_web_firebase.ps1 -AppName student_app -EnvironmentFile env/app.web.prod.json
```

Admin web deploy:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy_web_firebase.ps1 -AppName admin_console -EnvironmentFile env/app.web.prod.json
```

Release APK build:

```powershell
cd apps/student_app
flutter build apk --release --dart-define-from-file=..\\..\\env\\app.web.prod.json
```

Emulator install:

```powershell
flutter install -d emulator-5554 --use-application-binary build\\app\\outputs\\flutter-apk\\app-release.apk
```

## 73. Readme Son Ek Notu - Neden Buyuk Tutuldu

Bu README'nin 1200 satira dogru buyumesi tesaduf degildir.

Bu repo:

- rewrite tarihi tasir
- production operasyonu tasir
- coklu Flutter app barindirir
- Supabase migration ve hosting akislari biriktirir
- yeni katilan biri icin baglam kaybi riski tasir

Bu yuzden kisa bir landing page yerine genis bir calisma rehberi tercih edilmistir.

Ileride daha da buyurse iki sey korunmalidir:

- eski kritik bilgi sebepsiz silinmemeli
- yeni snapshot bolumleri eklenerek dokuman canli tutulmalidir
