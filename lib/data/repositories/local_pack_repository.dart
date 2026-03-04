import '../../domain/entities/pack.dart';
import '../../domain/repositories/pack_repository.dart';
import '../local/app_content_local_datasource.dart';

class LocalPackRepository implements PackRepository {
  LocalPackRepository(this._local);

  final AppContentLocalDataSource _local;

  @override
  Future<List<Pack>> getPacksWithWordCount() {
    return _local.getPacksWithWordCount();
  }

  @override
  Future<Pack?> getPackById(String packId) {
    return _local.getPackById(packId);
  }
}
