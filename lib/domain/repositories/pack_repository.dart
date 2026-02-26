import '../entities/pack.dart';

abstract class PackRepository {
  Future<List<Pack>> getPacksWithWordCount();

  Future<Pack?> getPackById(String packId);
}
