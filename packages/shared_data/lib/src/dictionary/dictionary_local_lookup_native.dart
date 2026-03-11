import 'package:shared_domain/shared_domain.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

Future<DictionaryEntry?> lookupLocalDictionaryEntry({
  required String databasePath,
  required String normalizedQuery,
}) async {
  final database = sqlite.sqlite3.open(
    databasePath,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    final result = database.select(
      '''
      SELECT en_word, tr_meaning, pos
      FROM local_dictionary_entries
      WHERE en_word_normalized = ?
      ORDER BY seq_id ASC
      LIMIT 1
      ''',
      <Object?>[normalizedQuery],
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    final enWord = row['en_word']?.toString().trim() ?? '';
    final trMeaning = row['tr_meaning']?.toString().trim() ?? '';
    final pos = row['pos']?.toString().trim();
    if (enWord.isEmpty || trMeaning.isEmpty) {
      return null;
    }

    return DictionaryEntry(
      enWord: enWord,
      trMeaning: trMeaning,
      pos: pos == null || pos.isEmpty ? null : pos,
    );
  } finally {
    database.close();
  }
}
