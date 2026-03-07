import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tts_service.dart';
import '../../state/tts_providers.dart';

/// A compact speaker button that reads [text] aloud via TTS.
///
/// Drop this widget next to any English word or sentence to give the
/// user instant pronunciation feedback.
class AppSpeakButton extends ConsumerWidget {
  const AppSpeakButton({
    required this.text,
    this.iconSize = 20,
    this.language = SpeechLanguage.english,
    super.key,
  });

  /// The English text to speak when tapped.
  final String text;

  /// Icon size (defaults to 20).
  final double iconSize;
  final SpeechLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.volume_up_rounded, size: iconSize),
      tooltip: language == SpeechLanguage.english
          ? 'Ingilizce okunus'
          : 'Seslendir',
      visualDensity: VisualDensity.compact,
      onPressed: () =>
          ref.read(ttsServiceProvider).speak(text, language: language),
    );
  }
}
