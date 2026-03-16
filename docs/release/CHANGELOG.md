# PASSAGETR Changelog

Bu dosya her canli deploy oncesi guncellenir.

Zorunlu kural:
- `packages/shared_core/lib/src/workspace_info.dart` icindeki `appVersion` ve `buildNumber` alanlarini guncelle.
- `packages/shared_core/lib/src/release/release_catalog.dart` icine yeni surum notunu ekle.
- `apps/student_app/pubspec.yaml` ve `apps/admin_console/pubspec.yaml` surumlerini ayni release ile esle.
- Web sidebar chip ve dar layout/APK `Profil/Giris` release kartinin ayni shared metadata kaynagindan beslendigini deploy oncesi dogrula.
- Deploy scriptleri bu dosyada guncel surum etiketi yoksa fail etmelidir.

## v2.0.23 - 2026-03-16

Baslik:
Öğrenci Paneli Modernizasyonu ve Dashboard Widgetlerı

Notlar:
- Öğrenci ana sayfası "Hızlı İstatistikler" (Quick Stats Bar), "Günün Kelimesi" ve "Önerilen Okumalar" widget'ları ile modernize edildi.
- `GrammarModuleSeed` içerisindeki hardcoded ilerleme verileri (progressPercent) temizlendi; sistem tamamen dinamik DB verilerine bağlandı.
- Admin CMS üzerindeki toplu işlem yetenekleri ve UI geliştirmeleri bu sürümle birlikte web ve mobil platformlarda optimize edildi.
- Student web deploy ve Android ARM64 APK build işlemleri v2.0.23 sürümüyle gerçekleştirildi.

## v2.0.22 - 2026-03-16

Baslik:
Admin Console C4/C5/C6/B5 iyileştirmeleri ve UI/UX güncellemeleri

Notlar:
- Admin panel dashboard loading için shimmer skeleton ve deferred loader hata senaryoları (error states) iyileştirildi.
- Dashboard icerik trend grafiğine (CustomPaint) imleç etkileşimleriyle animasyonlu tooltip ve nokta gösterimleri (fl_chart mimarisini andıran) eklendi.
- Son audit kayitlarina, ilgili sayfalara hızlı geçiş sağlayan Action butonu eklendi.
- Öğrenci arayüzünde "Çeviri Modu" toggle olarak etkinleşip cümle kartlarında inline translate simgeleri sunar hale getirildi. Hatalı fallback analytics verileri sıfırlandı.
- Haftalık progress kartının yanısıra 7 günlük başarı Timeline widget'ı öğrenci arayüzüne dahil edildi.
- Android Offline First ve Web Remote First yapısı optimize edildi. Web admin build ve student app release build'leri çalıştırıldı.

## v2.0.21 - 2026-03-16
Admin cover pool migration to ImageRouter and Hugging Face

Notlar:
- Reading cover uretimi direct Gemini/OpenAI image saglayicilarindan cikarilip ImageRouter primary ve Hugging Face fallback havuzuna tasindi.
- Cover pipeline artik Otomatik Havuz, explicit ImageRouter modeli veya explicit Hugging Face modeli ile calisabilir.
- Her model icin gunluk attempt, success, failed ve rate-limited sayaçlari tutulur; admin Ayarlar ekranina AI Cover sekmesi eklendi.
- Okumalar, Eksik Kapaklar backfill ve AI Asistan save-sonrasi cover paneli ayni provider secim ve kullanim ozetini kullanir.
## v2.0.20 - 2026-03-15

Baslik:
Student reading cards compact layout

Notlar:
- Student Okuma sekmesindeki kartlardan `Bu okuma icin ozet ve ceviri destegi yakinda genisletilecek.` placeholder metni kaldirildi.
- Okuma kartlarinin grid spacing, kart yuksekligi, gorsel yuksekligi ve ic padding degerleri sikilastirilip bosluklar azaltildi.
- Gercek summary varsa kartta kisa ozet gosterilmeye devam eder; placeholder summary artik render edilmez.
- Student web `v2.0.20` ile bu daha kompakt kart duzeni canliya alindi.
## v2.0.19 - 2026-03-15

Baslik:
Admin dashboard content coverage metrics

Notlar:
- Admin dashboard stok kartlari negatif delta yerine semantik olarak dogru toplam-yayinda ve hazir-eksik formatina gecirildi.
- Mini test, kapak, odak kelime baglantisi ve sozluk eslesmesi icin yeni kapsama kartlari eklendi.
- Sozluk havuzu karti aktif dictionary entry sayisini gosterer; okuma, kelime ve gramer kartlari ise toplam envanter ve yayinda sayilarini birlikte sunar.
- Kullanici Trend Serisi kaldirilip audit log tabanli Icerik Operasyon Trendi paneli eklendi.

## v2.0.18 - 2026-03-15

Baslik:
Admin users bulk delete

Notlar:
- Admin Kullanicilar sekmesindeki toplu secim barina Kullanicilari Sil yikici aksiyonu eklendi.
- Toplu silme mevcut tekli silme ile ayni hard-delete zincirini kullanir; auth.users, profil, rol ve plan kayitlari kaldirilir.
- Islem kismi basari destekler; self-delete ve developer yetki kisitlari item bazinda atlanir ve sonuc ozeti snackbar ile gosterilir.
- admin_manage_users edge functioni yeni delete_many action'i ile per-user sonuc listesi ve summary audit kaydi dondurur.
## v2.0.17 - 2026-03-15

Baslik:
Cover backfill throttling and failure-rate guard

Notlar:
- Cover backfill artik batchSize=1 ile ilerler; her cover uretimi sonrasi 10 saniyelik throttle beklemesi vardir.
- Run toplamda en az 10 kayit islediyse ve hata orani yuzde 60 veya uzerine ciktiysa auto_failure_rate_threshold ile otomatik duraklatilir.
- Mevcut 5 art arda hata korumasi korunur; resume sirasinda pause ve last error statei temizlenir.
- AI Backfill Progress dialogunda Son 5 hata ayri bir panelde daha gorunur ve okunakli gosterilir.
## v2.0.16 - 2026-03-15

Baslik:
Admin cover backfill run controls

Notlar:
- Admin Okumalar ekranindaki Eksik Kapaklar akisi artik baslangic dialogu ile hedef kayit sayisi, filtre snapshot ozeti ve model secimi gosterir.
- AI Backfill Progress karti aktif runlari geri yukler; ayni job type icin ikinci run baslatmak yerine mevcut progress dialogunu acar.
- Cover backfill Gemini 2.5 Flash Image veya OpenAI GPT Image 1.5 modeliyle baslatilabilir; paused run resume sirasinda model guncellenebilir.
- Reading AI run hattina paused durumu, pause reason, last error ve 5 art arda hata sonrasi auto-pause korumasi eklendi.
## v2.0.15 - 2026-03-15

Baslik:
Admin manual cover upload and student cover rollout

Notlar:
- Admin Okumayi Duzenle cover paneli webde image_picker yerine file_picker kullanir; Dosya Yukle ve Dosya ile Degistir butonlari browserda gercek dosya secimi acip binary upload yapar.
- Gemini text ve image functionlari gemini-2.5-flash ve gemini-2.5-flash-image ile uyumlu halde production'da calismaya devam eder.
- Student web ve Android arm64 release build bu paketle birlikte yeniden yayinlanir; reading cover alanlari remote storage URL uzerinden gorunur hale gelir.
- Mobilde yeni kapaklari gormek icin mevcut Ayarlar > Icerigi yenile aksiyonu kullanilabilir.
## v2.0.14 - 2026-03-14

Baslik:
Admin reading cover Gemini image rollout

Notlar:
- `admin_ai_generate_reading_cover` edge functioni artik varsayilan olarak gemini-2.5-flash-image ile 16:9 reading cover uretir.
- Gemini image istegi basarisiz olursa ve OPENAI_API_KEY tanimliysa OpenAI Images ikinci alternatif olarak devreye girer.
- Faz 11.3 kapsamindaki reading mini test batch ve cover pipeline migration/function hatlari production deploy paketine alinmistir.
- Admin web deploy bu release ile yeni cover pipeline davranisini gosterecek sekilde yeniden yayinlandi.

## v2.0.13 - 2026-03-14

Baslik:
Student manual content refresh

Notlar:
- Student mobil `Ayarlar` ekranina `Icerigi yenile` aksiyonu eklendi; bu buton `SyncScope.content` icin zorunlu sync calistirir.
- Refresh sonrasi `packs`, `words`, `readings` ve `grammar` providerlari invalidate edilir; yeni AI reading ve AI kaynakli kelime kartlari APK tarafinda hemen gorunur.
- Ayarlar karti loading, basari ve hata durumlarini kisa metin ve snackbar ile gosterir.
- Student web production yeniden deploy edildi ve `arm64-v8a` release APK guncel surumle yeniden uretildi.

## v2.0.12 - 2026-03-14

Baslik:
Student reading pack filter and version chip fix

Notlar:
- Student web sidebar altindaki surum etiketi dar rail uzerinde kirpilmamasi icin icon kaldirildi ve metin-odakli compact button yapisina gecildi.
- Okuma Odasi sayfasina `Paket` dropdown filtresi eklendi; filtre `Tum Okumalar`, `Kayitlilar` ve `Favoriler` gorunumlerinde ayni state ile calisir.
- Reading catalog mappingi `pack_id` tasir hale geldi; boylece web ve APK tarafinda published readingler secili pakete gore filtrelenebilir.
- Student web yeniden deploy edildi ve Android icin tek `arm64-v8a` kucuk release APK uretildi.

## v2.0.11 - 2026-03-14

Baslik:
Admin AI POS normalization hotfix

Notlar:
- Admin AI Asistan yeni kelime karti taslaklarinda AI tarafindan gelen `noun`, `verb`, `adjective` gibi POS alias degerlerini DB uyumlu kisa formata normalize eder.
- Auto-match akisi AI suggestion POS degerini katalogdaki `n.`, `v.`, `adj.` gibi kayitlarla ayni kanonik formatta karsilastirir.
- `admin_upsert_word_detail` oncesi repository katmaninda ikinci bir POS normalizasyonu uygulanir; gecersiz POS artik DB constraint hatasi yerine client tarafinda net hata verir.
- Bu hotfix ile bos paket secildiginde AI tarafindan uretilen focus word kartlari save/publish sirasinda `words_pos_check` hatasina dusmeden kaydedilebilir.

## v2.0.10 - 2026-03-14

Baslik:
Admin AI auto-linked focus words

Notlar:
- Admin AI Asistan generate formundan `Category` ve `Tags Raw` input alanlari kaldirildi; bu alanlar artik yalnizca AI cevabindan gelir.
- Draft editor AI tarafindan uretilen `Kategori` ve `Tags Raw` degerlerini duzenlenebilir olarak gostermeye devam eder.
- Linked word akisi manuel katalog eslestirme yerine secili pakete gore otomatik eslesme veya yeni kelime karti taslagi uretimi davranisina gecti.
- Save/Publish sirasinda eksik focus words published kelime karti olarak upsert edilir, ardindan reading linked words zincirine baglanir.
- Edge function promptu `category` ve `tags_raw` alanlarini modelin icerikten infer etmesini zorlar.

## v2.0.9 - 2026-03-13

Baslik:
Reading mini test consumption

Notlar:
- Student reading detail ekrani artik `reading_passage_questions` kayitlarini canli veriden veya local sync deposundan yukler.
- Okuma akisi icine cevap secimi, skor banner'i, soru bazli dogru/yanlis vurgusu ve aciklama paneli eklendi.
- Mini test sonucu `source_type=reading` olarak `user_test_attempts` outbox event zincirine yazilir.
- Student web build ve repository/widget testleri bu reading soru tuketim akisiyla dogrulandi.

## v2.0.8 - 2026-03-13

Baslik:
Admin AI reading assistant

Notlar:
- Admin console icine `/content/ai-assistant` rotasi ve admin-only AI draft yuzeyi eklendi.
- Gemini tabanli edge function ile reading title, sentences, linked word onerileri ve soru taslagi JSON olarak uretilir hale geldi.
- Admin draft editoru linked word cozumleme tamamlanmadan `Save Draft` veya `Publish` aksiyonuna izin vermez.
- `reading_passage_questions`, `ai_generated` ve `ai_generation_meta` alanlari migration ile eklendi; mevcut reading detail RPC zinciri genisletildi.

## v2.0.7 - 2026-03-12

Baslik:
Web ve Android icin native TTS

Notlar:
- `student_app` icine `flutter_tts` tabanli native TTS katmani eklendi; ayni anda tek aktif oynatim korunur.
- Kelime paketi satirlarinda, ortak kelime karti popup'inda ve flashcard ekraninda English kelimeyi sesli oynatan speaker/stop aksiyonlari eklendi.
- Okuma detay ekraninda tam passage, tek cumle ve odak kelime popup'i icin TTS oynatimi eklendi.
- Route degisimi, popup kapanisi ve app background durumunda aktif TTS otomatik durdurulur.
- Web release ve Android release APK bu TTS akisiyla derlenip dogrulandi.

## v2.0.6 - 2026-03-12

Baslik:
Analytics kaynagi seffafligi ve haftalik bar grafik

Notlar:
- `fetch_user_daily_stats` kullanilamadiginda analytics fallback'i sessizce gizlenmez; home ve premium ekranlari `Tahmini Veri` etiketi gosterir.
- Analytics snapshot modeli veri kaynaginin `remote` veya `estimated` oldugunu tasir ve fallback nedeni loglanir.
- Ana sayfadaki haftalik ilerleme karti artik bugunun degil gercek haftanin toplam kelime ve oturum sayilarini gosterir.
- Haftalik trend cizgisi kaldirildi; yerine ayni gunluk aktivite skorlarini gosteren bar grafik geldi.

## v2.0.5 - 2026-03-12

Baslik:
Okuma odak kelimeleri ve passage gecisi

Notlar:
- Okuma detay sayfasi acilisinda content refresh tetiklenir; stale local cache odak kelime panelini bos birakmaz.
- `studentReadingsProvider`, `studentReadingSectionsProvider` ve `studentReadingFocusWordsProvider` ayni reading icin birlikte invalidate edilir.
- Okuma detayinin altina minimal `Onceki parca / Sonraki parca` gecis karti eklendi.
- Student web ve release APK bu reading detail duzeltmeleriyle yeniden deploy edildi.

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
