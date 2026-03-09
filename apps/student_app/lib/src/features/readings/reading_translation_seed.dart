const readingTranslationSeeds = <String, List<String>>{
  'reading-silent-ocean': <String>[
    'Okyanus, Dünya yüzeyinin yüzde yetmişinden fazlasını kaplayan ve büyük bölümü hâlâ keşfedilmemiş olan devasa bir alandır. Teknolojik ilerlemelere rağmen derin okyanus tabanı hakkında Ay yüzeyinden daha az şey biliyoruz. Bu bilinmezlik bilim insanlarını ve kaşifleri hâlâ büyülüyor.',
    'Derinliklere inildikçe ışık tamamen kaybolur ve mutlak karanlık başlar. Basınç son derece yüksektir; yine de yaşam sürer. Biyolüminesans özellikler taşıyan sıra dışı canlılar bu karanlık sularda, bize yabancı görünen uyum mekanizmalarıyla yol alır.',
  ],
  'reading-brief-history': <String>[
    'Modern kozmoloji basit ama güçlü bir soru sorar: Evren nasıl başladı? Bilim insanları uzak galaksileri gözlemler, zayıf radyasyonu ölçer ve uzay ile zamanın doğuşunu açıklayan kuramlar kurar. Her keşif hayal gücümüzün sınırını yeniden çizer.',
    'Teleskoplar yeni galaksiler ve bulutsular ortaya çıkardıkça araştırmacılar kozmik genişleme modellerini sürekli günceller. Yerçekimi ve kara delikler hakkında daha fazlasını öğrendikçe, aslında ne kadar çok bilinmeyen olduğunu da fark ederiz.',
  ],
  'reading-coffee-shops': <String>[
    'İngilizce kahve siparişi vermek, birkaç temel kalıbı öğrendikten sonra oldukça kolaydır. Bir barista içeceği burada mı yoksa paket mi istediğini sorabilir; sen de küçük bir ifade setiyle rahatlıkla cevap verebilirsin.',
    'Süt seçeneği, bardak boyutu ya da fiş isteyip istemediğin sorulabilir. Günlük konuşmada insanlar, paket siparişlerinin hazırlanmasını beklerken kısa bir sohbet de eder.',
  ],
};

String? readingTranslationFor(String readingId, int sectionIndex) {
  final sections = readingTranslationSeeds[readingId];
  if (sections == null || sectionIndex >= sections.length) {
    return null;
  }

  return sections[sectionIndex];
}
