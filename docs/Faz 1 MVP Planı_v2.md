# Faz 1 MVP Planı v2 — Değerlendirme + Revizyon (Implementation-Ready)

## Kısa Özet
Bu revizyonla plan, Faz 1 kapsamına sadık kalacak şekilde netleştirildi: app içi import yok, Supabase Dashboard CSV import var, Flutter yalnızca okuma/öğrenme/test/progress yapıyor. Revizyonda tek-pack kuralı, anonymous auth, 10k ölçek için pagination/lazy loading, matching UX, empty/loading/error durumları ve Faz 2’ye açık repository tasarımı karar-tam hale getirildi.

## Değerlendirme Sonucu (İstenen Maddelere Karşılık)
1. Pack yönetimi talebi uygun bulundu ve varsayılan strateji tek-pack olarak kesinleştirildi.
2. DEMO_USER_UUID yerine Anonymous Auth talebi uygun bulundu ve prod varsayılanı olarak benimsendi.
3. Atomic update talebi uygun bulundu; senin seçimine göre RPC Faz 1’de opsiyonel bırakıldı, risk notu + retry stratejisi planlandı.
4. Raw split sonrası boş chip alanlarını gizleme talebi uygun bulundu ve UI kuralı eklendi.
5. 10k+ ölçek için pagination/lazy loading talebi uygun bulundu ve repository sözleşmesine işlendi.
6. Matching için tıklamalı eşleştirme ve Typing exact-match talebi uygun bulundu.
7. Empty/loading/error state talebi uygun bulundu ve ekran bazlı UX davranışları netleştirildi.
8. Faz 2 genişleme için pack-only isimlendirme kilidini azaltma talebi uygun bulundu.

## Kesin Kararlar (v2)
1. Pack stratejisi: Faz 1 default “Master Pack” modelidir; `packs` tablosunda `YDS Set 001` seed edilir, CSV import sonrası `pack_id` NULL kayıtlar tek SQL ile bu pack’e bağlanır.
2. PackList davranışı: Faz 1’de PackListPage her zaman gösterilir; tek pack varsa listede sadece tek kart görünür, kullanıcı o karttan devam eder.
3. Alternatif yol notu: CSV’ye `pack_id` eklenebiliyorsa bu tercihli/geleceğe hazır yol olarak dokümana eklenir; ancak Faz 1 default’u tek-pack kalır.
4. Auth stratejisi: Uygulama ilk açılışta `Anonymous Sign-In` yapar; `user_word_progress.user_id = auth.uid()` kullanılır.
5. DEMO_USER_UUID kullanımı: Sadece debug/dev fallback; prod senaryoda kapalı.
6. RLS: `user_word_progress` için yalnızca `user_id = auth.uid()`; `packs/words` okuma Faz 1’de anon read açık kalır.
7. Progress update: RPC opsiyonel; default akış client-side serialized upsert + retry/backoff + risk notudur.
8. Pagination: WordList için `limit/offset` (default `limit=50`) + infinite scroll; full-pack preload yok.
9. Session memory: Flashcard ve test oturumları tüm kelimeleri RAM’e almaz; pencere/pool bazlı veri çeker.
10. Matching UX: Drag-drop yok; tıklamalı eşleştirme varsayılan.
11. Typing UX: Exact match + normalize (lowercase + trim + multi-space collapse); typo tolerance Faz 2+ notu olarak saklanır.
12. Empty/loading/error state: ekran bazlı zorunlu UX kuralı olarak eklendi.

## Uygulama Planı (Dosya ve İçerik Düzeyi)
1. `Faz 1 MVP Planı_v1.md` revize edilip v2 kararlarıyla güncellenecek; özellikle “Kilitlenen Kararlar”, “RLS/Auth”, “Repository Arayüzleri”, “Test Planı”, “UX States” bölümleri değiştirilecek.
2. `docs/supabase_csv_import.md` eklenecek; semicolon delimiter, quote char, header-map, pack bağlama SQL, örnek CSV ve data quality kuralları birebir yazılacak.
3. `supabase/migrations/20260225_001_phase1_schema.sql` eklenecek; Faz 1 şema + indeks + RLS + policy içerecek.
4. `supabase/migrations/20260225_002_progress_rpc_optional.sql` opsiyonel eklenecek; RPC taslağı burada tutulacak.
5. Flutter tarafında repository sözleşmeleri pagination ve source-agnostic modele göre güncellenecek; UI/feature planı bu sözleşmeleri kullanacak.

## Supabase SQL Migration Kapsamı
1. Tablolar: `packs`, `words`, `user_word_progress`.
2. `words` kolonları Faz 1 revize modeliyle kalır: `synonyms_raw`, `antonyms_raw`, `tags_raw` alanları `text`.
3. `words.pack_id` nullable kalır; default senaryoda import sonrası tek SQL ile set edilir.
4. Kısıtlar: `UNIQUE(pack_id, en_word, pos)`, `mastery` 0..100 check, `last_answer` değer seti check.
5. İndeksler: `words(pack_id)`, `words(pack_id,pos)`, `words(pack_id,en_word)`, `user_word_progress(user_id)`.
6. RLS: `packs/words` select açık; `user_word_progress` select/insert/update yalnız `auth.uid()` satırları.
7. Seed/bağlama adımı: `packs` içine `YDS Set 001` ekleme ve `UPDATE words SET pack_id='<PACK_UUID>' WHERE pack_id IS NULL;`.

## Opsiyonel RPC Taslağı (Atomic Update İçin)
1. Fonksiyon adı: `apply_flashcard_result(p_word_id uuid, p_answer text)`; DB tarafında `seen_count`, `last_seen_at`, `last_answer`, `mastery clamp` atomik günceller.
2. Fonksiyon adı: `apply_test_result(p_word_id uuid, p_is_correct boolean)`; `correct_count/wrong_count`, `mastery +/-10 clamp`, `seen_count`, `last_seen_at`, `last_answer` atomik günceller.
3. Güvenlik: Fonksiyon içinde `auth.uid()` zorunlu kontrolü; null ise hata.
4. Faz 1 default: RPC deploy edilmezse client fallback kullanılır; bu durumda cross-device race riski kabul edilip dokümana açıkça yazılır.

## Flutter Mimari ve Public API/Type Revizyonları
1. `WordSource` tipi eklenecek; Faz 1’de `pack` kaynağı kullanır, Faz 2’de `reading` kaynağı eklenebilir.
2. `WordQuery` tipi eklenecek; alanlar: `search`, `pos`, `tag`, `limit`, `offset`.
3. `PagedResult<T>` tipi eklenecek; alanlar: `items`, `nextOffset`, `hasMore`, `totalCount?`.
4. `WordRepository` sözleşmesi `getWordsByPack` yerine `getWordsBySource(WordSource source, WordQuery query)` modeline taşınacak.
5. `ProgressRepository` sözleşmesi `userId` parametresiz çalışacak; user kimliği Auth session’dan alınacak.
6. `AuthSessionService.ensureAnonymousSession()` akışı eklenecek; app startup’ta tek giriş noktası olacak.
7. `CsvRawParser` helper kuralları: split `;`, trim, empty-drop; boş sonuçta ilgili chip bölümü render edilmez.

## Ekran ve UX Davranışları (Faz 1 Zorunlu)
1. PackListPage: Tek-pack senaryosunda 1 kart görünür; pack yoksa “Henüz paket yok” metni ve “Kurulum dokümanına git” CTA gösterilir.
2. PackDetailPage: Flashcard/Test/Kelime Listesi girişleri; loading ve error durumunda retry aksiyonu bulunur.
3. WordListPage: Sunucu tarafı paginated fetch + infinite scroll; sonuç yoksa “Sonuç bulunamadı”.
4. WordDetailPage: synonyms/antonyms/tags yalnız doluysa chip alanı render edilir.
5. FlashcardSessionPage: Oturum sonu mini özet zorunlu; `known/unsure/unknown` sayıları ve “Tekrar Et” + “Teste Git” CTA gösterilir.
6. TestHub ve test ekranları: Supabase hata durumlarında Snackbar/Dialog + Retry.
7. Matching: Kullanıcı sol sütundan kelime seçer, sonra sağdan anlam seçer; doğruysa kilitlenir, yanlışsa kısa hata geri bildirimi verilir.
8. Typing: normalize edilmiş exact match; typo tolerance bu fazda yok.

## Performans ve Ölçek Kuralları (10k+ Hazır)
1. WordList default sayfa boyutu `50`; scroll eşiğinde bir sonraki sayfa çekilir.
2. Aynı anda bellekte maksimum sınırlı sayfa tutulur; eski sayfalar bırakılır.
3. Flashcard session başlangıçta sınırlı pencere (`50`) çeker, kalan azaldıkça prefetch yapar.
4. Test üretimi sınırlı aday havuzla çalışır (`50-200` arası konfigüre edilebilir); tüm pack’i RAM’e almaz.
5. MCQ distractor önceliği aynı `pos`; yetmezse pack geneli; seçenek tekrarları engellenir.
6. Tag filtre Faz 1’de `tags_raw` üzerinden basit filtreyle çalışır; tam doğruluk/performans iyileştirmesi Faz 2’de `text[] + index` dönüşümüne bırakılır.

## CSV Dokümantasyonu İçeriği (docs/supabase_csv_import.md)
1. Import ayarları birebir: Delimiter `;`, Quote char `"`, First row header açık, Encoding UTF-8.
2. Mapping tablosu birebir: `synonyms -> synonyms_raw`, `antonyms -> antonyms_raw`, `tags -> tags_raw`.
3. Örnek CSV satırları birebir eklenecek:
`en_word;tr_meaning;pos;example_en;example_tr;synonyms;antonyms;level;tags;notes`
`abandon;terk etmek;verb;He abandoned the plan.;Planı terk etti.;"leave; desert";"keep; continue";B2;;`
`ability;yetenek;noun;She has the ability to sing.;Şarkı söyleme yeteneği var.;"capability; talent";inability;B1;;`
`abroad;yurt dışı;adv;He lives abroad.;Yurt dışında yaşıyor.;overseas;locally;A2;;`
`absent;mevcut olmayan;adj;He was absent from school.;Okulda yoktu.;"missing; away";present;B1;;`
4. Data quality kuralları net yazılacak: alan içinde `;` varsa çift tırnak zorunlu; alan içinde `"` varsa CSV escape (`""`) zorunlu.
5. `pack_id` olmayan CSV için post-import SQL adımı zorunlu checklist olarak yazılacak.

## Test ve Kabul Senaryoları
1. Unit test: raw split/trim/empty-drop; mastery clamp; typing normalize; MCQ distractor same-pos öncelik.
2. Unit test: pagination state (`hasMore`, `nextOffset`) ve infinite-scroll tetik eşiği.
3. Unit test: progress fallback retry/backoff ve failure state yönetimi.
4. Integration test: anonymous sign-in sonrası `auth.uid()` ile progress yazımı.
5. Integration test: 200 satır import sonrası tek pack altında 200 kelime görünmesi.
6. Integration test: chip alanlarının boşken gizlenmesi, doluyken doğru parse edilmesi.
7. Integration test: Matching tıklamalı eşleştirme akışı; Typing exact-match davranışı.
8. Scale smoke test: 10k veri ile WordList sayfalı yükleme ve scroll’da stabilite; full preload yapılmadığının doğrulanması.
9. Error UX test: Supabase hata anında Retry görünümü ve başarılı tekrar denemesi.
10. Kabul kriteri: Faz 1 feature seti uçtan uca çalışır; app içi import yoktur; progress yazımı kullanıcı bazında ayrışır.

## Varsayımlar ve Varsayılanlar
1. Faz 1 prod varsayılanı anonymous auth açıktır; `DEMO_USER_UUID` yalnız debug fallback’tir.
2. `packs/words` select anonim açık bırakılır; güvenlik sıkılaştırması Faz 2’de opsiyonel geçirilebilir.
3. RPC bu fazda opsiyoneldir; deploy edilmezse fallback stratejisi ve risk notu zorunlu dokümante edilir.
4. CSV delimiter `;` ve header biçimi sabittir.
5. Faz 1 scope dışı işler yapılmaz: app içi import/upload, Edge Function zorunluluğu, PDF/Word işleme, gelişmiş typo tolerance, advanced analytics.
