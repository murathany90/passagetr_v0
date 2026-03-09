abstract interface class SyncConnectivityMonitor {
  Stream<bool> get onStatusChanged;
  Future<bool> isOnline();
  Future<void> dispose();
}

class PreviewSyncConnectivityMonitor implements SyncConnectivityMonitor {
  const PreviewSyncConnectivityMonitor();

  @override
  Stream<bool> get onStatusChanged => const Stream<bool>.empty();

  @override
  Future<bool> isOnline() async => false;

  @override
  Future<void> dispose() async {}
}
