# Veritabanı Şeması

Bu doküman, `7 Mart 2026` itibarıyla depo içi statik analizden çıkarılmıştır.

Kaynaklar:
- `supabase/migrations/*.sql`
- `lib/data/local/*.dart`
- `lib/data/repositories/*.dart`
- `lib/data/remote/*.dart`
- `assets/db/app_content.db`
- `assets/db/dictionary_local.sqlite`

Notlar:
- Buradaki "kullanılmayan" tespiti, repo içinde yapılan statik aramaya dayanır. Canlı sistemde sadece admin/import amaçlı kullanılan alanlar ayrıca mevcut olabilir.
- Doküman hem uzak `Supabase/PostgreSQL` şemasını hem de yerel `SQLite` dosyalarını kapsar.
- Yerel `app_content.db` fiziksel dosyasında, uygulamanın aktif olarak kullanmadığı ek sözlük tabloları da bulunmaktadır. Bunlar ayrıca işaretlenmiştir.

## 1. Veritabanı katmanları

| Katman | Fiziksel konum / sistem | Amaç |
|---|---|---|
| Uzak ana veritabanı | Supabase PostgreSQL | Uygulamanın esas içerik ve kullanıcı ilerleme verisi |
| Yerel statik içerik DB | `assets/db/app_content.db` | Paket, kelime, okuma, gramer içeriklerinin cihaz/web önbelleği |
| Yerel sözlük DB | `assets/db/dictionary_local.sqlite` | Yerel sözlük araması ve fallback cache |

## 2. Supabase PostgreSQL şeması

### 2.1 İçerik tabloları

#### `public.packs`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | Paket kimliği |
| `name` | `text` | `not null` | Paket adı |
| `from_lang` | `text` | `not null`, default `'en'` | Kaynak dil |
| `to_lang` | `text` | `not null`, default `'tr'` | Hedef dil |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |

Kullanım:
- Paket listesi
- Paket detay
- Flashcard ve kelime oturumu giriş noktası

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`

#### `public.words`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | Kelime kimliği |
| `pack_id` | `uuid` | FK -> `packs.id`, `on delete cascade` | Pakete bağlı kelime |
| `en_word` | `text` | `not null` | İngilizce kelime/phrase |
| `tr_meaning` | `text` | `not null` | Türkçe anlam |
| `pos` | `text` | `not null`, `words_pos_check` | Kelime türü |
| `example_en` | `text` | `not null` | İngilizce örnek |
| `example_tr` | `text` | nullable | Türkçe örnek |
| `synonyms_raw` | `text` | nullable | Ham eş anlamlı listesi |
| `antonyms_raw` | `text` | nullable | Ham zıt anlamlı listesi |
| `level` | `text` | nullable | CEFR/YDS seviyesi |
| `tags_raw` | `text` | nullable | Ham etiket listesi |
| `notes` | `text` | nullable | İçerik notu |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |
| `pos_raw` | `text` | nullable | `202603040007` ile eklendi |

Kullanım:
- Kelime listesi
- Arama
- Flashcard / test oturumları
- Okuma ekranındaki odak kelime ilişkileri

Önemli not:
- `202603040010_fix_words_pos_regex.sql` sonrası `pos` kısıtı eski sabit enum yerine regex tabanlı hale getirildi. Beklenen değerler artık `prep.`, `phr. v.`, `v.`, `n.`, `adj.`, `adv.`, `NP`, `conj.`, `det.`, `modal` gibi token'lar olabilir.

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`
- `pos_raw`

#### `public.reading_passages`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | Parça kimliği |
| `pack_id` | `uuid` | FK -> `packs.id`, `on delete cascade` | Hangi pakete bağlı |
| `pack_name` | `text` | nullable | CSV/import yardımcı kolonu |
| `title` | `text` | `not null` | Parça başlığı |
| `level` | `text` | nullable | Seviye |
| `tags_raw` | `text` | nullable | Ham etiket listesi |
| `category` | `text` | nullable | `202603040007` ile eklendi |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |

Kullanım:
- Okuma liste ekranı
- Ana sayfa reading feed
- Okuma detay meta alanı

Kaldırılmış kolon:
- `source_url` -> `202603040007_static_content_alignment.sql` ile düşürüldü

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`

#### `public.reading_passage_sentences`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | Cümle kimliği |
| `passage_id` | `uuid` | FK -> `reading_passages.id`, `on delete cascade` | Bağlı parça |
| `passage_title` | `text` | nullable | CSV/import yardımcı kolonu |
| `idx` | `int` | `not null`, `check (idx > 0)`, `unique (passage_id, idx)` | Cümle sırası |
| `sentence_en` | `text` | `not null` | İngilizce cümle |
| `sentence_tr` | `text` | nullable | Türkçe çeviri |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |

Kullanım:
- Okuma detay cümle listesi
- Çeviri popup / side panel

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`

#### `public.reading_passage_words`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `passage_id` | `uuid` | PK parçası, FK -> `reading_passages.id`, `on delete cascade` | Parça |
| `word_id` | `uuid` | PK parçası, FK -> `words.id`, `on delete cascade` | Bağlı kelime |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |

Kullanım:
- Okuma detay "odak kelimeler" ilişkisi
- Kelime setini doğrudan parça ile eşleme

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`

#### `public.reading_sentence_translations`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | Çeviri kaydı |
| `sentence_id` | `uuid` | FK -> `reading_passage_sentences.id`, `on delete cascade` | Bağlı cümle |
| `provider` | `text` | `not null` | Çeviri sağlayıcısı |
| `target_lang` | `text` | `not null`, default `'tr'` | Hedef dil |
| `translated_text` | `text` | `not null` | Üretilmiş çeviri |
| `created_at` | `timestamptz` | `not null`, default `now()` | Kayıt zamanı |

Tekillik:
- `unique (sentence_id, provider, target_lang)`

Kullanım:
- Okuma ekranında cache'lenmiş cümle çevirisi

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`

#### `public.gramer_modulleri`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `bigserial` | PK | Modül kimliği |
| `sira` | `integer` | `not null` | Listeleme sırası |
| `baslik` | `text` | `not null` | Modül başlığı |
| `dosya_adi` | `text` | `not null` | Kaynak markdown/html dosya adı |
| `toplam_sayfa` | `integer` | `not null`, default `0` | Sayfa sayısı |
| `icon` | `text` | `not null`, default `'📘'` | Simge |
| `renk` | `text` | `not null`, default `'#4776E6'` | Renk |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |

Kullanım:
- Gramer ana sayfası
- Son kaldığın yer

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`

#### `public.gramer_sayfalari`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `bigserial` | PK | Sayfa kimliği |
| `modul_id` | `bigint` | FK -> `gramer_modulleri.id`, `on delete cascade` | Bağlı modül |
| `sayfa_no` | `integer` | `not null`, `unique (modul_id, sayfa_no)` | Sıra numarası |
| `baslik` | `text` | `not null` | Sayfa başlığı |
| `icerik_html` | `text` | `not null` | Gövde HTML içeriği |
| `kelime_sayisi` | `integer` | `not null`, default `0` | Sayfa kelime sayısı |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |

Kullanım:
- Gramer sayfa listesi
- Gramer reader

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`

#### `public.gramer_ornekler`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `bigserial` | PK | Örnek kimliği |
| `sayfa_id` | `bigint` | FK -> `gramer_sayfalari.id`, `on delete cascade` | Bağlı sayfa |
| `sira` | `integer` | `not null`, default `0`, `unique (sayfa_id, sira)` | Örnek sırası |
| `ingilizce` | `text` | `not null` | İngilizce örnek |
| `turkce` | `text` | `not null` | Türkçe örnek |
| `aciklama` | `text` | nullable | Açıklama |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |

Kullanım:
- Gramer reader örnek blokları

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`

#### `public.gramer_testler`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `bigserial` | PK | Mini test kimliği |
| `sayfa_id` | `bigint` | FK -> `gramer_sayfalari.id`, `on delete cascade` | Bağlı sayfa |
| `sira` | `integer` | `not null`, default `0`, `unique (sayfa_id, sira)` | Sıra |
| `soru` | `text` | `not null` | Soru |
| `secenekler_json` | `jsonb` | `not null`, default `'{}'::jsonb` | Seçenekler |
| `dogru_cevap` | `text` | nullable | Doğru cevap |
| `aciklama` | `text` | nullable | Açıklama |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |

Kullanım:
- Gramer mini test bölümü

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`

### 2.2 Kullanıcı ilerleme tabloları

#### `public.user_word_progress`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `user_id` | `uuid` | PK parçası | Kullanıcı |
| `word_id` | `uuid` | PK parçası, FK -> `words.id`, `on delete cascade` | Kelime |
| `mastery` | `int` | `not null`, default `0`, `check 0..100` | Ustalık puanı |
| `seen_count` | `int` | `not null`, default `0` | Görülme sayısı |
| `correct_count` | `int` | `not null`, default `0` | Doğru sayısı |
| `wrong_count` | `int` | `not null`, default `0` | Yanlış sayısı |
| `last_seen_at` | `timestamptz` | nullable | Son etkileşim |
| `last_answer` | `text` | nullable, `known/unsure/unknown` | Son cevap |
| `created_at` | `timestamptz` | `not null`, default `now()` | İlk kayıt zamanı |
| `updated_at` | `timestamptz` | `not null`, default `now()` | Trigger ile güncellenir |

Kullanım:
- Flashcard sonucu
- Test sonucu
- Seviye merkezi, metrikler, odak kelime hesapları

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`
- `updated_at`

#### `public.user_reading_progress`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `user_id` | `uuid` | PK parçası | Kullanıcı |
| `passage_id` | `uuid` | PK parçası, FK -> `reading_passages.id`, `on delete cascade` | Parça |
| `completed` | `boolean` | `not null`, default `false` | Tamamlandı mı |
| `last_idx` | `int` | `not null`, default `0`, `check >= 0` | Son okunan cümle |
| `last_seen_at` | `timestamptz` | nullable | Son görülme zamanı |
| `created_at` | `timestamptz` | `not null`, default `now()` | İlk kayıt zamanı |
| `updated_at` | `timestamptz` | `not null`, default `now()` | Trigger ile güncellenir |

Kullanım:
- Okumaya devam et
- Tamamlanan parça sayısı
- Parça ilerleme çubuğu

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`
- `updated_at`

#### `public.user_reading_bookmarks`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `user_id` | `uuid` | PK parçası | Kullanıcı |
| `passage_id` | `uuid` | PK parçası, FK -> `reading_passages.id`, `on delete cascade` | İşaretlenen parça |
| `created_at` | `timestamptz` | `not null`, default `now()` | Sıralama / kayıt zamanı |

Kullanım:
- Okuma kütüphanesi / yer imi listesi

#### `public.user_reading_favorites`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `user_id` | `uuid` | PK parçası | Kullanıcı |
| `passage_id` | `uuid` | PK parçası, FK -> `reading_passages.id`, `on delete cascade` | Favori parça |
| `created_at` | `timestamptz` | `not null`, default `now()` | Sıralama / kayıt zamanı |

Kullanım:
- Favori parça listesi

### 2.3 Sözlük ve cache tabloları

#### `public.dictionary_import_batches`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | Import batch kimliği |
| `dataset_version` | `text` | `not null` | Dataset sürümü |
| `source_file` | `text` | nullable | Kaynak dosya |
| `source_checksum` | `text` | nullable | Checksum |
| `status` | `text` | `not null`, default `'running'`, `running/completed/failed` | Batch durumu |
| `total_rows_read` | `integer` | `not null`, default `0` | Okunan satır |
| `inserted_rows` | `integer` | `not null`, default `0` | Eklenen satır |
| `updated_rows` | `integer` | `not null`, default `0` | Güncellenen satır |
| `duplicate_rows` | `integer` | `not null`, default `0` | Tekrar satır |
| `invalid_rows` | `integer` | `not null`, default `0` | Geçersiz satır |
| `empty_meaning_rows` | `integer` | `not null`, default `0` | Boş anlam satırı |
| `started_at` | `timestamptz` | `not null`, default `now()` | Başlangıç |
| `completed_at` | `timestamptz` | nullable | Bitiş |
| `metadata` | `jsonb` | `not null`, default `'{}'::jsonb` | Import meta |

Kullanım:
- Uygulama tarafından doğrudan tablo sorgusu yapılmıyor
- `dictionary_bootstrap_manifest()` RPC'si bu tabloyu dolaylı kullanıyor

Durum:
- Tamamen "ölü" değil
- Doğrudan UI/runtime tablosu değil, daha çok operasyonel/import tablosu

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `source_file`
- `source_checksum`
- `metadata`

#### `public.dictionary_entries`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | Giriş kimliği |
| `seq_id` | `bigint` | identity | Bootstrap sıralama alanı |
| `en_word` | `text` | `not null` | İngilizce kelime |
| `en_word_normalized` | `text` | `not null` | Normalize arama alanı |
| `search_key` | `text` | `not null` | Geniş arama anahtarı |
| `pos` | `text` | nullable | POS |
| `raw_pos` | `text` | nullable | Ham POS |
| `tr_meaning` | `text` | `not null` | Türkçe anlam |
| `meaning_short` | `text` | nullable | Kısa anlam |
| `source` | `text` | `not null`, default `'excel_import'` | Kaynak |
| `is_active` | `boolean` | `not null`, default `true` | Aktif mi |
| `import_batch_id` | `uuid` | FK -> `dictionary_import_batches.id`, `on delete set null` | Kaynak batch |
| `hash` | `text` | `not null` | İçerik hash'i |
| `metadata` | `jsonb` | `not null`, default `'{}'::jsonb` | Esnek meta |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |
| `updated_at` | `timestamptz` | `not null`, default `now()` | Trigger ile güncellenir |

Kullanım:
- Uzak sözlük lookup
- Yerel sözlük bootstrap kaynağı

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `raw_pos`
- `meaning_short`
- `import_batch_id`
- `hash`
- `metadata`
- `created_at`

#### `public.dictionary_fallback_cache`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | Cache satırı |
| `query_text` | `text` | `not null` | Orijinal sorgu |
| `query_normalized` | `text` | `not null` | Normalize sorgu |
| `source_lang` | `text` | `not null`, default `'en'` | Kaynak dil |
| `target_lang` | `text` | `not null`, default `'tr'` | Hedef dil |
| `provider` | `text` | `not null`, default `'deepl_edge_function'` | Sağlayıcı |
| `translated_text` | `text` | `not null` | Fallback çeviri |
| `hit_count` | `integer` | `not null`, default `1`, `check >= 1` | Kullanım sayısı |
| `last_hit_at` | `timestamptz` | `not null`, default `now()` | Son kullanım |
| `metadata` | `jsonb` | `not null`, default `'{}'::jsonb` | Ek meta |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |
| `updated_at` | `timestamptz` | `not null`, default `now()` | Trigger ile güncellenir |

Tekillik:
- `unique (query_normalized, source_lang, target_lang, provider)`

Kullanım:
- Sözlükte eşleşme bulunamazsa çeviri sonucu cache'i

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `metadata`
- `created_at`

#### `public.dictionary_missing_queries`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | Kayıt kimliği |
| `query_text` | `text` | `not null` | Orijinal sorgu |
| `query_normalized` | `text` | `not null` | Normalize sorgu |
| `source_lang` | `text` | `not null`, default `'en'` | Kaynak dil |
| `target_lang` | `text` | `not null`, default `'tr'` | Hedef dil |
| `occurrence_count` | `integer` | `not null`, default `1`, `check >= 1` | Tekrar sayısı |
| `first_seen_at` | `timestamptz` | `not null`, default `now()` | İlk görülme |
| `last_seen_at` | `timestamptz` | `not null`, default `now()` | Son görülme |
| `metadata` | `jsonb` | `not null`, default `'{}'::jsonb` | Ek meta |
| `created_at` | `timestamptz` | `not null`, default `now()` | Oluşturulma zamanı |
| `updated_at` | `timestamptz` | `not null`, default `now()` | Trigger ile güncellenir |

Tekillik:
- `unique (query_normalized, source_lang, target_lang)`

Kullanım:
- Uzak sözlükte bulunamayan sorguların izlenmesi

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `metadata`
- `created_at`
- `updated_at`

## 3. Supabase RPC / fonksiyonlar

| Fonksiyon | Dönen değer | Amaç |
|---|---|---|
| `set_updated_at()` | `trigger` | `updated_at` kolonlarını otomatik günceller |
| `apply_flashcard_result(p_word_id uuid, p_answer text)` | `void` | Flashcard sonucunu `user_word_progress` üzerine işler |
| `apply_test_result(p_word_id uuid, p_is_correct boolean)` | `void` | Test sonucunu `user_word_progress` üzerine işler |
| `dictionary_bootstrap_manifest()` | `table(dataset_version, batch_id, row_count, generated_at)` | Yerel sözlük bootstrap manifest'i |
| `dictionary_entries_bootstrap_page(p_after_seq_id bigint, p_limit integer)` | `table(...)` | Sözlük satırlarını sayfalı bootstrap eder |
| `get_packs_with_word_count()` | `table(id, name, from_lang, to_lang, word_count)` | Paket + kelime sayısı özet sorgusu |
| `get_word_level_counts()` | `table(level, word_count)` | Seviye bazlı toplam kelime sayısı |
| `get_studied_word_counts_by_level(p_levels text[])` | `table(level, studied_word_count)` | Seviye bazlı çalışılmış kelime sayısı |
| `admin_reset_static_content()` | `jsonb` | Yalnız admin/service role için statik içerik temizleme |

## 4. Yerel `app_content.db` şeması

Bu dosya, uygulamanın yerel statik içerik deposudur. Kod tarafından aktif kullanılan mantıksal tablolar aşağıdadır.

### 4.1 Aktif kullanılan mantıksal tablolar

#### `meta`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `key` | `TEXT` | PK | Meta anahtarı |
| `value` | `TEXT` | `not null` | Meta değeri |

Kullanım:
- `dataset_version`
- `generated_at`
- içerik üretim meta bilgileri

#### `packs`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `TEXT` | PK | Paket kimliği |
| `name` | `TEXT` | `not null` | Paket adı |
| `from_lang` | `TEXT` | `not null` | Kaynak dil |
| `to_lang` | `TEXT` | `not null` | Hedef dil |

İndeksler:
- `ix_packs_name` unique

#### `words`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `TEXT` | PK | Kelime kimliği |
| `pack_id` | `TEXT` | `not null` | Paket |
| `en_word` | `TEXT` | `not null` | İngilizce kelime |
| `tr_meaning` | `TEXT` | `not null` | Türkçe anlam |
| `pos` | `TEXT` | `not null` | Kelime türü |
| `pos_raw` | `TEXT` | nullable | Ham POS |
| `example_en` | `TEXT` | `not null` | Örnek |
| `example_tr` | `TEXT` | nullable | Türkçe örnek |
| `synonyms_raw` | `TEXT` | nullable | Eş anlamlı |
| `antonyms_raw` | `TEXT` | nullable | Zıt anlamlı |
| `level` | `TEXT` | nullable | Seviye |
| `tags_raw` | `TEXT` | nullable | Etiketler |
| `notes` | `TEXT` | nullable | Not |
| `en_word_normalized` | `TEXT` | `not null` | Normalize arama |
| `search_key` | `TEXT` | `not null` | Geniş arama anahtarı |
| `created_at` | `INTEGER` | `not null` | Epoch zaman |

İndeksler:
- `ix_words_pack_id`
- `ix_words_pack_en`
- `ix_words_pack_pos`
- `ix_words_en_normalized`
- `ix_words_search_key`

Not:
- Yerel `words` tablosu, uzak `public.words` tablosundan daha zengindir. `en_word_normalized` ve `search_key` yalnız yerel aramayı hızlandırmak için bulunmaktadır.

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `pos_raw`
- `created_at`

#### `reading_passages`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `TEXT` | PK | Parça kimliği |
| `pack_id` | `TEXT` | nullable | Paket kimliği |
| `pack_name` | `TEXT` | nullable | Paket adı |
| `title` | `TEXT` | `not null` | Başlık |
| `level` | `TEXT` | nullable | Seviye |
| `tags_raw` | `TEXT` | nullable | Etiketler |
| `category` | `TEXT` | nullable | Kategori |
| `created_at` | `INTEGER` | `not null` | Epoch zaman |

İndeksler:
- `ix_reading_passages_pack_id`
- `ix_reading_passages_title`
- `ix_reading_passages_category`

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`

#### `reading_sentences`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `TEXT` | PK | Cümle kimliği |
| `passage_id` | `TEXT` | `not null` | Parça kimliği |
| `passage_title` | `TEXT` | `not null` | Parça başlığı |
| `idx` | `INTEGER` | `not null` | Cümle sırası |
| `sentence_en` | `TEXT` | `not null` | İngilizce cümle |
| `sentence_tr` | `TEXT` | nullable | Türkçe cümle |
| `created_at` | `INTEGER` | `not null` | Epoch zaman |

İndeksler:
- `ix_reading_sentences_passage_idx`
- `unique(passage_id, idx)`

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `created_at`

#### `grammar_modules`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `INTEGER` | PK | Yerel modül kimliği |
| `source_module_id` | `INTEGER` | nullable | Uzak kaynak id eşlemesi |
| `sira` | `INTEGER` | `not null` | Sıra |
| `baslik` | `TEXT` | `not null` | Başlık |
| `dosya_adi` | `TEXT` | `not null` | Dosya adı |
| `toplam_sayfa` | `INTEGER` | `not null`, default `0` | Sayfa sayısı |
| `icon` | `TEXT` | `not null`, default `'📘'` | İkon |
| `renk` | `TEXT` | `not null`, default `'#4776E6'` | Renk |
| `updated_at` | `INTEGER` | `not null` | Son güncelleme |

İndeksler:
- `ix_grammar_modules_sira` unique

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `source_module_id`
- `updated_at`

#### `grammar_pages`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `INTEGER` | PK | Sayfa kimliği |
| `module_id` | `INTEGER` | `not null` | Modül kimliği |
| `source_page_id` | `INTEGER` | nullable | Uzak kaynak id eşlemesi |
| `sayfa_no` | `INTEGER` | `not null` | Sıra |
| `baslik` | `TEXT` | `not null` | Başlık |
| `icerik_html` | `TEXT` | `not null` | HTML içerik |
| `kelime_sayisi` | `INTEGER` | `not null`, default `0` | Kelime sayısı |

İndeksler:
- `ix_grammar_pages_module_id`
- `unique(module_id, sayfa_no)`

Muhtemelen operasyonel / UI'da doğrudan kullanılmayan kolonlar:
- `source_page_id`

#### `grammar_examples`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `INTEGER` | PK | Örnek kimliği |
| `page_id` | `INTEGER` | `not null` | Sayfa |
| `sira` | `INTEGER` | `not null`, default `0` | Sıra |
| `ingilizce` | `TEXT` | `not null` | İngilizce örnek |
| `turkce` | `TEXT` | `not null` | Türkçe örnek |
| `aciklama` | `TEXT` | `not null`, default `''` | Açıklama |

#### `grammar_tests`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `INTEGER` | PK | Test kimliği |
| `page_id` | `INTEGER` | `not null` | Sayfa |
| `sira` | `INTEGER` | `not null`, default `0` | Sıra |
| `soru` | `TEXT` | `not null` | Soru |
| `secenekler_json` | `TEXT` | `not null`, default `'{}'` | JSON seçenekler |
| `dogru_cevap` | `TEXT` | `not null`, default `''` | Doğru cevap |
| `aciklama` | `TEXT` | `not null`, default `''` | Açıklama |

### 4.2 `app_content.db` içinde fiziksel olarak bulunan ama mevcut uygulamanın kullanmadığı tablolar

Bu tablolar `app_content.db` içinde fiziksel olarak var, ancak mevcut kod tabanı sözlük için ayrı `dictionary_local.sqlite` kullandığından bunlara doğrudan gitmiyor.

#### `dictionary_entries`

| Kolon | Tip | Not |
|---|---|---|
| `seq_id` | `INTEGER` | PK |
| `entry_id` | `TEXT` | unique giriş id |
| `en_word` | `TEXT` | İngilizce ifade |
| `en_word_normalized` | `TEXT` | Normalize arama alanı |
| `search_key` | `TEXT` | Arama anahtarı |
| `pos` | `TEXT` | POS |
| `tr_meaning` | `TEXT` | Türkçe anlam |
| `source` | `TEXT` | Kaynak |
| `updated_at` | `INTEGER` | Güncelleme zamanı |

#### `dictionary_entries_fts`

| Kolon | Tip | Not |
|---|---|---|
| `en_word` | virtual | FTS sanal kolon |
| `tr_meaning` | virtual | FTS sanal kolon |
| `pos` | virtual | FTS sanal kolon |
| `search_key` | virtual | FTS sanal kolon |

#### `dictionary_entries_fts_config`

Kolonlar:
- `k`
- `v`

#### `dictionary_entries_fts_content`

Kolonlar:
- `id`
- `c0`
- `c1`
- `c2`
- `c3`

#### `dictionary_entries_fts_data`

Kolonlar:
- `id`
- `block`

#### `dictionary_entries_fts_docsize`

Kolonlar:
- `id`
- `sz`

#### `dictionary_entries_fts_idx`

Kolonlar:
- `segid`
- `term`
- `pgno`

Durum:
- Bunlar ya eski sözlük kopyasıdır ya da FTS shadow table setidir.
- Mevcut uygulama akışında doğrudan kullanılmıyorlar.
- Temizleme yapılacaksa dikkatli yapılmalı; fiziksel asset üretim süreci ayrıca kontrol edilmeden silinmemeli.

## 5. Yerel `dictionary_local.sqlite` şeması

#### `local_dictionary_entries`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `seq_id` | `INTEGER` | PK | Sıralı bootstrap anahtarı |
| `entry_id` | `TEXT` | unique | Uzak giriş kimliği |
| `en_word` | `TEXT` | `not null` | İngilizce ifade |
| `en_word_normalized` | `TEXT` | `not null` | Normalize arama |
| `search_key` | `TEXT` | `not null` | Arama anahtarı |
| `pos` | `TEXT` | nullable | POS |
| `tr_meaning` | `TEXT` | `not null` | Türkçe anlam |
| `source` | `TEXT` | `not null` | Kaynak |
| `updated_at` | `INTEGER` | nullable | Epoch güncelleme zamanı |

İndeksler:
- `ix_local_dictionary_entry_id`
- `ix_local_dictionary_norm`
- `ix_local_dictionary_search_key`

#### `local_dictionary_fallback_cache`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `query_normalized` | `TEXT` | PK parçası | Normalize sorgu |
| `query_text` | `TEXT` | `not null` | Orijinal sorgu |
| `source_lang` | `TEXT` | PK parçası | Kaynak dil |
| `target_lang` | `TEXT` | PK parçası | Hedef dil |
| `provider` | `TEXT` | `not null` | Sağlayıcı |
| `translated_text` | `TEXT` | `not null` | Çeviri |
| `from_server_cache` | `INTEGER` | `not null`, default `0` | Sunucudan geldi mi |
| `hit_count` | `INTEGER` | `not null`, default `1` | Kullanım sayısı |
| `updated_at` | `INTEGER` | `not null` | Epoch güncelleme zamanı |

İndeksler:
- `ix_local_fallback_updated_at`

#### `local_dictionary_bootstrap_meta`

| Kolon | Tip | Kısıt | Not |
|---|---|---|---|
| `id` | `INTEGER` | PK | Tek satırlık durum kaydı |
| `dataset_version` | `TEXT` | `not null`, default `''` | Yüklü dataset sürümü |
| `batch_id` | `TEXT` | nullable | Uzak batch id |
| `row_count` | `INTEGER` | `not null`, default `0` | Toplam beklenen satır |
| `downloaded_count` | `INTEGER` | `not null`, default `0` | İndirilen satır |
| `last_seq_id` | `INTEGER` | `not null`, default `0` | Son bootstrap seq id |
| `status` | `TEXT` | `not null`, default `'idle'` | `idle/downloading/ready/error` benzeri durum |
| `error_message` | `TEXT` | nullable | Son hata |
| `updated_at` | `INTEGER` | `not null` | Epoch güncelleme zamanı |

## 6. Kullanılmayan veya yalnız operasyonel görünen yapılar

### 6.1 Tablolar

| Katman | Tablo | Durum | Gerekçe |
|---|---|---|---|
| Supabase | `dictionary_import_batches` | Doğrudan UI tablosu değil | Uygulama doğrudan bu tabloyu okumuyor; `dictionary_bootstrap_manifest()` dolaylı kullanıyor |
| `app_content.db` fiziksel dosya | `dictionary_entries` | Kullanılmıyor | Mevcut kod sözlük için ayrı `dictionary_local.sqlite` kullanıyor |
| `app_content.db` fiziksel dosya | `dictionary_entries_fts` | Kullanılmıyor | FTS sanal tablo, repo içinde referans yok |
| `app_content.db` fiziksel dosya | `dictionary_entries_fts_config` | Kullanılmıyor | FTS shadow table |
| `app_content.db` fiziksel dosya | `dictionary_entries_fts_content` | Kullanılmıyor | FTS shadow table |
| `app_content.db` fiziksel dosya | `dictionary_entries_fts_data` | Kullanılmıyor | FTS shadow table |
| `app_content.db` fiziksel dosya | `dictionary_entries_fts_docsize` | Kullanılmıyor | FTS shadow table |
| `app_content.db` fiziksel dosya | `dictionary_entries_fts_idx` | Kullanılmıyor | FTS shadow table |

### 6.2 Kolonlar

| Katman | Kolon | Durum | Gerekçe |
|---|---|---|---|
| Supabase | `packs.created_at` | operasyonel | UI/domain tarafında okunmuyor |
| Supabase | `words.pos_raw` | operasyonel | import/audit için tutuluyor, runtime mapping'de belirgin kullanım yok |
| Supabase | `words.created_at` | operasyonel | UI tarafında kullanılmıyor |
| Supabase | `reading_passage_words.created_at` | operasyonel | ilişki satırı için zaman damgası |
| Supabase | `reading_sentence_translations.created_at` | operasyonel | cache kayıt zamanı |
| Supabase | `user_word_progress.created_at` | operasyonel | ilk kayıt zamanı |
| Supabase | `user_word_progress.updated_at` | operasyonel | trigger ile yönetiliyor |
| Supabase | `user_reading_progress.created_at` | operasyonel | ilk kayıt zamanı |
| Supabase | `user_reading_progress.updated_at` | operasyonel | trigger ile yönetiliyor |
| Supabase | `gramer_modulleri.created_at` | operasyonel | UI'da kullanılmıyor |
| Supabase | `gramer_sayfalari.created_at` | operasyonel | UI'da kullanılmıyor |
| Supabase | `gramer_ornekler.created_at` | operasyonel | UI'da kullanılmıyor |
| Supabase | `gramer_testler.created_at` | operasyonel | UI'da kullanılmıyor |
| Supabase | `dictionary_import_batches.source_file` | operasyonel | import izleme |
| Supabase | `dictionary_import_batches.source_checksum` | operasyonel | import izleme |
| Supabase | `dictionary_import_batches.metadata` | operasyonel | import izleme |
| Supabase | `dictionary_entries.raw_pos` | muhtemelen kullanılmıyor | UI mapping'de referans görünmüyor |
| Supabase | `dictionary_entries.meaning_short` | muhtemelen kullanılmıyor | uygulama tam `tr_meaning` kullanıyor |
| Supabase | `dictionary_entries.import_batch_id` | operasyonel | import takibi |
| Supabase | `dictionary_entries.hash` | operasyonel | import/dedup mantığı |
| Supabase | `dictionary_entries.metadata` | operasyonel | esnek meta |
| Supabase | `dictionary_entries.created_at` | operasyonel | kayıt zamanı |
| Supabase | `dictionary_fallback_cache.metadata` | operasyonel | cache meta |
| Supabase | `dictionary_fallback_cache.created_at` | operasyonel | kayıt zamanı |
| Supabase | `dictionary_missing_queries.metadata` | operasyonel | eksik sorgu meta |
| Supabase | `dictionary_missing_queries.created_at` | operasyonel | kayıt zamanı |
| Supabase | `dictionary_missing_queries.updated_at` | operasyonel | sayaç güncelleme zamanı |
| `app_content.db` | `words.pos_raw` | operasyonel | raw POS |
| `app_content.db` | `words.created_at` | operasyonel | epoch timestamp |
| `app_content.db` | `reading_passages.created_at` | operasyonel | epoch timestamp |
| `app_content.db` | `reading_sentences.created_at` | operasyonel | epoch timestamp |
| `app_content.db` | `grammar_modules.source_module_id` | muhtemelen kullanılmıyor | kaynak eşlemesi |
| `app_content.db` | `grammar_modules.updated_at` | operasyonel | senkron güncelleme zamanı |
| `app_content.db` | `grammar_pages.source_page_id` | muhtemelen kullanılmıyor | kaynak eşlemesi |

## 7. Örnek veriler

Bu bölümde önce fiziksel SQLite dosyalarından alınmış gerçek örnekler, ardından yalnız uzak kullanıcı tabloları için temsili örnekler yer alır.

### 7.1 `app_content.db` içinden gerçek örnekler

#### `meta`

```json
[
  {"key": "dataset_version", "value": "20260305160340"},
  {"key": "generated_at", "value": "2026-03-05T16:04:14.439589+00:00"},
  {"key": "dictionary_sha256", "value": "e1f606d276dd7b4565bf0204536ad0c0c11421e609fbae8a917d367d1e4f5b68"}
]
```

#### `packs`

```json
{
  "id": "c048ce6c-98e8-5669-9254-72b3f23007ec",
  "name": "YDS Set 001",
  "from_lang": "en",
  "to_lang": "tr"
}
```

#### `words`

```json
{
  "id": "c80eac33-5549-52fd-b88e-f1fc620714b8",
  "pack_id": "c048ce6c-98e8-5669-9254-72b3f23007ec",
  "en_word": "a great deal of",
  "tr_meaning": "çok miktarda",
  "pos": "prep.",
  "pos_raw": "prep.",
  "example_en": "She has put a great deal of effort into preparing her presentation, so I am sure it will be a great success.",
  "example_tr": "Sunumunu hazırlamak için çok fazla çaba harcadı, bu yüzden büyük bir başarı olacağına eminim.",
  "synonyms_raw": "a large amount of; plenty of",
  "antonyms_raw": "a small amount of",
  "level": "B2",
  "tags_raw": "preposition; grammar",
  "notes": "Orta-üst seviye kelime. Akademik ve profesyonel bağlamlarda önemlidir.",
  "en_word_normalized": "a great deal of",
  "search_key": "a great deal of",
  "created_at": 1772726647
}
```

#### `reading_passages`

```json
{
  "id": "2274e790-7984-57d8-9517-3c2a82975cae",
  "pack_id": "c048ce6c-98e8-5669-9254-72b3f23007ec",
  "pack_name": "YDS Set 001",
  "title": "001-Amy's Restaurant (Amy'nin Restoranı)",
  "level": "A1",
  "tags_raw": "food; dining; prices",
  "category": "Food & Agriculture",
  "created_at": 1772726648
}
```

#### `reading_sentences`

```json
{
  "id": "648e7df2-15f9-5534-ae78-552472804bcf",
  "passage_id": "2274e790-7984-57d8-9517-3c2a82975cae",
  "passage_title": "001-Amy's Restaurant (Amy'nin Restoranı)",
  "idx": 1,
  "sentence_en": "Amy's Restaurant is a popular place for students to eat in Greenwich Village.",
  "sentence_tr": "Amy'nin Restoranı, Greenwich Village'de öğrencilerin yemek yemesi için popüler bir yerdir.",
  "created_at": 1772726648
}
```

#### `grammar_modules`

```json
{
  "id": 1,
  "source_module_id": null,
  "sira": 1,
  "baslik": "İngilizcede Temel Kavramlar",
  "dosya_adi": "01_temel_kavramlar.md",
  "toplam_sayfa": 16,
  "icon": "🔤",
  "renk": "#4776E6",
  "updated_at": 1772726654
}
```

#### `grammar_pages`

```json
{
  "id": 1001,
  "module_id": 1,
  "source_page_id": null,
  "sayfa_no": 1,
  "baslik": "Cümlenin Temel Unsurları",
  "kelime_sayisi": 206
}
```

#### `grammar_examples`

```json
{
  "id": 1001001,
  "page_id": 1001,
  "sira": 0,
  "ingilizce": "The boy runs.",
  "turkce": "Çocuk koşar. → Tek bir özne (the boy) ve tek bir fiil (runs) var. ### Örnek 2 (Nesneli cümle):",
  "aciklama": ""
}
```

#### `grammar_tests`

```json
{
  "id": 1001501,
  "page_id": 1001,
  "sira": 0,
  "soru": "Aşağıdaki cümlede kaç tane \"Noun Phrase\" vardır? \"The clever students in the large classroom are waiting for their teacher.\"",
  "secenekler_json": "{\"A\": \"2\", \"B\": \"3\", \"C\": \"4\", \"D\": \"5\"}",
  "dogru_cevap": "B) 3",
  "aciklama": "- NP1: \"The clever students\" (özne) - NP2: \"the large classroom\" (edat nesnesi) - NP3: \"their teacher\" (edat nesnesi) Toplam 3 Noun Phrase vardır."
}
```

### 7.2 `dictionary_local.sqlite` içinden gerçek örnekler

#### `local_dictionary_entries`

```json
{
  "seq_id": 1,
  "entry_id": "abc8c032c7dd6f52829902da5bca5804d3d0bdef4c62eefa308b01474548dbd6",
  "en_word": "a bad hat",
  "en_word_normalized": "a bad hat",
  "search_key": "a bad hat",
  "pos": "idiom",
  "tr_meaning": "ahlaksız tip, yavşak",
  "source": "excel_asset",
  "updated_at": 1772583478
}
```

#### `local_dictionary_bootstrap_meta`

```json
{
  "id": 1,
  "dataset_version": "2026-03-04-v1",
  "batch_id": null,
  "row_count": 121772,
  "downloaded_count": 121772,
  "last_seq_id": 121772,
  "status": "ready",
  "error_message": null,
  "updated_at": 1772583492
}
```

#### `local_dictionary_fallback_cache`

```json
[]
```

### 7.3 Yalnız uzak tablolar için temsili örnekler

#### `user_word_progress`

```json
{
  "user_id": "11111111-1111-1111-1111-111111111111",
  "word_id": "c80eac33-5549-52fd-b88e-f1fc620714b8",
  "mastery": 42,
  "seen_count": 5,
  "correct_count": 3,
  "wrong_count": 2,
  "last_seen_at": "2026-03-07T13:20:00Z",
  "last_answer": "unsure",
  "created_at": "2026-03-07T12:00:00Z",
  "updated_at": "2026-03-07T13:20:00Z"
}
```

#### `user_reading_progress`

```json
{
  "user_id": "11111111-1111-1111-1111-111111111111",
  "passage_id": "2274e790-7984-57d8-9517-3c2a82975cae",
  "completed": false,
  "last_idx": 2,
  "last_seen_at": "2026-03-07T13:25:00Z",
  "created_at": "2026-03-07T12:40:00Z",
  "updated_at": "2026-03-07T13:25:00Z"
}
```

#### `user_reading_bookmarks`

```json
{
  "user_id": "11111111-1111-1111-1111-111111111111",
  "passage_id": "2274e790-7984-57d8-9517-3c2a82975cae",
  "created_at": "2026-03-07T13:30:00Z"
}
```

#### `user_reading_favorites`

```json
{
  "user_id": "11111111-1111-1111-1111-111111111111",
  "passage_id": "2274e790-7984-57d8-9517-3c2a82975cae",
  "created_at": "2026-03-07T13:31:00Z"
}
```

#### `dictionary_import_batches`

```json
{
  "id": "22222222-2222-2222-2222-222222222222",
  "dataset_version": "2026-03-04-v1",
  "source_file": "dictionary.xlsx",
  "source_checksum": "sha256:example",
  "status": "completed",
  "total_rows_read": 121772,
  "inserted_rows": 121772,
  "updated_rows": 0,
  "duplicate_rows": 0,
  "invalid_rows": 0,
  "empty_meaning_rows": 0,
  "started_at": "2026-03-04T10:00:00Z",
  "completed_at": "2026-03-04T10:25:00Z",
  "metadata": {"source": "excel_import"}
}
```

#### `dictionary_fallback_cache`

```json
{
  "id": "33333333-3333-3333-3333-333333333333",
  "query_text": "clean up",
  "query_normalized": "clean up",
  "source_lang": "en",
  "target_lang": "tr",
  "provider": "deepl_edge_function",
  "translated_text": "temizlemek / toparlamak",
  "hit_count": 4,
  "last_hit_at": "2026-03-07T14:00:00Z",
  "metadata": {"reason": "dictionary_miss"},
  "created_at": "2026-03-07T12:00:00Z",
  "updated_at": "2026-03-07T14:00:00Z"
}
```

#### `dictionary_missing_queries`

```json
{
  "id": "44444444-4444-4444-4444-444444444444",
  "query_text": "long live life",
  "query_normalized": "long live life",
  "source_lang": "en",
  "target_lang": "tr",
  "occurrence_count": 2,
  "first_seen_at": "2026-03-07T11:00:00Z",
  "last_seen_at": "2026-03-07T14:05:00Z",
  "metadata": {"screen": "reading_detail"},
  "created_at": "2026-03-07T11:00:00Z",
  "updated_at": "2026-03-07T14:05:00Z"
}
```
