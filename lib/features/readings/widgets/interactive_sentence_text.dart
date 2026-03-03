import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/word_selection_utils.dart';

class InteractiveSentenceText extends StatefulWidget {
  const InteractiveSentenceText({
    required this.sentenceText,
    required this.knownWordsSet,
    required this.onWordTap,
    this.baseStyle,
    this.knownStyle,
    super.key,
  });

  final String sentenceText;
  final Set<String> knownWordsSet;
  final ValueChanged<String> onWordTap;
  final TextStyle? baseStyle;
  final TextStyle? knownStyle;

  @override
  State<InteractiveSentenceText> createState() =>
      _InteractiveSentenceTextState();
}

class _InteractiveSentenceTextState extends State<InteractiveSentenceText> {
  static final RegExp _tokenPattern =
      RegExp(r"[A-Za-z0-9]+(?:['-][A-Za-z0-9]+)*|\s+|[^A-Za-z0-9\s]+");

  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final TextStyle fallbackBase = widget.baseStyle ??
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle();
    final TextStyle fallbackKnown = widget.knownStyle ??
        fallbackBase.copyWith(
          fontWeight: FontWeight.w700,
        );

    final List<TextSpan> spans = <TextSpan>[];
    for (final Match match in _tokenPattern.allMatches(widget.sentenceText)) {
      final String raw = match.group(0) ?? '';
      final String normalized = normalizeWordToken(raw);
      final bool isWord = normalized.isNotEmpty;

      if (!isWord) {
        spans.add(TextSpan(text: raw, style: fallbackBase));
        continue;
      }

      final bool isKnown = widget.knownWordsSet.contains(normalized);
      final TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onWordTap(normalized);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: raw,
          style: isKnown ? fallbackKnown : fallbackBase,
          recognizer: recognizer,
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      textScaler: MediaQuery.textScalerOf(context),
      softWrap: true,
    );
  }
}
