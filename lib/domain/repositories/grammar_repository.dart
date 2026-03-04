import '../entities/grammar_module.dart';
import '../entities/grammar_page.dart';
import '../entities/grammar_page_detail.dart';

abstract class GrammarRepository {
  Future<List<GrammarModule>> getModules();

  Future<List<GrammarPage>> getPagesByModule({
    required int modulId,
  });

  Future<GrammarPageDetail> getPageDetail({
    required int sayfaId,
  });
}

