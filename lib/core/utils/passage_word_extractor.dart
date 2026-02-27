const Set<String> _defaultStopwords = <String>{
  'a',
  'an',
  'the',
  'of',
  'to',
  'in',
  'on',
  'for',
  'with',
  'at',
  'by',
  'from',
  'as',
  'is',
  'are',
  'was',
  'were',
  'be',
  'been',
  'being',
  'and',
  'or',
  'but',
  'if',
  'then',
  'than',
  'that',
  'this',
  'these',
  'those',
  'it',
  'its',
  'into',
  'about',
  'after',
  'before',
  'over',
  'under',
  'up',
  'down',
};

List<String> extractPassageWordCandidates(
  Iterable<String> sentences, {
  int max = 20,
}) {
  final Set<String> unique = <String>{};
  for (final String sentence in sentences) {
    final List<String> words = sentence
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .where((String e) => !_defaultStopwords.contains(e))
        .where((String e) => e.length > 1)
        .toList(growable: false);

    for (final String word in words) {
      unique.add(word);
      if (unique.length >= max) {
        return unique.toList(growable: false);
      }
    }
  }
  return unique.toList(growable: false);
}
