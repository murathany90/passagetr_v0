# Admin Console Prioritized Backlog

Bu dosya, `admin_console` icin tasarim parity, gercek CMS yetenekleri ve operasyonel ihtiyaclar temelinde uygulanacak backlog'u toplar.

## Kaynaklar
- `docs/ui_tasarim/web/07_admin_dash1.png`
- `docs/ui_tasarim/web/08_admin_kulla2.png`
- `docs/ui_tasarim/web/09_admin_okumauon3.png`
- `docs/ui_tasarim/web/10_admin_keliyon4.png`
- `docs/ui_tasarim/web/11_admin_gram5.png`
- `docs/ui_tasarim/web/12_admin_ayar5.png`
- `docs/phases/phase_05_admin_cms_icerik_operasyonlari.md`
- `apps/admin_console/lib/src/features/dashboard/dashboard_page.dart`
- `apps/admin_console/lib/src/features/users/users_page.dart`
- `apps/admin_console/lib/src/features/content/content_page.dart`
- `apps/admin_console/lib/src/features/settings/settings_page.dart`
- `supabase/migrations/202603090027_admin_console_management_rpcs.sql`

## Hedef
Admin paneli yalnizca listeleme ve tekil toggle yuzeyi olmaktan cikarip:

1. gercek CRUD is akislari olan
2. audit izi ureten
3. student web ve Android istemcilerini veri seviyesinde besleyen
4. `docs/ui_tasarim/web/07-12` referanslarina daha yakin

bir operasyon konsoluna donusturmek.

## Etki Notu
- Admin paneldeki rol, plan ve publish degisiklikleri dogrudan Supabase verisini etkiler.
- Bu degisiklikler web bundle veya APK binary uretmez.
- Student web remote-first oldugu icin DB degisikliklerini daha hizli gorur.
- Student Android offline-first oldugu icin DB degisiklikleri sync sonrasi gorunur.

## P0
| ID | Baslik | Route / Alan | Bugunku bosluk | Yapilacak is | Veri etkisi | Kabul kriteri |
|---|---|---|---|---|---|---|
| `ADM-P0-01` | Kelime CMS'yi paket-merkezli yap | `/content/words` | Mevcut ekran word satir listesi veriyor. Tasarim ise paket kartlari, `CSV Yukle` ve `Yeni Paket` akisi bekliyor. | Pack list/create/update/delete route'larini ac. `CSV Yukle` aksiyonunu panel icine al. Pack detay ekraninda kelime ekleme, cikarma ve toplu import akisi kur. Gerekli Supabase RPC veya tablo mutasyonlarini ekle. | `words`, pack iliskileri ve audit log | Tasarimdaki bilgi mimarisi yakalanir. Admin yeni paket acabilir, CSV ile kelime alabilir, pakete bagli kelimeleri yonetebilir. |
| `ADM-P0-02` | Okuma CMS'ye gercek create/edit/delete ekle | `/content/readings` | Mevcut ekran liste + publish toggle ile sinirli. Tasarim yeni parca ekleme ve daha zengin yonetim bekliyor. | `Yeni Parca Ekle` butonu, create/edit formu, seviye filtresi, tarih ve metrik kolonlari, satir aksiyon menusu ekle. Reading create/update/archive RPC'lerini ekle. | `reading_passages` ve audit log | Admin panelden yeni okuma olusturabilir, duzenleyebilir, yayina alabilir ve audit kaydi gorur. |
| `ADM-P0-03` | Gramer CMS'ye create/edit/reorder ekle | `/content/grammar` | Mevcut ekran modulleri yalniz listeliyor. Tasarim yeni modul, durum badge ve sira yonetimi istiyor. | `Yeni Modul` butonu, modul formu, siralama alani, drag handle veya explicit reorder aksiyonu, modul tipi ve soru sayisi gostergesi ekle. Grammar reorder/update RPC'lerini ekle. | `gramer_modulleri` ve audit log | Modul sirasi kalici olur. Yeni modul eklenir. Taslak/aktif durumu sadece switch degil butunsel yonetim akisina baglanir. |
| `ADM-P0-04` | Kritik mutasyonlar icin guvenlik ve geri bildirim katmani | Kullanici ve icerik tum mutasyonlari | Rol/plan ve publish islemleri tek tikla calisiyor. Onay, rollback ve acik etki bilgisi zayif. | Confirm modal, optimistic update rollback, standart success/error toast, audit log linki ve "degisiklik etkisi" metni ekle. Developer rol verme akisini cift onayla koru. | Tum kritik admin mutasyonlari | Yanlis tiklama riski azalir. Hata durumunda UI son state ile tekrar uyumlanir. Kritik degisiklikler izlenebilir hale gelir. |

## P1
| ID | Baslik | Route / Alan | Bugunku bosluk | Yapilacak is | Veri etkisi | Kabul kriteri |
|---|---|---|---|---|---|---|
| `ADM-P1-01` | Kullanici yonetimine ekleme ve bulk action ekle | `/users` | Tasarim yeni kullanici, checkbox secimi ve toplu aksiyonlar gosteriyor. Kodda yalniz filtreleme ve tekil guncelleme var. | `Yeni Kullanici Ekle`, secmeli tablo, toplu plan/rol degistirme, pagination ve row action menu ekle. | `auth.users`, `user_roles`, `entitlements`, audit log | Kullanicilar ekrandan toplu yonetilir. Buyuk listelerde islem hizi artar. |
| `ADM-P1-02` | Settings ekranini gercek ayar paneline cevir | `/settings` | Mevcut ekran read-only env ozeti. Tasarim sekmeli ve kaydedilebilir ayarlar paneli bekliyor. | `Genel`, `Bildirimler`, `Guvenlik`, `Veri Yonetimi` sekmelerini ekle. Form alanlari ve `Degisiklikleri Kaydet` akisi kur. Gerekirse `app_settings` tablosu veya RPC katmani tanimla. | Sistem konfigurasyonu ve audit log | Settings ekrani sahte gostergeden gercek yonetim paneline donusur. |
| `ADM-P1-03` | Dashboard'a zaman filtresi ve trend chart ekle | `/` | KPI kartlari var ama tasarimdaki trend grafiği, delta bilgisi ve zaman filtresi yok. | `Son 7 Gun` filtresi, kullanici buyumesi chart'i, degisim yuzdeleri ve sistem durumu karti ekle. | Yalniz admin analiz katmani | Dashboard tasarim parity'si belirgin iyilesir ve daha anlamli izleme yuzeyi olur. |
| `ADM-P1-04` | Content listelerine operasyonel zenginlik ekle | `/content/*` | Liste satirlari minimum alan gosteriyor. Tasarim daha zengin tablo hissi veriyor. | Reading, word ve grammar listelerine ek filtreler, durum chip'leri, created/updated bilgisi, owner veya updated_by, row action dropdown ekle. | Icerik operasyon gozlemi | Admin tek bakista durum ve son degisiklikleri anlayabilir. |

## P2
| ID | Baslik | Route / Alan | Bugunku bosluk | Yapilacak is | Veri etkisi | Kabul kriteri |
|---|---|---|---|---|---|---|
| `ADM-P2-01` | Import/export hattini genislet | `/content/words`, `/content/readings`, `/content/grammar` | Toplu veri operasyonlari hala script bagimli. | CSV import'u kelime disina tasir. Reading ve grammar export, import validation raporu ve islem ozeti eklenir. | Icerik verisi ve audit log | Toplu operasyonlar panel disi script'e daha az bagimli olur. |
| `ADM-P2-02` | Publish scheduling ve undo ekle | Tum icerik route'lari | Publish sadece anlik toggle. | `publish_at`, `unpublish_at`, kisa sureli undo banner, detayli audit diff gorunumu ekle. | Icerik yayin akisi | Yayin kararlari kontrollu ve geri alinabilir hale gelir. |
| `ADM-P2-03` | Session timeout hardening | Login, shell, protected route'lar | Token expiry ve stale session davranisi sinirli. | Session dususu dinleme, force redirect `/login`, timeout uyarisi, refresh fallback ekle. | Guvenlik ve oturum yonetimi | Uzun sure acik admin paneli guvenli davranir. |
| `ADM-P2-04` | UI parity polish | Tum admin shell | Islev var ama bazi ekranlar tasarima gore daha sade. | Sticky toolbar, bos durum ekranlari, daha iyi badge hiyerarsisi, tablo hizalari, responsive padding ve spacing polish yap. | Gorsel kalite | Farklar `belirgin` seviyeden `kucuk fark` seviyesine iner. |

## Onerilen Uygulama Sirasi
1. `ADM-P0-01`, `ADM-P0-02`, `ADM-P0-03` icin DB contract ve RPC tasarimini netlestir.
2. Repository ve provider katmanini yeni contract'lara gore genislet.
3. Admin route'larini gercek create/edit shell'lerine donustur.
4. `ADM-P0-04` ile mutasyon guvenligini standartlastir.
5. P0 bitince admin smoke ve student veri parity testlerini tekrar calistir.

## Teknik Baslangic Noktalari
- Router: `apps/admin_console/lib/src/app/admin_console_router.dart`
- Dashboard: `apps/admin_console/lib/src/features/dashboard/dashboard_page.dart`
- Users: `apps/admin_console/lib/src/features/users/users_page.dart`
- Content: `apps/admin_console/lib/src/features/content/content_page.dart`
- Settings: `apps/admin_console/lib/src/features/settings/settings_page.dart`
- Providers: `apps/admin_console/lib/src/core/admin_providers.dart`
- Mutasyon servisleri: `apps/admin_console/lib/src/core/admin_cms_controller.dart`
- Supabase RPC: `supabase/migrations/202603090027_admin_console_management_rpcs.sql`

## Dogrulama
- `flutter test apps/admin_console`
- `flutter analyze apps/admin_console`
- Admin web smoke: `/`, `/users`, `/content/readings`, `/content/words`, `/content/grammar`, `/settings`
- Kritik mutasyonlar icin manuel test:
  1. user role/plan guncelleme
  2. reading publish/unpublish
  3. word pack create/import
  4. grammar reorder
