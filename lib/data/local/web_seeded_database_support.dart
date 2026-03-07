import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_database_runtime_info.dart';

final Uri _sqlite3Uri = Uri.parse('sqlite3.wasm');
final Uri _driftWorkerUri = Uri.parse('drift_worker.dart.js');

Future<String> loadSeedVersion(String metaAssetPath) async {
  try {
    final String raw = await rootBundle.loadString(metaAssetPath);
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return (decoded['dataset_version'] ?? '').toString().trim();
    }
  } catch (_) {
    // Fallback to an unversioned database name.
  }
  return '';
}

Future<Uint8List> loadSeedBytes(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

String buildSeededDatabaseName({
  required String prefix,
  required String version,
}) {
  final String cleanVersion = version.trim();
  if (cleanVersion.isEmpty) {
    return prefix;
  }
  return '${prefix}_$cleanVersion';
}

Future<void> cleanupStaleSeededDatabases({
  required String prefsKey,
  required String currentDatabaseName,
}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final List<String> knownNames =
      prefs.getStringList(prefsKey) ?? const <String>[];

  for (final String oldName in knownNames) {
    final String trimmed = oldName.trim();
    if (trimmed.isEmpty || trimmed == currentDatabaseName) {
      continue;
    }
    await _deleteDatabaseIfPresent(trimmed);
  }

  await prefs.setStringList(prefsKey, <String>[currentDatabaseName]);
}

Future<WasmDatabaseResult> openSeededWebDatabase({
  required String databaseName,
  required String assetPath,
}) async {
  try {
    final WasmDatabaseResult result = await _openSeededWebDatabaseOnce(
      databaseName: databaseName,
      assetPath: assetPath,
    );
    await _validateDatabaseFile(result.resolvedExecutor);
    return result;
  } catch (error) {
    if (!_isRecoverableDatabaseError(error)) {
      rethrow;
    }

    await _deleteDatabaseIfPresent(databaseName);

    final WasmDatabaseResult retryResult = await _openSeededWebDatabaseOnce(
      databaseName: databaseName,
      assetPath: assetPath,
    );
    await _validateDatabaseFile(retryResult.resolvedExecutor);
    return retryResult;
  }
}

LocalDatabaseRuntimeInfo runtimeInfoFromWasmResult({
  required String databaseName,
  required WasmDatabaseResult result,
}) {
  final WasmStorageImplementation implementation = result.chosenImplementation;
  final bool isPersistent =
      implementation != WasmStorageImplementation.inMemory;
  final bool isReliable =
      implementation != WasmStorageImplementation.unsafeIndexedDb &&
          implementation != WasmStorageImplementation.inMemory;

  return LocalDatabaseRuntimeInfo(
    databaseName: databaseName,
    storageMode: switch (implementation) {
      WasmStorageImplementation.opfsShared ||
      WasmStorageImplementation.opfsLocks =>
        LocalDatabaseStorageMode.opfs,
      WasmStorageImplementation.sharedIndexedDb ||
      WasmStorageImplementation.unsafeIndexedDb =>
        LocalDatabaseStorageMode.indexedDb,
      WasmStorageImplementation.inMemory => LocalDatabaseStorageMode.inMemory,
    },
    isPersistent: isPersistent,
    isReliable: isReliable,
    missingFeatures: result.missingFeatures
        .map((MissingBrowserFeature feature) => feature.name)
        .toList(growable: false),
  );
}

Future<void> _deleteDatabaseIfPresent(String databaseName) async {
  final WasmProbeResult probe = await WasmDatabase.probe(
    sqlite3Uri: _sqlite3Uri,
    driftWorkerUri: _driftWorkerUri,
    databaseName: databaseName,
  );

  for (final ExistingDatabase existing in probe.existingDatabases) {
    if (existing.$2 == databaseName) {
      await probe.deleteDatabase(existing);
    }
  }
}

Future<WasmDatabaseResult> _openSeededWebDatabaseOnce({
  required String databaseName,
  required String assetPath,
}) {
  return WasmDatabase.open(
    databaseName: databaseName,
    sqlite3Uri: _sqlite3Uri,
    driftWorkerUri: _driftWorkerUri,
    initializeDatabase: () => loadSeedBytes(assetPath),
  );
}

Future<void> _validateDatabaseFile(DatabaseConnection connection) async {
  try {
    await connection.ensureOpen(_SeedValidationExecutorUser());
    await connection.runSelect('PRAGMA user_version;', const <Object?>[]);
  } catch (_) {
    await connection.close();
    rethrow;
  }
}

bool _isRecoverableDatabaseError(Object error) {
  final String text = error.toString().toLowerCase();
  return text.contains('file is not a database') ||
      text.contains('sqliteexception(26') ||
      text.contains('code 26');
}

class _SeedValidationExecutorUser extends QueryExecutorUser {
  _SeedValidationExecutorUser();

  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
