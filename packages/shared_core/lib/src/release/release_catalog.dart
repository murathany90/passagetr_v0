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
