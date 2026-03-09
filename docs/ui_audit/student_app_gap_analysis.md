# Student App — Gap Analysis: Figma Tasarım vs Mevcut Flutter UI

> **Tarih**: 2026-03-08
> **Kaynak**: `docs/ui_tasarim/web/*.png` (Figma export)
> **Kapsam**: `apps/student_app` — 6 öncelikli ekran

---

## Ekran Bazlı Gap Tablosu

### 1. Ana Sayfa (`/`)

| Kriter | Figma Tasarım | Mevcut Flutter Kodu | Durum |
|---|---|---|---|
| **Figma Ekranı** | `01_anasayfa.png` | — | — |
| **Mevcut Route** | `/` | `StudentHomePage` | ✅ |
| **Mevcut Dosya** | — | `features/home/home_page.dart` | — |
| **Sayfa Başlığı** | "Hoş Geldin, Ahmet! 👋" (emoji) | `'Hos Geldin, Ahmet!'` (emoji yok) | ⚠️ Unicode emoji eksik |
| **Alt Başlık** | "Bugün yeni bir şeyler öğrenmeye hazır mısın?" | `'Bugun yeni bir seyler ogrenmeye hazir misin?'` | ⚠️ Türkçe karakter (ş,ö,ü,ı,ç) eksik |
| **Pro Görünüm Pill** | Turuncu outline + yıldız icon | ✅ `_ProPill` widget | ✅ Eşleşiyor |
| **Streak Hero Card** | Turuncu gradient, 🔥 icon, "7 Gün" | ✅ `_StreakHeroCard` | ✅ Eşleşiyor |
| **Continue Reading Card** | "KALDIĞIN YERDEN DEVAM ET", "The Evolution of AI", "%65" | Farklı okuma: "The Silent Ocean", %45 | ⚠️ Veri farkı (kabul edilebilir) |
| **Review Card** | "Gözden Geçirilecekler", 12 Kelime, yıldız circle | ✅ `_ReviewCard` | ✅ Eşleşiyor |
| **Weekly Progress Card** | Haftalık İlerleme, trend grafiği, "Bu Hafta" pill | ✅ `_WeeklyProgressCard` | ✅ Eşleşiyor |
| **Layout (Desktop)** | 2 col hero row + 2 col second row | ✅ `LayoutBuilder` isWide≥860 | ✅ Eşleşiyor |
| **Metric Pills** | Günlük ilerleme + kelime/cümle count | ✅ `_MetricPill` var | ⚠️ Figma'da metric pill'ler görünmüyor düşük öncelik |
| **Hafta Günleri** | Sal, Çar, Per, Cum, Cmt, Paz | `_WeekLabel`: Sal, Car, Per, Cum, Cmt, Paz | ⚠️ "Çar" → "Car" Türkçe karakter |

**Eksik Bileşenler**: Yok (tam eşleşme)
**Etkilenecek Dosyalar**: `home_page.dart` (Türkçe karakter düzeltmesi)

---

### 2. Kelimeler (`/words`)

| Kriter | Figma Tasarım | Mevcut Flutter Kodu | Durum |
|---|---|---|---|
| **Figma Ekranı** | `02_kelimeler.png` | — | — |
| **Mevcut Route** | `/words` | `StudentWordsPage` | ✅ |
| **Mevcut Dosya** | — | `features/words/words_page.dart` | — |
| **Sayfa Başlığı** | "Kelimeler" | ✅ `'Kelimeler'` | ✅ |
| **Alt Başlık** | "Kelime hazinene yeni kelimeler ekle." | ✅ Tam eşleşiyor | ✅ |
| **Search Field** | Kelime havuzunda veya sözlükte ara... | ✅ `StudentSearchField` | ✅ |
| **Section Title** | "Kelime Paketleri" | ✅ `StudentSectionTitle` | ✅ |
| **Pack Card Layout** | 3 sütun grid, kart başına: icon + renk, kelime sayısı, isim, progress | ✅ `StudentPackCard` | ✅ Eşleşiyor |
| **Pack Icon** | Figma: renkli folder icon (dolgulu) | Kod: `Icons.folder_outlined` (outline) | ⚠️ Outline vs filled |
| **Pack Accent Renkleri** | Mavi, yeşil, mor, turuncu, pembe, mor | `_packAccentColor` palette | ✅ Yakın |
| **Progress Bar Rengi** | Her paketin kendi accent rengi | ✅ `accentColor` param | ✅ |
| **Grid Responsive** | 3 col (≥980), 2 col (≥620), 1 col | ✅ `LayoutBuilder` | ✅ |

**Eksik Bileşenler**: Yok
**Etkilenecek Dosyalar**: `words_page.dart` (icon filled yapma, düşük öncelik)

---

### 3. Okuma Odası (`/readings`)

| Kriter | Figma Tasarım | Mevcut Flutter Kodu | Durum |
|---|---|---|---|
| **Figma Ekranı** | `03_okuma.png` | — | — |
| **Mevcut Route** | `/readings` | `StudentReadingsPage` | ✅ |
| **Mevcut Dosya** | — | `features/readings/readings_page.dart` | — |
| **Sayfa Başlığı** | "Okuma Odası" | ✅ `'Okuma Odasi'` | ⚠️ Türkçe "ı" |
| **Toggle** | "Okuma Listem / Keşfet" | ✅ `SegmentedButton` | ✅ |
| **Kart Artwork** | **Gerçek fotoğraf**: dağ manzarası, uzay, kahve | **Gradient placeholder** + icon overlay | ❌ Büyük fark |
| **Kart Layout** | Üst: artwork (foto), alt: başlık + özet + progress/state | ✅ Aynı yapı | ✅ |
| **Level Badge** | "Zor" (kırmızımsı), "Orta" (turuncu), "Kolay" (yeşil) | ✅ `_CardChip` + `levelBadgeColor` | ✅ |
| **Duration Badge** | "⏱ 15 dk" pill | ✅ `_CardChip` icon + label | ✅ |
| **Progress / State** | İLERLEME %45 / "Okumaya Başla →" / "● Tamamlandı" | ✅ 3 durum da mevcut | ✅ |
| **Desktop Search** | Sağ üst köşe arama | ✅ `headerAction: StudentSearchField` | ✅ |

**Eksik Bileşenler**:
- ❌ **Gerçek okuma görselleri**: Figma'da her reading card'da gerçek fotoğraf var, mevcut kodda gradient + icon placeholder
- Bu, en büyük görsel farktır

**Etkilenecek Dosyalar**: `readings_page.dart`, `reading_seed_data.dart` (asset ekleme), potansiyel olarak medya asset'leri

---

### 4. Okuma Detay (`/readings/:id`)

| Kriter | Figma Tasarım | Mevcut Flutter Kodu | Durum |
|---|---|---|---|
| **Figma Ekranı** | `04_okuma_detay.png` | — | — |
| **Mevcut Route** | `/readings/:readingId` | `StudentReadingDetailPage` | ✅ |
| **Mevcut Dosya** | — | `features/readings/reading_detail_page.dart` | — |
| **Header Bar** | "< Geri Dön" + bookmark + share + menu | ✅ `_DetailHeader` | ✅ |
| **3-Panel Layout** | Sol: info, Orta: article, Sağ: focus words | ✅ `LayoutBuilder isWide≥1080` | ✅ |
| **Info Panel** | Artwork (gerçek foto), başlık, yazar, süre, seviye, TTS/Odak butonları | ✅ Tam eşleşiyor | ✅ (artwork hariç) |
| **Info Panel Artwork** | **Gerçek fotoğraf** | **Gradient placeholder** | ❌ Fark |
| **Article Panel** | Başlık, seviye badge, body text, **highlighted words (sarı)** | ✅ `_buildHighlightedSpans` ile sarı highlight | ✅ |
| **Focus Words Panel** | "ODAK KELİMELER" başlığı, kelime kartları | ✅ `_FocusWordsPanel` | ✅ |
| **Kategori Badge** | Sol panelde etiket | ✅ `DecoratedBox` ile kategori | ✅ |

**Eksik Bileşenler**:
- ❌ Gerçek artwork görseli (gradient placeholder)

**Etkilenecek Dosyalar**: `reading_detail_page.dart` (artwork asset)

---

### 5. Gramer Modülleri (`/grammar`)

| Kriter | Figma Tasarım | Mevcut Flutter Kodu | Durum |
|---|---|---|---|
| **Figma Ekranı** | `05_gramer.png` | — | — |
| **Mevcut Route** | `/grammar` | `StudentGrammarPage` | ✅ |
| **Mevcut Dosya** | — | `features/grammar/grammar_page.dart` | — |
| **Sayfa Başlığı** | "Gramer Modülleri" | ✅ `'Gramer Modulleri'` | ⚠️ "ü" eksik |
| **Intro Card** | Mavi icon + "Gramer Nasıl Çalışılmalı?" + açıklama | ✅ `_GrammarIntroCard` | ✅ |
| **Module Card** | Icon circle + başlık + sayfa sayısı pill + açıklama | ✅ `_GrammarModuleCard` | ✅ |
| **Completed State** | Yeşilimsi check icon ("1. Temel Kavramlar") | ✅ `GrammarModuleState.completed` | ✅ |
| **In-Progress State** | İlerleme çubuğu + %30 | ✅ `StudentProgressBar` + yüzde | ✅ |
| **Locked State** | Gri text + kilit icon | ✅ `isLocked` → gri text/icon | ✅ |
| **Background Number** | Büyük, soluk modul numarası (arka plan) | ✅ `displayLarge` fontSize:96 surfaceMuted | ✅ |

**Eksik Bileşenler**: Yok (tam eşleşme)
**Etkilenecek Dosyalar**: `grammar_page.dart` (Türkçe karakter)

---

### 6. Profil (`/profile`)

| Kriter | Figma Tasarım | Mevcut Flutter Kodu | Durum |
|---|---|---|---|
| **Figma Ekranı** | `05_profil.png` | — | — |
| **Mevcut Route** | `/profile` | `StudentProfilePage` | ✅ |
| **Mevcut Dosya** | — | `features/profile/profile_page.dart` | — |
| **Avatar** | Büyük dairesel avatar (kişi ikonu + turuncu ring) + ayar dişlisi | ❌ Yok | ❌ |
| **Kullanıcı Adı** | "Ahmet Yılmaz" büyük başlık | ❌ Yok | ❌ |
| **E-posta** | "📧 ahmet.yilmaz@example.com" | E-posta text input olarak var | ⚠️ Farklı gösterim |
| **PRO Banner** | Koyu lacivert gradient kart: "PASSAGETR PRO" + açıklama + "Hemen Yükselt" CTA butonu | ❌ Tamamen yok | ❌ |
| **Uygulama Ayarları** | Tema (Açık/Koyu/Sistem toggle), Uygulama Dili dropdown | ❌ Yok | ❌ |
| **Hesap Yönetimi** | Abonelik Yönetimi satırı + Çıkış Yap butonu | Çıkış butonu var ama farklı yapıda | ⚠️ |
| **Mevcut İçerik** | — | Auth/RBAC shell debug paneli: rol selector, plan selector, anonim toggle, email/password input, 6 aksiyon butonu | 🔧 Geliştirici paneli |

**Parity Durumu**: ❌ **EN BÜYÜK FARK — Profil sayfası tamamen farklı**

Mevcut profil sayfası bir **geliştirici/QA debug paneli** olarak tasarlanmış (rol/plan seçiciler, auth akışı test butonları). Figma tasarımı ise son kullanıcıya yönelik **gerçek profil sayfası** gösteriyor.

**Eksik Bileşenler**:
- ❌ Kullanıcı avatar widget'ı
- ❌ PRO abonelik banner kartı (gradient)
- ❌ Tema toggle (Açık/Koyu/Sistem)
- ❌ Dil seçici dropdown
- ❌ Abonelik yönetimi satırı
- ❌ Hesap yönetimi section kartı

**Etkilenecek Dosyalar**: `features/profile/profile_page.dart` (büyük refactor), potansiyel yeni widget'lar `packages/shared_ui/`

---

## Yatay Fark Özeti

| Ekran | Route | Parity | Kritik Fark |
|---|---|---|---|
| Ana Sayfa | `/` | 🟢 %95 | Türkçe karakter / emoji küçük düzeltme |
| Kelimeler | `/words` | 🟢 %95 | Folder icon outline→filled küçük düzeltme |
| Okuma Odası | `/readings` | 🟡 %75 | Gerçek fotoğraf artwork eksik |
| Okuma Detay | `/readings/:id` | 🟡 %80 | Gerçek fotoğraf artwork eksik |
| Gramer | `/grammar` | 🟢 %95 | Türkçe karakter küçük düzeltme |
| **Profil** | `/profile` | 🔴 **%15** | **Tamamen farklı — debug paneli vs son kullanıcı profili** |

---

## Yatay Temalar (Tüm Ekranları Etkileyen)

| Tema | Detay | Etki |
|---|---|---|
| **Font Ailesi** | Figma: Outfit/Inter, Flutter: Roboto (varsayılan) | Tüm ekranlar |
| **Türkçe Karakterler** | ş,ö,ü,ı,ç,ğ eksik pek çok string'de | Tüm ekranlar |
| **Artwork Görselleri** | Gradient placeholder vs gerçek fotoğraf | Readings ekranları |
| **Badge Renk Tokenleri** | `#FF6A3D` ve `#3B82F6` hardcoded, token yok | Home, Words |
| **Dark Mode Eksikliği** | `AppTheme.dark()` sadece `colorScheme` tanımlıyor, text/card/button theme eksik | Tüm ekranlar |
