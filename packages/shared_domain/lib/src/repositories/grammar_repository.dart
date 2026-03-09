import '../entities/grammar_module.dart';

abstract interface class GrammarRepository {
  Future<List<GrammarModule>> fetchModules();
}
