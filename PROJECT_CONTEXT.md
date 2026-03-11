# PROJECT_CONTEXT

## Proje Durumu

### Genel
- Monorepo durumu: Flutter tabanli iki uygulama ve ortak paketler aktif.
- Uygulamalar:
  - `apps/student_app`: ogrenci web + Android APK
  - `apps/admin_console`: admin web konsolu
- Ortak paketler:
  - `packages/shared_core`
  - `packages/shared_domain`
  - `packages/shared_data`
  - `packages/shared_ui`
- Guncel release kaynagi: `v2.0.3+3`
  - Kaynak: [packages/shared_core/lib/src/workspace_info.dart](c:/yazilim_projeler/passagetr_v0/packages/shared_core/lib/src/workspace_info.dart)
- Calisma agaci temiz degil. Student, admin, shared paketler, release dosyalari ve migration hattinda yerel degisiklikler var. Yeni oturum mevcut worktree uzerinden ilerlemeli; toplu reset uygulanmamali.

### Tamamlanan Ozellikler
- Student shell:
  - Web genis layout sidebar, mobil/APK bottom nav ayrimi aktif.
  - `/changelog` route aktif.
  - Web sidebar altindaki surum chipi ve mobil/dar layout profil ekrani release karti ayni kaynaktan besleniyor.
- Kimlik ve profil:
  - `AccessContext.hasIdentifiedProfile` ile anonymous/public ve kimlikli kullanici ayrimi aktif.
  - Anonymous kullanicida `/profile` auth surface, kimlikli kullanicida gercek profil yuzu gosteriliyor.
  - Fake profil kimligi kaldirildi; `Ahmet Yilmaz` fallback'i kullanilmiyor.
  - Profil ayarlari ve hesap yonetimi sheet'leri mevcut.
- Student words:
  - `StudentWordSummary` ve `studentWordSummaryProvider` ile ozet kartlari tek snapshot'tan uretiliyor.
  - `0` kelimelik paketler student yuzeyinde gizleniyor.
  - Kelime badge sayaci shell'den kaldirildi.
- Student home/readings:
  - `StudentContinueReadingSummary` ile continue CTA secimi duzeltildi.
  - Okuma listesi sayisal baslik prefix'ine gore kucukten buyuge siralaniyor.
  - Okuma listesi 21 kartlik sayfalara bolundu.
  - Okuma kartlari ve detaydan sure bilgisi kaldirildi.
  - Reading catalog `visible locked` davranisi `isPro` ile aktif; free kullanici pro okumayi listede goruyor ama tam icerige giremiyor.
- Reading detail:
  - Placeholder ozet notu kaldirildi.
  - Baslik altindaki ceviri/onkbellek yardim notu kaldirildi.
  - `Bolum n` etiketi ve `Turkce Ceviriyi Goster/Gizle` satiri kaldirildi.
  - Kisa basis kelime bazli sozluk lookup, uzun basis cumle cevirisi davranisi aktif.
  - Dictionary katmani ayri repository olarak kuruldu; mevcut words tablosu bu is icin kullanilmiyor.
- Grammar:
  - Seed-temelli premium lock kaldirildi; free akis acildi.
  - Remote hata durumlarinda ham exception gosterimi azaltildi.
- Admin console:
  - Auth/router hardening tamamlandi: `AdminAuthState` / `AdminAuthStatus` ile bootstrap-aware redirect, otomatik session refresh ve unauthorized/session-expired state'leri aktif.
  - Login akisi tek butonla calisir; manuel claim refresh butonu kaldirildi.
  - Session hardening aktif: auth state dususu, refresh failure ve idle timeout durumunda `/login` redirect + mesaj akisi var.
  - Dashboard, users, content ve settings route'lari aktif.
  - Audit feed icin `ready / empty / unavailable` state ayrimi var.
  - Sidebar e-posta tasmasi ellipsis ile duzeltildi.
  - `/users` server-side pagination, filtreleme, checkbox secim, bulk rol/plan degistirme, row action ve invite dialog destekler.
  - Invite akisi istemcide degil, `supabase/functions/admin_invite_users` edge function'inda calisir.
  - `/settings` artik `public.app_settings` tablosuna bagli kalici product config panelidir; save/reset/dirty state akisi vardir.
  - Dashboard `7 / 30 / 90` gun filtreleri, delta kartlari, trend chart ve sistem durumu paneli ile calisir.
  - `/content/words` ve `/content/readings` server-side paged listeleme kullanir; paketler full-list kalir.
  - Icerik satirlarinda `created_at`, `updated_at`, `updated_by` ve publish durumu gorunur.
  - Reading `isPro` alanini yoneten CRUD ve catalog davranisi aktif.
  - Publish scheduling kolonlari (`publish_at`, `unpublish_at`) migration seviyesinde eklendi.
  - Admin web build/deploy scriptleri `-WebRenderer` parametresini alir.
- Release / deploy:
  - Surum, changelog ve `version.json` ayni release metadata hattina baglandi.
  - Web deploy scriptleri `WorkspaceInfo`, `releaseCatalog` ve `docs/release/CHANGELOG.md` senkronunu kontrol ediyor.

### Eksik veya Acik Alanlar
- Admin console residual backlog:
  - grammar tarafinda buyuk veri esigine gore pagination UX'i acik
  - readings ve grammar import/export UI parity'si kismen acik
  - publish scheduling icin ileri tarih editoru ve undo banner UI'si acik
- TTS ozelligi planlarda gecti ancak uygulanmadi.
- Web ve APK arasinda UI parity yuksek, veri tazeligi parity degil:
  - Web remote-first
  - Android offline-first + local mirror + bootstrap sync
- Test hattinda bilinen acik:
  - Admin tarafi icin migration contract testi ve `shared_data` tum paket testi geciyor.
- Operasyonel acik:
  - `supabase db push` ve canli edge function deploy'u hedef ortamda ayrica yapilmali.
  - `-WebRenderer html` parametresi scriptte mevcut; fakat mevcut Flutter toolchain explicit `--web-renderer html` bayragini desteklemiyorsa script varsayilan renderer ile degrade olur.

## Teknik Yapi

### Teknoloji Yigini
- Flutter monorepo
- Paket yonetimi / orkestrasyon: `melos`
- State management: `flutter_riverpod`
- Routing: `go_router`
- Backend/auth/data sync: `supabase_flutter`
- Local persistence:
  - `drift`
  - `sqlite3`
  - `sqlite3_flutter_libs`
- Hosting / web release:
  - Firebase Hosting
  - PowerShell build/deploy scriptleri

### Mimari
- Student mimarisi:
  - Android: offline-first
  - Web: remote-first
- Admin mimarisi:
  - Web: remote-first, Supabase RPC + edge function odakli
  - Auth state: `AdminAuthState` + widget-level route gate
- Katmanlar:
  - `shared_domain`: entity + repository contract'lari
  - `shared_data`: Supabase, Drift, sync, repository implementasyonlari
  - `shared_core`: env, release, rbac, workspace metadata
  - `shared_ui`: ortak tema ve shell parcalari

### Onerilen Kritik Dosyalar
- Release metadata:
  - [packages/shared_core/lib/src/workspace_info.dart](c:/yazilim_projeler/passagetr_v0/packages/shared_core/lib/src/workspace_info.dart)
  - [packages/shared_core/lib/src/release/release_catalog.dart](c:/yazilim_projeler/passagetr_v0/packages/shared_core/lib/src/release/release_catalog.dart)
  - [docs/release/CHANGELOG.md](c:/yazilim_projeler/passagetr_v0/docs/release/CHANGELOG.md)
- Student state:
  - [apps/student_app/lib/src/core/student_providers.dart](c:/yazilim_projeler/passagetr_v0/apps/student_app/lib/src/core/student_providers.dart)
  - [apps/student_app/lib/src/core/student_access_controller.dart](c:/yazilim_projeler/passagetr_v0/apps/student_app/lib/src/core/student_access_controller.dart)
  - [apps/student_app/lib/src/core/student_translation_controller.dart](c:/yazilim_projeler/passagetr_v0/apps/student_app/lib/src/core/student_translation_controller.dart)
- Student feature screens:
  - [apps/student_app/lib/src/features/profile/profile_page.dart](c:/yazilim_projeler/passagetr_v0/apps/student_app/lib/src/features/profile/profile_page.dart)
  - [apps/student_app/lib/src/features/readings/readings_page.dart](c:/yazilim_projeler/passagetr_v0/apps/student_app/lib/src/features/readings/readings_page.dart)
  - [apps/student_app/lib/src/features/readings/reading_detail_page.dart](c:/yazilim_projeler/passagetr_v0/apps/student_app/lib/src/features/readings/reading_detail_page.dart)
  - [apps/student_app/lib/src/features/words/words_page.dart](c:/yazilim_projeler/passagetr_v0/apps/student_app/lib/src/features/words/words_page.dart)
  - [apps/student_app/lib/src/features/grammar/grammar_page.dart](c:/yazilim_projeler/passagetr_v0/apps/student_app/lib/src/features/grammar/grammar_page.dart)
- Shared data / repositories:
  - [packages/shared_data/lib/src/repositories/foundation_reading_repository.dart](c:/yazilim_projeler/passagetr_v0/packages/shared_data/lib/src/repositories/foundation_reading_repository.dart)
  - [packages/shared_data/lib/src/repositories/foundation_grammar_repository.dart](c:/yazilim_projeler/passagetr_v0/packages/shared_data/lib/src/repositories/foundation_grammar_repository.dart)
  - [packages/shared_data/lib/src/auth/foundation_auth_repository.dart](c:/yazilim_projeler/passagetr_v0/packages/shared_data/lib/src/auth/foundation_auth_repository.dart)
  - [packages/shared_data/lib/src/repositories/foundation_dictionary_repository.dart](c:/yazilim_projeler/passagetr_v0/packages/shared_data/lib/src/repositories/foundation_dictionary_repository.dart)
  - [packages/shared_data/lib/src/repositories/foundation_admin_user_management_repository.dart](c:/yazilim_projeler/passagetr_v0/packages/shared_data/lib/src/repositories/foundation_admin_user_management_repository.dart)
  - [packages/shared_data/lib/src/repositories/foundation_admin_settings_repository.dart](c:/yazilim_projeler/passagetr_v0/packages/shared_data/lib/src/repositories/foundation_admin_settings_repository.dart)
  - [packages/shared_data/lib/src/repositories/foundation_admin_analytics_repository.dart](c:/yazilim_projeler/passagetr_v0/packages/shared_data/lib/src/repositories/foundation_admin_analytics_repository.dart)
- Admin:
  - [apps/admin_console/lib/src/core/admin_access_controller.dart](c:/yazilim_projeler/passagetr_v0/apps/admin_console/lib/src/core/admin_access_controller.dart)
  - [apps/admin_console/lib/src/app/admin_console_router.dart](c:/yazilim_projeler/passagetr_v0/apps/admin_console/lib/src/app/admin_console_router.dart)
  - [apps/admin_console/lib/src/core/admin_providers.dart](c:/yazilim_projeler/passagetr_v0/apps/admin_console/lib/src/core/admin_providers.dart)
  - [apps/admin_console/lib/src/core/admin_settings_controller.dart](c:/yazilim_projeler/passagetr_v0/apps/admin_console/lib/src/core/admin_settings_controller.dart)
  - [apps/admin_console/lib/src/core/admin_user_management_controller.dart](c:/yazilim_projeler/passagetr_v0/apps/admin_console/lib/src/core/admin_user_management_controller.dart)
  - [apps/admin_console/lib/src/features/dashboard/dashboard_page.dart](c:/yazilim_projeler/passagetr_v0/apps/admin_console/lib/src/features/dashboard/dashboard_page.dart)
  - [apps/admin_console/lib/src/features/users/users_page.dart](c:/yazilim_projeler/passagetr_v0/apps/admin_console/lib/src/features/users/users_page.dart)
  - [apps/admin_console/lib/src/features/content/content_page.dart](c:/yazilim_projeler/passagetr_v0/apps/admin_console/lib/src/features/content/content_page.dart)
  - [apps/admin_console/lib/src/features/settings/settings_page.dart](c:/yazilim_projeler/passagetr_v0/apps/admin_console/lib/src/features/settings/settings_page.dart)
- Supabase:
  - [supabase/migrations/202603100030_reading_catalog_access_and_admin_is_pro.sql](c:/yazilim_projeler/passagetr_v0/supabase/migrations/202603100030_reading_catalog_access_and_admin_is_pro.sql)
  - [supabase/migrations/202603110031_admin_console_hardening_p1_p2.sql](c:/yazilim_projeler/passagetr_v0/supabase/migrations/202603110031_admin_console_hardening_p1_p2.sql)
  - [supabase/functions/admin_invite_users/index.ts](c:/yazilim_projeler/passagetr_v0/supabase/functions/admin_invite_users/index.ts)
- Faz / backlog:
  - [docs/phases/phase_05_admin_cms_icerik_operasyonlari.md](c:/yazilim_projeler/passagetr_v0/docs/phases/phase_05_admin_cms_icerik_operasyonlari.md)
  - [docs/phases/phase_05_5_admin_console_hardening.md](c:/yazilim_projeler/passagetr_v0/docs/phases/phase_05_5_admin_console_hardening.md)
  - [docs/reports/admin_console_backlog.md](c:/yazilim_projeler/passagetr_v0/docs/reports/admin_console_backlog.md)

### Onemli Tipler, Provider'lar ve Fonksiyonlar
- Release:
  - `WorkspaceInfo.appVersion`
  - `WorkspaceInfo.buildNumber`
  - `WorkspaceInfo.releaseNotesPath`
  - `releaseCatalog`
- Access/Profile:
  - `AccessContext.hasIdentifiedProfile`
  - `studentAccessProvider`
  - `studentAuthRepositoryProvider`
- Student state:
  - `StudentWordSummary`
  - `StudentContinueReadingSummary`
  - `studentWordSummaryProvider`
  - `studentContinueReadingSummaryProvider`
  - `studentReadingsProvider`
  - `studentReadingSectionsProvider`
  - `_compareReadingPassages`
- Dictionary:
  - `DictionaryEntry`
  - `DictionaryRepository.lookupWord`
  - `studentDictionaryRepositoryProvider`
  - `studentDictionaryEntryProvider`
- Admin auth/session:
  - `AdminAuthStatus`
  - `AdminAuthState`
  - `adminAuthStateProvider`
  - `adminAccessProvider`
  - `adminDashboardWindowProvider`
- Admin users/settings/analytics:
  - `AdminPage<T>`
  - `AdminUserListQuery`
  - `AdminBulkUserUpdate`
  - `AdminInviteRequest`
  - `AdminSettingsSnapshot`
  - `AdminDashboardSnapshot`
  - `AdminTrendPoint`
  - `adminUsersPageProvider`
  - `adminSettingsStateProvider`
  - `adminDashboardSnapshotProvider`
  - `adminWordPageProvider`
  - `adminReadingPageProvider`
- Supabase admin functions:
  - `admin_list_users_paged`
  - `admin_bulk_set_user_access`
  - `admin_get_settings`
  - `admin_upsert_settings`
  - `admin_fetch_dashboard_snapshot`
  - `admin_list_words_paged`
  - `admin_list_reading_passages_paged`
  - `admin_assign_invited_user_access`

### Dosya ve Dizin Organizasyonu
- `apps/student_app`
  - student UI, routes, feature ekranlari, Android build ciktilari
- `apps/admin_console`
  - admin web UI ve testleri
- `packages/shared_*`
  - domain/core/data/ui paylasilan kod
- `docs/phases`
  - faz kapanis ve kapsam belgeleri
- `docs/reports`
  - backlog, stabilization ve durum belgeleri
- `scripts`
  - build/deploy PowerShell scriptleri
- `supabase/migrations`
  - schema, RPC ve access flag migration'lari
- `supabase/functions`
  - edge function deploy yuzeyleri

## Kritik Kararlar

- Android offline-first, web remote-first secimi korundu.
  - Neden: APK'de zayif baglanti ve offline kullanim senaryolari desteklenmeli; webde veri tazeligi oncelikli.
- Student ve admin ayri uygulama olarak tutuldu.
  - Neden: role-based erisim, deploy hedefleri ve operational risk ayriliyor.
- Release metadata tek kaynaga baglandi.
  - Neden: surum sapmasini onlemek.
  - Kanonik kaynaklar:
    - `WorkspaceInfo`
    - `releaseCatalog`
    - `docs/release/CHANGELOG.md`
    - `scripts/build_web_firebase.ps1`
- Reading `visible locked` modeli secildi; pro okumalar free kullanicidan tamamen gizlenmiyor.
  - Neden: katalog kesfi korunuyor, tam icerik erisimi ise plan bazli kaliyor.
- Dictionary lookup mevcut words tablosundan ayrildi.
  - Neden: okuma icindeki anlik kelime lookup'i icin ayri dictionary veri modeli gerekiyor; flashcard/learning words modeli bu ihtiyaci karsilamiyor.
- Mobil dictionary local sqlite, web dictionary remote query olarak secildi.
  - Neden: APK'de hizli local lookup; webde asset sqlite dagitimi yerine mevcut `dictionary_entries` verisini kullanmak daha uygun.
- Admin auth state ayri state machine'e cekildi.
  - Neden: bootstrap, unauthorized ve sessionExpired gibi UI-yonlendirme durumlari yalniz `AccessContext` ile temiz tasinamiyordu.
- Invite akisinda istemciye `service_role` tasinmiyor.
  - Neden: admin panelde email invite ve access assignment edge function tarafinda yapilmali.
- Settings verisi `public.app_settings` JSON dokumani uzerinden normalize edilir.
  - Neden: secrets icermeyen product config alanlari tek migration contract'i ile yonetilsin.
- Manual destructive cleanup yapilmamali.
  - Neden: worktree dirty; kullanici ve onceki oturum degisiklikleri karisik halde. `git reset --hard` benzeri yaklasimlar riskli.

## Son Dogrulama Durumu

- 2026-03-11:
  - `flutter analyze apps/admin_console` gecti
  - `flutter test apps/admin_console` gecti
  - `flutter test packages/shared_data/test/migration_contract_test.dart` gecti
  - `flutter test packages/shared_data` gecti

## Siradaki Adim

- Hedef ortamda `supabase db push` ve `supabase functions deploy admin_invite_users` calistir.
- Ardindan admin web smoke akisini tekrar et:
  - `/`
  - `/users`
  - `/content/readings`
  - `/content/words`
  - `/content/grammar`
  - `/settings`
- Sonraki teknik backlog:
  - grammar pagination UX
  - readings/grammar import-export UI
  - publish scheduling editor + undo banner

## Yeni Chat Baslangic Promptu

```text
Yalnizca c:\yazilim_projeler\passagetr_v0\PROJECT_CONTEXT.md dosyasini oku. Icerigi 2-3 cumle ile teknik olarak ozetle. Henuz kod yazma; once mevcut admin/student durumunu ve kalan operasyonel riskleri dogrula.
```
