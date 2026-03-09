import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<QueryExecutor> createAppDatabaseExecutor({
  String dbName = 'passagetr_v2_local.db',
}) async {
  final directory = await getApplicationSupportDirectory();
  final file = File(p.join(directory.path, dbName));
  return NativeDatabase.createInBackground(file);
}

QueryExecutor createInMemoryExecutor() {
  return NativeDatabase.memory();
}
