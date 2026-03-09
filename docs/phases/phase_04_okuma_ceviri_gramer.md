# Faz 4 - Okuma, Ceviri ve Gramer

## 1. Faz Amaci
Okuma, cumle cevirisi ve gramer modullerini controlled rewrite mimarisine tasimak.

## 2. Kapsam
- Reading library ve detail
- Translation cache
- Grammar reader ve mini testler

## 3. Kapsam Disi
- Admin CMS operasyonlari

## 4. Yapilacak Isler
- [x] `docs/ui_tasarim` Faz 4 ekranlarini route bazinda esle
- [x] UI parity checklist'ini ekle
- [x] Okuma liste ve detay ekranlarini bagla
- [x] Gramer liste parity ekranini bagla
- [x] Reading bookmark/favorite state controller'ini ekle
- [x] Bookmark/favorite toggle'larini `user_reading_bookmarks` ve `user_reading_favorites` outbox event'lerine bagla
- [x] Reading detail icin translation cache controller'ini ekle
- [x] Cumle/bolum cevirisi cache hit-miss yuzeyini detail ekrana bagla
- [x] `/grammar/:moduleId` route'unu ac ve gramer reader ekranini uygula
- [x] Grammar progress snapshot okuma akisini ac
- [x] Grammar reader ilerlemesini `user_grammar_progress` outbox event'lerine bagla
- [x] Translation cache akisini bagla
- [x] Grammar repository ve progress'i ac
- [x] Reading detail bolum cevirisi gorunurlugunu ve fallback akislarini duzelt
- [x] Okuma ve gramer ekranlarindaki bozuk Turkce UI metinlerini normalize et
- [x] Reading detail ceviri davranisini widget test ile dogrula

### UI Parity Checklist
| Taslak | Route | Hedef Widget Agaci | Veri Kaynagi | Kabul Kriteri |
|---|---|---|---|---|
| `docs/ui_tasarim/android/03_okuma.png` | `/readings` | search + segmented filter + reading cards + alt navigation | `studentReadingsProvider` + progress/recent state | Mobil liste taslakla uyumlu |
| `docs/ui_tasarim/web/03_okuma.png` | `/readings` | rail + content grid/list shell | ayni route, web breakpoint layout | Web okuma kutuphanesi taslakla uyumlu |
| `docs/ui_tasarim/android/04_okuma_detay.png` | `/readings/:id` | article header + inline actions + progress footer | reading detail repository + bookmarks/favorites | Mobil detay ekran taslakla uyumlu |
| `docs/ui_tasarim/android/04_okuma_detay2.png` | `/readings/:id` | alternate detail state / expanded controls | ayni route, stateful sublayout | Detay durumlari taslakla uyumlu |
| `docs/ui_tasarim/web/04_okuma_detay.png` | `/readings/:id` | split content/detail shell | ayni route, web breakpoint layout | Web detay taslakla uyumlu |
| `docs/ui_tasarim/android/05_gramer.png` | `/grammar` | module list + status cards + alt navigation | `studentGrammarModulesProvider` + progress state | Mobil gramer liste taslakla uyumlu |
| `docs/ui_tasarim/web/05_gramer.png` | `/grammar` | rail + module cards / list | ayni route, web breakpoint layout | Web gramer ekran taslakla uyumlu |
| Faz 4 ekrani - gramer reader | `/grammar/:moduleId` | header + konu ozeti + ilerleme paneli + mini quiz | `studentGrammarModulesProvider` + `studentGrammarProgressProvider` | Reader ilerlemesi local state ve outbox ile tutulur |

## 5. Teknik Kararlar
- Reading/grammar domainleri korunur
- Remote fallback + Android local cache birlikte calisir
- Faz 4 ekranlari Faz 3 shell tokenlari uzerine kurulur, generic foundation shell geri kullanilmaz
- Okuma detay route'u ayrik calisir; liste ekranina gomulu modal ile gecistirilmez
- Reading detail icinde ceviri talebi once lokal cache'te aranir; yoksa preview/remote translation sonucu cache'e yazilir
- Bookmark ve favorite aksiyonlari optimistic UI ile calisir, yazmalar `ProgressRepository.enqueue` uzerinden outbox'a dusurulur
- Grammar reader modal degil ayrik route ile acilir; sayfa ilerlemesi `last_page_no = max`, `completed = OR` semantigi ile yazilir

## 6. Bagimliliklar
- Faz 2 sync
- Faz 3 cekirdek modul altyapisi

## 7. Riskler
- Cumle cevirisi cache tutarliligi

## 8. Test ve Kabul Kriterleri
- Lokal veri varsa offline acilis calisir
- `/readings/:id` bookmark/favorite toggle'lari optimistic olarak guncellenir ve outbox event'i uretir
- Translation paneli ayni oturumda ikinci acilista cache hit verir
- `/grammar/:moduleId` route'u Android ve Web'de acilir
- Grammar reader ilerlemesi `sync_outbox` ve lokal snapshot state'ine yansir

## 9. Ilerleme Durumu
- Durum: Tamamlandi
- Son guncelleme: 2026-03-09

## 10. Tamamlananlar / Notlar
- Dosya olusturuldu
- Faz 4 UI parity referanslari eklendi
- `/readings` route'u arama + segmented filtre + responsive kart yapisina cekildi
- `/readings/:id` route'u detail shell, makale okuyucu, odak modu ve ceviri paneli ile acildi
- `student_reading_engagement_controller.dart` ile bookmark/favorite optimistic state ve outbox event akisi acildi
- `student_translation_controller.dart` ile reading detail icinde bolum bazli translation cache hit/miss davranisi acildi
- `/grammar` route'u banner + modul kartlari + premium lock davranisi ile acildi
- `/grammar/:moduleId` route'u ve `grammar_detail_page.dart` uzerinden reader + mini quiz + progress paneli baglandi
- `student_grammar_progress_controller.dart` ile grammar snapshot ve progress enqueue akisi acildi
- UI parity polish duzeltmeleri `phase_04_5_student_ui_parity_polish.md` altinda yurutuldu ve tamamlandi
- Faz 4 kapanis dogrulamasi:
  - `flutter analyze`
  - `flutter test apps/student_app`
  - `flutter test apps/admin_console`
  - `flutter test packages/shared_data`
  - `flutter build apk --debug --dart-define-from-file=..\\..\\env\\app.web.json`
  - `flutter build web --release --dart-define-from-file=..\\..\\env\\app.web.json`
- 2026-03-09 regresyon kapamasi:
  - `/readings/:id` ekranindaki ceviri ac/gizle akisi duzeltildi
  - Reading translation seed ve reading detail UI metinleri normalize edildi
  - `apps/student_app/test/features/student_ui_behavior_test.dart` ile ceviri davranisi widget test seviyesinde kilitlendi
