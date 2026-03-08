# Faz 3 Smoke Test Checklist

## 0) On Kosullar
1. `202602270004_phase3_reading_progress.sql` migration calisti.
2. Faz 1 ve Faz 2 import adimlari tamamlandi.
3. Uygulama anonymous auth ile aciliyor.
4. `USE_LOCAL_STATIC_CONTENT=true` akisi aktifse `assets/db/app_content.db` guncel.

## 1) Bottom Navigation
1. Ana Sayfa / Kelime / Okuma / Gramer / Profil sekmeleri gorunur.
2. Sozluk sekmesi gorunmez.
3. Sekmeler arasi geciste app crash olmaz.
4. Kelime sekmesinde ustte birlesik arama, altta pack listesi gorunur.
5. Okuma sekmesinde pack secip reading list acilabilir.

## 2) Home Dashboard + Hizli Basla
1. Ana sayfada bugun metrik karti gorunur.
2. Ana sayfada teknik `Auth session yok` metni normal akisda gorunmez.
3. Hizli Basla:
   - Yarim kalan okuma varsa ReadingDetail'e devam eder.
   - Yoksa zayif kelimelerle flashcard acilir.
   - O da yoksa random flashcard acilir.
4. Anonim auth gecici hatasinda anlamli mesaj + Retry gorunur.

## 3) Profil Auth Stabilizasyonu
1. Profilde UID alani `session_not_found` gostermez.
2. Auth sorunu varsa kullanici dostu mesaj + Retry gorunur.
3. Refresh aksiyonu auth bootstrap + dashboard + pack verisini yeniden dener.

## 4) Kelime Sekmesi Birlesik Arama
1. Bos aramada network sorgusu atilmaz, yonlendirme metni gorunur.
2. Kart sonucu varsa butonlar: `Kelime Karti` + `Sozluk`.
3. Kart sonucu yoksa sadece `Sozluk` butonu gorunur.
4. `Kelime Karti` aksiyonu WordDetail acar.
5. `Sozluk` aksiyonu dictionary fallback sheet acar.

## 5) Reading Detail Interactive Sentence + Quick Word Popup
1. Sentence EN metni token bazli render edilir.
2. Sistemde bulunan kelimeler bold/belirgin gorunur.
3. Sistemde olmayan kelimeler normal stilde gorunur.
4. Kelimeye tek dokunusta dis tarayici acilmadan uygulama ici popup acilir.
5. Secilen kelime pack'te varsa popup'ta kelime detaylari (pos/tr/example/chipler) gorunur.
6. Secilen kelime pack'te yoksa popup loading sonrasi otomatik EN->TR ceviri gorunur.
7. Noktalama isaretlerine dokununca popup acilmaz.
8. `Kaynakta Ac` sadece butona basinca dis tarayiciyi acar (otomatik acmaz).
9. `Flashcard'da Calis` tek kelimelik custom oturum acabilir.
10. Quick Word popup'ta metin/etiketler tasma yapmadan dogru hizalanir.
11. Ayni passage tekrar acildiginda scroll/tap akisi akici kalir.

## 6) Reading Progress Write
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

## 7) Bu Paragraftan Kelimeler Paneli
1. Panel varsayilan olarak kapali gelir.
2. Panel acilinca `en_word + tr_meaning + pos` bilgisi gorunur.
3. `Kelime Calis` butonu sadece panel acikken gorunur.
4. `Kelime Calis` butonu paneldeki kelimelerle flashcard acar.
5. Eslesme yoksa uygun bos durum mesaji gorunur.
6. `Kelime Calis` custom list oturumu kontrolu:
   - Panelde gorunen kelimeleri not al.
   - Flashcard oturumunu baslat.
   - Oturumdaki kart kelimeleri panel listesi disina cikmamali.

## 8) Pack Sayac Tutarliligi
1. Kelime sekmesindeki pack kartinda gorunen kelime sayisi not edilir.
2. Okuma sekmesindeki ayni pack kartinda gorunen kelime sayisi kontrol edilir.
3. Beklenen: sayilar birebir ayni olmalidir.
4. Supabase kontrolu (opsiyonel):
   ```sql
   select p.name, count(w.id) as word_count
   from public.packs p
   left join public.words w on w.pack_id = p.id
   group by p.name
   order by p.name;
   ```

## 9) Error Cases
1. Ceviri endpoint yokken `Ceviriyi Goster`:
   - app crash olmaz
   - anlamli hata mesaji gorunur.
2. Sozluk linki acilamazsa snackbar gorunur.
3. Quick Word popup'ta ceviri hatasi olursa:
   - popup kapanmaz
   - `Retry` ile tekrar denenebilir
   - `Kaynakta Ac` aktif kalir.

## 10) Deepl Provider Smoke
1. Uygulamayi `--dart-define=TRANSLATE_PROVIDER=deepl` ile baslat.
2. ReadingDetail'de pack disi bir kelime sec.
3. Beklenen: Quick Word popup loading sonrasi ceviri gelir.
4. Beklenen: dis tarayici otomatik acilmaz; sadece `Kaynakta Ac` ile acilir.

## 11) POS/Etiket Filtre Doğruluğu
1. Kelime listesinde POS olarak `v.` seçildiğinde `adv.` etiketli kayıtlar gelmemelidir.
2. Kelime listesinde POS olarak `phr. v.` seçildiğinde yalnız bu tokenı içeren kayıtlar gelmelidir.
3. Seviye kelime sayfasında etiket filtreye `verb` yazıldığında `adverb` tokenı tek başına eşleşme üretmemelidir.
4. Etiket seçiminde görünen metinler okunabilir formatta olmalıdır (ör. `yds` -> `Yds`).

## 12) Türkçe Metin Tutarlılığı
1. `Kelime` ekranında `Seviye Merkezi` metni görünmelidir.
2. Paket kartında CTA `Paket Merkezini Aç` olmalıdır.
3. Filtre etiketlerinde `Kelime Türü (POS)` ve `Etiket` metinleri görünmelidir.
4. README mojibake denetimi için `python scripts/check_mojibake.py` komutu hatasız çalışmalıdır.

## 13) Offline Queue + Senkron
1. Ucak modunda ReadingDetail ekraninda `Ilerledim`/`Okumayi Bitirdim` aksiyonlari app'i kirmadan calismalidir.
2. Ucak modunda Flashcard/MCQ/Matching/Typing cevaplarinda teknik host/socket hatasi popup olarak gorunmemelidir.
3. Uygulama ustunde tek bir cevrimdisi banneri gorunmelidir:
   - `Cevrimdisi: ilerleme cihazda saklaniyor (N)`
4. Ag geri geldiginde bannerde bekleyen kayit sayisi azalip sifira iner.
5. Ag geri geldikten sonra Home/Profile metrikleri normal degerlere doner.
6. Ham teknik metinler (`SocketException`, `Failed host lookup`, `supabase.co/rest/v1/...`) kullaniciya gosterilmemelidir.

## 14) Reading Player v2
1. ReadingDetail app barinda `Paylas`, `Yer imi`, `Dinleme ayarlari` aksiyonlari gorunmelidir.
2. Kelimeye dokununca kisa inline baloncuk acilmali, 2-3 sn icinde otomatik kapanmalidir.
3. Inline baloncukta `Detay` aksiyonu `WordQuickViewSheet` acmalidir.
4. Scroll yapildiginda inline baloncuk kapanmalidir.
5. Quick word sheet uzun metinde tasma yapmamalidir.

## 15) Reading Sekmesi Segmentleri
1. Okuma ana sayfasinda `Hikayeler / Haber Akisi / Kitapligim` segmentleri gorunmelidir.
2. `Kitapligim` segmentinde yer imi yoksa bos durum mesaji gorunmelidir.
3. ReadingDetail'de yer imi ac/kapat sonrasi `Kitapligim` segmentine donuldugunde icerik gorunmelidir.
4. `Okumaya Devam Et` karti varsa ilgili passage dogru ekranla acilmalidir.

## 16) Dinleme Ayarlari
1. Reading player `Dinleme ayarlari` panelinde hiz secenekleri gorunmelidir (`x0.5`, `x1`, `x1.25`, `x1.5`).
2. `Kelimeye dokununca sesi durdur` acikken kelime tap etkileşiminde ses durmalidir.
3. Ayar degisikligi app yeniden acildiginda korunmalidir.
