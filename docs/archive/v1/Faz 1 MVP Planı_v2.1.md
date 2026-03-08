# Faz 1 MVP Planı v2.1 - Uygulanabilir Revizyon

## Kısa Özet
Bu sürüm, Faz 1 kapsamını koruyarak uygulamayı doğrudan geliştirilebilir hale getirir. App içi import yoktur; CSV import yalnız Supabase Dashboard üzerinden yapılır. Flutter uygulaması yalnızca okuma, öğrenme, test ve progress yazımı yapar.

## Faz 1 Scope Sınırı
- Dahil: Android Flutter uygulaması, Supabase şema/migration, CSV import dokümantasyonu, flashcard, testler, progress.
- Hariç: App içi CSV upload/import, PDF/Word, Edge Function zorunluluğu, typo tolerance, advanced analytics.

## Kesin Kararlar (v2.1)
1. Pack stratejisi: Faz 1 default tek "Master Pack" modelidir. `packs` içinde `YDS Set 001` seed edilir.
2. `pack_id` atama: CSV'de `pack_id` yoksa import sonrası `UPDATE words SET pack_id = '<PACK_UUID>' WHERE pack_id IS NULL;` çalıştırılır.
3. PackList davranışı: Faz 1'de tek pack görünür; çoklu pack varsa hepsi listelenir.
4. Auth varsayılanı: Uygulama açılışında Anonymous Sign-In yapılır.
   - Supabase Dashboard -> Auth -> Providers -> Anonymous aktif olmalıdır.
5. Progress user_id: `user_word_progress.user_id = auth.uid()` kullanılır.
6. `DEMO_USER_UUID`: Sadece dev/test fallback. Production default değildir.
   - Not: RLS `authenticated` odakli oldugu icin demo fallback ile progress yazimi icin dev ortamda gecici policy gerekebilir.
7. Auth hatası: Anonymous sign-in başarısız olursa bloklayıcı hata ekranı + Retry gösterilir.
8. RLS: `user_word_progress` için yalnız `auth.uid()` satırları okunur/yazılır. `packs/words` select Faz 1'de anon read açık kalır.
9. Progress güncelleme: Faz 1 default `upsert + retry + istemci tarafı serialized update`.
10. RPC: Atomik güncelleme için `apply_flashcard_result` ve `apply_test_result` SQL taslakları opsiyonel migration olarak sağlanır.
11. Pagination: WordList zorunlu olarak `limit/offset` (default 50) + infinite scroll kullanır.
12. Filtre reset: Arama/POS/tag değiştiğinde pagination sıfırlanır.
13. RAM kuralı: Flashcard/test tüm pack'i RAM'e almak zorunda değildir; batch/paged fetch'e uygun yapı korunur.
14. Matching UX: Drag-drop yok, tıklamalı eşleştirme varsayılan.
15. Typing doğrulama: Normalize exact match (lowercase + trim + çoklu boşluk tek boşluk).
16. Typo tolerance: Faz 2/3 iyileştirmesi olarak not edilir; Faz 1'de yoktur.
17. Raw alanlar: `synonyms_raw`, `antonyms_raw`, `tags_raw` split+trim+empty-drop ile parse edilir.
18. Boş listeler: İlgili chip bölümü UI'da render edilmez.
19. Faz 2 hazırlık: data layer/repository tasarımı pack-only kilitlenmez; reading kaynakları için genişlemeye açık kalır.

## Uygulama Öncelik Sırası
1. Supabase migration SQL dosyaları.
2. `docs/supabase_csv_import.md`.
3. Flutter iskelet (data/domain/ui + Riverpod).
4. Auth bootstrap (Anonymous default).
5. PackList / PackDetail / WordList (pagination).
6. Flashcard session + progress upsert.
7. TestHub + MCQ / Matching / Typing.
8. Empty/loading/error states + flashcard session summary.
9. Smoke test ve kabul kontrolleri.
   - `docs/phase1_smoke_test_checklist.md` adimlari birebir uygulanir.

## Supabase Şema Kapsamı
- `packs`, `words`, `user_word_progress` tabloları.
- `words` içinde `synonyms_raw`, `antonyms_raw`, `tags_raw` kolonları `text`.
- `words.pack_id` Faz 1'de nullable.
- `UNIQUE(pack_id, en_word, pos)`.
- `pos` ve `last_answer` check constraint.
- `mastery` 0..100 check.
- Gerekli indeksler: `words(pack_id)`, `words(pack_id,pos)`, `words(pack_id,en_word)`, `user_word_progress(user_id)`.

## Public API / Repository Sözleşmeleri
- `WordRepository.getWordsByPack(packId, {query, pos, tag, limit, offset})`
- `ProgressRepository.applyFlashcardResult(wordId, answer)`
- `ProgressRepository.applyTestResult(wordId, isCorrect)`
- `ProgressRepository.getProgressMap(wordIds)`
- Faz 2 notu: implementasyon içinde source-agnostic query builder yaklaşımı korunur.

## UI State Zorunlulukları
- PackListPage: loading, empty ("Henüz paket yok" + kurulum yönlendirmesi), error + Retry.
- WordListPage: initial loading, page loading, empty ("Sonuç bulunamadı"), error + Retry.
- FlashcardSessionPage: oturum sonu mini özet (`known/unsure/unknown`) + "Tekrar Çalış" ve "Teste Geç" CTA.
- Test ekranları: soru yükleme state'i; sonuç kaydı başarısızsa Retry/yeniden gönderim.

## CSV Dokümantasyon Kriterleri
- Delimiter `;`, Quote `"`, UTF-8, first row header.
- Mapping: `synonyms -> synonyms_raw`, `antonyms -> antonyms_raw`, `tags -> tags_raw`.
- Data quality notu: field içinde `;` varsa çift tırnak zorunlu; field içinde `"` varsa `""` escape.
- Projedeki aktif dosya: `docs/YDS_Set_001.csv` (235 satır, 234 veri satırı).
- `pos` doğrulaması: lowercase ve Faz 1 enum kümesi ile uyumlu.

## Kabul Kriterleri (Faz 1)
1. CSV import sonrası pack görünür.
2. Import edilen veri satiri kadar kelime listelenir (`YDS_Set_001.csv` icin 234).
3. Flashcard detayında raw alanlar doğru split edilir ve boş alanlar gizlenir.
4. MCQ distractor same-pos önceliği çalışır.
5. Matching tıklamalı eşleştirme çalışır.
6. Typing exact match doğrulaması çalışır.
7. Progress Supabase'e kullanıcı bazında yazılır.
8. Pagination 10k+ senaryosunda tek seferde tüm veriyi çekmez.

## Bilinen Sınırlamalar
- App içi import yok.
- Offline-first yok.
- Typo tolerance yok.
- `tags_raw` string filtre büyük veride sınırlı hassasiyet sunabilir.
- RPC atomik güncelleme opsiyoneldir; default istemci tabanlı retry kullanılır.
