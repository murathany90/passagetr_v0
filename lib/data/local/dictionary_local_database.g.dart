// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_local_database.dart';

// ignore_for_file: type=lint
class $LocalDictionaryEntriesTable extends LocalDictionaryEntries
    with TableInfo<$LocalDictionaryEntriesTable, LocalDictionaryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDictionaryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqIdMeta = const VerificationMeta('seqId');
  @override
  late final GeneratedColumn<int> seqId = GeneratedColumn<int>(
      'seq_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _entryIdMeta =
      const VerificationMeta('entryId');
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
      'entry_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _enWordMeta = const VerificationMeta('enWord');
  @override
  late final GeneratedColumn<String> enWord = GeneratedColumn<String>(
      'en_word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _enWordNormalizedMeta =
      const VerificationMeta('enWordNormalized');
  @override
  late final GeneratedColumn<String> enWordNormalized = GeneratedColumn<String>(
      'en_word_normalized', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _searchKeyMeta =
      const VerificationMeta('searchKey');
  @override
  late final GeneratedColumn<String> searchKey = GeneratedColumn<String>(
      'search_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posMeta = const VerificationMeta('pos');
  @override
  late final GeneratedColumn<String> pos = GeneratedColumn<String>(
      'pos', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _trMeaningMeta =
      const VerificationMeta('trMeaning');
  @override
  late final GeneratedColumn<String> trMeaning = GeneratedColumn<String>(
      'tr_meaning', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        seqId,
        entryId,
        enWord,
        enWordNormalized,
        searchKey,
        pos,
        trMeaning,
        source,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_dictionary_entries';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalDictionaryEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq_id')) {
      context.handle(
          _seqIdMeta, seqId.isAcceptableOrUnknown(data['seq_id']!, _seqIdMeta));
    }
    if (data.containsKey('entry_id')) {
      context.handle(_entryIdMeta,
          entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta));
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('en_word')) {
      context.handle(_enWordMeta,
          enWord.isAcceptableOrUnknown(data['en_word']!, _enWordMeta));
    } else if (isInserting) {
      context.missing(_enWordMeta);
    }
    if (data.containsKey('en_word_normalized')) {
      context.handle(
          _enWordNormalizedMeta,
          enWordNormalized.isAcceptableOrUnknown(
              data['en_word_normalized']!, _enWordNormalizedMeta));
    } else if (isInserting) {
      context.missing(_enWordNormalizedMeta);
    }
    if (data.containsKey('search_key')) {
      context.handle(_searchKeyMeta,
          searchKey.isAcceptableOrUnknown(data['search_key']!, _searchKeyMeta));
    } else if (isInserting) {
      context.missing(_searchKeyMeta);
    }
    if (data.containsKey('pos')) {
      context.handle(
          _posMeta, pos.isAcceptableOrUnknown(data['pos']!, _posMeta));
    }
    if (data.containsKey('tr_meaning')) {
      context.handle(_trMeaningMeta,
          trMeaning.isAcceptableOrUnknown(data['tr_meaning']!, _trMeaningMeta));
    } else if (isInserting) {
      context.missing(_trMeaningMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seqId};
  @override
  LocalDictionaryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDictionaryEntry(
      seqId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}seq_id'])!,
      entryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entry_id'])!,
      enWord: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}en_word'])!,
      enWordNormalized: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}en_word_normalized'])!,
      searchKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}search_key'])!,
      pos: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pos']),
      trMeaning: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tr_meaning'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $LocalDictionaryEntriesTable createAlias(String alias) {
    return $LocalDictionaryEntriesTable(attachedDatabase, alias);
  }
}

class LocalDictionaryEntry extends DataClass
    implements Insertable<LocalDictionaryEntry> {
  final int seqId;
  final String entryId;
  final String enWord;
  final String enWordNormalized;
  final String searchKey;
  final String? pos;
  final String trMeaning;
  final String source;
  final DateTime? updatedAt;
  const LocalDictionaryEntry(
      {required this.seqId,
      required this.entryId,
      required this.enWord,
      required this.enWordNormalized,
      required this.searchKey,
      this.pos,
      required this.trMeaning,
      required this.source,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq_id'] = Variable<int>(seqId);
    map['entry_id'] = Variable<String>(entryId);
    map['en_word'] = Variable<String>(enWord);
    map['en_word_normalized'] = Variable<String>(enWordNormalized);
    map['search_key'] = Variable<String>(searchKey);
    if (!nullToAbsent || pos != null) {
      map['pos'] = Variable<String>(pos);
    }
    map['tr_meaning'] = Variable<String>(trMeaning);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  LocalDictionaryEntriesCompanion toCompanion(bool nullToAbsent) {
    return LocalDictionaryEntriesCompanion(
      seqId: Value(seqId),
      entryId: Value(entryId),
      enWord: Value(enWord),
      enWordNormalized: Value(enWordNormalized),
      searchKey: Value(searchKey),
      pos: pos == null && nullToAbsent ? const Value.absent() : Value(pos),
      trMeaning: Value(trMeaning),
      source: Value(source),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory LocalDictionaryEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDictionaryEntry(
      seqId: serializer.fromJson<int>(json['seqId']),
      entryId: serializer.fromJson<String>(json['entryId']),
      enWord: serializer.fromJson<String>(json['enWord']),
      enWordNormalized: serializer.fromJson<String>(json['enWordNormalized']),
      searchKey: serializer.fromJson<String>(json['searchKey']),
      pos: serializer.fromJson<String?>(json['pos']),
      trMeaning: serializer.fromJson<String>(json['trMeaning']),
      source: serializer.fromJson<String>(json['source']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seqId': serializer.toJson<int>(seqId),
      'entryId': serializer.toJson<String>(entryId),
      'enWord': serializer.toJson<String>(enWord),
      'enWordNormalized': serializer.toJson<String>(enWordNormalized),
      'searchKey': serializer.toJson<String>(searchKey),
      'pos': serializer.toJson<String?>(pos),
      'trMeaning': serializer.toJson<String>(trMeaning),
      'source': serializer.toJson<String>(source),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  LocalDictionaryEntry copyWith(
          {int? seqId,
          String? entryId,
          String? enWord,
          String? enWordNormalized,
          String? searchKey,
          Value<String?> pos = const Value.absent(),
          String? trMeaning,
          String? source,
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      LocalDictionaryEntry(
        seqId: seqId ?? this.seqId,
        entryId: entryId ?? this.entryId,
        enWord: enWord ?? this.enWord,
        enWordNormalized: enWordNormalized ?? this.enWordNormalized,
        searchKey: searchKey ?? this.searchKey,
        pos: pos.present ? pos.value : this.pos,
        trMeaning: trMeaning ?? this.trMeaning,
        source: source ?? this.source,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  LocalDictionaryEntry copyWithCompanion(LocalDictionaryEntriesCompanion data) {
    return LocalDictionaryEntry(
      seqId: data.seqId.present ? data.seqId.value : this.seqId,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      enWord: data.enWord.present ? data.enWord.value : this.enWord,
      enWordNormalized: data.enWordNormalized.present
          ? data.enWordNormalized.value
          : this.enWordNormalized,
      searchKey: data.searchKey.present ? data.searchKey.value : this.searchKey,
      pos: data.pos.present ? data.pos.value : this.pos,
      trMeaning: data.trMeaning.present ? data.trMeaning.value : this.trMeaning,
      source: data.source.present ? data.source.value : this.source,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDictionaryEntry(')
          ..write('seqId: $seqId, ')
          ..write('entryId: $entryId, ')
          ..write('enWord: $enWord, ')
          ..write('enWordNormalized: $enWordNormalized, ')
          ..write('searchKey: $searchKey, ')
          ..write('pos: $pos, ')
          ..write('trMeaning: $trMeaning, ')
          ..write('source: $source, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seqId, entryId, enWord, enWordNormalized,
      searchKey, pos, trMeaning, source, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDictionaryEntry &&
          other.seqId == this.seqId &&
          other.entryId == this.entryId &&
          other.enWord == this.enWord &&
          other.enWordNormalized == this.enWordNormalized &&
          other.searchKey == this.searchKey &&
          other.pos == this.pos &&
          other.trMeaning == this.trMeaning &&
          other.source == this.source &&
          other.updatedAt == this.updatedAt);
}

class LocalDictionaryEntriesCompanion
    extends UpdateCompanion<LocalDictionaryEntry> {
  final Value<int> seqId;
  final Value<String> entryId;
  final Value<String> enWord;
  final Value<String> enWordNormalized;
  final Value<String> searchKey;
  final Value<String?> pos;
  final Value<String> trMeaning;
  final Value<String> source;
  final Value<DateTime?> updatedAt;
  const LocalDictionaryEntriesCompanion({
    this.seqId = const Value.absent(),
    this.entryId = const Value.absent(),
    this.enWord = const Value.absent(),
    this.enWordNormalized = const Value.absent(),
    this.searchKey = const Value.absent(),
    this.pos = const Value.absent(),
    this.trMeaning = const Value.absent(),
    this.source = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LocalDictionaryEntriesCompanion.insert({
    this.seqId = const Value.absent(),
    required String entryId,
    required String enWord,
    required String enWordNormalized,
    required String searchKey,
    this.pos = const Value.absent(),
    required String trMeaning,
    required String source,
    this.updatedAt = const Value.absent(),
  })  : entryId = Value(entryId),
        enWord = Value(enWord),
        enWordNormalized = Value(enWordNormalized),
        searchKey = Value(searchKey),
        trMeaning = Value(trMeaning),
        source = Value(source);
  static Insertable<LocalDictionaryEntry> custom({
    Expression<int>? seqId,
    Expression<String>? entryId,
    Expression<String>? enWord,
    Expression<String>? enWordNormalized,
    Expression<String>? searchKey,
    Expression<String>? pos,
    Expression<String>? trMeaning,
    Expression<String>? source,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (seqId != null) 'seq_id': seqId,
      if (entryId != null) 'entry_id': entryId,
      if (enWord != null) 'en_word': enWord,
      if (enWordNormalized != null) 'en_word_normalized': enWordNormalized,
      if (searchKey != null) 'search_key': searchKey,
      if (pos != null) 'pos': pos,
      if (trMeaning != null) 'tr_meaning': trMeaning,
      if (source != null) 'source': source,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LocalDictionaryEntriesCompanion copyWith(
      {Value<int>? seqId,
      Value<String>? entryId,
      Value<String>? enWord,
      Value<String>? enWordNormalized,
      Value<String>? searchKey,
      Value<String?>? pos,
      Value<String>? trMeaning,
      Value<String>? source,
      Value<DateTime?>? updatedAt}) {
    return LocalDictionaryEntriesCompanion(
      seqId: seqId ?? this.seqId,
      entryId: entryId ?? this.entryId,
      enWord: enWord ?? this.enWord,
      enWordNormalized: enWordNormalized ?? this.enWordNormalized,
      searchKey: searchKey ?? this.searchKey,
      pos: pos ?? this.pos,
      trMeaning: trMeaning ?? this.trMeaning,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seqId.present) {
      map['seq_id'] = Variable<int>(seqId.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (enWord.present) {
      map['en_word'] = Variable<String>(enWord.value);
    }
    if (enWordNormalized.present) {
      map['en_word_normalized'] = Variable<String>(enWordNormalized.value);
    }
    if (searchKey.present) {
      map['search_key'] = Variable<String>(searchKey.value);
    }
    if (pos.present) {
      map['pos'] = Variable<String>(pos.value);
    }
    if (trMeaning.present) {
      map['tr_meaning'] = Variable<String>(trMeaning.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDictionaryEntriesCompanion(')
          ..write('seqId: $seqId, ')
          ..write('entryId: $entryId, ')
          ..write('enWord: $enWord, ')
          ..write('enWordNormalized: $enWordNormalized, ')
          ..write('searchKey: $searchKey, ')
          ..write('pos: $pos, ')
          ..write('trMeaning: $trMeaning, ')
          ..write('source: $source, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalDictionaryFallbackCacheTable extends LocalDictionaryFallbackCache
    with
        TableInfo<$LocalDictionaryFallbackCacheTable,
            LocalDictionaryFallbackCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDictionaryFallbackCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queryNormalizedMeta =
      const VerificationMeta('queryNormalized');
  @override
  late final GeneratedColumn<String> queryNormalized = GeneratedColumn<String>(
      'query_normalized', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _queryTextMeta =
      const VerificationMeta('queryText');
  @override
  late final GeneratedColumn<String> queryText = GeneratedColumn<String>(
      'query_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceLangMeta =
      const VerificationMeta('sourceLang');
  @override
  late final GeneratedColumn<String> sourceLang = GeneratedColumn<String>(
      'source_lang', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetLangMeta =
      const VerificationMeta('targetLang');
  @override
  late final GeneratedColumn<String> targetLang = GeneratedColumn<String>(
      'target_lang', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _providerMeta =
      const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
      'provider', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _translatedTextMeta =
      const VerificationMeta('translatedText');
  @override
  late final GeneratedColumn<String> translatedText = GeneratedColumn<String>(
      'translated_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fromServerCacheMeta =
      const VerificationMeta('fromServerCache');
  @override
  late final GeneratedColumn<bool> fromServerCache = GeneratedColumn<bool>(
      'from_server_cache', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("from_server_cache" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _hitCountMeta =
      const VerificationMeta('hitCount');
  @override
  late final GeneratedColumn<int> hitCount = GeneratedColumn<int>(
      'hit_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        queryNormalized,
        queryText,
        sourceLang,
        targetLang,
        provider,
        translatedText,
        fromServerCache,
        hitCount,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_dictionary_fallback_cache';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalDictionaryFallbackCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('query_normalized')) {
      context.handle(
          _queryNormalizedMeta,
          queryNormalized.isAcceptableOrUnknown(
              data['query_normalized']!, _queryNormalizedMeta));
    } else if (isInserting) {
      context.missing(_queryNormalizedMeta);
    }
    if (data.containsKey('query_text')) {
      context.handle(_queryTextMeta,
          queryText.isAcceptableOrUnknown(data['query_text']!, _queryTextMeta));
    } else if (isInserting) {
      context.missing(_queryTextMeta);
    }
    if (data.containsKey('source_lang')) {
      context.handle(
          _sourceLangMeta,
          sourceLang.isAcceptableOrUnknown(
              data['source_lang']!, _sourceLangMeta));
    } else if (isInserting) {
      context.missing(_sourceLangMeta);
    }
    if (data.containsKey('target_lang')) {
      context.handle(
          _targetLangMeta,
          targetLang.isAcceptableOrUnknown(
              data['target_lang']!, _targetLangMeta));
    } else if (isInserting) {
      context.missing(_targetLangMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta,
          provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('translated_text')) {
      context.handle(
          _translatedTextMeta,
          translatedText.isAcceptableOrUnknown(
              data['translated_text']!, _translatedTextMeta));
    } else if (isInserting) {
      context.missing(_translatedTextMeta);
    }
    if (data.containsKey('from_server_cache')) {
      context.handle(
          _fromServerCacheMeta,
          fromServerCache.isAcceptableOrUnknown(
              data['from_server_cache']!, _fromServerCacheMeta));
    }
    if (data.containsKey('hit_count')) {
      context.handle(_hitCountMeta,
          hitCount.isAcceptableOrUnknown(data['hit_count']!, _hitCountMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey =>
      {queryNormalized, sourceLang, targetLang};
  @override
  LocalDictionaryFallbackCacheData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDictionaryFallbackCacheData(
      queryNormalized: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}query_normalized'])!,
      queryText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}query_text'])!,
      sourceLang: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_lang'])!,
      targetLang: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_lang'])!,
      provider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      translatedText: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}translated_text'])!,
      fromServerCache: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}from_server_cache'])!,
      hitCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}hit_count'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalDictionaryFallbackCacheTable createAlias(String alias) {
    return $LocalDictionaryFallbackCacheTable(attachedDatabase, alias);
  }
}

class LocalDictionaryFallbackCacheData extends DataClass
    implements Insertable<LocalDictionaryFallbackCacheData> {
  final String queryNormalized;
  final String queryText;
  final String sourceLang;
  final String targetLang;
  final String provider;
  final String translatedText;
  final bool fromServerCache;
  final int hitCount;
  final DateTime updatedAt;
  const LocalDictionaryFallbackCacheData(
      {required this.queryNormalized,
      required this.queryText,
      required this.sourceLang,
      required this.targetLang,
      required this.provider,
      required this.translatedText,
      required this.fromServerCache,
      required this.hitCount,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['query_normalized'] = Variable<String>(queryNormalized);
    map['query_text'] = Variable<String>(queryText);
    map['source_lang'] = Variable<String>(sourceLang);
    map['target_lang'] = Variable<String>(targetLang);
    map['provider'] = Variable<String>(provider);
    map['translated_text'] = Variable<String>(translatedText);
    map['from_server_cache'] = Variable<bool>(fromServerCache);
    map['hit_count'] = Variable<int>(hitCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalDictionaryFallbackCacheCompanion toCompanion(bool nullToAbsent) {
    return LocalDictionaryFallbackCacheCompanion(
      queryNormalized: Value(queryNormalized),
      queryText: Value(queryText),
      sourceLang: Value(sourceLang),
      targetLang: Value(targetLang),
      provider: Value(provider),
      translatedText: Value(translatedText),
      fromServerCache: Value(fromServerCache),
      hitCount: Value(hitCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalDictionaryFallbackCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDictionaryFallbackCacheData(
      queryNormalized: serializer.fromJson<String>(json['queryNormalized']),
      queryText: serializer.fromJson<String>(json['queryText']),
      sourceLang: serializer.fromJson<String>(json['sourceLang']),
      targetLang: serializer.fromJson<String>(json['targetLang']),
      provider: serializer.fromJson<String>(json['provider']),
      translatedText: serializer.fromJson<String>(json['translatedText']),
      fromServerCache: serializer.fromJson<bool>(json['fromServerCache']),
      hitCount: serializer.fromJson<int>(json['hitCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'queryNormalized': serializer.toJson<String>(queryNormalized),
      'queryText': serializer.toJson<String>(queryText),
      'sourceLang': serializer.toJson<String>(sourceLang),
      'targetLang': serializer.toJson<String>(targetLang),
      'provider': serializer.toJson<String>(provider),
      'translatedText': serializer.toJson<String>(translatedText),
      'fromServerCache': serializer.toJson<bool>(fromServerCache),
      'hitCount': serializer.toJson<int>(hitCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalDictionaryFallbackCacheData copyWith(
          {String? queryNormalized,
          String? queryText,
          String? sourceLang,
          String? targetLang,
          String? provider,
          String? translatedText,
          bool? fromServerCache,
          int? hitCount,
          DateTime? updatedAt}) =>
      LocalDictionaryFallbackCacheData(
        queryNormalized: queryNormalized ?? this.queryNormalized,
        queryText: queryText ?? this.queryText,
        sourceLang: sourceLang ?? this.sourceLang,
        targetLang: targetLang ?? this.targetLang,
        provider: provider ?? this.provider,
        translatedText: translatedText ?? this.translatedText,
        fromServerCache: fromServerCache ?? this.fromServerCache,
        hitCount: hitCount ?? this.hitCount,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalDictionaryFallbackCacheData copyWithCompanion(
      LocalDictionaryFallbackCacheCompanion data) {
    return LocalDictionaryFallbackCacheData(
      queryNormalized: data.queryNormalized.present
          ? data.queryNormalized.value
          : this.queryNormalized,
      queryText: data.queryText.present ? data.queryText.value : this.queryText,
      sourceLang:
          data.sourceLang.present ? data.sourceLang.value : this.sourceLang,
      targetLang:
          data.targetLang.present ? data.targetLang.value : this.targetLang,
      provider: data.provider.present ? data.provider.value : this.provider,
      translatedText: data.translatedText.present
          ? data.translatedText.value
          : this.translatedText,
      fromServerCache: data.fromServerCache.present
          ? data.fromServerCache.value
          : this.fromServerCache,
      hitCount: data.hitCount.present ? data.hitCount.value : this.hitCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDictionaryFallbackCacheData(')
          ..write('queryNormalized: $queryNormalized, ')
          ..write('queryText: $queryText, ')
          ..write('sourceLang: $sourceLang, ')
          ..write('targetLang: $targetLang, ')
          ..write('provider: $provider, ')
          ..write('translatedText: $translatedText, ')
          ..write('fromServerCache: $fromServerCache, ')
          ..write('hitCount: $hitCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      queryNormalized,
      queryText,
      sourceLang,
      targetLang,
      provider,
      translatedText,
      fromServerCache,
      hitCount,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDictionaryFallbackCacheData &&
          other.queryNormalized == this.queryNormalized &&
          other.queryText == this.queryText &&
          other.sourceLang == this.sourceLang &&
          other.targetLang == this.targetLang &&
          other.provider == this.provider &&
          other.translatedText == this.translatedText &&
          other.fromServerCache == this.fromServerCache &&
          other.hitCount == this.hitCount &&
          other.updatedAt == this.updatedAt);
}

class LocalDictionaryFallbackCacheCompanion
    extends UpdateCompanion<LocalDictionaryFallbackCacheData> {
  final Value<String> queryNormalized;
  final Value<String> queryText;
  final Value<String> sourceLang;
  final Value<String> targetLang;
  final Value<String> provider;
  final Value<String> translatedText;
  final Value<bool> fromServerCache;
  final Value<int> hitCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalDictionaryFallbackCacheCompanion({
    this.queryNormalized = const Value.absent(),
    this.queryText = const Value.absent(),
    this.sourceLang = const Value.absent(),
    this.targetLang = const Value.absent(),
    this.provider = const Value.absent(),
    this.translatedText = const Value.absent(),
    this.fromServerCache = const Value.absent(),
    this.hitCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDictionaryFallbackCacheCompanion.insert({
    required String queryNormalized,
    required String queryText,
    required String sourceLang,
    required String targetLang,
    required String provider,
    required String translatedText,
    this.fromServerCache = const Value.absent(),
    this.hitCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : queryNormalized = Value(queryNormalized),
        queryText = Value(queryText),
        sourceLang = Value(sourceLang),
        targetLang = Value(targetLang),
        provider = Value(provider),
        translatedText = Value(translatedText);
  static Insertable<LocalDictionaryFallbackCacheData> custom({
    Expression<String>? queryNormalized,
    Expression<String>? queryText,
    Expression<String>? sourceLang,
    Expression<String>? targetLang,
    Expression<String>? provider,
    Expression<String>? translatedText,
    Expression<bool>? fromServerCache,
    Expression<int>? hitCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (queryNormalized != null) 'query_normalized': queryNormalized,
      if (queryText != null) 'query_text': queryText,
      if (sourceLang != null) 'source_lang': sourceLang,
      if (targetLang != null) 'target_lang': targetLang,
      if (provider != null) 'provider': provider,
      if (translatedText != null) 'translated_text': translatedText,
      if (fromServerCache != null) 'from_server_cache': fromServerCache,
      if (hitCount != null) 'hit_count': hitCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDictionaryFallbackCacheCompanion copyWith(
      {Value<String>? queryNormalized,
      Value<String>? queryText,
      Value<String>? sourceLang,
      Value<String>? targetLang,
      Value<String>? provider,
      Value<String>? translatedText,
      Value<bool>? fromServerCache,
      Value<int>? hitCount,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LocalDictionaryFallbackCacheCompanion(
      queryNormalized: queryNormalized ?? this.queryNormalized,
      queryText: queryText ?? this.queryText,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      provider: provider ?? this.provider,
      translatedText: translatedText ?? this.translatedText,
      fromServerCache: fromServerCache ?? this.fromServerCache,
      hitCount: hitCount ?? this.hitCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (queryNormalized.present) {
      map['query_normalized'] = Variable<String>(queryNormalized.value);
    }
    if (queryText.present) {
      map['query_text'] = Variable<String>(queryText.value);
    }
    if (sourceLang.present) {
      map['source_lang'] = Variable<String>(sourceLang.value);
    }
    if (targetLang.present) {
      map['target_lang'] = Variable<String>(targetLang.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (translatedText.present) {
      map['translated_text'] = Variable<String>(translatedText.value);
    }
    if (fromServerCache.present) {
      map['from_server_cache'] = Variable<bool>(fromServerCache.value);
    }
    if (hitCount.present) {
      map['hit_count'] = Variable<int>(hitCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDictionaryFallbackCacheCompanion(')
          ..write('queryNormalized: $queryNormalized, ')
          ..write('queryText: $queryText, ')
          ..write('sourceLang: $sourceLang, ')
          ..write('targetLang: $targetLang, ')
          ..write('provider: $provider, ')
          ..write('translatedText: $translatedText, ')
          ..write('fromServerCache: $fromServerCache, ')
          ..write('hitCount: $hitCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalDictionaryBootstrapMetaTable extends LocalDictionaryBootstrapMeta
    with
        TableInfo<$LocalDictionaryBootstrapMetaTable,
            LocalDictionaryBootstrapMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDictionaryBootstrapMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _datasetVersionMeta =
      const VerificationMeta('datasetVersion');
  @override
  late final GeneratedColumn<String> datasetVersion = GeneratedColumn<String>(
      'dataset_version', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _batchIdMeta =
      const VerificationMeta('batchId');
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
      'batch_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rowCountMeta =
      const VerificationMeta('rowCount');
  @override
  late final GeneratedColumn<int> rowCount = GeneratedColumn<int>(
      'row_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _downloadedCountMeta =
      const VerificationMeta('downloadedCount');
  @override
  late final GeneratedColumn<int> downloadedCount = GeneratedColumn<int>(
      'downloaded_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastSeqIdMeta =
      const VerificationMeta('lastSeqId');
  @override
  late final GeneratedColumn<int> lastSeqId = GeneratedColumn<int>(
      'last_seq_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('idle'));
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        datasetVersion,
        batchId,
        rowCount,
        downloadedCount,
        lastSeqId,
        status,
        errorMessage,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_dictionary_bootstrap_meta';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalDictionaryBootstrapMetaData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('dataset_version')) {
      context.handle(
          _datasetVersionMeta,
          datasetVersion.isAcceptableOrUnknown(
              data['dataset_version']!, _datasetVersionMeta));
    }
    if (data.containsKey('batch_id')) {
      context.handle(_batchIdMeta,
          batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta));
    }
    if (data.containsKey('row_count')) {
      context.handle(_rowCountMeta,
          rowCount.isAcceptableOrUnknown(data['row_count']!, _rowCountMeta));
    }
    if (data.containsKey('downloaded_count')) {
      context.handle(
          _downloadedCountMeta,
          downloadedCount.isAcceptableOrUnknown(
              data['downloaded_count']!, _downloadedCountMeta));
    }
    if (data.containsKey('last_seq_id')) {
      context.handle(
          _lastSeqIdMeta,
          lastSeqId.isAcceptableOrUnknown(
              data['last_seq_id']!, _lastSeqIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalDictionaryBootstrapMetaData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDictionaryBootstrapMetaData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      datasetVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}dataset_version'])!,
      batchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}batch_id']),
      rowCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}row_count'])!,
      downloadedCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}downloaded_count'])!,
      lastSeqId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_seq_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalDictionaryBootstrapMetaTable createAlias(String alias) {
    return $LocalDictionaryBootstrapMetaTable(attachedDatabase, alias);
  }
}

class LocalDictionaryBootstrapMetaData extends DataClass
    implements Insertable<LocalDictionaryBootstrapMetaData> {
  final int id;
  final String datasetVersion;
  final String? batchId;
  final int rowCount;
  final int downloadedCount;
  final int lastSeqId;
  final String status;
  final String? errorMessage;
  final DateTime updatedAt;
  const LocalDictionaryBootstrapMetaData(
      {required this.id,
      required this.datasetVersion,
      this.batchId,
      required this.rowCount,
      required this.downloadedCount,
      required this.lastSeqId,
      required this.status,
      this.errorMessage,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['dataset_version'] = Variable<String>(datasetVersion);
    if (!nullToAbsent || batchId != null) {
      map['batch_id'] = Variable<String>(batchId);
    }
    map['row_count'] = Variable<int>(rowCount);
    map['downloaded_count'] = Variable<int>(downloadedCount);
    map['last_seq_id'] = Variable<int>(lastSeqId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalDictionaryBootstrapMetaCompanion toCompanion(bool nullToAbsent) {
    return LocalDictionaryBootstrapMetaCompanion(
      id: Value(id),
      datasetVersion: Value(datasetVersion),
      batchId: batchId == null && nullToAbsent
          ? const Value.absent()
          : Value(batchId),
      rowCount: Value(rowCount),
      downloadedCount: Value(downloadedCount),
      lastSeqId: Value(lastSeqId),
      status: Value(status),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalDictionaryBootstrapMetaData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDictionaryBootstrapMetaData(
      id: serializer.fromJson<int>(json['id']),
      datasetVersion: serializer.fromJson<String>(json['datasetVersion']),
      batchId: serializer.fromJson<String?>(json['batchId']),
      rowCount: serializer.fromJson<int>(json['rowCount']),
      downloadedCount: serializer.fromJson<int>(json['downloadedCount']),
      lastSeqId: serializer.fromJson<int>(json['lastSeqId']),
      status: serializer.fromJson<String>(json['status']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'datasetVersion': serializer.toJson<String>(datasetVersion),
      'batchId': serializer.toJson<String?>(batchId),
      'rowCount': serializer.toJson<int>(rowCount),
      'downloadedCount': serializer.toJson<int>(downloadedCount),
      'lastSeqId': serializer.toJson<int>(lastSeqId),
      'status': serializer.toJson<String>(status),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalDictionaryBootstrapMetaData copyWith(
          {int? id,
          String? datasetVersion,
          Value<String?> batchId = const Value.absent(),
          int? rowCount,
          int? downloadedCount,
          int? lastSeqId,
          String? status,
          Value<String?> errorMessage = const Value.absent(),
          DateTime? updatedAt}) =>
      LocalDictionaryBootstrapMetaData(
        id: id ?? this.id,
        datasetVersion: datasetVersion ?? this.datasetVersion,
        batchId: batchId.present ? batchId.value : this.batchId,
        rowCount: rowCount ?? this.rowCount,
        downloadedCount: downloadedCount ?? this.downloadedCount,
        lastSeqId: lastSeqId ?? this.lastSeqId,
        status: status ?? this.status,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalDictionaryBootstrapMetaData copyWithCompanion(
      LocalDictionaryBootstrapMetaCompanion data) {
    return LocalDictionaryBootstrapMetaData(
      id: data.id.present ? data.id.value : this.id,
      datasetVersion: data.datasetVersion.present
          ? data.datasetVersion.value
          : this.datasetVersion,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      rowCount: data.rowCount.present ? data.rowCount.value : this.rowCount,
      downloadedCount: data.downloadedCount.present
          ? data.downloadedCount.value
          : this.downloadedCount,
      lastSeqId: data.lastSeqId.present ? data.lastSeqId.value : this.lastSeqId,
      status: data.status.present ? data.status.value : this.status,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDictionaryBootstrapMetaData(')
          ..write('id: $id, ')
          ..write('datasetVersion: $datasetVersion, ')
          ..write('batchId: $batchId, ')
          ..write('rowCount: $rowCount, ')
          ..write('downloadedCount: $downloadedCount, ')
          ..write('lastSeqId: $lastSeqId, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, datasetVersion, batchId, rowCount,
      downloadedCount, lastSeqId, status, errorMessage, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDictionaryBootstrapMetaData &&
          other.id == this.id &&
          other.datasetVersion == this.datasetVersion &&
          other.batchId == this.batchId &&
          other.rowCount == this.rowCount &&
          other.downloadedCount == this.downloadedCount &&
          other.lastSeqId == this.lastSeqId &&
          other.status == this.status &&
          other.errorMessage == this.errorMessage &&
          other.updatedAt == this.updatedAt);
}

class LocalDictionaryBootstrapMetaCompanion
    extends UpdateCompanion<LocalDictionaryBootstrapMetaData> {
  final Value<int> id;
  final Value<String> datasetVersion;
  final Value<String?> batchId;
  final Value<int> rowCount;
  final Value<int> downloadedCount;
  final Value<int> lastSeqId;
  final Value<String> status;
  final Value<String?> errorMessage;
  final Value<DateTime> updatedAt;
  const LocalDictionaryBootstrapMetaCompanion({
    this.id = const Value.absent(),
    this.datasetVersion = const Value.absent(),
    this.batchId = const Value.absent(),
    this.rowCount = const Value.absent(),
    this.downloadedCount = const Value.absent(),
    this.lastSeqId = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LocalDictionaryBootstrapMetaCompanion.insert({
    this.id = const Value.absent(),
    this.datasetVersion = const Value.absent(),
    this.batchId = const Value.absent(),
    this.rowCount = const Value.absent(),
    this.downloadedCount = const Value.absent(),
    this.lastSeqId = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<LocalDictionaryBootstrapMetaData> custom({
    Expression<int>? id,
    Expression<String>? datasetVersion,
    Expression<String>? batchId,
    Expression<int>? rowCount,
    Expression<int>? downloadedCount,
    Expression<int>? lastSeqId,
    Expression<String>? status,
    Expression<String>? errorMessage,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (datasetVersion != null) 'dataset_version': datasetVersion,
      if (batchId != null) 'batch_id': batchId,
      if (rowCount != null) 'row_count': rowCount,
      if (downloadedCount != null) 'downloaded_count': downloadedCount,
      if (lastSeqId != null) 'last_seq_id': lastSeqId,
      if (status != null) 'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LocalDictionaryBootstrapMetaCompanion copyWith(
      {Value<int>? id,
      Value<String>? datasetVersion,
      Value<String?>? batchId,
      Value<int>? rowCount,
      Value<int>? downloadedCount,
      Value<int>? lastSeqId,
      Value<String>? status,
      Value<String?>? errorMessage,
      Value<DateTime>? updatedAt}) {
    return LocalDictionaryBootstrapMetaCompanion(
      id: id ?? this.id,
      datasetVersion: datasetVersion ?? this.datasetVersion,
      batchId: batchId ?? this.batchId,
      rowCount: rowCount ?? this.rowCount,
      downloadedCount: downloadedCount ?? this.downloadedCount,
      lastSeqId: lastSeqId ?? this.lastSeqId,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (datasetVersion.present) {
      map['dataset_version'] = Variable<String>(datasetVersion.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
    }
    if (rowCount.present) {
      map['row_count'] = Variable<int>(rowCount.value);
    }
    if (downloadedCount.present) {
      map['downloaded_count'] = Variable<int>(downloadedCount.value);
    }
    if (lastSeqId.present) {
      map['last_seq_id'] = Variable<int>(lastSeqId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDictionaryBootstrapMetaCompanion(')
          ..write('id: $id, ')
          ..write('datasetVersion: $datasetVersion, ')
          ..write('batchId: $batchId, ')
          ..write('rowCount: $rowCount, ')
          ..write('downloadedCount: $downloadedCount, ')
          ..write('lastSeqId: $lastSeqId, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$DictionaryLocalDatabase extends GeneratedDatabase {
  _$DictionaryLocalDatabase(QueryExecutor e) : super(e);
  $DictionaryLocalDatabaseManager get managers =>
      $DictionaryLocalDatabaseManager(this);
  late final $LocalDictionaryEntriesTable localDictionaryEntries =
      $LocalDictionaryEntriesTable(this);
  late final $LocalDictionaryFallbackCacheTable localDictionaryFallbackCache =
      $LocalDictionaryFallbackCacheTable(this);
  late final $LocalDictionaryBootstrapMetaTable localDictionaryBootstrapMeta =
      $LocalDictionaryBootstrapMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        localDictionaryEntries,
        localDictionaryFallbackCache,
        localDictionaryBootstrapMeta
      ];
}

typedef $$LocalDictionaryEntriesTableCreateCompanionBuilder
    = LocalDictionaryEntriesCompanion Function({
  Value<int> seqId,
  required String entryId,
  required String enWord,
  required String enWordNormalized,
  required String searchKey,
  Value<String?> pos,
  required String trMeaning,
  required String source,
  Value<DateTime?> updatedAt,
});
typedef $$LocalDictionaryEntriesTableUpdateCompanionBuilder
    = LocalDictionaryEntriesCompanion Function({
  Value<int> seqId,
  Value<String> entryId,
  Value<String> enWord,
  Value<String> enWordNormalized,
  Value<String> searchKey,
  Value<String?> pos,
  Value<String> trMeaning,
  Value<String> source,
  Value<DateTime?> updatedAt,
});

class $$LocalDictionaryEntriesTableFilterComposer
    extends Composer<_$DictionaryLocalDatabase, $LocalDictionaryEntriesTable> {
  $$LocalDictionaryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seqId => $composableBuilder(
      column: $table.seqId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entryId => $composableBuilder(
      column: $table.entryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get enWord => $composableBuilder(
      column: $table.enWord, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get enWordNormalized => $composableBuilder(
      column: $table.enWordNormalized,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get searchKey => $composableBuilder(
      column: $table.searchKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pos => $composableBuilder(
      column: $table.pos, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trMeaning => $composableBuilder(
      column: $table.trMeaning, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalDictionaryEntriesTableOrderingComposer
    extends Composer<_$DictionaryLocalDatabase, $LocalDictionaryEntriesTable> {
  $$LocalDictionaryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seqId => $composableBuilder(
      column: $table.seqId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entryId => $composableBuilder(
      column: $table.entryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get enWord => $composableBuilder(
      column: $table.enWord, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get enWordNormalized => $composableBuilder(
      column: $table.enWordNormalized,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get searchKey => $composableBuilder(
      column: $table.searchKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pos => $composableBuilder(
      column: $table.pos, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trMeaning => $composableBuilder(
      column: $table.trMeaning, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalDictionaryEntriesTableAnnotationComposer
    extends Composer<_$DictionaryLocalDatabase, $LocalDictionaryEntriesTable> {
  $$LocalDictionaryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seqId =>
      $composableBuilder(column: $table.seqId, builder: (column) => column);

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get enWord =>
      $composableBuilder(column: $table.enWord, builder: (column) => column);

  GeneratedColumn<String> get enWordNormalized => $composableBuilder(
      column: $table.enWordNormalized, builder: (column) => column);

  GeneratedColumn<String> get searchKey =>
      $composableBuilder(column: $table.searchKey, builder: (column) => column);

  GeneratedColumn<String> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<String> get trMeaning =>
      $composableBuilder(column: $table.trMeaning, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalDictionaryEntriesTableTableManager extends RootTableManager<
    _$DictionaryLocalDatabase,
    $LocalDictionaryEntriesTable,
    LocalDictionaryEntry,
    $$LocalDictionaryEntriesTableFilterComposer,
    $$LocalDictionaryEntriesTableOrderingComposer,
    $$LocalDictionaryEntriesTableAnnotationComposer,
    $$LocalDictionaryEntriesTableCreateCompanionBuilder,
    $$LocalDictionaryEntriesTableUpdateCompanionBuilder,
    (
      LocalDictionaryEntry,
      BaseReferences<_$DictionaryLocalDatabase, $LocalDictionaryEntriesTable,
          LocalDictionaryEntry>
    ),
    LocalDictionaryEntry,
    PrefetchHooks Function()> {
  $$LocalDictionaryEntriesTableTableManager(
      _$DictionaryLocalDatabase db, $LocalDictionaryEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDictionaryEntriesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDictionaryEntriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDictionaryEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> seqId = const Value.absent(),
            Value<String> entryId = const Value.absent(),
            Value<String> enWord = const Value.absent(),
            Value<String> enWordNormalized = const Value.absent(),
            Value<String> searchKey = const Value.absent(),
            Value<String?> pos = const Value.absent(),
            Value<String> trMeaning = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              LocalDictionaryEntriesCompanion(
            seqId: seqId,
            entryId: entryId,
            enWord: enWord,
            enWordNormalized: enWordNormalized,
            searchKey: searchKey,
            pos: pos,
            trMeaning: trMeaning,
            source: source,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> seqId = const Value.absent(),
            required String entryId,
            required String enWord,
            required String enWordNormalized,
            required String searchKey,
            Value<String?> pos = const Value.absent(),
            required String trMeaning,
            required String source,
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              LocalDictionaryEntriesCompanion.insert(
            seqId: seqId,
            entryId: entryId,
            enWord: enWord,
            enWordNormalized: enWordNormalized,
            searchKey: searchKey,
            pos: pos,
            trMeaning: trMeaning,
            source: source,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalDictionaryEntriesTableProcessedTableManager
    = ProcessedTableManager<
        _$DictionaryLocalDatabase,
        $LocalDictionaryEntriesTable,
        LocalDictionaryEntry,
        $$LocalDictionaryEntriesTableFilterComposer,
        $$LocalDictionaryEntriesTableOrderingComposer,
        $$LocalDictionaryEntriesTableAnnotationComposer,
        $$LocalDictionaryEntriesTableCreateCompanionBuilder,
        $$LocalDictionaryEntriesTableUpdateCompanionBuilder,
        (
          LocalDictionaryEntry,
          BaseReferences<_$DictionaryLocalDatabase,
              $LocalDictionaryEntriesTable, LocalDictionaryEntry>
        ),
        LocalDictionaryEntry,
        PrefetchHooks Function()>;
typedef $$LocalDictionaryFallbackCacheTableCreateCompanionBuilder
    = LocalDictionaryFallbackCacheCompanion Function({
  required String queryNormalized,
  required String queryText,
  required String sourceLang,
  required String targetLang,
  required String provider,
  required String translatedText,
  Value<bool> fromServerCache,
  Value<int> hitCount,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$LocalDictionaryFallbackCacheTableUpdateCompanionBuilder
    = LocalDictionaryFallbackCacheCompanion Function({
  Value<String> queryNormalized,
  Value<String> queryText,
  Value<String> sourceLang,
  Value<String> targetLang,
  Value<String> provider,
  Value<String> translatedText,
  Value<bool> fromServerCache,
  Value<int> hitCount,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalDictionaryFallbackCacheTableFilterComposer extends Composer<
    _$DictionaryLocalDatabase, $LocalDictionaryFallbackCacheTable> {
  $$LocalDictionaryFallbackCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get queryNormalized => $composableBuilder(
      column: $table.queryNormalized,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get queryText => $composableBuilder(
      column: $table.queryText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceLang => $composableBuilder(
      column: $table.sourceLang, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetLang => $composableBuilder(
      column: $table.targetLang, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get translatedText => $composableBuilder(
      column: $table.translatedText,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get fromServerCache => $composableBuilder(
      column: $table.fromServerCache,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hitCount => $composableBuilder(
      column: $table.hitCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalDictionaryFallbackCacheTableOrderingComposer extends Composer<
    _$DictionaryLocalDatabase, $LocalDictionaryFallbackCacheTable> {
  $$LocalDictionaryFallbackCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get queryNormalized => $composableBuilder(
      column: $table.queryNormalized,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get queryText => $composableBuilder(
      column: $table.queryText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceLang => $composableBuilder(
      column: $table.sourceLang, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetLang => $composableBuilder(
      column: $table.targetLang, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get translatedText => $composableBuilder(
      column: $table.translatedText,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get fromServerCache => $composableBuilder(
      column: $table.fromServerCache,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hitCount => $composableBuilder(
      column: $table.hitCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalDictionaryFallbackCacheTableAnnotationComposer extends Composer<
    _$DictionaryLocalDatabase, $LocalDictionaryFallbackCacheTable> {
  $$LocalDictionaryFallbackCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get queryNormalized => $composableBuilder(
      column: $table.queryNormalized, builder: (column) => column);

  GeneratedColumn<String> get queryText =>
      $composableBuilder(column: $table.queryText, builder: (column) => column);

  GeneratedColumn<String> get sourceLang => $composableBuilder(
      column: $table.sourceLang, builder: (column) => column);

  GeneratedColumn<String> get targetLang => $composableBuilder(
      column: $table.targetLang, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get translatedText => $composableBuilder(
      column: $table.translatedText, builder: (column) => column);

  GeneratedColumn<bool> get fromServerCache => $composableBuilder(
      column: $table.fromServerCache, builder: (column) => column);

  GeneratedColumn<int> get hitCount =>
      $composableBuilder(column: $table.hitCount, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalDictionaryFallbackCacheTableTableManager extends RootTableManager<
    _$DictionaryLocalDatabase,
    $LocalDictionaryFallbackCacheTable,
    LocalDictionaryFallbackCacheData,
    $$LocalDictionaryFallbackCacheTableFilterComposer,
    $$LocalDictionaryFallbackCacheTableOrderingComposer,
    $$LocalDictionaryFallbackCacheTableAnnotationComposer,
    $$LocalDictionaryFallbackCacheTableCreateCompanionBuilder,
    $$LocalDictionaryFallbackCacheTableUpdateCompanionBuilder,
    (
      LocalDictionaryFallbackCacheData,
      BaseReferences<_$DictionaryLocalDatabase,
          $LocalDictionaryFallbackCacheTable, LocalDictionaryFallbackCacheData>
    ),
    LocalDictionaryFallbackCacheData,
    PrefetchHooks Function()> {
  $$LocalDictionaryFallbackCacheTableTableManager(
      _$DictionaryLocalDatabase db, $LocalDictionaryFallbackCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDictionaryFallbackCacheTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDictionaryFallbackCacheTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDictionaryFallbackCacheTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> queryNormalized = const Value.absent(),
            Value<String> queryText = const Value.absent(),
            Value<String> sourceLang = const Value.absent(),
            Value<String> targetLang = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<String> translatedText = const Value.absent(),
            Value<bool> fromServerCache = const Value.absent(),
            Value<int> hitCount = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalDictionaryFallbackCacheCompanion(
            queryNormalized: queryNormalized,
            queryText: queryText,
            sourceLang: sourceLang,
            targetLang: targetLang,
            provider: provider,
            translatedText: translatedText,
            fromServerCache: fromServerCache,
            hitCount: hitCount,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String queryNormalized,
            required String queryText,
            required String sourceLang,
            required String targetLang,
            required String provider,
            required String translatedText,
            Value<bool> fromServerCache = const Value.absent(),
            Value<int> hitCount = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalDictionaryFallbackCacheCompanion.insert(
            queryNormalized: queryNormalized,
            queryText: queryText,
            sourceLang: sourceLang,
            targetLang: targetLang,
            provider: provider,
            translatedText: translatedText,
            fromServerCache: fromServerCache,
            hitCount: hitCount,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalDictionaryFallbackCacheTableProcessedTableManager
    = ProcessedTableManager<
        _$DictionaryLocalDatabase,
        $LocalDictionaryFallbackCacheTable,
        LocalDictionaryFallbackCacheData,
        $$LocalDictionaryFallbackCacheTableFilterComposer,
        $$LocalDictionaryFallbackCacheTableOrderingComposer,
        $$LocalDictionaryFallbackCacheTableAnnotationComposer,
        $$LocalDictionaryFallbackCacheTableCreateCompanionBuilder,
        $$LocalDictionaryFallbackCacheTableUpdateCompanionBuilder,
        (
          LocalDictionaryFallbackCacheData,
          BaseReferences<
              _$DictionaryLocalDatabase,
              $LocalDictionaryFallbackCacheTable,
              LocalDictionaryFallbackCacheData>
        ),
        LocalDictionaryFallbackCacheData,
        PrefetchHooks Function()>;
typedef $$LocalDictionaryBootstrapMetaTableCreateCompanionBuilder
    = LocalDictionaryBootstrapMetaCompanion Function({
  Value<int> id,
  Value<String> datasetVersion,
  Value<String?> batchId,
  Value<int> rowCount,
  Value<int> downloadedCount,
  Value<int> lastSeqId,
  Value<String> status,
  Value<String?> errorMessage,
  Value<DateTime> updatedAt,
});
typedef $$LocalDictionaryBootstrapMetaTableUpdateCompanionBuilder
    = LocalDictionaryBootstrapMetaCompanion Function({
  Value<int> id,
  Value<String> datasetVersion,
  Value<String?> batchId,
  Value<int> rowCount,
  Value<int> downloadedCount,
  Value<int> lastSeqId,
  Value<String> status,
  Value<String?> errorMessage,
  Value<DateTime> updatedAt,
});

class $$LocalDictionaryBootstrapMetaTableFilterComposer extends Composer<
    _$DictionaryLocalDatabase, $LocalDictionaryBootstrapMetaTable> {
  $$LocalDictionaryBootstrapMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get datasetVersion => $composableBuilder(
      column: $table.datasetVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get batchId => $composableBuilder(
      column: $table.batchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rowCount => $composableBuilder(
      column: $table.rowCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get downloadedCount => $composableBuilder(
      column: $table.downloadedCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastSeqId => $composableBuilder(
      column: $table.lastSeqId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalDictionaryBootstrapMetaTableOrderingComposer extends Composer<
    _$DictionaryLocalDatabase, $LocalDictionaryBootstrapMetaTable> {
  $$LocalDictionaryBootstrapMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get datasetVersion => $composableBuilder(
      column: $table.datasetVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get batchId => $composableBuilder(
      column: $table.batchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rowCount => $composableBuilder(
      column: $table.rowCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get downloadedCount => $composableBuilder(
      column: $table.downloadedCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastSeqId => $composableBuilder(
      column: $table.lastSeqId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalDictionaryBootstrapMetaTableAnnotationComposer extends Composer<
    _$DictionaryLocalDatabase, $LocalDictionaryBootstrapMetaTable> {
  $$LocalDictionaryBootstrapMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get datasetVersion => $composableBuilder(
      column: $table.datasetVersion, builder: (column) => column);

  GeneratedColumn<String> get batchId =>
      $composableBuilder(column: $table.batchId, builder: (column) => column);

  GeneratedColumn<int> get rowCount =>
      $composableBuilder(column: $table.rowCount, builder: (column) => column);

  GeneratedColumn<int> get downloadedCount => $composableBuilder(
      column: $table.downloadedCount, builder: (column) => column);

  GeneratedColumn<int> get lastSeqId =>
      $composableBuilder(column: $table.lastSeqId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalDictionaryBootstrapMetaTableTableManager extends RootTableManager<
    _$DictionaryLocalDatabase,
    $LocalDictionaryBootstrapMetaTable,
    LocalDictionaryBootstrapMetaData,
    $$LocalDictionaryBootstrapMetaTableFilterComposer,
    $$LocalDictionaryBootstrapMetaTableOrderingComposer,
    $$LocalDictionaryBootstrapMetaTableAnnotationComposer,
    $$LocalDictionaryBootstrapMetaTableCreateCompanionBuilder,
    $$LocalDictionaryBootstrapMetaTableUpdateCompanionBuilder,
    (
      LocalDictionaryBootstrapMetaData,
      BaseReferences<_$DictionaryLocalDatabase,
          $LocalDictionaryBootstrapMetaTable, LocalDictionaryBootstrapMetaData>
    ),
    LocalDictionaryBootstrapMetaData,
    PrefetchHooks Function()> {
  $$LocalDictionaryBootstrapMetaTableTableManager(
      _$DictionaryLocalDatabase db, $LocalDictionaryBootstrapMetaTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDictionaryBootstrapMetaTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDictionaryBootstrapMetaTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDictionaryBootstrapMetaTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> datasetVersion = const Value.absent(),
            Value<String?> batchId = const Value.absent(),
            Value<int> rowCount = const Value.absent(),
            Value<int> downloadedCount = const Value.absent(),
            Value<int> lastSeqId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              LocalDictionaryBootstrapMetaCompanion(
            id: id,
            datasetVersion: datasetVersion,
            batchId: batchId,
            rowCount: rowCount,
            downloadedCount: downloadedCount,
            lastSeqId: lastSeqId,
            status: status,
            errorMessage: errorMessage,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> datasetVersion = const Value.absent(),
            Value<String?> batchId = const Value.absent(),
            Value<int> rowCount = const Value.absent(),
            Value<int> downloadedCount = const Value.absent(),
            Value<int> lastSeqId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              LocalDictionaryBootstrapMetaCompanion.insert(
            id: id,
            datasetVersion: datasetVersion,
            batchId: batchId,
            rowCount: rowCount,
            downloadedCount: downloadedCount,
            lastSeqId: lastSeqId,
            status: status,
            errorMessage: errorMessage,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalDictionaryBootstrapMetaTableProcessedTableManager
    = ProcessedTableManager<
        _$DictionaryLocalDatabase,
        $LocalDictionaryBootstrapMetaTable,
        LocalDictionaryBootstrapMetaData,
        $$LocalDictionaryBootstrapMetaTableFilterComposer,
        $$LocalDictionaryBootstrapMetaTableOrderingComposer,
        $$LocalDictionaryBootstrapMetaTableAnnotationComposer,
        $$LocalDictionaryBootstrapMetaTableCreateCompanionBuilder,
        $$LocalDictionaryBootstrapMetaTableUpdateCompanionBuilder,
        (
          LocalDictionaryBootstrapMetaData,
          BaseReferences<
              _$DictionaryLocalDatabase,
              $LocalDictionaryBootstrapMetaTable,
              LocalDictionaryBootstrapMetaData>
        ),
        LocalDictionaryBootstrapMetaData,
        PrefetchHooks Function()>;

class $DictionaryLocalDatabaseManager {
  final _$DictionaryLocalDatabase _db;
  $DictionaryLocalDatabaseManager(this._db);
  $$LocalDictionaryEntriesTableTableManager get localDictionaryEntries =>
      $$LocalDictionaryEntriesTableTableManager(
          _db, _db.localDictionaryEntries);
  $$LocalDictionaryFallbackCacheTableTableManager
      get localDictionaryFallbackCache =>
          $$LocalDictionaryFallbackCacheTableTableManager(
              _db, _db.localDictionaryFallbackCache);
  $$LocalDictionaryBootstrapMetaTableTableManager
      get localDictionaryBootstrapMeta =>
          $$LocalDictionaryBootstrapMetaTableTableManager(
              _db, _db.localDictionaryBootstrapMeta);
}
