# Student App — UI Parity Güvenli İmplementasyon Planı

> **Tarih**: 2026-03-08
> **Durum**: PLAN — Henüz kod değişikliği yapılmadı
> **Kapsam**: `apps/student_app` + `packages/shared_ui`
> **Kural**: İş mantığı, repository, auth akışları ve provider yapısı DEĞİŞMEZ

---

## 1. Faz Dosyası Güncellemesi (Ön Koşul)

Aşağıdaki faz dosyaları bu UI parity çalışmasını yansıtacak şekilde güncellenmelidir (implementasyondan ÖNCE):

| Faz Dosyası | Güncellenecek Kısım |
|---|---|
| `docs/phases/phase_07_web_responsive_yayin_hazirligi.md` | UI parity maddeleri + profil redesign maddesi ekle |
| `docs/phases/phase_03_cekirdek_ogrenme_modulleri.md` | Reading artwork asset planı ekle |

---

## 2. İmplementasyon Sırası

### Sprint 0: Yatay Altyapı (Tüm Ekranları Etkiler)
**Risk**: Düşük — Yalnızca stil/tema değişikliği, logic dokunulmaz

| # | İş | Dosya | Etki |
|---|---|---|---|
| 0.1 | Font ailesi ekleme (Outfit veya Inter) | `packages/shared_ui/lib/src/app_theme.dart` | Tüm text'ler |
| 0.2 | `pubspec.yaml`'a `google_fonts` paketi ekleme | `apps/student_app/pubspec.yaml` | Build |
| 0.3 | Badge renk tokenlerini `AppThemeTokens`'a taşı (`badgeOrange`, `accentBlue`) | `packages/shared_ui/lib/src/app_theme_tokens.dart` | Token altyapısı |
| 0.4 | Dark theme'i tam doldur (text, card, button, input theme) | `packages/shared_ui/lib/src/app_theme.dart` | Dark mode |
| 0.5 | Tüm UI string'lerinde Türkçe karakter düzeltmesi (ş,ö,ü,ı,ç,ğ) | `home_page.dart`, `grammar_page.dart`, `readings_page.dart`, `page_parts.dart` | Tüm ekranlar |

### Sprint 1: Okuma Artwork Sistemi
**Risk**: Orta — Asset yönetimi ve medya stratejisi kararı gerekiyor

| # | İş | Dosya | Etki |
|---|---|---|---|
| 1.1 | Okuma artwork stratejisi belirle: (a) lokal asset, (b) network URL, (c) Supabase storage | Mimari karar | — |
| 1.2 | `ReadingSeedData`'ya `artworkUrl` veya `artworkAsset` alanı ekle | `features/readings/reading_seed_data.dart` | Veri modeli |
| 1.3 | `_ReadingArtwork` widget'ını gradient yerine `Image` widget kullanacak şekilde güncelle | `readings_page.dart`, `reading_detail_page.dart` | İki ekran |
| 1.4 | Placeholder/fallback gradient'i koru (image yüklenmezse) | Aynı dosyalar | Hata dayanıklılığı |

### Sprint 2: Profil Sayfası Redesign
**Risk**: Yüksek — En büyük değişiklik. Debug paneli ayrılmalı, son kullanıcı profili yazılmalı.

| # | İş | Dosya | Etki |
|---|---|---|---|
| 2.1 | Mevcut profil sayfasını `_DevAccessPanel` olarak ayır (sadece dev/admin modda göster) | `features/profile/profile_page.dart` | Mevcut işlevsellik korunur |
| 2.2 | Yeni `ProfileHeader` widget'ı: büyük avatar + isim + email | `features/profile/profile_page.dart` | Yeni widget |
| 2.3 | Yeni `ProBanner` widget'ı: koyu gradient kart + CTA butonu | `features/profile/profile_page.dart` veya `packages/shared_ui/` | Yeni widget (reusable olabilir) |
| 2.4 | Yeni `AppSettingsSection` widget'ı: Tema toggle (Açık/Koyu/Sistem) + Dil seçici | `features/profile/profile_page.dart` | Yeni widget |
| 2.5 | Yeni `AccountSection` widget'ı: Abonelik yönetimi + Çıkış yap | `features/profile/profile_page.dart` | Yeni widget |
| 2.6 | Tema toggle işlevselliği için provider (sadece UI state, ana ThemeMode'a bağlantı) | `core/student_providers.dart`'a ekleme | State (sadece UI) |
| 2.7 | Dev panel'i koşullu göster: `accessContext.role == admin` veya `developer` | `features/profile/profile_page.dart` | Koşullu UI |

### Sprint 3: Küçük Polish Düzeltmeleri
**Risk**: Düşük

| # | İş | Dosya | Etki |
|---|---|---|---|
| 3.1 | Pack icon'u `Icons.folder_outlined` → `Icons.folder_rounded` (filled görünüm) | `page_parts.dart` `StudentPackCard` | Kelimeler ekranı |
| 3.2 | Home emoji ekleme: "Hoş Geldin, Ahmet! 👋" | `home_page.dart` | Ana sayfa |
| 3.3 | Hardcoded renkleri token referansına çevir | `home_page.dart`, `page_parts.dart` | Temizlik |

---

## 3. Dokunulmayacak Dosyalar (İş Mantığı)

Aşağıdaki dosyalar bu UI parity çalışmasında **kesinlikle değiştirilmez**:

| Dosya | Neden |
|---|---|
| `core/student_access_controller.dart` | Auth/RBAC iş mantığı |
| `core/student_providers.dart` | Provider yapısı (Sprint 2.6 hariç: sadece UI theme provider eklenir) |
| `bootstrap/` | Uygulama başlatma mantığı |
| `packages/shared_data/` | Repository/veri katmanı |
| `packages/shared_domain/` | Domain modelleri |
| `packages/shared_core/` | Temel tipler/config |
| `app/student_router.dart` | Route yapısı |
| `app/student_app.dart` | MaterialApp yapısı |

---

## 4. Yalnız UI Katmanında Değişecek Dosyalar

| Dosya | Değişiklik Tipi |
|---|---|
| `packages/shared_ui/lib/src/app_theme.dart` | Font ailesi, dark theme completion |
| `packages/shared_ui/lib/src/app_theme_tokens.dart` | Yeni renk tokenleri |
| `features/home/home_page.dart` | Türkçe karakter, emoji |
| `features/words/words_page.dart` | Minimal (icon) |
| `features/readings/readings_page.dart` | Artwork widget güncellemesi |
| `features/readings/reading_detail_page.dart` | Artwork widget güncellemesi |
| `features/readings/reading_seed_data.dart` | Artwork alanı ekleme |
| `features/grammar/grammar_page.dart` | Türkçe karakter |
| `features/profile/profile_page.dart` | Büyük refactor (redesign) |
| `features/common/page_parts.dart` | Icon, hardcoded renk temizliği |

---

## 5. shared_ui Bileşen Revizyon Planı

| Bileşen | Mevcut Durum | Gerekli Revizyon |
|---|---|---|
| `AppTheme` | Light tam, dark minimal | Dark theme'i light ile simetrik yap |
| `AppThemeTokens` | 21 token | +2 token (`badgeOrange`, `accentBlue`) |
| `FoundationShell` | Geliştirici shell | Değiştirme (admin_console kullanıyor) |
| `AccessGate` | Çalışıyor | Değiştirme |
| `StudentSurfaceCard` | Tam | Değiştirme |
| `StudentProgressBar` | Tam | Değiştirme |
| `StudentPackCard` | Icon düzeltme | Minor |

---

## 6. Test ve Build Doğrulama Adımları

Her sprint sonunda:

```bash
# 1. Analiz (lint kontrolü)
cd apps/student_app && flutter analyze

# 2. Build doğrulama (web)
flutter build web --no-tree-shake-icons

# 3. Lokal test
flutter run -d chrome

# 4. Mevcut testler (varsa)
flutter test
```

**Manuel QA kontrol listesi:**
- [ ] Tüm 6 ekran açılıyor mu?
- [ ] Sidebar navigasyonu çalışıyor mu?
- [ ] Bottom nav (mobil) çalışıyor mu?
- [ ] Dark mode toggle çalışıyorsa, tüm ekranlar doğru mu?
- [ ] Responsive breakpoint'lar (960px, 860px, 1080px) doğru mu?
- [ ] Reading card artwork'lar yükleniyor mu?
- [ ] Profil sayfası Figma tasarımıyla eşleşiyor mu?

---

## 7. Riskler

| Risk | Olasılık | Etki | Mitigasyon |
|---|---|---|---|
| Font değişikliği layout shift yaratır | Orta | Orta | Font metrikleri test edilmeli |
| Profil redesign dev panelini kaybettirir | Yüksek | Yüksek | Dev paneli koşullu olarak korunur |
| Artwork asset stratejisi yanlış seçilir | Orta | Orta | Önce lokal asset ile başla, sonra network geçişi |
| Dark mode refactoru beklenenden büyük olur | Düşük | Düşük | Minimal dark token ile başla |
| Türkçe karakter düzeltmesi localization sistemiyle çelişir | Düşük | Düşük | Şimdilik inline, l10n gelince migrate |

---

## 8. Önerilen İmplementasyon Takvimi

| Sprint | Tahmini Süre | Öncelik |
|---|---|---|
| Sprint 0: Yatay Altyapı | 1-2 saat | 🔴 En yüksek |
| Sprint 1: Okuma Artwork | 2-3 saat | 🟡 Orta |
| Sprint 2: Profil Redesign | 3-4 saat | 🟡 Orta |
| Sprint 3: Polish | 0.5-1 saat | 🟢 Düşük |

**Toplam tahmini süre**: 6.5 – 10 saat
