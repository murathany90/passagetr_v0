String normalizeSelectedWord(String raw) {
  String value = raw.trim().toLowerCase();
  value = value.replaceAll(RegExp(r'''[,.!?:;"'\(\)\[\]\{\}/\\|]'''), ' ');
  value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.isEmpty) {
    return '';
  }
  return value.split(' ').first;
}

Uri buildCambridgeDictionaryUrl(String word) {
  final String normalized = normalizeSelectedWord(word);
  return Uri.parse(
    'https://dictionary.cambridge.org/dictionary/english/${Uri.encodeComponent(normalized)}',
  );
}

Uri buildDictionaryDotComUrl(String word) {
  final String normalized = normalizeSelectedWord(word);
  return Uri.parse(
    'https://www.dictionary.com/browse/${Uri.encodeComponent(normalized)}',
  );
}
