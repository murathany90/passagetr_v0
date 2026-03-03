# Stitch UI Uygulama Plani (Faz 3 Sonrasi)

## 1) Amac
Bu plan, `docs/stitch/stitch` altindaki tasarimlari mevcut Flutter arayuzune kontrollu sekilde uygulamak icin implementation-ready yol haritasi sunar.
Hedef: islevleri bozmadan gorunumu modernize etmek, ekranlar arasi tutarlilik saglamak, mevcut Faz 1-3 davranislarini korumak.

## 2) Girdi Kumesi
Kaynak tasarimlar:
- `dark_mode_flashcard_session`
- `dark_mode_home_dashboard`
- `dark_mode_pack_hub`
- `dark_mode_reading_selection`
- `detailed_word_flashcard_back`
- `elegant_word_pack_selection`
- `home_dashboard_status`
- `interactive_flashcard_session`
- `interactive_vocabulary_matching`
- `modern_multiple_choice_quiz`
- `modern_reading_list_items`
- `pack_study_hub_redesign`
- `premium_flashcard_interface`
- `premium_home_dashboard_redesign`
- `premium_test_hub_selection`
- `premium_typing_practice`
- `reading_experience_detail`
- `reading_packs_selection`

## 3) Tasarim Stratejisi (Tek Kural Seti)
1. Birebir HTML kopyasi yapilmayacak; Flutter Material 3 tabanli component-esleme yapilacak.
2. Primary stil kaynagi: `premium_*` ve `elegant_*` ekranlari.
3. Dark mode referansi: `dark_mode_*` ekranlari.
4. Renk sistemi emerald agirlikli kalacak (`#0C6D4F` ailesi), Faz 1-3 akisini bozmayacak.
5. Islevsel davranislar (progress, test kurallari, auth, pagination, translation) degismeyecek; sadece UI/UX sunumu iyilestirilecek.

## 4) Ekran Esleme Matrisi
| Stitch tasarimi | Uygulanacak Flutter ekran(lar)i | Hedef dosya(lar) |
|---|---|---|
| `premium_home_dashboard_redesign`, `home_dashboard_status`, `dark_mode_home_dashboard` | Ana Sayfa dashboard | `lib/features/home/home_dashboard_page.dart` |
| `elegant_word_pack_selection` | Pack list | `lib/features/packs/pack_list_page.dart` |
| `pack_study_hub_redesign`, `dark_mode_pack_hub` | Pack detail / study hub | `lib/features/packs/pack_list_page.dart` |
| `premium_flashcard_interface`, `interactive_flashcard_session`, `detailed_word_flashcard_back`, `dark_mode_flashcard_session` | Flashcard session | `lib/features/flashcard/flashcard_session_page.dart` |
| `premium_test_hub_selection` | Test hub secim ekrani | `lib/features/tests/test_hub_page.dart` |
| `modern_multiple_choice_quiz` | MCQ oturumu | `lib/features/tests/mcq_session_page.dart` |
| `interactive_vocabulary_matching` | Matching oturumu | `lib/features/tests/matching_session_page.dart` |
| `premium_typing_practice` | Typing oturumu | `lib/features/tests/typing_session_page.dart` |
| `reading_packs_selection`, `modern_reading_list_items`, `dark_mode_reading_selection` | Reading home + reading list | `lib/features/readings/reading_home_page.dart`, `lib/features/readings/reading_list_page.dart` |
| `reading_experience_detail` | Reading detail + progress + passage words panel | `lib/features/readings/reading_detail_page.dart` |

## 5) Teknik Uygulama Plani

### Faz A - Theme Foundation (1 gun)
Amac: Tum ekranlara ortak token sistemi kurmak.

Yapilacaklar:
1. `lib/app/app.dart` icinde `theme` + `darkTheme` ayrimini netlestir.
2. Yeni tema dosyalari ac:
   - `lib/core/theme/app_colors.dart`
   - `lib/core/theme/app_text_styles.dart`
   - `lib/core/theme/app_theme.dart`
3. Ortak tokenlar:
   - radius: 12/16/20/24
   - card shadow: soft + elevated
   - spacing scale: 4/8/12/16/24/32
   - semantic colors: success/warning/error/info
4. Bottom nav, app bar, card, chip, button temalari `ThemeData` icinde merkezilesir.

Cikis kriteri:
- Tum ekranlar tek tema katmanindan stil aliyor.

### Faz B - Shared UI Kit (1 gun)
Amac: Tekrarlanan UI bloklarini standartlastirmak.

Yapilacaklar:
1. Ortak widgetlar:
   - `AppSectionHeader`
   - `AppStatTile`
   - `AppGradientCtaButton`
   - `AppSurfaceCard`
   - `AppEmptyState`
   - `AppErrorState`
   - `AppLoadingBlock`
2. Dosya konumu onerisi:
   - `lib/core/widgets/...`
3. PackList, Home, ReadingList, TestHub bu ortak widgetlara gecirilir.

Cikis kriteri:
- Empty/loading/error gorunumleri ekranlar arasi tutarli.

### Faz C - Navigation + Home + Pack Hub (1 gun)
Amac: Uygulamanin ana akis ekranlarini Stitch ile hizalamak.

Yapilacaklar:
1. `main_shell_page.dart`
   - Bottom nav spacing, selected/unselected icon tonu, elevation/blur hissi.
2. `home_dashboard_page.dart`
   - Hero status card
   - 3 metrik karti
   - belirgin "Hizli Basla" CTA
3. `pack_list_page.dart`
   - kart tabanli pack listesi
   - progress bar + badge alanlari
4. `pack_list_page.dart` icindeki `PackDetailPage`
   - "Kelime Calis", "Paragraf Calis", "Test" aksiyonlarini Stitch hiyerarsisine gore yeniden diz.

Cikis kriteri:
- Home/Pack akisi yeni tasarim dilinde tamam.

### Faz D - Learning Screens (2 gun)
Amac: Flashcard + Test ekranlarini premium/interaktif tarza cekmek.

Yapilacaklar:
1. `flashcard_session_page.dart`
   - front/back kart derinligi
   - cevap butonlari (Known/Unsure/Unknown) vurgu hiyerarsisi
   - session summary layout yenileme
2. `test_hub_page.dart`
   - mod kartlari: MCQ / Matching / Typing
3. `mcq_session_page.dart`
   - soru karti + secenek kartlari + sticky action
4. `matching_session_page.dart`
   - tiklamali eslestirme kartlari
5. `typing_session_page.dart`
   - prompt karti + buyuk input + birincil CTA

Cikis kriteri:
- Test modlari görsel olarak birbirine yakin; kullanici hiyerarsisi net.

### Faz E - Reading Experience (1 gun)
Amac: Okuma ekranlarini Stitch detail seviyesine getirmek.

Yapilacaklar:
1. `reading_home_page.dart` + `reading_list_page.dart`
   - section basliklari, kategori chipleri, kart hover/press hissi
2. `reading_detail_page.dart`
   - progress header (x/y + linear bar)
   - sentence card stili
   - "Ceviriyi Goster" secondary CTA
   - TR alani icin ayrik stil (`TR:` label korunacak)
   - "Bu paragraftan kelimeler" panel kart tasarimi
3. `word_quick_view_sheet.dart`
   - popup sheet tipografisi ve CTA hiyerarsisi reading diliyle hizalanir.

Cikis kriteri:
- Reading list/detail ve quick popup tek tasarim dilinde.

### Faz F - Stabilizasyon + QA (0.5-1 gun)
Amac: UI patch sonrasi regresyon engellemek.

Yapilacaklar:
1. `flutter analyze`
2. `flutter test`
3. smoke:
   - auth bootstrap
   - pack/word pagination
   - flashcard progress write
   - test progress write
   - reading translation + quick popup
4. Dokuman snapshot guncelle:
   - `README.md` UI akis gorselleri/metinleri
   - `docs/phase3_smoke_test_checklist.md` gerekirse UI notlari

## 6) Uygulama Siralamasi (Oncelik)
1. Theme + shared widgetlar
2. Home + Pack ekranlari
3. Flashcard + Test ekranlari
4. Reading ekranlari
5. QA ve dokumantasyon

## 7) Riskler ve Azaltma
1. Risk: Faz 1-3 davranislari istemeden bozulur.
   - Azaltma: UI-only PR dilimleme; is kurali degisikliklerini ayri tut.
2. Risk: Theme gecisinde renk kontrasti dusuk kalir.
   - Azaltma: acik/koyu modda metin-kontrast kontrol checklisti.
3. Risk: Ortak widget refactorinda ekranlar arasi farkli exception state'ler kaybolur.
   - Azaltma: error/empty state metinlerini dosya bazli koruyarak sadece stil tasi.

## 8) Kabul Kriterleri
1. Ana sekmeler (Home/Kelime/Okuma/Profil) Stitch diline yakin tek tip gorunume sahip.
2. Home dashboard, pack list, pack hub, flashcard, test ve reading ekranlari arasinda tipografi/renk/buton tutarliligi var.
3. Quick Word Popup dahil mevcut Faz 3 davranislari aynen calisiyor.
4. `flutter analyze` temiz.
5. `flutter test` temiz.

## 9) Tahmini Efor
Toplam: 6-7 is gunu (tek gelistirici, review dahil).

## 10) Not
Bu plan sadece UI uygulama planidir. Supabase schema, import akislar ve Faz 1-3 is kurallari bu kapsamda degistirilmez.
