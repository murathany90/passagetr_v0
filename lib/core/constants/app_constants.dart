class AppConstants {
  static const int pageSize = 50;
  static const int testTargetQuestionCount = 10;
  static const int sessionBatchSize = 100;
  static const int testPoolSize = 200;

  // Fallback canonical POS order. UI should prefer repository-distinct values.
  static const List<String> posValues = <String>[
    'prep.',
    'phr. v.',
    'v.',
    'n.',
    'adj.',
    'adv.',
    'NP',
    'conj.',
    'det.',
    'modal',
  ];
}
