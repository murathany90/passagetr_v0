import 'package:shared_domain/shared_domain.dart';

import 'reading_seed_data.dart';

/// Represents a section of the reading article with English and optional Turkish text.
class ReadingArticleSection {
  const ReadingArticleSection({
    required this.lookupIndex,
    required this.heading,
    required this.englishText,
    this.turkishText,
  });

  final int lookupIndex;
  final String heading;
  final String englishText;
  final String? turkishText;
}

/// Represents a word selected for dictionary lookup within a sentence.
class SelectedDictionaryWord {
  const SelectedDictionaryWord({
    required this.displayWord,
    required this.lookupQuery,
  });

  final String displayWord;
  final String lookupQuery;
}

/// Holds the previous and next readings relative to the current reading.
class AdjacentReadings {
  const AdjacentReadings({this.previous, this.next});

  final ReadingPassage? previous;
  final ReadingPassage? next;
}

/// Result of a reading comprehension quiz.
class ReadingQuizResult {
  const ReadingQuizResult({
    required this.correctCount,
    required this.wrongCount,
    required this.score,
  });

  final int correctCount;
  final int wrongCount;
  final int score;
}

/// A single word token parsed from a sentence, with optional linked word card.
class SentenceToken {
  const SentenceToken({
    required this.displayWord,
    required this.lookupQuery,
    this.wordCard,
  });

  final String displayWord;
  final String lookupQuery;
  final WordEntry? wordCard;

  bool get isLookupable => lookupQuery.isNotEmpty;
}

final RegExp _tokenPattern = RegExp(r'\S+');
final RegExp _edgePunctuationPattern = RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$');

/// Tokenizes a sentence into [SentenceToken]s, linking focus words.
List<SentenceToken> tokenizeSentence(
  String text,
  List<WordEntry> focusWordCards,
) {
  final rawTokens = _tokenPattern
      .allMatches(text)
      .map(
        (match) => _RawSentenceToken(
          displayWord: match.group(0) ?? '',
          normalized: normalizeDictionaryQuery(match.group(0) ?? ''),
        ),
      )
      .where((token) => token.displayWord.isNotEmpty)
      .toList(growable: false);
  if (rawTokens.isEmpty) {
    return const <SentenceToken>[];
  }

  final focusPhrases =
      focusWordCards
          .map((item) {
            final parts = item.enWord
                .split(RegExp(r'\s+'))
                .map(normalizeDictionaryQuery)
                .where((part) => part.isNotEmpty)
                .toList(growable: false);
            return _FocusPhrase(word: item, parts: parts);
          })
          .where((item) => item.parts.isNotEmpty)
          .toList(growable: false)
        ..sort(
          (left, right) => right.parts.length.compareTo(left.parts.length),
        );

  final matchedWords = List<WordEntry?>.filled(rawTokens.length, null);
  for (var index = 0; index < rawTokens.length; index++) {
    if (matchedWords[index] != null) {
      continue;
    }

    for (final phrase in focusPhrases) {
      if (phrase.parts.length == 1 &&
          rawTokens[index].normalized == phrase.parts.first) {
        matchedWords[index] = phrase.word;
        break;
      }

      if (index + phrase.parts.length > rawTokens.length) {
        continue;
      }

      var matches = true;
      for (var partIndex = 0; partIndex < phrase.parts.length; partIndex++) {
        if (rawTokens[index + partIndex].normalized !=
            phrase.parts[partIndex]) {
          matches = false;
          break;
        }
      }
      if (!matches) {
        continue;
      }

      for (var partIndex = 0; partIndex < phrase.parts.length; partIndex++) {
        matchedWords[index + partIndex] = phrase.word;
      }
      break;
    }
  }

  return List<SentenceToken>.generate(rawTokens.length, (index) {
    final token = rawTokens[index];
    return SentenceToken(
      displayWord: token.displayWord,
      lookupQuery: token.normalized,
      wordCard: matchedWords[index],
    );
  }, growable: false);
}

/// Normalizes a word for dictionary lookup by lowercasing and stripping
/// edge punctuation.
String normalizeDictionaryQuery(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('\u2019', "'")
      .replaceAll(_edgePunctuationPattern, '');
}

/// Resolves article sections from either remote data or seed data.
List<ReadingArticleSection> resolveArticleSections(
  ReadingSeedData seed,
  List<ReadingSentence>? remoteSections,
) {
  if (remoteSections != null && remoteSections.isNotEmpty) {
    final sections = <ReadingArticleSection>[];
    for (var i = 0; i < remoteSections.length; i++) {
      final section = remoteSections[i];
      final englishText = section.englishText.trim();
      if (englishText.isEmpty) {
        continue;
      }
      sections.add(
        ReadingArticleSection(
          lookupIndex: i,
          heading: '',
          englishText: englishText,
          turkishText: _trimToNull(section.turkishText),
        ),
      );
    }
    return sections;
  }

  final sections = <ReadingArticleSection>[];
  for (var i = 0; i < seed.sections.length; i++) {
    final section = seed.sections[i];
    if (section.body.trim().isEmpty) {
      continue;
    }
    sections.add(
      ReadingArticleSection(
        lookupIndex: i,
        heading: section.heading,
        englishText: section.body,
      ),
    );
  }
  return sections;
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

/// Creates a fallback [WordEntry] from a [ReadingFocusWord].
WordEntry fallbackWordEntry(ReadingFocusWord word) {
  return WordEntry(
    id: word.wordId,
    packId: '',
    enWord: word.enWord,
    trMeaning: word.trMeaning,
    pos: word.pos ?? '',
  );
}

/// Resolves linked word cards from focus words and a word card map.
List<WordEntry> resolveLinkedWordCards(
  List<ReadingFocusWord> focusWords,
  Map<String, WordEntry> wordCardsById,
) {
  return focusWords
      .map((item) => wordCardsById[item.wordId] ?? fallbackWordEntry(item))
      .toList(growable: false);
}

// --- Private types ---

class _RawSentenceToken {
  const _RawSentenceToken({
    required this.displayWord,
    required this.normalized,
  });

  final String displayWord;
  final String normalized;
}

class _FocusPhrase {
  const _FocusPhrase({required this.word, required this.parts});

  final WordEntry word;
  final List<String> parts;
}
