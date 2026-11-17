// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedCategoriesTable extends CachedCategories
    with TableInfo<$CachedCategoriesTable, CachedCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lessonsCountMeta = const VerificationMeta(
    'lessonsCount',
  );
  @override
  late final GeneratedColumn<int> lessonsCount = GeneratedColumn<int>(
    'lessons_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    icon,
    sortOrder,
    lessonsCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('lessons_count')) {
      context.handle(
        _lessonsCountMeta,
        lessonsCount.isAcceptableOrUnknown(
          data['lessons_count']!,
          _lessonsCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      lessonsCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lessons_count'],
      )!,
    );
  }

  @override
  $CachedCategoriesTable createAlias(String alias) {
    return $CachedCategoriesTable(attachedDatabase, alias);
  }
}

class CachedCategory extends DataClass implements Insertable<CachedCategory> {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final int sortOrder;
  final int lessonsCount;
  const CachedCategory({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    required this.sortOrder,
    required this.lessonsCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['lessons_count'] = Variable<int>(lessonsCount);
    return map;
  }

  CachedCategoriesCompanion toCompanion(bool nullToAbsent) {
    return CachedCategoriesCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      sortOrder: Value(sortOrder),
      lessonsCount: Value(lessonsCount),
    );
  }

  factory CachedCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCategory(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      icon: serializer.fromJson<String?>(json['icon']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      lessonsCount: serializer.fromJson<int>(json['lessonsCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'icon': serializer.toJson<String?>(icon),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'lessonsCount': serializer.toJson<int>(lessonsCount),
    };
  }

  CachedCategory copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    int? sortOrder,
    int? lessonsCount,
  }) => CachedCategory(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    icon: icon.present ? icon.value : this.icon,
    sortOrder: sortOrder ?? this.sortOrder,
    lessonsCount: lessonsCount ?? this.lessonsCount,
  );
  CachedCategory copyWithCompanion(CachedCategoriesCompanion data) {
    return CachedCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      icon: data.icon.present ? data.icon.value : this.icon,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      lessonsCount: data.lessonsCount.present
          ? data.lessonsCount.value
          : this.lessonsCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCategory(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('lessonsCount: $lessonsCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, icon, sortOrder, lessonsCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCategory &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.icon == this.icon &&
          other.sortOrder == this.sortOrder &&
          other.lessonsCount == this.lessonsCount);
}

class CachedCategoriesCompanion extends UpdateCompanion<CachedCategory> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> icon;
  final Value<int> sortOrder;
  final Value<int> lessonsCount;
  final Value<int> rowid;
  const CachedCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.lessonsCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCategoriesCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.lessonsCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<CachedCategory> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? icon,
    Expression<int>? sortOrder,
    Expression<int>? lessonsCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (lessonsCount != null) 'lessons_count': lessonsCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? icon,
    Value<int>? sortOrder,
    Value<int>? lessonsCount,
    Value<int>? rowid,
  }) {
    return CachedCategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      lessonsCount: lessonsCount ?? this.lessonsCount,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (lessonsCount.present) {
      map['lessons_count'] = Variable<int>(lessonsCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('lessonsCount: $lessonsCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedLessonsTable extends CachedLessons
    with TableInfo<$CachedLessonsTable, CachedLesson> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedLessonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tempoBpmMeta = const VerificationMeta(
    'tempoBpm',
  );
  @override
  late final GeneratedColumn<int> tempoBpm = GeneratedColumn<int>(
    'tempo_bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _timeSignatureMeta = const VerificationMeta(
    'timeSignature',
  );
  @override
  late final GeneratedColumn<String> timeSignature = GeneratedColumn<String>(
    'time_signature',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keySignatureMeta = const VerificationMeta(
    'keySignature',
  );
  @override
  late final GeneratedColumn<String> keySignature = GeneratedColumn<String>(
    'key_signature',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPreviewUrlMeta = const VerificationMeta(
    'audioPreviewUrl',
  );
  @override
  late final GeneratedColumn<String> audioPreviewUrl = GeneratedColumn<String>(
    'audio_preview_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioLocalPathMeta = const VerificationMeta(
    'audioLocalPath',
  );
  @override
  late final GeneratedColumn<String> audioLocalPath = GeneratedColumn<String>(
    'audio_local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPremiumMeta = const VerificationMeta(
    'isPremium',
  );
  @override
  late final GeneratedColumn<bool> isPremium = GeneratedColumn<bool>(
    'is_premium',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_premium" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _totalPlaysMeta = const VerificationMeta(
    'totalPlays',
  );
  @override
  late final GeneratedColumn<int> totalPlays = GeneratedColumn<int>(
    'total_plays',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _averageScoreMeta = const VerificationMeta(
    'averageScore',
  );
  @override
  late final GeneratedColumn<double> averageScore = GeneratedColumn<double>(
    'average_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _categoryNameMeta = const VerificationMeta(
    'categoryName',
  );
  @override
  late final GeneratedColumn<String> categoryName = GeneratedColumn<String>(
    'category_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesCountMeta = const VerificationMeta(
    'notesCount',
  );
  @override
  late final GeneratedColumn<int> notesCount = GeneratedColumn<int>(
    'notes_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _userBestScoreMeta = const VerificationMeta(
    'userBestScore',
  );
  @override
  late final GeneratedColumn<double> userBestScore = GeneratedColumn<double>(
    'user_best_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    title,
    description,
    difficulty,
    tempoBpm,
    timeSignature,
    keySignature,
    thumbnailUrl,
    audioPreviewUrl,
    audioLocalPath,
    durationSeconds,
    sortOrder,
    isPremium,
    totalPlays,
    averageScore,
    categoryName,
    notesCount,
    userBestScore,
    downloadedAt,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_lessons';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedLesson> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('tempo_bpm')) {
      context.handle(
        _tempoBpmMeta,
        tempoBpm.isAcceptableOrUnknown(data['tempo_bpm']!, _tempoBpmMeta),
      );
    }
    if (data.containsKey('time_signature')) {
      context.handle(
        _timeSignatureMeta,
        timeSignature.isAcceptableOrUnknown(
          data['time_signature']!,
          _timeSignatureMeta,
        ),
      );
    }
    if (data.containsKey('key_signature')) {
      context.handle(
        _keySignatureMeta,
        keySignature.isAcceptableOrUnknown(
          data['key_signature']!,
          _keySignatureMeta,
        ),
      );
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('audio_preview_url')) {
      context.handle(
        _audioPreviewUrlMeta,
        audioPreviewUrl.isAcceptableOrUnknown(
          data['audio_preview_url']!,
          _audioPreviewUrlMeta,
        ),
      );
    }
    if (data.containsKey('audio_local_path')) {
      context.handle(
        _audioLocalPathMeta,
        audioLocalPath.isAcceptableOrUnknown(
          data['audio_local_path']!,
          _audioLocalPathMeta,
        ),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_premium')) {
      context.handle(
        _isPremiumMeta,
        isPremium.isAcceptableOrUnknown(data['is_premium']!, _isPremiumMeta),
      );
    }
    if (data.containsKey('total_plays')) {
      context.handle(
        _totalPlaysMeta,
        totalPlays.isAcceptableOrUnknown(data['total_plays']!, _totalPlaysMeta),
      );
    }
    if (data.containsKey('average_score')) {
      context.handle(
        _averageScoreMeta,
        averageScore.isAcceptableOrUnknown(
          data['average_score']!,
          _averageScoreMeta,
        ),
      );
    }
    if (data.containsKey('category_name')) {
      context.handle(
        _categoryNameMeta,
        categoryName.isAcceptableOrUnknown(
          data['category_name']!,
          _categoryNameMeta,
        ),
      );
    }
    if (data.containsKey('notes_count')) {
      context.handle(
        _notesCountMeta,
        notesCount.isAcceptableOrUnknown(data['notes_count']!, _notesCountMeta),
      );
    }
    if (data.containsKey('user_best_score')) {
      context.handle(
        _userBestScoreMeta,
        userBestScore.isAcceptableOrUnknown(
          data['user_best_score']!,
          _userBestScoreMeta,
        ),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedLesson map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedLesson(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty'],
      )!,
      tempoBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tempo_bpm'],
      )!,
      timeSignature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_signature'],
      ),
      keySignature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_signature'],
      ),
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      audioPreviewUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_preview_url'],
      ),
      audioLocalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_local_path'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isPremium: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_premium'],
      )!,
      totalPlays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_plays'],
      )!,
      averageScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}average_score'],
      )!,
      categoryName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_name'],
      ),
      notesCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notes_count'],
      )!,
      userBestScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}user_best_score'],
      ),
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedLessonsTable createAlias(String alias) {
    return $CachedLessonsTable(attachedDatabase, alias);
  }
}

class CachedLesson extends DataClass implements Insertable<CachedLesson> {
  final String id;
  final String categoryId;
  final String title;
  final String description;
  final String difficulty;
  final int tempoBpm;
  final String? timeSignature;
  final String? keySignature;
  final String? thumbnailUrl;
  final String? audioPreviewUrl;
  final String? audioLocalPath;
  final int? durationSeconds;
  final int sortOrder;
  final bool isPremium;
  final int totalPlays;
  final double averageScore;
  final String? categoryName;
  final int notesCount;
  final double? userBestScore;
  final DateTime? downloadedAt;
  final DateTime cachedAt;
  const CachedLesson({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.tempoBpm,
    this.timeSignature,
    this.keySignature,
    this.thumbnailUrl,
    this.audioPreviewUrl,
    this.audioLocalPath,
    this.durationSeconds,
    required this.sortOrder,
    required this.isPremium,
    required this.totalPlays,
    required this.averageScore,
    this.categoryName,
    required this.notesCount,
    this.userBestScore,
    this.downloadedAt,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['difficulty'] = Variable<String>(difficulty);
    map['tempo_bpm'] = Variable<int>(tempoBpm);
    if (!nullToAbsent || timeSignature != null) {
      map['time_signature'] = Variable<String>(timeSignature);
    }
    if (!nullToAbsent || keySignature != null) {
      map['key_signature'] = Variable<String>(keySignature);
    }
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    if (!nullToAbsent || audioPreviewUrl != null) {
      map['audio_preview_url'] = Variable<String>(audioPreviewUrl);
    }
    if (!nullToAbsent || audioLocalPath != null) {
      map['audio_local_path'] = Variable<String>(audioLocalPath);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_premium'] = Variable<bool>(isPremium);
    map['total_plays'] = Variable<int>(totalPlays);
    map['average_score'] = Variable<double>(averageScore);
    if (!nullToAbsent || categoryName != null) {
      map['category_name'] = Variable<String>(categoryName);
    }
    map['notes_count'] = Variable<int>(notesCount);
    if (!nullToAbsent || userBestScore != null) {
      map['user_best_score'] = Variable<double>(userBestScore);
    }
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedLessonsCompanion toCompanion(bool nullToAbsent) {
    return CachedLessonsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      title: Value(title),
      description: Value(description),
      difficulty: Value(difficulty),
      tempoBpm: Value(tempoBpm),
      timeSignature: timeSignature == null && nullToAbsent
          ? const Value.absent()
          : Value(timeSignature),
      keySignature: keySignature == null && nullToAbsent
          ? const Value.absent()
          : Value(keySignature),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      audioPreviewUrl: audioPreviewUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPreviewUrl),
      audioLocalPath: audioLocalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioLocalPath),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      sortOrder: Value(sortOrder),
      isPremium: Value(isPremium),
      totalPlays: Value(totalPlays),
      averageScore: Value(averageScore),
      categoryName: categoryName == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryName),
      notesCount: Value(notesCount),
      userBestScore: userBestScore == null && nullToAbsent
          ? const Value.absent()
          : Value(userBestScore),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedLesson.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedLesson(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
      tempoBpm: serializer.fromJson<int>(json['tempoBpm']),
      timeSignature: serializer.fromJson<String?>(json['timeSignature']),
      keySignature: serializer.fromJson<String?>(json['keySignature']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      audioPreviewUrl: serializer.fromJson<String?>(json['audioPreviewUrl']),
      audioLocalPath: serializer.fromJson<String?>(json['audioLocalPath']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isPremium: serializer.fromJson<bool>(json['isPremium']),
      totalPlays: serializer.fromJson<int>(json['totalPlays']),
      averageScore: serializer.fromJson<double>(json['averageScore']),
      categoryName: serializer.fromJson<String?>(json['categoryName']),
      notesCount: serializer.fromJson<int>(json['notesCount']),
      userBestScore: serializer.fromJson<double?>(json['userBestScore']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String>(categoryId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'difficulty': serializer.toJson<String>(difficulty),
      'tempoBpm': serializer.toJson<int>(tempoBpm),
      'timeSignature': serializer.toJson<String?>(timeSignature),
      'keySignature': serializer.toJson<String?>(keySignature),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'audioPreviewUrl': serializer.toJson<String?>(audioPreviewUrl),
      'audioLocalPath': serializer.toJson<String?>(audioLocalPath),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isPremium': serializer.toJson<bool>(isPremium),
      'totalPlays': serializer.toJson<int>(totalPlays),
      'averageScore': serializer.toJson<double>(averageScore),
      'categoryName': serializer.toJson<String?>(categoryName),
      'notesCount': serializer.toJson<int>(notesCount),
      'userBestScore': serializer.toJson<double?>(userBestScore),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedLesson copyWith({
    String? id,
    String? categoryId,
    String? title,
    String? description,
    String? difficulty,
    int? tempoBpm,
    Value<String?> timeSignature = const Value.absent(),
    Value<String?> keySignature = const Value.absent(),
    Value<String?> thumbnailUrl = const Value.absent(),
    Value<String?> audioPreviewUrl = const Value.absent(),
    Value<String?> audioLocalPath = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    int? sortOrder,
    bool? isPremium,
    int? totalPlays,
    double? averageScore,
    Value<String?> categoryName = const Value.absent(),
    int? notesCount,
    Value<double?> userBestScore = const Value.absent(),
    Value<DateTime?> downloadedAt = const Value.absent(),
    DateTime? cachedAt,
  }) => CachedLesson(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    title: title ?? this.title,
    description: description ?? this.description,
    difficulty: difficulty ?? this.difficulty,
    tempoBpm: tempoBpm ?? this.tempoBpm,
    timeSignature: timeSignature.present
        ? timeSignature.value
        : this.timeSignature,
    keySignature: keySignature.present ? keySignature.value : this.keySignature,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    audioPreviewUrl: audioPreviewUrl.present
        ? audioPreviewUrl.value
        : this.audioPreviewUrl,
    audioLocalPath: audioLocalPath.present
        ? audioLocalPath.value
        : this.audioLocalPath,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    sortOrder: sortOrder ?? this.sortOrder,
    isPremium: isPremium ?? this.isPremium,
    totalPlays: totalPlays ?? this.totalPlays,
    averageScore: averageScore ?? this.averageScore,
    categoryName: categoryName.present ? categoryName.value : this.categoryName,
    notesCount: notesCount ?? this.notesCount,
    userBestScore: userBestScore.present
        ? userBestScore.value
        : this.userBestScore,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedLesson copyWithCompanion(CachedLessonsCompanion data) {
    return CachedLesson(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      tempoBpm: data.tempoBpm.present ? data.tempoBpm.value : this.tempoBpm,
      timeSignature: data.timeSignature.present
          ? data.timeSignature.value
          : this.timeSignature,
      keySignature: data.keySignature.present
          ? data.keySignature.value
          : this.keySignature,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      audioPreviewUrl: data.audioPreviewUrl.present
          ? data.audioPreviewUrl.value
          : this.audioPreviewUrl,
      audioLocalPath: data.audioLocalPath.present
          ? data.audioLocalPath.value
          : this.audioLocalPath,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isPremium: data.isPremium.present ? data.isPremium.value : this.isPremium,
      totalPlays: data.totalPlays.present
          ? data.totalPlays.value
          : this.totalPlays,
      averageScore: data.averageScore.present
          ? data.averageScore.value
          : this.averageScore,
      categoryName: data.categoryName.present
          ? data.categoryName.value
          : this.categoryName,
      notesCount: data.notesCount.present
          ? data.notesCount.value
          : this.notesCount,
      userBestScore: data.userBestScore.present
          ? data.userBestScore.value
          : this.userBestScore,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedLesson(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('difficulty: $difficulty, ')
          ..write('tempoBpm: $tempoBpm, ')
          ..write('timeSignature: $timeSignature, ')
          ..write('keySignature: $keySignature, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('audioPreviewUrl: $audioPreviewUrl, ')
          ..write('audioLocalPath: $audioLocalPath, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isPremium: $isPremium, ')
          ..write('totalPlays: $totalPlays, ')
          ..write('averageScore: $averageScore, ')
          ..write('categoryName: $categoryName, ')
          ..write('notesCount: $notesCount, ')
          ..write('userBestScore: $userBestScore, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    categoryId,
    title,
    description,
    difficulty,
    tempoBpm,
    timeSignature,
    keySignature,
    thumbnailUrl,
    audioPreviewUrl,
    audioLocalPath,
    durationSeconds,
    sortOrder,
    isPremium,
    totalPlays,
    averageScore,
    categoryName,
    notesCount,
    userBestScore,
    downloadedAt,
    cachedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedLesson &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.title == this.title &&
          other.description == this.description &&
          other.difficulty == this.difficulty &&
          other.tempoBpm == this.tempoBpm &&
          other.timeSignature == this.timeSignature &&
          other.keySignature == this.keySignature &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.audioPreviewUrl == this.audioPreviewUrl &&
          other.audioLocalPath == this.audioLocalPath &&
          other.durationSeconds == this.durationSeconds &&
          other.sortOrder == this.sortOrder &&
          other.isPremium == this.isPremium &&
          other.totalPlays == this.totalPlays &&
          other.averageScore == this.averageScore &&
          other.categoryName == this.categoryName &&
          other.notesCount == this.notesCount &&
          other.userBestScore == this.userBestScore &&
          other.downloadedAt == this.downloadedAt &&
          other.cachedAt == this.cachedAt);
}

class CachedLessonsCompanion extends UpdateCompanion<CachedLesson> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> title;
  final Value<String> description;
  final Value<String> difficulty;
  final Value<int> tempoBpm;
  final Value<String?> timeSignature;
  final Value<String?> keySignature;
  final Value<String?> thumbnailUrl;
  final Value<String?> audioPreviewUrl;
  final Value<String?> audioLocalPath;
  final Value<int?> durationSeconds;
  final Value<int> sortOrder;
  final Value<bool> isPremium;
  final Value<int> totalPlays;
  final Value<double> averageScore;
  final Value<String?> categoryName;
  final Value<int> notesCount;
  final Value<double?> userBestScore;
  final Value<DateTime?> downloadedAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedLessonsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.tempoBpm = const Value.absent(),
    this.timeSignature = const Value.absent(),
    this.keySignature = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.audioPreviewUrl = const Value.absent(),
    this.audioLocalPath = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isPremium = const Value.absent(),
    this.totalPlays = const Value.absent(),
    this.averageScore = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.notesCount = const Value.absent(),
    this.userBestScore = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedLessonsCompanion.insert({
    required String id,
    required String categoryId,
    required String title,
    this.description = const Value.absent(),
    required String difficulty,
    this.tempoBpm = const Value.absent(),
    this.timeSignature = const Value.absent(),
    this.keySignature = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.audioPreviewUrl = const Value.absent(),
    this.audioLocalPath = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isPremium = const Value.absent(),
    this.totalPlays = const Value.absent(),
    this.averageScore = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.notesCount = const Value.absent(),
    this.userBestScore = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       categoryId = Value(categoryId),
       title = Value(title),
       difficulty = Value(difficulty);
  static Insertable<CachedLesson> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? difficulty,
    Expression<int>? tempoBpm,
    Expression<String>? timeSignature,
    Expression<String>? keySignature,
    Expression<String>? thumbnailUrl,
    Expression<String>? audioPreviewUrl,
    Expression<String>? audioLocalPath,
    Expression<int>? durationSeconds,
    Expression<int>? sortOrder,
    Expression<bool>? isPremium,
    Expression<int>? totalPlays,
    Expression<double>? averageScore,
    Expression<String>? categoryName,
    Expression<int>? notesCount,
    Expression<double>? userBestScore,
    Expression<DateTime>? downloadedAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (difficulty != null) 'difficulty': difficulty,
      if (tempoBpm != null) 'tempo_bpm': tempoBpm,
      if (timeSignature != null) 'time_signature': timeSignature,
      if (keySignature != null) 'key_signature': keySignature,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (audioPreviewUrl != null) 'audio_preview_url': audioPreviewUrl,
      if (audioLocalPath != null) 'audio_local_path': audioLocalPath,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isPremium != null) 'is_premium': isPremium,
      if (totalPlays != null) 'total_plays': totalPlays,
      if (averageScore != null) 'average_score': averageScore,
      if (categoryName != null) 'category_name': categoryName,
      if (notesCount != null) 'notes_count': notesCount,
      if (userBestScore != null) 'user_best_score': userBestScore,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedLessonsCompanion copyWith({
    Value<String>? id,
    Value<String>? categoryId,
    Value<String>? title,
    Value<String>? description,
    Value<String>? difficulty,
    Value<int>? tempoBpm,
    Value<String?>? timeSignature,
    Value<String?>? keySignature,
    Value<String?>? thumbnailUrl,
    Value<String?>? audioPreviewUrl,
    Value<String?>? audioLocalPath,
    Value<int?>? durationSeconds,
    Value<int>? sortOrder,
    Value<bool>? isPremium,
    Value<int>? totalPlays,
    Value<double>? averageScore,
    Value<String?>? categoryName,
    Value<int>? notesCount,
    Value<double?>? userBestScore,
    Value<DateTime?>? downloadedAt,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedLessonsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      tempoBpm: tempoBpm ?? this.tempoBpm,
      timeSignature: timeSignature ?? this.timeSignature,
      keySignature: keySignature ?? this.keySignature,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      audioPreviewUrl: audioPreviewUrl ?? this.audioPreviewUrl,
      audioLocalPath: audioLocalPath ?? this.audioLocalPath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sortOrder: sortOrder ?? this.sortOrder,
      isPremium: isPremium ?? this.isPremium,
      totalPlays: totalPlays ?? this.totalPlays,
      averageScore: averageScore ?? this.averageScore,
      categoryName: categoryName ?? this.categoryName,
      notesCount: notesCount ?? this.notesCount,
      userBestScore: userBestScore ?? this.userBestScore,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (tempoBpm.present) {
      map['tempo_bpm'] = Variable<int>(tempoBpm.value);
    }
    if (timeSignature.present) {
      map['time_signature'] = Variable<String>(timeSignature.value);
    }
    if (keySignature.present) {
      map['key_signature'] = Variable<String>(keySignature.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (audioPreviewUrl.present) {
      map['audio_preview_url'] = Variable<String>(audioPreviewUrl.value);
    }
    if (audioLocalPath.present) {
      map['audio_local_path'] = Variable<String>(audioLocalPath.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isPremium.present) {
      map['is_premium'] = Variable<bool>(isPremium.value);
    }
    if (totalPlays.present) {
      map['total_plays'] = Variable<int>(totalPlays.value);
    }
    if (averageScore.present) {
      map['average_score'] = Variable<double>(averageScore.value);
    }
    if (categoryName.present) {
      map['category_name'] = Variable<String>(categoryName.value);
    }
    if (notesCount.present) {
      map['notes_count'] = Variable<int>(notesCount.value);
    }
    if (userBestScore.present) {
      map['user_best_score'] = Variable<double>(userBestScore.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedLessonsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('difficulty: $difficulty, ')
          ..write('tempoBpm: $tempoBpm, ')
          ..write('timeSignature: $timeSignature, ')
          ..write('keySignature: $keySignature, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('audioPreviewUrl: $audioPreviewUrl, ')
          ..write('audioLocalPath: $audioLocalPath, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isPremium: $isPremium, ')
          ..write('totalPlays: $totalPlays, ')
          ..write('averageScore: $averageScore, ')
          ..write('categoryName: $categoryName, ')
          ..write('notesCount: $notesCount, ')
          ..write('userBestScore: $userBestScore, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedNotesTable extends CachedNotes
    with TableInfo<$CachedNotesTable, CachedNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<int> localId = GeneratedColumn<int>(
    'local_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<double> duration = GeneratedColumn<double>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isRestMeta = const VerificationMeta('isRest');
  @override
  late final GeneratedColumn<bool> isRest = GeneratedColumn<bool>(
    'is_rest',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_rest" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _fingerMeta = const VerificationMeta('finger');
  @override
  late final GeneratedColumn<int> finger = GeneratedColumn<int>(
    'finger',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _handMeta = const VerificationMeta('hand');
  @override
  late final GeneratedColumn<String> hand = GeneratedColumn<String>(
    'hand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _velocityMeta = const VerificationMeta(
    'velocity',
  );
  @override
  late final GeneratedColumn<int> velocity = GeneratedColumn<int>(
    'velocity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(80),
  );
  static const VerificationMeta _isChordMeta = const VerificationMeta(
    'isChord',
  );
  @override
  late final GeneratedColumn<bool> isChord = GeneratedColumn<bool>(
    'is_chord',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_chord" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _chordGroupMeta = const VerificationMeta(
    'chordGroup',
  );
  @override
  late final GeneratedColumn<int> chordGroup = GeneratedColumn<int>(
    'chord_group',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    lessonId,
    position,
    note,
    duration,
    isRest,
    finger,
    hand,
    velocity,
    isChord,
    chordGroup,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    } else if (isInserting) {
      context.missing(_noteMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('is_rest')) {
      context.handle(
        _isRestMeta,
        isRest.isAcceptableOrUnknown(data['is_rest']!, _isRestMeta),
      );
    }
    if (data.containsKey('finger')) {
      context.handle(
        _fingerMeta,
        finger.isAcceptableOrUnknown(data['finger']!, _fingerMeta),
      );
    }
    if (data.containsKey('hand')) {
      context.handle(
        _handMeta,
        hand.isAcceptableOrUnknown(data['hand']!, _handMeta),
      );
    }
    if (data.containsKey('velocity')) {
      context.handle(
        _velocityMeta,
        velocity.isAcceptableOrUnknown(data['velocity']!, _velocityMeta),
      );
    }
    if (data.containsKey('is_chord')) {
      context.handle(
        _isChordMeta,
        isChord.isAcceptableOrUnknown(data['is_chord']!, _isChordMeta),
      );
    }
    if (data.containsKey('chord_group')) {
      context.handle(
        _chordGroupMeta,
        chordGroup.isAcceptableOrUnknown(data['chord_group']!, _chordGroupMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  CachedNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedNote(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration'],
      )!,
      isRest: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_rest'],
      )!,
      finger: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finger'],
      ),
      hand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hand'],
      ),
      velocity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}velocity'],
      )!,
      isChord: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_chord'],
      )!,
      chordGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chord_group'],
      ),
    );
  }

  @override
  $CachedNotesTable createAlias(String alias) {
    return $CachedNotesTable(attachedDatabase, alias);
  }
}

class CachedNote extends DataClass implements Insertable<CachedNote> {
  final int localId;
  final String lessonId;
  final int position;
  final String note;
  final double duration;
  final bool isRest;
  final int? finger;
  final String? hand;
  final int velocity;
  final bool isChord;
  final int? chordGroup;
  const CachedNote({
    required this.localId,
    required this.lessonId,
    required this.position,
    required this.note,
    required this.duration,
    required this.isRest,
    this.finger,
    this.hand,
    required this.velocity,
    required this.isChord,
    this.chordGroup,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<int>(localId);
    map['lesson_id'] = Variable<String>(lessonId);
    map['position'] = Variable<int>(position);
    map['note'] = Variable<String>(note);
    map['duration'] = Variable<double>(duration);
    map['is_rest'] = Variable<bool>(isRest);
    if (!nullToAbsent || finger != null) {
      map['finger'] = Variable<int>(finger);
    }
    if (!nullToAbsent || hand != null) {
      map['hand'] = Variable<String>(hand);
    }
    map['velocity'] = Variable<int>(velocity);
    map['is_chord'] = Variable<bool>(isChord);
    if (!nullToAbsent || chordGroup != null) {
      map['chord_group'] = Variable<int>(chordGroup);
    }
    return map;
  }

  CachedNotesCompanion toCompanion(bool nullToAbsent) {
    return CachedNotesCompanion(
      localId: Value(localId),
      lessonId: Value(lessonId),
      position: Value(position),
      note: Value(note),
      duration: Value(duration),
      isRest: Value(isRest),
      finger: finger == null && nullToAbsent
          ? const Value.absent()
          : Value(finger),
      hand: hand == null && nullToAbsent ? const Value.absent() : Value(hand),
      velocity: Value(velocity),
      isChord: Value(isChord),
      chordGroup: chordGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(chordGroup),
    );
  }

  factory CachedNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedNote(
      localId: serializer.fromJson<int>(json['localId']),
      lessonId: serializer.fromJson<String>(json['lessonId']),
      position: serializer.fromJson<int>(json['position']),
      note: serializer.fromJson<String>(json['note']),
      duration: serializer.fromJson<double>(json['duration']),
      isRest: serializer.fromJson<bool>(json['isRest']),
      finger: serializer.fromJson<int?>(json['finger']),
      hand: serializer.fromJson<String?>(json['hand']),
      velocity: serializer.fromJson<int>(json['velocity']),
      isChord: serializer.fromJson<bool>(json['isChord']),
      chordGroup: serializer.fromJson<int?>(json['chordGroup']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<int>(localId),
      'lessonId': serializer.toJson<String>(lessonId),
      'position': serializer.toJson<int>(position),
      'note': serializer.toJson<String>(note),
      'duration': serializer.toJson<double>(duration),
      'isRest': serializer.toJson<bool>(isRest),
      'finger': serializer.toJson<int?>(finger),
      'hand': serializer.toJson<String?>(hand),
      'velocity': serializer.toJson<int>(velocity),
      'isChord': serializer.toJson<bool>(isChord),
      'chordGroup': serializer.toJson<int?>(chordGroup),
    };
  }

  CachedNote copyWith({
    int? localId,
    String? lessonId,
    int? position,
    String? note,
    double? duration,
    bool? isRest,
    Value<int?> finger = const Value.absent(),
    Value<String?> hand = const Value.absent(),
    int? velocity,
    bool? isChord,
    Value<int?> chordGroup = const Value.absent(),
  }) => CachedNote(
    localId: localId ?? this.localId,
    lessonId: lessonId ?? this.lessonId,
    position: position ?? this.position,
    note: note ?? this.note,
    duration: duration ?? this.duration,
    isRest: isRest ?? this.isRest,
    finger: finger.present ? finger.value : this.finger,
    hand: hand.present ? hand.value : this.hand,
    velocity: velocity ?? this.velocity,
    isChord: isChord ?? this.isChord,
    chordGroup: chordGroup.present ? chordGroup.value : this.chordGroup,
  );
  CachedNote copyWithCompanion(CachedNotesCompanion data) {
    return CachedNote(
      localId: data.localId.present ? data.localId.value : this.localId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      position: data.position.present ? data.position.value : this.position,
      note: data.note.present ? data.note.value : this.note,
      duration: data.duration.present ? data.duration.value : this.duration,
      isRest: data.isRest.present ? data.isRest.value : this.isRest,
      finger: data.finger.present ? data.finger.value : this.finger,
      hand: data.hand.present ? data.hand.value : this.hand,
      velocity: data.velocity.present ? data.velocity.value : this.velocity,
      isChord: data.isChord.present ? data.isChord.value : this.isChord,
      chordGroup: data.chordGroup.present
          ? data.chordGroup.value
          : this.chordGroup,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedNote(')
          ..write('localId: $localId, ')
          ..write('lessonId: $lessonId, ')
          ..write('position: $position, ')
          ..write('note: $note, ')
          ..write('duration: $duration, ')
          ..write('isRest: $isRest, ')
          ..write('finger: $finger, ')
          ..write('hand: $hand, ')
          ..write('velocity: $velocity, ')
          ..write('isChord: $isChord, ')
          ..write('chordGroup: $chordGroup')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    lessonId,
    position,
    note,
    duration,
    isRest,
    finger,
    hand,
    velocity,
    isChord,
    chordGroup,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedNote &&
          other.localId == this.localId &&
          other.lessonId == this.lessonId &&
          other.position == this.position &&
          other.note == this.note &&
          other.duration == this.duration &&
          other.isRest == this.isRest &&
          other.finger == this.finger &&
          other.hand == this.hand &&
          other.velocity == this.velocity &&
          other.isChord == this.isChord &&
          other.chordGroup == this.chordGroup);
}

class CachedNotesCompanion extends UpdateCompanion<CachedNote> {
  final Value<int> localId;
  final Value<String> lessonId;
  final Value<int> position;
  final Value<String> note;
  final Value<double> duration;
  final Value<bool> isRest;
  final Value<int?> finger;
  final Value<String?> hand;
  final Value<int> velocity;
  final Value<bool> isChord;
  final Value<int?> chordGroup;
  const CachedNotesCompanion({
    this.localId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.position = const Value.absent(),
    this.note = const Value.absent(),
    this.duration = const Value.absent(),
    this.isRest = const Value.absent(),
    this.finger = const Value.absent(),
    this.hand = const Value.absent(),
    this.velocity = const Value.absent(),
    this.isChord = const Value.absent(),
    this.chordGroup = const Value.absent(),
  });
  CachedNotesCompanion.insert({
    this.localId = const Value.absent(),
    required String lessonId,
    required int position,
    required String note,
    required double duration,
    this.isRest = const Value.absent(),
    this.finger = const Value.absent(),
    this.hand = const Value.absent(),
    this.velocity = const Value.absent(),
    this.isChord = const Value.absent(),
    this.chordGroup = const Value.absent(),
  }) : lessonId = Value(lessonId),
       position = Value(position),
       note = Value(note),
       duration = Value(duration);
  static Insertable<CachedNote> custom({
    Expression<int>? localId,
    Expression<String>? lessonId,
    Expression<int>? position,
    Expression<String>? note,
    Expression<double>? duration,
    Expression<bool>? isRest,
    Expression<int>? finger,
    Expression<String>? hand,
    Expression<int>? velocity,
    Expression<bool>? isChord,
    Expression<int>? chordGroup,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (position != null) 'position': position,
      if (note != null) 'note': note,
      if (duration != null) 'duration': duration,
      if (isRest != null) 'is_rest': isRest,
      if (finger != null) 'finger': finger,
      if (hand != null) 'hand': hand,
      if (velocity != null) 'velocity': velocity,
      if (isChord != null) 'is_chord': isChord,
      if (chordGroup != null) 'chord_group': chordGroup,
    });
  }

  CachedNotesCompanion copyWith({
    Value<int>? localId,
    Value<String>? lessonId,
    Value<int>? position,
    Value<String>? note,
    Value<double>? duration,
    Value<bool>? isRest,
    Value<int?>? finger,
    Value<String?>? hand,
    Value<int>? velocity,
    Value<bool>? isChord,
    Value<int?>? chordGroup,
  }) {
    return CachedNotesCompanion(
      localId: localId ?? this.localId,
      lessonId: lessonId ?? this.lessonId,
      position: position ?? this.position,
      note: note ?? this.note,
      duration: duration ?? this.duration,
      isRest: isRest ?? this.isRest,
      finger: finger ?? this.finger,
      hand: hand ?? this.hand,
      velocity: velocity ?? this.velocity,
      isChord: isChord ?? this.isChord,
      chordGroup: chordGroup ?? this.chordGroup,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<int>(localId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (duration.present) {
      map['duration'] = Variable<double>(duration.value);
    }
    if (isRest.present) {
      map['is_rest'] = Variable<bool>(isRest.value);
    }
    if (finger.present) {
      map['finger'] = Variable<int>(finger.value);
    }
    if (hand.present) {
      map['hand'] = Variable<String>(hand.value);
    }
    if (velocity.present) {
      map['velocity'] = Variable<int>(velocity.value);
    }
    if (isChord.present) {
      map['is_chord'] = Variable<bool>(isChord.value);
    }
    if (chordGroup.present) {
      map['chord_group'] = Variable<int>(chordGroup.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedNotesCompanion(')
          ..write('localId: $localId, ')
          ..write('lessonId: $lessonId, ')
          ..write('position: $position, ')
          ..write('note: $note, ')
          ..write('duration: $duration, ')
          ..write('isRest: $isRest, ')
          ..write('finger: $finger, ')
          ..write('hand: $hand, ')
          ..write('velocity: $velocity, ')
          ..write('isChord: $isChord, ')
          ..write('chordGroup: $chordGroup')
          ..write(')'))
        .toString();
  }
}

class $PendingPracticeTable extends PendingPractice
    with TableInfo<$PendingPracticeTable, PendingPracticeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingPracticeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<int> localId = GeneratedColumn<int>(
    'local_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctNotesMeta = const VerificationMeta(
    'correctNotes',
  );
  @override
  late final GeneratedColumn<int> correctNotes = GeneratedColumn<int>(
    'correct_notes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalNotesMeta = const VerificationMeta(
    'totalNotes',
  );
  @override
  late final GeneratedColumn<int> totalNotes = GeneratedColumn<int>(
    'total_notes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrongNotesMeta = const VerificationMeta(
    'wrongNotes',
  );
  @override
  late final GeneratedColumn<int> wrongNotes = GeneratedColumn<int>(
    'wrong_notes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missedNotesMeta = const VerificationMeta(
    'missedNotes',
  );
  @override
  late final GeneratedColumn<int> missedNotes = GeneratedColumn<int>(
    'missed_notes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _averageTempoMeta = const VerificationMeta(
    'averageTempo',
  );
  @override
  late final GeneratedColumn<double> averageTempo = GeneratedColumn<double>(
    'average_tempo',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalTimeSecondsMeta = const VerificationMeta(
    'totalTimeSeconds',
  );
  @override
  late final GeneratedColumn<double> totalTimeSeconds = GeneratedColumn<double>(
    'total_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorsDetailJsonMeta = const VerificationMeta(
    'errorsDetailJson',
  );
  @override
  late final GeneratedColumn<String> errorsDetailJson = GeneratedColumn<String>(
    'errors_detail_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    clientId,
    lessonId,
    score,
    correctNotes,
    totalNotes,
    wrongNotes,
    missedNotes,
    averageTempo,
    totalTimeSeconds,
    errorsDetailJson,
    completed,
    createdAt,
    isSynced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_practice';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingPracticeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('correct_notes')) {
      context.handle(
        _correctNotesMeta,
        correctNotes.isAcceptableOrUnknown(
          data['correct_notes']!,
          _correctNotesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctNotesMeta);
    }
    if (data.containsKey('total_notes')) {
      context.handle(
        _totalNotesMeta,
        totalNotes.isAcceptableOrUnknown(data['total_notes']!, _totalNotesMeta),
      );
    } else if (isInserting) {
      context.missing(_totalNotesMeta);
    }
    if (data.containsKey('wrong_notes')) {
      context.handle(
        _wrongNotesMeta,
        wrongNotes.isAcceptableOrUnknown(data['wrong_notes']!, _wrongNotesMeta),
      );
    } else if (isInserting) {
      context.missing(_wrongNotesMeta);
    }
    if (data.containsKey('missed_notes')) {
      context.handle(
        _missedNotesMeta,
        missedNotes.isAcceptableOrUnknown(
          data['missed_notes']!,
          _missedNotesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_missedNotesMeta);
    }
    if (data.containsKey('average_tempo')) {
      context.handle(
        _averageTempoMeta,
        averageTempo.isAcceptableOrUnknown(
          data['average_tempo']!,
          _averageTempoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_averageTempoMeta);
    }
    if (data.containsKey('total_time_seconds')) {
      context.handle(
        _totalTimeSecondsMeta,
        totalTimeSeconds.isAcceptableOrUnknown(
          data['total_time_seconds']!,
          _totalTimeSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalTimeSecondsMeta);
    }
    if (data.containsKey('errors_detail_json')) {
      context.handle(
        _errorsDetailJsonMeta,
        errorsDetailJson.isAcceptableOrUnknown(
          data['errors_detail_json']!,
          _errorsDetailJsonMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  PendingPracticeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingPracticeRow(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      correctNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_notes'],
      )!,
      totalNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_notes'],
      )!,
      wrongNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wrong_notes'],
      )!,
      missedNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}missed_notes'],
      )!,
      averageTempo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}average_tempo'],
      )!,
      totalTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_time_seconds'],
      )!,
      errorsDetailJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}errors_detail_json'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
    );
  }

  @override
  $PendingPracticeTable createAlias(String alias) {
    return $PendingPracticeTable(attachedDatabase, alias);
  }
}

class PendingPracticeRow extends DataClass
    implements Insertable<PendingPracticeRow> {
  final int localId;
  final String clientId;
  final String lessonId;
  final double score;
  final int correctNotes;
  final int totalNotes;
  final int wrongNotes;
  final int missedNotes;
  final double averageTempo;
  final double totalTimeSeconds;
  final String? errorsDetailJson;
  final bool completed;
  final DateTime createdAt;

  /// `false` mientras la práctica espera ser enviada; `true` cuando el backend
  /// ya la aceptó (la fila queda como registro local).
  final bool isSynced;
  const PendingPracticeRow({
    required this.localId,
    required this.clientId,
    required this.lessonId,
    required this.score,
    required this.correctNotes,
    required this.totalNotes,
    required this.wrongNotes,
    required this.missedNotes,
    required this.averageTempo,
    required this.totalTimeSeconds,
    this.errorsDetailJson,
    required this.completed,
    required this.createdAt,
    required this.isSynced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<int>(localId);
    map['client_id'] = Variable<String>(clientId);
    map['lesson_id'] = Variable<String>(lessonId);
    map['score'] = Variable<double>(score);
    map['correct_notes'] = Variable<int>(correctNotes);
    map['total_notes'] = Variable<int>(totalNotes);
    map['wrong_notes'] = Variable<int>(wrongNotes);
    map['missed_notes'] = Variable<int>(missedNotes);
    map['average_tempo'] = Variable<double>(averageTempo);
    map['total_time_seconds'] = Variable<double>(totalTimeSeconds);
    if (!nullToAbsent || errorsDetailJson != null) {
      map['errors_detail_json'] = Variable<String>(errorsDetailJson);
    }
    map['completed'] = Variable<bool>(completed);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  PendingPracticeCompanion toCompanion(bool nullToAbsent) {
    return PendingPracticeCompanion(
      localId: Value(localId),
      clientId: Value(clientId),
      lessonId: Value(lessonId),
      score: Value(score),
      correctNotes: Value(correctNotes),
      totalNotes: Value(totalNotes),
      wrongNotes: Value(wrongNotes),
      missedNotes: Value(missedNotes),
      averageTempo: Value(averageTempo),
      totalTimeSeconds: Value(totalTimeSeconds),
      errorsDetailJson: errorsDetailJson == null && nullToAbsent
          ? const Value.absent()
          : Value(errorsDetailJson),
      completed: Value(completed),
      createdAt: Value(createdAt),
      isSynced: Value(isSynced),
    );
  }

  factory PendingPracticeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingPracticeRow(
      localId: serializer.fromJson<int>(json['localId']),
      clientId: serializer.fromJson<String>(json['clientId']),
      lessonId: serializer.fromJson<String>(json['lessonId']),
      score: serializer.fromJson<double>(json['score']),
      correctNotes: serializer.fromJson<int>(json['correctNotes']),
      totalNotes: serializer.fromJson<int>(json['totalNotes']),
      wrongNotes: serializer.fromJson<int>(json['wrongNotes']),
      missedNotes: serializer.fromJson<int>(json['missedNotes']),
      averageTempo: serializer.fromJson<double>(json['averageTempo']),
      totalTimeSeconds: serializer.fromJson<double>(json['totalTimeSeconds']),
      errorsDetailJson: serializer.fromJson<String?>(json['errorsDetailJson']),
      completed: serializer.fromJson<bool>(json['completed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<int>(localId),
      'clientId': serializer.toJson<String>(clientId),
      'lessonId': serializer.toJson<String>(lessonId),
      'score': serializer.toJson<double>(score),
      'correctNotes': serializer.toJson<int>(correctNotes),
      'totalNotes': serializer.toJson<int>(totalNotes),
      'wrongNotes': serializer.toJson<int>(wrongNotes),
      'missedNotes': serializer.toJson<int>(missedNotes),
      'averageTempo': serializer.toJson<double>(averageTempo),
      'totalTimeSeconds': serializer.toJson<double>(totalTimeSeconds),
      'errorsDetailJson': serializer.toJson<String?>(errorsDetailJson),
      'completed': serializer.toJson<bool>(completed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  PendingPracticeRow copyWith({
    int? localId,
    String? clientId,
    String? lessonId,
    double? score,
    int? correctNotes,
    int? totalNotes,
    int? wrongNotes,
    int? missedNotes,
    double? averageTempo,
    double? totalTimeSeconds,
    Value<String?> errorsDetailJson = const Value.absent(),
    bool? completed,
    DateTime? createdAt,
    bool? isSynced,
  }) => PendingPracticeRow(
    localId: localId ?? this.localId,
    clientId: clientId ?? this.clientId,
    lessonId: lessonId ?? this.lessonId,
    score: score ?? this.score,
    correctNotes: correctNotes ?? this.correctNotes,
    totalNotes: totalNotes ?? this.totalNotes,
    wrongNotes: wrongNotes ?? this.wrongNotes,
    missedNotes: missedNotes ?? this.missedNotes,
    averageTempo: averageTempo ?? this.averageTempo,
    totalTimeSeconds: totalTimeSeconds ?? this.totalTimeSeconds,
    errorsDetailJson: errorsDetailJson.present
        ? errorsDetailJson.value
        : this.errorsDetailJson,
    completed: completed ?? this.completed,
    createdAt: createdAt ?? this.createdAt,
    isSynced: isSynced ?? this.isSynced,
  );
  PendingPracticeRow copyWithCompanion(PendingPracticeCompanion data) {
    return PendingPracticeRow(
      localId: data.localId.present ? data.localId.value : this.localId,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      score: data.score.present ? data.score.value : this.score,
      correctNotes: data.correctNotes.present
          ? data.correctNotes.value
          : this.correctNotes,
      totalNotes: data.totalNotes.present
          ? data.totalNotes.value
          : this.totalNotes,
      wrongNotes: data.wrongNotes.present
          ? data.wrongNotes.value
          : this.wrongNotes,
      missedNotes: data.missedNotes.present
          ? data.missedNotes.value
          : this.missedNotes,
      averageTempo: data.averageTempo.present
          ? data.averageTempo.value
          : this.averageTempo,
      totalTimeSeconds: data.totalTimeSeconds.present
          ? data.totalTimeSeconds.value
          : this.totalTimeSeconds,
      errorsDetailJson: data.errorsDetailJson.present
          ? data.errorsDetailJson.value
          : this.errorsDetailJson,
      completed: data.completed.present ? data.completed.value : this.completed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingPracticeRow(')
          ..write('localId: $localId, ')
          ..write('clientId: $clientId, ')
          ..write('lessonId: $lessonId, ')
          ..write('score: $score, ')
          ..write('correctNotes: $correctNotes, ')
          ..write('totalNotes: $totalNotes, ')
          ..write('wrongNotes: $wrongNotes, ')
          ..write('missedNotes: $missedNotes, ')
          ..write('averageTempo: $averageTempo, ')
          ..write('totalTimeSeconds: $totalTimeSeconds, ')
          ..write('errorsDetailJson: $errorsDetailJson, ')
          ..write('completed: $completed, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    clientId,
    lessonId,
    score,
    correctNotes,
    totalNotes,
    wrongNotes,
    missedNotes,
    averageTempo,
    totalTimeSeconds,
    errorsDetailJson,
    completed,
    createdAt,
    isSynced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingPracticeRow &&
          other.localId == this.localId &&
          other.clientId == this.clientId &&
          other.lessonId == this.lessonId &&
          other.score == this.score &&
          other.correctNotes == this.correctNotes &&
          other.totalNotes == this.totalNotes &&
          other.wrongNotes == this.wrongNotes &&
          other.missedNotes == this.missedNotes &&
          other.averageTempo == this.averageTempo &&
          other.totalTimeSeconds == this.totalTimeSeconds &&
          other.errorsDetailJson == this.errorsDetailJson &&
          other.completed == this.completed &&
          other.createdAt == this.createdAt &&
          other.isSynced == this.isSynced);
}

class PendingPracticeCompanion extends UpdateCompanion<PendingPracticeRow> {
  final Value<int> localId;
  final Value<String> clientId;
  final Value<String> lessonId;
  final Value<double> score;
  final Value<int> correctNotes;
  final Value<int> totalNotes;
  final Value<int> wrongNotes;
  final Value<int> missedNotes;
  final Value<double> averageTempo;
  final Value<double> totalTimeSeconds;
  final Value<String?> errorsDetailJson;
  final Value<bool> completed;
  final Value<DateTime> createdAt;
  final Value<bool> isSynced;
  const PendingPracticeCompanion({
    this.localId = const Value.absent(),
    this.clientId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.score = const Value.absent(),
    this.correctNotes = const Value.absent(),
    this.totalNotes = const Value.absent(),
    this.wrongNotes = const Value.absent(),
    this.missedNotes = const Value.absent(),
    this.averageTempo = const Value.absent(),
    this.totalTimeSeconds = const Value.absent(),
    this.errorsDetailJson = const Value.absent(),
    this.completed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isSynced = const Value.absent(),
  });
  PendingPracticeCompanion.insert({
    this.localId = const Value.absent(),
    required String clientId,
    required String lessonId,
    required double score,
    required int correctNotes,
    required int totalNotes,
    required int wrongNotes,
    required int missedNotes,
    required double averageTempo,
    required double totalTimeSeconds,
    this.errorsDetailJson = const Value.absent(),
    this.completed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isSynced = const Value.absent(),
  }) : clientId = Value(clientId),
       lessonId = Value(lessonId),
       score = Value(score),
       correctNotes = Value(correctNotes),
       totalNotes = Value(totalNotes),
       wrongNotes = Value(wrongNotes),
       missedNotes = Value(missedNotes),
       averageTempo = Value(averageTempo),
       totalTimeSeconds = Value(totalTimeSeconds);
  static Insertable<PendingPracticeRow> custom({
    Expression<int>? localId,
    Expression<String>? clientId,
    Expression<String>? lessonId,
    Expression<double>? score,
    Expression<int>? correctNotes,
    Expression<int>? totalNotes,
    Expression<int>? wrongNotes,
    Expression<int>? missedNotes,
    Expression<double>? averageTempo,
    Expression<double>? totalTimeSeconds,
    Expression<String>? errorsDetailJson,
    Expression<bool>? completed,
    Expression<DateTime>? createdAt,
    Expression<bool>? isSynced,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (clientId != null) 'client_id': clientId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (score != null) 'score': score,
      if (correctNotes != null) 'correct_notes': correctNotes,
      if (totalNotes != null) 'total_notes': totalNotes,
      if (wrongNotes != null) 'wrong_notes': wrongNotes,
      if (missedNotes != null) 'missed_notes': missedNotes,
      if (averageTempo != null) 'average_tempo': averageTempo,
      if (totalTimeSeconds != null) 'total_time_seconds': totalTimeSeconds,
      if (errorsDetailJson != null) 'errors_detail_json': errorsDetailJson,
      if (completed != null) 'completed': completed,
      if (createdAt != null) 'created_at': createdAt,
      if (isSynced != null) 'is_synced': isSynced,
    });
  }

  PendingPracticeCompanion copyWith({
    Value<int>? localId,
    Value<String>? clientId,
    Value<String>? lessonId,
    Value<double>? score,
    Value<int>? correctNotes,
    Value<int>? totalNotes,
    Value<int>? wrongNotes,
    Value<int>? missedNotes,
    Value<double>? averageTempo,
    Value<double>? totalTimeSeconds,
    Value<String?>? errorsDetailJson,
    Value<bool>? completed,
    Value<DateTime>? createdAt,
    Value<bool>? isSynced,
  }) {
    return PendingPracticeCompanion(
      localId: localId ?? this.localId,
      clientId: clientId ?? this.clientId,
      lessonId: lessonId ?? this.lessonId,
      score: score ?? this.score,
      correctNotes: correctNotes ?? this.correctNotes,
      totalNotes: totalNotes ?? this.totalNotes,
      wrongNotes: wrongNotes ?? this.wrongNotes,
      missedNotes: missedNotes ?? this.missedNotes,
      averageTempo: averageTempo ?? this.averageTempo,
      totalTimeSeconds: totalTimeSeconds ?? this.totalTimeSeconds,
      errorsDetailJson: errorsDetailJson ?? this.errorsDetailJson,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<int>(localId.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (correctNotes.present) {
      map['correct_notes'] = Variable<int>(correctNotes.value);
    }
    if (totalNotes.present) {
      map['total_notes'] = Variable<int>(totalNotes.value);
    }
    if (wrongNotes.present) {
      map['wrong_notes'] = Variable<int>(wrongNotes.value);
    }
    if (missedNotes.present) {
      map['missed_notes'] = Variable<int>(missedNotes.value);
    }
    if (averageTempo.present) {
      map['average_tempo'] = Variable<double>(averageTempo.value);
    }
    if (totalTimeSeconds.present) {
      map['total_time_seconds'] = Variable<double>(totalTimeSeconds.value);
    }
    if (errorsDetailJson.present) {
      map['errors_detail_json'] = Variable<String>(errorsDetailJson.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingPracticeCompanion(')
          ..write('localId: $localId, ')
          ..write('clientId: $clientId, ')
          ..write('lessonId: $lessonId, ')
          ..write('score: $score, ')
          ..write('correctNotes: $correctNotes, ')
          ..write('totalNotes: $totalNotes, ')
          ..write('wrongNotes: $wrongNotes, ')
          ..write('missedNotes: $missedNotes, ')
          ..write('averageTempo: $averageTempo, ')
          ..write('totalTimeSeconds: $totalTimeSeconds, ')
          ..write('errorsDetailJson: $errorsDetailJson, ')
          ..write('completed: $completed, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }
}

class $CachedSnapshotsTable extends CachedSnapshots
    with TableInfo<$CachedSnapshotsTable, CachedSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CachedSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSnapshot(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedSnapshotsTable createAlias(String alias) {
    return $CachedSnapshotsTable(attachedDatabase, alias);
  }
}

class CachedSnapshot extends DataClass implements Insertable<CachedSnapshot> {
  final String key;
  final String json;
  final DateTime updatedAt;
  const CachedSnapshot({
    required this.key,
    required this.json,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return CachedSnapshotsCompanion(
      key: Value(key),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSnapshot(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedSnapshot copyWith({String? key, String? json, DateTime? updatedAt}) =>
      CachedSnapshot(
        key: key ?? this.key,
        json: json ?? this.json,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CachedSnapshot copyWithCompanion(CachedSnapshotsCompanion data) {
    return CachedSnapshot(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSnapshot(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSnapshot &&
          other.key == this.key &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class CachedSnapshotsCompanion extends UpdateCompanion<CachedSnapshot> {
  final Value<String> key;
  final Value<String> json;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedSnapshotsCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedSnapshotsCompanion.insert({
    required String key,
    required String json,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       json = Value(json);
  static Insertable<CachedSnapshot> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedSnapshotsCompanion copyWith({
    Value<String>? key,
    Value<String>? json,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedSnapshotsCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
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
    return (StringBuffer('CachedSnapshotsCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedCategoriesTable cachedCategories = $CachedCategoriesTable(
    this,
  );
  late final $CachedLessonsTable cachedLessons = $CachedLessonsTable(this);
  late final $CachedNotesTable cachedNotes = $CachedNotesTable(this);
  late final $PendingPracticeTable pendingPractice = $PendingPracticeTable(
    this,
  );
  late final $CachedSnapshotsTable cachedSnapshots = $CachedSnapshotsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedCategories,
    cachedLessons,
    cachedNotes,
    pendingPractice,
    cachedSnapshots,
  ];
}

typedef $$CachedCategoriesTableCreateCompanionBuilder =
    CachedCategoriesCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      Value<String?> icon,
      Value<int> sortOrder,
      Value<int> lessonsCount,
      Value<int> rowid,
    });
typedef $$CachedCategoriesTableUpdateCompanionBuilder =
    CachedCategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<String?> icon,
      Value<int> sortOrder,
      Value<int> lessonsCount,
      Value<int> rowid,
    });

class $$CachedCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonsCount => $composableBuilder(
    column: $table.lessonsCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonsCount => $composableBuilder(
    column: $table.lessonsCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get lessonsCount => $composableBuilder(
    column: $table.lessonsCount,
    builder: (column) => column,
  );
}

class $$CachedCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCategoriesTable,
          CachedCategory,
          $$CachedCategoriesTableFilterComposer,
          $$CachedCategoriesTableOrderingComposer,
          $$CachedCategoriesTableAnnotationComposer,
          $$CachedCategoriesTableCreateCompanionBuilder,
          $$CachedCategoriesTableUpdateCompanionBuilder,
          (
            CachedCategory,
            BaseReferences<
              _$AppDatabase,
              $CachedCategoriesTable,
              CachedCategory
            >,
          ),
          CachedCategory,
          PrefetchHooks Function()
        > {
  $$CachedCategoriesTableTableManager(
    _$AppDatabase db,
    $CachedCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> lessonsCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCategoriesCompanion(
                id: id,
                name: name,
                description: description,
                icon: icon,
                sortOrder: sortOrder,
                lessonsCount: lessonsCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> lessonsCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCategoriesCompanion.insert(
                id: id,
                name: name,
                description: description,
                icon: icon,
                sortOrder: sortOrder,
                lessonsCount: lessonsCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCategoriesTable,
      CachedCategory,
      $$CachedCategoriesTableFilterComposer,
      $$CachedCategoriesTableOrderingComposer,
      $$CachedCategoriesTableAnnotationComposer,
      $$CachedCategoriesTableCreateCompanionBuilder,
      $$CachedCategoriesTableUpdateCompanionBuilder,
      (
        CachedCategory,
        BaseReferences<_$AppDatabase, $CachedCategoriesTable, CachedCategory>,
      ),
      CachedCategory,
      PrefetchHooks Function()
    >;
typedef $$CachedLessonsTableCreateCompanionBuilder =
    CachedLessonsCompanion Function({
      required String id,
      required String categoryId,
      required String title,
      Value<String> description,
      required String difficulty,
      Value<int> tempoBpm,
      Value<String?> timeSignature,
      Value<String?> keySignature,
      Value<String?> thumbnailUrl,
      Value<String?> audioPreviewUrl,
      Value<String?> audioLocalPath,
      Value<int?> durationSeconds,
      Value<int> sortOrder,
      Value<bool> isPremium,
      Value<int> totalPlays,
      Value<double> averageScore,
      Value<String?> categoryName,
      Value<int> notesCount,
      Value<double?> userBestScore,
      Value<DateTime?> downloadedAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });
typedef $$CachedLessonsTableUpdateCompanionBuilder =
    CachedLessonsCompanion Function({
      Value<String> id,
      Value<String> categoryId,
      Value<String> title,
      Value<String> description,
      Value<String> difficulty,
      Value<int> tempoBpm,
      Value<String?> timeSignature,
      Value<String?> keySignature,
      Value<String?> thumbnailUrl,
      Value<String?> audioPreviewUrl,
      Value<String?> audioLocalPath,
      Value<int?> durationSeconds,
      Value<int> sortOrder,
      Value<bool> isPremium,
      Value<int> totalPlays,
      Value<double> averageScore,
      Value<String?> categoryName,
      Value<int> notesCount,
      Value<double?> userBestScore,
      Value<DateTime?> downloadedAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedLessonsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedLessonsTable> {
  $$CachedLessonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tempoBpm => $composableBuilder(
    column: $table.tempoBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeSignature => $composableBuilder(
    column: $table.timeSignature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keySignature => $composableBuilder(
    column: $table.keySignature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPreviewUrl => $composableBuilder(
    column: $table.audioPreviewUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioLocalPath => $composableBuilder(
    column: $table.audioLocalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPremium => $composableBuilder(
    column: $table.isPremium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPlays => $composableBuilder(
    column: $table.totalPlays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get averageScore => $composableBuilder(
    column: $table.averageScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notesCount => $composableBuilder(
    column: $table.notesCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get userBestScore => $composableBuilder(
    column: $table.userBestScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedLessonsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedLessonsTable> {
  $$CachedLessonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tempoBpm => $composableBuilder(
    column: $table.tempoBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeSignature => $composableBuilder(
    column: $table.timeSignature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keySignature => $composableBuilder(
    column: $table.keySignature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPreviewUrl => $composableBuilder(
    column: $table.audioPreviewUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioLocalPath => $composableBuilder(
    column: $table.audioLocalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPremium => $composableBuilder(
    column: $table.isPremium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPlays => $composableBuilder(
    column: $table.totalPlays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get averageScore => $composableBuilder(
    column: $table.averageScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notesCount => $composableBuilder(
    column: $table.notesCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get userBestScore => $composableBuilder(
    column: $table.userBestScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedLessonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedLessonsTable> {
  $$CachedLessonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tempoBpm =>
      $composableBuilder(column: $table.tempoBpm, builder: (column) => column);

  GeneratedColumn<String> get timeSignature => $composableBuilder(
    column: $table.timeSignature,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keySignature => $composableBuilder(
    column: $table.keySignature,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioPreviewUrl => $composableBuilder(
    column: $table.audioPreviewUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioLocalPath => $composableBuilder(
    column: $table.audioLocalPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isPremium =>
      $composableBuilder(column: $table.isPremium, builder: (column) => column);

  GeneratedColumn<int> get totalPlays => $composableBuilder(
    column: $table.totalPlays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get averageScore => $composableBuilder(
    column: $table.averageScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notesCount => $composableBuilder(
    column: $table.notesCount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get userBestScore => $composableBuilder(
    column: $table.userBestScore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedLessonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedLessonsTable,
          CachedLesson,
          $$CachedLessonsTableFilterComposer,
          $$CachedLessonsTableOrderingComposer,
          $$CachedLessonsTableAnnotationComposer,
          $$CachedLessonsTableCreateCompanionBuilder,
          $$CachedLessonsTableUpdateCompanionBuilder,
          (
            CachedLesson,
            BaseReferences<_$AppDatabase, $CachedLessonsTable, CachedLesson>,
          ),
          CachedLesson,
          PrefetchHooks Function()
        > {
  $$CachedLessonsTableTableManager(_$AppDatabase db, $CachedLessonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedLessonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedLessonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedLessonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> difficulty = const Value.absent(),
                Value<int> tempoBpm = const Value.absent(),
                Value<String?> timeSignature = const Value.absent(),
                Value<String?> keySignature = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> audioPreviewUrl = const Value.absent(),
                Value<String?> audioLocalPath = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isPremium = const Value.absent(),
                Value<int> totalPlays = const Value.absent(),
                Value<double> averageScore = const Value.absent(),
                Value<String?> categoryName = const Value.absent(),
                Value<int> notesCount = const Value.absent(),
                Value<double?> userBestScore = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedLessonsCompanion(
                id: id,
                categoryId: categoryId,
                title: title,
                description: description,
                difficulty: difficulty,
                tempoBpm: tempoBpm,
                timeSignature: timeSignature,
                keySignature: keySignature,
                thumbnailUrl: thumbnailUrl,
                audioPreviewUrl: audioPreviewUrl,
                audioLocalPath: audioLocalPath,
                durationSeconds: durationSeconds,
                sortOrder: sortOrder,
                isPremium: isPremium,
                totalPlays: totalPlays,
                averageScore: averageScore,
                categoryName: categoryName,
                notesCount: notesCount,
                userBestScore: userBestScore,
                downloadedAt: downloadedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String categoryId,
                required String title,
                Value<String> description = const Value.absent(),
                required String difficulty,
                Value<int> tempoBpm = const Value.absent(),
                Value<String?> timeSignature = const Value.absent(),
                Value<String?> keySignature = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> audioPreviewUrl = const Value.absent(),
                Value<String?> audioLocalPath = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isPremium = const Value.absent(),
                Value<int> totalPlays = const Value.absent(),
                Value<double> averageScore = const Value.absent(),
                Value<String?> categoryName = const Value.absent(),
                Value<int> notesCount = const Value.absent(),
                Value<double?> userBestScore = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedLessonsCompanion.insert(
                id: id,
                categoryId: categoryId,
                title: title,
                description: description,
                difficulty: difficulty,
                tempoBpm: tempoBpm,
                timeSignature: timeSignature,
                keySignature: keySignature,
                thumbnailUrl: thumbnailUrl,
                audioPreviewUrl: audioPreviewUrl,
                audioLocalPath: audioLocalPath,
                durationSeconds: durationSeconds,
                sortOrder: sortOrder,
                isPremium: isPremium,
                totalPlays: totalPlays,
                averageScore: averageScore,
                categoryName: categoryName,
                notesCount: notesCount,
                userBestScore: userBestScore,
                downloadedAt: downloadedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedLessonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedLessonsTable,
      CachedLesson,
      $$CachedLessonsTableFilterComposer,
      $$CachedLessonsTableOrderingComposer,
      $$CachedLessonsTableAnnotationComposer,
      $$CachedLessonsTableCreateCompanionBuilder,
      $$CachedLessonsTableUpdateCompanionBuilder,
      (
        CachedLesson,
        BaseReferences<_$AppDatabase, $CachedLessonsTable, CachedLesson>,
      ),
      CachedLesson,
      PrefetchHooks Function()
    >;
typedef $$CachedNotesTableCreateCompanionBuilder =
    CachedNotesCompanion Function({
      Value<int> localId,
      required String lessonId,
      required int position,
      required String note,
      required double duration,
      Value<bool> isRest,
      Value<int?> finger,
      Value<String?> hand,
      Value<int> velocity,
      Value<bool> isChord,
      Value<int?> chordGroup,
    });
typedef $$CachedNotesTableUpdateCompanionBuilder =
    CachedNotesCompanion Function({
      Value<int> localId,
      Value<String> lessonId,
      Value<int> position,
      Value<String> note,
      Value<double> duration,
      Value<bool> isRest,
      Value<int?> finger,
      Value<String?> hand,
      Value<int> velocity,
      Value<bool> isChord,
      Value<int?> chordGroup,
    });

class $$CachedNotesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedNotesTable> {
  $$CachedNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRest => $composableBuilder(
    column: $table.isRest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finger => $composableBuilder(
    column: $table.finger,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hand => $composableBuilder(
    column: $table.hand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get velocity => $composableBuilder(
    column: $table.velocity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isChord => $composableBuilder(
    column: $table.isChord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chordGroup => $composableBuilder(
    column: $table.chordGroup,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedNotesTable> {
  $$CachedNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRest => $composableBuilder(
    column: $table.isRest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finger => $composableBuilder(
    column: $table.finger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hand => $composableBuilder(
    column: $table.hand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get velocity => $composableBuilder(
    column: $table.velocity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isChord => $composableBuilder(
    column: $table.isChord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chordGroup => $composableBuilder(
    column: $table.chordGroup,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedNotesTable> {
  $$CachedNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<double> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<bool> get isRest =>
      $composableBuilder(column: $table.isRest, builder: (column) => column);

  GeneratedColumn<int> get finger =>
      $composableBuilder(column: $table.finger, builder: (column) => column);

  GeneratedColumn<String> get hand =>
      $composableBuilder(column: $table.hand, builder: (column) => column);

  GeneratedColumn<int> get velocity =>
      $composableBuilder(column: $table.velocity, builder: (column) => column);

  GeneratedColumn<bool> get isChord =>
      $composableBuilder(column: $table.isChord, builder: (column) => column);

  GeneratedColumn<int> get chordGroup => $composableBuilder(
    column: $table.chordGroup,
    builder: (column) => column,
  );
}

class $$CachedNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedNotesTable,
          CachedNote,
          $$CachedNotesTableFilterComposer,
          $$CachedNotesTableOrderingComposer,
          $$CachedNotesTableAnnotationComposer,
          $$CachedNotesTableCreateCompanionBuilder,
          $$CachedNotesTableUpdateCompanionBuilder,
          (
            CachedNote,
            BaseReferences<_$AppDatabase, $CachedNotesTable, CachedNote>,
          ),
          CachedNote,
          PrefetchHooks Function()
        > {
  $$CachedNotesTableTableManager(_$AppDatabase db, $CachedNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                Value<String> lessonId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<double> duration = const Value.absent(),
                Value<bool> isRest = const Value.absent(),
                Value<int?> finger = const Value.absent(),
                Value<String?> hand = const Value.absent(),
                Value<int> velocity = const Value.absent(),
                Value<bool> isChord = const Value.absent(),
                Value<int?> chordGroup = const Value.absent(),
              }) => CachedNotesCompanion(
                localId: localId,
                lessonId: lessonId,
                position: position,
                note: note,
                duration: duration,
                isRest: isRest,
                finger: finger,
                hand: hand,
                velocity: velocity,
                isChord: isChord,
                chordGroup: chordGroup,
              ),
          createCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                required String lessonId,
                required int position,
                required String note,
                required double duration,
                Value<bool> isRest = const Value.absent(),
                Value<int?> finger = const Value.absent(),
                Value<String?> hand = const Value.absent(),
                Value<int> velocity = const Value.absent(),
                Value<bool> isChord = const Value.absent(),
                Value<int?> chordGroup = const Value.absent(),
              }) => CachedNotesCompanion.insert(
                localId: localId,
                lessonId: lessonId,
                position: position,
                note: note,
                duration: duration,
                isRest: isRest,
                finger: finger,
                hand: hand,
                velocity: velocity,
                isChord: isChord,
                chordGroup: chordGroup,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedNotesTable,
      CachedNote,
      $$CachedNotesTableFilterComposer,
      $$CachedNotesTableOrderingComposer,
      $$CachedNotesTableAnnotationComposer,
      $$CachedNotesTableCreateCompanionBuilder,
      $$CachedNotesTableUpdateCompanionBuilder,
      (
        CachedNote,
        BaseReferences<_$AppDatabase, $CachedNotesTable, CachedNote>,
      ),
      CachedNote,
      PrefetchHooks Function()
    >;
typedef $$PendingPracticeTableCreateCompanionBuilder =
    PendingPracticeCompanion Function({
      Value<int> localId,
      required String clientId,
      required String lessonId,
      required double score,
      required int correctNotes,
      required int totalNotes,
      required int wrongNotes,
      required int missedNotes,
      required double averageTempo,
      required double totalTimeSeconds,
      Value<String?> errorsDetailJson,
      Value<bool> completed,
      Value<DateTime> createdAt,
      Value<bool> isSynced,
    });
typedef $$PendingPracticeTableUpdateCompanionBuilder =
    PendingPracticeCompanion Function({
      Value<int> localId,
      Value<String> clientId,
      Value<String> lessonId,
      Value<double> score,
      Value<int> correctNotes,
      Value<int> totalNotes,
      Value<int> wrongNotes,
      Value<int> missedNotes,
      Value<double> averageTempo,
      Value<double> totalTimeSeconds,
      Value<String?> errorsDetailJson,
      Value<bool> completed,
      Value<DateTime> createdAt,
      Value<bool> isSynced,
    });

class $$PendingPracticeTableFilterComposer
    extends Composer<_$AppDatabase, $PendingPracticeTable> {
  $$PendingPracticeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctNotes => $composableBuilder(
    column: $table.correctNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalNotes => $composableBuilder(
    column: $table.totalNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wrongNotes => $composableBuilder(
    column: $table.wrongNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get missedNotes => $composableBuilder(
    column: $table.missedNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get averageTempo => $composableBuilder(
    column: $table.averageTempo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalTimeSeconds => $composableBuilder(
    column: $table.totalTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorsDetailJson => $composableBuilder(
    column: $table.errorsDetailJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingPracticeTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingPracticeTable> {
  $$PendingPracticeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctNotes => $composableBuilder(
    column: $table.correctNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalNotes => $composableBuilder(
    column: $table.totalNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wrongNotes => $composableBuilder(
    column: $table.wrongNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get missedNotes => $composableBuilder(
    column: $table.missedNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get averageTempo => $composableBuilder(
    column: $table.averageTempo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalTimeSeconds => $composableBuilder(
    column: $table.totalTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorsDetailJson => $composableBuilder(
    column: $table.errorsDetailJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingPracticeTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingPracticeTable> {
  $$PendingPracticeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get correctNotes => $composableBuilder(
    column: $table.correctNotes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalNotes => $composableBuilder(
    column: $table.totalNotes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wrongNotes => $composableBuilder(
    column: $table.wrongNotes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get missedNotes => $composableBuilder(
    column: $table.missedNotes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get averageTempo => $composableBuilder(
    column: $table.averageTempo,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalTimeSeconds => $composableBuilder(
    column: $table.totalTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorsDetailJson => $composableBuilder(
    column: $table.errorsDetailJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);
}

class $$PendingPracticeTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingPracticeTable,
          PendingPracticeRow,
          $$PendingPracticeTableFilterComposer,
          $$PendingPracticeTableOrderingComposer,
          $$PendingPracticeTableAnnotationComposer,
          $$PendingPracticeTableCreateCompanionBuilder,
          $$PendingPracticeTableUpdateCompanionBuilder,
          (
            PendingPracticeRow,
            BaseReferences<
              _$AppDatabase,
              $PendingPracticeTable,
              PendingPracticeRow
            >,
          ),
          PendingPracticeRow,
          PrefetchHooks Function()
        > {
  $$PendingPracticeTableTableManager(
    _$AppDatabase db,
    $PendingPracticeTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingPracticeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingPracticeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingPracticeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> lessonId = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<int> correctNotes = const Value.absent(),
                Value<int> totalNotes = const Value.absent(),
                Value<int> wrongNotes = const Value.absent(),
                Value<int> missedNotes = const Value.absent(),
                Value<double> averageTempo = const Value.absent(),
                Value<double> totalTimeSeconds = const Value.absent(),
                Value<String?> errorsDetailJson = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
              }) => PendingPracticeCompanion(
                localId: localId,
                clientId: clientId,
                lessonId: lessonId,
                score: score,
                correctNotes: correctNotes,
                totalNotes: totalNotes,
                wrongNotes: wrongNotes,
                missedNotes: missedNotes,
                averageTempo: averageTempo,
                totalTimeSeconds: totalTimeSeconds,
                errorsDetailJson: errorsDetailJson,
                completed: completed,
                createdAt: createdAt,
                isSynced: isSynced,
              ),
          createCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                required String clientId,
                required String lessonId,
                required double score,
                required int correctNotes,
                required int totalNotes,
                required int wrongNotes,
                required int missedNotes,
                required double averageTempo,
                required double totalTimeSeconds,
                Value<String?> errorsDetailJson = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
              }) => PendingPracticeCompanion.insert(
                localId: localId,
                clientId: clientId,
                lessonId: lessonId,
                score: score,
                correctNotes: correctNotes,
                totalNotes: totalNotes,
                wrongNotes: wrongNotes,
                missedNotes: missedNotes,
                averageTempo: averageTempo,
                totalTimeSeconds: totalTimeSeconds,
                errorsDetailJson: errorsDetailJson,
                completed: completed,
                createdAt: createdAt,
                isSynced: isSynced,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingPracticeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingPracticeTable,
      PendingPracticeRow,
      $$PendingPracticeTableFilterComposer,
      $$PendingPracticeTableOrderingComposer,
      $$PendingPracticeTableAnnotationComposer,
      $$PendingPracticeTableCreateCompanionBuilder,
      $$PendingPracticeTableUpdateCompanionBuilder,
      (
        PendingPracticeRow,
        BaseReferences<
          _$AppDatabase,
          $PendingPracticeTable,
          PendingPracticeRow
        >,
      ),
      PendingPracticeRow,
      PrefetchHooks Function()
    >;
typedef $$CachedSnapshotsTableCreateCompanionBuilder =
    CachedSnapshotsCompanion Function({
      required String key,
      required String json,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CachedSnapshotsTableUpdateCompanionBuilder =
    CachedSnapshotsCompanion Function({
      Value<String> key,
      Value<String> json,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CachedSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedSnapshotsTable> {
  $$CachedSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedSnapshotsTable> {
  $$CachedSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedSnapshotsTable> {
  $$CachedSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedSnapshotsTable,
          CachedSnapshot,
          $$CachedSnapshotsTableFilterComposer,
          $$CachedSnapshotsTableOrderingComposer,
          $$CachedSnapshotsTableAnnotationComposer,
          $$CachedSnapshotsTableCreateCompanionBuilder,
          $$CachedSnapshotsTableUpdateCompanionBuilder,
          (
            CachedSnapshot,
            BaseReferences<
              _$AppDatabase,
              $CachedSnapshotsTable,
              CachedSnapshot
            >,
          ),
          CachedSnapshot,
          PrefetchHooks Function()
        > {
  $$CachedSnapshotsTableTableManager(
    _$AppDatabase db,
    $CachedSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSnapshotsCompanion(
                key: key,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String json,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSnapshotsCompanion.insert(
                key: key,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedSnapshotsTable,
      CachedSnapshot,
      $$CachedSnapshotsTableFilterComposer,
      $$CachedSnapshotsTableOrderingComposer,
      $$CachedSnapshotsTableAnnotationComposer,
      $$CachedSnapshotsTableCreateCompanionBuilder,
      $$CachedSnapshotsTableUpdateCompanionBuilder,
      (
        CachedSnapshot,
        BaseReferences<_$AppDatabase, $CachedSnapshotsTable, CachedSnapshot>,
      ),
      CachedSnapshot,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedCategoriesTableTableManager get cachedCategories =>
      $$CachedCategoriesTableTableManager(_db, _db.cachedCategories);
  $$CachedLessonsTableTableManager get cachedLessons =>
      $$CachedLessonsTableTableManager(_db, _db.cachedLessons);
  $$CachedNotesTableTableManager get cachedNotes =>
      $$CachedNotesTableTableManager(_db, _db.cachedNotes);
  $$PendingPracticeTableTableManager get pendingPractice =>
      $$PendingPracticeTableTableManager(_db, _db.pendingPractice);
  $$CachedSnapshotsTableTableManager get cachedSnapshots =>
      $$CachedSnapshotsTableTableManager(_db, _db.cachedSnapshots);
}
