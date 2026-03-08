# PASSAGETR v2 - Faz Bazl? Geli?tirme Yol Haritas?

> Proje: PASSAGETR v2  
> Hedef platformlar: Android + Web  
> Mimari karar: Android offline-first, Web remote-first  
> Durum: v2 controlled rewrite foundation  
> Tarih: 8 Mart 2026

---

## 1. Executive Summary

PASSAGETR v2, mevcut v1 ?r?n?n?n s?f?rdan yaz?lan ama veri modeli ve i?erik domainleri korunan yeni nesil s?r?m?d?r. Bu ?al??ma greenfield bir ?r?n de?il; controlled rewrite + schema evolution i?idir.

Temel strateji:

- `main`, v1 uygulamas?n?n ar?iv dal?d?r.
- v2 geli?tirmesi `v2-rewrite-foundation` branch'inde ilerler.
- v1 veritaban? mant???, i?erik domainleri ve Supabase migration ge?mi?i korunur.
- Mevcut UI, deployment ve uygulama implementasyonu referans olarak ar?ivlenir; v2 i?in yeni monorepo iskeleti kurulur.
- Ayn? repo i?inde iki ayr? Flutter uygulamas? bulunur:
  - `apps/student_app`
  - `apps/admin_console`

Bu yol haritas?, v2'nin ?r?n stratejisini, veri koruma s?n?rlar?n?, branch/reset modelini, hedef workspace topolojisini ve ilk sprint teslimlerini implementeri yeniden karar vermeye zorlamadan tan?mlar.

---

## 2. Vizyon ve Stratejik Hedefler

PASSAGETR v2'nin amac? mevcut uygulaman?n i?levlerini yaln?zca yeniden ?retmek de?il; onlar? daha g?venli, daha ?l?eklenebilir, daha h?zl? y?netilebilir ve ?oklu platforma uygun bir ?r?n mimarisine d?n??t?rmektir.

Yeni sistemin stratejik hedefleri:

1. **Tek ?r?n, ?oklu platform**
   - Flutter ile Android ve Web istemcilerini ayn? repo ve ortak domain modeli ile ?retmek.
   - Ortak i? kurallar?n? korurken platforma g?re veri eri?im stratejisini ay?rmak.

2. **Kesintisiz ??renme deneyimi**
   - Android uygulamas?nda kullan?c? internet olmasa bile kelime, flashcard, okuma ve gramer mod?llerini kullanabilmelidir.
   - Kullan?c? ilerlemesi ba?lant? geldi?inde g?venli ve deterministik bi?imde senkronize edilmelidir.

3. **??erik operasyonlar?n? geli?tirici ba??ml?l???ndan kurtarmak**
   - Admin kullan?c?lar? kelime, test, okuma, gramer ve medya i?eriklerini CMS ?zerinden y?netebilmelidir.
   - ??erik ?retim s?reci script odakl? ak??tan do?rulama, preview ve publish ad?mlar? olan ?r?n ak???na d?n??melidir.

4. **Yetkilendirmeyi veritaban? ?ekirde?ine ta??mak**
   - Developer, Admin, Pro ve Free ayr?m? yaln?z UI seviyesinde de?il, Supabase RLS seviyesinde de korunmal?d?r.
   - Premium i?erik, y?netim ekranlar? ve kullan?c? verileri ?ift katmanl? g?venlikle korunmal?d?r.

5. **Web performans?n? ?r?n standard?na ??karmak**
   - Web s?r?m?nde mobil i?in haz?rlanm?? a??r yerel SQLite asset'leri ta??nmamal?d?r.
   - ?lk a??l?? s?resi d???r?lmeli, i?erikler lazy-load edilmeli ve admin mod?lleri gerekti?inde y?klenmelidir.

6. **Ya?ayan bir platform kurmak**
   - Yeni mod?l eklenmesini kolayla?t?ran katmanl? mimari, migration disiplini, test altyap?s? ve CI/CD s?reci kurulmal?d?r.

---

## 3. Tasar?m ve ?r?n ?lkeleri

### 3.1 Mimari ilkeler

- **Domain-first**: Kod organizasyonu ekranlara g?re de?il, i? alanlar?na g?re ?ekillenmelidir.
- **Repository abstraction**: UI katman? Supabase, Drift veya ba?ka veri kayna??n? do?rudan bilmemelidir.
- **Offline write safety**: Mobilde kullan?c? etkile?imleri ?nce yerel olarak i?lenmeli, sonra sunucuya g?nderilmelidir.
- **Server-authoritative content**: ??erik tablolar?nda nihai otorite sunucudur.
- **User-owned progress**: Kullan?c? ilerleme verileri kullan?c?ya aittir; sorgular ve g?ncellemeler `auth.uid()` ekseninde korunmal?d?r.
- **Incremental sync**: T?m i?eri?i yeniden indirmek yerine yaln?z de?i?en sat?rlar ta??nmal?d?r.
- **Soft-delete ve publish ak???**: ??erikler fiziksel silme yerine yay?n durumuyla y?netilmelidir.

### 3.2 UX ilkeleri

- Mobil ak??lar tek elle kullan?m, h?zl? geri d?n?? ve d???k ba?lant? ko?ullar? d???n?lerek tasarlanmal?d?r.
- Web taraf?nda `NavigationRail`, iki/?? kolonlu i?erik d?zeni ve geni? ekran ?retkenli?i esas al?nmal?d?r.
- `docs/ui_tasarim` klas?r? spacing, component breakdown, responsive davran?? ve tema i?in ana referanst?r.
- Dark ve light mod semantic color token'lar ve eri?ilebilir kontrast oranlar?yla tasarlanmal?d?r.

---

## 4. v1'den Korunacak Temeller

### 4.1 Korunacak ?r?n domainleri

v2'de a?a??daki domainler korunur ve schema evolution ile ta??n?r:

- `packs`
- `words`
- `reading_passages`
- `reading_passage_sentences`
- `reading_passage_words`
- `reading_sentence_translations`
- grammar module / page / example / test yap?s?
- `user_word_progress`
- `user_reading_progress`
- `user_reading_bookmarks`
- `user_reading_favorites`
- auth / role / premium eri?im mant???

### 4.2 v2'de eklenecek alanlar

Yeni mimari i?in a?a??daki tablolar veya geni?letmeler ?ng?r?l?r:

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

### 4.3 Korunacak repo varl?klar?

v2 resetinde a?a??daki alanlar korunur:

- `docs/`
- `docs/ui_tasarim/`
- `DATABASE_SCHEMA.md`
- `supabase/`
- `assets/` alt?ndaki ham i?erik ve veritaban? kaynaklar?
- `scripts/` alt?ndaki import / build / deploy pipeline dosyalar?
- `env/*.example`
- gerekiyorsa v2'ye uyarlanm?? `README.md`

### 4.4 Ar?ivlenecek veya temizlenecek alanlar

v2 resetinde mevcut uygulama implementasyonu s?f?rlan?r:

- `lib/`
- `test/`
- `android/`
- `ios/`
- `macos/`
- `linux/`
- `windows/`
- `web/`
- mevcut tek-app Flutter yap?s?na ait root `pubspec.yaml` ve `pubspec.lock`

Ge?ici ve ?retilmi? alanlar temizlenir:

- `.dart_tool/`
- `build/`
- `.firebase/`
- `artifacts/`
- `test-results/`
- `scripts/__pycache__/`
- `supabase/.temp/`

Belirsiz ama potansiyel operasyonel de?eri olan alanlar silinmez; s?n?fland?r?l?r:

- `json_output/`
- eski smoke test dok?manlar?
- manuel test dok?manlar?
- kopya roadmap veya prompt dosyalar?

---

## 5. Temel Mimari Kararlar

### 5.1 Platform stratejisi

- Android: `offline-first`
- Web: `remote-first`
- Admin: web ?ncelikli, ayr? Flutter app

### 5.2 Veri otoritesi

- ??erik verisi: server-authoritative
- Kullan?c? ilerlemesi: user-owned, syncable
- Mobil yazma i?lemleri: ?nce local outbox, sonra remote apply
- Web: local SQLite asset ta??maz; TTL cache + lazy loading kullan?r

### 5.3 G?venlik modeli

- Supabase ana backend'dir
- RLS zorunludur
- `service_role` hi?bir istemciye g?m?lmez
- UI gating yaln?z g?r?n?rl?k sa?lar; nihai g?venlik DB ve server-side katmandad?r
- Roller:
  - `developer`
  - `admin`
  - `pro`
  - `free`

### 5.4 Rol ve plan ayr?m?

Implementasyon d?zeyinde iki kavram ayr?l?r:

- **Role**: developer/admin/user-level yetki
- **Plan/Entitlement**: free/pro eri?im seviyesi

Bu ayr?m ileride tak?m plan?, kurumsal plan, ??retmen hesab? gibi geni?lemeleri kolayla?t?r?r.

### 5.5 Uygulama ve workspace topolojisi

v2 tek repo i?inde monorepo yap?s?nda ilerler:

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
  phases/
scripts/
supabase/
```

### 5.6 Katman yap?s?

Payla??lan paketler i?inde a?a??daki ayr?m korunur:

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

### 5.7 Teknoloji y???n?

| Alan | Teknoloji | Gerek?e |
|---|---|---|
| UI | Flutter 3.x | Android + Web tek repo |
| Dil | Dart 3.x | type-safe, generator uyumlu |
| State | Riverpod 2.x | test edilebilir ve compile-time g?venli |
| Routing | `go_router` | guard ve URL tabanl? navigasyon |
| Remote | `supabase_flutter` | auth + db + storage |
| Local mobile DB | Drift + SQLite | offline-first veri katman? |
| Charts | `fl_chart` | dashboard ve analytics |
| TTS | `flutter_tts` | kelime ve okuma seslendirme |
| Connectivity | `connectivity_plus` | sync tetikleme |
| Error monitoring | Sentry/Crashlytics + Supabase logs | operasyonel izleme |

### 5.8 Repository stratejisi

- Mobilde hibrit repository:
  - local read
  - background sync
  - outbox write
  - delta pull
- Web'de remote-first repository:
  - Supabase read
  - memory cache + TTL
  - stale-while-revalidate
- Ayr? repository s?n?flar?:
  - `PackRepository`
  - `WordRepository`
  - `ReadingRepository`
  - `GrammarRepository`
  - `ProgressRepository`
  - `AdminContentRepository`

---

## 6. Offline-First ve Schema Evolution

### 6.1 Mobil sync modeli

Mobil istemci i?in ?u yap?lar zorunludur:

- Drift tabanl? `AppDatabase`
- `sync_meta`
- `sync_outbox`
- `content_versions`
- `updated_at` / `event_id` / `dirty` benzeri deterministik sync alanlar?

### 6.2 Conflict resolution varsay?lanlar?

- ??erik tablolar?nda conflict yoktur; server her zaman otoritedir.
- Kullan?c? ilerlemesinde varsay?lan politika `Last Write Wins` olur.
- Saya? alanlar?nda gerekiyorsa merge uygulan?r.
- Sync i?lemleri idempotent RPC veya Edge Function ?zerinden i?lenir.

### 6.3 Supabase schema evolution kural?

- v1 tablolar? oldu?u gibi yeniden tasarlanmaz; migration ile evrimle?tirilir.
- Yeni tablo ve alanlar migration-first ilerler.
- ?lk eklenecek tablolar:
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

## 7. Branch ve Repo Reset Stratejisi

### 7.1 Git stratejisi

- `main`: v1 ar?iv durumu
- G?venli etiket: `v1-archive-2026-03-08`
- Yeni ?al??ma dal?: `v2-rewrite-foundation`

### 7.2 Reset kural?

Reset, veri ve operasyon katmanlar?n? silmeden yaln?z uygulama implementasyonunu temizler.

Korunacak eksen:

- veri modeli
- migration ge?mi?i
- import/build/deploy pipeline
- UI referanslar?
- teknik karar dok?manlar?

Silinecek eksen:

- v1 uygulama kodu
- v1 platform kabu?u
- ge?ici ?retim ??kt?lar?

---

## 8. Faz Bazl? Yol Haritas?

## Faz 0A - Dok?man Sonland?rma

### Hedef
Roadmap ve prompt'u v2 i?in karar kayna?? haline getirmek.

### Teknik i?ler
- roadmap sonland?rma
- prompt rol?n? daraltma
- encoding/UTF-8 normalize etmek
- branch/reset kararlar?n? belgeye eklemek
- v1 korunacak alanlar listesini sabitlemek

### Kabul kriterleri
- roadmap karar kayna?? olarak okunabilir
- prompt agent g?rev tan?m? olarak kullan?labilir
- mojibake yok

---

## Faz 0B - Branch, Ar?iv ve Reset

### Hedef
v1'i kaybetmeden v2 i?in temiz ?al??ma zemini olu?turmak.

### Teknik i?ler
- `v1-archive-2026-03-08` etiketi
- `v2-rewrite-foundation` dal?
- `docs/archive/v1/` yap?s?n?n olu?turulmas?
- keep/delete s?n?fland?rmas?
- mevcut app implementasyonunun temizlenmesi

### Kabul kriterleri
- v1 ar?ivlenmi? olur
- v2 branch temiz a??l?r
- korunacak veri/dok?man klas?rleri kal?r

---

## Faz 0C - Workspace Bootstrap

### Hedef
v2 monorepo iskeletini ?al??an ama bo? foundation olarak kurmak.

### Teknik i?ler
- `apps/student_app`
- `apps/admin_console`
- `packages/shared_core`
- `packages/shared_domain`
- `packages/shared_data`
- `packages/shared_ui`
- root workspace/melos yap?s?
- ortak lints, env example, CI skeleton
- temel theme + routing + shell scaffold

### Kabul kriterleri
- student_app web/android a??l?r
- admin_console web a??l?r
- ortak paket ba?lant?lar? ?al???r

---

## Faz 1 - Foundation + Auth + RBAC

### Hedef
Kimlik, oturum ve rol omurgas?n? kurmak.

### Teknik i?ler
- Supabase auth entegrasyonu
- anon session
- email/password upgrade
- `profiles`, `user_roles`, `entitlements`
- auth guard / admin guard / premium gate
- RLS ilk paket

### ??kt?lar
- kullan?c? oturumu y?netilebiliyor
- admin ve premium alanlar? ayr?l?yor
- shared auth contract netle?iyor

### Kabul kriterleri
- `free/pro/admin/developer` ayr?m? g?r?n?r
- admin route DB ve UI taraf?nda korunur

---

## Faz 2 - Mobile Offline Data + Schema Evolution

### Hedef
Mobil veri katman? ve sync omurgas?n? kurmak.

### Teknik i?ler
- Drift local schema
- DAO katman?
- `sync_meta`, `sync_outbox`
- delta pull
- outbox push
- content version invalidation

### ??kt?lar
- mobilde foundation veri katman? ?al???r
- i?erik ve progress katman? senkronize edilebilir hale gelir

### Kabul kriterleri
- mobil offline read yapar
- ilerleme offline kaybolmaz
- online olunca sync olur

---

## Faz 3 - Student Core MVP

### Hedef
??renci ?r?n?n?n temel ??renme ak??lar?n? yeniden a?mak.

### Teknik i?ler
- packs/words
- kelime listesi + arama
- flashcard
- temel test merkezi
- reading basic
- progress persistence

### ??kt?lar
- kullan?c? paket se?er ve ?al???r
- flashcard ve temel test ak??lar? kullan?labilir olur
- reading basic a??l?r

### Kabul kriterleri
- kullan?c? paket se?er ve ?al???r
- flashcard ve progress ?al???r
- reading basic a??l?r

---

## Faz 4 - Reading Advanced + Grammar

### Hedef
Okuma ve gramer mod?llerini premium gating ve daha zengin etkile?imle yeniden a?mak.

### Teknik i?ler
- sentence translation cache
- bookmarks/favorites
- grammar module/page/example/test
- HTML render sanitation
- TTS ayarlar?
- premium gating

### ??kt?lar
- reading player v2
- grammar reader
- bookmark/favorite sistemi
- free/pro g?r?n?rl?k fark?

### Kabul kriterleri
- okuma ekran? ?evrimd??? a??l?r
- ?eviri cache tekrar istek atmaz
- gramer mod?l? lokalde bo?sa remote fallback ?al???r

---

## Faz 5 - Admin CMS

### Hedef
??erik ekleme, d?zenleme ve yay?na alma s?re?lerini UI ?zerinden y?netilebilir hale getirmek.

### Teknik i?ler
- admin shell
- kelime/reading/grammar/test CRUD
- preview
- publish / unpublish
- bulk import
- validation katman?
- `content_versions`
- `audit_logs`

### ??kt?lar
- admin script ?al??t?rmadan i?erik y?netebilir
- de?i?iklikler istemcilere delta olarak yay?labilir

### Kabul kriterleri
- admin yeni i?erik ekleyebilir
- publish sonras? mobile sync tetiklenir
- audit kay?tlar? olu?ur

---

## Faz 6 - Analytics + Pro

### Hedef
Motivasyon ve gelir modelini destekleyen metrik ve abonelik katman?n? tamamlamak.

### Teknik i?ler
- daily stats
- streak
- quota / entitlement
- analytics dashboard
- monetization readiness

### ??kt?lar
- kullan?c? ilerlemesini g?rselle?tirebilir
- premium kilit mekanizmas? stabil hale gelir
- dashboard ?r?n hissi kazan?r

### Kabul kriterleri
- g?nl?k hedef ve streak do?ru hesaplan?r
- premium gate kritik ekranlarda tutarl? ?al???r
- analytics ekran? veri g?sterir

---

## Faz 7 - Web Production Readiness

### Hedef
Web deneyimini performansl? ve ?retime uygun hale getirmek.

### Teknik i?ler
- responsive shell
- deferred admin load
- asset pruning
- hosting pipeline
- LCP / bundle optimizasyonu
- web smoke testi

### ??kt?lar
- web s?r?m? b?y?k ekranlarda verimli ?al???r
- deploy s?reci standart hale gelir

### Kabul kriterleri
- web ilk y?k hissi kabul edilebilir olur
- admin ekran? masa?st?nde verimli olur
- deploy pipeline tekrarlanabilir olur

---

## Faz 8 - Test ve Operasyonel Sertle?tirme

### Hedef
Canl?ya ??kmadan ?nce sistemin g?venilirli?ini ve bak?m kolayl???n? garanti alt?na almak.

### Teknik i?ler
- unit / repository / widget testleri
- migration testleri
- RLS smoke testleri
- beta / rollback plan?
- offline/online ge?i? testleri

### ??kt?lar
- kritik user journey testleri otomatikle?ir
- migration ve RLS g?venlik a?? olu?ur

### Kabul kriterleri
- migration testleri ba?ar?s?z oldu?unda build k?r?l?r
- RLS yanl??sa release engellenir
- kritik yol testleri otomatik ?al???r

---

## Faz 9 - Canl?ya Alma

### Hedef
?retim da??t?m?, izleme ve ilk bak?m d?ng?s?n? tamamlamak.

### Teknik i?ler
- production migration freeze
- seed / initial content load
- staged rollout
- support playbook
- first-30-day monitoring

### ??kt?lar
- Android ve Web s?r?m? canl?ya al?n?r
- rollback ve operasyon playbook'u haz?r olur

### Kabul kriterleri
- Android ve Web s?r?m? canl?d?r
- rollback plan? do?rulanm??t?r
- ilk kritik hatalar operasyonel olarak y?netilebilir

---

## 9. Faz Bazl? ?al??ma Dok?man? Kurgusu

Her faz i?in uygulama ba?lamadan ?nce ve uygulama s?ras?nda ayr? ?al??ma dosyas? tutulur.

?nerilen yap?:

```text
docs/phases/
  _phase_calisma_sablonu.md
  phase_0a_dokuman_sonlandirma.md
  phase_0b_branch_reset.md
  phase_0c_workspace_bootstrap.md
  phase_1_foundation_auth_rbac.md
  ...
```

Her faz dosyas?nda en az ?u alanlar bulunur:

- hedef
- kapsam d??? maddeler
- yap?lacak i?ler
- kararlar
- ba??ml?l?klar
- riskler
- test/checklist
- ilerleme durumu
- tamamland? notlar?

Kural:

- Yeni geli?tirme do?rudan koda atlanarak ba?lamaz.
- ?nce ilgili faz dosyas? olu?turulur veya g?ncellenir.
- Uygulama boyunca bu dosya ya?ayan dok?man olarak i?lenir.
- Faz tamamlan?nca ??kt? ve ??renimler ayn? dosyaya kaydedilir.

---

## 10. ?lk 3 Sprint Teslim S?n?r?

### Sprint 1
- branch/reset tamam
- monorepo/workspace olu?mu?
- student_app ve admin_console bo? shell veriyor
- ortak paketler compile oluyor

### Sprint 2
- auth + profiles + roles + entitlements
- basic route guard
- shared theme ve responsive shell

### Sprint 3
- Drift foundation
- sync_meta + sync_outbox
- pack list + word list temel ak???

Bu ?? sprint sonunda ekip; ar?ivlenmi? v1, net v2 workspace, auth/RBAC omurgas? ve offline data foundation'a sahip olmal?d?r.

---

## 11. Riskler ve Azaltma Plan?

| Risk | Etki | Azaltma |
|---|---|---|
| v1 davran???n?n kaybolmas? | Y?ksek | v1 ar?iv etiketi + docs/archive |
| schema evolution'?n da??lmas? | ?ok y?ksek | migration-first disiplin |
| mobile offline kapsam ?i?mesi | Y?ksek | Faz 2'de yaln?z foundation teslimi |
| admin panelin scope ?i?mesi | Orta | Faz 5'e ertelenmi? ayr? app |
| web bundle ?i?mesi | Orta | remote-first + lazy load |
| tekrar eden karar dok?manlar? | Orta | roadmap/prompt rol ayr?m? |

---

## 12. Son Kararlar

- Bu proje greenfield de?il, controlled rewrite't?r.
- `main` v1 ar?ividir; aktif geli?tirme `v2-rewrite-foundation` dal?nda yap?l?r.
- Android offline-first, web remote-first olarak kal?r.
- `student_app` ve `admin_console` ayr? uygulama giri?leridir.
- Veritaban? korunur; uygulama kabu?u yeniden kurulur.
- Faz bazl? ?al??ma dok?manlar? `docs/phases/` alt?nda ya?ayan dok?man olarak tutulur.
