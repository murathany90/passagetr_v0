import 'grammar_module.dart';

class GrammarExample {
  const GrammarExample({
    required this.id,
    required this.sortOrder,
    required this.english,
    required this.turkish,
    this.description,
  });

  final int id;
  final int sortOrder;
  final String english;
  final String turkish;
  final String? description;
}

class GrammarQuestion {
  const GrammarQuestion({
    required this.id,
    required this.sortOrder,
    required this.prompt,
    required this.options,
    this.correctAnswer,
    this.description,
  });

  final int id;
  final int sortOrder;
  final String prompt;
  final List<String> options;
  final String? correctAnswer;
  final String? description;
}

class GrammarPageDetail {
  const GrammarPageDetail({
    required this.id,
    required this.pageNumber,
    required this.title,
    required this.htmlContent,
    required this.wordCount,
    this.examples = const <GrammarExample>[],
    this.questions = const <GrammarQuestion>[],
  });

  final int id;
  final int pageNumber;
  final String title;
  final String htmlContent;
  final int wordCount;
  final List<GrammarExample> examples;
  final List<GrammarQuestion> questions;
}

class GrammarModuleDetail {
  const GrammarModuleDetail({
    required this.module,
    this.pages = const <GrammarPageDetail>[],
  });

  final GrammarModule module;
  final List<GrammarPageDetail> pages;
}
