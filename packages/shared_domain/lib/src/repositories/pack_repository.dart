import '../entities/content_pack.dart';

abstract interface class PackRepository {
  Future<List<ContentPack>> fetchPacks();
}
