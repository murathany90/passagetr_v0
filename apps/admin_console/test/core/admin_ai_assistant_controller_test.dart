import 'package:admin_console/src/core/admin_ai_assistant_controller.dart';
import 'package:admin_console/src/core/admin_console_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

void main() {
  test(
    'generateDraft maps API category/tags and auto matches selected pack words',
    () async {
      final aiRepository = _FakeAdminAiReadingRepository(
        result: AppSuccess<AdminAiGeneratedReadingDraft>(_draftWithSuggestion),
      );
      final contentRepository = _FakeAdminContentRepository();
      final controller = AdminAiAssistantController(
        aiRepository: aiRepository,
        contentRepository: contentRepository,
      );

      controller.updateSelectedPackId('pack-1');
      controller.updateDraftRequest(
        const AdminAiGenerateReadingRequest(topic: 'Ocean science'),
      );
      final result = await controller.generateDraft(wordCatalog: _waveCatalog);

      expect(result, isA<AppSuccess<AdminAiGeneratedReadingDraft>>());
      expect(controller.state.editableDraft?.category, 'science');
      expect(controller.state.editableDraft?.tagsRaw, 'ocean, science');
      expect(controller.state.linkedWordResolutions.length, 1);
      expect(
        controller.state.linkedWordResolutions.single.isMatchedExisting,
        isTrue,
      );
      expect(
        controller.state.editableDraft?.linkedWords.single.wordId,
        'word-1',
      );
    },
  );

  test(
    'generateDraft waits for pack selection before preparing linked words',
    () async {
      final aiRepository = _FakeAdminAiReadingRepository(
        result: AppSuccess<AdminAiGeneratedReadingDraft>(_draftWithSuggestion),
      );
      final contentRepository = _FakeAdminContentRepository();
      final controller = AdminAiAssistantController(
        aiRepository: aiRepository,
        contentRepository: contentRepository,
      );

      controller.updateDraftRequest(
        const AdminAiGenerateReadingRequest(topic: 'Ocean science'),
      );
      await controller.generateDraft();

      expect(controller.state.isWaitingForPackSelection, isTrue);
      expect(controller.state.linkedWordResolutions, isEmpty);
    },
  );

  test(
    'selecting a pack after generate creates pending word cards when no match exists',
    () async {
      final aiRepository = _FakeAdminAiReadingRepository(
        result: AppSuccess<AdminAiGeneratedReadingDraft>(_draftWithSuggestion),
      );
      final contentRepository = _FakeAdminContentRepository();
      final controller = AdminAiAssistantController(
        aiRepository: aiRepository,
        contentRepository: contentRepository,
      );

      controller.updateDraftRequest(
        const AdminAiGenerateReadingRequest(topic: 'Ocean science'),
      );
      await controller.generateDraft();
      controller.updateSelectedPackId(
        'pack-2',
        wordCatalog: const <AdminWordRecord>[],
      );

      expect(controller.state.linkedWordResolutions.length, 1);
      final pending = controller.state.linkedWordResolutions.single;
      expect(pending.isPendingCreate, isTrue);
      expect(pending.pendingWord?.packId, 'pack-2');
      expect(pending.pendingWord?.pos, 'n.');
      expect(
        pending.pendingWord?.exampleEn,
        'Waves carry energy across the sea.',
      );
    },
  );

  test(
    'changing pack resets edited pending word cards and shows notice',
    () async {
      final aiRepository = _FakeAdminAiReadingRepository(
        result: AppSuccess<AdminAiGeneratedReadingDraft>(_draftWithSuggestion),
      );
      final contentRepository = _FakeAdminContentRepository();
      final controller = AdminAiAssistantController(
        aiRepository: aiRepository,
        contentRepository: contentRepository,
      );

      controller.updateSelectedPackId(
        'pack-1',
        wordCatalog: const <AdminWordRecord>[],
      );
      controller.updateDraftRequest(
        const AdminAiGenerateReadingRequest(topic: 'Ocean science'),
      );
      await controller.generateDraft();
      final pending = controller.state.linkedWordResolutions.single;
      controller.updatePendingLinkedWord(
        pending.key,
        pending.pendingWord!.copyWith(enWord: 'custom-wave'),
      );

      controller.updateSelectedPackId(
        'pack-2',
        wordCatalog: const <AdminWordRecord>[],
      );

      expect(
        controller.state.linkedWordResolutions.single.pendingWord?.enWord,
        'wave',
      );
      expect(controller.state.noticeMessage, contains('Paket degisti'));
    },
  );

  test('saveDraft blocks when pack is missing', () async {
    final aiRepository = _FakeAdminAiReadingRepository(
      result: AppSuccess<AdminAiGeneratedReadingDraft>(_draftWithSuggestion),
    );
    final contentRepository = _FakeAdminContentRepository();
    final controller = AdminAiAssistantController(
      aiRepository: aiRepository,
      contentRepository: contentRepository,
    );

    controller.updateDraftRequest(
      const AdminAiGenerateReadingRequest(topic: 'Ocean science'),
    );
    await controller.generateDraft();
    final result = await controller.saveDraft();

    expect(result, isA<AppFailure<AdminReadingDetail>>());
    expect(
      (result as AppFailure<AdminReadingDetail>).message,
      'Save veya publish oncesi paket secilmeli.',
    );
  });

  test(
    'saveDraft upserts pending word cards before persisting reading detail',
    () async {
      final aiRepository = _FakeAdminAiReadingRepository(
        result: AppSuccess<AdminAiGeneratedReadingDraft>(_draftWithSuggestion),
      );
      final contentRepository = _FakeAdminContentRepository();
      final controller = AdminAiAssistantController(
        aiRepository: aiRepository,
        contentRepository: contentRepository,
      );

      controller.updateSelectedPackId(
        'pack-1',
        wordCatalog: const <AdminWordRecord>[],
      );
      controller.updateDraftRequest(
        const AdminAiGenerateReadingRequest(topic: 'Ocean science'),
      );
      await controller.generateDraft();
      final result = await controller.saveDraft();

      expect(result, isA<AppSuccess<AdminReadingDetail>>());
      expect(contentRepository.wordUpsertCount, 1);
      expect(contentRepository.upsertCount, 1);
      expect(contentRepository.lastWordDetail?.isPublished, isTrue);
      expect(contentRepository.lastWordDetail?.pos, 'n.');
      expect(contentRepository.lastWordDetail?.posRaw, 'noun');
      expect(
        contentRepository.lastUpsertDetail?.linkedWords.single.wordId,
        'word-created',
      );
      expect(contentRepository.callLog, ['word', 'reading']);
    },
  );
}

class _FakeAdminAiReadingRepository implements AdminAiReadingRepository {
  _FakeAdminAiReadingRepository({required this.result});

  final AppResult<AdminAiGeneratedReadingDraft> result;

  @override
  Future<AppResult<AdminAiGeneratedReadingDraft>> generateReadingDraft(
    AdminAiGenerateReadingRequest request,
  ) async {
    return result;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAdminContentRepository implements AdminContentRepository {
  int upsertCount = 0;
  int wordUpsertCount = 0;
  AdminReadingDetail? lastUpsertDetail;
  AdminWordDetail? lastWordDetail;
  final List<String> callLog = <String>[];

  @override
  Future<AppResult<AdminReadingDetail>> upsertReadingDetail(
    AdminReadingDetail detail,
  ) async {
    callLog.add('reading');
    upsertCount += 1;
    lastUpsertDetail = detail;
    return AppSuccess<AdminReadingDetail>(
      detail.copyWith(metadata: const AdminContentMetadata(id: 'reading-1')),
    );
  }

  @override
  Future<AppResult<AdminWordDetail>> upsertWordDetail(
    AdminWordDetail detail,
  ) async {
    callLog.add('word');
    wordUpsertCount += 1;
    lastWordDetail = detail;
    return AppSuccess<AdminWordDetail>(
      detail.copyWith(metadata: const AdminContentMetadata(id: 'word-created')),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _waveCatalog = <AdminWordRecord>[
  AdminWordRecord(
    id: 'word-1',
    packId: 'pack-1',
    enWord: 'wave',
    trMeaning: 'dalga',
    pos: 'n.',
    exampleEn: 'A big wave hit the boat.',
    exampleTr: 'Buyuk bir dalga tekneye vurdu.',
    level: 'A2',
    notes: null,
    isPublished: true,
    updatedAtLabel: 'now',
  ),
];

final _draftWithSuggestion = AdminAiGeneratedReadingDraft(
  title: 'Ocean Science',
  level: 'B1',
  category: 'science',
  tagsRaw: 'ocean, science',
  sentences: const [
    AdminReadingSentenceInput(
      idx: 1,
      sentenceEn: 'Waves carry energy across the sea.',
      sentenceTr: 'Dalgalar deniz boyunca enerji tasir.',
    ),
  ],
  suggestedLinkedWords: const [
    AdminAiSuggestedLinkedWord(enWord: 'wave', trMeaning: 'dalga', pos: 'noun'),
  ],
  questions: const [
    AdminReadingQuestionInput(
      sortOrder: 1,
      question: 'What do waves carry?',
      options: ['Energy', 'Trees'],
      correctOptionIndex: 0,
    ),
  ],
  generationMeta: AdminAiGenerationMeta(
    provider: 'gemini',
    model: 'gemini-test',
    topic: 'Ocean science',
    cefrLevel: 'B1',
    targetWordCount: 120,
    focusWordCount: 5,
    questionCount: 3,
    actualWordCount: 6,
    generatedAt: DateTime.utc(2026, 3, 13, 10),
  ),
);
