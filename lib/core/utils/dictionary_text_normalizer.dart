String normalizeDictionaryQuery(String input) {
  final String lowered = input.toLowerCase();
  return lowered.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String buildDictionarySearchKey(String normalizedWord) {
  final String base = normalizedWord
      .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return base.isEmpty ? normalizedWord : base;
}
