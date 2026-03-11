import '../entities/dictionary_entry.dart';

abstract interface class DictionaryRepository {
  Future<DictionaryEntry?> lookupWord(String query);
}
