# PASSAGETR Changelog

Bu dosya her canli deploy oncesi guncellenir.

Zorunlu kural:
- `packages/shared_core/lib/src/workspace_info.dart` icindeki `appVersion` ve `buildNumber` alanlarini guncelle.
- `packages/shared_core/lib/src/release/release_catalog.dart` icine yeni surum notunu ekle.
- `apps/student_app/pubspec.yaml` ve `apps/admin_console/pubspec.yaml` surumlerini ayni release ile esle.
- Web sidebar chip ve dar layout/APK `Profil/Giris` release kartinin ayni shared metadata kaynagindan beslendigini deploy oncesi dogrula.
- Deploy scriptleri bu dosyada guncel surum etiketi yoksa fail etmelidir.

## v2.0.5 - 2026-03-12

Baslik:
Okuma odak kelimeleri ve passage gecisi

Notlar:
- Okuma detay sayfasi acilisinda content refresh tetiklenir; stale local cache odak kelime panelini bos birakmaz.
- `studentReadingsProvider`, `studentReadingSectionsProvider` ve `studentReadingFocusWordsProvider` ayni reading icin birlikte invalidate edilir.
- Okuma detayinin altina minimal `Onceki parca / Sonraki parca` gecis karti eklendi.
- Student web ve release APK bu reading detail duzeltmeleriyle yeniden deploy edildi.

## v2.0.6 - 2026-03-12

Baslik:
Analytics kaynagi seffafligi ve haftalik bar grafik

Notlar:
- `fetch_user_daily_stats` kullanilamadiginda analytics fallback'i sessizce gizlenmez; home ve premium ekranlari `Tahmini Veri` etiketi gosterir.
- Analytics snapshot modeli veri kaynaginin `remote` veya `estimated` oldugunu tasir ve fallback nedeni loglanir.
- Ana sayfadaki haftalik ilerleme karti artik bugunun degil gercek haftanin toplam kelime ve oturum sayilarini gosterir.
- Haftalik trend cizgisi kaldirildi; yerine ayni gunluk aktivite skorlarini gosteren bar grafik geldi.

## v2.0.3 - 2026-03-11

Baslik:
Okuma detay sozluk etkilesimi

Notlar:
- Okuma detay ekranindaki placeholder ozet notu ve baslik alti ceviri yardim metni kaldirildi.
- Cumle kartlarindaki `Turkce Ceviriyi Goster/Gizle` satiri ile `Bolum n` etiketi kaldirildi.
- Kelimeye kisa basista veritabani sozluk anlami inline gosterilmeye baslandi.
- Kelimeye uzun basista ayni cumlenin Turkce cevirisi kart icinde acilir hale geldi.
- Mobil bundle icine `dictionary_local.sqlite` asset'i eklendi; web tarafinda mevcut `dictionary_entries` kaynagi kullanilmaya devam ediyor.

## v2.0.4 - 2026-03-11

Baslik:
Gramer veri senkronu ve timeline deneyimi

Notlar:
- Gramer menusu artik gercek veritabani modulleriyle eslenir; ham DB `id` degerleri kullaniciya konu numarasi olarak gosterilmez.
- Gramer liste ekrani timeline duzenine gecirildi; kartlarda baslik, sayfa sayisi, durum ve ilerleme gosterilir.
- Gramer detay ekranlari `icerik_html`, `gramer_ornekler` ve `gramer_testler` kayitlarini gercek DB kaynagindan render eder.
- Ilerleme kaydi `gramer_sayfalari.id` ile tutulur; eski bozuk `page_id` kayitlari `lastPageNo` uzerinden guvenli sekilde devam eder.

## v2.0.1 - 2026-03-10

Baslik:
Canli release surum standardi

Notlar:
- Web sidebar altindaki `v2-rev...` etiketi kaldirildi; yerine `v2.0.1` geldi.
- Sidebar surum etiketi tiklaninca `/changelog` sayfasi acilir.
- Student webde reading catalog gorunur-kilitli davranisi canliya alindi.
- Admin console reading `isPro` kaydi canli veritabani migrationlariyla eslendi.
- Sentence translation index esleme ve light tema sidebar kontrasti duzeltildi.

## v2.0.2 - 2026-03-10

Baslik:
Okuma sayfalama ve icerik gorunurlugu

Notlar:
- Giris butonunun ustundeki ek `Giris` etiketi kaldirildi.
- `Kelimeler` nav badge sayisi web ve APK yuzlerinde kaldirildi.
- Okuma listesi 21 kartlik sayfalara bolundu; `Onceki / Sonraki` gecisi eklendi.
- Okuma kartlari ve detay bilgi panelindeki sure bilgisi kaldirildi.
- Okuma detay ekrani artik `reading_passage_sentences` kayitlarindan gercek Ingilizce cumleleri yukler.
