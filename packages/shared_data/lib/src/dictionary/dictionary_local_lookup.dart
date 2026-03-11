import 'package:shared_domain/shared_domain.dart';

import 'dictionary_local_lookup_stub.dart'
    if (dart.library.io) 'dictionary_local_lookup_native.dart'
    as impl;

Future<DictionaryEntry?> lookupLocalDictionaryEntry({
  required String databasePath,
  required String normalizedQuery,
}) {
  return impl.lookupLocalDictionaryEntry(
    databasePath: databasePath,
    normalizedQuery: normalizedQuery,
  );
}
