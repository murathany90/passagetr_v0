String normalizeSelectedWord(String raw) {
  String value = raw.trim().toLowerCase();
  value = value.replaceAll(RegExp(r'''[,.!?:;"'\(\)\[\]\{\}/\\|]'''), ' ');
  value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.isEmpty) {
    return '';
  }
  return value.split(' ').first;
}

String normalizeWordToken(String raw) {
  String value = raw.trim().toLowerCase();
  if (value.isEmpty) {
    return '';
  }

  value = value.replaceAll('’', '\'');
  value = value.replaceAll(RegExp(r"^[^a-z0-9'-]+"), '');
  value = value.replaceAll(RegExp(r"[^a-z0-9'-]+$"), '');

  if (value.isEmpty) {
    return '';
  }

  // Collapse repeated separators and strip dangling separators.
  value = value.replaceAll(RegExp(r"[-']{2,}"), '-');
  value = value.replaceAll(RegExp(r"^[-']+"), '');
  value = value.replaceAll(RegExp(r"[-']+$"), '');

  if (value.endsWith("'s")) {
    value = value.substring(0, value.length - 2);
  }
  value = value.replaceAll(RegExp(r"'+$"), '');

  value = value.trim();
  if (!RegExp(r'[a-z]').hasMatch(value)) {
    return '';
  }
  return value;
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
