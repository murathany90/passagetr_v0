# PASSAGETR v2 Admin AI Reading Assistant Prompt

Bu prompt, bu repo içinde çalışan bir kod ajanına verilecektir.

Amacın, `apps/admin_console` içine AI destekli okuma üretici eklemektir.
Bu repo greenfield değildir. Repo gerçeği ile çelişen varsayım yapma.

Öncelik sırası:

1. Mevcut repo yapısını ve sözleşmelerini oku.
2. Faz dokümanını oluştur veya güncelle.
3. Kararları repo gerçeklerine göre sabitle.
4. Sonra implementasyona geç.

Bu prompttaki herhangi bir madde repo ile çelişirse repo gerçeğini esas al ve farkı final notunda açıkça belirt.

---

## 1. Çalışma Çerçevesi

- Hedef uygulama: `apps/admin_console`
- Hedef özellik: admin paneline AI destekli okuma üretim ekranı eklemek
- İlk sürüm kapsamı: yalnızca `reading-first`
- Öğrenci uygulamasında yeni UI yüzeyi açma
- Flutter dışı frontend stack önerme
- Supabase ana backend olarak kalacak
- `service_role` istemciye taşınmayacak
- Türkçe metin içeren tüm yeni veya güncellenen dosyalar `UTF-8 (BOM'suz)` olacak
- Faz dokümanı oluşturmadan doğrudan implementasyona geçme

---

## 2. Önce Oku

Implementasyona başlamadan önce şu kaynakları mutlaka oku:

1. `README.md`
2. `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
3. `apps/admin_console/lib/src/app/admin_console_router.dart`
4. `apps/admin_console/lib/src/features/common/admin_page_parts.dart`
5. `apps/admin_console/lib/src/core/admin_providers.dart`
6. `apps/admin_console/lib/src/features/content/content_page.dart`
7. `packages/shared_domain/lib/src/repositories/admin_content_repository.dart`
8. `packages/shared_domain/lib/src/entities/admin_console_contracts.dart`
9. `packages/shared_data/lib/src/repositories/foundation_admin_content_repository.dart`
10. `supabase/migrations/202603110032_admin_console_stabilization_detail_contracts.sql`
11. `supabase/migrations/202603110033_admin_console_reading_import.sql`
12. `supabase/functions/admin_invite_users/index.ts`
13. `docs/ENCODING.md`

Okuma tamamlanmadan mimari karar verme.

---

## 3. Repo Gerçekleri

Şunları sabit kabul et:

- Admin router `GoRouter` kullanır.
- Admin state yönetimi `Riverpod` tabanlıdır.
- Admin shell ve sidebar yapısı `AdminShellFrame` ve `AdminDestination` etrafında kuruludur.
- Admin content persistence zinciri mevcutta `AdminContentRepository` ve `FoundationAdminContentRepository` üstünden yürür.
- Reading kalıcı modeli `reading_passages`, `reading_passage_sentences`, `reading_passage_words` tablolarıdır.
- Reading publish modeli `status` tabanlı değil; `is_published`, `publish_at`, `unpublish_at` tabanlıdır.
- Reading detail JSON sözleşmesi mevcutta `AdminReadingDetail` üstünden yürür.
- Admin CRUD akışı `admin_get_*_detail`, `admin_upsert_*_detail`, `admin_import_*` ve `admin_list_*` RPC’leriyle ilerler.
- `content_versions`, `content_change_log` ve `audit_logs` zaten vardır; yeni iş akışı bunları bozmamalı, bunlarla uyumlu çalışmalıdır.
- Admin console şu anda düz bir sidebar listesi kullanır; ayrı `layout/admin_sidebar.dart` veya `router/app_router.dart` dosyası yoktur.

Yanlış varsayım yapma:

- `readings`, `reading_sentences`, `focus_words` gibi eski/genel isimleri yeni gerçek tablo isimleri yerine kullanma.
- `AppColors` gibi repo dışı tema sınıfı icat etme.
- “Yeni paralel CRUD sistemi” kurma.

---

## 4. Hedef Özellik

Yeni route:

- `/content/ai-assistant`

Bu route altında admin kullanıcı şunları yapabilmelidir:

1. AI üretim parametrelerini girer
2. Gemini tabanlı edge function ile okuma taslağı üretir
3. Üretilen sonucu edit edilebilir draft halinde inceler
4. Draft içindeki başlık, cümleler, çeviriler, odak kelime adayları ve okuma sorularını düzenler
5. Draft’ı taslak olarak kaydeder
6. Draft’ı yayınlar

İlk sürümde kapsam dışı:

- kelime AI üretimi
- gramer AI üretimi
- parça bazlı regenerate
- background queue / async job sistemi
- öğrenci uygulamasında soru gösterimi

Not:

- İlk sürümde tek generate akışı vardır.
- “Metni yeniden üret”, “yalnız soruları yeniden üret” gibi alt parçalı regenerate davranışı ekleme.

---

## 5. Önce Faz Dokümanı

İlk kod değişikliğinden önce şu dosyayı oluştur veya güncelle:

- `docs/phases/phase_11_admin_ai_content_assistant.md`

Bu faz dosyasında en az şu başlıklar olmalı:

1. Faz Amacı
2. Kapsam
3. Kapsam Dışı
4. Yapılacak İşler
5. Teknik Kararlar
6. Bağımlılıklar
7. Riskler
8. Test ve Kabul Kriterleri
9. İlerleme Durumu
10. Tamamlananlar / Notlar

Bu özellik boyunca faz dosyasını yaşayan doküman gibi güncelle.

---

## 6. Teknik Kararlar

Bu kararları değiştirmeden uygula:

### 6.1 Route ve UI yerleşimi

- Yeni bir `AdminDestination.aiAssistant` eklenecek.
- Sidebar’a `AI Asistan` girişi eklenecek.
- `admin_console_router.dart` içinde mevcut pattern korunacak; yeni route deferred import + `DeferredPageLoader` ile bağlanacak.
- Sidebar sırası:
  1. Dashboard
  2. Kullanıcılar
  3. AI Asistan
  4. Okumalar
  5. Kelimeler
  6. Gramer
  7. Ayarlar
- Yeni page, mevcut `AdminShellFrame` kullanacak.
- Mevcut `AdminContentPage` içindeki segmented button yalnızca `Okumalar / Kelimeler / Gramer` olarak kalabilir; onu AI sekmeli hale getirmek bu iş için zorunlu değildir.
- Yeni AI sayfası ayrı feature page olarak yazılacak; mevcut `AdminContentPage` içine sıkıştırılmayacak.

### 6.2 AI generation katmanı

- Yeni generation edge function yalnızca üretim yapar.
- Edge function veri kaydetmez.
- Kalıcı kayıt admin reading detail persistence zinciri üzerinden yapılır.
- Bu yüzden AI repository’nin görevi:
  - request body üretmek
  - edge function çağırmak
  - sonucu typed draft modele maplemek
- Draft save ve publish mevcut `AdminContentRepository` zincirinden yürür.

### 6.3 Reading soru persistence kararı

- Okuma soruları ilk sürümde kalıcıya yazılacaktır.
- Bunun için yeni tablo gerekir.
- Yeni soru modeli mevcut `AdminReadingDetail` JSON sözleşmesine eklenir.
- Soru persistence admin reading detail RPC zincirine dahil edilir.
- Öğrenci uygulaması bu soruları bu iş kapsamında tüketmez.

### 6.4 Odak kelime kararı

Bu kritik kararı uygula:

- AI odak kelimeleri ilk aşamada “öneri” olarak üretir.
- `reading_passage_words` yalnızca mevcut `words` satırlarına bağlanabildiği için, AI önerileri save öncesi çözülmelidir.
- İlk sürümde AI tarafından önerilen odak kelimeler otomatik olarak yeni `words` kaydına çevrilmeyecek.
- Admin kullanıcı her öneriyi şu iki yoldan biriyle çözmelidir:
  1. mevcut bir `word_id` ile eşleştirme
  2. öneriyi silme
- `word_id` çözülmemiş linked word kaldığında `save draft` ve `publish` bloklanır.

Bu karar bilinçlidir. Sessiz otomatik kelime yaratma yapma.

### 6.5 AI metadata kararı

AI ile üretilen reading kayıtlarında iz bırak:

- `reading_passages` tablosuna AI kaynağını işaretleyen alanlar ekle
- minimum öneri:
  - `ai_generated boolean not null default false`
  - `ai_generation_meta jsonb`

Bu metadata admin detail contract içinde de taşınır.

---

## 7. Yeni Alanlar, Tipler ve Dosyalar

### 7.1 Domain katmanı

Yeni AI generation sözleşmeleri ekle:

- `packages/shared_domain/lib/src/entities/admin_ai_reading_contracts.dart`

Bu dosyada en az şu tipler olsun:

```dart
class AdminAiGenerateReadingRequest {
  final String topic;
  final String cefrLevel;
  final int targetWordCount;
  final int focusWordCount;
  final int questionCount;
  final String? category;
  final String? tagsRaw;
  final String? extraInstructions;
}

class AdminAiGeneratedReadingDraft {
  final String title;
  final String? level;
  final String? category;
  final String? tagsRaw;
  final List<AdminReadingSentenceInput> sentences;
  final List<AdminAiSuggestedLinkedWord> suggestedLinkedWords;
  final List<AdminReadingQuestionInput> questions;
  final AdminAiGenerationMeta generationMeta;
}
```

`AdminReadingDetail` sözleşmesini genişlet:

- `List<AdminReadingQuestionInput> questions`
- `bool aiGenerated`
- `AdminAiGenerationMeta? aiGenerationMeta`

`AdminReadingQuestionInput` alanları:

```dart
class AdminReadingQuestionInput {
  final String? id;
  final int sortOrder;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String? explanation;
}
```

Bu soru tipi `packages/shared_domain/lib/src/entities/admin_console_contracts.dart` içinde veya aynı dosyada mantıklı yerde tanımlanabilir; fakat kesinlikle `AdminReadingDetail` sözleşmesine bağlanmalıdır.

### 7.2 Repository katmanı

Yeni repository interface:

- `packages/shared_domain/lib/src/repositories/admin_ai_reading_repository.dart`

```dart
abstract interface class AdminAiReadingRepository {
  Future<AppResult<AdminAiGeneratedReadingDraft>> generateReadingDraft(
    AdminAiGenerateReadingRequest request,
  );
}
```

Yeni data impl:

- `packages/shared_data/lib/src/repositories/foundation_admin_ai_reading_repository.dart`

Kurallar:

- `Supabase.instance.client.functions.invoke(...)` kullan
- function adı sabit: `admin_ai_generate_reading_draft`
- hata mesajlarını kullanıcıya uygun kısa metne çevir
- JSON parse hatasını ayrı handle et

Yeni provider:

- `adminAiReadingRepositoryProvider`

Bunu `apps/admin_console/lib/src/core/admin_providers.dart` içine ekle.

### 7.3 Admin app state

Yeni controller:

- `apps/admin_console/lib/src/core/admin_ai_assistant_controller.dart`

Yeni state:

```dart
enum AdminAiAssistantStatus { idle, loading, success, error, saving, publishing }

class AdminAiAssistantState {
  final AdminAiAssistantStatus status;
  final AdminAiGenerateReadingRequest draftRequest;
  final AdminAiGeneratedReadingDraft? generatedDraft;
  final AdminReadingDetail? editableDraft;
  final String? errorMessage;
  final String? noticeMessage;
}
```

Controller metodları:

- `generateDraft()`
- `replaceEditableDraft(AdminReadingDetail detail)`
- `saveDraft()`
- `publish()`
- `clear()`
- `clearMessage()`

Persistence kuralı:

- `saveDraft()` mevcut `AdminContentRepository.upsertReadingDetail(...)` ile çalışır
- `publish()` de yine `upsertReadingDetail(...)` kullanır; publish için `isPublished = true` gönderir
- yeni parallel save API uydurma

### 7.4 Admin app UI

Yeni feature klasörü:

- `apps/admin_console/lib/src/features/ai_assistant/`

Minimum dosyalar:

- `ai_assistant_page.dart`
- `widgets/ai_generation_form.dart`
- `widgets/ai_draft_editor.dart`
- `widgets/ai_linked_words_panel.dart`
- `widgets/ai_questions_panel.dart`
- `widgets/ai_publish_panel.dart`

UI kuralları:

- mevcut `AdminShellFrame`, `AdminPanelCard`, `AdminEmptyState` ve tema tokenlarıyla çalış
- yeni renk sistemi icat etme
- mevcut `shared_ui` token yaklaşımını kullan
- geniş ekranda iki kolonlu, dar ekranda tek kolonlu düzen kur

Dar ekran davranışı:

- `maxWidth < 1100`: tek kolon
- `maxWidth >= 1100`: sol kolon editör, sağ kolon publish ve metadata paneli

---

## 8. Supabase Tasarımı

### 8.1 Yeni migration

Yeni migration ekle:

- `supabase/migrations/[timestamp]_admin_ai_reading_assistant.sql`

Bu migration en az şunları yapmalı:

1. `reading_passages` tablosuna:
   - `ai_generated boolean not null default false`
   - `ai_generation_meta jsonb`
2. Yeni tablo:
   - `reading_passage_questions`
3. Gerekli index’ler
4. `updated_at` / audit / content change tracking uyumu

`reading_passage_questions` önerilen minimum alanları:

```sql
create table if not exists public.reading_passage_questions (
  id uuid primary key default gen_random_uuid(),
  passage_id uuid not null references public.reading_passages(id) on delete cascade,
  sort_order integer not null default 1,
  question text not null,
  options_json jsonb not null default '[]'::jsonb,
  correct_option_index integer not null,
  explanation text,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id)
);
```

Ek gereklilikler:

- `passage_id, sort_order` index’i ekle
- `content_change_log` için `reading_passage_questions` trigger’ı ekle
- gerekiyorsa `audit_logs` ve `content_versions` zinciri mevcut trigger yaklaşımıyla uyumlu çalışsın

### 8.2 Admin reading detail RPC genişletmesi

Mevcut RPC’leri genişlet:

- `admin_get_reading_detail`
- `admin_upsert_reading_detail`

Yeni davranış:

- `admin_get_reading_detail` artık `questions` alanını da döndürür
- `admin_upsert_reading_detail` artık `questions` dizisini kabul eder
- update sırasında mevcut sorular silinip payload’daki sıraya göre yeniden yazılabilir
- audit log payload’ına `question_count` eklenir
- `ai_generated` ve `ai_generation_meta` da payload’tan okunur ve döndürülür

Yeni ayrı `admin_save_ai_reading_draft` RPC’si açma.

### 8.3 Edge function

Yeni function:

- `supabase/functions/admin_ai_generate_reading_draft/index.ts`

İşlev:

- yalnızca AI üretim yapar
- DB’ye kalıcı kayıt yazmaz
- admin veya developer olmayan çağrıları reddeder

Auth doğrulama:

- `Authorization` header zorunlu
- `SUPABASE_URL` + `SUPABASE_ANON_KEY` ile caller client oluştur
- `current_app_role()` kullan
- yalnız `admin` ve `developer` rollerine izin ver

`SUPABASE_SERVICE_ROLE_KEY` bu function için zorunlu değildir.

Secret ve config:

- `GEMINI_API_KEY` zorunlu
- `GEMINI_MODEL` opsiyonel, default: `gemini-2.0-flash`

Request body:

```ts
interface GenerateReadingDraftRequest {
  topic: string;
  cefr_level: "A1" | "A2" | "B1" | "B2" | "C1" | "C2";
  target_word_count: number;
  focus_word_count: number;
  question_count: number;
  category?: string | null;
  tags_raw?: string | null;
  extra_instructions?: string | null;
}
```

Response body:

```ts
interface GenerateReadingDraftResponse {
  title: string;
  level: string | null;
  category: string | null;
  tags_raw: string | null;
  sentences: Array<{
    idx: number;
    sentence_en: string;
    sentence_tr: string | null;
  }>;
  suggested_linked_words: Array<{
    en_word: string;
    tr_meaning: string;
    pos: string;
    notes?: string | null;
  }>;
  questions: Array<{
    sort_order: number;
    question: string;
    options: string[];
    correct_option_index: number;
    explanation?: string | null;
  }>;
  generation_meta: {
    provider: "gemini";
    model: string;
    topic: string;
    cefr_level: string;
    target_word_count: number;
    focus_word_count: number;
    question_count: number;
    actual_word_count: number;
    generated_at: string;
  };
}
```

Çok önemli:

- `body` veya `text` için ayrı DB alanı icat etme
- source of truth `sentences` dizisidir
- UI preview gerekirse İngilizce cümleleri birleştirerek üret

Gemini çağrısında zorunlu kurallar:

- yalın JSON döndürmesini iste
- response schema doğrula
- invalid JSON veya eksik alan durumunda 502/500 yerine kontrollü, anlaşılır hata dön

---

## 9. Save ve Publish Kuralları

### 9.1 Save draft

Kaydetme öncesi şu validasyonlar zorunlu:

- başlık boş olamaz
- en az 1 cümle olmalı
- her cümlede `sentence_en` dolu olmalı
- en az 1 soru olmalı
- her soruda en az 2 seçenek olmalı
- `correct_option_index` seçenek dizisi sınırları içinde olmalı
- çözümlenmemiş linked word kalmamalı

Taslak kaydında:

- `is_published = false`
- `ai_generated = true`
- `ai_generation_meta` set edilir

### 9.2 Publish

Publish butonu ayrı bir yeni persistence hattı açmayacak.

Publish sırasında:

- yine `upsertReadingDetail(...)` kullan
- `is_published = true`
- `publish_at` ve `unpublish_at` UI’dan geliyorsa koru
- `published_at` gibi türetilen alanları server tarafındaki mevcut RPC mantığı yönetsin

### 9.3 Linked word çözümleme

AI suggestions ile mevcut word kataloğu arasında çözümleme UI’si ekle.

Beklenen davranış:

- her öneri için mevcut `words` içinden seçim yapılabilir
- eşleşme yoksa admin öneriyi silebilir
- unresolved item varsa save ve publish bloklanır

Bu ilk sürümde otomatik word create yok.

---

## 10. UI Davranışı

AI sayfası şu bölümleri içermeli:

1. Parametre formu
2. Generation durum banner’ı
3. Edit edilebilir draft alanı
4. Linked word çözümleme paneli
5. Soru editörü
6. Publish paneli
7. Metadata paneli

Beklenen alanlar:

- `topic`
- `cefrLevel`
- `targetWordCount`
- `focusWordCount`
- `questionCount`
- `category`
- `tagsRaw`
- `extraInstructions`

Editör tarafında:

- başlık düzenlenebilir
- cümle satırları düzenlenebilir
- Türkçe çeviri alanları düzenlenebilir
- soru metni, seçenekler, doğru indeks ve açıklama düzenlenebilir
- linked word önerileri çözümlenebilir

Kullanıcı mesajları:

- network error
- JSON parse error
- auth/forbidden
- generation success
- draft save success
- publish success

Bu mesajları state içinde yönet, sayfa içinde snack bar veya banner ile göster.

---

## 11. Dosya Yerleşimi

Yeni veya değişecek ana dosyalar:

```text
docs/phases/
  phase_11_admin_ai_content_assistant.md

supabase/migrations/
  [timestamp]_admin_ai_reading_assistant.sql

supabase/functions/
  admin_ai_generate_reading_draft/
    index.ts
    index_test.ts

packages/shared_domain/lib/src/entities/
  admin_ai_reading_contracts.dart
  admin_console_contracts.dart                # reading question + ai metadata genişletmesi

packages/shared_domain/lib/src/repositories/
  admin_ai_reading_repository.dart

packages/shared_data/lib/src/repositories/
  foundation_admin_ai_reading_repository.dart
  foundation_admin_content_repository.dart    # reading detail questions desteği

apps/admin_console/lib/src/core/
  admin_ai_assistant_controller.dart
  admin_providers.dart

apps/admin_console/lib/src/app/
  admin_console_router.dart

apps/admin_console/lib/src/features/common/
  admin_page_parts.dart

apps/admin_console/lib/src/features/ai_assistant/
  ai_assistant_page.dart
  widgets/
    ai_generation_form.dart
    ai_draft_editor.dart
    ai_linked_words_panel.dart
    ai_questions_panel.dart
    ai_publish_panel.dart

apps/admin_console/test/
  features/ai_assistant/ai_assistant_page_test.dart
  core/admin_ai_assistant_controller_test.dart

packages/shared_data/test/
  migration_contract_test.dart
```

`impl/` gibi repo dışı klasör yapısı oluşturma.

---

## 12. Test Zorunlulukları

Şunlar zorunludur:

### 12.1 Migration ve schema

- `packages/shared_data/test/migration_contract_test.dart` güncellenmeli
- yeni migration dosyası test beklentilerine eklenmeli
- `reading_passage_questions` ve ilgili RPC genişletmeleri sözleşme testinde doğrulanmalı

### 12.2 Edge function

`supabase/functions/admin_ai_generate_reading_draft/index_test.ts`

Minimum testler:

1. admin/developer yetkili istek -> 200 + valid JSON
2. yetkisiz rol -> 403
3. eksik veya invalid request -> 400
4. invalid Gemini response -> kontrollü hata

### 12.3 Shared data/domain

Minimum testler:

1. AI response mapping typed draft’a doğru dönüşüyor
2. `AdminReadingDetail` `questions` alanı serialize/deserialize oluyor
3. `foundation_admin_content_repository` reading detail save akışı soru alanlarını taşıyor
4. AI repository function invoke hata durumlarını doğru mapliyor

### 12.4 Admin widget ve controller

Minimum testler:

1. route açılıyor
2. form validasyonu çalışıyor
3. loading state render ediliyor
4. success state render ediliyor
5. error state render ediliyor
6. draft save çağrısı yapılıyor
7. publish çağrısı yapılıyor
8. unresolved linked words save/publish’i blokluyor

### 12.5 Smoke

Smoke senaryosu:

1. admin login
2. `/content/ai-assistant`
3. formu doldur
4. generate
5. draft’ı düzenle
6. linked words çöz
7. save draft
8. `/content/readings` listesinde kaydı gör
9. detail tekrar açıldığında questions ve AI metadata yükleniyor mu kontrol et

---

## 13. Kabul Kriterleri

İş tamamlanmış sayılması için şunların hepsi sağlanmalı:

- `/content/ai-assistant` route’u açılıyor
- sidebar’da `AI Asistan` görünüyor
- generation edge function admin/developer rolüyle çalışıyor
- edge function yalnızca generation yapıyor, kalıcı kayıt yazmıyor
- üretilen draft edit edilebilir state’e mapleniyor
- linked words save öncesi çözülmek zorunda
- `AdminReadingDetail` artık soruları ve AI metadata’yı taşıyor
- `reading_passage_questions` tablosu migration ile eklenmiş
- `admin_get_reading_detail` ve `admin_upsert_reading_detail` soru alanlarını taşıyor
- save draft sonrası kayıt `/content/readings` listesinde görünür
- publish sonrası mevcut admin reading listesi bozulmuyor
- student reading akışı bu değişiklik yüzünden kırılmıyor
- `dart analyze apps/admin_console packages/shared_domain packages/shared_data` temiz
- ilgili testler geçiyor

---

## 14. Çıktı Formatı

İş bittiğinde final cevabın şunları içermeli:

1. kısa özet
2. değişen ana dosyalar
3. migration özeti
4. çalışan test komutları
5. çalıştırılamayan veya eksik kalan doğrulamalar
6. kalan riskler

Belirsiz kapanış yapma.
“Muhtemelen”, “gibi görünüyor”, “ileride bakılır” türü ifadeleri minimumda tut.

---

## 15. Yasaklar

Şunları yapma:

- React / Next / başka frontend stack önerme
- yeni bağımsız admin persistence sistemi kurma
- `AdminContentRepository` zincirini bypass eden dağınık direct write mantığı kurma
- `service_role` key’i client’a taşıma
- reading body/text için sahte DB kolonu icat etme
- unresolved linked words’u sessizce ignore edip save etme
- AI önerilerini sessizce `words` tablosuna otomatik ekleme
- öğrenci uygulamasında yeni AI ekranı açma
- repo içinde olmayan dosya yollarını referans alma

---

## 16. Son Hatırlatma

Bu işte amaç “AI ile tüm içerik CMS’ini yeniden yazmak” değildir.

Amaç:

- mevcut PASSAGETR admin mimarisi içine
- reading-first
- güvenli
- repo-gerçekleriyle uyumlu
- kararları net

bir AI reading assistant eklemektir.

Önce repo gerçeğini izle, sonra implement et.
