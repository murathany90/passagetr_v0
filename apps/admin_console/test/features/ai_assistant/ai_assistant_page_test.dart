import 'dart:async';

import 'package:admin_console/src/core/admin_console_models.dart';
import 'package:admin_console/src/core/admin_providers.dart';
import 'package:admin_console/src/features/ai_assistant/ai_assistant_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
    'page renders AI assistant shell with pack selector and no category inputs',
    (tester) async {
      await _pumpPage(tester);

      expect(find.text('AI Asistan'), findsWidgets);
      expect(find.text('Generation Parametreleri'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ai-provider-dropdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ai-pack-dropdown-none')),
        findsOneWidget,
      );
      expect(find.text('Category'), findsNothing);
      expect(find.text('Tags Raw'), findsNothing);
    },
  );

  testWidgets('form validation shows error when topic is empty', (
    tester,
  ) async {
    await _pumpPage(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    expect(find.text('Konu zorunlu.'), findsOneWidget);
  });

  testWidgets('loading state renders while AI request is in flight', (
    tester,
  ) async {
    final completer = Completer<AppResult<AdminAiGeneratedReadingDraft>>();
    final aiRepository = _WidgetFakeAdminAiReadingRepository(
      onGenerate: (_) => completer.future,
    );

    await _pumpPage(tester, aiRepository: aiRepository);
    await tester.enterText(
      find.byKey(const ValueKey('ai-topic-field')),
      'Ocean',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pump();

    expect(find.text('Uretiliyor'), findsOneWidget);

    completer.complete(
      AppSuccess<AdminAiGeneratedReadingDraft>(_draftWithoutSuggestion),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'openrouter selection resets model and generate uses chosen provider',
    (tester) async {
      final aiRepository = _WidgetFakeAdminAiReadingRepository(
        result: AppSuccess<AdminAiGeneratedReadingDraft>(
          _draftWithoutSuggestion,
        ),
      );

      await _pumpPage(tester, aiRepository: aiRepository);

      await tester.tap(find.byKey(const ValueKey('ai-provider-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OpenRouter').last);
      await tester.pumpAndSettle();

      final openRouterModelField = tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('ai-model-dropdown-openrouter')),
          );
      expect(
        openRouterModelField.initialValue,
        adminAiOpenRouterCuratedModels.first,
      );

      await tester.tap(
        find.byKey(const ValueKey('ai-model-dropdown-openrouter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qwen3 Coder (free)').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('ai-topic-field')),
        'Ocean',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.pumpAndSettle();

      expect(aiRepository.lastRequest?.provider, adminAiProviderOpenRouter);
      expect(aiRepository.lastRequest?.model, 'qwen/qwen3-coder:free');
    },
  );

  testWidgets(
    'generate with matched pack word shows unlink-only linked word item',
    (tester) async {
      await _pumpPage(
        tester,
        aiRepository: _WidgetFakeAdminAiReadingRepository(
          result: AppSuccess<AdminAiGeneratedReadingDraft>(
            _draftWithSuggestion,
          ),
        ),
      );
      await _selectPack(tester, 'Starter Pack');
      await tester.enterText(
        find.byKey(const ValueKey('ai-topic-field')),
        'Ocean',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.pumpAndSettle();

      expect(find.text('Draft Editor'), findsOneWidget);
      expect(find.text('Question Editor'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Tags Raw'), findsOneWidget);
      expect(find.text('Unlink'), findsOneWidget);
      expect(find.text('Yeni Kelime Karti'), findsNothing);
      expect(find.text('Mevcut word ile eslestir'), findsNothing);
    },
  );

  testWidgets(
    'generate with no catalog match shows editable pending word card',
    (tester) async {
      await _pumpPage(
        tester,
        wordEntries: const <AdminWordRecord>[],
        aiRepository: _WidgetFakeAdminAiReadingRepository(
          result: AppSuccess<AdminAiGeneratedReadingDraft>(
            _draftWithSuggestion,
          ),
        ),
      );
      await _selectPack(tester, 'Starter Pack');
      await tester.enterText(
        find.byKey(const ValueKey('ai-topic-field')),
        'Ocean',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.pumpAndSettle();

      expect(find.text('Yeni Kelime Karti'), findsOneWidget);
      expect(find.text('English word'), findsOneWidget);
      expect(find.text('Turkish meaning'), findsOneWidget);
      expect(find.text('Example EN'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    },
  );

  testWidgets(
    'save draft with pending word card upserts word before reading detail',
    (tester) async {
      final contentRepository = _WidgetFakeAdminContentRepository();

      await _pumpPage(
        tester,
        wordEntries: const <AdminWordRecord>[],
        aiRepository: _WidgetFakeAdminAiReadingRepository(
          result: AppSuccess<AdminAiGeneratedReadingDraft>(
            _draftWithSuggestion,
          ),
        ),
        contentRepository: contentRepository,
      );
      await _selectPack(tester, 'Starter Pack');
      await tester.enterText(
        find.byKey(const ValueKey('ai-topic-field')),
        'Ocean',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Save Draft'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save Draft'));
      await tester.pumpAndSettle();

      expect(contentRepository.callLog, ['word', 'reading']);
      expect(
        contentRepository.lastUpsertDetail?.linkedWords.single.wordId,
        'word-created',
      );
    },
  );

  testWidgets('save draft without pack shows validation error', (tester) async {
    await _pumpPage(
      tester,
      aiRepository: _WidgetFakeAdminAiReadingRepository(
        result: AppSuccess<AdminAiGeneratedReadingDraft>(_draftWithSuggestion),
      ),
      wordEntries: const <AdminWordRecord>[],
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai-topic-field')),
      'Ocean',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save Draft'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save Draft'));
    await tester.pumpAndSettle();

    expect(
      find.text('Save veya publish oncesi paket secilmeli.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  _WidgetFakeAdminAiReadingRepository? aiRepository,
  _WidgetFakeAdminContentRepository? contentRepository,
  List<AdminWordRecord>? wordEntries,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 1200);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAccessProvider.overrideWith(
          (ref) => AccessContext.preview(
            role: AppRole.admin,
            plan: EntitlementPlan.pro,
            isAnonymous: false,
          ),
        ),
        adminAiReadingRepositoryProvider.overrideWith(
          (ref) =>
              aiRepository ??
              _WidgetFakeAdminAiReadingRepository(
                result: AppSuccess<AdminAiGeneratedReadingDraft>(
                  _draftWithoutSuggestion,
                ),
              ),
        ),
        adminContentRepositoryProvider.overrideWith(
          (ref) => contentRepository ?? _WidgetFakeAdminContentRepository(),
        ),
        adminPacksProvider.overrideWith(
          (ref) async => const [
            AdminPackRecord(
              id: 'pack-1',
              name: 'Starter Pack',
              wordCount: 10,
              isPublished: true,
              updatedAtLabel: 'now',
            ),
          ],
        ),
        adminWordEntriesProvider.overrideWith(
          (ref) async =>
              wordEntries ??
              const [
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
              ],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const AdminAiAssistantPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectPack(WidgetTester tester, String packName) async {
  await tester.tap(find.byKey(const ValueKey('ai-pack-dropdown-none')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(packName).last);
  await tester.pumpAndSettle();
}

class _WidgetFakeAdminAiReadingRepository implements AdminAiReadingRepository {
  _WidgetFakeAdminAiReadingRepository({this.result, this.onGenerate});

  final AppResult<AdminAiGeneratedReadingDraft>? result;
  final Future<AppResult<AdminAiGeneratedReadingDraft>> Function(
    AdminAiGenerateReadingRequest request,
  )?
  onGenerate;
  AdminAiGenerateReadingRequest? lastRequest;

  @override
  Future<AppResult<AdminAiGeneratedReadingDraft>> generateReadingDraft(
    AdminAiGenerateReadingRequest request,
  ) async {
    lastRequest = request;
    if (onGenerate != null) {
      return onGenerate!(request);
    }
    return result ??
        AppSuccess<AdminAiGeneratedReadingDraft>(_draftWithoutSuggestion);
  }
}

class _WidgetFakeAdminContentRepository implements AdminContentRepository {
  int upsertCount = 0;
  int wordUpsertCount = 0;
  final List<String> callLog = <String>[];
  AdminReadingDetail? lastUpsertDetail;

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
    return AppSuccess<AdminWordDetail>(
      detail.copyWith(metadata: const AdminContentMetadata(id: 'word-created')),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

final _draftWithoutSuggestion = AdminAiGeneratedReadingDraft(
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
  suggestedLinkedWords: const [],
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
