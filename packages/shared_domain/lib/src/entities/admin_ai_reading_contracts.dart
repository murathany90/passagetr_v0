import 'admin_console_contracts.dart';

const adminAiProviderGemini = 'gemini';
const adminAiProviderOpenRouter = 'openrouter';
const adminAiGeminiDefaultModel = 'gemini-2.0-flash';
const adminAiOpenRouterCuratedModels = <String>[
  'arcee-ai/trinity-large-preview:free',
  'nvidia/nemotron-3-super-120b-a12b:free',
  'z-ai/glm-4.5-air:free',
  'qwen/qwen3-coder:free',
  'stepfun/step-3.5-flash:free',
];
const adminAiSupportedProviders = <String>[
  adminAiProviderGemini,
  adminAiProviderOpenRouter,
];

List<String> adminAiModelsForProvider(String provider) {
  return switch (provider.trim().toLowerCase()) {
    adminAiProviderOpenRouter => adminAiOpenRouterCuratedModels,
    _ => const <String>[adminAiGeminiDefaultModel],
  };
}

String? adminAiDefaultModelForProvider(String provider) {
  final models = adminAiModelsForProvider(provider);
  if (models.isEmpty) {
    return null;
  }
  return models.first;
}

String adminAiModelLabel(String model) {
  return switch (model) {
    adminAiGeminiDefaultModel => 'Gemini 2.0 Flash',
    'arcee-ai/trinity-large-preview:free' => 'Trinity Large Preview (free)',
    'nvidia/nemotron-3-super-120b-a12b:free' => 'Nemotron 3 Super 120B (free)',
    'z-ai/glm-4.5-air:free' => 'GLM 4.5 Air (free)',
    'qwen/qwen3-coder:free' => 'Qwen3 Coder (free)',
    'stepfun/step-3.5-flash:free' => 'Step 3.5 Flash (free)',
    _ => model,
  };
}

class AdminAiGenerateReadingRequest {
  const AdminAiGenerateReadingRequest({
    this.topic = '',
    this.cefrLevel = 'B1',
    this.targetWordCount = 120,
    this.focusWordCount = 5,
    this.questionCount = 3,
    this.provider = adminAiProviderGemini,
    this.model = adminAiGeminiDefaultModel,
    this.extraInstructions,
  });

  final String topic;
  final String cefrLevel;
  final int targetWordCount;
  final int focusWordCount;
  final int questionCount;
  final String provider;
  final String? model;
  final String? extraInstructions;

  AdminAiGenerateReadingRequest copyWith({
    String? topic,
    String? cefrLevel,
    int? targetWordCount,
    int? focusWordCount,
    int? questionCount,
    String? provider,
    String? model,
    String? extraInstructions,
    bool clearModel = false,
    bool clearExtraInstructions = false,
  }) {
    final nextProvider = provider ?? this.provider;
    final nextModel = clearModel
        ? null
        : model ??
              (provider != null && provider != this.provider
                  ? adminAiDefaultModelForProvider(nextProvider)
                  : this.model);
    return AdminAiGenerateReadingRequest(
      topic: topic ?? this.topic,
      cefrLevel: cefrLevel ?? this.cefrLevel,
      targetWordCount: targetWordCount ?? this.targetWordCount,
      focusWordCount: focusWordCount ?? this.focusWordCount,
      questionCount: questionCount ?? this.questionCount,
      provider: nextProvider,
      model: nextModel,
      extraInstructions: clearExtraInstructions
          ? null
          : extraInstructions ?? this.extraInstructions,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'topic': topic,
    'cefr_level': cefrLevel,
    'target_word_count': targetWordCount,
    'focus_word_count': focusWordCount,
    'question_count': questionCount,
    'provider': provider,
    'model': model,
    'extra_instructions': extraInstructions,
  };

  factory AdminAiGenerateReadingRequest.fromJson(Map<String, dynamic>? json) {
    final provider =
        _adminAiProviderFromValue(json?['provider']) ?? adminAiProviderGemini;
    return AdminAiGenerateReadingRequest(
      topic: json?['topic']?.toString() ?? '',
      cefrLevel: json?['cefr_level']?.toString() ?? 'B1',
      targetWordCount: (json?['target_word_count'] as num?)?.toInt() ?? 120,
      focusWordCount: (json?['focus_word_count'] as num?)?.toInt() ?? 5,
      questionCount: (json?['question_count'] as num?)?.toInt() ?? 3,
      provider: provider,
      model:
          _adminAiEmptyStringAsNull(json?['model']?.toString()) ??
          adminAiDefaultModelForProvider(provider),
      extraInstructions: _adminAiEmptyStringAsNull(
        json?['extra_instructions']?.toString(),
      ),
    );
  }
}

class AdminAiSuggestedLinkedWord {
  const AdminAiSuggestedLinkedWord({
    required this.enWord,
    required this.trMeaning,
    required this.pos,
    this.notes,
  });

  final String enWord;
  final String trMeaning;
  final String pos;
  final String? notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'en_word': enWord,
    'tr_meaning': trMeaning,
    'pos': pos,
    'notes': notes,
  };

  factory AdminAiSuggestedLinkedWord.fromJson(Map<String, dynamic>? json) {
    return AdminAiSuggestedLinkedWord(
      enWord: json?['en_word']?.toString() ?? '',
      trMeaning: json?['tr_meaning']?.toString() ?? '',
      pos: json?['pos']?.toString() ?? '',
      notes: _adminAiEmptyStringAsNull(json?['notes']?.toString()),
    );
  }
}

class AdminReadingQuestionInput {
  const AdminReadingQuestionInput({
    this.id,
    required this.sortOrder,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    this.explanation,
  });

  final String? id;
  final int sortOrder;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String? explanation;

  AdminReadingQuestionInput copyWith({
    String? id,
    int? sortOrder,
    String? question,
    List<String>? options,
    int? correctOptionIndex,
    String? explanation,
    bool clearId = false,
    bool clearExplanation = false,
  }) {
    return AdminReadingQuestionInput(
      id: clearId ? null : id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      question: question ?? this.question,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      explanation: clearExplanation ? null : explanation ?? this.explanation,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sort_order': sortOrder,
    'question': question,
    'options': options,
    'correct_option_index': correctOptionIndex,
    'explanation': explanation,
  };

  factory AdminReadingQuestionInput.fromJson(Map<String, dynamic>? json) {
    final rawOptions = json?['options'];
    return AdminReadingQuestionInput(
      id: _adminAiEmptyStringAsNull(json?['id']?.toString()),
      sortOrder: (json?['sort_order'] as num?)?.toInt() ?? 1,
      question: json?['question']?.toString() ?? '',
      options: switch (rawOptions) {
        List<dynamic>() =>
          rawOptions.map((item) => item.toString()).toList(growable: false),
        _ => const <String>[],
      },
      correctOptionIndex: (json?['correct_option_index'] as num?)?.toInt() ?? 0,
      explanation: _adminAiEmptyStringAsNull(json?['explanation']?.toString()),
    );
  }
}

class AdminAiGenerationMeta {
  const AdminAiGenerationMeta({
    required this.provider,
    required this.model,
    required this.topic,
    required this.cefrLevel,
    required this.targetWordCount,
    required this.focusWordCount,
    required this.questionCount,
    required this.actualWordCount,
    required this.generatedAt,
  });

  final String provider;
  final String model;
  final String topic;
  final String cefrLevel;
  final int targetWordCount;
  final int focusWordCount;
  final int questionCount;
  final int actualWordCount;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'provider': provider,
    'model': model,
    'topic': topic,
    'cefr_level': cefrLevel,
    'target_word_count': targetWordCount,
    'focus_word_count': focusWordCount,
    'question_count': questionCount,
    'actual_word_count': actualWordCount,
    'generated_at': generatedAt.toIso8601String(),
  };

  factory AdminAiGenerationMeta.fromJson(Map<String, dynamic>? json) {
    return AdminAiGenerationMeta(
      provider:
          _adminAiProviderFromValue(json?['provider']) ?? adminAiProviderGemini,
      model: json?['model']?.toString() ?? '',
      topic: json?['topic']?.toString() ?? '',
      cefrLevel: json?['cefr_level']?.toString() ?? '',
      targetWordCount: (json?['target_word_count'] as num?)?.toInt() ?? 0,
      focusWordCount: (json?['focus_word_count'] as num?)?.toInt() ?? 0,
      questionCount: (json?['question_count'] as num?)?.toInt() ?? 0,
      actualWordCount: (json?['actual_word_count'] as num?)?.toInt() ?? 0,
      generatedAt:
          _adminAiDateTimeFromValue(json?['generated_at']) ?? DateTime.now(),
    );
  }
}

class AdminAiGeneratedReadingDraft {
  const AdminAiGeneratedReadingDraft({
    required this.title,
    required this.level,
    required this.category,
    required this.tagsRaw,
    required this.sentences,
    required this.suggestedLinkedWords,
    required this.questions,
    required this.generationMeta,
  });

  final String title;
  final String? level;
  final String? category;
  final String? tagsRaw;
  final List<AdminReadingSentenceInput> sentences;
  final List<AdminAiSuggestedLinkedWord> suggestedLinkedWords;
  final List<AdminReadingQuestionInput> questions;
  final AdminAiGenerationMeta generationMeta;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'level': level,
    'category': category,
    'tags_raw': tagsRaw,
    'sentences': sentences.map((item) => item.toJson()).toList(growable: false),
    'suggested_linked_words': suggestedLinkedWords
        .map((item) => item.toJson())
        .toList(growable: false),
    'questions': questions.map((item) => item.toJson()).toList(growable: false),
    'generation_meta': generationMeta.toJson(),
  };

  factory AdminAiGeneratedReadingDraft.fromJson(Map<String, dynamic>? json) {
    final rawSentences = json?['sentences'];
    final rawSuggestedLinkedWords = json?['suggested_linked_words'];
    final rawQuestions = json?['questions'];
    return AdminAiGeneratedReadingDraft(
      title: json?['title']?.toString() ?? '',
      level: _adminAiEmptyStringAsNull(json?['level']?.toString()),
      category: _adminAiEmptyStringAsNull(json?['category']?.toString()),
      tagsRaw: _adminAiEmptyStringAsNull(json?['tags_raw']?.toString()),
      sentences: switch (rawSentences) {
        List<dynamic>() =>
          rawSentences
              .whereType<Map>()
              .map(
                (item) => AdminReadingSentenceInput.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false),
        _ => const <AdminReadingSentenceInput>[],
      },
      suggestedLinkedWords: switch (rawSuggestedLinkedWords) {
        List<dynamic>() =>
          rawSuggestedLinkedWords
              .whereType<Map>()
              .map(
                (item) => AdminAiSuggestedLinkedWord.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false),
        _ => const <AdminAiSuggestedLinkedWord>[],
      },
      questions: switch (rawQuestions) {
        List<dynamic>() =>
          rawQuestions
              .whereType<Map>()
              .map(
                (item) => AdminReadingQuestionInput.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false),
        _ => const <AdminReadingQuestionInput>[],
      },
      generationMeta: AdminAiGenerationMeta.fromJson(
        _adminAiCoerceMap(json?['generation_meta']),
      ),
    );
  }
}

String? _adminAiEmptyStringAsNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

DateTime? _adminAiDateTimeFromValue(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}

String? _adminAiProviderFromValue(Object? value) {
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  if (adminAiSupportedProviders.contains(normalized)) {
    return normalized;
  }
  return normalized;
}

Map<String, dynamic>? _adminAiCoerceMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}
