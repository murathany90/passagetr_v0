import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';

void main() {
  const config = AppConfig(
    appName: 'PASSAGETR',
    environment: AppEnvironment.dev,
    platformMode: PlatformMode.web,
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'anon-key',
    adminConsoleUrl: '',
    adminPreviewEnabled: true,
  );

  const request = AdminAiGenerateReadingRequest(topic: 'Ocean science');

  test(
    'AdminAiGenerateReadingRequest serializes provider/model without category fields',
    () {
      const request = AdminAiGenerateReadingRequest(
        topic: 'Ocean science',
        provider: adminAiProviderOpenRouter,
        model: 'qwen/qwen3-coder:free',
      );

      final json = request.toJson();
      final decoded = AdminAiGenerateReadingRequest.fromJson(json);

      expect(decoded.provider, adminAiProviderOpenRouter);
      expect(decoded.model, 'qwen/qwen3-coder:free');
      expect(json.containsKey('category'), isFalse);
      expect(json.containsKey('tags_raw'), isFalse);
    },
  );

  test('maps successful AI response to typed draft', () async {
    final repository = FoundationAdminAiReadingRepository(
      config: config,
      functionInvoker: (_) async => AdminAiReadingFunctionResponse(
        status: 200,
        data: <String, dynamic>{
          'title': 'Ocean Science',
          'level': 'B1',
          'category': 'science',
          'tags_raw': 'ocean, science',
          'sentences': [
            {
              'idx': 1,
              'sentence_en': 'Waves carry energy across the sea.',
              'sentence_tr': 'Dalgalar deniz boyunca enerji tasir.',
            },
          ],
          'suggested_linked_words': [
            {'en_word': 'wave', 'tr_meaning': 'dalga', 'pos': 'noun'},
          ],
          'questions': [
            {
              'sort_order': 1,
              'question': 'What do waves carry?',
              'options': ['Energy', 'Trees'],
              'correct_option_index': 0,
            },
          ],
          'generation_meta': {
            'provider': 'openrouter',
            'model': 'qwen/qwen3-coder:free',
            'topic': 'Ocean science',
            'cefr_level': 'B1',
            'target_word_count': 120,
            'focus_word_count': 5,
            'question_count': 3,
            'actual_word_count': 6,
            'generated_at': '2026-03-13T10:00:00Z',
          },
        },
      ),
    );

    final result = await repository.generateReadingDraft(request);

    expect(result, isA<AppSuccess<AdminAiGeneratedReadingDraft>>());
    final draft = (result as AppSuccess<AdminAiGeneratedReadingDraft>).value;
    expect(draft.title, 'Ocean Science');
    expect(
      draft.sentences.single.sentenceEn,
      'Waves carry energy across the sea.',
    );
    expect(draft.questions.single.options, ['Energy', 'Trees']);
    expect(draft.generationMeta.provider, adminAiProviderOpenRouter);
    expect(draft.generationMeta.model, 'qwen/qwen3-coder:free');
  });

  test('returns controlled failure for malformed schema', () async {
    final repository = FoundationAdminAiReadingRepository(
      config: config,
      functionInvoker: (_) async => AdminAiReadingFunctionResponse(
        status: 200,
        data: <String, dynamic>{
          'title': 'Broken Draft',
          'sentences': [],
          'suggested_linked_words': [],
          'questions': [],
          'generation_meta': {
            'provider': 'gemini',
            'model': 'gemini-test',
            'topic': 'Ocean science',
            'cefr_level': 'B1',
            'target_word_count': 120,
            'focus_word_count': 5,
            'question_count': 3,
            'actual_word_count': 0,
            'generated_at': '2026-03-13T10:00:00Z',
          },
        },
      ),
    );

    final result = await repository.generateReadingDraft(request);

    expect(result, isA<AppFailure<AdminAiGeneratedReadingDraft>>());
    expect(
      (result as AppFailure<AdminAiGeneratedReadingDraft>).message,
      contains('cumle'),
    );
  });

  test('maps function errors to user facing message', () async {
    final repository = FoundationAdminAiReadingRepository(
      config: config,
      functionInvoker: (_) async => AdminAiReadingFunctionResponse(
        status: 403,
        data: <String, dynamic>{'error': 'forbidden'},
      ),
    );

    final result = await repository.generateReadingDraft(request);

    expect(result, isA<AppFailure<AdminAiGeneratedReadingDraft>>());
    expect(
      (result as AppFailure<AdminAiGeneratedReadingDraft>).message,
      'Bu islemi yalniz admin veya developer yapabilir.',
    );
  });

  test('maps rate limited error to quota guidance', () async {
    final repository = FoundationAdminAiReadingRepository(
      config: config,
      functionInvoker: (_) async => AdminAiReadingFunctionResponse(
        status: 429,
        data: <String, dynamic>{'error': 'rate_limited'},
      ),
    );

    final result = await repository.generateReadingDraft(request);

    expect(result, isA<AppFailure<AdminAiGeneratedReadingDraft>>());
    expect(
      (result as AppFailure<AdminAiGeneratedReadingDraft>).message,
      'Secilen AI saglayicisi kota veya billing hatasi verdi. API planini kontrol edin.',
    );
  });

  test('maps invalid jwt exception to re-login guidance', () async {
    final repository = FoundationAdminAiReadingRepository(
      config: config,
      functionInvoker: (_) async => throw Exception(
        'FunctionException(status: 401, details: {code: 401, message: Invalid JWT}, reasonPhrase: )',
      ),
    );

    final result = await repository.generateReadingDraft(request);

    expect(result, isA<AppFailure<AdminAiGeneratedReadingDraft>>());
    expect(
      (result as AppFailure<AdminAiGeneratedReadingDraft>).message,
      'Admin oturumu yenilenemedi. Cikis yapip tekrar giris yapin.',
    );
  });

  test('AdminReadingDetail serializes questions and AI metadata', () {
    final detail = AdminReadingDetail(
      metadata: const AdminContentMetadata(id: 'reading-1'),
      title: 'AI Reading',
      sentences: const [
        AdminReadingSentenceInput(idx: 1, sentenceEn: 'Hello world'),
      ],
      questions: const [
        AdminReadingQuestionInput(
          sortOrder: 1,
          question: 'What is this?',
          options: ['Hello', 'Goodbye'],
          correctOptionIndex: 0,
        ),
      ],
      aiGenerated: true,
      aiGenerationMeta: AdminAiGenerationMeta(
        provider: 'gemini',
        model: 'gemini-test',
        topic: 'Ocean science',
        cefrLevel: 'B1',
        targetWordCount: 120,
        focusWordCount: 5,
        questionCount: 3,
        actualWordCount: 42,
        generatedAt: DateTime.parse('2026-03-13T10:00:00Z'),
      ),
    );

    final json = detail.toJson();
    final decoded = AdminReadingDetail.fromJson(json);

    expect(decoded.questions.single.question, 'What is this?');
    expect(decoded.aiGenerated, isTrue);
    expect(decoded.aiGenerationMeta?.actualWordCount, 42);
  });
}
