List<String> parseRawList(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <String>[];
  }
  return raw
      .split(';')
      .map((String e) => e.trim())
      .where((String e) => e.isNotEmpty)
      .toList(growable: false);
}
