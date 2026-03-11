# Admin Console Prioritized Backlog

Bu dosya, `admin_console` icin Faz 5 ve Faz 5.5 sonrasindaki gercek durumu ve kalan backlog'u toplar.

## Kaynaklar
- `admin_console_analysis_report.md`
- `docs/phases/phase_05_admin_cms_icerik_operasyonlari.md`
- `docs/phases/phase_05_5_admin_console_hardening.md`
- `apps/admin_console/lib/src/features/dashboard/dashboard_page.dart`
- `apps/admin_console/lib/src/features/users/users_page.dart`
- `apps/admin_console/lib/src/features/content/content_page.dart`
- `apps/admin_console/lib/src/features/settings/settings_page.dart`
- `supabase/migrations/202603110031_admin_console_hardening_p1_p2.sql`
- `supabase/functions/admin_invite_users/index.ts`

## Durum Ozeti
- Faz 5 temel admin CMS route'lari, CRUD ve publish akislarini acmisti.
- Faz 5.5 ile auth/router hardening, users/settings/dashboard P1 isleri ve kritik P2 sertlestirme maddeleri tamamlandi.
- Mevcut admin panel production benzeri kullanima yaklasti; kalan isler daha cok parity polish, ileri yayin akislari ve test/altyapi tarafinda toplaniyor.

## Tamamlanan Basliklar
| ID | Baslik | Durum | Not |
|---|---|---|---|
| `ADM-P0-01` | Kelime CMS'yi paket-merkezli yap | Tamamlandi | Paket listesi, `CSV Yukle`, `Yeni Paket`, pakete bagli kelime CRUD ve paged word list aktif. |
| `ADM-P0-02` | Okuma CMS'ye gercek create/edit/delete ekle | Tamamlandi | Reading create/edit/delete, seviye filtresi, publish akisi ve paged reading list aktif. |
| `ADM-P0-03` | Gramer CMS'ye create/edit/reorder ekle | Tamamlandi | Modul create/edit/reorder ve publish akisi aktif. |
| `ADM-P0-04` | Kritik mutasyonlar icin guvenlik ve geri bildirim katmani | Buyuk oranda tamamlandi | Confirm modal, audit push, developer role cift onay ve success/error feedback mevcut. |
| `ADM-P1-01` | Kullanici yonetimine ekleme ve bulk action ekle | Tamamlandi | Server-side pagination, bulk role/plan, select-all, row action ve invite dialog edge function ile aktif. |
| `ADM-P1-02` | Settings ekranini gercek ayar paneline cevir | Tamamlandi | `public.app_settings`, `admin_get_settings`, `admin_upsert_settings` ve sekmeli UI aktif. |
| `ADM-P1-03` | Dashboard'a zaman filtresi ve trend chart ekle | Tamamlandi | `admin_fetch_dashboard_snapshot`, delta kartlari, trend chart ve sistem durumu paneli aktif. |
| `ADM-P1-04` | Content listelerine operasyonel zenginlik ekle | Tamamlandi | Metadata, publish bilgisi, durum chip'leri ve row action gorunurlugu aktif. |
| `ADM-P2-03` | Session timeout hardening | Tamamlandi | Idle timeout, session-expired redirect ve bootstrap-aware auth gate aktif. |
| `ADM-P2-04` | UI parity polish | Buyuk oranda tamamlandi | Responsive spacing, audit/settings panel yerlesimi ve content filter overflow fixleri yapildi. |

## Kalan Oncelikli Backlog

### P1
| ID | Baslik | Route / Alan | Bugunku bosluk | Yapilacak is | Kabul kriteri |
|---|---|---|---|---|---|
| `ADM-R1-01` | Deploy ve production smoke kapatisi | Tum admin deploy hattı | Kod ve testler yerelde hazir; migration ve function deploy hedef ortamda henuz uygulanmamis olabilir. | `supabase db push`, `supabase functions deploy admin_invite_users`, admin web build/deploy ve route smoke tamamlanir. | Canli admin panelde login, users, settings, dashboard ve content route'lari environment verisiyle dogrulanir. |

### P2
| ID | Baslik | Route / Alan | Bugunku bosluk | Yapilacak is | Kabul kriteri |
|---|---|---|---|---|---|
| `ADM-R2-01` | Reading ve grammar import/export parity | `/content/readings`, `/content/grammar` | Kelime import akisi panelde mevcut; reading ve grammar tarafinda panel ici import/export UI eksik. | Validation raporu, import ozeti ve export aksiyonlari eklenir. | Toplu operasyonlar script'e daha az bagimli hale gelir. |
| `ADM-R2-02` | Publish scheduling UI ve undo banner | Tum icerik route'lari | `publish_at` / `unpublish_at` kolonlari var; fakat editor ve geri alma UX'i yok. | Tarih secimli publish/unpublish editoru, kisa sureli undo banner ve audit diff gorunumu eklenir. | Zamanlanmis yayin kararleri panelden yonetilir. |
| `ADM-R2-03` | Grammar buyuk veri pagination stratejisi | `/content/grammar` | Grammar listesi halen tam liste mantiginda calisir. | Threshold, filtreleme ve gerekirse sayfalama UX'i netlestirilir. | Buyuk grammar dataset'lerinde performans stabil kalir. |
| `ADM-R2-04` | Web renderer stratejisinin production karari | Build/deploy scriptleri | `-WebRenderer` parametresi eklendi; mevcut Flutter toolchain explicit `html` flag'ini her zaman desteklemeyebilir. | Admin hosting bundle icin `auto/html/wasm` smoke karsilastirmasi yapilip kalici tercih belgelenir. | Renderer secimi test edilmis ve dokumante edilmis olur. |

## Teknik Baslangic Noktalari
- Router: `apps/admin_console/lib/src/app/admin_console_router.dart`
- Auth/session: `apps/admin_console/lib/src/core/admin_access_controller.dart`
- Dashboard: `apps/admin_console/lib/src/features/dashboard/dashboard_page.dart`
- Users: `apps/admin_console/lib/src/features/users/users_page.dart`
- Content: `apps/admin_console/lib/src/features/content/content_page.dart`
- Settings: `apps/admin_console/lib/src/features/settings/settings_page.dart`
- Providers: `apps/admin_console/lib/src/core/admin_providers.dart`
- Settings controller: `apps/admin_console/lib/src/core/admin_settings_controller.dart`
- User management controller: `apps/admin_console/lib/src/core/admin_user_management_controller.dart`
- Supabase migration: `supabase/migrations/202603110031_admin_console_hardening_p1_p2.sql`
- Edge function: `supabase/functions/admin_invite_users/index.ts`

## Son Dogrulama
- `flutter test apps/admin_console`
- `flutter analyze apps/admin_console`
- `flutter test packages/shared_data/test/migration_contract_test.dart`
- `flutter test packages/shared_data`

## Not
- `admin_console_analysis_report.md` icindeki "Sonuc ve Onceliklendirilmis Aksiyon Plani" Faz 5.5 kapsaminda kod seviyesinde buyuk oranda karsilanmistir.
- Bu backlog artik kapanan P0/P1 maddelerini tekrar acmaz; yalniz residual ve environment-dependent isleri takip eder.
