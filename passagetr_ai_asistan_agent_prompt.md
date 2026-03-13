# PASSAGETR v2 — AI İçerik Asistanı: Agent Geliştirme Promptu

> **Hedef:** `apps/admin_console` içine, mevcut mimari ve kod kurallarına tam uyumlu, Gemini API tabanlı AI içerik üretim ekranı ekle.
> Bu doküman tek başına yeterli bir agent promptudur. Yukarıdan aşağıya oku, sırayla uygula.

---

## 1. Proje Bağlamı

### 1.1 Repo yapısı

```
apps/
  admin_console/          ← hedef uygulama
  student_app/
packages/
  shared_core/
  shared_domain/
  shared_data/
  shared_ui/
supabase/
  migrations/
```

### 1.2 Admin console teknik yığını

- Flutter web uygulaması (dart)
- Supabase backend (postgres + edge functions + storage)
- `AdminAuthState` / `AdminAuthStatus` ile auth guard — tüm protected route'lar bu gate'ten geçer
- Router: GoRouter (veya mevcut router implementasyonu ne ise ona uy)
- State management: mevcut provider mimarisini takip et (`ChangeNotifier` / Riverpod — repo'da hangisi kullanılıyorsa)
- Supabase edge functions: `supabase/functions/` altında TypeScript/Deno

### 1.3 Mevcut içerik tabloları (referans)

```sql
readings          (id, title, body, level, status, publish_at, unpublish_at, created_at, updated_at, updated_by)
reading_sentences (id, reading_id, order_index, text, translation)
focus_words       (id, reading_id, word, pos, turkish, example, auto_assigned)
grammar_modules   (id, title, ...)
```

### 1.4 Kod kuralları

- `service_role` key istemciye taşınmaz; kritik işlemler edge function üzerinden yapılır
- Her yeni Supabase alanı için migration dosyası yaz (`supabase/migrations/YYYYMMDDHHMMSS_<açıklama>.sql`)
- Yeni sayfa eklenirken admin router'a hem route hem de sidebar entry eklenir
- Sidebar ve route isimlendirmesi snake_case, widget class isimleri PascalCase

---

## 2. Özellik Tanımı

### 2.1 Ne yapılacak

Admin paneline `/content/ai-assistant` route'unda yeni bir ekran eklenecek. Bu ekran:

1. İçerik editörünün **parametreleri** (seviye, konu, kelime sayısı, vb.) girmesini sağlar
2. Gemini API'yi çağıran bir **Supabase edge function** üzerinden okuma metni, odak kelimeler ve test soruları üretir
3. Üretilen içeriği editörün **inceleyip düzenlemesine** izin verir
4. Onaylanan içeriği `readings`, `reading_sentences`, `focus_words` tablolarına **taslak olarak kaydeder**
5. Editör isterse **zamanlanmış yayın** (`publish_at`) veya **anlık yayın** yapabilir

### 2.2 Kapsam dışı

- Student app tarafında değişiklik yok
- Mevcut okuma/kelime CRUD akışları bozulmaz
- Gemini API key asla client'a taşınmaz

---

## 3. Teknik Tasarım

### 3.1 Edge function: `admin_ai_generate_content`

**Dosya:** `supabase/functions/admin_ai_generate_content/index.ts`

**Giriş (request body):**

```typescript
interface GenerateContentRequest {
  topic: string;           // "kahvehane kültürü"
  level: 'A1'|'A2'|'B1'|'B2'|'C1'|'C2';
  word_count: number;      // 80 | 150 | 250
  focus_word_count: number; // 5 | 8 | 12
  question_count: number;  // 2 | 3 | 5
  extra_notes?: string;    // opsiyonel serbest alan
  regenerate?: 'text'|'words'|'questions'|null; // parça yenileme
  existing_text?: string;  // regenerate='words'|'questions' için mevcut metin
}
```

**Çıkış (response body):**

```typescript
interface GenerateContentResponse {
  title: string;
  text: string;
  sentences: { order_index: number; text: string; translation: string }[];
  focus_words: { word: string; pos: string; turkish: string; example: string }[];
  questions: {
    question: string;
    options: string[];
    correct: number;
    explanation: string;
  }[];
  meta: {
    actual_word_count: number;
    grammar_focus: string;
    difficulty_notes: string;
  };
}
```

**Gemini API çağrısı:**

```typescript
// Gemini 2.0 Flash — içerik üretim için yeterli, hızlı, ucuz
const GEMINI_MODEL = 'gemini-2.0-flash';
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

const geminiKey = Deno.env.get('GEMINI_API_KEY'); // Supabase secret olarak sakla
```

**Prompt şablonu (edge function içinde sabit):**

```
Sen bir İngilizce dil öğrenme platformu (PASSAGETR) için içerik üretiyorsun.

GÖREV: Verilen parametrelere uygun bir okuma parçası üret.

Parametreler:
- CEFR Seviyesi: {level}
- Konu: {topic}
- Kelime sayısı hedefi: ~{word_count}
- Odak kelime sayısı: {focus_word_count}
- Test soru sayısı: {question_count}
{extra_notes}

KURALLAR:
- Metin {level} seviyesine uygun kelime ve yapı kullan
- Odak kelimeler metinde geçmeli ve pedagojik değeri yüksek olmalı
- Sorular okuma anlayışını test etmeli, cevap metnin içinde açık olmalı
- Cümleleri sentence_count adet satıra böl (her satır bir sentence)

ÇIKTI: Yalnızca geçerli JSON döndür, başka hiçbir şey yazma:
{ "title": "...", "text": "...", "sentences": [...], "focus_words": [...], "questions": [...], "meta": {...} }
```

**Auth guard:** Edge function içinde `Authorization: Bearer <token>` kontrolü yap; admin rolü olmayanları 403 ile reddet.

```typescript
const { data: { user } } = await supabase.auth.getUser(token);
const { data: claims } = await supabase.rpc('get_user_claims', { uid: user.id });
if (claims?.role !== 'admin') return new Response('Forbidden', { status: 403 });
```

**Supabase secret ekle:**

```bash
supabase secrets set GEMINI_API_KEY=AIza...
```

---

### 3.2 Migration

**Dosya:** `supabase/migrations/[timestamp]_add_ai_draft_fields.sql`

```sql
-- AI tarafından oluşturulan içerikleri işaretlemek için
ALTER TABLE readings
  ADD COLUMN IF NOT EXISTS ai_generated boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS ai_prompt_meta jsonb;

-- Test soruları tablosu (yoksa oluştur)
CREATE TABLE IF NOT EXISTS reading_questions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reading_id  uuid REFERENCES readings(id) ON DELETE CASCADE,
  order_index integer NOT NULL DEFAULT 0,
  question    text NOT NULL,
  options     jsonb NOT NULL,  -- string[]
  correct     integer NOT NULL,
  explanation text,
  created_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reading_questions_reading_id ON reading_questions(reading_id);
```

---

### 3.3 Repository katmanı

**Dosya:** `packages/shared_data/lib/src/repositories/ai_content_repository.dart`

```dart
abstract class AiContentRepository {
  Future<AiGenerateContentResponse> generateContent(AiGenerateContentRequest request);
  Future<String> saveAsDraft(AiGenerateContentResponse content, AiDraftMeta meta);
  Future<void> publish(String readingId, {DateTime? publishAt});
}
```

`AiGenerateContentRequest` ve `AiGenerateContentResponse` modellerini `packages/shared_domain/lib/src/models/ai_content/` altına ekle.

**Edge function çağrısı:**

```dart
final response = await supabase.functions.invoke(
  'admin_ai_generate_content',
  body: request.toJson(),
);
```

---

### 3.4 UI State

**Dosya:** `apps/admin_console/lib/features/ai_assistant/ai_assistant_notifier.dart`

```dart
enum AiAssistantStatus { idle, loading, success, error }

enum RegenerateTarget { none, text, words, questions }

class AiAssistantState {
  final AiAssistantStatus status;
  final AiGenerateContentResponse? result;
  final RegenerateTarget regenerating;
  final String? errorMessage;
  // ...
}
```

---

## 4. UI Tasarımı

### 4.1 Route ve sidebar

- Route: `/content/ai-assistant`
- Sidebar başlığı: **AI Asistan** (🤖 ikonu ile)
- Sidebar grubu: mevcut "İçerik" grubu altına, "Okumalar"ın hemen üstüne ekle
- Auth guard: mevcut admin protected shell'i kullan, ayrıca yeni guard yazma

---

### 4.2 Ekran düzeni (wireframe)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ TOPBAR: PASSAGETR Admin          İçerik › AI Asistan                   │
├──────────────┬──────────────────────────────────────────────────────────┤
│  SIDEBAR     │  MAIN CONTENT                                            │
│              │                                                          │
│  Dashboard   │  AI İçerik Asistanı                                     │
│  Kullanıcılar│  Seviye ve konu gir — metin, kelimeler ve sorular üretilir│
│              │                                                          │
│  [İçerik]    │  ┌── ADIM 1: Parametreler ─────────────────────────────┐ │
│  🤖 AI       │  │                                                      │ │
│    Asistan ← │  │  [CEFR ▾]  [Kelime Sayısı ▾]  [Konu / Bağlam    ]  │ │
│  Kelimeler   │  │  [Odak Kelime ▾]  [Soru Sayısı ▾]                   │ │
│  Okumalar    │  │  [Ek Yönergeler (opsiyonel)                      ]   │ │
│  Gramer      │  │                                                      │ │
│              │  │  [✦ İçerik Üret]  [Temizle]                          │ │
│  [Sistem]    │  └──────────────────────────────────────────────────────┘ │
│  Ayarlar     │                                                          │
│              │  ─── Yükleniyor / Hata / Başarı durumu ──────────────── │
│              │                                                          │
│              │  ┌── SOL KOLON (flex:2) ──┐  ┌── SAĞ KOLON (flex:1) ─┐ │
│              │  │                        │  │                        │ │
│              │  │  📄 Okuma Metni        │  │  🔑 Odak Kelimeler     │ │
│              │  │  ┌──────────────────┐  │  │  ┌────────────────┐   │ │
│              │  │  │ [Başlık]         │  │  │  │ [chip][chip]   │   │ │
│              │  │  │                  │  │  │  │ [chip][chip]   │   │ │
│              │  │  │  Metin içinde    │  │  │  └────────────────┘   │ │
│              │  │  │  odak kelimeler  │  │  │  [↻ Kelimeleri Yenile]│ │
│              │  │  │  highlight       │  │  │                        │ │
│              │  │  └──────────────────┘  │  ├────────────────────────┤ │
│              │  │  [↻ Metni Yenile][Kop] │  │                        │ │
│              │  │                        │  │  📤 Yayın              │ │
│              │  ├────────────────────────┤  │  Plan:   [Free/Pro ▾]  │ │
│              │  │                        │  │  Tarih:  [__/__/____]  │ │
│              │  │  🧩 Test Soruları      │  │                        │ │
│              │  │  ┌──────────────────┐  │  │  [💾 Taslak Kaydet]   │ │
│              │  │  │ 1. Soru metni?   │  │  │  [🚀 Yayınla]         │ │
│              │  │  │ ○ A) ...         │  │  │                        │ │
│              │  │  │ ✓ B) ... ← doğru │  │  ├────────────────────────┤ │
│              │  │  │ ○ C) ...         │  │  │  ℹ Meta Bilgi          │ │
│              │  │  └──────────────────┘  │  │  Gramer odağı: ...     │ │
│              │  │  [↻ Soruları Yenile]   │  │  Seviye notu: ...      │ │
│              │  └────────────────────────┘  └────────────────────────┘ │
└──────────────┴──────────────────────────────────────────────────────────┘
```

---

### 4.3 Widget ağacı

```
AiAssistantPage (route: /content/ai-assistant)
└── AiAssistantShell (Consumer/Listener → AiAssistantNotifier)
    ├── AiAssistantParamsCard          ← Adım 1 formu
    │   ├── LevelDropdown
    │   ├── WordCountDropdown
    │   ├── TopicTextField
    │   ├── FocusWordCountDropdown
    │   ├── QuestionCountDropdown
    │   ├── ExtraNotesTextField
    │   └── GenerateButton
    ├── AiStatusBanner                 ← loading / error / success
    └── AiResultLayout (görünür: status == success)
        ├── ReadingTextCard
        │   ├── ReadingTitleText
        │   ├── HighlightedBodyText    ← odak kelimeler vurgulu
        │   ├── RegenerateTextButton
        │   └── CopyButton
        ├── TestQuestionsCard
        │   ├── QuestionItem (x N)
        │   └── RegenerateQuestionsButton
        ├── FocusWordsCard
        │   ├── WordChip (x N)
        │   └── RegenerateWordsButton
        ├── PublishPanel
        │   ├── PlanDropdown
        │   ├── PublishAtDatePicker
        │   ├── SaveDraftButton
        │   └── PublishButton
        └── MetaInfoCard
```

---

### 4.4 Renk ve stil kuralları

Mevcut admin_console tema sistemine tamamen uy. Yeni renk veya stil sabiti ekleme; yalnızca aşağıdaki mevcut token'ları kullan:

| Kullanım | Token |
|---|---|
| Birincil aksiyon | `AppColors.teal` / `AppColors.primary` |
| Başarı durumu | `AppColors.success` veya yeşil ton |
| Uyarı / Taslak | `AppColors.amber` veya sarı ton |
| Hata | `AppColors.danger` / `AppColors.red` |
| Kart arka planı | `AppColors.surface` / `Colors.white` |
| Sayfa arka planı | `AppColors.background` |
| Muted metin | `AppColors.textSecondary` |

Eğer projede `AppTheme` veya `AppColors` sınıfı yoksa `packages/shared_ui/lib/src/theme/` altındakini bul ve oradan import et.

---

### 4.5 Responsive davranış

- Ekran genişliği ≥ 900px: sol/sağ kolon yan yana (`Row`)
- Ekran genişliği < 900px: alt alta (`Column`), sağ kolon aşağıya kayar
- Parametreler formu her zaman tam genişlikte

---

## 5. Uygulama Adımları

Agent bu sırayı takip etmeli. Her adımı tamamladıktan sonra bir sonrakine geç.

### Adım 1 — Migration

- [ ] `supabase/migrations/[timestamp]_add_ai_draft_fields.sql` dosyasını oluştur
- [ ] `readings` tablosuna `ai_generated`, `ai_prompt_meta` kolonlarını ekle
- [ ] `reading_questions` tablosunu oluştur (yoksa)
- [ ] Yerel Supabase'de `supabase db reset` veya `supabase migration up` ile uygula

### Adım 2 — Edge function

- [ ] `supabase/functions/admin_ai_generate_content/index.ts` oluştur
- [ ] `GEMINI_API_KEY` env değişkenini oku
- [ ] Admin auth guard yaz
- [ ] Gemini API çağrısını yaz (yukarıdaki prompt şablonuyla)
- [ ] JSON parse + response döndür
- [ ] `supabase/functions/admin_ai_generate_content/deno.json` veya `import_map.json` varsa ekle

### Adım 3 — Domain modelleri

- [ ] `packages/shared_domain/lib/src/models/ai_content/ai_generate_content_request.dart`
- [ ] `packages/shared_domain/lib/src/models/ai_content/ai_generate_content_response.dart`
- [ ] `packages/shared_domain/lib/src/models/ai_content/ai_focus_word.dart`
- [ ] `packages/shared_domain/lib/src/models/ai_content/ai_question.dart`
- [ ] Her modelde `fromJson` / `toJson` — `json_serializable` kullanılıyorsa annotate et

### Adım 4 — Repository

- [ ] `packages/shared_data/lib/src/repositories/ai_content_repository.dart` abstract class
- [ ] `packages/shared_data/lib/src/repositories/impl/supabase_ai_content_repository.dart` impl
  - `generateContent` → edge function çağrısı
  - `saveAsDraft` → `readings` INSERT + `reading_sentences` INSERT + `focus_words` INSERT + `reading_questions` INSERT
  - `publish` → `readings` UPDATE status/publish_at
- [ ] Repository'yi DI / provider'a kaydet (mevcut pattern'i takip et)

### Adım 5 — State management

- [ ] `apps/admin_console/lib/features/ai_assistant/ai_assistant_notifier.dart` yaz
- [ ] `AiAssistantState` class'ını tanımla
- [ ] Metodlar: `generate()`, `regenerateText()`, `regenerateWords()`, `regenerateQuestions()`, `saveAsDraft()`, `publish()`, `clear()`
- [ ] Hata yönetimi: edge function hatası, ağ hatası, JSON parse hatası ayrı ayrı handle et

### Adım 6 — UI

- [ ] `apps/admin_console/lib/features/ai_assistant/` klasörünü oluştur
- [ ] Widget ağacını (Bölüm 4.3) dosyalara böl
- [ ] `AiAssistantPage` → router'a ekle: `/content/ai-assistant`
- [ ] Sidebar'a "AI Asistan" girişini ekle (İçerik grubunda, Okumalar'ın üstüne)
- [ ] `HighlightedBodyText`: odak kelimeler `RichText` içinde `TextSpan` ile vurgula
- [ ] Parça yenileme sırasında sadece o bölüm loading göster, diğerleri donuk kalmasın
- [ ] `RegenerateTarget` enum ile hangi parçanın yenilendiğini state'te tut

### Adım 7 — Test ve doğrulama

- [ ] Edge function unit test: `supabase/functions/admin_ai_generate_content/index_test.ts`
  - Geçerli admin token → 200 + JSON
  - Yetkisiz token → 403
  - Eksik parametre → 400
- [ ] Flutter widget test: `apps/admin_console/test/features/ai_assistant/`
  - Form validasyonu (boş konu → buton disabled)
  - Loading state doğru gösteriliyor
  - Sonuç render ediliyor
- [ ] Smoke test: admin panelini aç → `/content/ai-assistant` → form doldur → üret → taslak kaydet → Okumalar listesinde görünüyor mu kontrol et

---

## 6. Dosya Listesi Özeti

Agent'ın oluşturacağı / değiştireceği dosyalar:

```
supabase/
  migrations/
    [ts]_add_ai_draft_fields.sql                         ← YENİ
  functions/
    admin_ai_generate_content/
      index.ts                                           ← YENİ
      deno.json                                          ← YENİ

packages/
  shared_domain/lib/src/models/ai_content/
    ai_generate_content_request.dart                     ← YENİ
    ai_generate_content_response.dart                    ← YENİ
    ai_focus_word.dart                                   ← YENİ
    ai_question.dart                                     ← YENİ
  shared_data/lib/src/repositories/
    ai_content_repository.dart                           ← YENİ
    impl/supabase_ai_content_repository.dart             ← YENİ

apps/admin_console/lib/
  features/ai_assistant/
    ai_assistant_page.dart                               ← YENİ
    ai_assistant_notifier.dart                           ← YENİ
    widgets/
      ai_params_card.dart                                ← YENİ
      ai_status_banner.dart                              ← YENİ
      reading_text_card.dart                             ← YENİ
      focus_words_card.dart                              ← YENİ
      test_questions_card.dart                           ← YENİ
      publish_panel.dart                                 ← YENİ
      meta_info_card.dart                                ← YENİ
  router/
    app_router.dart                                      ← DEĞİŞİKLİK (route ekle)
  layout/
    admin_sidebar.dart                                   ← DEĞİŞİKLİK (menü girişi ekle)

apps/admin_console/test/features/ai_assistant/
  ai_assistant_notifier_test.dart                        ← YENİ
  ai_assistant_page_test.dart                            ← YENİ
```

---

## 7. Önemli Kısıtlar ve Hatırlatmalar

1. **`service_role` key istemciye taşınamaz.** Gemini API key yalnızca edge function içinde, `Deno.env.get()` ile okunur.
2. **Mevcut migration'lar bozulmaz.** Yeni migration dosyası en yüksek timestamp ile eklenir.
3. **`main` dalı arşiv sayılır.** Değişiklikler `v2-rewrite-foundation` veya aktif feature branch üzerinden yapılır.
4. **`0` odak kelimeli okumalar student listesinde gizlenir.** `saveAsDraft` sırasında en az 1 focus word kaydedilmesini zorla.
5. **Publish scheduling var.** `publish_at` boş bırakılırsa anlık yayın (`status = 'published'`, `publish_at = now()`); dolu ise zamanlanmış (`status = 'scheduled'`).
6. **Router bootstrap tamamlanmadan redirect yapılmaz.** Yeni route protected shell içinde kalmalı; ayrıca auth guard yazma.
7. **Dart analyze geçmeli.** Commit öncesi `dart analyze apps/admin_console packages/shared_domain packages/shared_data` çalıştır ve uyarı bırakma.

---

## 8. Kabul Kriterleri

Özellik şu koşulların tamamı sağlandığında tamamlanmış sayılır:

- [ ] Admin panelinde `/content/ai-assistant` route'u açılıyor
- [ ] Sidebar'da "AI Asistan" girişi görünüyor
- [ ] Form doldurulup "İçerik Üret" butonuna basılınca Gemini API'den yanıt geliyor
- [ ] Üretilen metin, odak kelimeler ve test soruları ekranda görünüyor
- [ ] Odak kelimeler metin içinde vurgulu gösteriliyor
- [ ] "↻ Metni Yenile" yalnızca metni, "↻ Kelimeleri Yenile" yalnızca kelimeleri yeniliyor
- [ ] "Taslak Kaydet" → `readings` tablosunda `status='draft'` kaydı oluşuyor
- [ ] "Yayınla" → `status='published'` ve `publish_at` güncelleniyor
- [ ] Kaydedilen okuma `/content/readings` listesinde görünüyor
- [ ] Admin olmayan kullanıcı edge function'ı çağıramıyor (403)
- [ ] `dart analyze` temiz çıkıyor
- [ ] Edge function için en az 3 test var ve geçiyor
