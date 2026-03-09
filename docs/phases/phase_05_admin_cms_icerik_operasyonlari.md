# Faz 5 - Admin CMS Icerik Operasyonlari

## 1. Faz Amaci
Ayri `admin_console` uygulamasinda temel CMS modullerini calisir hale getirmek.

## 2. Kapsam
- Dashboard
- Kullanici yonetimi
- Kelime, okuma ve gramer yonetim yuzeyleri
- Audit goruntuleme

## 3. Kapsam Disi
- Odeme ve destek sistemleri
- Mobil admin uygulamasi

## 4. Yapilacak Isler
- [x] `docs/ui_tasarim` Faz 5 admin ekranlarini route bazinda esle
- [x] UI parity checklist'ini ekle
- [x] Admin shell'i rail/sidebar + top toolbar yapisina taslaga gore tasarla
- [x] Dashboard verilerini bagla
- [x] `/users` ekraninda rol/plan filtreleme ve duzenleme yuzeyini ac
- [x] `/content/readings` ekranini okuma CMS listesi olarak ac
- [x] `/content/words` ekranini kelime/paket CMS listesi olarak ac
- [x] `/content/grammar` ekranini gramer CMS listesi olarak ac
- [x] Publish/unpublish aksiyonlarini admin repository'ye bagla
- [x] Audit gorunumunu `/settings` icinde ekle
- [x] Admin dashboard quick action'larini ilgili route'lara bagla

### UI Parity Checklist
| Taslak | Route | Hedef Widget Agaci | Veri Kaynagi | Kabul Kriteri |
|---|---|---|---|---|
| `docs/ui_tasarim/web/06_admin.png` | `/login` veya admin shell root | branded auth shell + left rail | auth/session state | Admin giris kabugu taslak diliyle uyumlu |
| `docs/ui_tasarim/web/07_admin_dash1.png` | `/` | dashboard cards + charts + quick actions | dashboard aggregates | Dashboard layout taslakla uyumlu |
| `docs/ui_tasarim/web/08_admin_kulla2.png` | `/users` | toolbar + filters + user table | users/roles/entitlements query | Kullanicilar ekran taslakla uyumlu |
| `docs/ui_tasarim/web/09_admin_okumauon3.png` | `/content/readings` | content table/editor shell | reading CMS data | Okuma yonetimi taslakla uyumlu |
| `docs/ui_tasarim/web/10_admin_keliyon4.png` | `/content/words` | pack/word management shell | pack/word CMS data | Kelime yonetimi taslakla uyumlu |
| `docs/ui_tasarim/web/11_admin_gram5.png` | `/content/grammar` | grammar module table/editor shell | grammar CMS data | Gramer yonetimi taslakla uyumlu |
| `docs/ui_tasarim/web/12_admin_ayar5.png` | `/settings` | settings + audit panels | config + audit data | Ayarlar ve audit gorunumu taslakla uyumlu |

## 5. Teknik Kararlar
- CMS ayri uygulamada kalir
- Admin mutasyonlari audit log uretir
- Faz 5 web shell, `docs/ui_tasarim/web` altindaki admin ekranlarina sadik kalir
- Student app icindeki admin launcher no-op birakilmaz; `admin_console` entrypoint davranisi tanimlanir
- Admin content route'lari ayrik kalir: `/content/readings`, `/content/words`, `/content/grammar`
- Audit gorunumu ayarlar ekraninin icinde sag panel veya alt panel olarak acilir
- Admin listeleri icin Supabase RPC oncelikli remote-first okuma kullanilir; preview fallback korunur

## 6. Bagimliliklar
- Faz 1 RBAC
- Faz 4 icerik domainleri

## 7. Riskler
- Kapsam buyumesi

## 8. Test ve Kabul Kriterleri
- Admin mevcut icerigi listeleyebilir ve yayin durumunu degistirebilir
- Admin shell web build'de tum route'lari acar
- Kullanicilar, content ve settings ekranlari table/list bazli veri gosterir
- Publish aksiyonlari ve audit listesi UI'da gorunur

## 9. Ilerleme Durumu
- Durum: Tamamlandi
- Son guncelleme: 2026-03-09

## 10. Tamamlananlar / Notlar
- Dosya olusturuldu
- Faz 5 UI parity referanslari eklendi
- Faz 5 route parity sabitlendi: `/`, `/users`, `/content/readings`, `/content/words`, `/content/grammar`, `/settings`
- `admin_console` shell'i `docs/ui_tasarim/web/06-12` referanslarina gore branded login + rail/sidebar + dashboard/cards + users/content/settings yuzeyleriyle tamamlandi
- `admin_providers.dart` admin listeleri icin Supabase RPC oncelikli remote-first yukleyiciye cekildi; preview fallback korundu
- `202603090027_admin_console_management_rpcs.sql` ile `admin_list_users`, `admin_list_words`, `admin_list_reading_passages`, `admin_list_grammar_modules`, `admin_set_user_access`, `admin_set_content_publish_state` fonksiyonlari eklendi ve remote Supabase projesine push edildi
- Kullanici yonetimi ekraninda rol/plan filtreleme, developer korumasi ve remote role/plan guncelleme akisi acildi
- Icerik ekranlarinda publish/unpublish aksiyonlari remote admin repository ve audit log akisina baglandi
- Ayarlar ekraninda env ozeti + audit paneli acildi; dashboard quick action butonlari ilgili route'lara baglandi
- Faz 5 kapanis dogrulamasi:
  - `supabase db push`
  - `flutter analyze`
  - `flutter test apps/admin_console`
  - `flutter test apps/student_app`
  - `flutter test packages/shared_data`
  - `flutter build web --release --dart-define-from-file=..\\..\\env\\app.web.json` (`apps/admin_console`)
  - `flutter build web --release --dart-define-from-file=..\\..\\env\\app.web.json` (`apps/student_app`)
  - `flutter build apk --debug --dart-define-from-file=..\\..\\env\\app.web.json` (`apps/student_app`)
