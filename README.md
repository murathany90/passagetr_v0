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
- okuma detay ve çeviri katmanı
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

### 11.2 Faz 10 Sonucu

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
powershell -ExecutionPolicy Bypass -File .\scripts\build_web_firebase.ps1 -AppName student_app -EnvironmentFile env/app.web.prod.json
```

Admin web build:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_web_firebase.ps1 -AppName admin_console -EnvironmentFile env/app.web.prod.json
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
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_web_firebase.ps1 -AppName admin_console -EnvironmentFile env/app.web.prod.json
```

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

## 47. Son Not

Bu doküman düzenli olarak güncellenmelidir.

Özellikle şu durumlarda README güncellemesi yapılması önerilir:

- yeni faz açılırsa
- production URL değişirse
- deploy scriptleri değişirse
- workspace yapısı değişirse
- yeni smoke veya quality gate eklendiyse

README ile faz dosyalarının çelişmemesi temel kuraldır.
