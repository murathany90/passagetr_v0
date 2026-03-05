import 'package:flutter_test/flutter_test.dart';

import 'package:passagetr/core/utils/passage_word_extractor.dart';

void main() {
  test('extractPassageWordCandidates removes stopwords and punctuation', () {
    final List<String> words = extractPassageWordCandidates(
      <String>[
        'The technology in the office is changing rapidly.',
        'People work with tools and collaboration platforms.',
      ],
      max: 10,
    );

    expect(words.contains('the'), isFalse);
    expect(words.contains('in'), isFalse);
    expect(words.contains('technology'), isTrue);
    expect(words.contains('office'), isTrue);
  });
}

