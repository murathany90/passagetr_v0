import 'grammar_example.dart';
import 'grammar_mini_test.dart';
import 'grammar_module.dart';
import 'grammar_page.dart';

class GrammarBundle {
  const GrammarBundle({
    required this.modules,
  });

  final List<GrammarModuleBundleItem> modules;

  bool get isEmpty => modules.isEmpty;
}

class GrammarModuleBundleItem {
  const GrammarModuleBundleItem({
    required this.module,
    required this.pages,
    this.sourceModuleId,
  });

  final GrammarModule module;
  final List<GrammarPageBundleItem> pages;
  final int? sourceModuleId;
}

class GrammarPageBundleItem {
  const GrammarPageBundleItem({
    required this.page,
    required this.examples,
    required this.tests,
    this.sourcePageId,
  });

  final GrammarPage page;
  final List<GrammarExample> examples;
  final List<GrammarMiniTest> tests;
  final int? sourcePageId;
}
