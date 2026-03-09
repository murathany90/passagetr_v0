# Figma Stil Sözlüğü — PASSAGETR Student App

> **Kaynak**: `docs/ui_tasarim/web/*.png` mockup'ları + Figma file `Adq9rlxsgNczDRwVUY2RU1`
> **Tarih**: 2026-03-08
> **Kapsam**: Yalnızca `apps/student_app` ekranları

---

## 1. Renkler

| Token Adı | Figma'dan Çıkarılan Değer | Mevcut `AppThemeTokens` Karşılığı | Eşleşme |
|---|---|---|---|
| App Background | `#F4F6FA` (açık gri-mavi) | `appBackground: Color(0xFFF4F6FA)` | ✅ Tam |
| Surface (Kart) | `#FFFFFF` | `surface: Colors.white` | ✅ Tam |
| Surface Border | `#E3E8F1` (ince gri kenar) | `surfaceBorder: Color(0xFFE3E8F1)` | ✅ Tam |
| Primary Text | `#18243D` (koyu lacivert) | `primaryText: Color(0xFF18243D)` | ✅ Tam |
| Secondary Text | `#7D8CAA` (grimsi mavi) | `secondaryText: Color(0xFF7D8CAA)` | ✅ Tam |
| Accent / Primary | `#1B2D63` (koyu lacivert) | `accent: Color(0xFF1B2D63)` | ✅ Tam |
| Hero (CTA) | `#FF6A00` (turuncu) | `hero: Color(0xFFFF6A00)` | ✅ Tam |
| Success | `#11C979` (yeşil) | `success: Color(0xFF11C979)` | ✅ Tam |
| Warning / Streak Gradient | `#FF6A00 → #FF720F` | `hero → heroGlow` | ✅ Yakın |
| Pack Blue | `#3B82F6` | Hardcoded `_packAccentColor` | ⚠️ Token yok |
| Pack Purple | `#695CFF` | `tokens.purple` | ✅ Tam |
| Pack Green / Teal | `#14C77F` | `tokens.green` | ✅ Tam |
| Pack Pink | `#FF2A68` | `tokens.pink` | ✅ Tam |
| Sidebar Selected BG | Accent rengi | `tokens.accent` | ✅ Tam |
| Badge Pill (Turuncu) | `#FF6A3D` | Hardcoded `Color(0xFFFF6A3D)` | ⚠️ Token yok |
| Pro Banner BG | Koyu lacivert gradient | Mevcut kodda yok | ❌ Eksik |

---

## 2. Tipografi

| Rol | Figma (tahmini) | Mevcut `TextTheme` Karşılığı | Eşleşme |
|---|---|---|---|
| Page Title | ~30px, w800 | `headlineMedium: 30/w800` | ✅ Tam |
| Card Title | ~22px, w800 | `headlineSmall: 22/w800` | ✅ Tam |
| Section Title | ~18px, w800 | `titleLarge: 18/w800` | ✅ Tam |
| Subtitle / Nav Label | ~15px, w700 | `titleMedium: 15/w700` | ✅ Tam |
| Body | ~16px, w500 | `bodyLarge: 16/w500` | ✅ Tam |
| Caption / Badge | ~12px, w600 | `bodySmall: 12/w600` | ✅ Tam |
| Sidebar Nav Label | ~13px, w700 | Inline `TextStyle(13/w700)` | ⚠️ Inline, token değil |
| Font Ailesi | Outfit / Inter (Figma) | Flutter default (Roboto) | ❌ Uyuşmuyor |

> **Kritik Fark**: Figma'da **Outfit** veya **Inter** font ailesi kullanılıyor. Mevcut Flutter kodu herhangi bir özel font tanımlamıyor (varsayılan Material 3 fontunu kullanıyor).

---

## 3. Spacing

| Kullanım | Figma (px tahmini) | Mevcut Kod | Eşleşme |
|---|---|---|---|
| Sayfa padding (desktop) | 36px horizontal | `EdgeInsets.fromLTRB(36, 24, 36, 36)` | ✅ Tam |
| Sayfa padding (mobil) | 20px horizontal | `EdgeInsets.fromLTRB(20, 24, 20, 112)` | ✅ Tam |
| Kart arası boşluk | 18–20px | `SizedBox(height: 18–20)` | ✅ Tam |
| Kart iç padding | 20px | `EdgeInsets.all(20)` | ✅ Tam |
| Content max width | ~1120px | `contentMaxWidth: 1120` | ✅ Tam |
| Sidebar genişliği | ~92px | `railWidth: 92` | ✅ Tam |

---

## 4. Border Radius

| Element | Figma (px tahmini) | Mevcut Kod | Eşleşme |
|---|---|---|---|
| Kart | 24px | `cardRadius: 24` | ✅ Tam |
| Pill / Button | 22px | `pillRadius: 22` | ✅ Tam |
| Badge pill | 999px (tam yuvarlak) | `BorderRadius.circular(999)` | ✅ Tam |
| Sidebar button | 18px | `BorderRadius.circular(18)` | ✅ Tam |
| Search input | 16px | `cardRadius - 8 = 16` | ✅ Tam |

---

## 5. Shadows

| Element | Figma | Mevcut Kod | Eşleşme |
|---|---|---|---|
| Surface kart | Hafif drop shadow | `BoxShadow(blur: 20, offset: 0,6, color: surfaceShadow)` | ✅ Yakın |
| Bottom nav | Hafif yukarı shadow | `BoxShadow(blur: 18, offset: 0,-4)` | ✅ Yakın |

---

## 6. Navigation Yapısı

### Figma Sidebar (Desktop ≥ 960px)

| Sıra | İkon | Label | Badge |
|---|---|---|---|
| 1 | Home outline | Ana Sayfa | — |
| 2 | Dashboard outline | Kelimeler | 12 |
| 3 | Book outline | Okuma | — |
| 4 | Style outline | Gramer | — |
| 5 | Person outline | Profil | — |
| 6 | Admin panel | Admin | — (koşullu) |

→ **Mevcut kodla tam eşleşiyor** ✅

### Figma Bottom Nav (Mobil < 960px)

Aynı 5 item (Admin hariç) → **Eşleşiyor** ✅

---

## 7. Kart, Liste ve Detail Layout Kalıpları

### Home Ekranı Layout (Desktop)
```
Row [
  Expanded( StreakHeroCard ),
  SizedBox(w:20),
  Expanded( ContinueReadingCard ),
]
Row [
  SizedBox(w:282, ReviewCard),
  SizedBox(w:20),
  Expanded(WeeklyProgressCard),
]
```
→ **Figma ile eşleşiyor** ✅

### Kelimeler Layout
```
Column [
  SearchField,
  SectionTitle("Kelime Paketleri"),
  Wrap(
    columns: responsive(1/2/3),
    children: [ PackCard × N ],
  )
]
```
→ **Figma ile eşleşiyor** ✅

### Okuma Listesi Layout
```
Column [
  SegmentedButton(Okuma Listem / Keşfet),
  Wrap(
    columns: responsive(1/2/3),
    children: [ ReadingCard × N ],
  )
]
```
→ **Figma ile eşleşiyor** ✅ (kart içi artwork farklılığı hariç)

### Okuma Detay Layout (Desktop)
```
Row [
  SizedBox(w:252, InfoPanel),
  SizedBox(w:20),
  Expanded(ArticlePanel),
  SizedBox(w:20),
  SizedBox(w:286, FocusWordsPanel),
]
```
→ **Figma ile eşleşiyor** ✅

---

## 8. Auto Layout → Flutter Widget Eşleştirmesi

| Figma Auto Layout | Flutter Widget | Kullanıldığı Yer |
|---|---|---|
| Horizontal, fill | `Row` + `Expanded` | Home hero/continue row |
| Vertical, fill | `Column` + `CrossAxisAlignment.start` | Tüm page body'ler |
| Wrap, responsive | `Wrap` + `LayoutBuilder` | PackCard grid, ReadingCard grid |
| Stack, absolute | `Stack` + `Positioned` | Streak glow icon, badge pill, grammar module number |
| Responsive breakpoint | `LayoutBuilder` → `isWide` | 860 (home), 960 (shell), 1080 (detail) |

---

## 9. Figma vs `docs/ui_tasarim` Çelişki Raporu

> Figma REST API'ye doğrudan erişim 403 döndüğü için analiz `docs/ui_tasarim/web/*.png` mockup'larıyla yapılmıştır. Bu dosyaların Figma'dan dışa aktarılmış olduğu varsayılmıştır. Herhangi bir güncellik çelişkisi doğrulanamadı. Kullanıcının Figma dosyasını güncellemesi halinde bu sözlük yeniden oluşturulmalıdır.
