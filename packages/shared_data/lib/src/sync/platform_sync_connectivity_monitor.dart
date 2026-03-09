import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'sync_connectivity_monitor.dart';

class PlatformSyncConnectivityMonitor implements SyncConnectivityMonitor {
  PlatformSyncConnectivityMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = _isOnlineResult(results);
      if (_lastKnownStatus == isOnline) {
        return;
      }
      _lastKnownStatus = isOnline;
      _controller.add(isOnline);
    });
  }

  final Connectivity _connectivity;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  bool? _lastKnownStatus;

  @override
  Stream<bool> get onStatusChanged => _controller.stream;

  @override
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    final isOnline = _isOnlineResult(results);
    _lastKnownStatus = isOnline;
    return isOnline;
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }

  bool _isOnlineResult(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
