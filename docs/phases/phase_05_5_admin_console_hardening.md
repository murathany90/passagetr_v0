# Faz 5.5 - Admin Console Hardening

## 1. Faz Amaci
Faz 5 ile acilan admin CMS yuzeyini production benzeri kullanima daha yakin hale getirmek; auth/router kararliligini, kullanici yonetimi P1 islerini, settings/dashboard parity'sini ve kritik P2 sertlestirme maddelerini tamamlamak.

## 2. Kapsam
- Admin auth, router ve session hardening
- `/users` icin pagination, bulk action ve invite akisi
- `/settings` icin kalici product config veri modeli ve UI
- Dashboard analytics snapshot, delta ve trend chart
- `/content/words` ve `/content/readings` icin paged listeleme ve metadata parity
- Admin web build/deploy scriptlerinde renderer secimi
- Faz 5.5 migration ve edge function katmani

## 3. Kapsam Disi
- Yeni odeme veya destek sistemleri
- Mobil admin uygulamasi
- Grammar tarafinda buyuk veri esigine gore yeni pagination UX'i
- Publish scheduling icin ileri tarihli editor/undo banner UI'sinin tam urunlestirilmesi

## 4. Yapilacak Isler
- [x] `AdminAuthState` / `AdminAuthStatus` katmanini ekle
- [x] Router redirect kararlarini bootstrap-aware hale getir
- [x] Login akisini otomatik claim refresh ve deterministic unauthorized hata akisi ile sertlestir
- [x] Idle timeout ve session expiry redirect davranisini ekle
- [x] `/users` ekranini server-side paged listeleme, filtreleme ve bulk action yapisina tasarla
- [x] Invite akisinda istemci yerine edge function kullan
- [x] `public.app_settings` tablosu ve `admin_get_settings` / `admin_upsert_settings` RPC'lerini ekle
- [x] `/settings` ekranini sekmeli product config paneline donustur
- [x] `admin_fetch_dashboard_snapshot` analytics contract'ini ekle
- [x] Dashboard'a window filtresi, delta kartlari, trend chart ve sistem durumu paneli ekle
- [x] `/content/words` ve `/content/readings` listelemelerini paged hale getir
- [x] Icerik satirlarina metadata ve publish durumu gorunurlugu ekle
- [x] `publish_at` / `unpublish_at` kolonlarini migration'a ekle
- [x] `build_web_firebase.ps1` ve `deploy_web_firebase.ps1` icin `-WebRenderer` parametresini ekle
- [x] Admin widget testleri ve migration contract testlerini guncelle

## 5. Teknik Kararlar
- Auth state artik yalniz `AccessContext` ile degil, UI yonlendirme ihtiyaclarini da tasiyan ayri bir `AdminAuthState` ile yonetilir.
- Router bootstrap sirasinda redirect vermez; protected route'lar widget-level gate ile acilir.
- Unauthorized login sonucu session temizlenir; kullanici dashboard'a bir kez bile dusmeden `/login` uzerinde hata gorur.
- Invite akisi istemcide `service_role` kullanmaz; `supabase/functions/admin_invite_users` edge function'i davet ve access atamasini tamamlar.
- Users, words ve readings listelemeleri offset-based pagination kullanir; varsayilan page size `50` olarak tutulur.
- Settings verisi tek satirlik `public.app_settings` JSON dokumani uzerinden normalize edilir.
- Dashboard chart'i icin yeni paket eklenmez; `CustomPainter` tabanli yerel cizim kullanilir.
- Admin web renderer secimi script seviyesinde parametrelesir; mevcut Flutter toolchain explicit renderer bayraklarini desteklemiyorsa script degrade olarak varsayilan build ile devam eder.

## 6. Bagimliliklar
- Faz 1 auth, session ve RBAC temeli
- Faz 5 admin CMS route ve temel CRUD akislari
- Supabase migration ve edge function dagitim hatti

## 7. Riskler
- Auth claim propagation hala Supabase oturum yenilemesine baglidir; environment tarafinda claim atama latency'si artarsa login UX'i etkilenebilir.
- Invite edge function'i production `service_role` / SMTP kurulumuna baglidir.
- Publish scheduling kolonlari eklense de bunlari kullanan tam zamanlanmis yayin UI'si daha sonra tamamlanacaktir.

## 8. Test ve Kabul Kriterleri
- `flutter analyze apps/admin_console` temiz gecer.
- `flutter test apps/admin_console` temiz gecer.
- `flutter test packages/shared_data/test/migration_contract_test.dart` temiz gecer.
- Login sonrasi redirect loop yeniden uretilemez.
- Non-admin girisi yetkisiz hata mesaji ile kapanir.
- `/users` pagination, bulk action ve invite dialog akislari calisir.
- `/settings` save/reset/dirty state akisi kalici veriyle calisir.
- Dashboard `7 / 30 / 90` gun filtreleri ve trend chart render olur.
- `/content/words` ve `/content/readings` paged listeleme ile calisir.

## 9. Ilerleme Durumu
- Durum: Tamamlandi
- Son guncelleme: 2026-03-11

## 10. Tamamlananlar / Notlar
- `packages/shared_domain` icine admin contract entity ve repository interface'leri eklendi: `AdminPage`, `AdminUserListQuery`, `AdminBulkUserUpdate`, `AdminInviteRequest`, `AdminSettingsSnapshot`, `AdminDashboardSnapshot`, `AdminTrendPoint`.
- `packages/shared_data` icine `FoundationAdminUserManagementRepository`, `FoundationAdminSettingsRepository` ve `FoundationAdminAnalyticsRepository` eklendi.
- `apps/admin_console/lib/src/core/admin_access_controller.dart` auth state machine ve otomatik refresh akisina gecirildi.
- `apps/admin_console/lib/src/app/admin_console_router.dart` bootstrap-aware redirect ve route gate yapisina cekildi.
- `apps/admin_console/lib/src/app/admin_console_app.dart` idle timeout davranisi icin session activity scope ile guncellendi.
- `/users`, `/settings`, `/` dashboard ve content route'lari yeni veri kontratlarina gore yenilendi.
- `supabase/migrations/202603110031_admin_console_hardening_p1_p2.sql` ile settings, users paging/bulk RPC'leri, dashboard snapshot fonksiyonu ve publish scheduling kolonlari eklendi.
- `supabase/functions/admin_invite_users/index.ts` invite ve access assignment akisini tasir.
- `scripts/build_web_firebase.ps1` ve `scripts/deploy_web_firebase.ps1` `-WebRenderer` parametresi alir.
- Admin content widget layout'i dar alanlarda overflow vermeyecek sekilde `Wrap` tabanli filtre bloklarina cekildi.

## 11. Faz Kapanis Dogrulamasi
- `flutter analyze apps/admin_console`
- `flutter test apps/admin_console`
- `flutter test packages/shared_data/test/migration_contract_test.dart`
- `flutter test packages/shared_data`

## 12. Sonraki Isler
- Grammar listesi icin buyuk veri esiginde pagination UX'ini netlestir.
- Reading ve grammar import/export UI parity'sini tamamla.
- Publish scheduling icin ileri tarihli editor ve undo banner akisini urunlestir.
