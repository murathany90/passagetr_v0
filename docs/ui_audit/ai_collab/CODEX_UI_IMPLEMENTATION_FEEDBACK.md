# CODEX UI IMPLEMENTATION FEEDBACK

> **Yazar**: Gemini Code Assist — UI Reviewer & Sistem Mimarı
> **Tarih**: 2026-03-08
> **Hedef**: Codex'in `apps/student_app` UI parity çalışmasını güvenli ve sistematik şekilde yürütmesi için teknik geri bildirim
> **Kural**: Bu dosya yalnızca geri bildirimdir. KOD DEĞİŞİKLİĞİ İÇERMEZ.

---

## 1. Özet

Mevcut `apps/student_app`, Figma tasarımıyla büyük ölçüde yapısal uyum içindedir. Route yapısı, sidebar/bottom nav navigasyonu, responsive breakpoint stratejisi ve kart/layout hiyerarşisi doğrudur. Ancak 10 kritik parity açığı tespit edilmiştir. Bunların 6'sı düşük riskli stil düzeltmesi, 2'si orta riskli artwork/asset değişikliği, 2'si yüksek riskli yapısal değişikliktir (profil redesign + dark mode tamamlama).

Codex'in öncelikle yatay altyapı tokenlerini düzeltmesi, ardından profil sayfası redesign'ını yapması, en son artwork asset stratejisini uygulaması önerilir.

---

## 2. En Kritik 10 Parity Farkı

| # | Kritiklik | Ekran | Fark | Mevcut Dosya | Risk |
|---|---|---|---|---|---|
| **1** | 🔴 Kritik | `/profile` | Profil sayfası tamamen farklı — mevcut: auth debug paneli, Figma: son kullanıcı profili (avatar, PRO banner, ayarlar) | `profile_page.dart` | Yüksek |
| **2** | 🔴 Kritik | Tümü | Font ailesi eksik — Figma: Outfit/Inter, Flutter: varsayılan Roboto | `app_theme.dart` | Orta |
| **3** | 🟠 Yüksek | Tümü | Dark mode tema eksik — sadece `colorScheme` tanımlı, text/card/button/input theme yok | `app_theme.dart` | Orta |
| **4** | 🟠 Yüksek | `/readings`, `/readings/:id` | Okuma kartlarında gradient placeholder var, Figma'da gerçek fotoğraf artwork | `readings_page.dart`, `reading_detail_page.dart`, `reading_seed_data.dart` | Orta |
| **5** | 🟡 Orta | Tümü | Tüm UI string'lerinde Türkçe karakter eksik (ş,ö,ü,ı,ç,ğ) | Home, grammar, readings, page_parts | Düşük |
| **6** | 🟡 Orta | Tümü | Hardcoded badge renkleri token'a taşınmalı (`#FF6A3D`, `#3B82F6`) | `home_page.dart`, `page_parts.dart` | Düşük |
| **7** | 🟡 Orta | `/` | Home sayfasında emoji eksik ("Hoş Geldin, Ahmet! 👋") | `home_page.dart` | Düşük |
| **8** | 🟢 Düşük | `/words` | Pack ikonu outline, Figma'da filled/rounded | `page_parts.dart` `StudentPackCard` | Düşük |
| **9** | 🟢 Düşük | `/grammar` | Module card background number zaten var ama font boyutu Figma ile kıyaslanmalı | `grammar_page.dart` | Düşük |
| **10** | 🟢 Düşük | Sidebar | Sidebar nav label inline `TextStyle`, token referansına çevrilmeli | `page_parts.dart` `_SidebarButton` | Düşük |

---

## 3. Dosya Bazlı Müdahale Planı

### 3.1 `packages/shared_ui/lib/src/app_theme.dart`

**Uygulanacak:**
- `google_fonts` paketi ile Outfit (veya Inter) font ailesini `textTheme`'e entegre et
- `dark()` metodunu `light()` ile simetrik hale getir: tüm `textTheme`, `appBarTheme`, `cardTheme`, `chipTheme`, `inputDecorationTheme`, `filledButtonTheme`, `outlinedButtonTheme` tanımlarını ekle
- Dark token renklerini mevcut `AppThemeTokens` dark değerleriyle bağla

**Dokunulmayacak:**
- `light()` metodundaki mevcut renk, radius ve spacing değerleri (Figma ile eşleşiyor)
- `colorScheme` yapısı

**Riskli:**
- Font değişikliği layout shift yaratabilir. Codex font uyguladıktan sonra **tüm 6 ekranı** web build'de test etmeli
- Dark mode token'ları eksik widget theme'lere bağlanırken `tokens` nesnesinin `const` olması nedeniyle `copyWith` kullanılmalı

### 3.2 `packages/shared_ui/lib/src/app_theme_tokens.dart`

**Uygulanacak:**
- Yeni renk token'ları ekle: `badgeOrange` (Color(0xFFFF6A3D)), `accentBlue` (Color(0xFF3B82F6))
- `copyWith` ve `lerp` metodlarını yeni alanlarla güncelle

**Dokunulmayacak:**
- Mevcut 21 token (hepsi Figma ile eşleşiyor)

**Riskli:**
- `copyWith` veya `lerp`'e yeni alan eklemeyi unutmak compile error vermez ama runtime'da interpolasyon bozulur

### 3.3 `packages/shared_ui/lib/shared_ui.dart`

**Uygulanacak:** Yeni widget export'ları (ProBanner vb. eklenirse)
**Dokunulmayacak:** Mevcut export'lar
**Riskli:** Yok

### 3.4 `apps/student_app/lib/src/features/profile/profile_page.dart`

**Uygulanacak:**
- Mevcut auth debug panelini `_DevAccessPanel` private widget'ına taşı
- Figma'daki son kullanıcı profil sayfasını oluştur:
  - `_ProfileHeader`: Büyük dairesel avatar + turuncu ring + ayar dişlisi + isim + email
  - `_ProBanner`: Koyu lacivert gradient kart + "PASSAGETR PRO" + "Hemen Yükselt" CTA
  - `_AppSettingsSection`: "UYGULAMA AYARLARI" başlıklı kart — Tema toggle (Açık/Koyu/Sistem), Dil seçici (Türkçe dropdown)
  - `_AccountSection`: "HESAP YÖNETİMİ" başlıklı kart — Abonelik Yönetimi satırı, Çıkış Yap butonu
- Dev paneli koşullu göster: `accessContext.role == AppRole.admin || accessContext.role == AppRole.developer`

**Dokunulmayacak:**
- `_RoleSelector` ve `_PlanSelector` widget'ları (dev panelin parçası olarak kalacak)
- Auth butonlarının iş mantığı (signIn, signUp vb.)

**Riskli:**
- ⚠️ **En yüksek risk**: Mevcut profil sayfası auth test aracı olarak aktif kullanılıyor. Dev paneli kaldırılırsa auth akışını test etmek zorlaşır. **Çözüm**: Dev panelini `Column` sonuna koşullu olarak ekle, silme.
- Tema toggle için yeni bir `ThemeMode` provider gerekecek. Bu `student_providers.dart`'a eklenmeli ama **yalnızca UI state** olmalı, auth/data akışına müdahale etmemeli.

### 3.5 `apps/student_app/lib/src/features/home/home_page.dart`

**Uygulanacak:**
- Tüm string'lerde Türkçe karakter düzeltmesi: `'Hos Geldin'` → `'Hoş Geldin'`, `'Bugun'` → `'Bugün'`, `'ogrenmeye'` → `'öğrenmeye'` vb.
- Başlığa emoji ekle: `'Hoş Geldin, Ahmet! 👋'`
- `_ReviewCard` içindeki `Color(0xFFFFECE9)` ve `Color(0xFFFF6A3D)` → `tokens.badgeOrange` referansına çevir
- `_WeekLabel` listesinde `'Car'` → `'Çar'`

**Dokunulmayacak:**
- `StudentHomePage.build()` içindeki provider watch'ları
- `_selectContinueReading` iş mantığı
- Layout yapısı ve breakpoint (860px) — Figma ile eşleşiyor

**Riskli:**
- Türkçe karakter düzeltmesi yapılırken string'lerin başka dosyalarda da geçip geçmediği kontrol edilmeli (navigation label'ları `page_parts.dart`'ta ayrı tanımlı)

### 3.6 `apps/student_app/lib/src/features/words/words_page.dart`

**Uygulanacak:**
- `_packAccentColor` içindeki `Color(0xFF3B82F6)` → `tokens.accentBlue` referansı

**Dokunulmayacak:**
- Search/filter mantığı, provider bağlantıları, responsive grid breakpoint'ları
- `StudentWordsPage` yapısı Figma ile tam eşleşiyor

**Riskli:** Yok (minimal değişiklik)

### 3.7 `apps/student_app/lib/src/features/readings/readings_page.dart`

**Uygulanacak:**
- `_ReadingArtwork` widget'ını gerçek görsel desteği ile güncelle:
  - `ReadingSeedData`'ya `imageAsset` veya `imageUrl` alanı eklenince, `Image.asset()` veya `Image.network()` kullanılacak
  - Mevcut gradient'i `errorBuilder` / `loadingBuilder` fallback'i olarak koru
- String'lerde Türkçe karakter düzeltmesi

**Dokunulmayacak:**
- `_visibleReadings` filtreleme mantığı
- `ReadingCollectionView` enum ve toggle yapısı
- Responsive breakpoint'lar (1100/720/880)

**Riskli:**
- Asset stratejisi (lokal vs network) belirlenene kadar artwork değişikliğine başlanmamalı
- `_ReadingCard` içindeki `minHeight: 520` image yüksekliğiyle uyumlu kalmalı

### 3.8 `apps/student_app/lib/src/features/readings/reading_detail_page.dart`

**Uygulanacak:**
- Aynı `_ReadingArtwork` güncellemesi (readings_page ile paylaşılan sorun)
- String Türkçe karakter düzeltmesi

**Dokunulmayacak:**
- 3-panel layout yapısı (sol info, orta article, sağ focus words) — Figma ile tam eşleşiyor
- `_buildHighlightedSpans` highlight mantığı
- Bookmark/share/menu aksiyonları
- Focus mode toggle mantığı

**Riskli:** Yok (artwork hariç)

### 3.9 `apps/student_app/lib/src/features/readings/reading_seed_data.dart`

**Uygulanacak:**
- Her `ReadingSeedData`'ya `imageAsset` (String?) alanı ekle
- Lokal asset stratejisinde `assets/images/readings/` altına placeholder fotoğraflar

**Dokunulmayacak:**
- Mevcut tüm seed verileri (textler, renkler, ikonlar)
- `readingSeedFor()` fonksiyonu

**Riskli:**
- Yeni alan eklenince tüm `const` constructor'lar güncellenmeli (3 adet ReadingSeedData kaydı)

### 3.10 `apps/student_app/lib/src/features/grammar/grammar_page.dart`

**Uygulanacak:**
- String Türkçe karakter düzeltmesi: `'Modulleri'` → `'Modülleri'`, `'ogrenme'` → `'öğrenme'` vb.

**Dokunulmayacak:**
- `_GrammarModuleCard` yapısı — Figma ile tam eşleşiyor
- `_handleTap` bottom sheet mantığı
- `GrammarModuleState` locked/premium gate mantığı

**Riskli:** Yok (minimal değişiklik)

### 3.11 `apps/student_app/lib/src/features/common/page_parts.dart`

**Uygulanacak:**
- `StudentPackCard` içinde `Icons.folder_outlined` → `Icons.folder_rounded`
- `_BadgePill` içindeki `Color(0xFFFF6A3D)` → `tokens.badgeOrange` referansı
- `_SidebarButton` ve `_StudentBottomNavigationBar` label'larında Türkçe karakter düzeltmesi
- Sidebar nav label `TextStyle` inline tanımını `theme.textTheme` referansına çevir (opsiyonel)

**Dokunulmayacak:**
- `StudentShellFrame` ve `StudentDetailFrame` layout yapısı — Figma ile tam eşleşiyor
- `StudentSurfaceCard` — tam eşleşiyor
- `StudentProgressBar` — tam eşleşiyor
- `_navigate()` fonksiyonu — route mantığı
- `_sidebarDestinations` ve `_bottomDestinations` — öğe listesi ve sırası Figma ile eşleşiyor

**Riskli:**
- `_BadgePill` renk değişikliği yapılırken `tokens` context'inin mevcut olduğundan emin olunmalı (widget zaten `BuildContext` alıyor ama `const` constructor bozulacak)

---

## 4. Dokunulmayacak Logic Alanları

| Dosya / Path | Neden |
|---|---|
| `core/student_access_controller.dart` | Auth state machine — 7 aksiyon (signIn, signUp, upgrade, signOut, restoreSession, refreshSession, set*) |
| `core/student_providers.dart` | 27 provider tanımı — tüm data binding ve repository wiring |
| `app/student_router.dart` | 8 route tanımı — `/`, `/words`, `/readings`, `/readings/:readingId`, `/grammar`, `/profile`, `/premium`, `/admin` |
| `app/student_app.dart` | `MaterialApp.router` yapısı, theme bağlama |
| `bootstrap/` | Uygulama başlatma zinciri |
| `packages/shared_core/` | `AccessContext`, `AppRole`, `EntitlementPlan`, `AppConfig`, `WorkspaceInfo` — domain tipleri |
| `packages/shared_domain/` | `ReadingPassage`, `ContentPack`, `GrammarModule`, `WordEntry` — domain modelleri ve repository arayüzleri |
| `packages/shared_data/` | `FoundationAuthRepository`, `FoundationPackRepository` vb. — data layer implementasyonları |
| `grammar_seed_data.dart` | Seed verisi — UI parity seed data'yı değiştirmez |
| `reading_seed_data.dart` | Seed verisi yapısı (yeni alan ekleme HARİÇ) |

> **Kritik Kural**: `studentAccessProvider`, `studentPacksProvider`, `studentReadingsProvider`, `studentGrammarModulesProvider` gibi provider tanımları ve bunların bağlı olduğu repository'ler **kesinlikle** değiştirilmez. Provider'a yalnızca **yeni, bağımsız UI state** provider'ları eklenebilir (örn: `themeModeProvider`).

---

## 5. Regression Riskleri

| Risk | Etki Alanı | Olasılık | Mitigasyon |
|---|---|---|---|
| Font değişikliği layout shift yaratır | Tüm ekranlar | Orta | Font uygulandıktan sonra tüm 6 ekranı 3 breakpoint'ta (mobil, tablet, desktop) test et |
| Dark mode token'ları hatalı bağlanır | Dark mode | Orta | `AppTheme.dark()` içinde `tokens` nesnesinin tüm alanlarını doğrula, renk kontrastı kontrol et |
| Profil redesign'ı dev paneli kaybettirir | Auth test akışı | Yüksek | Dev panelini koşullu tut, **silme** |
| Profil ThemeMode provider'ı mevcut state'i bozar | App geneli | Düşük | Provider'ı `student_providers.dart`'ta izole tanımla, `AccessContext`'e dokunma |
| `AppThemeTokens`'a yeni alan eklenince `const` constructor'lar kırılır | Compile time | Düşük | Tüm `AppThemeTokens(...)` çağrılarını güncelle (light + dark) |
| `_BadgePill`'den `const` constructor kaldırılır | Performance | Çok düşük | `const` yerine final kullan, widget tree cache kaybı ihmal edilebilir |
| Reading artwork image yüklenemezse boş alan kalır | Readings ekranı | Orta | Mevcut gradient'i fallback olarak koru: `errorBuilder` ile gradient göster |
| `StudentPackCard` icon değişikliği görsel regression | Kelimeler ekranı | Çok düşük | Sadece icon name değişikliği, test et |
| Türkçe karakter düzeltmesi sırasında yanlış string kesilir | Tüm ekranlar | Düşük | Her string'i bağlamında doğrula, kopyala-yapıştır hatası yapma |

---

## 6. Codex İçin Önerilen Uygulama Sırası

### Aşama 1: Yatay Altyapı (Tüm ekranları etkiler — önce yapılmalı)

```
Sıra 1.1: packages/shared_ui/lib/src/app_theme_tokens.dart
  → badgeOrange + accentBlue token ekle
  → copyWith + lerp güncelle

Sıra 1.2: packages/shared_ui/lib/src/app_theme.dart
  → google_fonts ile Outfit font ailesini entegre et
  → dark() metodunu light() ile simetrik yap

Sıra 1.3: apps/student_app/pubspec.yaml
  → google_fonts dependency ekle

Sıra 1.4: DOĞRULAMA
  → flutter analyze
  → flutter build web --no-tree-shake-icons
  → 6 ekranı tarayıcıda aç, font ve renk doğrula
```

### Aşama 2: Türkçe Karakter + Küçük Düzeltmeler (Düşük risk, hızlı tamamlanır)

```
Sıra 2.1: apps/student_app/lib/src/features/home/home_page.dart
  → Türkçe karakter + emoji + hardcoded renk → token

Sıra 2.2: apps/student_app/lib/src/features/grammar/grammar_page.dart
  → Türkçe karakter

Sıra 2.3: apps/student_app/lib/src/features/readings/readings_page.dart
  → Türkçe karakter

Sıra 2.4: apps/student_app/lib/src/features/readings/reading_detail_page.dart
  → Türkçe karakter

Sıra 2.5: apps/student_app/lib/src/features/common/page_parts.dart
  → Türkçe karakter + icon + badge renk token

Sıra 2.6: DOĞRULAMA
  → flutter analyze
  → Tüm ekranlarda string'leri gözle doğrula
```

### Aşama 3: Profil Sayfası Redesign (En büyük değişiklik — dikkatli ilerle)

```
Sıra 3.1: apps/student_app/lib/src/features/profile/profile_page.dart
  → Mevcut build() body'sini _DevAccessPanel'e taşı
  → Yeni profil UI'ı oluştur: avatar, PRO banner, ayarlar, hesap yönetimi
  → Dev paneli koşullu ekle (alt kısma)

Sıra 3.2: apps/student_app/lib/src/core/student_providers.dart
  → themeModeProvider ekle (StateProvider<ThemeMode>)
  → DİKKAT: Mevcut provider'lara DOKUNMA

Sıra 3.3: apps/student_app/lib/src/app/student_app.dart
  → themeMode'u themeModeProvider'dan oku (opsiyonel, ThemeMode.system default)

Sıra 3.4: DOĞRULAMA
  → flutter analyze
  → Profil sayfasını Figma ile karşılaştır
  → Dev panelinin admin rolünde göründüğünü doğrula
  → Auth butonlarının hala çalıştığını doğrula
```

### Aşama 4: Okuma Artwork Sistemi (Asset stratejisi kararı gerektirir)

```
Sıra 4.1: Artwork stratejisini belirle
  → Önerilen: Lokal asset (assets/images/readings/) ile başla
  → İleride Supabase storage'a geçiş planla

Sıra 4.2: apps/student_app/lib/src/features/readings/reading_seed_data.dart
  → ReadingSeedData'ya imageAsset alanı ekle
  → 3 seed kaydını güncelle

Sıra 4.3: readings_page.dart + reading_detail_page.dart
  → _ReadingArtwork widget'ını Image.asset desteğiyle güncelle
  → Gradient fallback koru

Sıra 4.4: DOĞRULAMA
  → flutter analyze
  → Okuma liste ve detay ekranlarında artwork görünürlüğü
  → Image yüklenemezse gradient fallback çalışıyor mu
```

---

## 7. Faz Geçiş Öneri Notları

### Faz 3 → Faz 3.5 (Ara Faz: UI Parity Polish)

Faz 3 kapsamında home + words parity'si tamamlanmış, flashcard/test henüz açılmamış. Codex'in **Aşama 1 + Aşama 2**'yi Faz 3.5 olarak uygulaması önerilir.

**`docs/phases/phase_03_cekirdek_ogrenme_modulleri.md`'ye eklenecek maddeler:**
```
- [ ] Font ailesi (Outfit) entegrasyonu
- [ ] Dark mode tema tamamlama
- [ ] Yeni renk token'ları (badgeOrange, accentBlue)
- [ ] Türkçe karakter düzeltmesi (home, words, grammar, readings, page_parts)
- [ ] Hardcoded renk referanslarını token'a taşı
```

### Faz 4 → Faz 4.5 (Ara Faz: Readings Artwork + Profil)

Faz 4 kapsamında readings + grammar parity'si tamamlanmış, translation cache henüz bağlanmamış. Codex'in **Aşama 3 + Aşama 4**'ü Faz 4.5 olarak uygulaması önerilir.

**`docs/phases/phase_04_okuma_ceviri_gramer.md`'ye eklenecek maddeler:**
```
- [ ] Okuma artwork: gradient placeholder → gerçek görsel
- [ ] Reading seed data imageAsset alanı
- [ ] Profil sayfası redesign (son kullanıcı görünümü)
- [ ] Dev paneli koşullu koruma
- [ ] ThemeMode provider + tema toggle
```

### Faz 7 Notu

`phase_07_web_responsive_yayin_hazirligi.md` dosyasına herhangi bir güncelleme **bu aşamada gerekmez**. Responsive shell zaten çalışıyor. Faz 7, web-specific optimizasyonlar (lazy loading, asset eliminasyonu) içindir ve UI parity ile doğrudan ilişkili değildir.

---

## Teknik Geri Bildirim Detayı

### Shell ve Navigation
- ✅ Sidebar/bottom nav geçişi 960px breakpoint'ta doğru çalışıyor
- ✅ Nav item'ları ve sırası Figma ile eşleşiyor
- ✅ Badge pill (12 Kelime) doğru konumda
- ⚠️ Sidebar nav label `TextStyle` inline tanımlı, `theme.textTheme.bodySmall` referansına çevrilmeli
- ⚠️ Sidebar logo "PT" kutusu Figma ile uyumlu (44×44, radius:14, accent renk)
- ⚠️ Admin nav item'ı koşullu (canAccessAdmin) — bu korunmalı

### Typography ve Spacing
- ✅ 8 seviyeli text hiyerarşisi Figma ile uyumlu (46/30/22/18/15/16/14/12)
- ✅ Font weight dağılımı doğru (w800 başlıklar, w700 alt başlıklar, w500/w600 body)
- ❌ Font ailesi: Figma'da Outfit, Flutter'da Roboto varsayılan
- ✅ Spacing tokenları: sayfa padding (36/20), kart arası (18-20), kart iç (20) doğru
- ✅ `contentMaxWidth: 1120`, `railWidth: 92` doğru

### Renk/Token Uyumsuzlukları
- ✅ Ana 16 renk tokeni Figma ile eşleşiyor
- ❌ `#FF6A3D` (badge turuncu) ve `#3B82F6` (pack mavi) hardcoded — token'a taşınmalı
- ✅ `hero`, `heroGlow`, `accent`, `accentSoft`, `success`, `warning`, `purple`, `pink`, `green` tokenları doğru
- ⚠️ Dark mode'da sadece `colorScheme` var, diğer theme bileşenleri light'tan inherit ediliyor

### Kart/List/Detail Component Farkları
- ✅ `StudentSurfaceCard`: shadow, border, radius Figma ile eşleşiyor
- ✅ `StudentPackCard`: layout yapısı Figma ile eşleşiyor (icon + word count + title + progress)
- ⚠️ Pack icon: Figma'da filled, kodda outlined
- ✅ Reading card: artwork + badge overlay + başlık + özet + progress state yapısı doğru
- ❌ Reading artwork: gradient vs gerçek fotoğraf
- ✅ Grammar module card: icon circle + başlık + sayfa badge + açıklama + progress doğru
- ✅ Detail page 3-panel layout doğru (252 + flex + 286)

### Responsive Davranış
- ✅ `StudentShellFrame`: 960px sidebar/bottom nav geçişi doğru
- ✅ Home: 860px tek/çift kolon geçişi doğru
- ✅ Words: 980/620 — 3/2/1 kolon doğru
- ✅ Readings: 1100/720 — 3/2/1 kolon doğru
- ✅ Reading detail: 1080px — 3-panel/tek kolon geçişi doğru
- ✅ Mobil padding (20px) vs desktop padding (36px) doğru
