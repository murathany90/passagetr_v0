# Faz 1 MVP Planı: Supabase CSV Import Tabanlı İngilizce Kelime Öğrenme Uygulaması (Flutter)

## Kısa Özet
- Proje dizini şu an boşa yakın (`not1.md` dışında kaynak yok), bu nedenle Faz 1 sıfırdan kurulacak.
- Uygulama sadece öğrenme motoru olacak: pack/word okuma, flashcard, 3 test modu, progress yazımı.
- CSV import uygulama içinde olmayacak; yalnız Supabase Dashboard import akışı dokümante edilecek.
- Faz 2’ye hazırlık için mimari modüler olacak; reading modülü için genişleme noktaları şimdiden ayrılacak.

## Kilitlenen Kararlar
- Kimlik modeli: `Hybrid` (Auth varsa `auth.uid()`, yoksa sabit `DEMO_USER_UUID`).
- Güvenlik: `MVP RLS` (`packs/words` read açık, `user_word_progress` kontrollü).
- `pack_id` stratejisi: CSV’de yoksa tek pack + import sonrası toplu `UPDATE`.
- Test progress güncellemesi: Testte de `seen_count`, `last_seen_at`, `last_answer` güncellenecek.
- Küçük pack davranışı: Soru adedi dinamik azaltılacak (`min(target, pack_size)`).

## Kapsam
- Dahil: Android Flutter app, Supabase şema/migration, CSV import dokümanı, çalışan öğrenme/test/progress akışı.
- Hariç: App içi import/upload, Edge Function, PDF/Word işleme, Faz 2 reading implementasyonu.

## Uygulama Adımları (Karar-Tam)

## 1) Ön Koşul ve Kurulum
1. Flutter projesi oluşturulacak (Android hedefli).
2. Bağımlılıklar eklenecek: `supabase_flutter`, `flutter_riverpod`, `go_router` (veya Navigator 2.0 eşdeğeri), `freezed/json_serializable` (opsiyonel), `equatable` benzeri model yardımcıları.
3. Ortam değişkenleri: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `DEMO_USER_UUID`.
4. Not: Mevcut ortamda `flutter/dart/supabase` PATH’te görünmüyor; implementasyon öncesi SDK/CLI kurulumu tamamlanacak.

## 2) Flutter Dosya Yapısı
1. `lib/core`: config, constants, helpers (`splitRaw`, normalize).
2. `lib/domain`: entities (`Pack`, `WordItem`, `UserWordProgress`) ve repository arayüzleri.
3. `lib/data`: Supabase datasource + repository implementasyonları + DTO/mapper.
4. `lib/features/packs`: `PackListPage`, `PackDetailPage`.
5. `lib/features/words`: `WordListPage`, `WordDetailPage`, filtreleme.
6. `lib/features/flashcard`: `FlashcardSessionPage` + kart widgetları.
7. `lib/features/tests`: `TestHubPage`, `McqSessionPage`, `MatchingSessionPage`, `TypingSessionPage`.
8. `lib/features/readings` (placeholder): Faz 2 için boş modül iskeleti ve route rezervi.
9. `lib/app`: router, theme, app entry.

## 3) Supabase Şema ve Migration
1. Migration-1: `packs`, `words`, `user_word_progress` oluşturulacak.
2. `words` Faz 1 revize kolonları kullanılacak: `synonyms_raw`, `antonyms_raw`, `tags_raw` alanları `text`.
3. `words.pack_id` nullable bırakılacak (CSV’de pack_id yok senaryosu için).
4. `UNIQUE(pack_id, en_word, pos)` eklenecek.
5. `pos` için `CHECK` (allowed enum benzeri text seti) eklenecek.
6. `user_word_progress.mastery` için `CHECK (mastery between 0 and 100)`.
7. `last_answer` için `CHECK (last_answer in ('known','unsure','unknown') or null)`.
8. İndeksler: `words(pack_id)`, `words(pack_id,pos)`, `words(pack_id,en_word)`, `user_word_progress(user_id)`.

## 4) RLS ve Erişim Politikaları (MVP)
1. `packs` ve `words`: `SELECT` herkese açık (anon read).
2. `user_word_progress`: `SELECT/INSERT/UPDATE` koşulu:
`user_id = auth.uid() OR user_id = '<DEMO_USER_UUID>'::uuid`.
3. Silme (`DELETE`) Faz 1’de kapalı tutulacak.
4. Auth yoksa uygulama `DEMO_USER_UUID` ile yazacak; auth varsa `auth.uid()` kullanacak.

## 5) CSV Import Dokümantasyonu (Dashboard Akışı)
1. Delimiter `;`, quote char `"`, UTF-8, first-row-header açık.
2. Mapping birebir:
- `synonyms` -> `synonyms_raw`
- `antonyms` -> `antonyms_raw`
- `tags` -> `tags_raw`
- diğer alanlar isim eşleşmesiyle.
3. `pack_id` yoksa:
- `packs` tablosuna `YDS Set 001` eklenecek.
- import sonrası `UPDATE words SET pack_id='<PACK_UUID>' WHERE pack_id IS NULL;`.
4. Dokümana örnek CSV satırları (senin verdiğin 4 satır) aynı delimiter ile eklenecek.
5. Data quality notları eklenecek:
- Alan içinde `;` varsa çift tırnak zorunlu.
- Alan içinde `"` varsa CSV escape kuralı uygulanmalı.

## 6) Domain Model ve Dönüşüm Kuralları
1. `WordItem` içinde raw alanlar tutulacak: `synonymsRaw`, `antonymsRaw`, `tagsRaw`.
2. UI helper’ları:
- `synonymsList = split(';') + trim + empty-drop`
- `antonymsList = split(';') + trim + empty-drop`
- `tagsList = split(';') + trim + empty-drop`
3. `pos` filtrelemesi doğrudan string eşleşmesi ile yapılacak.
4. `Typing` normalize: `lowercase + trim` (ek olarak çoklu boşluk tek boşluğa indirgenecek).

## 7) Repository Arayüzleri (Public Interface)
1. `PackRepository`
- `getPacksWithWordCount()`
- `getPackById(packId)`
2. `WordRepository`
- `getWordsByPack(packId, {search,pos,tags})`
- `getWordById(wordId)`
3. `ProgressRepository`
- `getProgressMap(userId, wordIds)`
- `applyFlashcardResult(userId, wordId, answer)` (`known|unsure|unknown`)
- `applyTestResult(userId, wordId, isCorrect)`

## 8) Flashcard Akışı
1. Kart ön: `en_word`, `pos`.
2. Kart arka: `tr_meaning`, `example_en`, `example_tr?`, chips (`synonyms/antonyms`).
3. Buton etkileri:
- `known` -> `mastery +12`
- `unsure` -> `mastery +4`
- `unknown` -> `mastery -8`
4. Her etkileşimde:
- `seen_count +1`
- `last_seen_at = now()`
- `last_answer = button value`
- `mastery = clamp(0..100)`
5. Progress kaydı `upsert(user_id, word_id)` modeliyle yapılacak.

## 9) Test Modları
1. MCQ (EN->TR):
- hedef soru sayısı `min(10, pack_size)`.
- distractor seçim önceliği aynı `pos`, yetmezse pack geneli.
- seçeneklerde tekrar engellenecek (özellikle aynı `tr_meaning` tekrarına karşı).
2. Matching:
- `N = min(10, pack_size)`; pack küçükse dinamik düşürme.
- sol `en_word`, sağ karışık `tr_meaning`.
3. Typing (TR->EN):
- prompt `tr_meaning`, cevap `en_word` normalize karşılaştırma.
4. Testte progress:
- doğru `mastery +10`, `correct_count +1`
- yanlış `mastery -10`, `wrong_count +1`
- ayrıca `seen_count +1`, `last_seen_at = now()`, `last_answer` (`known`/`unknown`)
- `mastery clamp(0..100)`

## 10) UI Sayfaları ve Navigasyon
1. `PackListPage`: pack listesi + kelime sayısı.
2. `PackDetailPage`: Flashcard başlat, Test Hub, Kelime listesi.
3. `WordListPage`: arama + POS filtre + tag filtre.
4. `WordDetailPage`: tüm alanlar + chips.
5. `FlashcardSessionPage`: kart flip + 3 cevap butonu.
6. `TestHubPage`: MCQ / Matching / Typing giriş.
7. Oturum bitiş ekranları: skor, doğru/yanlış, güncel mastery özet.

## 11) Faz 2’ye Hazırlık (Kod Yazmadan Tasarım)
1. `features/readings` modül sınırı şimdiden açılacak (boş route + interface placeholder).
2. Test motoru soru üretimini modüler tutacak (`mcq/matching/typing` sınıfları bağımsız).
3. Word odaklı modeller reading’den ayrık olacak; böylece `reading_passages` ve `reading_questions` eklenince mevcut word akışı bozulmadan genişleyecek.

## 12) Test Planı ve Kabul Senaryoları
1. Unit:
- raw split helper (`;` split + trim + empty-drop).
- mastery clamp.
- typing normalize.
- MCQ distractor seçim önceliği (same-pos önce).
2. Widget:
- Pack listede count görünümü.
- Word list filtreleri (search/pos/tag).
- Flashcard ön/arka ve buton akışı.
3. Entegrasyon:
- Supabase’den pack/word çekme.
- `user_word_progress` upsert ve sayaç güncelleme.
4. Kabul (200 satır CSV):
- pack listede pack görünüyor.
- pack detayında kelime sayısı 200.
- flashcard detayında synonym/antonym chip split doğru.
- MCQ aynı pos önceliğiyle distractor üretiyor.
- progress yazımı Supabase’de doğrulanıyor.

## 13) Teslimat Artefaktları
1. Flutter proje iskeleti ve modüler feature yapısı.
2. Supabase migration SQL dosyaları (schema + RLS + opsiyonel seed/update script).
3. `docs/supabase_csv_import.md` (semicolon import ayarları + mapping + örnek CSV + quality notları).
4. Çalışır Faz 1 uygulama akışları (okuma, flashcard, test, progress).

## Varsayımlar ve Varsayılanlar
- CSV header: `en_word;tr_meaning;pos;example_en;example_tr;synonyms;antonyms;level;tags;notes`.
- CSV’de `pack_id` yok varsayımıyla tek pack stratejisi uygulanacak.
- `DEMO_USER_UUID` sabit ve environment’dan alınacak.
- Faz 1’de offline-first yok; her işlem online Supabase üstünden.
- Faz 1’de app içi import/upload kesinlikle yok.
