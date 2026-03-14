import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

import 'admin_console_models.dart';

enum AdminAiAssistantStatus {
  idle,
  loading,
  success,
  error,
  saving,
  publishing,
}

enum AdminAiLinkedWordResolutionType { matchedExisting, pendingCreate }

class AdminAiLinkedWordResolution {
  const AdminAiLinkedWordResolution({
    required this.key,
    required this.source,
    required this.type,
    this.linkedWord,
    this.pendingWord,
    this.isUserEdited = false,
  });

  final String key;
  final AdminAiSuggestedLinkedWord source;
  final AdminAiLinkedWordResolutionType type;
  final AdminReadingWordLinkInput? linkedWord;
  final AdminWordDetail? pendingWord;
  final bool isUserEdited;

  bool get isMatchedExisting =>
      type == AdminAiLinkedWordResolutionType.matchedExisting;
  bool get isPendingCreate =>
      type == AdminAiLinkedWordResolutionType.pendingCreate;

  AdminAiLinkedWordResolution copyWith({
    AdminReadingWordLinkInput? linkedWord,
    AdminWordDetail? pendingWord,
    bool? isUserEdited,
  }) {
    return AdminAiLinkedWordResolution(
      key: key,
      source: source,
      type: linkedWord != null
          ? AdminAiLinkedWordResolutionType.matchedExisting
          : pendingWord != null
          ? AdminAiLinkedWordResolutionType.pendingCreate
          : type,
      linkedWord: linkedWord ?? this.linkedWord,
      pendingWord: pendingWord ?? this.pendingWord,
      isUserEdited: isUserEdited ?? this.isUserEdited,
    );
  }
}

class AdminAiAssistantState {
  const AdminAiAssistantState({
    this.status = AdminAiAssistantStatus.idle,
    this.draftRequest = const AdminAiGenerateReadingRequest(),
    this.selectedPackId,
    this.generatedDraft,
    this.editableDraft,
    this.sourceLinkedWords = const <AdminAiSuggestedLinkedWord>[],
    this.linkedWordResolutions = const <AdminAiLinkedWordResolution>[],
    this.dismissedLinkedWordKeys = const <String>[],
    this.errorMessage,
    this.noticeMessage,
  });

  final AdminAiAssistantStatus status;
  final AdminAiGenerateReadingRequest draftRequest;
  final String? selectedPackId;
  final AdminAiGeneratedReadingDraft? generatedDraft;
  final AdminReadingDetail? editableDraft;
  final List<AdminAiSuggestedLinkedWord> sourceLinkedWords;
  final List<AdminAiLinkedWordResolution> linkedWordResolutions;
  final List<String> dismissedLinkedWordKeys;
  final String? errorMessage;
  final String? noticeMessage;

  bool get isBusy =>
      status == AdminAiAssistantStatus.loading ||
      status == AdminAiAssistantStatus.saving ||
      status == AdminAiAssistantStatus.publishing;

  bool get hasSelectedPack => _normalizedOptionalText(selectedPackId) != null;
  bool get isWaitingForPackSelection =>
      sourceLinkedWords.any(
        (item) => !dismissedLinkedWordKeys.contains(_suggestionKey(item)),
      ) &&
      !hasSelectedPack;
  bool get hasPendingWordCards =>
      linkedWordResolutions.any((item) => item.isPendingCreate);

  AdminAiAssistantState copyWith({
    AdminAiAssistantStatus? status,
    AdminAiGenerateReadingRequest? draftRequest,
    String? selectedPackId,
    AdminAiGeneratedReadingDraft? generatedDraft,
    AdminReadingDetail? editableDraft,
    List<AdminAiSuggestedLinkedWord>? sourceLinkedWords,
    List<AdminAiLinkedWordResolution>? linkedWordResolutions,
    List<String>? dismissedLinkedWordKeys,
    String? errorMessage,
    String? noticeMessage,
    bool clearSelectedPackId = false,
    bool clearGeneratedDraft = false,
    bool clearEditableDraft = false,
    bool clearSourceLinkedWords = false,
    bool clearLinkedWordResolutions = false,
    bool clearDismissedLinkedWordKeys = false,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return AdminAiAssistantState(
      status: status ?? this.status,
      draftRequest: draftRequest ?? this.draftRequest,
      selectedPackId: clearSelectedPackId
          ? null
          : selectedPackId ?? this.selectedPackId,
      generatedDraft: clearGeneratedDraft
          ? null
          : generatedDraft ?? this.generatedDraft,
      editableDraft: clearEditableDraft
          ? null
          : editableDraft ?? this.editableDraft,
      sourceLinkedWords: clearSourceLinkedWords
          ? const <AdminAiSuggestedLinkedWord>[]
          : sourceLinkedWords ?? this.sourceLinkedWords,
      linkedWordResolutions: clearLinkedWordResolutions
          ? const <AdminAiLinkedWordResolution>[]
          : linkedWordResolutions ?? this.linkedWordResolutions,
      dismissedLinkedWordKeys: clearDismissedLinkedWordKeys
          ? const <String>[]
          : dismissedLinkedWordKeys ?? this.dismissedLinkedWordKeys,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      noticeMessage: clearNotice ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

class AdminAiAssistantController extends StateNotifier<AdminAiAssistantState> {
  AdminAiAssistantController({
    required AdminAiReadingRepository aiRepository,
    required AdminContentRepository contentRepository,
  }) : _aiRepository = aiRepository,
       _contentRepository = contentRepository,
       super(const AdminAiAssistantState());

  final AdminAiReadingRepository _aiRepository;
  final AdminContentRepository _contentRepository;

  void updateDraftRequest(AdminAiGenerateReadingRequest request) {
    state = state.copyWith(
      draftRequest: request,
      clearError: true,
      clearNotice: true,
    );
  }

  void updateSelectedPackId(
    String? packId, {
    List<AdminWordRecord> wordCatalog = const <AdminWordRecord>[],
  }) {
    final normalizedPackId = _normalizedOptionalText(packId);
    final previousPackId = _normalizedOptionalText(state.selectedPackId);
    final packChanged = previousPackId != normalizedPackId;
    if (!packChanged && state.editableDraft?.packId == normalizedPackId) {
      return;
    }

    final editableDraft = state.editableDraft?.copyWith(
      packId: normalizedPackId,
      clearPackId: normalizedPackId == null,
    );

    state = state.copyWith(
      selectedPackId: normalizedPackId,
      editableDraft: editableDraft,
      clearError: true,
    );

    if (state.generatedDraft == null) {
      return;
    }

    _refreshLinkedWordResolutions(
      wordCatalog: wordCatalog,
      packChanged: packChanged,
    );
  }

  Future<AppResult<AdminAiGeneratedReadingDraft>> generateDraft({
    List<AdminWordRecord> wordCatalog = const <AdminWordRecord>[],
  }) async {
    final validationError = _validateRequest(state.draftRequest);
    if (validationError != null) {
      state = state.copyWith(
        status: AdminAiAssistantStatus.error,
        errorMessage: validationError,
        clearNotice: true,
      );
      return AppFailure<AdminAiGeneratedReadingDraft>(validationError);
    }

    state = state.copyWith(
      status: AdminAiAssistantStatus.loading,
      clearError: true,
      clearNotice: true,
    );
    final result = await _aiRepository.generateReadingDraft(state.draftRequest);
    if (result case AppSuccess<AdminAiGeneratedReadingDraft>()) {
      final editableDraft = _toEditableDraft(result.value).copyWith(
        packId: state.selectedPackId,
        clearPackId: _normalizedOptionalText(state.selectedPackId) == null,
      );
      state = state.copyWith(
        status: AdminAiAssistantStatus.success,
        generatedDraft: result.value,
        editableDraft: editableDraft,
        sourceLinkedWords: result.value.suggestedLinkedWords,
        clearDismissedLinkedWordKeys: true,
        clearLinkedWordResolutions: true,
        noticeMessage: 'AI taslagi olusturuldu.',
        clearError: true,
      );
      _refreshLinkedWordResolutions(
        wordCatalog: wordCatalog,
        packChanged: false,
        baseNotice: 'AI taslagi olusturuldu.',
      );
      return result;
    }

    state = state.copyWith(
      status: AdminAiAssistantStatus.error,
      errorMessage:
          (result as AppFailure<AdminAiGeneratedReadingDraft>).message,
      clearNotice: true,
    );
    return result;
  }

  void replaceEditableDraft(AdminReadingDetail detail) {
    state = state.copyWith(
      editableDraft: detail,
      selectedPackId: _normalizedOptionalText(detail.packId),
      status: AdminAiAssistantStatus.success,
      clearError: true,
      clearNotice: true,
    );
  }

  void updatePendingLinkedWord(String key, AdminWordDetail detail) {
    final nextResolutions = <AdminAiLinkedWordResolution>[];
    for (final item in state.linkedWordResolutions) {
      if (item.key != key || !item.isPendingCreate) {
        nextResolutions.add(item);
        continue;
      }
      nextResolutions.add(
        item.copyWith(pendingWord: detail, isUserEdited: true),
      );
    }
    state = _applyLinkedWordResolutions(
      state.copyWith(
        linkedWordResolutions: nextResolutions,
        status: AdminAiAssistantStatus.success,
        clearError: true,
        clearNotice: true,
      ),
      nextResolutions,
    );
  }

  void removeLinkedWord(String key) {
    final dismissed = <String>{
      ...state.dismissedLinkedWordKeys,
      key,
    }.toList(growable: false);
    state = _applyLinkedWordResolutions(
      state.copyWith(
        dismissedLinkedWordKeys: dismissed,
        linkedWordResolutions: state.linkedWordResolutions
            .where((item) => item.key != key)
            .toList(growable: false),
        noticeMessage: 'Linked word kaldirildi.',
        clearError: true,
      ),
      state.linkedWordResolutions
          .where((item) => item.key != key)
          .toList(growable: false),
    );
  }

  Future<AppResult<AdminReadingDetail>> saveDraft() {
    return _persistDraft(
      isPublished: false,
      busyStatus: AdminAiAssistantStatus.saving,
      successMessage: 'Taslak kaydedildi.',
    );
  }

  Future<AppResult<AdminReadingDetail>> publish() {
    return _persistDraft(
      isPublished: true,
      busyStatus: AdminAiAssistantStatus.publishing,
      successMessage: 'Reading yayina alindi.',
    );
  }

  void clear() {
    state = const AdminAiAssistantState();
  }

  void clearMessage() {
    state = state.copyWith(clearError: true, clearNotice: true);
  }

  Future<AppResult<AdminReadingDetail>> _persistDraft({
    required bool isPublished,
    required AdminAiAssistantStatus busyStatus,
    required String successMessage,
  }) async {
    final editableDraft = state.editableDraft;
    if (editableDraft == null) {
      const message = 'Kaydedilecek AI taslagi bulunamadi.';
      state = state.copyWith(
        status: AdminAiAssistantStatus.error,
        errorMessage: message,
        clearNotice: true,
      );
      return const AppFailure<AdminReadingDetail>(message);
    }

    final validationError = _validateEditableDraft(editableDraft);
    if (validationError != null) {
      state = state.copyWith(
        status: AdminAiAssistantStatus.error,
        errorMessage: validationError,
        clearNotice: true,
      );
      return AppFailure<AdminReadingDetail>(validationError);
    }

    state = state.copyWith(
      status: busyStatus,
      clearError: true,
      clearNotice: true,
    );

    final preparedLinks = await _prepareLinkedWordsForPersistence();
    if (preparedLinks case AppFailure<_PreparedLinkedWords>()) {
      state = state.copyWith(
        status: AdminAiAssistantStatus.error,
        errorMessage: preparedLinks.message,
        clearNotice: true,
      );
      return AppFailure<AdminReadingDetail>(preparedLinks.message);
    }

    final prepared = (preparedLinks as AppSuccess<_PreparedLinkedWords>).value;
    final generationMeta =
        editableDraft.aiGenerationMeta ?? state.generatedDraft?.generationMeta;
    final payload = editableDraft.copyWith(
      packId: state.selectedPackId,
      clearPackId: _normalizedOptionalText(state.selectedPackId) == null,
      linkedWords: prepared.linkedWords,
      isPublished: isPublished,
      aiGenerated: true,
      aiGenerationMeta: generationMeta,
    );

    state = _applyLinkedWordResolutions(
      state.copyWith(
        status: busyStatus,
        editableDraft: payload,
        linkedWordResolutions: prepared.resolutions,
        clearError: true,
        clearNotice: true,
      ),
      prepared.resolutions,
    );

    final result = await _contentRepository.upsertReadingDetail(payload);
    if (result case AppSuccess<AdminReadingDetail>()) {
      state = state.copyWith(
        status: AdminAiAssistantStatus.success,
        editableDraft: result.value,
        linkedWordResolutions: prepared.resolutions,
        noticeMessage: successMessage,
        clearError: true,
      );
      return result;
    }

    state = state.copyWith(
      status: AdminAiAssistantStatus.error,
      errorMessage: (result as AppFailure<AdminReadingDetail>).message,
      clearNotice: true,
    );
    return result;
  }

  Future<AppResult<_PreparedLinkedWords>>
  _prepareLinkedWordsForPersistence() async {
    final pending = state.linkedWordResolutions
        .where((item) => item.isPendingCreate)
        .toList(growable: false);
    if (pending.isEmpty) {
      final linkedWords = state.linkedWordResolutions
          .where((item) => item.isMatchedExisting && item.linkedWord != null)
          .map((item) => item.linkedWord!)
          .toList(growable: false);
      return AppSuccess<_PreparedLinkedWords>(
        _PreparedLinkedWords(
          linkedWords: linkedWords,
          resolutions: state.linkedWordResolutions,
        ),
      );
    }

    final nextResolutions = <AdminAiLinkedWordResolution>[];
    for (final item in state.linkedWordResolutions) {
      if (!item.isPendingCreate || item.pendingWord == null) {
        nextResolutions.add(item);
        continue;
      }

      final normalizedPending = _normalizePendingWordDetail(item.pendingWord!);
      if (normalizedPending case AppFailure<AdminWordDetail>()) {
        return AppFailure<_PreparedLinkedWords>(
          'Kelime karti kaydedilemedi: ${normalizedPending.message}',
        );
      }
      final wordDetail =
          (normalizedPending as AppSuccess<AdminWordDetail>).value;

      final result = await _contentRepository.upsertWordDetail(wordDetail);
      if (result case AppFailure<AdminWordDetail>()) {
        return AppFailure<_PreparedLinkedWords>(
          'Kelime karti kaydedilemedi: ${result.message}',
        );
      }

      final created = (result as AppSuccess<AdminWordDetail>).value;
      final createdWordId = _normalizedOptionalText(created.metadata.id);
      if (createdWordId == null) {
        return const AppFailure<_PreparedLinkedWords>(
          'Kelime karti kaydedildi ancak gecerli bir word id donmedi.',
        );
      }
      nextResolutions.add(
        AdminAiLinkedWordResolution(
          key: item.key,
          source: item.source,
          type: AdminAiLinkedWordResolutionType.matchedExisting,
          linkedWord: AdminReadingWordLinkInput(
            wordId: createdWordId,
            enWord: created.enWord,
            trMeaning: created.trMeaning,
          ),
        ),
      );
    }

    final linkedWords = nextResolutions
        .where((item) => item.isMatchedExisting && item.linkedWord != null)
        .map((item) => item.linkedWord!)
        .toList(growable: false);
    return AppSuccess<_PreparedLinkedWords>(
      _PreparedLinkedWords(
        linkedWords: linkedWords,
        resolutions: nextResolutions,
      ),
    );
  }

  AdminReadingDetail _toEditableDraft(AdminAiGeneratedReadingDraft draft) {
    return AdminReadingDetail(
      title: draft.title,
      level: draft.level,
      category: draft.category,
      tagsRaw: draft.tagsRaw,
      isPublished: false,
      sentences: draft.sentences
          .map(
            (item) => item.copyWith(
              clearId: true,
              translations: const <AdminReadingSentenceTranslationInput>[],
            ),
          )
          .toList(growable: false),
      linkedWords: const <AdminReadingWordLinkInput>[],
      questions: draft.questions
          .map((item) => item.copyWith(clearId: true))
          .toList(growable: false),
      aiGenerated: true,
      aiGenerationMeta: draft.generationMeta,
    );
  }

  void _refreshLinkedWordResolutions({
    required List<AdminWordRecord> wordCatalog,
    required bool packChanged,
    String? baseNotice,
  }) {
    final editableDraft = state.editableDraft;
    if (editableDraft == null) {
      return;
    }

    final selectedPackId = _normalizedOptionalText(state.selectedPackId);
    final visibleSuggestions = _visibleSourceSuggestions();
    if (selectedPackId == null) {
      final notice = visibleSuggestions.isEmpty
          ? baseNotice
          : 'Paket secildiginde linked words otomatik hazirlanacak.';
      state = _applyLinkedWordResolutions(
        state.copyWith(
          editableDraft: editableDraft.copyWith(
            clearPackId: true,
            linkedWords: const <AdminReadingWordLinkInput>[],
          ),
          clearLinkedWordResolutions: true,
          noticeMessage: notice,
          clearError: true,
        ),
        const <AdminAiLinkedWordResolution>[],
      );
      return;
    }

    final nextResolutions = _buildLinkedWordResolutions(
      suggestions: visibleSuggestions,
      wordCatalog: wordCatalog,
      packId: selectedPackId,
      detail: editableDraft.copyWith(packId: selectedPackId),
    );
    String? notice = baseNotice;
    if (packChanged && _hasEditedPendingWordCards()) {
      notice =
          'Paket degisti; yeni kelime karti taslaklari secili pakete gore yeniden hazirlandi.';
    } else if (packChanged && visibleSuggestions.isNotEmpty) {
      notice = 'Linked words secili pakete gore yeniden hazirlandi.';
    } else if (notice == null && visibleSuggestions.isNotEmpty) {
      notice = 'Linked words secili pakete gore otomatik hazirlandi.';
    }

    state = _applyLinkedWordResolutions(
      state.copyWith(
        editableDraft: editableDraft.copyWith(packId: selectedPackId),
        linkedWordResolutions: nextResolutions,
        noticeMessage: notice,
        clearError: true,
      ),
      nextResolutions,
    );
  }

  AdminAiAssistantState _applyLinkedWordResolutions(
    AdminAiAssistantState baseState,
    List<AdminAiLinkedWordResolution> resolutions,
  ) {
    final editableDraft = baseState.editableDraft;
    if (editableDraft == null) {
      return baseState;
    }

    return baseState.copyWith(
      editableDraft: editableDraft.copyWith(
        linkedWords: resolutions
            .where((item) => item.isMatchedExisting && item.linkedWord != null)
            .map((item) => item.linkedWord!)
            .toList(growable: false),
      ),
      linkedWordResolutions: resolutions,
    );
  }

  List<AdminAiLinkedWordResolution> _buildLinkedWordResolutions({
    required List<AdminAiSuggestedLinkedWord> suggestions,
    required List<AdminWordRecord> wordCatalog,
    required String packId,
    required AdminReadingDetail detail,
  }) {
    final packWords = wordCatalog
        .where((item) => item.packId == packId)
        .toList(growable: false);
    final seenKeys = <String>{};
    final results = <AdminAiLinkedWordResolution>[];
    for (final suggestion in suggestions) {
      final key = _suggestionKey(suggestion);
      if (!seenKeys.add(key)) {
        continue;
      }

      final normalizedWord = _normalizeLookupText(suggestion.enWord);
      final normalizedPos = _normalizedWordPosLookup(suggestion.pos);
      final exactMatches = packWords
          .where(
            (item) =>
                _normalizeLookupText(item.enWord) == normalizedWord &&
                _normalizedWordPosLookup(item.pos) == normalizedPos,
          )
          .toList(growable: false);
      if (exactMatches.length == 1) {
        final match = exactMatches.single;
        results.add(
          AdminAiLinkedWordResolution(
            key: key,
            source: suggestion,
            type: AdminAiLinkedWordResolutionType.matchedExisting,
            linkedWord: AdminReadingWordLinkInput(
              wordId: match.id,
              enWord: match.enWord,
              trMeaning: match.trMeaning,
            ),
          ),
        );
        continue;
      }

      final fallbackMatches = packWords
          .where((item) => _normalizeLookupText(item.enWord) == normalizedWord)
          .toList(growable: false);
      if (fallbackMatches.length == 1) {
        final match = fallbackMatches.single;
        results.add(
          AdminAiLinkedWordResolution(
            key: key,
            source: suggestion,
            type: AdminAiLinkedWordResolutionType.matchedExisting,
            linkedWord: AdminReadingWordLinkInput(
              wordId: match.id,
              enWord: match.enWord,
              trMeaning: match.trMeaning,
            ),
          ),
        );
        continue;
      }

      results.add(
        AdminAiLinkedWordResolution(
          key: key,
          source: suggestion,
          type: AdminAiLinkedWordResolutionType.pendingCreate,
          pendingWord: _buildPendingWordDetail(
            suggestion: suggestion,
            detail: detail,
            packId: packId,
          ),
        ),
      );
    }
    return results;
  }

  AdminWordDetail _buildPendingWordDetail({
    required AdminAiSuggestedLinkedWord suggestion,
    required AdminReadingDetail detail,
    required String packId,
  }) {
    final example = _resolveExampleSentence(
      suggestion.enWord,
      detail.sentences,
    );
    final rawPos = _normalizedOptionalText(suggestion.pos);
    final normalizedPos = normalizeAdminWordPos(rawPos) ?? 'n.';
    return AdminWordDetail(
      packId: packId,
      enWord: suggestion.enWord.trim(),
      trMeaning: suggestion.trMeaning.trim(),
      pos: normalizedPos,
      posRaw: rawPos != null && rawPos != normalizedPos ? rawPos : null,
      exampleEn: example.english,
      exampleTr: example.turkish,
      level: _normalizedOptionalText(detail.level),
      tagsRaw: _normalizedOptionalText(detail.tagsRaw),
      notes: _normalizedOptionalText(suggestion.notes),
      isPro: false,
      isPublished: true,
    );
  }

  List<AdminAiSuggestedLinkedWord> _visibleSourceSuggestions() {
    final dismissedKeys = state.dismissedLinkedWordKeys.toSet();
    final seenKeys = <String>{};
    final visible = <AdminAiSuggestedLinkedWord>[];
    for (final item in state.sourceLinkedWords) {
      final key = _suggestionKey(item);
      if (dismissedKeys.contains(key) || !seenKeys.add(key)) {
        continue;
      }
      visible.add(item);
    }
    return visible;
  }

  bool _hasEditedPendingWordCards() {
    return state.linkedWordResolutions.any(
      (item) => item.isPendingCreate && item.isUserEdited,
    );
  }

  AppResult<AdminWordDetail> _normalizePendingWordDetail(
    AdminWordDetail detail,
  ) {
    final rawPos = detail.pos.trim();
    final normalizedPos =
        normalizeAdminWordPos(rawPos) ?? normalizeAdminWordPos(detail.posRaw);
    if (normalizedPos == null) {
      return const AppFailure<AdminWordDetail>(
        'POS gecersiz. Gecerli degerler: n., v., adj., adv., prep., conj., det., modal, NP, phr. v.',
      );
    }

    final resolvedPosRaw =
        _normalizedOptionalText(detail.posRaw) ??
        (rawPos != normalizedPos ? rawPos : null);
    return AppSuccess<AdminWordDetail>(
      detail.copyWith(
        pos: normalizedPos,
        posRaw: resolvedPosRaw,
        clearPosRaw: resolvedPosRaw == null,
      ),
    );
  }

  String? _validateRequest(AdminAiGenerateReadingRequest request) {
    if (request.topic.trim().isEmpty) {
      return 'Konu zorunlu.';
    }
    if (!adminAiSupportedProviders.contains(request.provider)) {
      return 'AI saglayicisi gecersiz.';
    }
    final model = request.model?.trim();
    if (request.provider == adminAiProviderOpenRouter &&
        (model == null || model.isEmpty)) {
      return 'OpenRouter modeli secilmeli.';
    }
    if (request.targetWordCount < 30) {
      return 'Hedef kelime sayisi en az 30 olmali.';
    }
    if (request.focusWordCount < 1) {
      return 'Odak kelime sayisi en az 1 olmali.';
    }
    if (request.questionCount < 1) {
      return 'Soru sayisi en az 1 olmali.';
    }
    return null;
  }

  String? _validateEditableDraft(AdminReadingDetail detail) {
    if (detail.title.trim().isEmpty) {
      return 'Baslik bos olamaz.';
    }
    if (_normalizedOptionalText(state.selectedPackId) == null) {
      return 'Save veya publish oncesi paket secilmeli.';
    }
    if (detail.sentences.isEmpty) {
      return 'En az 1 cumle olmali.';
    }
    for (final sentence in detail.sentences) {
      if (sentence.sentenceEn.trim().isEmpty) {
        return 'Her cumlede Inglizce metin dolu olmali.';
      }
    }
    if (detail.questions.isEmpty) {
      return 'En az 1 soru olmali.';
    }
    for (final question in detail.questions) {
      if (question.options.length < 2) {
        return 'Her soruda en az 2 secenek olmali.';
      }
      if (question.correctOptionIndex < 0 ||
          question.correctOptionIndex >= question.options.length) {
        return 'Dogru secenek indeksi sinirlar icinde olmali.';
      }
    }
    return null;
  }
}

class _PreparedLinkedWords {
  const _PreparedLinkedWords({
    required this.linkedWords,
    required this.resolutions,
  });

  final List<AdminReadingWordLinkInput> linkedWords;
  final List<AdminAiLinkedWordResolution> resolutions;
}

class _ExampleSentence {
  const _ExampleSentence({required this.english, required this.turkish});

  final String english;
  final String? turkish;
}

_ExampleSentence _resolveExampleSentence(
  String enWord,
  List<AdminReadingSentenceInput> sentences,
) {
  final fallback = sentences.isNotEmpty
      ? _ExampleSentence(
          english: sentences.first.sentenceEn.trim(),
          turkish: _normalizedOptionalText(sentences.first.sentenceTr),
        )
      : const _ExampleSentence(english: '', turkish: null);
  final target = _normalizeLookupText(enWord);
  if (target.isEmpty) {
    return fallback;
  }

  for (final sentence in sentences) {
    final normalizedSentence = ' ${_normalizeLookupText(sentence.sentenceEn)} ';
    final normalizedTarget = ' $target ';
    if (normalizedSentence.contains(normalizedTarget) ||
        normalizedSentence.contains(target)) {
      return _ExampleSentence(
        english: sentence.sentenceEn.trim(),
        turkish: _normalizedOptionalText(sentence.sentenceTr),
      );
    }
  }
  return fallback;
}

String _suggestionKey(AdminAiSuggestedLinkedWord suggestion) {
  return [
    _normalizeLookupText(suggestion.enWord),
    _normalizedWordPosLookup(suggestion.pos),
    _normalizeLookupText(suggestion.trMeaning),
  ].join('|');
}

String _normalizedWordPosLookup(String value) {
  return normalizeAdminWordPos(value) ?? _normalizeLookupText(value);
}

String _normalizeLookupText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9']+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _normalizedOptionalText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
