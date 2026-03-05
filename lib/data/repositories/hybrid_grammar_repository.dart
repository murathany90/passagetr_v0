import 'dart:async';

import '../../data/local/app_content_local_datasource.dart';
import '../../domain/entities/grammar_bundle.dart';
import '../../domain/entities/grammar_module.dart';
import '../../domain/entities/grammar_page.dart';
import '../../domain/entities/grammar_page_detail.dart';
import '../../domain/repositories/grammar_repository.dart';

class HybridGrammarRepository implements GrammarRepository {
  HybridGrammarRepository({
    required GrammarLocalStore localDataSource,
    required GrammarRepository remoteDataSource,
  })  : _local = localDataSource,
        _remote = remoteDataSource;

  final GrammarLocalStore _local;
  final GrammarRepository _remote;

  DateTime? _lastSyncAt;
  bool _syncInFlight = false;

  static const Duration _defaultStaleAfter = Duration(hours: 6);

  Future<void> syncIfStale({
    Duration staleAfter = _defaultStaleAfter,
  }) async {
    if (_syncInFlight) {
      return;
    }
    final DateTime? lastSync = _lastSyncAt;
    if (lastSync != null && DateTime.now().difference(lastSync) < staleAfter) {
      return;
    }
    await _syncFromRemote();
  }

  Future<void> forceSync() => _syncFromRemote();

  @override
  Future<List<GrammarModule>> getModules() async {
    final List<GrammarModule> localModules = await _local.getGrammarModules();
    if (localModules.isNotEmpty) {
      unawaited(syncIfStale());
      return localModules;
    }

    try {
      await _syncFromRemote();
    } catch (_) {
      // Ignore sync error here, local result is source of truth.
    }
    final List<GrammarModule> syncedModules = await _local.getGrammarModules();
    if (syncedModules.isNotEmpty) {
      return syncedModules;
    }
    throw StateError(
      'Lokal gramer içerigi yok. İnternetsiz kullanım için içerik paketi gereklidir.',
    );
  }

  @override
  Future<List<GrammarPage>> getPagesByModule({
    required int modulId,
  }) async {
    final List<GrammarPage> localPages =
        await _local.getGrammarPagesByModule(modulId);
    if (localPages.isNotEmpty) {
      unawaited(syncIfStale());
      return localPages;
    }

    try {
      await _syncFromRemote();
    } catch (_) {
      // fall through and try local again
    }
    final List<GrammarPage> syncedPages =
        await _local.getGrammarPagesByModule(modulId);
    if (syncedPages.isNotEmpty) {
      return syncedPages;
    }

    throw StateError(
      'Lokal içerik yok. Güncelleme alınamadı, internet bağlantısını kontrol edin.',
    );
  }

  @override
  Future<GrammarPageDetail> getPageDetail({
    required int sayfaId,
  }) async {
    try {
      final GrammarPageDetail localDetail =
          await _local.getGrammarPageDetail(sayfaId);
      unawaited(syncIfStale());
      return localDetail;
    } catch (_) {
      // continue to sync attempt
    }

    try {
      await _syncFromRemote();
    } catch (_) {
      // continue and try local once more
    }

    try {
      return await _local.getGrammarPageDetail(sayfaId);
    } catch (_) {
      throw StateError(
        'Lokal içerik yok. Güncelleme alınamadı, internet bağlantısını kontrol edin.',
      );
    }
  }

  Future<void> _syncFromRemote() async {
    if (_syncInFlight) {
      return;
    }
    _syncInFlight = true;
    try {
      final List<GrammarModule> modules = await _remote.getModules();
      if (modules.isEmpty) {
        return;
      }

      final List<GrammarModuleBundleItem> bundleModules =
          <GrammarModuleBundleItem>[];
      for (final GrammarModule module in modules) {
        final List<GrammarPage> pages =
            await _remote.getPagesByModule(modulId: module.id);
        final List<GrammarPageBundleItem> bundlePages =
            <GrammarPageBundleItem>[];
        for (final GrammarPage page in pages) {
          final GrammarPageDetail detail =
              await _remote.getPageDetail(sayfaId: page.id);
          bundlePages.add(
            GrammarPageBundleItem(
              page: detail.page,
              sourcePageId: detail.page.id,
              examples: detail.examples,
              tests: detail.tests,
            ),
          );
        }
        bundleModules.add(
          GrammarModuleBundleItem(
            module: module,
            sourceModuleId: module.id,
            pages: bundlePages,
          ),
        );
      }

      await _local.replaceGrammarBundle(
        GrammarBundle(modules: bundleModules),
      );
      _lastSyncAt = DateTime.now();
    } finally {
      _syncInFlight = false;
    }
  }
}
