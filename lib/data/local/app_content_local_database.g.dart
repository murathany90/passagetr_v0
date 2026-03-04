// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_content_local_database.dart';

// ignore_for_file: type=lint
class $AppContentMetaTable extends AppContentMeta
    with TableInfo<$AppContentMetaTable, AppContentMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppContentMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(Insertable<AppContentMetaData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppContentMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppContentMetaData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppContentMetaTable createAlias(String alias) {
    return $AppContentMetaTable(attachedDatabase, alias);
  }
}

class AppContentMetaData extends DataClass
    implements Insertable<AppContentMetaData> {
  final String key;
  final String value;
  const AppContentMetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppContentMetaCompanion toCompanion(bool nullToAbsent) {
    return AppContentMetaCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppContentMetaData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppContentMetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppContentMetaData copyWith({String? key, String? value}) =>
      AppContentMetaData(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppContentMetaData copyWithCompanion(AppContentMetaCompanion data) {
    return AppContentMetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppContentMetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppContentMetaData &&
          other.key == this.key &&
          other.value == this.value);
}

class AppContentMetaCompanion extends UpdateCompanion<AppContentMetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppContentMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppContentMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppContentMetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppContentMetaCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppContentMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppContentMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppContentPacksTable extends AppContentPacks
    with TableInfo<$AppContentPacksTable, AppContentPack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppContentPacksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fromLangMeta =
      const VerificationMeta('fromLang');
  @override
  late final GeneratedColumn<String> fromLang = GeneratedColumn<String>(
      'from_lang', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _toLangMeta = const VerificationMeta('toLang');
  @override
  late final GeneratedColumn<String> toLang = GeneratedColumn<String>(
      'to_lang', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, fromLang, toLang];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'packs';
  @override
  VerificationContext validateIntegrity(Insertable<AppContentPack> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('from_lang')) {
      context.handle(_fromLangMeta,
          fromLang.isAcceptableOrUnknown(data['from_lang']!, _fromLangMeta));
    } else if (isInserting) {
      context.missing(_fromLangMeta);
    }
    if (data.containsKey('to_lang')) {
      context.handle(_toLangMeta,
          toLang.isAcceptableOrUnknown(data['to_lang']!, _toLangMeta));
    } else if (isInserting) {
      context.missing(_toLangMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppContentPack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppContentPack(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      fromLang: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}from_lang'])!,
      toLang: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_lang'])!,
    );
  }

  @override
  $AppContentPacksTable createAlias(String alias) {
    return $AppContentPacksTable(attachedDatabase, alias);
  }
}

class AppContentPack extends DataClass implements Insertable<AppContentPack> {
  final String id;
  final String name;
  final String fromLang;
  final String toLang;
  const AppContentPack(
      {required this.id,
      required this.name,
      required this.fromLang,
      required this.toLang});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['from_lang'] = Variable<String>(fromLang);
    map['to_lang'] = Variable<String>(toLang);
    return map;
  }

  AppContentPacksCompanion toCompanion(bool nullToAbsent) {
    return AppContentPacksCompanion(
      id: Value(id),
      name: Value(name),
      fromLang: Value(fromLang),
      toLang: Value(toLang),
    );
  }

  factory AppContentPack.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppContentPack(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      fromLang: serializer.fromJson<String>(json['fromLang']),
      toLang: serializer.fromJson<String>(json['toLang']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'fromLang': serializer.toJson<String>(fromLang),
      'toLang': serializer.toJson<String>(toLang),
    };
  }

  AppContentPack copyWith(
          {String? id, String? name, String? fromLang, String? toLang}) =>
      AppContentPack(
        id: id ?? this.id,
        name: name ?? this.name,
        fromLang: fromLang ?? this.fromLang,
        toLang: toLang ?? this.toLang,
      );
  AppContentPack copyWithCompanion(AppContentPacksCompanion data) {
    return AppContentPack(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      fromLang: data.fromLang.present ? data.fromLang.value : this.fromLang,
      toLang: data.toLang.present ? data.toLang.value : this.toLang,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppContentPack(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('fromLang: $fromLang, ')
          ..write('toLang: $toLang')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, fromLang, toLang);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppContentPack &&
          other.id == this.id &&
          other.name == this.name &&
          other.fromLang == this.fromLang &&
          other.toLang == this.toLang);
}

class AppContentPacksCompanion extends UpdateCompanion<AppContentPack> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> fromLang;
  final Value<String> toLang;
  final Value<int> rowid;
  const AppContentPacksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.fromLang = const Value.absent(),
    this.toLang = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppContentPacksCompanion.insert({
    required String id,
    required String name,
    required String fromLang,
    required String toLang,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        fromLang = Value(fromLang),
        toLang = Value(toLang);
  static Insertable<AppContentPack> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? fromLang,
    Expression<String>? toLang,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (fromLang != null) 'from_lang': fromLang,
      if (toLang != null) 'to_lang': toLang,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppContentPacksCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? fromLang,
      Value<String>? toLang,
      Value<int>? rowid}) {
    return AppContentPacksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      fromLang: fromLang ?? this.fromLang,
      toLang: toLang ?? this.toLang,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (fromLang.present) {
      map['from_lang'] = Variable<String>(fromLang.value);
    }
    if (toLang.present) {
      map['to_lang'] = Variable<String>(toLang.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppContentPacksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('fromLang: $fromLang, ')
          ..write('toLang: $toLang, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppContentWordsTable extends AppContentWords
    with TableInfo<$AppContentWordsTable, AppContentWord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppContentWordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _packIdMeta = const VerificationMeta('packId');
  @override
  late final GeneratedColumn<String> packId = GeneratedColumn<String>(
      'pack_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _enWordMeta = const VerificationMeta('enWord');
  @override
  late final GeneratedColumn<String> enWord = GeneratedColumn<String>(
      'en_word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _trMeaningMeta =
      const VerificationMeta('trMeaning');
  @override
  late final GeneratedColumn<String> trMeaning = GeneratedColumn<String>(
      'tr_meaning', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posMeta = const VerificationMeta('pos');
  @override
  late final GeneratedColumn<String> pos = GeneratedColumn<String>(
      'pos', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posRawMeta = const VerificationMeta('posRaw');
  @override
  late final GeneratedColumn<String> posRaw = GeneratedColumn<String>(
      'pos_raw', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _exampleEnMeta =
      const VerificationMeta('exampleEn');
  @override
  late final GeneratedColumn<String> exampleEn = GeneratedColumn<String>(
      'example_en', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _exampleTrMeta =
      const VerificationMeta('exampleTr');
  @override
  late final GeneratedColumn<String> exampleTr = GeneratedColumn<String>(
      'example_tr', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _synonymsRawMeta =
      const VerificationMeta('synonymsRaw');
  @override
  late final GeneratedColumn<String> synonymsRaw = GeneratedColumn<String>(
      'synonyms_raw', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _antonymsRawMeta =
      const VerificationMeta('antonymsRaw');
  @override
  late final GeneratedColumn<String> antonymsRaw = GeneratedColumn<String>(
      'antonyms_raw', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
      'level', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagsRawMeta =
      const VerificationMeta('tagsRaw');
  @override
  late final GeneratedColumn<String> tagsRaw = GeneratedColumn<String>(
      'tags_raw', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        packId,
        enWord,
        trMeaning,
        pos,
        posRaw,
        exampleEn,
        exampleTr,
        synonymsRaw,
        antonymsRaw,
        level,
        tagsRaw,
        notes,
        enWordNormalized,
        searchKey,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'words';
  @override
  VerificationContext validateIntegrity(Insertable<AppContentWord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pack_id')) {
      context.handle(_packIdMeta,
          packId.isAcceptableOrUnknown(data['pack_id']!, _packIdMeta));
    } else if (isInserting) {
      context.missing(_packIdMeta);
    }
    if (data.containsKey('en_word')) {
      context.handle(_enWordMeta,
          enWord.isAcceptableOrUnknown(data['en_word']!, _enWordMeta));
    } else if (isInserting) {
      context.missing(_enWordMeta);
    }
    if (data.containsKey('tr_meaning')) {
      context.handle(_trMeaningMeta,
          trMeaning.isAcceptableOrUnknown(data['tr_meaning']!, _trMeaningMeta));
    } else if (isInserting) {
      context.missing(_trMeaningMeta);
    }
    if (data.containsKey('pos')) {
      context.handle(
          _posMeta, pos.isAcceptableOrUnknown(data['pos']!, _posMeta));
    } else if (isInserting) {
      context.missing(_posMeta);
    }
    if (data.containsKey('pos_raw')) {
      context.handle(_posRawMeta,
          posRaw.isAcceptableOrUnknown(data['pos_raw']!, _posRawMeta));
    }
    if (data.containsKey('example_en')) {
      context.handle(_exampleEnMeta,
          exampleEn.isAcceptableOrUnknown(data['example_en']!, _exampleEnMeta));
    } else if (isInserting) {
      context.missing(_exampleEnMeta);
    }
    if (data.containsKey('example_tr')) {
      context.handle(_exampleTrMeta,
          exampleTr.isAcceptableOrUnknown(data['example_tr']!, _exampleTrMeta));
    }
    if (data.containsKey('synonyms_raw')) {
      context.handle(
          _synonymsRawMeta,
          synonymsRaw.isAcceptableOrUnknown(
              data['synonyms_raw']!, _synonymsRawMeta));
    }
    if (data.containsKey('antonyms_raw')) {
      context.handle(
          _antonymsRawMeta,
          antonymsRaw.isAcceptableOrUnknown(
              data['antonyms_raw']!, _antonymsRawMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    }
    if (data.containsKey('tags_raw')) {
      context.handle(_tagsRawMeta,
          tagsRaw.isAcceptableOrUnknown(data['tags_raw']!, _tagsRawMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
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
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppContentWord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppContentWord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      packId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pack_id'])!,
      enWord: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}en_word'])!,
      trMeaning: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tr_meaning'])!,
      pos: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pos'])!,
      posRaw: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pos_raw']),
      exampleEn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}example_en'])!,
      exampleTr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}example_tr']),
      synonymsRaw: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}synonyms_raw']),
      antonymsRaw: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}antonyms_raw']),
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}level']),
      tagsRaw: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags_raw']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      enWordNormalized: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}en_word_normalized'])!,
      searchKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}search_key'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AppContentWordsTable createAlias(String alias) {
    return $AppContentWordsTable(attachedDatabase, alias);
  }
}

class AppContentWord extends DataClass implements Insertable<AppContentWord> {
  final String id;
  final String packId;
  final String enWord;
  final String trMeaning;
  final String pos;
  final String? posRaw;
  final String exampleEn;
  final String? exampleTr;
  final String? synonymsRaw;
  final String? antonymsRaw;
  final String? level;
  final String? tagsRaw;
  final String? notes;
  final String enWordNormalized;
  final String searchKey;
  final int createdAt;
  const AppContentWord(
      {required this.id,
      required this.packId,
      required this.enWord,
      required this.trMeaning,
      required this.pos,
      this.posRaw,
      required this.exampleEn,
      this.exampleTr,
      this.synonymsRaw,
      this.antonymsRaw,
      this.level,
      this.tagsRaw,
      this.notes,
      required this.enWordNormalized,
      required this.searchKey,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pack_id'] = Variable<String>(packId);
    map['en_word'] = Variable<String>(enWord);
    map['tr_meaning'] = Variable<String>(trMeaning);
    map['pos'] = Variable<String>(pos);
    if (!nullToAbsent || posRaw != null) {
      map['pos_raw'] = Variable<String>(posRaw);
    }
    map['example_en'] = Variable<String>(exampleEn);
    if (!nullToAbsent || exampleTr != null) {
      map['example_tr'] = Variable<String>(exampleTr);
    }
    if (!nullToAbsent || synonymsRaw != null) {
      map['synonyms_raw'] = Variable<String>(synonymsRaw);
    }
    if (!nullToAbsent || antonymsRaw != null) {
      map['antonyms_raw'] = Variable<String>(antonymsRaw);
    }
    if (!nullToAbsent || level != null) {
      map['level'] = Variable<String>(level);
    }
    if (!nullToAbsent || tagsRaw != null) {
      map['tags_raw'] = Variable<String>(tagsRaw);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['en_word_normalized'] = Variable<String>(enWordNormalized);
    map['search_key'] = Variable<String>(searchKey);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AppContentWordsCompanion toCompanion(bool nullToAbsent) {
    return AppContentWordsCompanion(
      id: Value(id),
      packId: Value(packId),
      enWord: Value(enWord),
      trMeaning: Value(trMeaning),
      pos: Value(pos),
      posRaw:
          posRaw == null && nullToAbsent ? const Value.absent() : Value(posRaw),
      exampleEn: Value(exampleEn),
      exampleTr: exampleTr == null && nullToAbsent
          ? const Value.absent()
          : Value(exampleTr),
      synonymsRaw: synonymsRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(synonymsRaw),
      antonymsRaw: antonymsRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(antonymsRaw),
      level:
          level == null && nullToAbsent ? const Value.absent() : Value(level),
      tagsRaw: tagsRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(tagsRaw),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      enWordNormalized: Value(enWordNormalized),
      searchKey: Value(searchKey),
      createdAt: Value(createdAt),
    );
  }

  factory AppContentWord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppContentWord(
      id: serializer.fromJson<String>(json['id']),
      packId: serializer.fromJson<String>(json['packId']),
      enWord: serializer.fromJson<String>(json['enWord']),
      trMeaning: serializer.fromJson<String>(json['trMeaning']),
      pos: serializer.fromJson<String>(json['pos']),
      posRaw: serializer.fromJson<String?>(json['posRaw']),
      exampleEn: serializer.fromJson<String>(json['exampleEn']),
      exampleTr: serializer.fromJson<String?>(json['exampleTr']),
      synonymsRaw: serializer.fromJson<String?>(json['synonymsRaw']),
      antonymsRaw: serializer.fromJson<String?>(json['antonymsRaw']),
      level: serializer.fromJson<String?>(json['level']),
      tagsRaw: serializer.fromJson<String?>(json['tagsRaw']),
      notes: serializer.fromJson<String?>(json['notes']),
      enWordNormalized: serializer.fromJson<String>(json['enWordNormalized']),
      searchKey: serializer.fromJson<String>(json['searchKey']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'packId': serializer.toJson<String>(packId),
      'enWord': serializer.toJson<String>(enWord),
      'trMeaning': serializer.toJson<String>(trMeaning),
      'pos': serializer.toJson<String>(pos),
      'posRaw': serializer.toJson<String?>(posRaw),
      'exampleEn': serializer.toJson<String>(exampleEn),
      'exampleTr': serializer.toJson<String?>(exampleTr),
      'synonymsRaw': serializer.toJson<String?>(synonymsRaw),
      'antonymsRaw': serializer.toJson<String?>(antonymsRaw),
      'level': serializer.toJson<String?>(level),
      'tagsRaw': serializer.toJson<String?>(tagsRaw),
      'notes': serializer.toJson<String?>(notes),
      'enWordNormalized': serializer.toJson<String>(enWordNormalized),
      'searchKey': serializer.toJson<String>(searchKey),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  AppContentWord copyWith(
          {String? id,
          String? packId,
          String? enWord,
          String? trMeaning,
          String? pos,
          Value<String?> posRaw = const Value.absent(),
          String? exampleEn,
          Value<String?> exampleTr = const Value.absent(),
          Value<String?> synonymsRaw = const Value.absent(),
          Value<String?> antonymsRaw = const Value.absent(),
          Value<String?> level = const Value.absent(),
          Value<String?> tagsRaw = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          String? enWordNormalized,
          String? searchKey,
          int? createdAt}) =>
      AppContentWord(
        id: id ?? this.id,
        packId: packId ?? this.packId,
        enWord: enWord ?? this.enWord,
        trMeaning: trMeaning ?? this.trMeaning,
        pos: pos ?? this.pos,
        posRaw: posRaw.present ? posRaw.value : this.posRaw,
        exampleEn: exampleEn ?? this.exampleEn,
        exampleTr: exampleTr.present ? exampleTr.value : this.exampleTr,
        synonymsRaw: synonymsRaw.present ? synonymsRaw.value : this.synonymsRaw,
        antonymsRaw: antonymsRaw.present ? antonymsRaw.value : this.antonymsRaw,
        level: level.present ? level.value : this.level,
        tagsRaw: tagsRaw.present ? tagsRaw.value : this.tagsRaw,
        notes: notes.present ? notes.value : this.notes,
        enWordNormalized: enWordNormalized ?? this.enWordNormalized,
        searchKey: searchKey ?? this.searchKey,
        createdAt: createdAt ?? this.createdAt,
      );
  AppContentWord copyWithCompanion(AppContentWordsCompanion data) {
    return AppContentWord(
      id: data.id.present ? data.id.value : this.id,
      packId: data.packId.present ? data.packId.value : this.packId,
      enWord: data.enWord.present ? data.enWord.value : this.enWord,
      trMeaning: data.trMeaning.present ? data.trMeaning.value : this.trMeaning,
      pos: data.pos.present ? data.pos.value : this.pos,
      posRaw: data.posRaw.present ? data.posRaw.value : this.posRaw,
      exampleEn: data.exampleEn.present ? data.exampleEn.value : this.exampleEn,
      exampleTr: data.exampleTr.present ? data.exampleTr.value : this.exampleTr,
      synonymsRaw:
          data.synonymsRaw.present ? data.synonymsRaw.value : this.synonymsRaw,
      antonymsRaw:
          data.antonymsRaw.present ? data.antonymsRaw.value : this.antonymsRaw,
      level: data.level.present ? data.level.value : this.level,
      tagsRaw: data.tagsRaw.present ? data.tagsRaw.value : this.tagsRaw,
      notes: data.notes.present ? data.notes.value : this.notes,
      enWordNormalized: data.enWordNormalized.present
          ? data.enWordNormalized.value
          : this.enWordNormalized,
      searchKey: data.searchKey.present ? data.searchKey.value : this.searchKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppContentWord(')
          ..write('id: $id, ')
          ..write('packId: $packId, ')
          ..write('enWord: $enWord, ')
          ..write('trMeaning: $trMeaning, ')
          ..write('pos: $pos, ')
          ..write('posRaw: $posRaw, ')
          ..write('exampleEn: $exampleEn, ')
          ..write('exampleTr: $exampleTr, ')
          ..write('synonymsRaw: $synonymsRaw, ')
          ..write('antonymsRaw: $antonymsRaw, ')
          ..write('level: $level, ')
          ..write('tagsRaw: $tagsRaw, ')
          ..write('notes: $notes, ')
          ..write('enWordNormalized: $enWordNormalized, ')
          ..write('searchKey: $searchKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      packId,
      enWord,
      trMeaning,
      pos,
      posRaw,
      exampleEn,
      exampleTr,
      synonymsRaw,
      antonymsRaw,
      level,
      tagsRaw,
      notes,
      enWordNormalized,
      searchKey,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppContentWord &&
          other.id == this.id &&
          other.packId == this.packId &&
          other.enWord == this.enWord &&
          other.trMeaning == this.trMeaning &&
          other.pos == this.pos &&
          other.posRaw == this.posRaw &&
          other.exampleEn == this.exampleEn &&
          other.exampleTr == this.exampleTr &&
          other.synonymsRaw == this.synonymsRaw &&
          other.antonymsRaw == this.antonymsRaw &&
          other.level == this.level &&
          other.tagsRaw == this.tagsRaw &&
          other.notes == this.notes &&
          other.enWordNormalized == this.enWordNormalized &&
          other.searchKey == this.searchKey &&
          other.createdAt == this.createdAt);
}

class AppContentWordsCompanion extends UpdateCompanion<AppContentWord> {
  final Value<String> id;
  final Value<String> packId;
  final Value<String> enWord;
  final Value<String> trMeaning;
  final Value<String> pos;
  final Value<String?> posRaw;
  final Value<String> exampleEn;
  final Value<String?> exampleTr;
  final Value<String?> synonymsRaw;
  final Value<String?> antonymsRaw;
  final Value<String?> level;
  final Value<String?> tagsRaw;
  final Value<String?> notes;
  final Value<String> enWordNormalized;
  final Value<String> searchKey;
  final Value<int> createdAt;
  final Value<int> rowid;
  const AppContentWordsCompanion({
    this.id = const Value.absent(),
    this.packId = const Value.absent(),
    this.enWord = const Value.absent(),
    this.trMeaning = const Value.absent(),
    this.pos = const Value.absent(),
    this.posRaw = const Value.absent(),
    this.exampleEn = const Value.absent(),
    this.exampleTr = const Value.absent(),
    this.synonymsRaw = const Value.absent(),
    this.antonymsRaw = const Value.absent(),
    this.level = const Value.absent(),
    this.tagsRaw = const Value.absent(),
    this.notes = const Value.absent(),
    this.enWordNormalized = const Value.absent(),
    this.searchKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppContentWordsCompanion.insert({
    required String id,
    required String packId,
    required String enWord,
    required String trMeaning,
    required String pos,
    this.posRaw = const Value.absent(),
    required String exampleEn,
    this.exampleTr = const Value.absent(),
    this.synonymsRaw = const Value.absent(),
    this.antonymsRaw = const Value.absent(),
    this.level = const Value.absent(),
    this.tagsRaw = const Value.absent(),
    this.notes = const Value.absent(),
    required String enWordNormalized,
    required String searchKey,
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        packId = Value(packId),
        enWord = Value(enWord),
        trMeaning = Value(trMeaning),
        pos = Value(pos),
        exampleEn = Value(exampleEn),
        enWordNormalized = Value(enWordNormalized),
        searchKey = Value(searchKey),
        createdAt = Value(createdAt);
  static Insertable<AppContentWord> custom({
    Expression<String>? id,
    Expression<String>? packId,
    Expression<String>? enWord,
    Expression<String>? trMeaning,
    Expression<String>? pos,
    Expression<String>? posRaw,
    Expression<String>? exampleEn,
    Expression<String>? exampleTr,
    Expression<String>? synonymsRaw,
    Expression<String>? antonymsRaw,
    Expression<String>? level,
    Expression<String>? tagsRaw,
    Expression<String>? notes,
    Expression<String>? enWordNormalized,
    Expression<String>? searchKey,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (packId != null) 'pack_id': packId,
      if (enWord != null) 'en_word': enWord,
      if (trMeaning != null) 'tr_meaning': trMeaning,
      if (pos != null) 'pos': pos,
      if (posRaw != null) 'pos_raw': posRaw,
      if (exampleEn != null) 'example_en': exampleEn,
      if (exampleTr != null) 'example_tr': exampleTr,
      if (synonymsRaw != null) 'synonyms_raw': synonymsRaw,
      if (antonymsRaw != null) 'antonyms_raw': antonymsRaw,
      if (level != null) 'level': level,
      if (tagsRaw != null) 'tags_raw': tagsRaw,
      if (notes != null) 'notes': notes,
      if (enWordNormalized != null) 'en_word_normalized': enWordNormalized,
      if (searchKey != null) 'search_key': searchKey,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppContentWordsCompanion copyWith(
      {Value<String>? id,
      Value<String>? packId,
      Value<String>? enWord,
      Value<String>? trMeaning,
      Value<String>? pos,
      Value<String?>? posRaw,
      Value<String>? exampleEn,
      Value<String?>? exampleTr,
      Value<String?>? synonymsRaw,
      Value<String?>? antonymsRaw,
      Value<String?>? level,
      Value<String?>? tagsRaw,
      Value<String?>? notes,
      Value<String>? enWordNormalized,
      Value<String>? searchKey,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return AppContentWordsCompanion(
      id: id ?? this.id,
      packId: packId ?? this.packId,
      enWord: enWord ?? this.enWord,
      trMeaning: trMeaning ?? this.trMeaning,
      pos: pos ?? this.pos,
      posRaw: posRaw ?? this.posRaw,
      exampleEn: exampleEn ?? this.exampleEn,
      exampleTr: exampleTr ?? this.exampleTr,
      synonymsRaw: synonymsRaw ?? this.synonymsRaw,
      antonymsRaw: antonymsRaw ?? this.antonymsRaw,
      level: level ?? this.level,
      tagsRaw: tagsRaw ?? this.tagsRaw,
      notes: notes ?? this.notes,
      enWordNormalized: enWordNormalized ?? this.enWordNormalized,
      searchKey: searchKey ?? this.searchKey,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (packId.present) {
      map['pack_id'] = Variable<String>(packId.value);
    }
    if (enWord.present) {
      map['en_word'] = Variable<String>(enWord.value);
    }
    if (trMeaning.present) {
      map['tr_meaning'] = Variable<String>(trMeaning.value);
    }
    if (pos.present) {
      map['pos'] = Variable<String>(pos.value);
    }
    if (posRaw.present) {
      map['pos_raw'] = Variable<String>(posRaw.value);
    }
    if (exampleEn.present) {
      map['example_en'] = Variable<String>(exampleEn.value);
    }
    if (exampleTr.present) {
      map['example_tr'] = Variable<String>(exampleTr.value);
    }
    if (synonymsRaw.present) {
      map['synonyms_raw'] = Variable<String>(synonymsRaw.value);
    }
    if (antonymsRaw.present) {
      map['antonyms_raw'] = Variable<String>(antonymsRaw.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (tagsRaw.present) {
      map['tags_raw'] = Variable<String>(tagsRaw.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (enWordNormalized.present) {
      map['en_word_normalized'] = Variable<String>(enWordNormalized.value);
    }
    if (searchKey.present) {
      map['search_key'] = Variable<String>(searchKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppContentWordsCompanion(')
          ..write('id: $id, ')
          ..write('packId: $packId, ')
          ..write('enWord: $enWord, ')
          ..write('trMeaning: $trMeaning, ')
          ..write('pos: $pos, ')
          ..write('posRaw: $posRaw, ')
          ..write('exampleEn: $exampleEn, ')
          ..write('exampleTr: $exampleTr, ')
          ..write('synonymsRaw: $synonymsRaw, ')
          ..write('antonymsRaw: $antonymsRaw, ')
          ..write('level: $level, ')
          ..write('tagsRaw: $tagsRaw, ')
          ..write('notes: $notes, ')
          ..write('enWordNormalized: $enWordNormalized, ')
          ..write('searchKey: $searchKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppContentReadingPassagesTable extends AppContentReadingPassages
    with TableInfo<$AppContentReadingPassagesTable, AppContentReadingPassage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppContentReadingPassagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _packIdMeta = const VerificationMeta('packId');
  @override
  late final GeneratedColumn<String> packId = GeneratedColumn<String>(
      'pack_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _packNameMeta =
      const VerificationMeta('packName');
  @override
  late final GeneratedColumn<String> packName = GeneratedColumn<String>(
      'pack_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
      'level', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagsRawMeta =
      const VerificationMeta('tagsRaw');
  @override
  late final GeneratedColumn<String> tagsRaw = GeneratedColumn<String>(
      'tags_raw', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, packId, packName, title, level, tagsRaw, category, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_passages';
  @override
  VerificationContext validateIntegrity(
      Insertable<AppContentReadingPassage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pack_id')) {
      context.handle(_packIdMeta,
          packId.isAcceptableOrUnknown(data['pack_id']!, _packIdMeta));
    }
    if (data.containsKey('pack_name')) {
      context.handle(_packNameMeta,
          packName.isAcceptableOrUnknown(data['pack_name']!, _packNameMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    }
    if (data.containsKey('tags_raw')) {
      context.handle(_tagsRawMeta,
          tagsRaw.isAcceptableOrUnknown(data['tags_raw']!, _tagsRawMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppContentReadingPassage map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppContentReadingPassage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      packId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pack_id']),
      packName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pack_name']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}level']),
      tagsRaw: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags_raw']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AppContentReadingPassagesTable createAlias(String alias) {
    return $AppContentReadingPassagesTable(attachedDatabase, alias);
  }
}

class AppContentReadingPassage extends DataClass
    implements Insertable<AppContentReadingPassage> {
  final String id;
  final String? packId;
  final String? packName;
  final String title;
  final String? level;
  final String? tagsRaw;
  final String? category;
  final int createdAt;
  const AppContentReadingPassage(
      {required this.id,
      this.packId,
      this.packName,
      required this.title,
      this.level,
      this.tagsRaw,
      this.category,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || packId != null) {
      map['pack_id'] = Variable<String>(packId);
    }
    if (!nullToAbsent || packName != null) {
      map['pack_name'] = Variable<String>(packName);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || level != null) {
      map['level'] = Variable<String>(level);
    }
    if (!nullToAbsent || tagsRaw != null) {
      map['tags_raw'] = Variable<String>(tagsRaw);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AppContentReadingPassagesCompanion toCompanion(bool nullToAbsent) {
    return AppContentReadingPassagesCompanion(
      id: Value(id),
      packId:
          packId == null && nullToAbsent ? const Value.absent() : Value(packId),
      packName: packName == null && nullToAbsent
          ? const Value.absent()
          : Value(packName),
      title: Value(title),
      level:
          level == null && nullToAbsent ? const Value.absent() : Value(level),
      tagsRaw: tagsRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(tagsRaw),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      createdAt: Value(createdAt),
    );
  }

  factory AppContentReadingPassage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppContentReadingPassage(
      id: serializer.fromJson<String>(json['id']),
      packId: serializer.fromJson<String?>(json['packId']),
      packName: serializer.fromJson<String?>(json['packName']),
      title: serializer.fromJson<String>(json['title']),
      level: serializer.fromJson<String?>(json['level']),
      tagsRaw: serializer.fromJson<String?>(json['tagsRaw']),
      category: serializer.fromJson<String?>(json['category']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'packId': serializer.toJson<String?>(packId),
      'packName': serializer.toJson<String?>(packName),
      'title': serializer.toJson<String>(title),
      'level': serializer.toJson<String?>(level),
      'tagsRaw': serializer.toJson<String?>(tagsRaw),
      'category': serializer.toJson<String?>(category),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  AppContentReadingPassage copyWith(
          {String? id,
          Value<String?> packId = const Value.absent(),
          Value<String?> packName = const Value.absent(),
          String? title,
          Value<String?> level = const Value.absent(),
          Value<String?> tagsRaw = const Value.absent(),
          Value<String?> category = const Value.absent(),
          int? createdAt}) =>
      AppContentReadingPassage(
        id: id ?? this.id,
        packId: packId.present ? packId.value : this.packId,
        packName: packName.present ? packName.value : this.packName,
        title: title ?? this.title,
        level: level.present ? level.value : this.level,
        tagsRaw: tagsRaw.present ? tagsRaw.value : this.tagsRaw,
        category: category.present ? category.value : this.category,
        createdAt: createdAt ?? this.createdAt,
      );
  AppContentReadingPassage copyWithCompanion(
      AppContentReadingPassagesCompanion data) {
    return AppContentReadingPassage(
      id: data.id.present ? data.id.value : this.id,
      packId: data.packId.present ? data.packId.value : this.packId,
      packName: data.packName.present ? data.packName.value : this.packName,
      title: data.title.present ? data.title.value : this.title,
      level: data.level.present ? data.level.value : this.level,
      tagsRaw: data.tagsRaw.present ? data.tagsRaw.value : this.tagsRaw,
      category: data.category.present ? data.category.value : this.category,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppContentReadingPassage(')
          ..write('id: $id, ')
          ..write('packId: $packId, ')
          ..write('packName: $packName, ')
          ..write('title: $title, ')
          ..write('level: $level, ')
          ..write('tagsRaw: $tagsRaw, ')
          ..write('category: $category, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, packId, packName, title, level, tagsRaw, category, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppContentReadingPassage &&
          other.id == this.id &&
          other.packId == this.packId &&
          other.packName == this.packName &&
          other.title == this.title &&
          other.level == this.level &&
          other.tagsRaw == this.tagsRaw &&
          other.category == this.category &&
          other.createdAt == this.createdAt);
}

class AppContentReadingPassagesCompanion
    extends UpdateCompanion<AppContentReadingPassage> {
  final Value<String> id;
  final Value<String?> packId;
  final Value<String?> packName;
  final Value<String> title;
  final Value<String?> level;
  final Value<String?> tagsRaw;
  final Value<String?> category;
  final Value<int> createdAt;
  final Value<int> rowid;
  const AppContentReadingPassagesCompanion({
    this.id = const Value.absent(),
    this.packId = const Value.absent(),
    this.packName = const Value.absent(),
    this.title = const Value.absent(),
    this.level = const Value.absent(),
    this.tagsRaw = const Value.absent(),
    this.category = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppContentReadingPassagesCompanion.insert({
    required String id,
    this.packId = const Value.absent(),
    this.packName = const Value.absent(),
    required String title,
    this.level = const Value.absent(),
    this.tagsRaw = const Value.absent(),
    this.category = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        createdAt = Value(createdAt);
  static Insertable<AppContentReadingPassage> custom({
    Expression<String>? id,
    Expression<String>? packId,
    Expression<String>? packName,
    Expression<String>? title,
    Expression<String>? level,
    Expression<String>? tagsRaw,
    Expression<String>? category,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (packId != null) 'pack_id': packId,
      if (packName != null) 'pack_name': packName,
      if (title != null) 'title': title,
      if (level != null) 'level': level,
      if (tagsRaw != null) 'tags_raw': tagsRaw,
      if (category != null) 'category': category,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppContentReadingPassagesCompanion copyWith(
      {Value<String>? id,
      Value<String?>? packId,
      Value<String?>? packName,
      Value<String>? title,
      Value<String?>? level,
      Value<String?>? tagsRaw,
      Value<String?>? category,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return AppContentReadingPassagesCompanion(
      id: id ?? this.id,
      packId: packId ?? this.packId,
      packName: packName ?? this.packName,
      title: title ?? this.title,
      level: level ?? this.level,
      tagsRaw: tagsRaw ?? this.tagsRaw,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (packId.present) {
      map['pack_id'] = Variable<String>(packId.value);
    }
    if (packName.present) {
      map['pack_name'] = Variable<String>(packName.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (tagsRaw.present) {
      map['tags_raw'] = Variable<String>(tagsRaw.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppContentReadingPassagesCompanion(')
          ..write('id: $id, ')
          ..write('packId: $packId, ')
          ..write('packName: $packName, ')
          ..write('title: $title, ')
          ..write('level: $level, ')
          ..write('tagsRaw: $tagsRaw, ')
          ..write('category: $category, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppContentReadingSentencesTable extends AppContentReadingSentences
    with
        TableInfo<$AppContentReadingSentencesTable, AppContentReadingSentence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppContentReadingSentencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _passageIdMeta =
      const VerificationMeta('passageId');
  @override
  late final GeneratedColumn<String> passageId = GeneratedColumn<String>(
      'passage_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _passageTitleMeta =
      const VerificationMeta('passageTitle');
  @override
  late final GeneratedColumn<String> passageTitle = GeneratedColumn<String>(
      'passage_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idxMeta = const VerificationMeta('idx');
  @override
  late final GeneratedColumn<int> idx = GeneratedColumn<int>(
      'idx', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sentenceEnMeta =
      const VerificationMeta('sentenceEn');
  @override
  late final GeneratedColumn<String> sentenceEn = GeneratedColumn<String>(
      'sentence_en', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sentenceTrMeta =
      const VerificationMeta('sentenceTr');
  @override
  late final GeneratedColumn<String> sentenceTr = GeneratedColumn<String>(
      'sentence_tr', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, passageId, passageTitle, idx, sentenceEn, sentenceTr, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_sentences';
  @override
  VerificationContext validateIntegrity(
      Insertable<AppContentReadingSentence> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('passage_id')) {
      context.handle(_passageIdMeta,
          passageId.isAcceptableOrUnknown(data['passage_id']!, _passageIdMeta));
    } else if (isInserting) {
      context.missing(_passageIdMeta);
    }
    if (data.containsKey('passage_title')) {
      context.handle(
          _passageTitleMeta,
          passageTitle.isAcceptableOrUnknown(
              data['passage_title']!, _passageTitleMeta));
    } else if (isInserting) {
      context.missing(_passageTitleMeta);
    }
    if (data.containsKey('idx')) {
      context.handle(
          _idxMeta, idx.isAcceptableOrUnknown(data['idx']!, _idxMeta));
    } else if (isInserting) {
      context.missing(_idxMeta);
    }
    if (data.containsKey('sentence_en')) {
      context.handle(
          _sentenceEnMeta,
          sentenceEn.isAcceptableOrUnknown(
              data['sentence_en']!, _sentenceEnMeta));
    } else if (isInserting) {
      context.missing(_sentenceEnMeta);
    }
    if (data.containsKey('sentence_tr')) {
      context.handle(
          _sentenceTrMeta,
          sentenceTr.isAcceptableOrUnknown(
              data['sentence_tr']!, _sentenceTrMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppContentReadingSentence map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppContentReadingSentence(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      passageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}passage_id'])!,
      passageTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}passage_title'])!,
      idx: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}idx'])!,
      sentenceEn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sentence_en'])!,
      sentenceTr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sentence_tr']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AppContentReadingSentencesTable createAlias(String alias) {
    return $AppContentReadingSentencesTable(attachedDatabase, alias);
  }
}

class AppContentReadingSentence extends DataClass
    implements Insertable<AppContentReadingSentence> {
  final String id;
  final String passageId;
  final String passageTitle;
  final int idx;
  final String sentenceEn;
  final String? sentenceTr;
  final int createdAt;
  const AppContentReadingSentence(
      {required this.id,
      required this.passageId,
      required this.passageTitle,
      required this.idx,
      required this.sentenceEn,
      this.sentenceTr,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['passage_id'] = Variable<String>(passageId);
    map['passage_title'] = Variable<String>(passageTitle);
    map['idx'] = Variable<int>(idx);
    map['sentence_en'] = Variable<String>(sentenceEn);
    if (!nullToAbsent || sentenceTr != null) {
      map['sentence_tr'] = Variable<String>(sentenceTr);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AppContentReadingSentencesCompanion toCompanion(bool nullToAbsent) {
    return AppContentReadingSentencesCompanion(
      id: Value(id),
      passageId: Value(passageId),
      passageTitle: Value(passageTitle),
      idx: Value(idx),
      sentenceEn: Value(sentenceEn),
      sentenceTr: sentenceTr == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceTr),
      createdAt: Value(createdAt),
    );
  }

  factory AppContentReadingSentence.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppContentReadingSentence(
      id: serializer.fromJson<String>(json['id']),
      passageId: serializer.fromJson<String>(json['passageId']),
      passageTitle: serializer.fromJson<String>(json['passageTitle']),
      idx: serializer.fromJson<int>(json['idx']),
      sentenceEn: serializer.fromJson<String>(json['sentenceEn']),
      sentenceTr: serializer.fromJson<String?>(json['sentenceTr']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'passageId': serializer.toJson<String>(passageId),
      'passageTitle': serializer.toJson<String>(passageTitle),
      'idx': serializer.toJson<int>(idx),
      'sentenceEn': serializer.toJson<String>(sentenceEn),
      'sentenceTr': serializer.toJson<String?>(sentenceTr),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  AppContentReadingSentence copyWith(
          {String? id,
          String? passageId,
          String? passageTitle,
          int? idx,
          String? sentenceEn,
          Value<String?> sentenceTr = const Value.absent(),
          int? createdAt}) =>
      AppContentReadingSentence(
        id: id ?? this.id,
        passageId: passageId ?? this.passageId,
        passageTitle: passageTitle ?? this.passageTitle,
        idx: idx ?? this.idx,
        sentenceEn: sentenceEn ?? this.sentenceEn,
        sentenceTr: sentenceTr.present ? sentenceTr.value : this.sentenceTr,
        createdAt: createdAt ?? this.createdAt,
      );
  AppContentReadingSentence copyWithCompanion(
      AppContentReadingSentencesCompanion data) {
    return AppContentReadingSentence(
      id: data.id.present ? data.id.value : this.id,
      passageId: data.passageId.present ? data.passageId.value : this.passageId,
      passageTitle: data.passageTitle.present
          ? data.passageTitle.value
          : this.passageTitle,
      idx: data.idx.present ? data.idx.value : this.idx,
      sentenceEn:
          data.sentenceEn.present ? data.sentenceEn.value : this.sentenceEn,
      sentenceTr:
          data.sentenceTr.present ? data.sentenceTr.value : this.sentenceTr,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppContentReadingSentence(')
          ..write('id: $id, ')
          ..write('passageId: $passageId, ')
          ..write('passageTitle: $passageTitle, ')
          ..write('idx: $idx, ')
          ..write('sentenceEn: $sentenceEn, ')
          ..write('sentenceTr: $sentenceTr, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, passageId, passageTitle, idx, sentenceEn, sentenceTr, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppContentReadingSentence &&
          other.id == this.id &&
          other.passageId == this.passageId &&
          other.passageTitle == this.passageTitle &&
          other.idx == this.idx &&
          other.sentenceEn == this.sentenceEn &&
          other.sentenceTr == this.sentenceTr &&
          other.createdAt == this.createdAt);
}

class AppContentReadingSentencesCompanion
    extends UpdateCompanion<AppContentReadingSentence> {
  final Value<String> id;
  final Value<String> passageId;
  final Value<String> passageTitle;
  final Value<int> idx;
  final Value<String> sentenceEn;
  final Value<String?> sentenceTr;
  final Value<int> createdAt;
  final Value<int> rowid;
  const AppContentReadingSentencesCompanion({
    this.id = const Value.absent(),
    this.passageId = const Value.absent(),
    this.passageTitle = const Value.absent(),
    this.idx = const Value.absent(),
    this.sentenceEn = const Value.absent(),
    this.sentenceTr = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppContentReadingSentencesCompanion.insert({
    required String id,
    required String passageId,
    required String passageTitle,
    required int idx,
    required String sentenceEn,
    this.sentenceTr = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        passageId = Value(passageId),
        passageTitle = Value(passageTitle),
        idx = Value(idx),
        sentenceEn = Value(sentenceEn),
        createdAt = Value(createdAt);
  static Insertable<AppContentReadingSentence> custom({
    Expression<String>? id,
    Expression<String>? passageId,
    Expression<String>? passageTitle,
    Expression<int>? idx,
    Expression<String>? sentenceEn,
    Expression<String>? sentenceTr,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (passageId != null) 'passage_id': passageId,
      if (passageTitle != null) 'passage_title': passageTitle,
      if (idx != null) 'idx': idx,
      if (sentenceEn != null) 'sentence_en': sentenceEn,
      if (sentenceTr != null) 'sentence_tr': sentenceTr,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppContentReadingSentencesCompanion copyWith(
      {Value<String>? id,
      Value<String>? passageId,
      Value<String>? passageTitle,
      Value<int>? idx,
      Value<String>? sentenceEn,
      Value<String?>? sentenceTr,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return AppContentReadingSentencesCompanion(
      id: id ?? this.id,
      passageId: passageId ?? this.passageId,
      passageTitle: passageTitle ?? this.passageTitle,
      idx: idx ?? this.idx,
      sentenceEn: sentenceEn ?? this.sentenceEn,
      sentenceTr: sentenceTr ?? this.sentenceTr,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (passageId.present) {
      map['passage_id'] = Variable<String>(passageId.value);
    }
    if (passageTitle.present) {
      map['passage_title'] = Variable<String>(passageTitle.value);
    }
    if (idx.present) {
      map['idx'] = Variable<int>(idx.value);
    }
    if (sentenceEn.present) {
      map['sentence_en'] = Variable<String>(sentenceEn.value);
    }
    if (sentenceTr.present) {
      map['sentence_tr'] = Variable<String>(sentenceTr.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppContentReadingSentencesCompanion(')
          ..write('id: $id, ')
          ..write('passageId: $passageId, ')
          ..write('passageTitle: $passageTitle, ')
          ..write('idx: $idx, ')
          ..write('sentenceEn: $sentenceEn, ')
          ..write('sentenceTr: $sentenceTr, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppContentLocalDatabase extends GeneratedDatabase {
  _$AppContentLocalDatabase(QueryExecutor e) : super(e);
  $AppContentLocalDatabaseManager get managers =>
      $AppContentLocalDatabaseManager(this);
  late final $AppContentMetaTable appContentMeta = $AppContentMetaTable(this);
  late final $AppContentPacksTable appContentPacks =
      $AppContentPacksTable(this);
  late final $AppContentWordsTable appContentWords =
      $AppContentWordsTable(this);
  late final $AppContentReadingPassagesTable appContentReadingPassages =
      $AppContentReadingPassagesTable(this);
  late final $AppContentReadingSentencesTable appContentReadingSentences =
      $AppContentReadingSentencesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        appContentMeta,
        appContentPacks,
        appContentWords,
        appContentReadingPassages,
        appContentReadingSentences
      ];
}

typedef $$AppContentMetaTableCreateCompanionBuilder = AppContentMetaCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppContentMetaTableUpdateCompanionBuilder = AppContentMetaCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppContentMetaTableFilterComposer
    extends Composer<_$AppContentLocalDatabase, $AppContentMetaTable> {
  $$AppContentMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppContentMetaTableOrderingComposer
    extends Composer<_$AppContentLocalDatabase, $AppContentMetaTable> {
  $$AppContentMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppContentMetaTableAnnotationComposer
    extends Composer<_$AppContentLocalDatabase, $AppContentMetaTable> {
  $$AppContentMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppContentMetaTableTableManager extends RootTableManager<
    _$AppContentLocalDatabase,
    $AppContentMetaTable,
    AppContentMetaData,
    $$AppContentMetaTableFilterComposer,
    $$AppContentMetaTableOrderingComposer,
    $$AppContentMetaTableAnnotationComposer,
    $$AppContentMetaTableCreateCompanionBuilder,
    $$AppContentMetaTableUpdateCompanionBuilder,
    (
      AppContentMetaData,
      BaseReferences<_$AppContentLocalDatabase, $AppContentMetaTable,
          AppContentMetaData>
    ),
    AppContentMetaData,
    PrefetchHooks Function()> {
  $$AppContentMetaTableTableManager(
      _$AppContentLocalDatabase db, $AppContentMetaTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppContentMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppContentMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppContentMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentMetaCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentMetaCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppContentMetaTableProcessedTableManager = ProcessedTableManager<
    _$AppContentLocalDatabase,
    $AppContentMetaTable,
    AppContentMetaData,
    $$AppContentMetaTableFilterComposer,
    $$AppContentMetaTableOrderingComposer,
    $$AppContentMetaTableAnnotationComposer,
    $$AppContentMetaTableCreateCompanionBuilder,
    $$AppContentMetaTableUpdateCompanionBuilder,
    (
      AppContentMetaData,
      BaseReferences<_$AppContentLocalDatabase, $AppContentMetaTable,
          AppContentMetaData>
    ),
    AppContentMetaData,
    PrefetchHooks Function()>;
typedef $$AppContentPacksTableCreateCompanionBuilder = AppContentPacksCompanion
    Function({
  required String id,
  required String name,
  required String fromLang,
  required String toLang,
  Value<int> rowid,
});
typedef $$AppContentPacksTableUpdateCompanionBuilder = AppContentPacksCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> fromLang,
  Value<String> toLang,
  Value<int> rowid,
});

class $$AppContentPacksTableFilterComposer
    extends Composer<_$AppContentLocalDatabase, $AppContentPacksTable> {
  $$AppContentPacksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromLang => $composableBuilder(
      column: $table.fromLang, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toLang => $composableBuilder(
      column: $table.toLang, builder: (column) => ColumnFilters(column));
}

class $$AppContentPacksTableOrderingComposer
    extends Composer<_$AppContentLocalDatabase, $AppContentPacksTable> {
  $$AppContentPacksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromLang => $composableBuilder(
      column: $table.fromLang, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toLang => $composableBuilder(
      column: $table.toLang, builder: (column) => ColumnOrderings(column));
}

class $$AppContentPacksTableAnnotationComposer
    extends Composer<_$AppContentLocalDatabase, $AppContentPacksTable> {
  $$AppContentPacksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get fromLang =>
      $composableBuilder(column: $table.fromLang, builder: (column) => column);

  GeneratedColumn<String> get toLang =>
      $composableBuilder(column: $table.toLang, builder: (column) => column);
}

class $$AppContentPacksTableTableManager extends RootTableManager<
    _$AppContentLocalDatabase,
    $AppContentPacksTable,
    AppContentPack,
    $$AppContentPacksTableFilterComposer,
    $$AppContentPacksTableOrderingComposer,
    $$AppContentPacksTableAnnotationComposer,
    $$AppContentPacksTableCreateCompanionBuilder,
    $$AppContentPacksTableUpdateCompanionBuilder,
    (
      AppContentPack,
      BaseReferences<_$AppContentLocalDatabase, $AppContentPacksTable,
          AppContentPack>
    ),
    AppContentPack,
    PrefetchHooks Function()> {
  $$AppContentPacksTableTableManager(
      _$AppContentLocalDatabase db, $AppContentPacksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppContentPacksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppContentPacksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppContentPacksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> fromLang = const Value.absent(),
            Value<String> toLang = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentPacksCompanion(
            id: id,
            name: name,
            fromLang: fromLang,
            toLang: toLang,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String fromLang,
            required String toLang,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentPacksCompanion.insert(
            id: id,
            name: name,
            fromLang: fromLang,
            toLang: toLang,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppContentPacksTableProcessedTableManager = ProcessedTableManager<
    _$AppContentLocalDatabase,
    $AppContentPacksTable,
    AppContentPack,
    $$AppContentPacksTableFilterComposer,
    $$AppContentPacksTableOrderingComposer,
    $$AppContentPacksTableAnnotationComposer,
    $$AppContentPacksTableCreateCompanionBuilder,
    $$AppContentPacksTableUpdateCompanionBuilder,
    (
      AppContentPack,
      BaseReferences<_$AppContentLocalDatabase, $AppContentPacksTable,
          AppContentPack>
    ),
    AppContentPack,
    PrefetchHooks Function()>;
typedef $$AppContentWordsTableCreateCompanionBuilder = AppContentWordsCompanion
    Function({
  required String id,
  required String packId,
  required String enWord,
  required String trMeaning,
  required String pos,
  Value<String?> posRaw,
  required String exampleEn,
  Value<String?> exampleTr,
  Value<String?> synonymsRaw,
  Value<String?> antonymsRaw,
  Value<String?> level,
  Value<String?> tagsRaw,
  Value<String?> notes,
  required String enWordNormalized,
  required String searchKey,
  required int createdAt,
  Value<int> rowid,
});
typedef $$AppContentWordsTableUpdateCompanionBuilder = AppContentWordsCompanion
    Function({
  Value<String> id,
  Value<String> packId,
  Value<String> enWord,
  Value<String> trMeaning,
  Value<String> pos,
  Value<String?> posRaw,
  Value<String> exampleEn,
  Value<String?> exampleTr,
  Value<String?> synonymsRaw,
  Value<String?> antonymsRaw,
  Value<String?> level,
  Value<String?> tagsRaw,
  Value<String?> notes,
  Value<String> enWordNormalized,
  Value<String> searchKey,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$AppContentWordsTableFilterComposer
    extends Composer<_$AppContentLocalDatabase, $AppContentWordsTable> {
  $$AppContentWordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get packId => $composableBuilder(
      column: $table.packId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get enWord => $composableBuilder(
      column: $table.enWord, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trMeaning => $composableBuilder(
      column: $table.trMeaning, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pos => $composableBuilder(
      column: $table.pos, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posRaw => $composableBuilder(
      column: $table.posRaw, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exampleEn => $composableBuilder(
      column: $table.exampleEn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exampleTr => $composableBuilder(
      column: $table.exampleTr, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get synonymsRaw => $composableBuilder(
      column: $table.synonymsRaw, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get antonymsRaw => $composableBuilder(
      column: $table.antonymsRaw, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagsRaw => $composableBuilder(
      column: $table.tagsRaw, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get enWordNormalized => $composableBuilder(
      column: $table.enWordNormalized,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get searchKey => $composableBuilder(
      column: $table.searchKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AppContentWordsTableOrderingComposer
    extends Composer<_$AppContentLocalDatabase, $AppContentWordsTable> {
  $$AppContentWordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get packId => $composableBuilder(
      column: $table.packId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get enWord => $composableBuilder(
      column: $table.enWord, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trMeaning => $composableBuilder(
      column: $table.trMeaning, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pos => $composableBuilder(
      column: $table.pos, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posRaw => $composableBuilder(
      column: $table.posRaw, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exampleEn => $composableBuilder(
      column: $table.exampleEn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exampleTr => $composableBuilder(
      column: $table.exampleTr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get synonymsRaw => $composableBuilder(
      column: $table.synonymsRaw, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get antonymsRaw => $composableBuilder(
      column: $table.antonymsRaw, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagsRaw => $composableBuilder(
      column: $table.tagsRaw, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get enWordNormalized => $composableBuilder(
      column: $table.enWordNormalized,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get searchKey => $composableBuilder(
      column: $table.searchKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AppContentWordsTableAnnotationComposer
    extends Composer<_$AppContentLocalDatabase, $AppContentWordsTable> {
  $$AppContentWordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get packId =>
      $composableBuilder(column: $table.packId, builder: (column) => column);

  GeneratedColumn<String> get enWord =>
      $composableBuilder(column: $table.enWord, builder: (column) => column);

  GeneratedColumn<String> get trMeaning =>
      $composableBuilder(column: $table.trMeaning, builder: (column) => column);

  GeneratedColumn<String> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<String> get posRaw =>
      $composableBuilder(column: $table.posRaw, builder: (column) => column);

  GeneratedColumn<String> get exampleEn =>
      $composableBuilder(column: $table.exampleEn, builder: (column) => column);

  GeneratedColumn<String> get exampleTr =>
      $composableBuilder(column: $table.exampleTr, builder: (column) => column);

  GeneratedColumn<String> get synonymsRaw => $composableBuilder(
      column: $table.synonymsRaw, builder: (column) => column);

  GeneratedColumn<String> get antonymsRaw => $composableBuilder(
      column: $table.antonymsRaw, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get tagsRaw =>
      $composableBuilder(column: $table.tagsRaw, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get enWordNormalized => $composableBuilder(
      column: $table.enWordNormalized, builder: (column) => column);

  GeneratedColumn<String> get searchKey =>
      $composableBuilder(column: $table.searchKey, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AppContentWordsTableTableManager extends RootTableManager<
    _$AppContentLocalDatabase,
    $AppContentWordsTable,
    AppContentWord,
    $$AppContentWordsTableFilterComposer,
    $$AppContentWordsTableOrderingComposer,
    $$AppContentWordsTableAnnotationComposer,
    $$AppContentWordsTableCreateCompanionBuilder,
    $$AppContentWordsTableUpdateCompanionBuilder,
    (
      AppContentWord,
      BaseReferences<_$AppContentLocalDatabase, $AppContentWordsTable,
          AppContentWord>
    ),
    AppContentWord,
    PrefetchHooks Function()> {
  $$AppContentWordsTableTableManager(
      _$AppContentLocalDatabase db, $AppContentWordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppContentWordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppContentWordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppContentWordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> packId = const Value.absent(),
            Value<String> enWord = const Value.absent(),
            Value<String> trMeaning = const Value.absent(),
            Value<String> pos = const Value.absent(),
            Value<String?> posRaw = const Value.absent(),
            Value<String> exampleEn = const Value.absent(),
            Value<String?> exampleTr = const Value.absent(),
            Value<String?> synonymsRaw = const Value.absent(),
            Value<String?> antonymsRaw = const Value.absent(),
            Value<String?> level = const Value.absent(),
            Value<String?> tagsRaw = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String> enWordNormalized = const Value.absent(),
            Value<String> searchKey = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentWordsCompanion(
            id: id,
            packId: packId,
            enWord: enWord,
            trMeaning: trMeaning,
            pos: pos,
            posRaw: posRaw,
            exampleEn: exampleEn,
            exampleTr: exampleTr,
            synonymsRaw: synonymsRaw,
            antonymsRaw: antonymsRaw,
            level: level,
            tagsRaw: tagsRaw,
            notes: notes,
            enWordNormalized: enWordNormalized,
            searchKey: searchKey,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String packId,
            required String enWord,
            required String trMeaning,
            required String pos,
            Value<String?> posRaw = const Value.absent(),
            required String exampleEn,
            Value<String?> exampleTr = const Value.absent(),
            Value<String?> synonymsRaw = const Value.absent(),
            Value<String?> antonymsRaw = const Value.absent(),
            Value<String?> level = const Value.absent(),
            Value<String?> tagsRaw = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required String enWordNormalized,
            required String searchKey,
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentWordsCompanion.insert(
            id: id,
            packId: packId,
            enWord: enWord,
            trMeaning: trMeaning,
            pos: pos,
            posRaw: posRaw,
            exampleEn: exampleEn,
            exampleTr: exampleTr,
            synonymsRaw: synonymsRaw,
            antonymsRaw: antonymsRaw,
            level: level,
            tagsRaw: tagsRaw,
            notes: notes,
            enWordNormalized: enWordNormalized,
            searchKey: searchKey,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppContentWordsTableProcessedTableManager = ProcessedTableManager<
    _$AppContentLocalDatabase,
    $AppContentWordsTable,
    AppContentWord,
    $$AppContentWordsTableFilterComposer,
    $$AppContentWordsTableOrderingComposer,
    $$AppContentWordsTableAnnotationComposer,
    $$AppContentWordsTableCreateCompanionBuilder,
    $$AppContentWordsTableUpdateCompanionBuilder,
    (
      AppContentWord,
      BaseReferences<_$AppContentLocalDatabase, $AppContentWordsTable,
          AppContentWord>
    ),
    AppContentWord,
    PrefetchHooks Function()>;
typedef $$AppContentReadingPassagesTableCreateCompanionBuilder
    = AppContentReadingPassagesCompanion Function({
  required String id,
  Value<String?> packId,
  Value<String?> packName,
  required String title,
  Value<String?> level,
  Value<String?> tagsRaw,
  Value<String?> category,
  required int createdAt,
  Value<int> rowid,
});
typedef $$AppContentReadingPassagesTableUpdateCompanionBuilder
    = AppContentReadingPassagesCompanion Function({
  Value<String> id,
  Value<String?> packId,
  Value<String?> packName,
  Value<String> title,
  Value<String?> level,
  Value<String?> tagsRaw,
  Value<String?> category,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$AppContentReadingPassagesTableFilterComposer extends Composer<
    _$AppContentLocalDatabase, $AppContentReadingPassagesTable> {
  $$AppContentReadingPassagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get packId => $composableBuilder(
      column: $table.packId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get packName => $composableBuilder(
      column: $table.packName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagsRaw => $composableBuilder(
      column: $table.tagsRaw, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AppContentReadingPassagesTableOrderingComposer extends Composer<
    _$AppContentLocalDatabase, $AppContentReadingPassagesTable> {
  $$AppContentReadingPassagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get packId => $composableBuilder(
      column: $table.packId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get packName => $composableBuilder(
      column: $table.packName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagsRaw => $composableBuilder(
      column: $table.tagsRaw, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AppContentReadingPassagesTableAnnotationComposer extends Composer<
    _$AppContentLocalDatabase, $AppContentReadingPassagesTable> {
  $$AppContentReadingPassagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get packId =>
      $composableBuilder(column: $table.packId, builder: (column) => column);

  GeneratedColumn<String> get packName =>
      $composableBuilder(column: $table.packName, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get tagsRaw =>
      $composableBuilder(column: $table.tagsRaw, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AppContentReadingPassagesTableTableManager extends RootTableManager<
    _$AppContentLocalDatabase,
    $AppContentReadingPassagesTable,
    AppContentReadingPassage,
    $$AppContentReadingPassagesTableFilterComposer,
    $$AppContentReadingPassagesTableOrderingComposer,
    $$AppContentReadingPassagesTableAnnotationComposer,
    $$AppContentReadingPassagesTableCreateCompanionBuilder,
    $$AppContentReadingPassagesTableUpdateCompanionBuilder,
    (
      AppContentReadingPassage,
      BaseReferences<_$AppContentLocalDatabase, $AppContentReadingPassagesTable,
          AppContentReadingPassage>
    ),
    AppContentReadingPassage,
    PrefetchHooks Function()> {
  $$AppContentReadingPassagesTableTableManager(
      _$AppContentLocalDatabase db, $AppContentReadingPassagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppContentReadingPassagesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$AppContentReadingPassagesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppContentReadingPassagesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> packId = const Value.absent(),
            Value<String?> packName = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> level = const Value.absent(),
            Value<String?> tagsRaw = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentReadingPassagesCompanion(
            id: id,
            packId: packId,
            packName: packName,
            title: title,
            level: level,
            tagsRaw: tagsRaw,
            category: category,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> packId = const Value.absent(),
            Value<String?> packName = const Value.absent(),
            required String title,
            Value<String?> level = const Value.absent(),
            Value<String?> tagsRaw = const Value.absent(),
            Value<String?> category = const Value.absent(),
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentReadingPassagesCompanion.insert(
            id: id,
            packId: packId,
            packName: packName,
            title: title,
            level: level,
            tagsRaw: tagsRaw,
            category: category,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppContentReadingPassagesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppContentLocalDatabase,
        $AppContentReadingPassagesTable,
        AppContentReadingPassage,
        $$AppContentReadingPassagesTableFilterComposer,
        $$AppContentReadingPassagesTableOrderingComposer,
        $$AppContentReadingPassagesTableAnnotationComposer,
        $$AppContentReadingPassagesTableCreateCompanionBuilder,
        $$AppContentReadingPassagesTableUpdateCompanionBuilder,
        (
          AppContentReadingPassage,
          BaseReferences<_$AppContentLocalDatabase,
              $AppContentReadingPassagesTable, AppContentReadingPassage>
        ),
        AppContentReadingPassage,
        PrefetchHooks Function()>;
typedef $$AppContentReadingSentencesTableCreateCompanionBuilder
    = AppContentReadingSentencesCompanion Function({
  required String id,
  required String passageId,
  required String passageTitle,
  required int idx,
  required String sentenceEn,
  Value<String?> sentenceTr,
  required int createdAt,
  Value<int> rowid,
});
typedef $$AppContentReadingSentencesTableUpdateCompanionBuilder
    = AppContentReadingSentencesCompanion Function({
  Value<String> id,
  Value<String> passageId,
  Value<String> passageTitle,
  Value<int> idx,
  Value<String> sentenceEn,
  Value<String?> sentenceTr,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$AppContentReadingSentencesTableFilterComposer extends Composer<
    _$AppContentLocalDatabase, $AppContentReadingSentencesTable> {
  $$AppContentReadingSentencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get passageId => $composableBuilder(
      column: $table.passageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get passageTitle => $composableBuilder(
      column: $table.passageTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idx => $composableBuilder(
      column: $table.idx, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sentenceEn => $composableBuilder(
      column: $table.sentenceEn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sentenceTr => $composableBuilder(
      column: $table.sentenceTr, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AppContentReadingSentencesTableOrderingComposer extends Composer<
    _$AppContentLocalDatabase, $AppContentReadingSentencesTable> {
  $$AppContentReadingSentencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get passageId => $composableBuilder(
      column: $table.passageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get passageTitle => $composableBuilder(
      column: $table.passageTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idx => $composableBuilder(
      column: $table.idx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sentenceEn => $composableBuilder(
      column: $table.sentenceEn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sentenceTr => $composableBuilder(
      column: $table.sentenceTr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AppContentReadingSentencesTableAnnotationComposer extends Composer<
    _$AppContentLocalDatabase, $AppContentReadingSentencesTable> {
  $$AppContentReadingSentencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get passageId =>
      $composableBuilder(column: $table.passageId, builder: (column) => column);

  GeneratedColumn<String> get passageTitle => $composableBuilder(
      column: $table.passageTitle, builder: (column) => column);

  GeneratedColumn<int> get idx =>
      $composableBuilder(column: $table.idx, builder: (column) => column);

  GeneratedColumn<String> get sentenceEn => $composableBuilder(
      column: $table.sentenceEn, builder: (column) => column);

  GeneratedColumn<String> get sentenceTr => $composableBuilder(
      column: $table.sentenceTr, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AppContentReadingSentencesTableTableManager extends RootTableManager<
    _$AppContentLocalDatabase,
    $AppContentReadingSentencesTable,
    AppContentReadingSentence,
    $$AppContentReadingSentencesTableFilterComposer,
    $$AppContentReadingSentencesTableOrderingComposer,
    $$AppContentReadingSentencesTableAnnotationComposer,
    $$AppContentReadingSentencesTableCreateCompanionBuilder,
    $$AppContentReadingSentencesTableUpdateCompanionBuilder,
    (
      AppContentReadingSentence,
      BaseReferences<_$AppContentLocalDatabase,
          $AppContentReadingSentencesTable, AppContentReadingSentence>
    ),
    AppContentReadingSentence,
    PrefetchHooks Function()> {
  $$AppContentReadingSentencesTableTableManager(
      _$AppContentLocalDatabase db, $AppContentReadingSentencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppContentReadingSentencesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$AppContentReadingSentencesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppContentReadingSentencesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> passageId = const Value.absent(),
            Value<String> passageTitle = const Value.absent(),
            Value<int> idx = const Value.absent(),
            Value<String> sentenceEn = const Value.absent(),
            Value<String?> sentenceTr = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentReadingSentencesCompanion(
            id: id,
            passageId: passageId,
            passageTitle: passageTitle,
            idx: idx,
            sentenceEn: sentenceEn,
            sentenceTr: sentenceTr,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String passageId,
            required String passageTitle,
            required int idx,
            required String sentenceEn,
            Value<String?> sentenceTr = const Value.absent(),
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentReadingSentencesCompanion.insert(
            id: id,
            passageId: passageId,
            passageTitle: passageTitle,
            idx: idx,
            sentenceEn: sentenceEn,
            sentenceTr: sentenceTr,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppContentReadingSentencesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppContentLocalDatabase,
        $AppContentReadingSentencesTable,
        AppContentReadingSentence,
        $$AppContentReadingSentencesTableFilterComposer,
        $$AppContentReadingSentencesTableOrderingComposer,
        $$AppContentReadingSentencesTableAnnotationComposer,
        $$AppContentReadingSentencesTableCreateCompanionBuilder,
        $$AppContentReadingSentencesTableUpdateCompanionBuilder,
        (
          AppContentReadingSentence,
          BaseReferences<_$AppContentLocalDatabase,
              $AppContentReadingSentencesTable, AppContentReadingSentence>
        ),
        AppContentReadingSentence,
        PrefetchHooks Function()>;

class $AppContentLocalDatabaseManager {
  final _$AppContentLocalDatabase _db;
  $AppContentLocalDatabaseManager(this._db);
  $$AppContentMetaTableTableManager get appContentMeta =>
      $$AppContentMetaTableTableManager(_db, _db.appContentMeta);
  $$AppContentPacksTableTableManager get appContentPacks =>
      $$AppContentPacksTableTableManager(_db, _db.appContentPacks);
  $$AppContentWordsTableTableManager get appContentWords =>
      $$AppContentWordsTableTableManager(_db, _db.appContentWords);
  $$AppContentReadingPassagesTableTableManager get appContentReadingPassages =>
      $$AppContentReadingPassagesTableTableManager(
          _db, _db.appContentReadingPassages);
  $$AppContentReadingSentencesTableTableManager
      get appContentReadingSentences =>
          $$AppContentReadingSentencesTableTableManager(
              _db, _db.appContentReadingSentences);
}
