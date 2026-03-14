import '../workspace_info.dart';

class ReleaseNoteEntry {
  const ReleaseNoteEntry({
    required this.version,
    required this.releaseDate,
    required this.title,
    required this.summary,
    required this.highlights,
  });

  final String version;
  final String releaseDate;
  final String title;
  final String summary;
  final List<String> highlights;

  bool get isCurrent => version == WorkspaceInfo.appVersion;
}

const List<ReleaseNoteEntry> releaseCatalog = <ReleaseNoteEntry>[
  ReleaseNoteEntry(
    version: 'v2.0.13',
    releaseDate: '2026-03-14',
    title: 'Student manual content refresh',
    summary:
        'Student mobil ayarlar ekranina zorunlu content sync calistiran manuel yenileme aksiyonu eklendi; boylece AI ile yayinlanan yeni reading ve kelime kartlari APK tarafinda 6 saatlik TTL beklemeden gorunebilir.',
    highlights: <String>[
      'Ayarlar ekraninda mobilde gorunen Icerigi yenile butonu SyncScope.content icin zorunlu sync tetikler.',
      'Refresh sonrasi packs, readings, words ve grammar providerlari invalidate edilerek yeni lokal ayna hemen okunur.',
      'Yukleniyor, basari ve hata durumlari ayarlar kartinda ve snackbar ile kisa geri bildirim verir.',
      'Student web deploy ve arm64-v8a release APK bu akisl a birlikte uretildi.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.12',
    releaseDate: '2026-03-14',
    title: 'Student reading pack filter and version chip fix',
    summary:
        'Student web sidebar surum etiketi dar rail uzerinde tam gorunecek sekilde sadeleştirildi; Okuma Odasi sayfasina paket secimi filtresi eklendi ve reading catalog pack_id bilgisi web ile APK akisi icin tasinmaya baslandi.',
    highlights: <String>[
      'Sidebar surum chipi icon yerine dar rail uyumlu metin-odakli outlined button olarak guncellendi.',
      'Okuma Odasi artik Tum Paketler veya belirli bir paket secilerek filtrelenebilir; filtre saved ve favorites gorunumlerinde de calisir.',
      'Reading repository local ve remote catalog mappingi pack_id bilgisini student tarafa tasir.',
      'Student release bu degisikliklerle web ve kucuk arm64 APK olarak yayinlandi.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.11',
    releaseDate: '2026-03-14',
    title: 'Admin AI POS normalization hotfix',
    summary:
        'Admin AI Asistan yeni kelime karti taslaklarinda AI tarafindan gelen POS alias degerlerini DB uyumlu kisaltmalara normalize eder; boylece hem mevcut katalog eslesmesi hem de kelime karti kaydi words_pos_check hatasina dusmeden ilerler.',
    highlights: <String>[
      'AI suggestion icindeki noun, verb, adjective gibi alias POS degerleri n., v., adj. gibi kanonik formata cevrilir.',
      'Auto-match akisi artik AI noun ile katalogdaki n. kartlarini ayni POS olarak eslestirir.',
      'Yeni kelime karti save oncesi repository katmaninda tekrar normalize edilir ve gecersiz POS degeri DB yerine client tarafinda net hata verir.',
      'YDS Set 002 gibi bos paketlerde AI ile uretilen focus word kartlari published olarak kaydedilirken words_pos_check constraint hatasi alinmaz.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.10',
    releaseDate: '2026-03-14',
    title: 'Admin AI auto-linked focus words',
    summary:
        'Admin AI Asistan generate formundan category ve tags girdi alanlari kaldirildi; secili pakete gore linked words otomatik eslesir veya yeni kelime karti taslagi olarak save/publish sirasinda olusturulur hale geldi.',
    highlights: <String>[
      'AI response icindeki category ve tags_raw alanlari draft editor icinde duzenlenebilir olarak korunur.',
      'Linked word paneli manuel katalog eslestirme yerine auto-match, unlink ve yeni kart taslagi edit/delete davranisina gecti.',
      'Eksik focus words save veya publish sirasinda admin_upsert_word_detail ile published kart olarak olusturulup sonra reading linked words kaydina baglanir.',
      'Edge function promptu category ve tags alanlarini artik kullanicidan degil modelden infer eder.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.9',
    releaseDate: '2026-03-13',
    title: 'Reading mini test consumption',
    summary:
        'Student reading detail ekrani artik admin tarafinda tanimlanan okuma sorularini canli veriden yukleyip mini test olarak sunar; sonuc ozeti ve reading tipinde test attempt kaydi eklenmistir.',
    highlights: <String>[
      'Reading repository ve sync bootstrap reading_passage_questions kayitlarini yukler hale getirildi.',
      'Student reading detail sayfasina cevap secimi, skor hesaplama ve aciklama gosteren mini test paneli eklendi.',
      'Cevaplar kontrol edildiginde source_type=reading olacak sekilde user_test_attempts eventi kuyruklanir.',
      'Student UI, TTS ve repository testleri soru tuketim senaryolariyla genisletildi.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.8',
    releaseDate: '2026-03-13',
    title: 'Admin AI reading assistant',
    summary:
        'Admin console icine AI destekli reading draft uretimi, linked word cozumleme ve soru editoru eklendi; okuma detay persistence hatti AI metadata ve soru kayitlarini destekler hale geldi.',
    highlights: <String>[
      'Admin panelde /content/ai-assistant rotasi, generate formu, draft editoru ve publish paneli eklendi.',
      'AI draft akisi linked word onerilerini cozulmeden save veya publish etmeye izin vermez.',
      'AdminReadingDetail sozlesmesi questions, aiGenerated ve aiGenerationMeta alanlariyla genisletildi.',
      'Supabase migration ve edge function ile reading_passage_questions, ai_generation_meta ve Gemini tabanli draft uretimi canliya hazirlandi.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.7',
    releaseDate: '2026-03-12',
    title: 'Web ve Android icin native TTS',
    summary:
        'Student app icine native TTS eklendi; kelime paketleri, flashcard ve okuma detay akislari web ile Android release buildlerinde sesli okuma destekler hale geldi.',
    highlights: <String>[
      'Yeni StudentTtsEngine ve StudentTtsController katmani tek aktif oynatim kurali ile calisir.',
      'Kelime paketi listesi ve ortak word-card popup icine kelime bazli dinle/durdur aksiyonu eklendi.',
      'Flashcard ekraninda her iki yuzde de yalnizca English kelimeyi okuyan speaker aksiyonu eklendi.',
      'Reading detail ekraninda full passage, sentence ve word seviyesinde TTS; route ve popup kapanisinda otomatik durdurma davranisi eklendi.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.6',
    releaseDate: '2026-03-12',
    title: 'Analytics kaynagi seffafligi ve haftalik bar grafik',
    summary:
        'Ana sayfadaki haftalik ilerleme karti artik gercek haftalik toplamlarla calisir, tahmini veri kullandiginda bunu acikca belirtir ve cizgi yerine bar grafik render eder.',
    highlights: <String>[
      'Student analytics snapshot modeli remote ve estimated kaynak bilgisini birlikte tasir.',
      'Canli gunluk analytics verisi gelmezse home ve premium ekranlarinda Tahmini Veri etiketi gosterilir.',
      'Haftalik ilerleme kartindaki ikincil metrikler bugunun degil gercek haftanin toplam kelime ve oturum sayilarini gosterir.',
      'Ana sayfadaki haftalik trend cizgisi bar grafik olarak yeniden tasarlandi ve bu build web ile APK release olarak yayinlandi.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.5',
    releaseDate: '2026-03-12',
    title: 'Okuma odak kelimeleri ve passage gecisi',
    summary:
        'Okuma detayinda odak kelimeler guncel icerik sync sonrasinda yeniden yuklenir hale geldi; ayni ekran icinden onceki ve sonraki passage gecisi eklendi.',
    highlights: <String>[
      'Reading detail sayfasi acilisinda content refresh ile odak kelime ve cumle verilerini yeniden ister.',
      'Odak kelime paneli stale provider sonucuna takilmayip mevcut reading icin yeniden invalidate edilir.',
      'Okuma detayinin altina minimal Onceki parca ve Sonraki parca navigasyon karti eklendi.',
      'Student web ve release APK bu okuma akisi duzeltmeleriyle yeniden yayinlandi.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.4',
    releaseDate: '2026-03-11',
    title: 'Gramer veri senkronu ve timeline deneyimi',
    summary:
        'Gramer menusu gercek veritabani modulleriyle eslendi; detay ekranlari DB icerigi, ornek ve test kayitlarini render eder hale geldi.',
    highlights: <String>[
      'Gramer liste ekrani artik ham id yerine normalize konu sirasi ve timeline kart duzeni kullanir.',
      'Yayinli moduller ve sayfalar local sync store veya Supabase kaynagindan okunur; production akisinda seed fallback kullanilmaz.',
      'Gramer detay ekranlari icerik_html, ornekler ve testleri gercek veritabani kayitlarindan render eder.',
      'Ilerleme kayitlari artik gercek gramer sayfasi row id ile tutulur ve eski bozuk page_id kayitlari lastPageNo ile guvenli sekilde resume edilir.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.3',
    releaseDate: '2026-03-11',
    title: 'Okuma detay sozluk etkilesimi',
    summary:
        'Okuma detay ekranindaki yardim notlari ve bolum etiketleri kaldirildi; kelime bazli sozluk ve uzun basista cumle cevirisi ayni kart icine tasindi.',
    highlights: <String>[
      'Okuma detayindaki placeholder ozet notu ve baslik altindaki ceviri yardim metni kaldirildi.',
      'Cumle kartlarindaki Turkce ceviri butonu ve Bolum etiketi kaldirilarak daha sade bir akis kuruldu.',
      'Kelimeye kisa basista dictionary_entries veya local sqlite tabanli sozluk anlami inline gosterilmeye baslandi.',
      'Kelimeye uzun basista ayni cumlenin Turkce cevirisi kart icinde acilir hale geldi.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.2',
    releaseDate: '2026-03-10',
    title: 'Okuma sayfalama ve icerik gorunurlugu',
    summary:
        'Giris CTA sadelestirildi, kelime badge sayilari kaldirildi, reading listesi 21 kayitlik sayfalara bolundu ve detay ekraninda gercek Ingilizce cumleler gosterilmeye baslandi.',
    highlights: <String>[
      'Web ve APK shell icinde giris butonunun ustundeki ek giris etiketi kaldirildi.',
      'Kelimeler sekmesindeki badge sayisi web ve mobil navdan tamamen cikartildi.',
      'Okuma listesi 21 kartlik sayfalara bolundu; onceki-sonraki gecisi eklendi ve sure bilgisi kartlardan kaldirildi.',
      'Okuma detayinda reading_passage_sentences verisi kullanilarak Ingilizce cumleler yuklenir hale geldi.',
    ],
  ),
  ReleaseNoteEntry(
    version: 'v2.0.1',
    releaseDate: '2026-03-10',
    title: 'Canli release surum standardi',
    summary:
        'Sidebar surum etiketi, changelog routeu, release manifesti ve reading pro katalog akisi ayni release hatti altinda toplandi.',
    highlights: <String>[
      'Web sidebar altindaki surum etiketi artik v2.0.1 gosterir ve /changelog sayfasini acar.',
      'Student webde reading catalog görünur-kilitli davranisi canliya alindi.',
      'Admin console reading isPro kaydi canli veritabani migrationlari ile eslendi.',
      'Sentence translation esleme ve light tema sidebar kontrasti duzeltildi.',
    ],
  ),
];
