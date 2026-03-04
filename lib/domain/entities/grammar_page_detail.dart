import 'grammar_example.dart';
import 'grammar_mini_test.dart';
import 'grammar_page.dart';

class GrammarPageDetail {
  const GrammarPageDetail({
    required this.page,
    required this.examples,
    required this.tests,
  });

  final GrammarPage page;
  final List<GrammarExample> examples;
  final List<GrammarMiniTest> tests;
}

