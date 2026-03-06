class TrUiTexts {
  const TrUiTexts._();

  static const String retry = 'Tekrar Dene';
  static const String refresh = 'Yenile';
  static const String clear = 'Temizle';

  static const String packsAppBarTitle = 'Paketler';
  static const String packListLoadError = 'Paket listesi yüklenemedi.';
  static const String packListEmptyTitle = 'Henüz paket yok';
  static const String packOpenHubCta = 'Paket Merkezini Aç';
  static const String packOnlyReading = 'Sadece paragraf';
  static const String packModesHeader = 'Çalışma Modları';
  static const String wordStudyCta = 'Kelime Çalış';

  static String packWordCount(int count) => '$count kelime';

  static const String wordSearchTitle = 'Kelime / Sözlük Arama';
  static const String wordSearchHint = 'Kelime ara (örn. abandon)';
  static const String searchButton = 'Ara';
  static const String levelHubCta = 'Seviye Merkezi';
  static const String searching = 'Arama yapılıyor...';
  static const String searchError =
      'Arama şu an tamamlanamadı. Tekrar deneyin.';
  static const String searchErrorPrefix = 'Arama hatası:';
  static const String searchInfo =
      'Arama sonucunda kelime kartı varsa "Kelime Kartı", her durumda "Sözlük" sonucuna gidebilirsiniz.';
  static const String wordCardFoundPrefix = 'Kelime kartında bulundu:';
  static const String wordCardMissing =
      'Kelime kartında bulunamadı. Sözlük sonucunu açabilirsiniz.';
  static const String wordCardButton = 'Kelime Kartı';
  static const String dictionaryButton = 'Sözlük';

  static const String levelsLoading = 'Seviyeler yükleniyor...';
  static const String levelListLoadError = 'Seviye listesi yüklenemedi.';
  static const String levelEmptyTitle = 'Seviye bulunamadı';
  static const String levelEmptyMessage =
      'Kelime seviyeleri için veri bulunamadı.';
  static const String levelTitleDefault = 'Seviye';
  static const String levelA1Title = 'Başlangıç';
  static const String levelA2Title = 'Temel Gelişim';
  static const String levelB1Title = 'Orta Seviye';
  static const String levelB2Title = 'Orta-Üst';
  static const String levelC1Title = 'İleri Seviye';
  static const String levelC2Title = 'Akademik Üst';

  static const String wordsLoading = 'Kelimeler yükleniyor...';
  static const String wordListLoadError = 'Kelime listesi yüklenemedi.';
  static const String wordListEmptyTitle = 'Filtreye uygun kelime bulunamadı';
  static const String wordListEmptyMessage =
      'Arama veya etiket/POS filtresini değiştirerek tekrar deneyin.';
  static const String wordsLoadMoreError = 'Sayfa yükleme hatası';
  static const String wordsLoadMore = 'Daha fazla yükle';
  static const String noResults = 'Sonuç bulunamadı';
  static const String searchWordHint = 'Kelime ara (en_word)';
  static const String applyFilters = 'Uygula';
  static const String posFilterLabel = 'Kelime Türü (POS)';
  static const String allPos = 'Tüm POS';
  static const String tagFilterLabel = 'Etiket';
  static const String allTags = 'Tüm Etiketler';
  static const String tagLoading = 'Etiket yükleniyor...';
  static const String searchTagHint = 'Etiket ara';
  static const String filterTagHint = 'Etiket filtre';

  static const String readingPackLoadError = 'Okuma paketleri yüklenemedi.';
  static const String readingPackEmptyTitle = 'Okuma paketi bulunamadı';
  static const String readingPackEmptyMessage =
      'Okuma paketleri için docs/supabase_readings_import.md adımlarını takip edin.';
  static const String readingPackCardTitle = 'Okuma Paketi';
  static const String readingHeroTitle = 'Paragraf Çalış';
  static const String readingHeroSubtitle =
      'Cümle bazlı çalış, çeviriyle pekiştir.';
  static const String readingHeroStart = 'Okumaya Başla';
  static const String csvImportHint =
      'CSV import rehberini docs/supabase_csv_import.md dosyasından takip edin.';

  static String readingHeroSummary(int packCount) {
    return '$packCount okuma paketi hazır. $readingHeroSubtitle';
  }

  static const String sourceLocalDictionary = 'Yerel sözlük';
  static const String sourceServerCache = 'Sunucu önbelleği';
  static const String sourceDeepLFallback = 'DeepL yedeği';
  static const String sourceFallback = 'Yedek kaynak';
  static const String sourceError = 'Hata';
}
