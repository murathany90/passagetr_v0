# Faz 3 Smoke Test Checklist

## 0) On Kosullar
1. `20260227_004_phase3_reading_progress.sql` migration calisti.
2. Faz 1 ve Faz 2 import adimlari tamamlandi.
3. Uygulama anonymous auth ile aciliyor.

## 1) Bottom Navigation
1. Ana Sayfa / Kelime / Okuma / Profil sekmeleri gorunur.
2. Sekmeler arasi geciste app crash olmaz.
3. Kelime sekmesinde pack listesi acilir.
4. Okuma sekmesinde pack secip reading list acilabilir.

## 2) Home Dashboard + Hizli Basla
1. Ana sayfada bugun metrik karti gorunur.
2. Hizli Basla:
   - Yarım kalan okuma varsa ReadingDetail'e devam eder.
   - Yoksa zayif kelimelerle flashcard acilir.
   - O da yoksa random flashcard acilir.

## 3) Reading Detail Selection + Quick Word Popup
1. Sentence EN metni secilebilir.
2. Bir kelime secildiginde dis tarayici acilmadan uygulama ici popup acilir.
3. Secilen kelime pack'te varsa popup'ta kelime detaylari (pos/tr/example/chipler) gorunur.
4. Secilen kelime pack'te yoksa popup loading sonrasi otomatik EN->TR ceviri gorunur.
5. `Kaynakta Ac` sadece butona basinca dis tarayiciyi acar (otomatik acmaz).
6. `Flashcard'da Calis` tek kelimelik custom oturum acabilir.

## 4) Reading Progress Write
1. ReadingDetail acilisinda `user_reading_progress` kaydi olusur/guncellenir.
2. `Ilerledim` butonu `last_idx` degerini artirir.
3. `Okumayi Bitirdim` `completed=true` yazar.
4. UI progress metni `x/y` dogru guncellenir.
5. `Okumayi Bitirdim` sonrasi SQL dogrulamasi:
   ```sql
   select urp.completed, urp.last_idx, max(s.idx) as max_idx
   from public.user_reading_progress urp
   join public.reading_passage_sentences s on s.passage_id = urp.passage_id
   where urp.user_id = auth.uid()
     and urp.passage_id = '<PASSAGE_ID>'
   group by urp.completed, urp.last_idx;
   ```
   Beklenen: `completed = true` ve `last_idx = max_idx`.

## 5) Bu Paragraftan Kelimeler Paneli
1. Panelde en_word + pos + mastery badge gorunur.
2. `Kelime Calis` butonu sadece paneldeki kelimelerle flashcard acar.
3. Eslesme yoksa uygun bos durum mesaji gorunur.
4. `Kelime Calis` custom list oturumu kontrolu:
   - Panelde gorunen kelimeleri not al.
   - Flashcard oturumunu baslat.
   - Oturumdaki kart kelimeleri panel listesi disina cikmamali.

## 6) Error Cases
1. Ceviri endpoint yokken `Ceviriyi Goster`:
   - app crash olmaz
   - anlamli hata mesaji gorunur.
2. Sozluk linki acilamazsa snackbar gorunur.
3. Quick Word popup'ta ceviri hatasi olursa:
   - popup kapanmaz
   - `Retry` ile tekrar denenebilir
   - `Kaynakta Ac` aktif kalir.

## 7) Deepl Provider Smoke
1. Uygulamayi `--dart-define=TRANSLATE_PROVIDER=deepl` ile baslat.
2. ReadingDetail'de pack disi bir kelime sec.
3. Beklenen: Quick Word popup loading sonrasi ceviri gelir.
4. Beklenen: dis tarayici otomatik acilmaz; sadece `Kaynakta Ac` ile acilir.
