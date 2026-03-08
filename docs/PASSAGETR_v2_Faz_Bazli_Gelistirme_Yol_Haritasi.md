# PASSAGETR v2 — Flutter + Supabase Tabanlı Faz Bazlı Geliştirme Yol Haritası

> **Proje:** Flutter ve Supabase tabanlı yeni nesil İngilizce eğitim platformu  
> **Hedef Platformlar:** Android (APK/AAB) + Web  
> **Mimari Karar:** Mobilde **offline-first**, webde **remote-first**  
> **Sürüm:** Taslak v1.0  
> **Tarih:** 8 Mart 2026

---

## 1. Vizyon ve Stratejik Hedefler

PASSAGETR v2’nin amacı, mevcut uygulamanın işlevlerini yalnızca yeniden üretmek değil; onları daha güvenli, daha ölçeklenebilir, daha hızlı yönetilebilir ve çoklu platforma uygun bir ürün mimarisine dönüştürmektir.

Yeni sistemin stratejik hedefleri şunlardır:

1. **Tek ürün, çoklu platform**
   - Flutter ile tek kod tabanından Android ve Web istemcileri üretmek.
   - Ortak domain modeli ve ortak iş kurallarını korurken platforma göre veri erişim stratejisini ayırmak.

2. **Kesintisiz öğrenme deneyimi**
   - Android uygulamasında kullanıcı; internet olmasa bile kelime çalışması, flashcard, okuma ve gramer modüllerini kullanabilmelidir.
   - Kullanıcı ilerlemesi bağlantı geldiğinde güvenli ve deterministik biçimde senkronize edilmelidir.

3. **İçerik operasyonlarını geliştirici bağımlılığından kurtarmak**
   - Admin kullanıcıları; kelime, test, okuma, gramer ve medya içeriklerini doğrudan CMS üzerinden yönetebilmelidir.
   - İçerik üretim süreci “dosya üret → script çalıştır → veritabanına yükle” modelinden, doğrulama ve yayınlama adımları olan bir ürün akışına dönüştürülmelidir.

4. **Yetkilendirmeyi uygulama kodundan veritabanı çekirdeğine taşımak**
   - Developer, Admin, Pro ve Free rollerini yalnızca UI seviyesinde değil, Supabase RLS seviyesinde de korumak.
   - Premium içerik, yönetim ekranları ve kullanıcı verileri için çift katmanlı güvenlik uygulamak.

5. **Web performansını ürün standardına çıkarmak**
   - Web sürümünde mobil için hazırlanmış büyük yerel veritabanı asset’lerini taşımamak.
   - İlk açılış süresini düşürmek, içerikleri lazy-load etmek ve admin modüllerini gerektiğinde yüklemek.

6. **Yaşayan bir platform kurmak**
   - Yeni modül eklenmesini kolaylaştıran katmanlı mimari, migration disiplini, test altyapısı ve CI/CD süreci oluşturmak.
   - iOS ve masaüstü gibi ileride açılabilecek hedef platformlara teknik borç oluşturmadan ilerlemek.

---

## 2. Tasarım ve Ürün İlkeleri

Bu yeniden yazım sürecinde aşağıdaki ilkeler sabit kabul edilmelidir:

### 2.1 Mimari İlkeler

- **Domain-first**: Kod organizasyonu ekranlara göre değil, iş alanlarına göre şekillenmelidir.
- **Repository abstraction**: UI katmanı; Supabase, Drift veya başka veri kaynağını doğrudan bilmemelidir.
- **Offline write safety**: Mobilde kullanıcı etkileşimleri önce yerel olarak işlenmeli, sonra sunucuya gönderilmelidir.
- **Server-authoritative content**: İçerik tablolarında nihai otorite sunucudur.
- **User-owned progress**: Kullanıcı ilerleme verileri kullanıcıya aittir; her sorgu ve güncelleme `auth.uid()` ekseninde korunmalıdır.
- **Incremental sync**: Tüm içeriği yeniden indirmek yerine yalnızca değişen satırlar taşınmalıdır.
- **Soft-delete ve publish akışı**: İçerikler fiziksel silme yerine yayından kaldırma mantığıyla yönetilmelidir.

### 2.2 UX İlkeleri

- Mobilde akışlar tek elle kullanım, hızlı geri dönüş ve düşük bağlantı koşulları düşünülerek tasarlanmalıdır.
- Web tarafında `NavigationRail`, iki/üç kolonlu içerik düzeni ve geniş ekran üretkenliği esas alınmalıdır.
- `docs/ui_tasarim` klasöründeki taslak ekranlar; component breakdown, spacing, responsive davranış ve dark/light tema eşlemesi için ana referans kabul edilmelidir.
- Dark ve light mod; tema değişkenleri, semantic color token’lar ve erişilebilir kontrast oranları ile tasarlanmalıdır.

---

## 3. Mevcut Sistemden Devralınacak Alanlar

Mevcut yapının veri modeli ve ürün kapsamı, v2 için güçlü bir temel sunmaktadır. Yeni mimari aşağıdaki alanları koruyup iyileştirmelidir:

### 3.1 İçerik Alanları

- **Paketler**: `packs`
- **Kelime havuzu**: `words`
- **Okuma parçaları**: `reading_passages`
- **Cümle bazlı okuma verisi**: `reading_passage_sentences`
- **Parça-kelime ilişkisi**: `reading_passage_words`
- **Çeviri cache**: `reading_sentence_translations`
- **Gramer modülleri**: `gramer_modulleri`
- **Gramer sayfaları**: `gramer_sayfalari`
- **Gramer örnekleri**: `gramer_ornekler`
- **Gramer mini testleri**: `gramer_testler`

### 3.2 Kullanıcı Verisi

- **Kelime ilerlemesi**: `user_word_progress`
- **Okuma ilerlemesi**: `user_reading_progress`
- **Yer imleri**: `user_reading_bookmarks`
- **Favoriler**: `user_reading_favorites`

### 3.3 v2’de Eklenecek Yeni Alanlar

Yeni mimari için aşağıdaki tablolar veya genişletmeler önerilir:

- `profiles`
- `user_roles`
- `subscriptions` veya `entitlements`
- `user_test_attempts`
- `user_grammar_progress`
- `user_daily_stats`
- `content_versions`
- `content_change_log`
- `audit_logs`
- `media_assets`

### 3.4 Lokal Veri Katmanı

Mevcut yapıda yer alan:

- `assets/db/app_content.db`
- `assets/db/dictionary_local.sqlite`

yaklaşımı, v2’de mobil için yönetilen Drift şemasına dönüştürülmelidir. Web build’e büyük SQLite asset gömülmemelidir.

---

## 4. Teknoloji Yığını (Tech Stack)

## 4.1 İstemci Katmanı

| Katman | Teknoloji | Gerekçe |
|---|---|---|
| UI | Flutter 3.x | Web + Android tek kod tabanı |
| Dil | Dart 3.x | Modern dil özellikleri, code-gen uyumu |
| State Management | Riverpod 2.x + generator | Test edilebilir, compile-time güvenli |
| Routing | `go_router` | URL tabanlı navigasyon, guard, deep link |
| Form/Validation | `flutter_form_builder` veya sade custom form yapısı | CMS ve auth akışları için |
| HTML Render | `flutter_html` + tablo desteği | Gramer ve zengin içerik gösterimi |
| TTS | `flutter_tts` | Kelime ve okuma seslendirme |
| Charts | `fl_chart` | İlerleme ve analitik ekranları |
| Connectivity | `connectivity_plus` | Sync tetikleme |
| Secure local prefs | `shared_preferences` | Tema, son seçimler, basit ayarlar |

## 4.2 Veri Katmanı

| Katman | Teknoloji | Gerekçe |
|---|---|---|
| Remote backend | Supabase | Auth, Postgres, Storage, Realtime |
| Local mobile DB | Drift + SQLite | Type-safe sorgu, migration, offline veri |
| Network client | `supabase_flutter` + gerektiğinde `dio` | Auth’li istekler ve özel servisler |
| File storage | Supabase Storage | Ses, görsel, kapak ve import dosyaları |

## 4.3 Backend / Platform Katmanı

| Alan | Teknoloji | Gerekçe |
|---|---|---|
| Veritabanı | PostgreSQL (Supabase) | İlişkisel içerik modeli ve RLS |
| Auth | Supabase Auth | Anonim, e-posta/şifre, OAuth genişleyebilirliği |
| Yetkilendirme | RLS + JWT custom claims | DB seviyesinde güvenlik |
| Server-side logic | Supabase Edge Functions | Bulk import, denetim, kontrollü işlemler |
| Realtime | Supabase Realtime | İçerik değişikliği bildirimleri |
| CI/CD | GitHub Actions | Otomatik test, build ve deploy |
| Web hosting | Firebase Hosting veya Supabase hosting benzeri CDN akışı | Hızlı statik dağıtım |
| Gözlemlenebilirlik | Crashlytics/Sentry + Supabase logs | Hata takibi |

---

## 5. Önerilen Mimari

## 5.1 Katmanlı Yapı

```text
presentation/
  widgets/
  pages/
  controllers/

application/
  use_cases/
  dto/
  mappers/

domain/
  entities/
  repositories/
  services/
  value_objects/

data/
  local/
    drift/
    daos/
    sync/
  remote/
    supabase/
    functions/
  repositories/

core/
  config/
  auth/
  rbac/
  theme/
  errors/
  utils/
```

## 5.2 Uygulama Ayrımı

Tek repo, iki ana giriş noktası önerilir:

- `student_app`: Son kullanıcı uygulaması
- `admin_console`: Admin/CMS arayüzü

Bu ayrım tek repo içinde yapılmalı; ortak domain, entity, mapper ve repository sözleşmeleri paylaşılmalıdır. Böylece CMS ihtiyaçları büyüdüğünde ana uygulamayı gereksiz yüklemeden ayrıştırmak mümkün olur.

## 5.3 Platform Modları

| Mod | Davranış |
|---|---|
| `PLATFORM_MODE=mobile` | Drift aktif, hybrid repository, offline-first |
| `PLATFORM_MODE=web` | Remote-first, ağır lokal asset yok |
| `BUILD_ENV=dev/stage/prod` | Ortam konfigürasyonu ayrılır |

## 5.4 Repository Stratejisi

Her içerik alanı için hibrit repository tasarlanmalıdır:

- `PackRepository`
- `WordRepository`
- `ReadingRepository`
- `GrammarRepository`
- `ProgressRepository`
- `AdminContentRepository`

Mobilde örnek davranış:

1. Önce lokal veriyi döndür.
2. Arka planda `syncIfStale()` çalıştır.
3. Yeni veri gelirse provider invalidate et.
4. Kullanıcı yazma işlemleri lokal outbox’a yazılsın.
5. Ağ gelince batch push çalışsın.

Webde örnek davranış:

1. Veriyi Supabase’den çek.
2. Gerekirse memory cache kullan.
3. Admin ekranları deferred import ile sonradan yüklensin.

---

## 6. RBAC ve Güvenlik Tasarımı

## 6.1 Rol Modeli

Sistem rolleri:

- **Developer**
- **Admin**
- **Pro**
- **Free**

Ancak implementasyon düzeyinde iki kavram ayrı tutulmalıdır:

- **Role**: developer/admin/user-level yetki
- **Plan/Entitlement**: free/pro erişim seviyesi

Bu ayrım ileride takım planı, kurumsal plan, öğretmen hesabı gibi genişlemeleri kolaylaştırır.

## 6.2 Yetki Matrisi

| Alan | Free | Pro | Admin | Developer |
|---|---:|---:|---:|---:|
| Public içerik görüntüleme | ✓ | ✓ | ✓ | ✓ |
| Premium içerik görüntüleme | – | ✓ | ✓ | ✓ |
| Flashcard / SRS | Kısıtlı | ✓ | ✓ | ✓ |
| Test merkezi | Temel | Geniş | ✓ | ✓ |
| Okuma / çeviri | Kotalı | Geniş | ✓ | ✓ |
| Analytics | Temel | Gelişmiş | Gelişmiş | Gelişmiş |
| Offline paket indirme | Kısıtlı | ✓ | ✓ | ✓ |
| CMS erişimi | – | – | ✓ | ✓ |
| Kullanıcı rol yönetimi | – | – | Sınırlı | ✓ |
| Sistem ayarları / flag’ler | – | – | – | ✓ |

## 6.3 Güvenlik Kararları

### Zorunlu kurallar

- `SUPABASE_SERVICE_ROLE_KEY` hiçbir istemciye gömülmeyecek.
- İstemci yalnızca publishable/anon key ile çalışacak.
- Tüm `public` şema tablolarında RLS etkin olacak.
- İçerik tablolarında `select` politikaları plan ve yayın durumuna göre yazılacak.
- Kullanıcı tablolarında temel politika: `auth.uid() = user_id`.
- Admin yazma yetkileri, ya admin claim kontrollü RLS ile ya da Edge Function üzerinden verilecek.
- Storage bucket’ları private olacak; medya erişimi rol/plan bazlı korunacak.

## 6.4 Önerilen Yetki Uygulaması

En doğru yaklaşım:

1. `user_roles` ve `entitlements` verisini veritabanında tut.
2. Access token üretimi sırasında `user_role` ve `plan` claim’lerini JWT’ye ekle.
3. RLS politikalarını bu claim’ler üzerinden çalıştır.
4. UI yalnızca görünürlük kontrolü yapsın; nihai güvenlik veritabanısında olsun.

---

## 7. Offline-First ve Senkronizasyon Stratejisi

## 7.1 Temel Karar

- **Android**: offline-first
- **Web**: remote-first

Bu ayrım zorunludur. Web tarafında yerel SQLite asset taşımak ilk yükü büyütür, deploy’u şişirir ve kullanıcı deneyimini bozar.

## 7.2 Senkronize Edilecek Veri Sınıfları

### Sunucu otoriteli veri
- paketler
- kelimeler
- okumalar
- gramer içerikleri
- medya varlıkları

### Kullanıcı otoriteli veri
- word progress
- reading progress
- test sonuçları
- grammar progress
- bookmarks / favorites
- günlük istatistikler

## 7.3 Lokal Şema Ekleri

Mobil Drift veritabanına aşağıdaki teknik tablolar eklenmelidir:

- `sync_meta`
  - `scope`
  - `last_pull_at`
  - `last_server_cursor`
  - `last_content_version`

- `sync_outbox`
  - `event_id`
  - `entity_type`
  - `entity_id`
  - `op`
  - `payload_json`
  - `client_ts`
  - `retry_count`
  - `status`

## 7.4 Push/Pull Akışı

### Pull
- Kullanıcı indirdiği paketlerin içerik delta’larını çeker.
- Kullanıcı verilerinde `updated_at > last_pull_at` filtresiyle fark alınır.
- `content_versions` tablosu invalidation sinyali olarak kullanılır.

### Push
- Flashcard, test, okuma ilerlemesi gibi eylemler outbox’a yazılır.
- Ağ geri geldiğinde batch apply yapılır.
- Sunucuda idempotent RPC veya Edge Function ile işlenir.

## 7.5 Çakışma Çözümü

İçerik tablolarında çatışma yoktur; sunucu otoritelidir.

Kullanıcı verileri için öneri:

- Varsayılan politika: **Last Write Wins**
- Sayaç alanları için opsiyonel merge
- SRS alanlarında sunucu doğrulaması
- Çift cihaz kullanımında `updated_at` ve `event_id` bazlı deterministik çözüm

## 7.6 İçerik Güncelleme Modeli

Her CMS değişikliği sonrası:

1. içerik tablosu güncellenir
2. `updated_at` tetiklenir
3. `content_versions` güncellenir
4. istemci `syncIfStale()` çağrısında delta alır
5. lokal DB batch upsert edilir
6. ilgili provider’lar invalidate edilir

---

## 8. Veritabanı Tasarımı: v2 İçin Hedef Şema

## 8.1 Korunacak Ana Tablolar

- `packs`
- `words`
- `reading_passages`
- `reading_passage_sentences`
- `reading_passage_words`
- `reading_sentence_translations`
- `gramer_modulleri`
- `gramer_sayfalari`
- `gramer_ornekler`
- `gramer_testler`
- `user_word_progress`
- `user_reading_progress`
- `user_reading_bookmarks`
- `user_reading_favorites`

## 8.2 Standardize Edilecek Alanlar

İçerik tablolarında ortak alan standardı önerilir:

- `created_at`
- `updated_at`
- `published_at`
- `is_published`
- `is_pro`
- `deleted_at` (soft delete için opsiyonel)
- `created_by`
- `updated_by`

## 8.3 Yeni Tablolar

### `profiles`
Kullanıcıya ait temel profil bilgileri, avatar, display name, tercih edilen dil, tema, onboarding durumu.

### `user_roles`
`user_id`, `role`, `granted_at`, `granted_by`

### `entitlements`
`user_id`, `plan`, `starts_at`, `expires_at`, `source`

### `user_test_attempts`
Test sonuçlarının saklanması, zorluk analizi ve analytics için gerekli.

### `user_grammar_progress`
Gramer sayfa tamamlama ve son konum takibi için gerekli.

### `user_daily_stats`
streak, günlük hedef, okuma adedi, çalışılan kelime sayısı.

### `content_versions`
tablo bazlı veya scope bazlı içerik sürümü.

### `content_change_log`
ince taneli delta ve audit için.

### `audit_logs`
admin işlemleri için kayıt.

---

## 9. Admin CMS Tasarımı

## 9.1 Amaç

Admin paneli, teknik olmayan içerik yöneticisinin aşağıdaki işlemleri yapmasını sağlamalıdır:

- içerik oluşturma
- içerik düzenleme
- önizleme
- yayınlama / yayından kaldırma
- medya yükleme
- toplu import
- kalite kontrol
- audit inceleme

## 9.2 Modüller

### Admin Dashboard
- içerik sayıları
- son güncellenen kayıtlar
- yayın bekleyen içerikler
- senkron durum göstergesi
- import geçmişi

### Kelime Yönetimi
- EN/TR anlam, POS, örnek cümle, etiket
- paket atama
- toplu CSV import
- duplicate kontrolü

### Okuma Yönetimi
- başlık, seviye, kategori
- cümle bazlı içerik düzenleme
- odak kelime bağlama
- görsel/ses yükleme
- önizleme

### Gramer Yönetimi
- modül sıralama
- sayfa editörü
- örnekler ve mini testler
- HTML/Markdown içerik doğrulama

### Test Yönetimi
- soru türü
- doğru cevap yapısı
- açıklama / ipucu
- free/pro görünürlük

## 9.3 Teknik Kurallar

- CMS route’ları ayrı guard ile korunmalı.
- Admin paneli mümkünse web öncelikli çalışmalı.
- Service role istemciye verilmemeli.
- Bulk import işlemleri Edge Function veya kontrollü server-side katman ile yapılmalı.
- Tüm admin mutasyonları `audit_logs` içine yazılmalı.

---

## 10. Faz Bazlı Geliştirme Yol Haritası

## Faz 0 — Keşif, Kurulum ve Teknik İskelet

### Hedef
Yeni repo yapısını, ortamları ve temel mimari iskeleti kurmak.

### Teknik işler
- Yeni Flutter workspace oluşturma
- `student_app`, `admin_console`, `shared` paket ayrımı
- Riverpod + go_router + Drift + Supabase kurulumları
- `AppConfig` ve environment yönetimi
- `dev / stage / prod` Supabase proje ayrımı
- ilk migration repo standardı
- tema token altyapısı
- responsive shell iskeleti
- dark/light mode temel sistemi

### Çıktılar
- çalışan boş web + android scaffold
- login dışı navigation shell
- CI’da analyze ve test çalışan pipeline

### Kabul kriterleri
- web ve android build açılıyor
- environment dosyaları standart
- temel route yapısı aktif
- tema geçişi çalışıyor

---

## Faz 1 — Auth, Oturum Yönetimi ve RBAC

### Hedef
Anonim başlangıç, kayıtlı hesaba yükseltme, rol/plan modeli ve güvenlik omurgasını kurmak.

### Teknik işler
- Supabase Auth entegrasyonu
- anonim oturum akışı
- e-posta/şifre kayıt ve giriş
- `profiles`, `user_roles`, `entitlements` migration’ları
- yeni kullanıcıya otomatik `free` rolü
- JWT custom claims akışı
- `authGuard`, `adminGuard`, `premiumGate`
- profil ekranında aktif rol ve plan bilgisi
- RLS politika seti

### Çıktılar
- anon → kayıtlı yükseltme
- free/pro/admin görünürlüğü
- admin route koruması

### Kabul kriterleri
- yeni kullanıcı varsayılan `free`
- admin kullanıcı CMS girişine erişiyor
- anonim kullanıcı verisi kaybetmeden hesap yükseltebiliyor

---

## Faz 2 — Offline-First Veri Katmanı

### Hedef
Mobilde lokal veritabanı, senkron motoru ve hibrit repository altyapısını kurmak.

### Teknik işler
- Drift `AppDatabase`
- içerik ve kullanıcı tablolarının lokal karşılıkları
- `sync_meta`, `sync_outbox`
- DAO katmanı
- `HybridRepository<T>`
- `SyncManager`
- delta sync
- outbox flush
- conflict resolver
- connectivity izleme
- web build’den SQLite asset çıkarılması

### Çıktılar
- mobilde lokal veri okunabiliyor
- offline etkileşim kaybolmuyor
- tekrar online olduğunda push/pull gerçekleşiyor

### Kabul kriterleri
- uçak modunda kelime/okuma/gramer içerikleri açılıyor
- offline flashcard sonrası veri sync oluyor
- web build büyük lokal DB asset taşımıyor

---

## Faz 3 — Çekirdek Öğrenme Modülleri

### Hedef
Kelime, flashcard, test ve SRS altyapısını v2 mimarisine taşımak.

### Teknik işler
- `packs` ve `words` repository’leri
- kelime listeleme, arama, filtreleme
- flashcard oturumu
- SM-2 tabanlı SRS alanları
- `user_word_progress` genişletmesi
- test merkezi
- typing / matching / mcq akışı
- `user_test_attempts`
- analytics veri toplama

### Çıktılar
- kullanıcı kelime paketi seçip çalışabiliyor
- sistem zor kelimeleri öncelikli çıkarabiliyor
- test sonuçları kaydediliyor

### Kabul kriterleri
- flashcard ilerlemesi lokal + remote tutarlı
- test sonucu analytics’e düşüyor
- SRS tekrar listesi hesaplanıyor

---

## Faz 4 — Okuma, Çeviri ve Gramer

### Hedef
Okuma ve gramer modüllerini offline-first ve premium gating mantığıyla yeniden inşa etmek.

### Teknik işler
- `reading_passages`, `reading_passage_sentences`, `reading_passage_words`
- inline kelime açılımı ve quick word panel
- cümle bazlı çeviri cache
- yer imi ve favori akışı
- `user_reading_progress`, `user_reading_bookmarks`, `user_reading_favorites`
- gramer modül/sayfa/örnek/test repository’leri
- HTML render sanitation
- gramerde lokal-first + background sync
- TTS hız ve okuma ayarları

### Çıktılar
- reading player v2
- gramer reader
- bookmark/favorite sistemi
- free/pro görünürlük farkı

### Kabul kriterleri
- okuma ekranı çevrimdışı açılıyor
- çeviri cache tekrar istek atmıyor
- gramer modülü lokalde boşsa remote fallback çalışıyor

---

## Faz 5 — Admin CMS ve İçerik Operasyonları

### Hedef
İçerik ekleme, düzenleme ve yayınlama süreçlerini UI üzerinden yönetilebilir hale getirmek.

### Teknik işler
- admin shell
- dashboard ve içerik sayacı
- kelime CRUD
- okuma CRUD
- gramer CRUD
- test CRUD
- medya upload
- bulk import
- validation katmanı
- preview modu
- publish / unpublish
- `content_versions`
- `audit_logs`

### Çıktılar
- Admin kullanıcı script çalıştırmadan içerik yönetebiliyor
- değişiklik mobil istemcilere delta olarak yayılıyor

### Kabul kriterleri
- admin yeni içerik ekleyebiliyor
- yayın sonrası mobile sync tetikleniyor
- audit kayıtları oluşuyor

---

## Faz 6 — Analytics, Streak ve Pro Paketleme

### Hedef
Ürün motivasyon ve gelir modelini destekleyen metrik ve abonelik katmanını tamamlamak.

### Teknik işler
- `user_daily_stats`
- streak servisi
- günlük hedefler
- analytics dashboard
- zorluk analizi
- pro/free limit ve kota yönetimi
- abonelik yenileme/iptal modeli
- ödeme sağlayıcısı entegrasyon hazırlığı

### Çıktılar
- kullanıcı ilerlemesini görselleştirebiliyor
- premium kilit mekanizması stabil
- dashboard ürün hissi kazanıyor

### Kabul kriterleri
- günlük hedef ve streak doğru hesaplanıyor
- premium gate bütün kritik ekranlarda tutarlı
- analytics ekranı veri gösteriyor

---

## Faz 7 — Web, Responsive Shell ve Yayın Hazırlığı

### Hedef
Web deneyimini performanslı ve üretime uygun hale getirmek.

### Teknik işler
- responsive shell
- mobile/tablet/desktop kırılımları
- `NavigationRail`
- max-width container sistemi
- admin ve analytics deferred import
- web smoke test
- hosting pipeline
- asset pruning
- firebase ignore / deploy doğrulaması
- LCP ve bundle boyutu optimizasyonu

### Çıktılar
- web sürümü büyük ekranlarda verimli çalışıyor
- deploy süreci standart hale geliyor

### Kabul kriterleri
- web ilk yük hissi kabul edilebilir
- admin ekranı masaüstünde verimli
- deploy pipeline tekrarlanabilir

---

## Faz 8 — Test, Kalite ve Operasyonel Sertleştirme

### Hedef
Canlıya çıkmadan önce sistemin güvenilirliğini ve bakım kolaylığını garanti altına almak.

### Teknik işler
- unit test
- repository test
- Drift migration test
- RLS smoke test
- widget test
- golden test
- sync senaryosu testleri
- offline/online geçiş testleri
- crash ve log entegrasyonu
- rollback planı
- beta kanal yayını

### Kabul kriterleri
- kritik user journey testleri otomatik
- migration testleri başarısız olduğunda build kırılıyor
- RLS yanlışsa release engelleniyor

---

## Faz 9 — Canlıya Alma ve Son Optimizasyon

### Hedef
Üretim dağıtımı, izleme ve ilk bakım döngüsünü tamamlamak.

### Teknik işler
- production migration freeze
- veri seed ve başlangıç içerik yükü
- internal test
- kademeli rollout
- performans izleme
- support playbook
- ilk 30 gün hata ve metric takibi

### Kabul kriterleri
- Android ve web sürümü canlı
- rollback planı doğrulanmış
- ilk kritik hatalar operasyonel olarak yönetilebiliyor

---

## 11. Riskler ve Azaltma Planı

| Risk | Etki | Azaltma |
|---|---|---|
| Drift migration kırılması | Yüksek | sürüm bazlı migration testleri |
| Yanlış RLS politikası | Çok yüksek | CLI test + code review + stage doğrulama |
| Web bundle şişmesi | Orta | asset pruning + CI size check |
| Offline sync veri çakışması | Yüksek | outbox, event_id, LWW, retry |
| Anonim kullanıcı veri kaybı | Orta | erken upgrade CTA + migration test |
| Admin yanlış içerik yayını | Orta | preview + publish adımı + audit |
| Çeviri servis limiti | Düşük/Orta | cache + fallback + kota |
| CMS kapsamının büyümesi | Orta | ayrı admin_console ve ortak domain katmanı |

---

## 12. İlk Uygulama Sırası Önerisi

Başlangıç için en doğru sıra aşağıdaki gibidir:

1. Faz 0 ve Faz 1 birlikte başlatılsın.
2. Faz 2 tamamlanmadan çekirdek modüller yeniden yazılmasın.
3. Faz 3 ve Faz 4 ürün çekirdeğini tamamlasın.
4. Faz 5 ayrı sprint olarak ele alınsın.
5. Faz 6–9 üretim sertleştirme ve gelir modeli katmanı olarak planlansın.

Bu sıra korunursa ekip; önce mimari omurgayı, sonra veri güvenliğini, sonra ürün modüllerini, en son da operasyonel büyüme araçlarını tamamlamış olur.

---

## 13. Sonuç

PASSAGETR v2, mevcut uygulamanın birebir taşınmış bir kopyası olmamalıdır. Doğru hedef; aynı eğitim alanlarını koruyan fakat:

- daha hızlı,
- daha güvenli,
- yönetilebilir,
- çevrimdışı dayanıklı,
- premium modeli net,
- web ve mobilde tutarlı

bir ürün mimarisine geçmektir.

Bu yol haritası, projeyi “özellik eklenen uygulama” seviyesinden “yaşayan eğitim platformu” seviyesine taşımak için teknik omurgayı tanımlar. Başarı ölçütü yalnızca ekranların çalışması değil; içerik operasyonunun sürdürülebilir, veri güvenliğinin doğrulanabilir ve mobil deneyimin bağlantısız senaryolarda dahi güvenilir olmasıdır.
---

## 14. Controlled Rewrite Ek Kararlar

Bu belge ilk taslak yol haritasını korur; ancak v2'nin fiili uygulama modeli için aşağıdaki kararlar sabittir.

### 14.1 Branch ve arşiv stratejisi

- `main`, v1 arşiv dalıdır.
- Güvenli arşiv etiketi: `v1-archive-2026-03-08`
- Aktif geliştirme dalı: `v2-rewrite-foundation`
- v2 geliştirmesi, v1 kodunun refactor edilmesi değil; yeni foundation üzerinde kontrollü rewrite olarak ilerler.

### 14.2 Reset ve korunacak alanlar

Korunacak ana varlıklar:

- `docs/`
- `docs/ui_tasarim/`
- `DATABASE_SCHEMA.md`
- `supabase/`
- `assets/` altındaki ham içerik ve veritabanı kaynakları
- `scripts/` altındaki import / build / deploy pipeline dosyaları
- `env/*.example`

v1 uygulama implementasyonu ise bilinçli olarak temizlenir ve v2 monorepo foundation yapısı kurulur.

### 14.3 Workspace topolojisi

```text
apps/
  student_app/
  admin_console/
packages/
  shared_core/
  shared_domain/
  shared_data/
  shared_ui/
docs/
  phases/
  ui_tasarim/
  archive/
supabase/
scripts/
assets/
```

### 14.4 Faz bazlı çalışma kuralı

- Her faz için `docs/phases/` altında ayrı bir çalışma dosyası tutulur.
- Faz dosyası oluşturulmadan doğrudan implementasyona geçilmez.
- Faz boyunca kararlar, yapılacak işler, testler ve tamamlananlar aynı dosyada güncellenir.
- Faz sonunda kısa sonuç ve kalan riskler yine aynı dosyada tutulur.
