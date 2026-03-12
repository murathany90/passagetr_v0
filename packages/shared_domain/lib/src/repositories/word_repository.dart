import '../entities/word_entry.dart';

abstract interface class WordRepository {
  Future<List<WordEntry>> fetchWords({String? packId});
  Future<List<WordEntry>> fetchWordsByIds(Iterable<String> ids);
}
