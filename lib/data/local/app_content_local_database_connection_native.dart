import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_database_runtime_info.dart';

DatabaseConnection openAppContentDatabaseConnection() {
  return DatabaseConnection.delayed(_openAppContentDatabaseConnection());
}

Future<LocalDatabaseRuntimeInfo> appContentLocalDatabaseRuntimeInfo() async {
  return LocalDatabaseRuntimeInfo.native(databaseName: 'app_content.db');
}

Future<DatabaseConnection> _openAppContentDatabaseConnection() async {
  final Directory directory = await getApplicationDocumentsDirectory();
  final File file = File(p.join(directory.path, 'app_content.db'));
  await _copyAppContentIfNeeded(file);
  return DatabaseConnection(NativeDatabase.createInBackground(file));
}

Future<void> _copyAppContentIfNeeded(File targetFile) async {
  final Directory directory = targetFile.parent;
  final File metaFile = File(p.join(directory.path, 'app_content_meta.json'));

  final Map<String, dynamic> assetMeta = await _loadAssetMeta();
  final String assetVersion =
      (assetMeta['dataset_version'] ?? '').toString().trim();

  bool shouldCopy = !await targetFile.exists();
  if (!shouldCopy && assetVersion.isNotEmpty) {
    if (!await metaFile.exists()) {
      shouldCopy = true;
    } else {
      try {
        final Map<String, dynamic> localMeta = jsonDecode(
          await metaFile.readAsString(),
        ) as Map<String, dynamic>;
        final String localVersion =
            (localMeta['dataset_version'] ?? '').toString().trim();
        shouldCopy = localVersion != assetVersion;
      } catch (_) {
        shouldCopy = true;
      }
    }
  }

  if (!shouldCopy) {
    return;
  }

  final ByteData data = await rootBundle.load('assets/db/app_content.db');
  final Uint8List bytes = data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  await directory.create(recursive: true);
  await targetFile.writeAsBytes(bytes, flush: true);

  final Map<String, dynamic> finalMeta = assetMeta.isEmpty
      ? <String, dynamic>{
          'dataset_version': '',
          'generated_at': DateTime.now().toUtc().toIso8601String(),
        }
      : assetMeta;
  await metaFile.writeAsString(
    jsonEncode(finalMeta),
    flush: true,
  );
}

Future<Map<String, dynamic>> _loadAssetMeta() async {
  try {
    final String raw =
        await rootBundle.loadString('assets/db/app_content.meta.json');
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return const <String, dynamic>{};
  } catch (_) {
    return const <String, dynamic>{};
  }
}
