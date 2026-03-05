import 'package:flutter_test/flutter_test.dart';

import 'package:ingilizce_app1/core/utils/levenshtein.dart';

void main() {
  group('levenshteinDistance', () {
    test('identical strings return 0', () {
      expect(levenshteinDistance('ability', 'ability'), 0);
    });

    test('empty vs non-empty returns length', () {
      expect(levenshteinDistance('', 'abc'), 3);
      expect(levenshteinDistance('abc', ''), 3);
    });

    test('both empty returns 0', () {
      expect(levenshteinDistance('', ''), 0);
    });

    test('classic kitten → sitting = 3', () {
      expect(levenshteinDistance('kitten', 'sitting'), 3);
    });

    test('single substitution', () {
      expect(levenshteinDistance('cat', 'bat'), 1);
    });

    test('single insertion', () {
      expect(levenshteinDistance('cat', 'cats'), 1);
    });

    test('single deletion', () {
      expect(levenshteinDistance('cats', 'cat'), 1);
    });

    test('completely different strings', () {
      expect(levenshteinDistance('abc', 'xyz'), 3);
    });
  });

  group('checkTypingAnswer', () {
    test('exact match returns exact', () {
      expect(checkTypingAnswer('ability', 'ability'), TypingResult.exact);
    });

    test('one edit on long word (>5 chars) returns nearMatch', () {
      // "abilty" → missing 'i' at position 4: distance = 1
      expect(checkTypingAnswer('ability', 'abilty'), TypingResult.nearMatch);
    });

    test('two edits on long word returns nearMatch', () {
      // "abiltiy" → transposition-like: distance = 2
      expect(checkTypingAnswer('ability', 'abiltiy'), TypingResult.nearMatch);
    });

    test('three edits on long word returns wrong', () {
      expect(checkTypingAnswer('ability', 'abilxyz'), TypingResult.wrong);
    });

    test('one edit on short word (<=5 chars) returns nearMatch', () {
      expect(checkTypingAnswer('cat', 'bat'), TypingResult.nearMatch);
    });

    test('two edits on short word returns wrong (threshold is 1)', () {
      expect(checkTypingAnswer('cat', 'bax'), TypingResult.wrong);
    });

    test('completely wrong returns wrong', () {
      expect(checkTypingAnswer('ability', 'xyz'), TypingResult.wrong);
    });

    test('empty actual returns wrong for non-empty expected', () {
      expect(checkTypingAnswer('hello', ''), TypingResult.wrong);
    });

    test('both empty returns exact', () {
      expect(checkTypingAnswer('', ''), TypingResult.exact);
    });
  });
}
