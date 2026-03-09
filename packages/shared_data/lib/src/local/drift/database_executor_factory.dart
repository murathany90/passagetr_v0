import 'package:drift/drift.dart';

import 'app_database_contract.dart';
import 'database_executor_factory_stub.dart'
    if (dart.library.io) 'database_executor_factory_native.dart'
    as impl;

Future<QueryExecutor> createAppDatabaseExecutor({
  String dbName = AppDatabaseContract.databaseFileName,
}) {
  return impl.createAppDatabaseExecutor(dbName: dbName);
}

QueryExecutor createInMemoryExecutor() {
  return impl.createInMemoryExecutor();
}
