import 'dart:math' as math;

/// Result of a typing answer evaluation.
enum TypingResult {
  /// The answer is an exact character-for-character match.
  exact,

  /// The answer is within the acceptable edit-distance threshold.
  nearMatch,

  /// The answer is too far from the expected text.
  wrong,
}

/// Computes the Levenshtein (edit) distance between [a] and [b].
///
/// The distance is the minimum number of single-character edits
/// (insertions, deletions, substitutions) required to transform [a] into [b].
int levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  // Use two-row DP to save memory.
  List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
  List<int> current = List<int>.filled(b.length + 1, 0);

  for (int i = 1; i <= a.length; i++) {
    current[0] = i;
    for (int j = 1; j <= b.length; j++) {
      final int cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
    }
    // Swap rows.
    final List<int> temp = previous;
    previous = current;
    current = temp;
  }

  return previous[b.length];
}

/// Evaluates a typing answer against the expected text using Levenshtein
/// distance with a length-dependent threshold.
///
/// * Short words (≤ 5 characters): 1 edit allowed → [TypingResult.nearMatch]
/// * Longer words: 2 edits allowed → [TypingResult.nearMatch]
/// * Beyond threshold → [TypingResult.wrong]
/// * Exact match → [TypingResult.exact]
TypingResult checkTypingAnswer(String expected, String actual) {
  if (expected == actual) return TypingResult.exact;

  final int distance = levenshteinDistance(expected, actual);
  final int threshold = expected.length <= 5 ? 1 : 2;

  if (distance <= threshold) return TypingResult.nearMatch;
  return TypingResult.wrong;
}
