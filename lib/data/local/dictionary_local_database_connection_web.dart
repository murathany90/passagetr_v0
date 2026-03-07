import 'package:drift/drift.dart';

import 'local_database_runtime_info.dart';
import 'web_seeded_database_support.dart';

const String _databasePrefix = 'dictionary_local_web_v2';
const String _knownNamesPrefsKey =
    'web_seeded_db_names_dictionary_local_v2';

LocalDatabaseRuntimeInfo? _runtimeInfo;

DatabaseConnection openDictionaryLocalDatabaseConnection() {
  return DatabaseConnection.delayed(_openDictionaryLocalDatabaseConnection());
}

Future<LocalDatabaseRuntimeInfo> dictionaryLocalDatabaseRuntimeInfo() async {
  return _runtimeInfo ??
      const LocalDatabaseRuntimeInfo(
        databaseName: _databasePrefix,
        storageMode: LocalDatabaseStorageMode.inMemory,
        isPersistent: false,
        isReliable: false,
      );
}

Future<DatabaseConnection> _openDictionaryLocalDatabaseConnection() async {
  final String version =
      await loadSeedVersion('assets/db/dictionary_local.meta.json');
  final String databaseName = buildSeededDatabaseName(
    prefix: _databasePrefix,
    version: version,
  );

  await cleanupStaleSeededDatabases(
    prefsKey: _knownNamesPrefsKey,
    currentDatabaseName: databaseName,
  );

  final result = await openSeededWebDatabase(
    databaseName: databaseName,
    assetPath: 'assets/db/dictionary_local.sqlite',
  );
  _runtimeInfo = runtimeInfoFromWasmResult(
    databaseName: databaseName,
    result: result,
  );
  return result.resolvedExecutor;
}
