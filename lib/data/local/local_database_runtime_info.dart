enum LocalDatabaseStorageMode {
  native,
  opfs,
  indexedDb,
  inMemory,
}

class LocalDatabaseRuntimeInfo {
  const LocalDatabaseRuntimeInfo({
    required this.databaseName,
    required this.storageMode,
    required this.isPersistent,
    required this.isReliable,
    this.missingFeatures = const <String>[],
  });

  final String databaseName;
  final LocalDatabaseStorageMode storageMode;
  final bool isPersistent;
  final bool isReliable;
  final List<String> missingFeatures;

  factory LocalDatabaseRuntimeInfo.native({
    required String databaseName,
  }) {
    return LocalDatabaseRuntimeInfo(
      databaseName: databaseName,
      storageMode: LocalDatabaseStorageMode.native,
      isPersistent: true,
      isReliable: true,
    );
  }

  String? get warningMessage {
    if (storageMode == LocalDatabaseStorageMode.inMemory) {
      return 'Tarayici yerel veriyi kalici saklayamiyor. Oturum kapaninca indirme tekrar gerekebilir.';
    }
    if (!isReliable) {
      return 'Tarayici yerel veriyi sinirli guvenilirlikle sakliyor. Ayni anda birden fazla sekme acmayin.';
    }
    if (!isPersistent) {
      return 'Yerel veri gecici depolamada tutuluyor. Tarayici temizlenirse yeniden indirilebilir.';
    }
    return null;
  }
}
