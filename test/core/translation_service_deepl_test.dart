import 'package:flutter_test/flutter_test.dart';

import 'package:passagetr/core/services/translation_service.dart';

void main() {
  test('DeeplEdgeFunctionTranslationService parses translatedText', () async {
    final DeeplEdgeFunctionTranslationService service =
        DeeplEdgeFunctionTranslationService(
      invokeOverride: (Map<String, dynamic> body) async {
        expect(body['text'], equals('technology'));
        expect(body['source'], equals('EN'));
        expect(body['target'], equals('TR'));
        return const DeeplFunctionResponse(
          status: 200,
          data: <String, dynamic>{'translatedText': 'teknoloji'},
        );
      },
    );

    final String translated = await service.translateEnToTr('technology');
    expect(translated, equals('teknoloji'));
  });

  test('DeeplEdgeFunctionTranslationService maps 429 to user-friendly error',
      () async {
    final DeeplEdgeFunctionTranslationService service =
        DeeplEdgeFunctionTranslationService(
      invokeOverride: (Map<String, dynamic> body) async {
        return const DeeplFunctionResponse(
          status: 429,
          data: <String, dynamic>{'message': 'quota exceeded'},
        );
      },
    );

    expect(
      () => service.translateEnToTr('network'),
      throwsA(
        isA<TranslationException>().having(
          (TranslationException e) => e.message,
          'message',
          contains('Ceviri siniri asildi'),
        ),
      ),
    );
  });
}

