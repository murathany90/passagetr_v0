# Faz 3 - Cekirdek Ogrenme Modulleri

## 1. Faz Amaci
Kelime, flashcard ve temel test modullerini yeni mimari uzerinde acmak.

## 2. Kapsam
- `apps/student_app` shell parity refactor
- Ana sayfa parity implementasyonu
- Pack/word listeleme
- Flashcard ve test merkezi
- User progress entegrasyonu

## 3. Kapsam Disi
- Okuma detay ve gramer reader

## 4. Yapilacak Isler
- [x] `docs/ui_tasarim` referans ekranlarini Faz 3 kapsamina esle
- [x] UI parity checklist'ini ekle
- [x] `student_app` shell yapisini `docs/ui_tasarim` ana sayfa ve kelimeler ekranlari ile hizala
- [x] Ana sayfa parity ekranini bagla
- [x] Kelime paket ekranlarini bagla
- [x] `ProgressRepository` uzerinden `user_word_progress` snapshot okuma akisini ac
- [x] `student_app` icin `word progress` provider/controller katmanini ekle
- [x] `/words/flashcards` rotasi ve flashcard oturumu ekranini uygula
- [x] `/words/tests` rotasi ve mini test merkezi ekranini uygula
- [x] Flashcard sonucunu `user_word_progress` outbox event'i olarak enqueue et
- [x] Test sonucunu `user_word_progress` ve `user_test_attempts` outbox event'lerine bagla
- [x] Kelime ekranina progress ozetleri ve calisma merkezi kartlarini bagla
- [x] Flashcard/test akisini ac
- [x] Progress repository'lerini remote/local ile bagla

### UI Parity Checklist
| Taslak | Route | Hedef Widget Agaci | Veri Kaynagi | Kabul Kriteri |
|---|---|---|---|---|
| `docs/ui_tasarim/android/01_anasayfa.png` | `/` | responsive student shell + streak hero + continue card + review card + weekly chart | `studentPacksProvider`, `studentReadingsProvider`, turetilmis local metrics | Mobilde alt navigation ve kart hiyerarsisi taslakla uyumlu |
| `docs/ui_tasarim/web/01_anasayfa.png` | `/` | rail sidebar + iki kolon dashboard + pro badge | ayni route, web breakpoint layout | Webde sidebar ve dashboard grid taslakla uyumlu |
| `docs/ui_tasarim/android/02_kelimeler.png` | `/words` | search bar + package cards + alt navigation | `studentPacksProvider` + turetilmis progress ozetleri | Mobilde kelime arama ve kart listesi taslakla uyumlu |
| `docs/ui_tasarim/web/02_kelimeler.png` | `/words` | rail sidebar + search bar + 3 kolon kart grid | ayni route, web breakpoint layout | Webde search + 3 kolon pack grid taslakla uyumlu |
| Faz 3 ekrani - flashcard merkezi | `/words/flashcards` | header + ilerleme bandi + flashcard deck + aksiyon butonlari | `studentWordsProvider` + `studentWordProgressProvider` | Bir kelime oturumu local progress ile ilerler ve cevap enqueue edilir |
| Faz 3 ekrani - mini test merkezi | `/words/tests` | header + soru karti + secenekler + sonuc ozeti | `studentWordsProvider` + `studentWordProgressProvider` | Mini test tamamlanir, score ozeti ve enqueue akisi calisir |

## 5. Teknik Kararlar
- `user_word_progress` korunur
- Word domainleri additive evrilir
- `docs/ui_tasarim` Faz 3 icin layout, spacing ve komponent referansi olarak baglayicidir
- Faz 3 tamamlanana kadar `SummaryCard` tabanli generic foundation ekranlari urun ekrani olarak kullanilmaz
- Mobil shell alt `NavigationBar`, web shell sol rail / sidebar kullanir
- `user_word_progress` okumasi once lokal `progress_snapshot_cache` uzerinden yapilir; lokal cache bos ise preview fallback kullanilir
- Flashcard cevaplari `known`, `unsure`, `unknown` answer semantigi ile yazilir
- Mini test sonunda tek tek soru cevaplari icin word progress event'i, oturum sonunda toplu test attempt event'i yazilir

## 6. Bagimliliklar
- Faz 2 lokal veri katmani

## 7. Riskler
- Progress event semantigi

## 8. Test ve Kabul Kriterleri
- `student_app` ana sayfa ve kelimeler ekranlari Android ve Web'de taslaklara sadik gorunur
- Flashcard ilerlemesi lokal ve remote tutarli olur
- `/words/flashcards` ve `/words/tests` rotalari Android ve Web build'de acilir
- Word progress snapshot'lari kelime kartlari ve calisma merkezinde gorunur
- Flashcard ve mini test oturumu sonunda `sync_outbox` icinde ilgili event'ler olusur

## 9. Ilerleme Durumu
- Durum: Tamamlandi
- Son guncelleme: 2026-03-09

## 10. Tamamlananlar / Notlar
- Dosya olusturuldu
- Faz 3 UI parity referanslari eklendi
- `shared_ui` tema token'lari ve ogrenci shell'i `docs/ui_tasarim` referanslarina gore yeniden kuruldu
- `/` rotasi icin streak hero, devam et, tekrar ve haftalik ilerleme kartlari baglandi
- `/words` rotasi icin arama + responsive pack grid yapisi baglandi
- `student_word_progress_controller.dart` ile word progress snapshot okuma, flashcard sonucu ve mini test sonucu enqueue akisi acildi
- `/words/flashcards` ve `/words/tests` rotalari baglandi; kelime ekrani calisma merkezi ve progress kartlariyla guncellendi
- `FoundationProgressRepository` lokal/remote progress snapshot ve outbox entegrasyonu ile Faz 3 akislarini destekler hale getirildi
- UI parity polish duzeltmeleri `phase_04_5_student_ui_parity_polish.md` altinda yurutuldu ve tamamlandi
- Faz 3 kapanis dogrulamasi:
  - `flutter analyze`
  - `flutter test apps/student_app`
  - `flutter test apps/admin_console`
  - `flutter test packages/shared_data`
  - `flutter build apk --debug --dart-define-from-file=..\\..\\env\\app.web.json`
  - `flutter build web --release --dart-define-from-file=..\\..\\env\\app.web.json`
