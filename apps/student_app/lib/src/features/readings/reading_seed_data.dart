import 'package:flutter/material.dart';
import 'package:shared_domain/shared_domain.dart';

const fallbackReadingSummaryPlaceholder =
    'Bu okuma icin ozet ve ceviri destegi yakinda genisletilecek.';

class ReadingSectionSeed {
  const ReadingSectionSeed({required this.heading, required this.body});

  final String heading;
  final String body;
}

class ReadingFocusWordSeed {
  const ReadingFocusWordSeed({required this.word, required this.meaning});

  final String word;
  final String meaning;
}

class ReadingSeedData {
  const ReadingSeedData({
    required this.id,
    required this.summary,
    required this.author,
    required this.durationMinutes,
    required this.progressPercent,
    required this.levelBadgeColor,
    required this.artworkColors,
    required this.artworkIcon,
    this.imageAsset,
    required this.sections,
    required this.focusWords,
  });

  final String id;
  final String summary;
  final String author;
  final int durationMinutes;
  final int progressPercent;
  final Color levelBadgeColor;
  final List<Color> artworkColors;
  final IconData artworkIcon;
  final String? imageAsset;
  final List<ReadingSectionSeed> sections;
  final List<ReadingFocusWordSeed> focusWords;

  bool get isCompleted => progressPercent >= 100;
}

const readingSeedData = <String, ReadingSeedData>{
  'reading-silent-ocean': ReadingSeedData(
    id: 'reading-silent-ocean',
    summary:
        'Derin deniz kesiflerinin bilinmeyen dunyasi ve okyanusun karanlik sirlari uzerine buyuleyici bir arastirma.',
    author: 'Jane Doe',
    durationMinutes: 15,
    progressPercent: 45,
    levelBadgeColor: Color(0xFFF05D80),
    artworkColors: <Color>[
      Color(0xFFD8C7AA),
      Color(0xFF8F6A49),
      Color(0xFF172029),
    ],
    artworkIcon: Icons.landscape_rounded,
    imageAsset: 'assets/images/readings/silent_ocean.webp',
    sections: <ReadingSectionSeed>[
      ReadingSectionSeed(
        heading: '',
        body:
            "The ocean is a vast and largely unexplored territory that covers more than 70 percent of the Earth's surface. Despite our technological advancements, we still know more about the surface of the moon than we do about the deep ocean floor. This profound mystery continues to captivate scientists and explorers alike.",
      ),
      ReadingSectionSeed(
        heading: 'The Abyssal Zone',
        body:
            'Descending into the abyss, the light fades entirely, leaving a world of complete darkness. Here, the pressure is crushing, yet life finds a way. Bizarre creatures with bioluminescent features navigate these black waters, relying on adaptations that seem almost alien to us.',
      ),
    ],
    focusWords: <ReadingFocusWordSeed>[
      ReadingFocusWordSeed(word: 'Territory', meaning: 'Bolge, alan'),
      ReadingFocusWordSeed(word: 'Mystery', meaning: 'Gizem, sir'),
      ReadingFocusWordSeed(word: 'Abyss', meaning: 'Ucurum, derinlik'),
      ReadingFocusWordSeed(
        word: 'Adaptations',
        meaning: 'Adaptasyonlar, uyumlar',
      ),
      ReadingFocusWordSeed(word: 'Captivate', meaning: 'Cezbetmek, buyulemek'),
    ],
  ),
  'reading-brief-history': ReadingSeedData(
    id: 'reading-brief-history',
    summary:
        "Stephen Hawking'in unlu eserinden alinmis kisa bir ozet parcasi. Evrenin baslangici ve sonu.",
    author: 'Stephen Hawking',
    durationMinutes: 10,
    progressPercent: 0,
    levelBadgeColor: Color(0xFFF2A646),
    artworkColors: <Color>[
      Color(0xFF45D4E6),
      Color(0xFF24438F),
      Color(0xFF30163F),
    ],
    artworkIcon: Icons.auto_awesome_rounded,
    imageAsset: 'assets/images/readings/brief_history.webp',
    sections: <ReadingSectionSeed>[
      ReadingSectionSeed(
        heading: '',
        body:
            'Modern cosmology asks a simple but powerful question: how did the universe begin? Scientists observe distant galaxies, measure faint radiation, and build theories to explain the birth of space and time. Every discovery changes the scale of our imagination.',
      ),
      ReadingSectionSeed(
        heading: 'Expanding Space',
        body:
            'As telescopes reveal new galaxies and nebulae, researchers continue to refine their models of cosmic expansion. The more we learn about gravity and black holes, the more we realize how much remains unknown.',
      ),
    ],
    focusWords: <ReadingFocusWordSeed>[
      ReadingFocusWordSeed(word: 'Cosmology', meaning: 'Kozmoloji'),
      ReadingFocusWordSeed(word: 'Galaxy', meaning: 'Galaksi'),
      ReadingFocusWordSeed(word: 'Radiation', meaning: 'Isinim, radyasyon'),
      ReadingFocusWordSeed(word: 'Expansion', meaning: 'Genisleme'),
    ],
  ),
  'reading-coffee-shops': ReadingSeedData(
    id: 'reading-coffee-shops',
    summary:
        'Bir kafede kahve siparis ederken ve sohbet ederken kullanilan gunluk Ingilizce kaliplari.',
    author: 'PASSAGETR Team',
    durationMinutes: 5,
    progressPercent: 100,
    levelBadgeColor: Color(0xFF37A981),
    artworkColors: <Color>[
      Color(0xFF3D281D),
      Color(0xFF765232),
      Color(0xFFE6D1B8),
    ],
    artworkIcon: Icons.local_cafe_rounded,
    imageAsset: 'assets/images/readings/coffee_shops.webp',
    sections: <ReadingSectionSeed>[
      ReadingSectionSeed(
        heading: '',
        body:
            'Ordering coffee in English can be surprisingly simple once you know a few key phrases. A barista may ask whether you want your drink for here or to go, and you can answer confidently with a small set of expressions.',
      ),
      ReadingSectionSeed(
        heading: 'Useful Phrases',
        body:
            'You might hear questions about milk options, cup size, or whether you need a receipt. In casual conversation, people often add small talk while waiting for their takeaway order to be ready.',
      ),
    ],
    focusWords: <ReadingFocusWordSeed>[
      ReadingFocusWordSeed(word: 'Barista', meaning: 'Kahve gorevlisi'),
      ReadingFocusWordSeed(word: 'Receipt', meaning: 'Fis, makbuz'),
      ReadingFocusWordSeed(word: 'Takeaway', meaning: 'Paket servis'),
      ReadingFocusWordSeed(
        word: 'Confidently',
        meaning: 'Kendinden emin sekilde',
      ),
    ],
  ),
};

ReadingSeedData readingSeedFor(String readingId) {
  return readingSeedData[readingId] ?? readingSeedData.values.first;
}

ReadingSeedData readingSeedForPassage(ReadingPassage passage) {
  final seeded = readingSeedData[passage.id];
  if (seeded != null) {
    return seeded;
  }

  return _fallbackReadingSeedForPassage(passage);
}

bool isFallbackReadingSummary(String? summary) {
  return (summary ?? '').trim() == fallbackReadingSummaryPlaceholder;
}

ReadingSeedData _fallbackReadingSeedForPassage(ReadingPassage passage) {
  const palettes = <List<Color>>[
    <Color>[Color(0xFF1D4ED8), Color(0xFF0F172A), Color(0xFF38BDF8)],
    <Color>[Color(0xFF059669), Color(0xFF064E3B), Color(0xFFFDE68A)],
    <Color>[Color(0xFF7C3AED), Color(0xFF312E81), Color(0xFFF472B6)],
    <Color>[Color(0xFFDC2626), Color(0xFF7F1D1D), Color(0xFFF97316)],
  ];
  final seedIndex =
      (passage.category ?? passage.level ?? passage.id).hashCode.abs() %
      palettes.length;
  final summary = (passage.summary?.trim().isNotEmpty ?? false)
      ? passage.summary!.trim()
      : fallbackReadingSummaryPlaceholder;

  return ReadingSeedData(
    id: passage.id,
    summary: summary,
    author: 'PASSAGETR',
    durationMinutes: _estimateReadingDuration(summary),
    progressPercent: 0,
    levelBadgeColor: _fallbackLevelColor(passage.level),
    artworkColors: palettes[seedIndex],
    artworkIcon: _fallbackArtworkIcon(passage.category),
    sections: <ReadingSectionSeed>[
      ReadingSectionSeed(heading: '', body: summary),
    ],
    focusWords: const <ReadingFocusWordSeed>[],
  );
}

int _estimateReadingDuration(String summary) {
  final wordCount = summary
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .length;
  return wordCount <= 18 ? 4 : 6;
}

Color _fallbackLevelColor(String? level) {
  switch ((level ?? '').toUpperCase()) {
    case 'A1':
    case 'A2':
      return const Color(0xFF10B981);
    case 'B1':
    case 'B2':
      return const Color(0xFFF59E0B);
    case 'C1':
    case 'C2':
      return const Color(0xFF8B5CF6);
    default:
      return const Color(0xFF38BDF8);
  }
}

IconData _fallbackArtworkIcon(String? category) {
  final normalized = (category ?? '').toLowerCase();
  if (normalized.contains('science') || normalized.contains('bilim')) {
    return Icons.biotech_outlined;
  }
  if (normalized.contains('history') || normalized.contains('tarih')) {
    return Icons.account_balance_outlined;
  }
  if (normalized.contains('travel') || normalized.contains('seyahat')) {
    return Icons.travel_explore_outlined;
  }
  if (normalized.contains('business') || normalized.contains('is')) {
    return Icons.cases_outlined;
  }
  return Icons.auto_stories_outlined;
}
