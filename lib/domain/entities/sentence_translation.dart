class SentenceTranslation {
  const SentenceTranslation({
    required this.id,
    required this.sentenceId,
    required this.provider,
    required this.targetLang,
    required this.translatedText,
    required this.createdAt,
  });

  final String id;
  final String sentenceId;
  final String provider;
  final String targetLang;
  final String translatedText;
  final DateTime? createdAt;
}
