import 'package:flutter_test/flutter_test.dart';

import 'package:passagetr/core/utils/word_selection_utils.dart';

void main() {
  test('normalizeSelectedWord trims punctuation and lowercases', () {
    expect(normalizeSelectedWord(' "Technology," '), equals('technology'));
  });

  test('normalizeWordToken trims edge punctuation and keeps hyphen/apostrophe',
      () {
    expect(normalizeWordToken(' "Technology," '), equals('technology'));
    expect(normalizeWordToken("students'"), equals('students'));
    expect(normalizeWordToken('state-of-the-art'), equals('state-of-the-art'));
    expect(normalizeWordToken('2026'), equals(''));
  });

  test('dictionary url builders generate expected urls', () {
    expect(
      buildCambridgeDictionaryUrl('Technology').toString(),
      equals('https://dictionary.cambridge.org/dictionary/english/technology'),
    );
    expect(
      buildDictionaryDotComUrl('remote-work').toString(),
      equals('https://www.dictionary.com/browse/remote-work'),
    );
  });
}

