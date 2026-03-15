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

  test('maps generated reading questions from named function', () async {
    final repository = FoundationAdminAiReadingRepository(
      config: config,
      namedFunctionInvoker: (functionName, body) async {
        expect(functionName, 'admin_ai_generate_reading_questions');
        expect(body, isA<Map<String, dynamic>>());
        return AdminAiReadingFunctionResponse(
          status: 200,
          data: <String, dynamic>{
            'questions': [
              {
                'sort_order': 1,
                'question': 'What moves across the sea?',
                'options': ['Waves', 'Cars'],
                'correct_option_index': 0,
                'explanation': 'The passage says waves carry energy.',
              },
            ],
            'provider': 'gemini',
            'model': 'gemini-2.5-flash',
            'generated_at': '2026-03-14T10:00:00Z',
          },
        );
      },
    );

    final result = await repository.generateReadingQuestions(
      const AdminAiGenerateReadingQuestionsRequest(readingId: 'reading-1'),
    );

    expect(result, isA<AppSuccess<AdminAiGeneratedReadingQuestions>>());
    final value =
        (result as AppSuccess<AdminAiGeneratedReadingQuestions>).value;
    expect(value.questions, hasLength(1));
    expect(value.questions.single.correctOptionIndex, 0);
    expect(value.provider, adminAiProviderGemini);
  });

  test('maps generated reading cover detail from named function', () async {
    final repository = FoundationAdminAiReadingRepository(
      config: config,
      namedFunctionInvoker: (functionName, body) async {
        expect(functionName, 'admin_ai_generate_reading_cover');
        expect(body, isA<Map<String, dynamic>>());
        expect(
          body,
          <String, dynamic>{
            'reading_id': 'reading-1',
            'provider': adminAiProviderOpenAiImages,
            'model': adminAiOpenAiImageDefaultModel,
          },
        );
        return AdminAiReadingFunctionResponse(
          status: 200,
          data: <String, dynamic>{
            'id': 'reading-1',
            'title': 'Ocean Science',
            'sentences': [
              {'idx': 1, 'sentence_en': 'Waves carry energy across the sea.'},
            ],
            'cover_media_asset_id': 'asset-1',
            'cover_bucket_name': 'reading-covers',
            'cover_storage_path': 'readings/reading-1/asset-1.png',
            'cover_alt_text': 'Ocean Science cover',
            'cover_generation_meta': {'provider': 'openai-images'},
          },
        );
      },
    );

    final result = await repository.generateReadingCover(
      const AdminAiGenerateReadingCoverRequest(
        readingId: 'reading-1',
        provider: adminAiProviderOpenAiImages,
        model: adminAiOpenAiImageDefaultModel,
      ),
    );

    expect(result, isA<AppSuccess<AdminReadingDetail>>());
    final value = (result as AppSuccess<AdminReadingDetail>).value;
    expect(value.cover.hasCover, isTrue);
    expect(value.cover.bucketName, 'reading-covers');
    expect(value.cover.storagePath, 'readings/reading-1/asset-1.png');
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

  test('lists active AI runs from admin RPC', () async {
    final repository = FoundationAdminAiReadingRepository(
      config: config,
      rpcInvoker: (functionName, {params = const <String, dynamic>{}}) async {
        expect(functionName, 'admin_list_active_reading_ai_runs');
        expect(params, isEmpty);
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'run-1',
            'job_type': 'cover_backfill',
            'status': 'paused',
            'provider': adminAiProviderGeminiImage,
            'model': adminAiGeminiImageDefaultModel,
            'question_count': 3,
            'total_count': 12,
            'processed_count': 7,
            'succeeded_count': 4,
            'failed_count': 3,
            'skipped_count': 0,
            'failure_samples': const <String>['sample error'],
            'pause_reason': 'auto_failure_threshold',
            'last_error_message': 'Last failure',
            'consecutive_failure_count': 5,
            'filter_snapshot': const <String, dynamic>{'has_cover': false},
          },
        ];
      },
    );

    final result = await repository.listActiveReadingAiRuns();

    expect(result, isA<AppSuccess<List<AdminAiReadingRun>>>());
    final runs = (result as AppSuccess<List<AdminAiReadingRun>>).value;
    expect(runs, hasLength(1));
    expect(runs.single.isPaused, isTrue);
    expect(runs.single.pauseReason, 'auto_failure_threshold');
    expect(runs.single.consecutiveFailureCount, 5);
    expect(runs.single.filterSnapshot['has_cover'], isFalse);
  });

  test('controls AI run through admin RPC', () async {
    final repository = FoundationAdminAiReadingRepository(
      config: config,
      rpcInvoker: (functionName, {params = const <String, dynamic>{}}) async {
        expect(functionName, 'admin_control_reading_ai_run');
        expect(params['p_payload'], <String, dynamic>{
          'run_id': 'run-1',
          'action': 'resume',
          'provider': adminAiProviderOpenAiImages,
          'model': adminAiOpenAiImageDefaultModel,
          'question_count': null,
        });
        return <String, dynamic>{
          'id': 'run-1',
          'job_type': 'cover_backfill',
          'status': 'running',
          'provider': adminAiProviderOpenAiImages,
          'model': adminAiOpenAiImageDefaultModel,
          'question_count': 3,
          'total_count': 12,
          'processed_count': 7,
          'succeeded_count': 4,
          'failed_count': 3,
          'skipped_count': 0,
          'failure_samples': const <String>[],
          'pause_reason': null,
          'last_error_message': null,
          'consecutive_failure_count': 0,
          'filter_snapshot': const <String, dynamic>{'has_cover': false},
        };
      },
    );

    final result = await repository.controlReadingAiRun(
      runId: 'run-1',
      action: 'resume',
      provider: adminAiProviderOpenAiImages,
      model: adminAiOpenAiImageDefaultModel,
    );

    expect(result, isA<AppSuccess<AdminAiReadingRun>>());
    final run = (result as AppSuccess<AdminAiReadingRun>).value;
    expect(run.status, 'running');
    expect(run.provider, adminAiProviderOpenAiImages);
    expect(run.model, adminAiOpenAiImageDefaultModel);
  });
}

