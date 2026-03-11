import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?>? _cachedDictionaryDatabasePath;

Future<String?> resolveDictionaryDatabasePath({
  String assetPath = 'assets/db/dictionary_local.sqlite',
  String fileName = 'dictionary_local.sqlite',
}) {
  return _cachedDictionaryDatabasePath ??= _copyDictionaryAsset(
    assetPath: assetPath,
    fileName: fileName,
  );
}

Future<String?> _copyDictionaryAsset({
  required String assetPath,
  required String fileName,
}) async {
  final directory = await getApplicationSupportDirectory();
  final file = File(p.join(directory.path, fileName));
  if (await file.exists()) {
    return file.path;
  }

  final byteData = await rootBundle.load(assetPath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    flush: true,
  );
  return file.path;
}
