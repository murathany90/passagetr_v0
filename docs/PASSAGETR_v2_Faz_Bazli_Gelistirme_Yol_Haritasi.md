# PASSAGETR v2 - Faz Bazli Gelistirme Yol Haritasi

> Proje: PASSAGETR v2  
> Hedef platformlar: Android + Web  
> Mimari karar: Android offline-first, Web remote-first  
> Durum: v2 controlled rewrite foundation  
> Tarih: 8 Mart 2026

---

## 1. Executive Summary

PASSAGETR v2, mevcut v1 urununun sifirdan yazilan ama veri modeli ve icerik domainleri korunan yeni nesil surumudur. Bu calisma greenfield bir urun degil; kontrollu rewrite + schema evolution isidir.

Temel strateji:

- `main`, v1 uygulamasinin arsiv dalidir.
- v2 gelistirmesi `v2-rewrite-foundation` branch'inde ilerler.
- v1 veritabani mantigi, icerik domainleri ve Supabase migration gecmisi korunur.
- Mevcut UI, deployment ve uygulama implementasyonu referans olarak arsivlenir; v2 icin yeni monorepo iskeleti kurulur.
- Ayni repo icinde iki ayri Flutter uygulamasi bulunur:
  - `apps/student_app`
  - `apps/admin_console`

Bu yol haritasi, v2'nin urun stratejisini, veri koruma sinirlarini, branch/reset modelini, hedef workspace topolojisini ve ilk sprint teslimlerini implementeri karar vermeye zorlamadan tanimlar.

---

## 2. v1'den Korunacak Temeller

### 2.1 Korunacak urun domainleri

v2'de asagidaki domainler korunur ve schema evolution ile tasinır:

- `packs`
- `words`
- `reading_passages`
- `reading_passage_sentences`
- `reading_passage_words`
- `reading_sentence_translations`
- grammar module / page / example / test yapisi
- `user_word_progress`
- `user_reading_progress`
- `user_reading_bookmarks`
- `user_reading_favorites`
- auth / role / premium erisim mantigi

### 2.2 Korunacak repo varliklari

v2 resetinde asagidaki alanlar korunur:

- `docs/`
- `docs/ui_tasarim/`
- `DATABASE_SCHEMA.md`
- `supabase/`
- `assets/` altindaki ham icerik ve veritabani kaynaklari
- `scripts/` altindaki import / build / deploy pipeline dosyalari
- `env/*.example`
- gerekiyorsa v2'ye uyarlanmis `README.md`

### 2.3 Arsivlenecek veya temizlenecek alanlar

v2 resetinde mevcut uygulama implementasyonu sifirlanir:

- `lib/`
- `test/`
- `android/`
- `ios/`
- `macos/`
- `linux/`
- `windows/`
- `web/`
- mevcut tek-app Flutter yapisina ait root `pubspec.yaml` ve `pubspec.lock`

Gecici ve uretilmis alanlar temizlenir:

- `.dart_tool/`
- `build/`
- `.firebase/`
- `artifacts/`
- `test-results/`
- `scripts/__pycache__/`
- `supabase/.temp/`

Belirsiz ama potansiyel operasyonel degeri olan alanlar silinmez; siniflandirilir:

- `json_output/`
- eski smoke test dokumanlari
- manuel test dokumanlari
- kopya roadmap veya prompt dosyalari

---

## 3. Temel Mimari Kararlar

### 3.1 Platform stratejisi

- Android: `offline-first`
- Web: `remote-first`
- Admin: web-oncelikli, ayri Flutter app

### 3.2 Veri otoritesi

- Icerik verisi: server-authoritative
- Kullanici ilerlemesi: user-owned, syncable
- Mobil yazma islemleri: once local outbox, sonra remote apply
- Web: local SQLite asset tasimaz; TTL cache + lazy loading kullanir

### 3.3 Guvenlik modeli

- Supabase ana backend'dir
- RLS zorunludur
- `service_role` hicbir istemciye gomulmez
- UI gating yalniz gorunurluk saglar; nihai guvenlik DB ve server-side katmandadir
- Roller:
  - `developer`
  - `admin`
  - `pro`
  - `free`

### 3.4 Uygulama ve workspace topolojisi

v2 tek repo icinde monorepo yapisinda ilerler:

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
  db/
  content/
docs/
  ui_tasarim/
  archive/
scripts/
supabase/
```

### 3.5 Katman yapisi

Paylasilan paketler icinde asagidaki ayrim korunur:

```text
shared_core/
  config/
  auth/
  theme/
  routing/
  errors/
  utils/

shared_domain/
  entities/
  value_objects/
  repositories/
  services/

shared_data/
  local/
    drift/
    daos/
    sync/
  remote/
    supabase/
    functions/
  repositories/

shared_ui/
  tokens/
  components/
  layouts/
  patterns/
```

### 3.6 Repository stratejisi

- Mobilde hibrit repository:
  - local read
  - background sync
  - outbox write
  - delta pull
- Web'de remote-first repository:
  - Supabase read
  - memory cache + TTL
  - stale-while-revalidate
- Ayrı repository siniflari:
  - `PackRepository`
  - `WordRepository`
  - `ReadingRepository`
  - `GrammarRepository`
  - `ProgressRepository`
  - `AdminContentRepository`

---

## 4. Offline-First ve Schema Evolution

### 4.1 Mobil sync modeli

Mobil istemci icin su yapilar zorunludur:

- Drift tabanli `AppDatabase`
- `sync_meta`
- `sync_outbox`
- `content_versions`
- `updated_at` / `event_id` / `dirty` benzeri deterministik sync alanlari

### 4.2 Conflict resolution varsayilanlari

- Icerik tablolarinda conflict yoktur; server her zaman otoritedir.
- Kullanici ilerlemesinde varsayilan politika `Last Write Wins` olur.
- Sayaç alanlarinda gerekiyorsa merge uygulanir.
- Sync islemleri idempotent RPC veya Edge Function uzerinden islenir.

### 4.3 Supabase schema evolution kurali

- v1 tablolari oldugu gibi yeniden tasarlanmaz; migration ile evrimlestirilir.
- Yeni tablo ve alanlar migration-first ilerler.
- Ilk eklenecek tablolar:
  - `profiles`
  - `user_roles`
  - `entitlements`
  - `user_test_attempts`
  - `user_grammar_progress`
  - `user_daily_stats`
  - `content_versions`
  - `content_change_log`
  - `audit_logs`
  - `media_assets`

---

## 5. Branch ve Repo Reset Stratejisi

### 5.1 Git stratejisi

- `main`: v1 arsiv durumu
- Guvenli etiket: `v1-archive-2026-03-08`
- Yeni calisma dali: `v2-rewrite-foundation`

### 5.2 Reset kurali

Reset, veri ve operasyon katmanlarini silmeden yalniz uygulama implementasyonunu temizler.

Korunacak eksen:

- veri modeli
- migration gecmisi
- import/build/deploy pipeline
- UI referanslari
- teknik karar dokumanlari

Silinecek eksen:

- v1 uygulama kodu
- v1 testleri
- v1 platform kabugu
- build/cache/artifact alanlari

### 5.3 Arsiv klasorlugu

v1'e ait referans dokumanlar `docs/archive/v1/` altinda toplanir:

- eski MVP planlari
- eski smoke checklist dosyalari
- manuel UI test raporlari
- kopya dokumanlar

---

## 6. Faz Bazli Geliştirme Yol Haritasi

## Faz 0A - Dokuman Sonlandirma

### Hedef
v2 icin tek kaynak teknik karar setini netlestirmek.

### Teknik isler
- roadmap ve prompt tekrarlarini ayirmak
- encoding/UTF-8 normalize etmek
- branch/reset kararlarini belgeye eklemek
- v1 korunacak alanlar listesini sabitlemek

### Kabul kriterleri
- roadmap karar kaynagi olarak okunabilir
- prompt agent gorev tanimi olarak kullanilabilir
- mojibake yok

---

## Faz 0B - Branch, Arsiv ve Reset

### Hedef
v1'i kaybetmeden v2 icin temiz calisma zemini olusturmak.

### Teknik isler
- `v1-archive-2026-03-08` etiketi
- `v2-rewrite-foundation` dali
- `docs/archive/v1/` yapisinin olusturulmasi
- keep/delete siniflandirmasi
- mevcut app implementasyonunun temizlenmesi

### Kabul kriterleri
- v1 arsivlenmis olur
- v2 branch temiz acilir
- korunacak veri/dokuman klasorleri kalir

---

## Faz 0C - Workspace Bootstrap

### Hedef
v2 monorepo iskeletini calisan ama bos foundation olarak kurmak.

### Teknik isler
- `apps/student_app`
- `apps/admin_console`
- `packages/shared_core`
- `packages/shared_domain`
- `packages/shared_data`
- `packages/shared_ui`
- root workspace/melos yapisi
- ortak lints, env example, CI skeleton
- temel theme + routing + shell scaffold

### Kabul kriterleri
- student_app web/android acilir
- admin_console web acilir
- ortak paket baglantilari calisir

---

## Faz 1 - Foundation + Auth + RBAC

### Hedef
kimlik, oturum ve rol omurgasini kurmak.

### Teknik isler
- Supabase auth entegrasyonu
- anon session
- email/password upgrade
- `profiles`, `user_roles`, `entitlements`
- auth guard / admin guard / premium gate
- RLS ilk paket

### Kabul kriterleri
- `free/pro/admin/developer` ayrimi gorulur
- admin route DB ve UI tarafinda korunur

---

## Faz 2 - Mobile Offline Data + Schema Evolution

### Hedef
mobil veri katmani ve sync omurgasini kurmak.

### Teknik isler
- Drift local schema
- DAO katmani
- `sync_meta`, `sync_outbox`
- delta pull
- outbox push
- content version invalidation

### Kabul kriterleri
- mobil offline read yapar
- ilerleme offline kaybolmaz
- online olunca sync olur

---

## Faz 3 - Student Core MVP

### Hedef
ogrenci urununun temel ogrenme akislarini yeniden acmak.

### Teknik isler
- packs/words
- kelime listesi + arama
- flashcard
- temel test merkezi
- reading basic
- progress persistence

### Kabul kriterleri
- kullanici paket secer ve calisir
- flashcard ve progress calisir
- reading basic acilir

---

## Faz 4 - Reading Advanced + Grammar

### Teknik isler
- sentence translation cache
- bookmarks/favorites
- grammar module/page/example/test
- TTS ayarlari
- premium gating

---

## Faz 5 - Admin CMS

### Teknik isler
- admin shell
- kelime/reading/grammar/test CRUD
- preview
- publish / unpublish
- bulk import
- audit log

---

## Faz 6 - Analytics + Pro

### Teknik isler
- daily stats
- streak
- quota / entitlement
- analytics dashboard
- monetization readiness

---

## Faz 7 - Web Production Readiness

### Teknik isler
- responsive shell
- deferred admin load
- asset pruning
- hosting pipeline
- LCP / bundle optimizasyonu

---

## Faz 8 - Test ve Operasyonel Sertlestirme

### Teknik isler
- unit / repository / widget testleri
- migration testleri
- RLS smoke testleri
- beta / rollback plani

---

## Faz 9 - Canliya Alma

### Teknik isler
- production migration freeze
- seed / initial content load
- staged rollout
- support playbook
- first-30-day monitoring

---

## 7. Ilk 3 Sprint Teslim Siniri

### Sprint 1
- branch/reset tamam
- monorepo/workspace olusmus
- student_app ve admin_console bos shell veriyor
- ortak paketler compile oluyor

### Sprint 2
- auth + profiles + roles + entitlements
- basic route guard
- shared theme ve responsive shell

### Sprint 3
- Drift foundation
- sync_meta + sync_outbox
- pack list + word list temel akisi

Bu uc sprint sonunda ekip; arsivlenmis v1, net v2 workspace, auth/RBAC omurgasi ve offline data foundation'a sahip olmalidir.

---

## 8. Riskler ve Azaltma Plani

| Risk | Etki | Azaltma |
|---|---|---|
| v1 davranisinin kaybolmasi | Yuksek | v1 arsiv etiketi + docs/archive |
| schema evolution'in dagilmasi | Cok yuksek | migration-first disiplin |
| mobile offline kapsam sismesi | Yuksek | Faz 2'de yalniz foundation teslimi |
| admin panelin scope sismesi | Orta | Faz 5'e ertelenmis ayri app |
| web bundle sismesi | Orta | remote-first + lazy load |
| tekrar eden karar dokumanlari | Orta | roadmap/prompt rol ayrimi |

---

## 9. Son Kararlar

- Bu proje greenfield degil, controlled rewrite'tir.
- `main` v1 arsivdir; aktif gelistirme `v2-rewrite-foundation` dalinda yapilir.
- Android offline-first, web remote-first olarak kalir.
- `student_app` ve `admin_console` ayri uygulama girisleridir.
- Veritabani korunur; uygulama kabugu yeniden kurulur.
