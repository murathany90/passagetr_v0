import 'package:flutter/material.dart';

import '../../../core/utils/word_selection_utils.dart';

class InteractiveSentenceText extends StatelessWidget {
  const InteractiveSentenceText({
    required this.sentenceText,
    required this.highlightedWordsSet,
    required this.onWordTap,
    required this.onSentenceLongPress,
    this.onSentenceDoubleTap,
    this.gestureKey,
    this.baseStyle,
    this.highlightStyle,
    super.key,
  });

  final String sentenceText;
  final Set<String> highlightedWordsSet;
  final ValueChanged<SentenceWordTapDetail> onWordTap;
  final ValueChanged<SentenceTapDetail> onSentenceLongPress;
  final ValueChanged<SentenceTapDetail>? onSentenceDoubleTap;
  final Key? gestureKey;
  final TextStyle? baseStyle;
  final TextStyle? highlightStyle;

  static final RegExp _tokenPattern =
      RegExp(r"[A-Za-z0-9]+(?:['-][A-Za-z0-9]+)*|\s+|[^A-Za-z0-9\s]+");

  @override
  Widget build(BuildContext context) {
    final TextStyle fallbackBase = baseStyle ??
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle();
    final TextStyle fallbackHighlight = highlightStyle ??
        fallbackBase.copyWith(
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
        );

    Offset doubleTapPosition = Offset.zero;
    final List<InlineSpan> spans = <InlineSpan>[];
    for (final Match match in _tokenPattern.allMatches(sentenceText)) {
      final String raw = match.group(0) ?? '';
      final String normalized = normalizeWordToken(raw);
      final bool isWord = normalized.isNotEmpty;

      if (!isWord) {
        spans.add(TextSpan(text: raw, style: fallbackBase));
        continue;
      }

      Offset tapPosition = Offset.zero;
      final bool isHighlighted = highlightedWordsSet.contains(normalized);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            key: ValueKey<String>('interactive-word-$normalized-${match.start}'),
            behavior: HitTestBehavior.translucent,
            onTapDown: (TapDownDetails details) {
              tapPosition = details.globalPosition;
            },
            onTap: () {
              onWordTap(
                SentenceWordTapDetail(
                  word: normalized,
                  globalPosition: tapPosition,
                ),
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                raw,
                style: isHighlighted ? fallbackHighlight : fallbackBase,
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      key: gestureKey,
      behavior: HitTestBehavior.translucent,
      onDoubleTapDown: onSentenceDoubleTap == null
          ? null
          : (TapDownDetails details) {
              doubleTapPosition = details.globalPosition;
            },
      onDoubleTap: onSentenceDoubleTap == null
          ? null
          : () {
              onSentenceDoubleTap!(
                SentenceTapDetail(globalPosition: doubleTapPosition),
              );
            },
      onLongPressStart: (LongPressStartDetails details) {
        onSentenceLongPress(
          SentenceTapDetail(globalPosition: details.globalPosition),
        );
      },
      child: RichText(
        text: TextSpan(
          style: fallbackBase,
          children: spans,
        ),
        textScaler: MediaQuery.textScalerOf(context),
        softWrap: true,
      ),
    );
  }
}

class SentenceTapDetail {
  const SentenceTapDetail({
    required this.globalPosition,
  });

  final Offset globalPosition;
}

class SentenceWordTapDetail {
  const SentenceWordTapDetail({
    required this.word,
    required this.globalPosition,
  });

  final String word;
  final Offset globalPosition;
}
