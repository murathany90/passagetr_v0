import '../entities/grammar_module.dart';
import '../entities/grammar_module_detail.dart';

abstract interface class GrammarRepository {
  Future<List<GrammarModule>> fetchModules();
  Future<GrammarModuleDetail?> fetchModuleDetail(int moduleId);
}
