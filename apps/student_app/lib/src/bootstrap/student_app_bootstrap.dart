import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_domain/shared_domain.dart';

import '../app/student_app.dart';
import '../core/student_providers.dart';

class StudentAppBootstrap extends ConsumerStatefulWidget {
  const StudentAppBootstrap({super.key});

  @override
  ConsumerState<StudentAppBootstrap> createState() =>
      _StudentAppBootstrapState();
}

class _StudentAppBootstrapState extends ConsumerState<StudentAppBootstrap> {
  bool _smokeActionScheduled = false;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _connectivityBound = false;
  AppLifecycleListener? _appLifecycleListener;

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onHide: _stopActiveTts,
      onInactive: _stopActiveTts,
      onPause: _stopActiveTts,
      onDetach: _stopActiveTts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(studentBootstrapProvider);

    if (bootstrap.hasValue && !_smokeActionScheduled) {
      _smokeActionScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runSmokeActionIfRequested();
      });
    }
    if (bootstrap.hasValue && !_connectivityBound) {
      _connectivityBound = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bindConnectivitySync();
      });
    }

    if (bootstrap.hasError) {
      debugPrint('student_bootstrap_error:${bootstrap.error}');
    }

    return const StudentApp();
  }

  @override
  void dispose() {
    _appLifecycleListener?.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _runSmokeActionIfRequested() async {
    final smokeAction = _resolveSmokeAction(Uri.base);
    if (smokeAction == null) {
      return;
    }

    final controller = ref.read(studentAccessProvider.notifier);
    debugPrint('student_web_smoke_action:$smokeAction');

    if (smokeAction == 'anonymous-auth') {
      final result = await controller.signInAnonymously();
      debugPrint('student_web_smoke_result:$result');
      return;
    }

    if (smokeAction == 'sign-out') {
      final result = await controller.signOut();
      debugPrint('student_web_smoke_result:$result');
      return;
    }

    debugPrint('student_web_smoke_result:unsupported:$smokeAction');
  }

  String? _resolveSmokeAction(Uri baseUri) {
    final queryAction = baseUri.queryParameters['smoke'];
    if (queryAction != null && queryAction.isNotEmpty) {
      return queryAction;
    }

    final fragment = baseUri.fragment;
    if (fragment.isEmpty || !fragment.contains('?')) {
      return null;
    }

    final query = fragment.substring(fragment.indexOf('?') + 1);
    final fragmentUri = Uri(query: query);
    final fragmentAction = fragmentUri.queryParameters['smoke'];
    if (fragmentAction == null || fragmentAction.isEmpty) {
      return null;
    }

    return fragmentAction;
  }

  Future<void> _bindConnectivitySync() async {
    if (!mounted) {
      return;
    }
    if (kIsWeb) {
      return;
    }

    final monitor = ref.read(studentSyncConnectivityMonitorProvider);
    _connectivitySubscription = monitor.onStatusChanged.listen((isOnline) {
      if (!isOnline) {
        return;
      }
      _runReconnectionSync();
    });
  }

  Future<void> _runReconnectionSync() async {
    final syncRepository = ref.read(studentSyncRepositoryProvider);
    await syncRepository.syncIfStale(SyncScope.content);
    await syncRepository.syncIfStale(SyncScope.progress);
  }

  void _stopActiveTts() {
    ref.read(studentTtsControllerProvider.notifier).stop();
  }
}
