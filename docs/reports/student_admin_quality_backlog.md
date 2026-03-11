# PASSAGETR QA + Public/Auth Navigation Backlog

## Kapsam
Bu backlog üç alanı tek dosyada toplar:

- Student app QA bulguları
- Public/anonim ve giriş yapmış kullanıcı navigasyon ayrımı
- Admin console QA polish maddeleri

## Doğrulama Özeti

| Alan | Bulgu | Durum | Not |
|---|---|---|---|
| Student / Words | `Çalışılan / Tekrar / Toplam` tutarsızlığı | Doğrulandı | Tek summary provider altında birleştirildi |
| Student / Home | `%100` içerikte `Kaldığın Yerden Devam Et` CTA’sı | Doğrulandı | Continue seçimi ve CTA metni düzeltildi |
| Student / Readings | Çeviri fallback’inde gereksiz kaynak paragraf tekrarı | Doğrulandı | Kısa fallback copy kullanılıyor |
| Student / Words | `0` kelimelik paketlerin görünmesi | Doğrulandı | Student listesinde gizleniyor |
| Student / Grammar | Bilinmeyen modüllerin ilk seed açıklamasına düşmesi | Kısmen doğrulandı | Nötr fallback description eklendi |
| Student / Readings | Bilinmeyen okumaların aynı artwork’e düşmesi | Kısmen doğrulandı | Deterministic fallback artwork eklendi |
| Student / Profile | Anonim kullanıcıda sahte isim/e-posta görünmesi | Doğrulandı | `Misafir` ve auth surface ile değiştirildi |
| Student / Shell | Public girişte `Profil` sekmesinin görünmesi | Doğrulandı | Web ve mobilde auth-state tabanlı görünürlük eklendi |
| Admin / Sidebar | Sidebar e-posta taşması | Doğrulandı | `maxLines: 1` ve `ellipsis` eklendi |
| Admin / Audit | Boş audit panelinin açıklamasız görünmesi | Kısmen doğrulandı | Empty ve unavailable state’ler ayrıldı |
| Admin / Users | Pagination var sanılması | Geçersiz | Repo’da pagination yok |

## P0

| ID | İş | Durum | Sonuç |
|---|---|---|---|
| `QA-P0-01` | Student words summary provider | Uygulandı | `StudentWordSummary` ile tek veri snapshot’ı kullanılıyor |
| `QA-P0-02` | Continue reading seçimi ve CTA düzeltmesi | Uygulandı | `StudentContinueReadingSummary` eklendi |
| `QA-P0-03` | Çeviri fallback kopyasını düzelt | Uygulandı | Kısa fallback, kaynak paragraf tekrarı yok |
| `QA-P0-04` | Public/auth navigasyon ayrımı | Uygulandı | Anonimde `Giriş`, kimlikli kullanıcıda `Profil` |
| `QA-P0-05` | `/profile` ekranını iki moda ayır | Uygulandı | Anonymous auth surface, identified profile management |
| `QA-P0-06` | Sahte profil kimliğini kaldır | Uygulandı | `Ahmet Yılmaz` ve fake email kaldırıldı |
| `QA-P0-07` | Admin sidebar ve audit polish | Uygulandı | E-posta ellipsis, audit state copy’leri eklendi |

## P1

| ID | İş | Durum | Sonuç |
|---|---|---|---|
| `QA-P1-01` | Student’ta `0` kelimelik paketleri gizle | Uygulandı | Sadece student listing etkilenir |
| `QA-P1-02` | Grammar description fallback’ini seed-first olmaktan çıkar | Uygulandı | Bilinmeyen modüller nötr açıklama kullanır |
| `QA-P1-03` | Reading artwork fallback’ini deterministic yap | Uygulandı | Bilinmeyen okumalar kategori/level bazlı fallback alır |

## P2

| ID | İş | Durum | Sonuç |
|---|---|---|---|
| `QA-P2-01` | Regression suite’i genişlet | Uygulandı | Student ve admin için yeni widget/unit testler eklendi |
| `QA-P2-02` | Dokümantasyonu senkronize et | Uygulandı | Repo içi backlog bu doğrulama durumlarını taşır |

## Beklenen Davranış

- Anonim kullanıcıda web sidebar ana navigasyonda `Profil` görünmez.
- Web sidebar’ın alt bölümünde `Giriş` alanı görünür.
- Mobil bottom nav’da son sekme anonimken `Giriş`, giriş sonrası `Profil` olur.
- `/profile` route’u korunur.
- Anonim kullanıcı `/profile` altında auth surface görür.
- Giriş yapmış kullanıcı `/profile` altında profil, plan ve hesap yönetimi görür.
- Student words ekranı `wordCount == 0` olan paketleri göstermez.
- Reading detail translation fallback’i kaynak İngilizce paragrafı tekrar yazmaz.
- Admin dashboard ve settings audit panelleri boş veya erişilemez durumda açıklayıcı mesaj gösterir.

## Test Kapsamı

- `studentWordSummaryProvider` tutarlılığı
- continue reading öncelik sırası ve CTA etiketi
- anonymous shell `Giriş` görünürlüğü
- `/profile` anonymous/authenticated ayrımı
- sahte isim/e-posta görünmemesi
- translation fallback copy
- zero-word pack filtresi
- admin sidebar email ellipsis
- admin audit empty state
