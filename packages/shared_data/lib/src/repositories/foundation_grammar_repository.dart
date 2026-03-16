import 'dart:convert';

import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';
import '../local/drift/local_sync_models.dart';
import '../local/drift/local_sync_store.dart';

class FoundationGrammarRepository implements GrammarRepository {
  const FoundationGrammarRepository.preview()
    : _database = null,
      _config = null;

  const FoundationGrammarRepository({
    LocalSyncStore? database,
    required AppConfig config,
  }) : _database = database,
       _config = config;

  final LocalSyncStore? _database;
  final AppConfig? _config;

  @override
  Future<List<GrammarModule>> fetchModules() async {
    try {
      final remoteItems = await _readModulesFromRemote();
      if (remoteItems.isNotEmpty) {
        _syncGrammarModulesToLocal(remoteItems);
        return remoteItems;
      }
    } catch (_) {
      // Fallback to local
    }

    final localItems = await _readModulesFromLocal();
    if (localItems.isNotEmpty) {
      return localItems;
    }

    return _previewModules;
  }

  @override
  Future<GrammarModuleDetail?> fetchModuleDetail(int moduleId) async {
    try {
      final remoteDetail = await _readDetailFromRemote(moduleId);
      if (remoteDetail != null) {
        _syncGrammarDetailToLocal(remoteDetail);
        return remoteDetail;
      }
    } catch (_) {
      // Fallback to local
    }

    final localDetail = await _readDetailFromLocal(moduleId);
    if (localDetail != null) {
      return localDetail;
    }

    return _previewDetails[moduleId];
  }

  Future<void> _syncGrammarModulesToLocal(List<GrammarModule> modules) async {
    final database = _database;
    if (database == null) return;

    for (final item in modules) {
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'grammar',
          entityType: 'gramer_modulleri',
          entityId: item.id.toString(),
          payloadJson: jsonEncode({
            'id': item.id,
            'sira': item.sortOrder,
            'baslik': item.title,
            'toplam_sayfa': item.pageCount,
            'icon': item.icon,
            'renk': item.color,
            'is_published': true,
          }),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _syncGrammarDetailToLocal(GrammarModuleDetail detail) async {
    final database = _database;
    if (database == null) return;

    // Sync the module itself first
    await _syncGrammarModulesToLocal([detail.module]);

    for (final page in detail.pages) {
      // Sync Page
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'grammar',
          entityType: 'gramer_sayfalari',
          entityId: page.id.toString(),
          payloadJson: jsonEncode({
            'id': page.id,
            'modul_id': detail.module.id,
            'sayfa_no': page.pageNumber,
            'baslik': page.title,
            'icerik_html': page.htmlContent,
            'kelime_sayisi': page.wordCount,
            'is_published': true,
          }),
          updatedAt: DateTime.now(),
        ),
      );

      // Sync Examples for this page
      for (final example in page.examples) {
        await database.upsertContentEntity(
          ContentEntityRecord(
            scope: 'grammar',
            entityType: 'gramer_ornekler',
            entityId: example.id.toString(),
            payloadJson: jsonEncode({
              'id': example.id,
              'sayfa_id': page.id,
              'sira': example.sortOrder,
              'ingilizce': example.english,
              'turkce': example.turkish,
              'aciklama': example.description,
              'is_published': true,
            }),
            updatedAt: DateTime.now(),
          ),
        );
      }

      // Sync Questions for this page
      for (final question in page.questions) {
        await database.upsertContentEntity(
          ContentEntityRecord(
            scope: 'grammar',
            entityType: 'gramer_testler',
            entityId: question.id.toString(),
            payloadJson: jsonEncode({
              'id': question.id,
              'sayfa_id': page.id,
              'sira': question.sortOrder,
              'soru': question.prompt,
              'secenekler_json': jsonEncode(question.options),
              'dogru_cevap': question.correctAnswer,
              'aciklama': question.description,
              'is_published': true,
            }),
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
  }

  Future<List<GrammarModule>> _readModulesFromLocal() async {
    final database = _database;
    if (database == null) {
      return const <GrammarModule>[];
    }

    final records = await database.listContentEntities(
      scope: 'grammar',
      entityType: 'gramer_modulleri',
    );
    return _sortModules(
      records
          .map(
            (record) => _moduleFromPayload(_decodePayload(record.payloadJson)),
          )
          .whereType<GrammarModule>()
          .toList(growable: false),
    );
  }

  Future<GrammarModuleDetail?> _readDetailFromLocal(int moduleId) async {
    final database = _database;
    if (database == null) {
      return null;
    }

    final moduleRecords = await database.listContentEntities(
      scope: 'grammar',
      entityType: 'gramer_modulleri',
    );
    final modulePayload = moduleRecords
        .map((record) => _decodePayload(record.payloadJson))
        .firstWhere(
          (payload) => _readInt(payload['id']) == moduleId,
          orElse: () => const <String, dynamic>{},
        );
    final module = _moduleFromPayload(modulePayload);
    if (module == null) {
      return null;
    }

    final pageRecords = await database.listContentEntities(
      scope: 'grammar',
      entityType: 'gramer_sayfalari',
    );
    final exampleRecords = await database.listContentEntities(
      scope: 'grammar',
      entityType: 'gramer_ornekler',
    );
    final questionRecords = await database.listContentEntities(
      scope: 'grammar',
      entityType: 'gramer_testler',
    );

    final pagePayloads = pageRecords
        .map((record) => _decodePayload(record.payloadJson))
        .where(
          (payload) =>
              _readInt(payload['modul_id']) == moduleId && _isVisible(payload),
        )
        .toList(growable: false);

    return GrammarModuleDetail(
      module: module,
      pages: _buildPages(
        pagePayloads: pagePayloads,
        examplePayloads: exampleRecords
            .map((record) => _decodePayload(record.payloadJson))
            .where(_isVisible)
            .toList(growable: false),
        questionPayloads: questionRecords
            .map((record) => _decodePayload(record.payloadJson))
            .where(_isVisible)
            .toList(growable: false),
      ),
    );
  }

  Future<List<GrammarModule>> _readModulesFromRemote() async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return const <GrammarModule>[];
    }

    await SupabaseBootstrap.initialize(config);
    final rows =
        (await Supabase.instance.client
                .from('gramer_modulleri')
                .select('id,sira,baslik,toplam_sayfa,icon,renk,is_published')
                .order('sira'))
            as List<dynamic>;

    return _sortModules(
      rows
          .whereType<Map<String, dynamic>>()
          .map(_moduleFromPayload)
          .whereType<GrammarModule>()
          .toList(growable: false),
    );
  }

  Future<GrammarModuleDetail?> _readDetailFromRemote(int moduleId) async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return null;
    }

    await SupabaseBootstrap.initialize(config);
    final client = Supabase.instance.client;
    final rawModule = await client
        .from('gramer_modulleri')
        .select('id,sira,baslik,toplam_sayfa,icon,renk,is_published')
        .eq('id', moduleId)
        .maybeSingle();
    final module = _moduleFromPayload(_asMap(rawModule));
    if (module == null) {
      return null;
    }

    final pageRows =
        (await client
                .from('gramer_sayfalari')
                .select(
                  'id,modul_id,sayfa_no,baslik,icerik_html,kelime_sayisi,is_published',
                )
                .eq('modul_id', moduleId)
                .order('sayfa_no'))
            as List<dynamic>;
    final pagePayloads = pageRows
        .whereType<Map<String, dynamic>>()
        .where(_isVisible)
        .toList(growable: false);
    final pageIds = pagePayloads
        .map((payload) => _readInt(payload['id']))
        .where((id) => id > 0)
        .toList(growable: false);

    List<Map<String, dynamic>> examplePayloads = const <Map<String, dynamic>>[];
    List<Map<String, dynamic>> questionPayloads =
        const <Map<String, dynamic>>[];
    if (pageIds.isNotEmpty) {
      final exampleRows =
          (await client
                  .from('gramer_ornekler')
                  .select(
                    'id,sayfa_id,sira,ingilizce,turkce,aciklama,is_published',
                  )
                  .inFilter('sayfa_id', pageIds)
                  .order('sira'))
              as List<dynamic>;
      final questionRows =
          (await client
                  .from('gramer_testler')
                  .select(
                    'id,sayfa_id,sira,soru,secenekler_json,dogru_cevap,aciklama,is_published',
                  )
                  .inFilter('sayfa_id', pageIds)
                  .order('sira'))
              as List<dynamic>;
      examplePayloads = exampleRows
          .whereType<Map<String, dynamic>>()
          .where(_isVisible)
          .toList(growable: false);
      questionPayloads = questionRows
          .whereType<Map<String, dynamic>>()
          .where(_isVisible)
          .toList(growable: false);
    }

    return GrammarModuleDetail(
      module: module,
      pages: _buildPages(
        pagePayloads: pagePayloads,
        examplePayloads: examplePayloads,
        questionPayloads: questionPayloads,
      ),
    );
  }

  List<GrammarPageDetail> _buildPages({
    required List<Map<String, dynamic>> pagePayloads,
    required List<Map<String, dynamic>> examplePayloads,
    required List<Map<String, dynamic>> questionPayloads,
  }) {
    final pages =
        pagePayloads
            .map((payload) {
              final pageId = _readInt(payload['id']);
              final examples =
                  examplePayloads
                      .where((item) => _readInt(item['sayfa_id']) == pageId)
                      .map(_exampleFromPayload)
                      .whereType<GrammarExample>()
                      .toList(growable: false)
                    ..sort(
                      (left, right) =>
                          left.sortOrder.compareTo(right.sortOrder),
                    );
              final questions =
                  questionPayloads
                      .where((item) => _readInt(item['sayfa_id']) == pageId)
                      .map(_questionFromPayload)
                      .whereType<GrammarQuestion>()
                      .toList(growable: false)
                    ..sort(
                      (left, right) =>
                          left.sortOrder.compareTo(right.sortOrder),
                    );
              return GrammarPageDetail(
                id: pageId,
                pageNumber: _readInt(payload['sayfa_no'], fallback: 1),
                title: _readString(payload['baslik']),
                htmlContent: _readString(payload['icerik_html']),
                wordCount: _readInt(payload['kelime_sayisi']),
                examples: examples,
                questions: questions,
              );
            })
            .where((item) => item.id > 0)
            .toList(growable: false)
          ..sort((left, right) => left.pageNumber.compareTo(right.pageNumber));
    return pages;
  }

  GrammarModule? _moduleFromPayload(Map<String, dynamic> payload) {
    final id = _readInt(payload['id']);
    if (id <= 0 || !_isVisible(payload)) {
      return null;
    }

    return GrammarModule(
      id: id,
      sortOrder: _readInt(payload['sira'], fallback: id),
      title: _readString(payload['baslik']),
      pageCount: _readInt(payload['toplam_sayfa']),
      icon: _readString(payload['icon'], fallback: 'menu_book'),
      color: _readString(payload['renk'], fallback: '#4776E6'),
    );
  }

  GrammarExample? _exampleFromPayload(Map<String, dynamic> payload) {
    final id = _readInt(payload['id']);
    if (id <= 0) {
      return null;
    }

    return GrammarExample(
      id: id,
      sortOrder: _readInt(payload['sira'], fallback: 1),
      english: _readString(payload['ingilizce']),
      turkish: _readString(payload['turkce']),
      description: _readNullableString(payload['aciklama']),
    );
  }

  GrammarQuestion? _questionFromPayload(Map<String, dynamic> payload) {
    final id = _readInt(payload['id']);
    if (id <= 0) {
      return null;
    }

    return GrammarQuestion(
      id: id,
      sortOrder: _readInt(payload['sira'], fallback: 1),
      prompt: _readString(payload['soru']),
      options: _readOptions(payload['secenekler_json']),
      correctAnswer: _readNullableString(payload['dogru_cevap']),
      description: _readNullableString(payload['aciklama']),
    );
  }

  List<GrammarModule> _sortModules(List<GrammarModule> items) {
    final sorted = items.toList(growable: false)
      ..sort((left, right) {
        final orderComparison = left.sortOrder.compareTo(right.sortOrder);
        if (orderComparison != 0) {
          return orderComparison;
        }
        return left.id.compareTo(right.id);
      });
    return sorted;
  }

  bool _isVisible(Map<String, dynamic> payload) {
    final raw = payload['is_published'];
    if (raw == null) {
      return true;
    }
    if (raw is bool) {
      return raw;
    }
    return raw.toString().toLowerCase() != 'false';
  }

  List<String> _readOptions(Object? value) {
    if (value is List<dynamic>) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is Map<dynamic, dynamic>) {
      return _formatOptionEntries(value.entries);
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = _decodeDynamic(value);
      if (decoded is List<dynamic>) {
        return decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      if (decoded is Map<dynamic, dynamic>) {
        return _formatOptionEntries(decoded.entries);
      }
    }
    return const <String>[];
  }

  List<String> _formatOptionEntries(
    Iterable<MapEntry<dynamic, dynamic>> entries,
  ) {
    final formatted =
        entries
            .map(
              (entry) => MapEntry(
                entry.key.toString().trim(),
                entry.value.toString().trim(),
              ),
            )
            .where((entry) => entry.value.isNotEmpty)
            .toList(growable: false)
          ..sort((left, right) => left.key.compareTo(right.key));
    return formatted
        .map(
          (entry) =>
              entry.key.isEmpty ? entry.value : '${entry.key}) ${entry.value}',
        )
        .toList(growable: false);
  }

  Map<String, dynamic> _decodePayload(String payloadJson) {
    final decoded = _decodeDynamic(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }

    return const <String, dynamic>{};
  }

  Object? _decodeDynamic(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  int _readInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  String _readString(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return fallback;
    }
    return text;
  }

  String? _readNullableString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }
}

const List<GrammarModule> _previewModules = <GrammarModule>[
  GrammarModule(
    id: 1,
    sortOrder: 1,
    title: 'Temel Kavramlar',
    pageCount: 3,
    icon: 'menu_book',
    color: '#10B981',
  ),
  GrammarModule(
    id: 2,
    sortOrder: 2,
    title: 'Tense System',
    pageCount: 3,
    icon: 'schedule',
    color: '#2563EB',
  ),
];

const Map<int, GrammarModuleDetail>
_previewDetails = <int, GrammarModuleDetail>{
  1: GrammarModuleDetail(
    module: GrammarModule(
      id: 1,
      sortOrder: 1,
      title: 'Temel Kavramlar',
      pageCount: 2,
      icon: 'menu_book',
      color: '#10B981',
    ),
    pages: <GrammarPageDetail>[
      GrammarPageDetail(
        id: 101,
        pageNumber: 1,
        title: 'Subject + Verb + Object',
        htmlContent:
            '<p>Ingilizce temel cumle duzeni cogu zaman subject + verb + object sirasini izler.</p>',
        wordCount: 12,
        examples: <GrammarExample>[
          GrammarExample(
            id: 1001,
            sortOrder: 1,
            english: 'She reads books.',
            turkish: 'O kitap okur.',
          ),
        ],
      ),
      GrammarPageDetail(
        id: 102,
        pageNumber: 2,
        title: 'Objects and Complements',
        htmlContent:
            '<p>Bazi fiiller nesne alir, bazilari ise tamamlayici ile kullanilir.</p>',
        wordCount: 10,
        questions: <GrammarQuestion>[
          GrammarQuestion(
            id: 10001,
            sortOrder: 1,
            prompt: 'Dogru temel dizilim hangisidir?',
            options: <String>[
              'Subject + Verb + Object',
              'Object + Verb + Subject',
            ],
            correctAnswer: 'Subject + Verb + Object',
          ),
        ],
      ),
    ],
  ),
  2: GrammarModuleDetail(
    module: GrammarModule(
      id: 2,
      sortOrder: 2,
      title: 'Tense System',
      pageCount: 2,
      icon: 'schedule',
      color: '#2563EB',
    ),
    pages: <GrammarPageDetail>[
      GrammarPageDetail(
        id: 201,
        pageNumber: 1,
        title: 'Present Simple',
        htmlContent:
            '<p>Present Simple aliskanliklar ve genel gercekler icin kullanilir.</p>',
        wordCount: 11,
      ),
      GrammarPageDetail(
        id: 202,
        pageNumber: 2,
        title: 'Present Continuous',
        htmlContent:
            '<p>Present Continuous su anda devam eden eylemleri anlatir.</p>',
        wordCount: 11,
      ),
    ],
  ),
};
