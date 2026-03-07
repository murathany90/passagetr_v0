import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/services/tts_service.dart';

void main() {
  test('selectPreferredVoice prefers en-US then en-GB for english', () {
    final Map<String, String>? voice = TtsService.selectPreferredVoice(
      <Map<String, String>>[
        <String, String>{'name': 'British', 'locale': 'en-GB'},
        <String, String>{'name': 'US', 'locale': 'en-US'},
      ],
      language: SpeechLanguage.english,
    );

    expect(voice?['locale'], 'en-US');
  });

  test(
    'selectPreferredVoice falls back to null when no matching locale exists',
    () {
      final Map<String, String>? voice = TtsService.selectPreferredVoice(
        <Map<String, String>>[
          <String, String>{'name': 'German', 'locale': 'de-DE'},
        ],
        language: SpeechLanguage.english,
      );

      expect(voice, isNull);
    },
  );
}
