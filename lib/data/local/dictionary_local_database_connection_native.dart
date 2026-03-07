import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_database_runtime_info.dart';

DatabaseConnection openDictionaryLocalDatabaseConnection() {
  return DatabaseConnection.delayed(_openDictionaryLocalDatabaseConnection());
}

Future<LocalDatabaseRuntimeInfo> dictionaryLocalDatabaseRuntimeInfo() async {
  return LocalDatabaseRuntimeInfo.native(
      databaseName: 'dictionary_local.sqlite');
}

Future<DatabaseConnection> _openDictionaryLocalDatabaseConnection() async {
  final Directory directory = await getApplicationDocumentsDirectory();
  final File file = File(p.join(directory.path, 'dictionary_local.sqlite'));
  await _copyPrebuiltDictionaryIfMissing(file);
  return DatabaseConnection(NativeDatabase.createInBackground(file));
}

Future<void> _copyPrebuiltDictionaryIfMissing(File targetFile) async {
  if (await targetFile.exists()) {
    return;
  }

  try {
    final ByteData data =
        await rootBundle.load('assets/db/dictionary_local.sqlite');
    final Uint8List bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsBytes(bytes, flush: true);
  } catch (_) {
    // Asset yoksa Drift onCreate ile bos local DB olusturur.
  }
}
