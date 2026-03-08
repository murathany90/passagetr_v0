# Faz 2 Smoke Test Checklist

Bu checklist Faz 2 reading akisi icin manuel test adimlarini listeler.

## 0) On Kosullar
1. `20260226_003_phase2_readings.sql` migration calisti.
2. `docs/readings_passages.csv` import edildi.
3. `docs/readings_sentences.csv` import edildi.
4. `docs/supabase_readings_import.md` icindeki post-import SQL calisti.
5. Supabase Anonymous auth aktif.
6. Uygulama `SUPABASE_URL` ve `SUPABASE_ANON_KEY` ile calisiyor.

## 1) Pack Detail Mode Butonlari
1. Pack listeden `YDS Set 001` ac.
2. Beklenen: `Kelime Calis` ve `Paragraf Calis` butonlari gorunur.
3. `Kelime Calis` -> mevcut flashcard/test/kelime listesi akisi acilir.
4. `Paragraf Calis` -> reading list acilir.

## 2) Reading List
1. Reading listte kartlar gorunur.
2. Beklenen: title, varsa level, varsa tag chipleri gorunur.
3. Asagi kaydir.
4. Beklenen: pagination ile yeni sayfa yuklenir.
5. Ag kesme/yetersiz baglantida hata al.
6. Beklenen: retry butonu ile toparlar, app crash olmaz.

## 3) Reading Detail
1. Bir passage ac.
2. Beklenen: cumleler `idx` sirasina gore gorunur.
3. Her satirda `Ceviriyi Goster` butonu var.
4. `sentence_tr` dolu satirda butona bas.
5. Beklenen: TR metin acilir.
6. `sentence_tr` bos satirda butona bas.
7. Beklenen: API cagrisi olur, loading gorunur, ceviri gelir.

## 4) Translation Cache
1. `sentence_tr` bos bir cumleyi bir kez cevirt.
2. Supabase `reading_sentence_translations` tablosunu kontrol et.
3. Beklenen: ilgili `sentence_id/provider/target_lang` satiri yazilir.
4. Ayni cumleyi tekrar ac.
5. Beklenen: cache kullanilir, tekrar ayni ceviri gorunur.

## 5) Dictionary Sheet
1. Reading detailde bir cumlede kitap ikonuna bas.
2. Bottom sheet acilir.
3. Kelime girip `Cambridge` bas.
4. Beklenen: tarayici/dis app acilir.
5. `Dictionary.com` ve `Copy` islemleri de calisir.

## 6) Error Dayaniklilik
1. `TRANSLATE_ENDPOINT` bos veya gecersiz ayarla.
2. Bos `sentence_tr` icin `Ceviriyi Goster` de.
3. Beklenen: app crash olmaz, anlamli hata + retry gorunur.

## 6.1) Translation Disabled Beklenen Davranis
1. `TRANSLATE_ENDPOINT` degeri tamamen bos birak.
2. Bos `sentence_tr` satirinda `Ceviriyi Goster` bas.
3. Beklenen:
   - API cagrisi denenmez.
   - `Ceviri yapilandirilmadi.` mesaji gorunur.
   - Sayfa akisi bozulmaz, kullanici diger cumlelere devam edebilir.

## 7) Faz 2 Kabul
- Pack detailde iki mod var (`Kelime Calis`, `Paragraf Calis`).
- Reading list ve detail Supabase'ten geliyor.
- `sentence_tr` varsa direkt, yoksa API + cache ile ceviri geliyor.
- Dictionary sheet calisiyor.
- Faz 1 ekranlari bozulmadi.
