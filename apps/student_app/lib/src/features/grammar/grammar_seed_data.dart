import 'package:flutter/material.dart';

enum GrammarModuleState { completed, inProgress, locked }

class GrammarModuleSeed {
  const GrammarModuleSeed({
    required this.id,
    required this.title,
    required this.pageCount,
    required this.description,
    required this.state,
    required this.progressPercent,
    required this.icon,
    required this.tint,
  });

  final int id;
  final String title;
  final int pageCount;
  final String description;
  final GrammarModuleState state;
  final int progressPercent;
  final IconData icon;
  final Color tint;
}

class GrammarReaderPageSeed {
  const GrammarReaderPageSeed({
    required this.title,
    required this.body,
    required this.highlight,
  });

  final String title;
  final String body;
  final String highlight;
}

class GrammarQuizQuestionSeed {
  const GrammarQuizQuestionSeed({
    required this.prompt,
    required this.options,
    required this.correctAnswer,
  });

  final String prompt;
  final List<String> options;
  final String correctAnswer;
}

class GrammarReaderSeed {
  const GrammarReaderSeed({
    required this.moduleId,
    required this.summary,
    required this.pages,
    required this.quiz,
  });

  final int moduleId;
  final String summary;
  final List<GrammarReaderPageSeed> pages;
  final GrammarQuizQuestionSeed quiz;
}

const grammarModuleSeeds = <GrammarModuleSeed>[
  GrammarModuleSeed(
    id: 1,
    title: 'Temel Kavramlar',
    pageCount: 12,
    description: 'Özneler, nesneler ve fiillerin cümle içindeki rolleri.',
    state: GrammarModuleState.completed,
    progressPercent: 100,
    icon: Icons.check_circle_outline_rounded,
    tint: Color(0xFF32B67A),
  ),
  GrammarModuleSeed(
    id: 2,
    title: 'Tense System (Zamanlar)',
    pageCount: 45,
    description: 'İngilizcedeki tüm zamanların karşılaştırmalı analizi.',
    state: GrammarModuleState.inProgress,
    progressPercent: 30,
    icon: Icons.description_outlined,
    tint: Color(0xFF8A94A6),
  ),
  GrammarModuleSeed(
    id: 3,
    title: 'Modals (Kiplikler)',
    pageCount: 20,
    description: 'Yetenek, zorunluluk, ihtimal ve izin anlatımları.',
    state: GrammarModuleState.locked,
    progressPercent: 0,
    icon: Icons.lock_outline_rounded,
    tint: Color(0xFFBCC6D4),
  ),
  GrammarModuleSeed(
    id: 4,
    title: 'Conditionals (Koşul Cümleleri)',
    pageCount: 18,
    description: 'If clauses Type 0, 1, 2, 3 ve mixed structures.',
    state: GrammarModuleState.locked,
    progressPercent: 0,
    icon: Icons.lock_outline_rounded,
    tint: Color(0xFFBCC6D4),
  ),
];

const grammarReaderSeeds = <int, GrammarReaderSeed>{
  1: GrammarReaderSeed(
    moduleId: 1,
    summary: 'Özne, nesne ve temel cümle dizilimini hızlıca oturt.',
    pages: <GrammarReaderPageSeed>[
      GrammarReaderPageSeed(
        title: 'Özne ve Fiil',
        body:
            'İngilizce temel cümle yapısı çoğunlukla subject + verb + object sırasını takip eder. İlk adımda cümlenin iş yapan unsurunu, yani özneyi net ayırt etmek gerekir.',
        highlight: 'Subject + Verb + Object',
      ),
      GrammarReaderPageSeed(
        title: 'Nesne ve Tamlayıcı',
        body:
            'Bazı fiiller doğrudan nesne alırken bazıları tamamlayıcı ile kullanılır. Özellikle be, seem ve become gibi fiiller sonrasında tamamlayıcı yapı kurulur.',
        highlight: 'She became a doctor.',
      ),
    ],
    quiz: GrammarQuizQuestionSeed(
      prompt: 'Aşağıdakilerden hangisi doğru temel cümle sırasıdır?',
      options: <String>[
        'Verb + Subject + Object',
        'Subject + Verb + Object',
        'Object + Subject + Verb',
      ],
      correctAnswer: 'Subject + Verb + Object',
    ),
  ),
  2: GrammarReaderSeed(
    moduleId: 2,
    summary: 'Simple, continuous ve perfect zamanların farkını kalıplarla gör.',
    pages: <GrammarReaderPageSeed>[
      GrammarReaderPageSeed(
        title: 'Present Simple',
        body:
            'Present Simple; alışkanlıklar, genel gerçekler ve programlı tekrarlar için kullanılır. Yardımcı fiil olarak do/does yapısı soru ve olumsuzda devreye girer.',
        highlight: 'She works every day.',
      ),
      GrammarReaderPageSeed(
        title: 'Present Continuous',
        body:
            'Present Continuous konuşma anında devam eden işleri veya geçici durumları anlatır. Be + verb-ing kalıbı bu zamanın temelidir.',
        highlight: 'They are studying now.',
      ),
      GrammarReaderPageSeed(
        title: 'Present Perfect',
        body:
            'Present Perfect geçmişte başlayıp etkisi süren deneyim ve sonuçlar için kullanılır. Have/has + past participle kalıbı ile kurulur.',
        highlight: 'I have finished my homework.',
      ),
    ],
    quiz: GrammarQuizQuestionSeed(
      prompt: 'Aşağıdaki cümlelerden hangisi Present Continuous örneğidir?',
      options: <String>[
        'I go to work every day.',
        'I am reading a new book.',
        'I have visited London twice.',
      ],
      correctAnswer: 'I am reading a new book.',
    ),
  ),
  3: GrammarReaderSeed(
    moduleId: 3,
    summary: 'Modal yapılar ile izin, zorunluluk ve ihtimal farklarını ayır.',
    pages: <GrammarReaderPageSeed>[
      GrammarReaderPageSeed(
        title: 'Can / Could',
        body:
            'Can ve could; yetenek, rica ve olasılık için kullanılır. Could daha nazik ve daha düşük kesinlikli bir ton taşır.',
        highlight: 'Could you help me?',
      ),
    ],
    quiz: GrammarQuizQuestionSeed(
      prompt: 'Nazik rica için hangi modal daha uygundur?',
      options: <String>['Must', 'Could', 'Should'],
      correctAnswer: 'Could',
    ),
  ),
  4: GrammarReaderSeed(
    moduleId: 4,
    summary: 'Koşul cümlelerinde zaman kayması ve sonuç ilişkisini oturt.',
    pages: <GrammarReaderPageSeed>[
      GrammarReaderPageSeed(
        title: 'Type 1',
        body:
            'Gerçekleşmesi mümkün koşullar için if + present simple, will + verb kalıbı kullanılır.',
        highlight: 'If it rains, we will stay home.',
      ),
    ],
    quiz: GrammarQuizQuestionSeed(
      prompt: 'Gerçekleşmesi muhtemel koşullar için hangi yapı kullanılır?',
      options: <String>['Type 1', 'Type 2', 'Type 3'],
      correctAnswer: 'Type 1',
    ),
  ),
};

GrammarModuleSeed grammarSeedFor(int moduleId) {
  for (final item in grammarModuleSeeds) {
    if (item.id == moduleId) {
      return item;
    }
  }

  return _fallbackGrammarModuleSeed(moduleId);
}

GrammarReaderSeed grammarReaderSeedFor(int moduleId) {
  return grammarReaderSeeds[moduleId] ?? _fallbackGrammarReaderSeed(moduleId);
}

GrammarModuleSeed _fallbackGrammarModuleSeed(int moduleId) {
  const palette = <Color>[
    Color(0xFF4776E6),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFEF4444),
  ];
  return GrammarModuleSeed(
    id: moduleId,
    title: 'Gramer Modülü',
    pageCount: 0,
    description: 'Bu modülün açıklaması yakında güncellenecek.',
    state: GrammarModuleState.inProgress,
    progressPercent: 0,
    icon: Icons.auto_stories_outlined,
    tint: palette[moduleId.abs() % palette.length],
  );
}

GrammarReaderSeed _fallbackGrammarReaderSeed(int moduleId) {
  return GrammarReaderSeed(
    moduleId: moduleId,
    summary: 'Bu modülün ayrıntılı içeriği yakında genişletilecek.',
    pages: const <GrammarReaderPageSeed>[
      GrammarReaderPageSeed(
        title: 'İçerik Hazırlanıyor',
        body:
            'Bu gramer modülü için ayrıntılı anlatım henüz eklenmedi. İçerik yayınlandığında burada konu özeti ve örnekler görünecek.',
        highlight: 'Yeni içerik yakında yayınlanacak.',
      ),
    ],
    quiz: const GrammarQuizQuestionSeed(
      prompt: 'Bu modül için quiz henüz hazır değil.',
      options: <String>['Daha sonra tekrar kontrol et'],
      correctAnswer: 'Daha sonra tekrar kontrol et',
    ),
  );
}
