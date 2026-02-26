# Faz 1 Smoke Test Checklist

Bu checklist manuel test icindir. App ici import yoktur; once CSV Supabase Dashboard'dan import edilmelidir.

## 0) On Kosullar
1. `20260225_001_phase1_schema_rls.sql` migration calisti.
2. `docs/YDS_Set_001.csv` `words` tablosuna import edildi.
3. `pack_id` null kalan satirlara master pack atama SQL'i calisti.
4. Uygulama `SUPABASE_URL` ve `SUPABASE_ANON_KEY` ile baslatildi.
5. Supabase Auth -> Providers -> Anonymous giris aktif.
6. `YDS_Set_001.csv` importu icin hedef satir: 234 kelime.

## 1) PackList
1. Uygulamayi ac.
2. Beklenen: Anonymous sign-in tamamlanir ve PackList acilir.
3. Beklenen: `YDS Set 001` gorunur.
4. Beklenen: pack kelime sayisi gorunur.

### Empty State
1. `packs` tablosunu gecici bosalt veya baglantiyi degistir.
2. Beklenen: "Henuz paket yok" mesaji gorunur.
3. Beklenen: Retry butonu gorunur.

### Error State
1. Agi kes veya yanlis Supabase key ile ac.
2. Beklenen: hata metni + Retry gorunur, app crash olmaz.

## 2) WordList (Pagination + Filter)
1. PackDetail -> Kelime Listesi ac.
2. Beklenen: ilk sayfada veriler gelir, loading indicator kaybolur.
3. Listeyi asagi kaydir.
4. Beklenen: page-loading indicator ile yeni veriler gelir.
5. Arama kutusuna deger girip uygula.
6. Beklenen: liste reset olur, yeni filtre sonucu gelir.
7. POS secimini degistir.
8. Beklenen: pagination sifirlanir ve filtreli sonuc gelir.
9. Sonuc yok filtre gir.
10. Beklenen: "Sonuc bulunamadi" gorunur.

## 3) WordDetail (Raw Alanlar)
1. Synonyms/antonyms/tags dolu bir kelime ac.
2. Beklenen: chip alanlari dogru split edilir.
3. Bos raw alanli bir kelime ac.
4. Beklenen: bos chip bolumleri hic render edilmez.

## 4) Flashcard
1. PackDetail -> Flashcard ac.
2. Beklenen: kart on yuzde `en_word + pos`.
3. Karta tikla.
4. Beklenen: arka yuzde `tr_meaning`, `example_en`, varsa `example_tr`, varsa synonym/antonym chipleri.
5. Sirayla "Biliyordum / Kararsizim / Bilmiyordum" dene.
6. Beklenen: soru ilerler, app donmez.
7. Oturum sonuna gel.
8. Beklenen: summary ekraninda `known/unsure/unknown` sayilari gorunur.
9. "Tekrar Calis" ve "Teste Gec" CTA calisir.

## 5) MCQ
1. TestHub -> MCQ ac.
2. Beklenen: soru yukleme loading gorunur.
3. Beklenen: hedef 10 soru (yetersiz veride daha az).
4. Beklenen: seceneklerde duplicate yok.
5. Beklenen: distractor secimi ayni pos onceligiyle calisir.
6. Test bitince sonuc ekrani gorunur.

## 6) Matching (Tiklamali)
1. TestHub -> Matching ac.
2. Beklenen: solda kelimeler, sagda anlamlar.
3. Sol kelime sec, sonra sag anlam sec.
4. Beklenen: dogruysa yesil geri bildirim ve eslesme kilitlenir.
5. Beklenen: yanlissa kisa hata mesaji ve tekrar deneme.
6. Beklenen: drag-drop davranisi yok.

## 7) Typing
1. TestHub -> Typing ac.
2. Beklenen: prompt `tr_meaning`, cevap `en_word`.
3. Buyuk-kucuk harf ve coklu bosluk farkli cevaplar dene.
4. Beklenen: normalize exact match calisir.
5. Beklenen: typo tolerance yok (Faz 1).

## 8) Progress Dogrulama (Supabase)
1. Flashcard ve testlerden sonra `user_word_progress` tablosunu kontrol et.
2. Beklenen:
   - `seen_count` artar
   - `correct_count / wrong_count` teste gore artar
   - `last_seen_at` dolar
   - `last_answer` dolar
   - `mastery` 0..100 araliginda kalir

## 9) Error/Retry Dayaniklilik
1. Test/flashcard sirasinda agi gecici kes.
2. Beklenen: kayit hatasinda kullaniciya Retry/Skip benzeri yol sunulur.
3. Beklenen: uygulama crash olmaz, oturum geri doner.

## 10) Faz 1 Kabul
- App import yapmadan Supabase'ten okuyor.
- Flashcard + MCQ + Matching + Typing calisiyor.
- Progress Supabase'e yaziliyor.
- Empty/loading/error durumlari gorunur.
