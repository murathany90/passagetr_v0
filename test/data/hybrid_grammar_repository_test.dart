import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/data/local/app_content_local_datasource.dart';
import 'package:passagetr/data/repositories/hybrid_grammar_repository.dart';
import 'package:passagetr/domain/entities/grammar_bundle.dart';
import 'package:passagetr/domain/entities/grammar_example.dart';
import 'package:passagetr/domain/entities/grammar_mini_test.dart';
import 'package:passagetr/domain/entities/grammar_module.dart';
import 'package:passagetr/domain/entities/grammar_page.dart';
import 'package:passagetr/domain/entities/grammar_page_detail.dart';
import 'package:passagetr/domain/repositories/grammar_repository.dart';

void main() {
  group('HybridGrammarRepository', () {
    test('returns local modules when local content exists', () async {
      final FakeGrammarLocalStore local = FakeGrammarLocalStore.withSeed();
      final FakeGrammarRemoteRepository remote =
          FakeGrammarRemoteRepository.withSeed();
      final HybridGrammarRepository repository = HybridGrammarRepository(
        localDataSource: local,
        remoteDataSource: remote,
      );

      final List<GrammarModule> modules = await repository.getModules();

      expect(modules, isNotEmpty);
      expect(modules.first.baslik, 'Temel Kavramlar');
    });

    test('syncs from remote when local modules are empty', () async {
      final FakeGrammarLocalStore local = FakeGrammarLocalStore.empty();
      final FakeGrammarRemoteRepository remote =
          FakeGrammarRemoteRepository.withSeed();
      final HybridGrammarRepository repository = HybridGrammarRepository(
        localDataSource: local,
        remoteDataSource: remote,
      );

      final List<GrammarModule> modules = await repository.getModules();

      expect(modules, isNotEmpty);
      expect(local.modules, isNotEmpty);
      expect(local.pagesByModule[1], isNotEmpty);
      expect(local.details[1001], isNotNull);
    });

    test('throws local-missing error when local empty and remote fails',
        () async {
      final FakeGrammarLocalStore local = FakeGrammarLocalStore.empty();
      final FakeGrammarRemoteRepository remote =
          FakeGrammarRemoteRepository.throwing(StateError('remote fail'));
      final HybridGrammarRepository repository = HybridGrammarRepository(
        localDataSource: local,
        remoteDataSource: remote,
      );

      expect(
        repository.getModules(),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('Lokal gramer içerigi yok'),
          ),
        ),
      );
    });
  });
}

class FakeGrammarLocalStore implements GrammarLocalStore {
  FakeGrammarLocalStore.empty();

  FakeGrammarLocalStore.withSeed() {
    final GrammarPageDetail detail = _sampleDetail();
    modules = <GrammarModule>[_sampleModule()];
    pagesByModule = <int, List<GrammarPage>>{
      1: <GrammarPage>[detail.page],
    };
    details = <int, GrammarPageDetail>{
      detail.page.id: detail,
    };
  }

  List<GrammarModule> modules = <GrammarModule>[];
  Map<int, List<GrammarPage>> pagesByModule = <int, List<GrammarPage>>{};
  Map<int, GrammarPageDetail> details = <int, GrammarPageDetail>{};

  @override
  Future<List<GrammarModule>> getGrammarModules() async => modules;

  @override
  Future<List<GrammarPage>> getGrammarPagesByModule(int modulId) async =>
      pagesByModule[modulId] ?? <GrammarPage>[];

  @override
  Future<GrammarPageDetail> getGrammarPageDetail(int sayfaId) async {
    final GrammarPageDetail? detail = details[sayfaId];
    if (detail == null) {
      throw StateError('Lokal gramer içerigi yok: sayfa $sayfaId');
    }
    return detail;
  }

  @override
  Future<void> replaceGrammarBundle(GrammarBundle bundle) async {
    final List<GrammarModule> nextModules = <GrammarModule>[];
    final Map<int, List<GrammarPage>> nextPages = <int, List<GrammarPage>>{};
    final Map<int, GrammarPageDetail> nextDetails = <int, GrammarPageDetail>{};
    for (final GrammarModuleBundleItem moduleItem in bundle.modules) {
      nextModules.add(moduleItem.module);
      nextPages[moduleItem.module.id] =
          moduleItem.pages.map((e) => e.page).toList();
      for (final GrammarPageBundleItem pageItem in moduleItem.pages) {
        nextDetails[pageItem.page.id] = GrammarPageDetail(
          page: pageItem.page,
          examples: pageItem.examples,
          tests: pageItem.tests,
        );
      }
    }
    modules = nextModules;
    pagesByModule = nextPages;
    details = nextDetails;
  }
}

class FakeGrammarRemoteRepository implements GrammarRepository {
  FakeGrammarRemoteRepository.withSeed() : _error = null;

  FakeGrammarRemoteRepository.throwing(this._error);

  final Object? _error;

  @override
  Future<List<GrammarModule>> getModules() async {
    if (_error != null) {
      throw _error;
    }
    return <GrammarModule>[_sampleModule()];
  }

  @override
  Future<List<GrammarPage>> getPagesByModule({required int modulId}) async {
    if (_error != null) {
      throw _error;
    }
    if (modulId != 1) {
      return const <GrammarPage>[];
    }
    return <GrammarPage>[_sampleDetail().page];
  }

  @override
  Future<GrammarPageDetail> getPageDetail({required int sayfaId}) async {
    if (_error != null) {
      throw _error;
    }
    if (sayfaId != 1001) {
      throw StateError('missing');
    }
    return _sampleDetail();
  }
}

GrammarModule _sampleModule() {
  return const GrammarModule(
    id: 1,
    sira: 1,
    baslik: 'Temel Kavramlar',
    dosyaAdi: '01_temel_kavramlar.md',
    toplamSayfa: 1,
    icon: 'ğŸ“˜',
    renk: '#4776E6',
  );
}

GrammarPageDetail _sampleDetail() {
  const GrammarPage page = GrammarPage(
    id: 1001,
    modulId: 1,
    sayfaNo: 1,
    baslik: 'Giris',
    icerikHtml: '<p>Merhaba</p>',
    kelimeSayisi: 12,
  );

  return const GrammarPageDetail(
    page: page,
    examples: <GrammarExample>[
      GrammarExample(
        id: 1,
        sayfaId: 1001,
        sira: 0,
        ingilizce: 'She is a teacher.',
        turkce: 'O bir ogretmendir.',
        aciklama: 'To be',
      ),
    ],
    tests: <GrammarMiniTest>[
      GrammarMiniTest(
        id: 1,
        sayfaId: 1001,
        sira: 0,
        soru: 'She ___ a teacher.',
        secenekler: <String, String>{'A': 'is', 'B': 'are'},
        dogruCevap: 'A',
        aciklama: 'Subject singular.',
      ),
    ],
  );
}

