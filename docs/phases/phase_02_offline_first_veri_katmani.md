# Faz 2 - Offline First Veri Katmani

## 1. Faz Amaci
Android icin Drift tabanli lokal veri omurgasini, sync teknik tablolarini ve repository tabanli offline-first iskeleti acmak.

## 2. Kapsam
- Drift `AppDatabase`
- `sync_meta` ve `sync_outbox` lokal tablolari
- `content_delta_cache` lokal delta aynasi
- `FoundationSyncRepository` lokal stale kontrolu, remote delta pull ve outbox flush akisi
- `FoundationProgressRepository` outbox enqueue ve conflict resolve akisi
- Mobil baglanti geri geldiginde otomatik sync tetikleme
- `student_app` tarafinda mobil odakli veritabani provider iskeleti

## 3. Kapsam Disi
- CMS mutasyonlari
- Analytics
- Lokal content mirror repository'lerinin UI ile tam baglanmasi
- Gelismis conflict policy'ler (`user_word_progress`, `user_grammar_progress`, test denemeleri)

## 4. Yapilacak Isler
- [x] Faz dosyasini Faz 2 kapsamiyla guncelle
- [x] Drift `AppDatabase` iskeletini ekle
- [x] `sync_meta` ve `sync_outbox` tablolarini lokal tarafta olustur
- [x] Lokal kayit modellerini schema ile hizala
- [x] `FoundationSyncRepository` icin stale/touch davranisini ekle
- [x] `FoundationProgressRepository` icin outbox enqueue davranisini ekle
- [x] `student_app` provider katmanina mobil veritabani iskeletini bagla
- [x] Content delta cache tablosunu ekle
- [x] Supabase tabanli remote sync client ekle
- [x] `pull_content_changes` RPC'sini lokal cache'e bagla
- [x] Pending outbox event'lerini ilgili RPC'lere flush et
- [x] Desteklenen progress event'leri icin lokal outbox conflict resolver ekle
- [x] Mobil baglanti geri geldiginde otomatik sync tetikle
- [x] Lokal `content_entity_cache` aynasini ekle
- [x] Content delta kayitlarini lokal entity cache'e uygula
- [x] Remote bootstrap ile lokal content mirror'u doldur
- [x] `user_word_progress` ve `user_grammar_progress` snapshot cache'ini ekle
- [x] Idempotent word/grammar/test progress event semantigini ac
- [x] Retry/backoff sertlestirmesini ekle
- [x] Paket testlerini ekle
- [x] Analyze, test ve web/apk build dogrulamasini kaydet

## 5. Teknik Kararlar
- Android runtime veri otoritesi Drift'tir
- Web build lokal SQLite asset veya agir DB worker tasimaz
- Web tarafi bu fazda preview/no-op sync repository ile devam eder
- Drift icin kod uretimine girmeden `customStatement` / `customSelect` tabanli ilk iskelet acilir
- Lokal tablo adlari roadmap ile sabit kalir: `sync_meta`, `sync_outbox`, `content_delta_cache`
- Content delta aynasi remote `content_change_log` kayitlarini lokal bootstrap/preview cache'i olarak tutar
- Progress event'lerinde lokal merge kurali sabittir: `user_reading_progress` icin `completed = OR` ve `last_idx = max`; bookmark/favorite icin son istenen set durumu kazanir
- Baglanti geri geldiginde sync tetikleme yalniz mobilde ve Supabase env'i aktifse devreye girer

## 6. Bagimliliklar
- Faz 1 auth/RBAC omurgasi
- Supabase migration seti `020-024`
- `shared_domain` icindeki `OutboxEvent` ve `SyncScope`

## 7. Riskler
- Outbox status modeli gercek flush gelmeden fazla erken soyutlanabilir
- Web build ile mobil Drift baglantisini ayni pakette tasirken platform ayrimi dogru kurulmalidir
- Drift baglantisi test ortaminda dosya yerine memory executor kullanilmazsa testler kirilgan olur
- Lokal cache katmani fazla generic kalirsa repository mapping karmasiklasabilir

## 8. Test ve Kabul Kriterleri
- `sync_meta` kaydi yazilip tekrar okunabilir
- `sync_outbox` kaydi enqueue edilebilir
- `syncIfStale` stale durumda remote delta cekip cursor'u gunceller
- Pending outbox event'leri uygun RPC'lere flush edilip status guncellenir
- Desteklenen progress event'leri lokal kuyrukta merge edilir
- Mobil baglanti geri geldiginde sync tekrar tetiklenir
- Lokal content mirror cache'inden pack/word/reading/grammar verisi okunabilir
- Word ve grammar progress snapshot'lari lokal ve remote arasinda tutarlidir
- `student_app` web build kirilmaz
- `student_app` APK build kirilmaz

## 9. Ilerleme Durumu
- Durum: Tamamlandi
- Son guncelleme: 2026-03-09

## 10. Tamamlananlar / Notlar
- Faz dosyasi Faz 2 is kapsamiyla detaylandirildi
- Roadmap referansi korunuyor: mobilde Drift, webde remote-first/no-op lokal DB
- Bu fazda amac tam sync degil, Faz 3-4'un ustune oturacagi lokal omurgayi acmaktir
- `packages/shared_data/lib/src/local/drift/app_database.dart` eklendi
- Drift tarafinda `sync_meta`, `sync_outbox` ve `content_delta_cache` tablolarini olusturan migration strategy acildi
- `LocalSyncStore` arayuzu eklendi; repository testleri native sqlite bagimliligindan bu arayuz uzerinden izole edildi
- `SyncRemoteClient` / `SupabaseSyncRemoteClient` eklendi; content delta pull, bootstrap mirror, progress snapshot cekme ve progress outbox flush RPC katmani acildi
- `FoundationSyncRepository` stale kontrolunun otesine gecip remote delta cekme, lokal `content_entity_cache` aynasini guncelleme, cursor guncelleme ve pending/failed outbox flush etme davranislarini aldi
- `FoundationProgressRepository` `OutboxEvent` kayitlarini lokal pending queue'ya yaziyor; reading, bookmark/favorite, word progress, grammar progress ve test attempt event'lerinde duplicate kayitlari merge ediyor
- Lokal `progress_snapshot_cache` eklendi; `user_word_progress`, `user_reading_progress` ve `user_grammar_progress` snapshot'lari remote ile senkronize ediliyor
- Retry/backoff ve dead-letter kural seti `sync_outbox` icin acildi
- `202603090025_content_delta_scope_expansion.sql` ve `202603090026_progress_event_rpcs.sql` migration'lari remote Supabase projesine push edildi
- `student_app` provider katmanina mobilde `AppDatabase`, remote sync client ve baglanti geri geldiginde otomatik sync tetigi eklendi; webde preview/no-op sync karari korunuyor
- Regresyon kanit klasorleri:
  - `docs/verification/phase02_offline_foundation/`
  - `docs/verification/phase02_sync_connectivity/`
- Dogrulanan komutlar:
  - `flutter analyze`
  - `flutter test packages/shared_data`
  - `flutter test apps/student_app`
  - `flutter test apps/admin_console`
  - `flutter build apk --debug --dart-define-from-file=C:\\yazilim_projeler\\passagetr_v0\\env\\app.web.json`
  - `flutter build web --release --dart-define-from-file=C:\\yazilim_projeler\\passagetr_v0\\env\\app.web.json` (`apps/student_app`)
  - `flutter build web --release --dart-define-from-file=C:\\yazilim_projeler\\passagetr_v0\\env\\app.web.json` (`apps/admin_console`)
  - `supabase db push`
- Faz 2 kapanis notu:
  - Okuma/gramer UI regression widget coverage'i Faz 4 veri bagli testlerinde derinlestirilecek
