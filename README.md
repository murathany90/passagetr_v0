# Ä°ngilizce Ã–ÄŸrenme UygulamasÄ± (Faz 1-4, GÃ¼ncel)

Bu repo, Flutter + Supabase tabanlÄ± Ä°ngilizce Ã¶ÄŸrenme uygulamasÄ±nÄ±n gÃ¼ncel sÃ¼rÃ¼mÃ¼nÃ¼ iÃ§erir.
Mevcut kapsam artÄ±k yalnÄ±zca Faz 1 deÄŸil; Faz 2 (reading/Ã§eviri), Faz 3 (dashboard/akÄ±ÅŸ iyileÅŸtirmeleri) ve Faz 4 (gramer modÃ¼lÃ¼ + content pipeline) dahildir.

## Kapsam Ã–zeti

- Faz 1: Kelime paketleri, flashcard, test hub, progress takibi
- Faz 2: Reading modÃ¼lÃ¼, Ã§eviri servisleri ve Ã§eviri cache
- Faz 3: Home/dashboard ve gezinme akÄ±ÅŸÄ± iyileÅŸtirmeleri
- Faz 4: Gramer modÃ¼lÃ¼, markdown->json dÃ¶nÃ¼ÅŸtÃ¼rme ve Supabase yÃ¼kleme pipeline'Ä±

## Mimari ve Teknolojiler

- Framework: Flutter
- State management: Riverpod
- Backend: Supabase
- Render: `flutter_html`, `flutter_html_table`
- Local lightweight state: `shared_preferences`

### BaÄŸÄ±mlÄ±lÄ±k Ã–zeti (`pubspec.yaml`)

| TÃ¼r | Paket | AmaÃ§ |
|---|---|---|
| dependency | `flutter_riverpod` | Provider/state katmanÄ± |
| dependency | `supabase_flutter` | Auth + DB eriÅŸimi |
| dependency | `shared_preferences` | Basit lokal kalÄ±cÄ±lÄ±k |
| dependency | `flutter_html` | HTML iÃ§erik render |
| dependency | `flutter_html_table` | HTML table desteÄŸi |
| dependency | `http` | Servis Ã§aÄŸrÄ±larÄ± |
| dependency | `google_fonts` | Tipografi |
| dev_dependency | `flutter_test` | Test |
| dev_dependency | `flutter_lints` | Lint kurallarÄ± |

### Proje KlasÃ¶r YapÄ±sÄ± (`lib/`)

```text
lib/
|-- main.dart                  # Uygulama giriÅŸ noktasÄ±, Supabase init
|-- app/                       # MaterialApp, routing ve app-level yapÄ±
|-- core/                      # Ortak altyapÄ±
|   |-- auth/                  # Oturum/anon auth yardÄ±mcÄ±larÄ±
|   |-- config/                # dart-define / env config okuma
|   |-- constants/             # Uygulama sabitleri
|   |-- services/              # Harici servis katmanÄ± (Ã§eviri vb.)
|   |-- theme/                 # Renk, tipografi, tema tanÄ±mlarÄ±
|   |-- utils/                 # Saf yardÄ±mcÄ± fonksiyonlar
|   `-- widgets/               # Yeniden kullanÄ±labilir UI bileÅŸenleri
|-- data/
|   `-- repositories/          # Supabase repository implementasyonlarÄ±
|-- domain/
|   |-- entities/              # Ä°ÅŸ modeli nesneleri
|   |-- repositories/          # Repository arayÃ¼zleri
|   `-- value_objects/         # Value object tipleri
|-- features/                  # Feature-first ekran/modÃ¼l yapÄ±sÄ±
|   |-- bootstrap/             # AÃ§Ä±lÄ±ÅŸ/baÅŸlatma akÄ±ÅŸÄ±
|   |-- home/                  # Dashboard
|   |-- shell/                 # Bottom navigation container
|   |-- packs/                 # Paket listesi
|   |-- words/                 # Kelime liste/detay
|   |-- flashcard/             # Flashcard oturumlarÄ±
|   |-- tests/                 # MCQ, matching, typing testleri
|   |-- readings/              # Okuma modÃ¼lÃ¼
|   |-- grammar/               # Gramer modÃ¼lÃ¼ (modÃ¼l/sayfa/reader)
|   `-- profile/               # Profil ve debug/ayar ekranlarÄ±
`-- state/
    `-- providers.dart         # Riverpod provider tanÄ±mlarÄ±
```

## Kurulum ve Ä°lk Ã‡alÄ±ÅŸtÄ±rma

## 1) Repo kurulum

```bash
git clone <REPO_URL>
cd ingilizce_app1
flutter pub get
```

## 2) KonfigÃ¼rasyon dosyalarÄ±

### Flutter app config (`env/app.dev.json`)

```bash
cp env/app.dev.json.example env/app.dev.json
```

`env/app.dev.json` Ã¶rnek iÃ§erik:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_xxx",
  "TRANSLATE_PROVIDER": "deepl"
}
```

### Uploader config (`.env`)

```bash
cp .env.example .env
```

`.env` Ã¶rnek iÃ§erik:

```env
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sb_secret_xxx
```

Not:
- Mobil uygulama tarafÄ±nda yalnÄ±zca `SUPABASE_ANON_KEY` (`sb_publishable_...`) kullanÄ±lmalÄ±dÄ±r.
- `SUPABASE_SERVICE_ROLE_KEY` yalnÄ±zca script/server tarafÄ±nda kullanÄ±lmalÄ±dÄ±r.

## 3) UygulamayÄ± Ã§alÄ±ÅŸtÄ±rma

Windows (PowerShell script):

```powershell
.\scripts\run_flutter_dev.ps1
```

macOS/Linux veya script kullanmak istemeyenler:

```bash
flutter run --dart-define-from-file=env/app.dev.json
```

## Android Build Gereksinimleri (Repo GerÃ§eÄŸi)

- Java: 17
- Kotlin plugin: `2.2.20` (`android/settings.gradle.kts`)
- Gradle wrapper: `8.14` (`android/gradle/wrapper/gradle-wrapper.properties`)
- Android compile/min/target SDK: Flutter tarafÄ±ndan saÄŸlanÄ±r (`flutter.compileSdkVersion`, `flutter.minSdkVersion`, `flutter.targetSdkVersion`)
- NDK: Flutter tarafÄ±ndan saÄŸlanÄ±r (`flutter.ndkVersion`)

## Supabase Kurulum AkÄ±ÅŸÄ± (KÄ±sa)

## 1) Migration uygula

CLI ile:

```bash
supabase db push
```

Alternatif:
- Supabase SQL Editor aÃ§
- `supabase/migrations/*.sql` iÃ§eriÄŸini sÄ±rayla Ã§alÄ±ÅŸtÄ±r

## 2) RLS mantÄ±ÄŸÄ± Ã¶rnek (doÄŸrulanmÄ±ÅŸ desen)

`user_word_progress` iÃ§in temel politika mantÄ±ÄŸÄ±:

```sql
create policy progress_select_own on public.user_word_progress
for select to authenticated
using (auth.uid() = user_id);
```

Benzer ÅŸekilde insert/update iÃ§in `with check (auth.uid() = user_id)` uygulanÄ±r.

## 3) Ã–rnek veri yÃ¼kleme (Ã¶zet)

- Kelime setleri/okuma iÃ§erikleri iÃ§in: `docs/supabase_csv_import.md`, `docs/supabase_readings_import.md`
- Gramer verisi iÃ§in:
  1. Markdown -> JSON
  2. JSON -> Supabase uploader

## Faz 4 - Gramer ModÃ¼lÃ¼ ve Pipeline

- Markdown kaynak klasÃ¶rÃ¼: `docs/gramer`
- Converter: `markdown_to_json_converter.py`
- Uploader: `supabase_uploader.py`
- Migration: `supabase/migrations/202603030005_grammar.sql`
- Flutter ekranlarÄ±: `lib/features/grammar/`

### Gramer komutlarÄ±

```powershell
python markdown_to_json_converter.py --input-dir docs/gramer --output-dir json_output
.\scripts\upload_grammar.ps1 -Mode replace -DryRun
.\scripts\upload_grammar.ps1 -Mode replace
```

Alternatif uploader:

```powershell
python supabase_uploader.py --json-file json_output/tum_gramer_modulleri.json --mode replace
```

## UI AkÄ±ÅŸÄ± (TutarlÄ± Ã–zet)

1. AÃ§Ä±lÄ±ÅŸ/Splash: Supabase baÄŸlantÄ±sÄ± kontrol edilir, anonim oturum baÅŸlatÄ±lÄ±r.
2. Paket listesi: KullanÄ±cÄ± Ã§alÄ±ÅŸacaÄŸÄ± paketi seÃ§er.
3. Kelime listesi: Arama/filtreleme yapÄ±lÄ±r, buradan **Ã¶ÄŸrenme oturumu baÅŸlatÄ±lÄ±r**.
4. Flashcard oturumu: Bilme dÃ¼zeyi iÅŸaretlenir, progress gÃ¼ncellenir.
5. Test hub: MCQ / eÅŸleÅŸtirme / yazma testleri.
6. Reading: Metin, Ã§eviri ve kelime etkileÅŸimleri.
7. Gramer: ModÃ¼l listesi -> modÃ¼l sayfalarÄ± -> reader akÄ±ÅŸÄ±.

### Temsili UI Ã‡izimi (Wireframe)

```text
+-----------------------------------+
| ingilizce_app1                    |
+-----------------------------------+
| [Ana Sayfa] [Kelime] [Okuma] [Gramer] [Profil]  <- Bottom Nav
+-----------------------------------+

[KELIME LISTESI]
+-----------------------------------+
| Arama...                    [Filtre]
| Paket: YDS Set 001                |
|-----------------------------------|
| abandon          terk etmek       |
| ability          yetenek          |
| ...                               |
|-----------------------------------|
| [KARTLARLA OGRENMEYE BASLA]       |
+-----------------------------------+

[TEST HUB]
+-----------------------------------+
| < Geri           TEST MERKEZI     |
| [Coktan Secmeli] [Eslestirme] [Yaz]
|-----------------------------------|
| Soru: "ability"                   |
| ( ) mevcut olmayan                |
| (*) yetenek                       |
| ( ) terk etmek                    |
|-----------------------------------|
| [CEVAPLA]                         |
+-----------------------------------+

[READING DETAIL]
+-----------------------------------+
| < Geri          A Day in Paris    |
|-----------------------------------|
| The weather was breathtaking...   |
| [Ceviriyi Goster]                 |
|-----------------------------------|
| Hava ... nefes kesiciydi.         |
+-----------------------------------+

[GRAMER - MODUL LISTESI]
+-----------------------------------+
| < Geri         INGILIZCE GRAMER   |
|-----------------------------------|
| [1] Temel Kavramlar        16 sf  |
| [2] Tense System           25 sf  |
| [3] Modality               15 sf  |
| ...                               |
+-----------------------------------+

[GRAMER - MODUL SAYFALARI]
+-----------------------------------+
| < Geri      Adjectives/Adverbs    |
|-----------------------------------|
| 1) Sifatlar - Tanim ve Turetme    |
| 2) Sifatlarin Sirasi              |
| ...                               |
| 20) Bolum Tarama Testi            |
+-----------------------------------+

[GRAMER - READER]
+-----------------------------------+
| < Geri         Adjectives/Adverbs |
| 3/20  [=========-----]            |
|-----------------------------------|
| Sayfa basligi                     |
| HTML icerik (tablo + metin)       |
|-----------------------------------|
| Ornekler                          |
| Mini Test                         |
+-----------------------------------+
```

## Faz 3 Ã–zet AkÄ±ÅŸÄ±

- Bottom nav: `Ana Sayfa / Kelime / Okuma / Gramer / Profil`
- Home hÄ±zlÄ± baÅŸlangÄ±Ã§: `resume reading -> weak words -> random words`
- Reading detail: seÃ§im ve hÄ±zlÄ± sÃ¶zlÃ¼k etkileÅŸimi
- Gramer reader: modÃ¼l bazlÄ± sayfa ilerleme akÄ±ÅŸÄ±

## Test ve Kalite Kontrolleri

```bash
flutter analyze
flutter test
python -m py_compile markdown_to_json_converter.py supabase_uploader.py
```

Not:
- Typing testi ÅŸu an esasen exact-match davranÄ±ÅŸÄ±na yakÄ±ndÄ±r.
- Typo tolerance yardÄ±mcÄ± katmanlarÄ± bazÄ± akÄ±ÅŸlarda vardÄ±r, ancak typing doÄŸrulamasÄ±na otomatik geniÅŸ tolerans olarak garanti edilmez.

## Operasyonel Risk NotlarÄ±

- Anonymous auth hÄ±zlÄ± onboarding saÄŸlar; ancak cihaz deÄŸiÅŸimi/uygulama silme sonrasÄ± kullanÄ±cÄ± kimliÄŸi taÅŸÄ±namazsa ilerleme geri getirilemeyebilir.
- Public translation fallback endpoint'leri geliÅŸtirmede pratik olsa da production iÃ§in gizlilik, limit ve uptime riskleri barÄ±ndÄ±rÄ±r.

## Troubleshooting

| Sorun | Belirti | Kontrol / Ã‡Ã¶zÃ¼m |
|---|---|---|
| Supabase URL/Key eksik | Uygulama Supabaseâ€™e baÄŸlanmaz | `SUPABASE_URL` + `SUPABASE_ANON_KEY` deÄŸerlerini kontrol et |
| Anonymous provider kapalÄ± | AÃ§Ä±lÄ±ÅŸta anonim oturum oluÅŸmaz | Supabase Dashboard -> Auth -> Providers -> Anonymous aÃ§ |
| Android INTERNET izni eksik | `Failed host lookup` / `SocketException` | `AndroidManifest.xml` iÃ§inde INTERNET iznini doÄŸrula |
| Translation endpoint yok | Ã‡eviri Ã¶zelliÄŸi Ã§alÄ±ÅŸmaz | Endpoint tanÄ±mla veya fallback davranÄ±ÅŸÄ±nÄ± kabul et |

## Android Release Notu (Split APK)

KÃ¼Ã§Ã¼k boyutlu APK (ABI bazlÄ±):

```powershell
flutter build apk --release --split-per-abi --dart-define-from-file=env/app.dev.json
```

## Not: T?rk?e Karakterler

Bu README dosyas? **UTF-8** kodlamas? ile tutulur. T?rk?e karakterlerin (?, ?, ?, ?, ?, ?, ?) bozulmamas? i?in dosyay? UTF-8 olarak a??p kaydedin.

PowerShell ile dosya yazarken UTF-8 kullan?n: `Set-Content -Encoding UTF8` veya `Out-File -Encoding utf8`.

## Faz 3.1 Stabilizasyon Notu

- Bottom nav guncellendi: `Ana Sayfa / Kelime / Okuma / Gramer / Profil`.
- Ayrik `Sozluk` sekmesi kaldirildi; sozluk aramasi `Kelime` sekmesindeki birlesik arama kutusuna tasindi.
- Kelime aramasinda sonuc karti varsa iki aksiyon sunulur: `Kelime Karti` ve `Sozluk`.
- ReadingDetail odak kelimeler paneli varsayilan kapali gelir; acildiginda EN + TR anlam listelenir.
- Reading quick word popup layoutu tasma yapmayacak sekilde yeniden hizalandi.
- Home/Profile auth akisinda anonim session zorunlu hale getirildi; auth hatalari kullanici dostu Retry mesaji ile gosterilir.

## Faz 3.1 Ek Guncelleme (Kelime/SÃ¶zlÃ¼k Birlesimi + UI Stabilizasyon)

Bu bolum, mevcut Faz 3.1 notlarina ek olarak son patchlerde gelen davranis guncellemelerini listeler.

### 1) Navigasyon ve Bilgi Mimarisi

- Bottom nav artik 5 sekmelidir: `Ana Sayfa / Kelime / Okuma / Gramer / Profil`.
- Ayrik `Sozluk` sekmesi shell'den cikarilmistir.
- Sozluk ozelligi kaldirilmadi; `Kelime` sekmesi icinde birlesik arama deneyimine tasindi.

### 2) Kelime Sekmesi (Yeni Birlesik Arama Akisi)

- Kelime sekmesinde ustte tek bir arama kutusu bulunur.
- Bos aramada gereksiz sorgu atilmaz, yonlendirme metni gosterilir.
- Arama sonucu kelime kartinda eslesirse:
  - `Kelime Karti` aksiyonu ile `WordDetail` acilir.
  - `Sozluk` aksiyonu ile dictionary/fallback sonucu acilir.
- Arama sonucu kelime kartinda yoksa:
  - `Sozluk` aksiyonu ile fallback lookup sonucu acilir.
- Kelime sekmesinin altinda pack listesi gomulu kalir (`PackListPage(embedded: true)`).

### 3) Auth Stabilizasyonu

- `appBootstrapProvider` auth hatalarini artik swallow etmez.
- Home/Profile veri providerlari auth session kurulmadan metrik sorgularina gecmez.
- Gecici oturum kopmalarinda bir kez otomatik toparlama (retry) uygulanir.
- Kullaniciya gosterilen hata dili teknik yerine aksiyon odaklidir (`Retry`).

### 4) Reading Quick Word Popup Iyilestirmesi

- Popup ust bolumunde baslik ve etiketler `Column + Wrap` duzenine alinmistir.
- Uzun kelime ve uzun etiketlerde satir kirilmasi/overflow riski azaltilmistir.
- Bulunan kelime kartinda `trMeaning` chip satirindan ayrilip ayri blokta gosterilir.
- Synonym/antonym chipleri iliskili kelime veya sozluk fallback akisini tetikleyebilir.
- `Kaynakta Ac` otomatik calismaz, sadece butonla dis tarayici acilir.

### 5) Reading Odak Kelimeler Paneli

- Panel varsayilan olarak kapalidir (collapse/expand).
- Panel acildiginda her satirda `EN + TR + POS` bilgisi gosterilir.
- `Kelime Calis` ve `Mini MCQ` aksiyonlari panel acikken gorunur.
- Odak kelimeler mevcut deterministic highlight yaklasimiyla uyumlu uretilir.

### 6) Sayac Tutarliligi

- Pack kartlarinda gorunen kelime sayisi tek bir kaynak semasiyla sunulur (`Pack.wordCount`).
- Reading pack kart metni `X kelime` formatina alinmistir.
- Word ve Reading yuzeyinde ayni pack icin ayni sayi gosterilmesi hedeflenmistir.

### 7) Build Notu (Kucuk APK)

Kucuk boyutlu arm64 release APK icin:

```powershell
flutter build apk --release --target-platform android-arm64 --split-per-abi --dart-define-from-file=env/app.dev.json
```

Beklenen cikti:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

## Screenshots

### 1) Home Dashboard
![Home Dashboard](docs/screenshots/01_home_dashboard.png)

### 2) Word List
![Word List](docs/screenshots/02_word_list.png)

### 3) Test Hub
![Test Hub](docs/screenshots/03_test_hub.png)

### 4) Reading Detail
![Reading Detail](docs/screenshots/04_reading_detail.png)

### 5) Grammar Modules
![Grammar Modules](docs/screenshots/05_grammar_modules.png)

### 6) Grammar Reader
![Grammar Reader](docs/screenshots/06_grammar_reader.png)
