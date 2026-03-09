import 'package:drift/drift.dart';

Future<QueryExecutor> createAppDatabaseExecutor({
  String dbName = 'passagetr_v2_local.db',
}) async {
  return createInMemoryExecutor();
}

QueryExecutor createInMemoryExecutor() {
  return LazyDatabase(() async {
    throw UnsupportedError(
      'Local Drift database is unavailable on this platform.',
    );
  });
}
