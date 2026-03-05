import '../../data/local/app_content_local_datasource.dart';
import '../../domain/entities/grammar_page.dart';
import '../../domain/entities/grammar_page_detail.dart';
import '../../domain/entities/grammar_module.dart';
import '../../domain/repositories/grammar_repository.dart';

class LocalGrammarRepository implements GrammarRepository {
  LocalGrammarRepository(this._local);

  final AppContentLocalDataSource _local;

  @override
  Future<List<GrammarModule>> getModules() {
    return _local.getGrammarModules();
  }

  @override
  Future<List<GrammarPage>> getPagesByModule({
    required int modulId,
  }) {
    return _local.getGrammarPagesByModule(modulId);
  }

  @override
  Future<GrammarPageDetail> getPageDetail({
    required int sayfaId,
  }) {
    return _local.getGrammarPageDetail(sayfaId);
  }
}
