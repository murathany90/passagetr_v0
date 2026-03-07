import 'package:drift/drift.dart';

import 'local_database_runtime_info.dart';
import 'web_seeded_database_support.dart';

const String _databasePrefix = 'app_content_web_v2';
const String _knownNamesPrefsKey = 'web_seeded_db_names_app_content_v2';

LocalDatabaseRuntimeInfo? _runtimeInfo;

DatabaseConnection openAppContentDatabaseConnection() {
  return DatabaseConnection.delayed(_openAppContentDatabaseConnection());
}

Future<LocalDatabaseRuntimeInfo> appContentLocalDatabaseRuntimeInfo() async {
  return _runtimeInfo ??
      const LocalDatabaseRuntimeInfo(
        databaseName: _databasePrefix,
        storageMode: LocalDatabaseStorageMode.inMemory,
        isPersistent: false,
        isReliable: false,
      );
}

Future<DatabaseConnection> _openAppContentDatabaseConnection() async {
  final String version =
      await loadSeedVersion('assets/db/app_content.meta.json');
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
    assetPath: 'assets/db/app_content.db',
  );
  _runtimeInfo = runtimeInfoFromWasmResult(
    databaseName: databaseName,
    result: result,
  );
  return result.resolvedExecutor;
}
