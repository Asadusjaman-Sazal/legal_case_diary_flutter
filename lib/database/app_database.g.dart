// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CourtCategoriesTable extends CourtCategories
    with TableInfo<$CourtCategoriesTable, CourtCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CourtCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameKeyMeta = const VerificationMeta(
    'nameKey',
  );
  @override
  late final GeneratedColumn<String> nameKey = GeneratedColumn<String>(
    'name_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courtLevelMeta = const VerificationMeta(
    'courtLevel',
  );
  @override
  late final GeneratedColumn<String> courtLevel = GeneratedColumn<String>(
    'court_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _divisionMeta = const VerificationMeta(
    'division',
  );
  @override
  late final GeneratedColumn<String> division = GeneratedColumn<String>(
    'division',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _districtMeta = const VerificationMeta(
    'district',
  );
  @override
  late final GeneratedColumn<String> district = GeneratedColumn<String>(
    'district',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isUserModifiedMeta = const VerificationMeta(
    'isUserModified',
  );
  @override
  late final GeneratedColumn<bool> isUserModified = GeneratedColumn<bool>(
    'is_user_modified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_user_modified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nameKey,
    courtLevel,
    orderIndex,
    division,
    district,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'court_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CourtCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name_key')) {
      context.handle(
        _nameKeyMeta,
        nameKey.isAcceptableOrUnknown(data['name_key']!, _nameKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_nameKeyMeta);
    }
    if (data.containsKey('court_level')) {
      context.handle(
        _courtLevelMeta,
        courtLevel.isAcceptableOrUnknown(data['court_level']!, _courtLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_courtLevelMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('division')) {
      context.handle(
        _divisionMeta,
        division.isAcceptableOrUnknown(data['division']!, _divisionMeta),
      );
    }
    if (data.containsKey('district')) {
      context.handle(
        _districtMeta,
        district.isAcceptableOrUnknown(data['district']!, _districtMeta),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('is_user_modified')) {
      context.handle(
        _isUserModifiedMeta,
        isUserModified.isAcceptableOrUnknown(
          data['is_user_modified']!,
          _isUserModifiedMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CourtCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CourtCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nameKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_key'],
      )!,
      courtLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}court_level'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      division: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}division'],
      ),
      district: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}district'],
      ),
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      isUserModified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_user_modified'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $CourtCategoriesTable createAlias(String alias) {
    return $CourtCategoriesTable(attachedDatabase, alias);
  }
}

class CourtCategory extends DataClass implements Insertable<CourtCategory> {
  /// Stable machine key (e.g. `appellate_division`).
  final String id;

  /// Localization key resolved through app translations.
  final String nameKey;

  /// `appellate`, `high_court`, or `lower`.
  final String courtLevel;

  /// Canonical display order.
  final int orderIndex;

  /// Bangladesh division for user-created lower-court categories; null for
  /// built-in categories, which are global. A category added inside a district
  /// is scoped to that division + district only.
  final String? division;

  /// Bangladesh district for user-created lower-court categories; null for
  /// built-in categories. See [division].
  final String? district;

  /// Built-in vs user-created category.
  final bool isCustom;

  /// Whether the user/firm has modified a pre-seeded row.
  final bool isUserModified;

  /// Creator for custom individual categories; null for built-ins.
  final String? userId;

  /// Firm scope for custom firm categories; null for built-ins/individuals.
  final String? firmId;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const CourtCategory({
    required this.id,
    required this.nameKey,
    required this.courtLevel,
    required this.orderIndex,
    this.division,
    this.district,
    required this.isCustom,
    required this.isUserModified,
    this.userId,
    this.firmId,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name_key'] = Variable<String>(nameKey);
    map['court_level'] = Variable<String>(courtLevel);
    map['order_index'] = Variable<int>(orderIndex);
    if (!nullToAbsent || division != null) {
      map['division'] = Variable<String>(division);
    }
    if (!nullToAbsent || district != null) {
      map['district'] = Variable<String>(district);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    map['is_user_modified'] = Variable<bool>(isUserModified);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  CourtCategoriesCompanion toCompanion(bool nullToAbsent) {
    return CourtCategoriesCompanion(
      id: Value(id),
      nameKey: Value(nameKey),
      courtLevel: Value(courtLevel),
      orderIndex: Value(orderIndex),
      division: division == null && nullToAbsent
          ? const Value.absent()
          : Value(division),
      district: district == null && nullToAbsent
          ? const Value.absent()
          : Value(district),
      isCustom: Value(isCustom),
      isUserModified: Value(isUserModified),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory CourtCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CourtCategory(
      id: serializer.fromJson<String>(json['id']),
      nameKey: serializer.fromJson<String>(json['nameKey']),
      courtLevel: serializer.fromJson<String>(json['courtLevel']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      division: serializer.fromJson<String?>(json['division']),
      district: serializer.fromJson<String?>(json['district']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      isUserModified: serializer.fromJson<bool>(json['isUserModified']),
      userId: serializer.fromJson<String?>(json['userId']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nameKey': serializer.toJson<String>(nameKey),
      'courtLevel': serializer.toJson<String>(courtLevel),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'division': serializer.toJson<String?>(division),
      'district': serializer.toJson<String?>(district),
      'isCustom': serializer.toJson<bool>(isCustom),
      'isUserModified': serializer.toJson<bool>(isUserModified),
      'userId': serializer.toJson<String?>(userId),
      'firmId': serializer.toJson<String?>(firmId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  CourtCategory copyWith({
    String? id,
    String? nameKey,
    String? courtLevel,
    int? orderIndex,
    Value<String?> division = const Value.absent(),
    Value<String?> district = const Value.absent(),
    bool? isCustom,
    bool? isUserModified,
    Value<String?> userId = const Value.absent(),
    Value<String?> firmId = const Value.absent(),
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => CourtCategory(
    id: id ?? this.id,
    nameKey: nameKey ?? this.nameKey,
    courtLevel: courtLevel ?? this.courtLevel,
    orderIndex: orderIndex ?? this.orderIndex,
    division: division.present ? division.value : this.division,
    district: district.present ? district.value : this.district,
    isCustom: isCustom ?? this.isCustom,
    isUserModified: isUserModified ?? this.isUserModified,
    userId: userId.present ? userId.value : this.userId,
    firmId: firmId.present ? firmId.value : this.firmId,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  CourtCategory copyWithCompanion(CourtCategoriesCompanion data) {
    return CourtCategory(
      id: data.id.present ? data.id.value : this.id,
      nameKey: data.nameKey.present ? data.nameKey.value : this.nameKey,
      courtLevel: data.courtLevel.present
          ? data.courtLevel.value
          : this.courtLevel,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      division: data.division.present ? data.division.value : this.division,
      district: data.district.present ? data.district.value : this.district,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      isUserModified: data.isUserModified.present
          ? data.isUserModified.value
          : this.isUserModified,
      userId: data.userId.present ? data.userId.value : this.userId,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CourtCategory(')
          ..write('id: $id, ')
          ..write('nameKey: $nameKey, ')
          ..write('courtLevel: $courtLevel, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('division: $division, ')
          ..write('district: $district, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nameKey,
    courtLevel,
    orderIndex,
    division,
    district,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CourtCategory &&
          other.id == this.id &&
          other.nameKey == this.nameKey &&
          other.courtLevel == this.courtLevel &&
          other.orderIndex == this.orderIndex &&
          other.division == this.division &&
          other.district == this.district &&
          other.isCustom == this.isCustom &&
          other.isUserModified == this.isUserModified &&
          other.userId == this.userId &&
          other.firmId == this.firmId &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class CourtCategoriesCompanion extends UpdateCompanion<CourtCategory> {
  final Value<String> id;
  final Value<String> nameKey;
  final Value<String> courtLevel;
  final Value<int> orderIndex;
  final Value<String?> division;
  final Value<String?> district;
  final Value<bool> isCustom;
  final Value<bool> isUserModified;
  final Value<String?> userId;
  final Value<String?> firmId;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const CourtCategoriesCompanion({
    this.id = const Value.absent(),
    this.nameKey = const Value.absent(),
    this.courtLevel = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.division = const Value.absent(),
    this.district = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CourtCategoriesCompanion.insert({
    required String id,
    required String nameKey,
    required String courtLevel,
    required int orderIndex,
    this.division = const Value.absent(),
    this.district = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nameKey = Value(nameKey),
       courtLevel = Value(courtLevel),
       orderIndex = Value(orderIndex),
       updatedAt = Value(updatedAt);
  static Insertable<CourtCategory> custom({
    Expression<String>? id,
    Expression<String>? nameKey,
    Expression<String>? courtLevel,
    Expression<int>? orderIndex,
    Expression<String>? division,
    Expression<String>? district,
    Expression<bool>? isCustom,
    Expression<bool>? isUserModified,
    Expression<String>? userId,
    Expression<String>? firmId,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nameKey != null) 'name_key': nameKey,
      if (courtLevel != null) 'court_level': courtLevel,
      if (orderIndex != null) 'order_index': orderIndex,
      if (division != null) 'division': division,
      if (district != null) 'district': district,
      if (isCustom != null) 'is_custom': isCustom,
      if (isUserModified != null) 'is_user_modified': isUserModified,
      if (userId != null) 'user_id': userId,
      if (firmId != null) 'firm_id': firmId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CourtCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? nameKey,
    Value<String>? courtLevel,
    Value<int>? orderIndex,
    Value<String?>? division,
    Value<String?>? district,
    Value<bool>? isCustom,
    Value<bool>? isUserModified,
    Value<String?>? userId,
    Value<String?>? firmId,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return CourtCategoriesCompanion(
      id: id ?? this.id,
      nameKey: nameKey ?? this.nameKey,
      courtLevel: courtLevel ?? this.courtLevel,
      orderIndex: orderIndex ?? this.orderIndex,
      division: division ?? this.division,
      district: district ?? this.district,
      isCustom: isCustom ?? this.isCustom,
      isUserModified: isUserModified ?? this.isUserModified,
      userId: userId ?? this.userId,
      firmId: firmId ?? this.firmId,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nameKey.present) {
      map['name_key'] = Variable<String>(nameKey.value);
    }
    if (courtLevel.present) {
      map['court_level'] = Variable<String>(courtLevel.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (division.present) {
      map['division'] = Variable<String>(division.value);
    }
    if (district.present) {
      map['district'] = Variable<String>(district.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (isUserModified.present) {
      map['is_user_modified'] = Variable<bool>(isUserModified.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CourtCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('nameKey: $nameKey, ')
          ..write('courtLevel: $courtLevel, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('division: $division, ')
          ..write('district: $district, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CourtsTable extends Courts with TableInfo<$CourtsTable, Court> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CourtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courtNameMeta = const VerificationMeta(
    'courtName',
  );
  @override
  late final GeneratedColumn<String> courtName = GeneratedColumn<String>(
    'court_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _higherLowerCourtsMeta = const VerificationMeta(
    'higherLowerCourts',
  );
  @override
  late final GeneratedColumn<String> higherLowerCourts =
      GeneratedColumn<String>(
        'higher_lower_courts',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _divisionMeta = const VerificationMeta(
    'division',
  );
  @override
  late final GeneratedColumn<String> division = GeneratedColumn<String>(
    'division',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _districtMeta = const VerificationMeta(
    'district',
  );
  @override
  late final GeneratedColumn<String> district = GeneratedColumn<String>(
    'district',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _courtCategoryIdMeta = const VerificationMeta(
    'courtCategoryId',
  );
  @override
  late final GeneratedColumn<String> courtCategoryId = GeneratedColumn<String>(
    'court_category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES court_categories (id)',
    ),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isUserModifiedMeta = const VerificationMeta(
    'isUserModified',
  );
  @override
  late final GeneratedColumn<bool> isUserModified = GeneratedColumn<bool>(
    'is_user_modified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_user_modified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courtName,
    higherLowerCourts,
    division,
    district,
    courtCategoryId,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Court> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('court_name')) {
      context.handle(
        _courtNameMeta,
        courtName.isAcceptableOrUnknown(data['court_name']!, _courtNameMeta),
      );
    } else if (isInserting) {
      context.missing(_courtNameMeta);
    }
    if (data.containsKey('higher_lower_courts')) {
      context.handle(
        _higherLowerCourtsMeta,
        higherLowerCourts.isAcceptableOrUnknown(
          data['higher_lower_courts']!,
          _higherLowerCourtsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_higherLowerCourtsMeta);
    }
    if (data.containsKey('division')) {
      context.handle(
        _divisionMeta,
        division.isAcceptableOrUnknown(data['division']!, _divisionMeta),
      );
    }
    if (data.containsKey('district')) {
      context.handle(
        _districtMeta,
        district.isAcceptableOrUnknown(data['district']!, _districtMeta),
      );
    }
    if (data.containsKey('court_category_id')) {
      context.handle(
        _courtCategoryIdMeta,
        courtCategoryId.isAcceptableOrUnknown(
          data['court_category_id']!,
          _courtCategoryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courtCategoryIdMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('is_user_modified')) {
      context.handle(
        _isUserModifiedMeta,
        isUserModified.isAcceptableOrUnknown(
          data['is_user_modified']!,
          _isUserModifiedMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Court map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Court(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      courtName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}court_name'],
      )!,
      higherLowerCourts: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}higher_lower_courts'],
      )!,
      division: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}division'],
      ),
      district: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}district'],
      ),
      courtCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}court_category_id'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      isUserModified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_user_modified'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $CourtsTable createAlias(String alias) {
    return $CourtsTable(attachedDatabase, alias);
  }
}

class Court extends DataClass implements Insertable<Court> {
  /// UUID primary key.
  final String id;

  /// Court name (Bengali or English).
  final String courtName;

  /// `higher_courts` or `lower_courts`.
  final String higherLowerCourts;

  /// Bangladesh division; only for lower courts.
  final String? division;

  /// Bangladesh district; only for lower courts.
  final String? district;

  /// Required court category.
  final String courtCategoryId;

  /// Display order from the canonical seed list.
  final int orderIndex;

  /// True if added by the user; false if pre-seeded.
  final bool isCustom;

  /// Whether the user/firm has modified a pre-seeded row.
  final bool isUserModified;

  /// Creator of custom court; null for pre-seeded.
  final String? userId;

  /// Firm scope; null for individuals & pre-seeded rows.
  final String? firmId;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const Court({
    required this.id,
    required this.courtName,
    required this.higherLowerCourts,
    this.division,
    this.district,
    required this.courtCategoryId,
    required this.orderIndex,
    required this.isCustom,
    required this.isUserModified,
    this.userId,
    this.firmId,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['court_name'] = Variable<String>(courtName);
    map['higher_lower_courts'] = Variable<String>(higherLowerCourts);
    if (!nullToAbsent || division != null) {
      map['division'] = Variable<String>(division);
    }
    if (!nullToAbsent || district != null) {
      map['district'] = Variable<String>(district);
    }
    map['court_category_id'] = Variable<String>(courtCategoryId);
    map['order_index'] = Variable<int>(orderIndex);
    map['is_custom'] = Variable<bool>(isCustom);
    map['is_user_modified'] = Variable<bool>(isUserModified);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  CourtsCompanion toCompanion(bool nullToAbsent) {
    return CourtsCompanion(
      id: Value(id),
      courtName: Value(courtName),
      higherLowerCourts: Value(higherLowerCourts),
      division: division == null && nullToAbsent
          ? const Value.absent()
          : Value(division),
      district: district == null && nullToAbsent
          ? const Value.absent()
          : Value(district),
      courtCategoryId: Value(courtCategoryId),
      orderIndex: Value(orderIndex),
      isCustom: Value(isCustom),
      isUserModified: Value(isUserModified),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory Court.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Court(
      id: serializer.fromJson<String>(json['id']),
      courtName: serializer.fromJson<String>(json['courtName']),
      higherLowerCourts: serializer.fromJson<String>(json['higherLowerCourts']),
      division: serializer.fromJson<String?>(json['division']),
      district: serializer.fromJson<String?>(json['district']),
      courtCategoryId: serializer.fromJson<String>(json['courtCategoryId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      isUserModified: serializer.fromJson<bool>(json['isUserModified']),
      userId: serializer.fromJson<String?>(json['userId']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'courtName': serializer.toJson<String>(courtName),
      'higherLowerCourts': serializer.toJson<String>(higherLowerCourts),
      'division': serializer.toJson<String?>(division),
      'district': serializer.toJson<String?>(district),
      'courtCategoryId': serializer.toJson<String>(courtCategoryId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'isCustom': serializer.toJson<bool>(isCustom),
      'isUserModified': serializer.toJson<bool>(isUserModified),
      'userId': serializer.toJson<String?>(userId),
      'firmId': serializer.toJson<String?>(firmId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  Court copyWith({
    String? id,
    String? courtName,
    String? higherLowerCourts,
    Value<String?> division = const Value.absent(),
    Value<String?> district = const Value.absent(),
    String? courtCategoryId,
    int? orderIndex,
    bool? isCustom,
    bool? isUserModified,
    Value<String?> userId = const Value.absent(),
    Value<String?> firmId = const Value.absent(),
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => Court(
    id: id ?? this.id,
    courtName: courtName ?? this.courtName,
    higherLowerCourts: higherLowerCourts ?? this.higherLowerCourts,
    division: division.present ? division.value : this.division,
    district: district.present ? district.value : this.district,
    courtCategoryId: courtCategoryId ?? this.courtCategoryId,
    orderIndex: orderIndex ?? this.orderIndex,
    isCustom: isCustom ?? this.isCustom,
    isUserModified: isUserModified ?? this.isUserModified,
    userId: userId.present ? userId.value : this.userId,
    firmId: firmId.present ? firmId.value : this.firmId,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  Court copyWithCompanion(CourtsCompanion data) {
    return Court(
      id: data.id.present ? data.id.value : this.id,
      courtName: data.courtName.present ? data.courtName.value : this.courtName,
      higherLowerCourts: data.higherLowerCourts.present
          ? data.higherLowerCourts.value
          : this.higherLowerCourts,
      division: data.division.present ? data.division.value : this.division,
      district: data.district.present ? data.district.value : this.district,
      courtCategoryId: data.courtCategoryId.present
          ? data.courtCategoryId.value
          : this.courtCategoryId,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      isUserModified: data.isUserModified.present
          ? data.isUserModified.value
          : this.isUserModified,
      userId: data.userId.present ? data.userId.value : this.userId,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Court(')
          ..write('id: $id, ')
          ..write('courtName: $courtName, ')
          ..write('higherLowerCourts: $higherLowerCourts, ')
          ..write('division: $division, ')
          ..write('district: $district, ')
          ..write('courtCategoryId: $courtCategoryId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    courtName,
    higherLowerCourts,
    division,
    district,
    courtCategoryId,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Court &&
          other.id == this.id &&
          other.courtName == this.courtName &&
          other.higherLowerCourts == this.higherLowerCourts &&
          other.division == this.division &&
          other.district == this.district &&
          other.courtCategoryId == this.courtCategoryId &&
          other.orderIndex == this.orderIndex &&
          other.isCustom == this.isCustom &&
          other.isUserModified == this.isUserModified &&
          other.userId == this.userId &&
          other.firmId == this.firmId &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class CourtsCompanion extends UpdateCompanion<Court> {
  final Value<String> id;
  final Value<String> courtName;
  final Value<String> higherLowerCourts;
  final Value<String?> division;
  final Value<String?> district;
  final Value<String> courtCategoryId;
  final Value<int> orderIndex;
  final Value<bool> isCustom;
  final Value<bool> isUserModified;
  final Value<String?> userId;
  final Value<String?> firmId;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const CourtsCompanion({
    this.id = const Value.absent(),
    this.courtName = const Value.absent(),
    this.higherLowerCourts = const Value.absent(),
    this.division = const Value.absent(),
    this.district = const Value.absent(),
    this.courtCategoryId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CourtsCompanion.insert({
    required String id,
    required String courtName,
    required String higherLowerCourts,
    this.division = const Value.absent(),
    this.district = const Value.absent(),
    required String courtCategoryId,
    this.orderIndex = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courtName = Value(courtName),
       higherLowerCourts = Value(higherLowerCourts),
       courtCategoryId = Value(courtCategoryId),
       updatedAt = Value(updatedAt);
  static Insertable<Court> custom({
    Expression<String>? id,
    Expression<String>? courtName,
    Expression<String>? higherLowerCourts,
    Expression<String>? division,
    Expression<String>? district,
    Expression<String>? courtCategoryId,
    Expression<int>? orderIndex,
    Expression<bool>? isCustom,
    Expression<bool>? isUserModified,
    Expression<String>? userId,
    Expression<String>? firmId,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courtName != null) 'court_name': courtName,
      if (higherLowerCourts != null) 'higher_lower_courts': higherLowerCourts,
      if (division != null) 'division': division,
      if (district != null) 'district': district,
      if (courtCategoryId != null) 'court_category_id': courtCategoryId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (isCustom != null) 'is_custom': isCustom,
      if (isUserModified != null) 'is_user_modified': isUserModified,
      if (userId != null) 'user_id': userId,
      if (firmId != null) 'firm_id': firmId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CourtsCompanion copyWith({
    Value<String>? id,
    Value<String>? courtName,
    Value<String>? higherLowerCourts,
    Value<String?>? division,
    Value<String?>? district,
    Value<String>? courtCategoryId,
    Value<int>? orderIndex,
    Value<bool>? isCustom,
    Value<bool>? isUserModified,
    Value<String?>? userId,
    Value<String?>? firmId,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return CourtsCompanion(
      id: id ?? this.id,
      courtName: courtName ?? this.courtName,
      higherLowerCourts: higherLowerCourts ?? this.higherLowerCourts,
      division: division ?? this.division,
      district: district ?? this.district,
      courtCategoryId: courtCategoryId ?? this.courtCategoryId,
      orderIndex: orderIndex ?? this.orderIndex,
      isCustom: isCustom ?? this.isCustom,
      isUserModified: isUserModified ?? this.isUserModified,
      userId: userId ?? this.userId,
      firmId: firmId ?? this.firmId,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (courtName.present) {
      map['court_name'] = Variable<String>(courtName.value);
    }
    if (higherLowerCourts.present) {
      map['higher_lower_courts'] = Variable<String>(higherLowerCourts.value);
    }
    if (division.present) {
      map['division'] = Variable<String>(division.value);
    }
    if (district.present) {
      map['district'] = Variable<String>(district.value);
    }
    if (courtCategoryId.present) {
      map['court_category_id'] = Variable<String>(courtCategoryId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (isUserModified.present) {
      map['is_user_modified'] = Variable<bool>(isUserModified.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CourtsCompanion(')
          ..write('id: $id, ')
          ..write('courtName: $courtName, ')
          ..write('higherLowerCourts: $higherLowerCourts, ')
          ..write('division: $division, ')
          ..write('district: $district, ')
          ..write('courtCategoryId: $courtCategoryId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CaseCategoriesTable extends CaseCategories
    with TableInfo<$CaseCategoriesTable, CaseCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaseCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courtCategoryIdMeta = const VerificationMeta(
    'courtCategoryId',
  );
  @override
  late final GeneratedColumn<String> courtCategoryId = GeneratedColumn<String>(
    'court_category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES court_categories (id)',
    ),
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
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isUserModifiedMeta = const VerificationMeta(
    'isUserModified',
  );
  @override
  late final GeneratedColumn<bool> isUserModified = GeneratedColumn<bool>(
    'is_user_modified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_user_modified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courtCategoryId,
    name,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'case_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaseCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('court_category_id')) {
      context.handle(
        _courtCategoryIdMeta,
        courtCategoryId.isAcceptableOrUnknown(
          data['court_category_id']!,
          _courtCategoryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courtCategoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('is_user_modified')) {
      context.handle(
        _isUserModifiedMeta,
        isUserModified.isAcceptableOrUnknown(
          data['is_user_modified']!,
          _isUserModifiedMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaseCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaseCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      courtCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}court_category_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      isUserModified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_user_modified'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $CaseCategoriesTable createAlias(String alias) {
    return $CaseCategoriesTable(attachedDatabase, alias);
  }
}

class CaseCategory extends DataClass implements Insertable<CaseCategory> {
  /// Stable deterministic seed ID or UUID for a custom row.
  final String id;

  /// Canonical court category that owns this case category.
  final String courtCategoryId;

  /// English seed/custom display name.
  final String name;

  /// Display order within the court category.
  final int orderIndex;

  /// Built-in versus user-created case category.
  final bool isCustom;

  /// Whether the user/firm has modified a built-in row.
  final bool isUserModified;

  /// Creator for custom individual categories; null for built-ins.
  final String? userId;

  /// Firm scope for custom firm categories; null for built-ins/individuals.
  final String? firmId;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const CaseCategory({
    required this.id,
    required this.courtCategoryId,
    required this.name,
    required this.orderIndex,
    required this.isCustom,
    required this.isUserModified,
    this.userId,
    this.firmId,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['court_category_id'] = Variable<String>(courtCategoryId);
    map['name'] = Variable<String>(name);
    map['order_index'] = Variable<int>(orderIndex);
    map['is_custom'] = Variable<bool>(isCustom);
    map['is_user_modified'] = Variable<bool>(isUserModified);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  CaseCategoriesCompanion toCompanion(bool nullToAbsent) {
    return CaseCategoriesCompanion(
      id: Value(id),
      courtCategoryId: Value(courtCategoryId),
      name: Value(name),
      orderIndex: Value(orderIndex),
      isCustom: Value(isCustom),
      isUserModified: Value(isUserModified),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory CaseCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaseCategory(
      id: serializer.fromJson<String>(json['id']),
      courtCategoryId: serializer.fromJson<String>(json['courtCategoryId']),
      name: serializer.fromJson<String>(json['name']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      isUserModified: serializer.fromJson<bool>(json['isUserModified']),
      userId: serializer.fromJson<String?>(json['userId']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'courtCategoryId': serializer.toJson<String>(courtCategoryId),
      'name': serializer.toJson<String>(name),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'isCustom': serializer.toJson<bool>(isCustom),
      'isUserModified': serializer.toJson<bool>(isUserModified),
      'userId': serializer.toJson<String?>(userId),
      'firmId': serializer.toJson<String?>(firmId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  CaseCategory copyWith({
    String? id,
    String? courtCategoryId,
    String? name,
    int? orderIndex,
    bool? isCustom,
    bool? isUserModified,
    Value<String?> userId = const Value.absent(),
    Value<String?> firmId = const Value.absent(),
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => CaseCategory(
    id: id ?? this.id,
    courtCategoryId: courtCategoryId ?? this.courtCategoryId,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
    isCustom: isCustom ?? this.isCustom,
    isUserModified: isUserModified ?? this.isUserModified,
    userId: userId.present ? userId.value : this.userId,
    firmId: firmId.present ? firmId.value : this.firmId,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  CaseCategory copyWithCompanion(CaseCategoriesCompanion data) {
    return CaseCategory(
      id: data.id.present ? data.id.value : this.id,
      courtCategoryId: data.courtCategoryId.present
          ? data.courtCategoryId.value
          : this.courtCategoryId,
      name: data.name.present ? data.name.value : this.name,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      isUserModified: data.isUserModified.present
          ? data.isUserModified.value
          : this.isUserModified,
      userId: data.userId.present ? data.userId.value : this.userId,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaseCategory(')
          ..write('id: $id, ')
          ..write('courtCategoryId: $courtCategoryId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    courtCategoryId,
    name,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaseCategory &&
          other.id == this.id &&
          other.courtCategoryId == this.courtCategoryId &&
          other.name == this.name &&
          other.orderIndex == this.orderIndex &&
          other.isCustom == this.isCustom &&
          other.isUserModified == this.isUserModified &&
          other.userId == this.userId &&
          other.firmId == this.firmId &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class CaseCategoriesCompanion extends UpdateCompanion<CaseCategory> {
  final Value<String> id;
  final Value<String> courtCategoryId;
  final Value<String> name;
  final Value<int> orderIndex;
  final Value<bool> isCustom;
  final Value<bool> isUserModified;
  final Value<String?> userId;
  final Value<String?> firmId;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const CaseCategoriesCompanion({
    this.id = const Value.absent(),
    this.courtCategoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaseCategoriesCompanion.insert({
    required String id,
    required String courtCategoryId,
    required String name,
    required int orderIndex,
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courtCategoryId = Value(courtCategoryId),
       name = Value(name),
       orderIndex = Value(orderIndex),
       updatedAt = Value(updatedAt);
  static Insertable<CaseCategory> custom({
    Expression<String>? id,
    Expression<String>? courtCategoryId,
    Expression<String>? name,
    Expression<int>? orderIndex,
    Expression<bool>? isCustom,
    Expression<bool>? isUserModified,
    Expression<String>? userId,
    Expression<String>? firmId,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courtCategoryId != null) 'court_category_id': courtCategoryId,
      if (name != null) 'name': name,
      if (orderIndex != null) 'order_index': orderIndex,
      if (isCustom != null) 'is_custom': isCustom,
      if (isUserModified != null) 'is_user_modified': isUserModified,
      if (userId != null) 'user_id': userId,
      if (firmId != null) 'firm_id': firmId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaseCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? courtCategoryId,
    Value<String>? name,
    Value<int>? orderIndex,
    Value<bool>? isCustom,
    Value<bool>? isUserModified,
    Value<String?>? userId,
    Value<String?>? firmId,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return CaseCategoriesCompanion(
      id: id ?? this.id,
      courtCategoryId: courtCategoryId ?? this.courtCategoryId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      isCustom: isCustom ?? this.isCustom,
      isUserModified: isUserModified ?? this.isUserModified,
      userId: userId ?? this.userId,
      firmId: firmId ?? this.firmId,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (courtCategoryId.present) {
      map['court_category_id'] = Variable<String>(courtCategoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (isUserModified.present) {
      map['is_user_modified'] = Variable<bool>(isUserModified.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaseCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('courtCategoryId: $courtCategoryId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OnBehalfsTable extends OnBehalfs
    with TableInfo<$OnBehalfsTable, OnBehalf> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnBehalfsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courtCategoryIdMeta = const VerificationMeta(
    'courtCategoryId',
  );
  @override
  late final GeneratedColumn<String> courtCategoryId = GeneratedColumn<String>(
    'court_category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES court_categories (id)',
    ),
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
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isUserModifiedMeta = const VerificationMeta(
    'isUserModified',
  );
  @override
  late final GeneratedColumn<bool> isUserModified = GeneratedColumn<bool>(
    'is_user_modified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_user_modified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courtCategoryId,
    name,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'on_behalfs';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnBehalf> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('court_category_id')) {
      context.handle(
        _courtCategoryIdMeta,
        courtCategoryId.isAcceptableOrUnknown(
          data['court_category_id']!,
          _courtCategoryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courtCategoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('is_user_modified')) {
      context.handle(
        _isUserModifiedMeta,
        isUserModified.isAcceptableOrUnknown(
          data['is_user_modified']!,
          _isUserModifiedMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OnBehalf map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnBehalf(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      courtCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}court_category_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      isUserModified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_user_modified'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $OnBehalfsTable createAlias(String alias) {
    return $OnBehalfsTable(attachedDatabase, alias);
  }
}

class OnBehalf extends DataClass implements Insertable<OnBehalf> {
  /// UUID primary key.
  final String id;

  /// Court category this role belongs to.
  final String courtCategoryId;

  /// Display name of the role.
  final String name;

  /// Display order within the category.
  final int orderIndex;

  /// True if added by the user; false if pre-seeded.
  final bool isCustom;

  /// Whether the user/firm has modified a pre-seeded row.
  final bool isUserModified;

  /// Creator of custom role; null for pre-seeded.
  final String? userId;

  /// Firm scope; null for individuals & pre-seeded rows.
  final String? firmId;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const OnBehalf({
    required this.id,
    required this.courtCategoryId,
    required this.name,
    required this.orderIndex,
    required this.isCustom,
    required this.isUserModified,
    this.userId,
    this.firmId,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['court_category_id'] = Variable<String>(courtCategoryId);
    map['name'] = Variable<String>(name);
    map['order_index'] = Variable<int>(orderIndex);
    map['is_custom'] = Variable<bool>(isCustom);
    map['is_user_modified'] = Variable<bool>(isUserModified);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  OnBehalfsCompanion toCompanion(bool nullToAbsent) {
    return OnBehalfsCompanion(
      id: Value(id),
      courtCategoryId: Value(courtCategoryId),
      name: Value(name),
      orderIndex: Value(orderIndex),
      isCustom: Value(isCustom),
      isUserModified: Value(isUserModified),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory OnBehalf.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnBehalf(
      id: serializer.fromJson<String>(json['id']),
      courtCategoryId: serializer.fromJson<String>(json['courtCategoryId']),
      name: serializer.fromJson<String>(json['name']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      isUserModified: serializer.fromJson<bool>(json['isUserModified']),
      userId: serializer.fromJson<String?>(json['userId']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'courtCategoryId': serializer.toJson<String>(courtCategoryId),
      'name': serializer.toJson<String>(name),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'isCustom': serializer.toJson<bool>(isCustom),
      'isUserModified': serializer.toJson<bool>(isUserModified),
      'userId': serializer.toJson<String?>(userId),
      'firmId': serializer.toJson<String?>(firmId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  OnBehalf copyWith({
    String? id,
    String? courtCategoryId,
    String? name,
    int? orderIndex,
    bool? isCustom,
    bool? isUserModified,
    Value<String?> userId = const Value.absent(),
    Value<String?> firmId = const Value.absent(),
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => OnBehalf(
    id: id ?? this.id,
    courtCategoryId: courtCategoryId ?? this.courtCategoryId,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
    isCustom: isCustom ?? this.isCustom,
    isUserModified: isUserModified ?? this.isUserModified,
    userId: userId.present ? userId.value : this.userId,
    firmId: firmId.present ? firmId.value : this.firmId,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  OnBehalf copyWithCompanion(OnBehalfsCompanion data) {
    return OnBehalf(
      id: data.id.present ? data.id.value : this.id,
      courtCategoryId: data.courtCategoryId.present
          ? data.courtCategoryId.value
          : this.courtCategoryId,
      name: data.name.present ? data.name.value : this.name,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      isUserModified: data.isUserModified.present
          ? data.isUserModified.value
          : this.isUserModified,
      userId: data.userId.present ? data.userId.value : this.userId,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnBehalf(')
          ..write('id: $id, ')
          ..write('courtCategoryId: $courtCategoryId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    courtCategoryId,
    name,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnBehalf &&
          other.id == this.id &&
          other.courtCategoryId == this.courtCategoryId &&
          other.name == this.name &&
          other.orderIndex == this.orderIndex &&
          other.isCustom == this.isCustom &&
          other.isUserModified == this.isUserModified &&
          other.userId == this.userId &&
          other.firmId == this.firmId &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class OnBehalfsCompanion extends UpdateCompanion<OnBehalf> {
  final Value<String> id;
  final Value<String> courtCategoryId;
  final Value<String> name;
  final Value<int> orderIndex;
  final Value<bool> isCustom;
  final Value<bool> isUserModified;
  final Value<String?> userId;
  final Value<String?> firmId;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const OnBehalfsCompanion({
    this.id = const Value.absent(),
    this.courtCategoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OnBehalfsCompanion.insert({
    required String id,
    required String courtCategoryId,
    required String name,
    required int orderIndex,
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courtCategoryId = Value(courtCategoryId),
       name = Value(name),
       orderIndex = Value(orderIndex),
       updatedAt = Value(updatedAt);
  static Insertable<OnBehalf> custom({
    Expression<String>? id,
    Expression<String>? courtCategoryId,
    Expression<String>? name,
    Expression<int>? orderIndex,
    Expression<bool>? isCustom,
    Expression<bool>? isUserModified,
    Expression<String>? userId,
    Expression<String>? firmId,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courtCategoryId != null) 'court_category_id': courtCategoryId,
      if (name != null) 'name': name,
      if (orderIndex != null) 'order_index': orderIndex,
      if (isCustom != null) 'is_custom': isCustom,
      if (isUserModified != null) 'is_user_modified': isUserModified,
      if (userId != null) 'user_id': userId,
      if (firmId != null) 'firm_id': firmId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OnBehalfsCompanion copyWith({
    Value<String>? id,
    Value<String>? courtCategoryId,
    Value<String>? name,
    Value<int>? orderIndex,
    Value<bool>? isCustom,
    Value<bool>? isUserModified,
    Value<String?>? userId,
    Value<String?>? firmId,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return OnBehalfsCompanion(
      id: id ?? this.id,
      courtCategoryId: courtCategoryId ?? this.courtCategoryId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      isCustom: isCustom ?? this.isCustom,
      isUserModified: isUserModified ?? this.isUserModified,
      userId: userId ?? this.userId,
      firmId: firmId ?? this.firmId,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (courtCategoryId.present) {
      map['court_category_id'] = Variable<String>(courtCategoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (isUserModified.present) {
      map['is_user_modified'] = Variable<bool>(isUserModified.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnBehalfsCompanion(')
          ..write('id: $id, ')
          ..write('courtCategoryId: $courtCategoryId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CasesTable extends Cases with TableInfo<$CasesTable, Case> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _courtIdMeta = const VerificationMeta(
    'courtId',
  );
  @override
  late final GeneratedColumn<String> courtId = GeneratedColumn<String>(
    'court_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES courts (id)',
    ),
  );
  static const VerificationMeta _caseTypeMeta = const VerificationMeta(
    'caseType',
  );
  @override
  late final GeneratedColumn<String> caseType = GeneratedColumn<String>(
    'case_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caseCategoryIdMeta = const VerificationMeta(
    'caseCategoryId',
  );
  @override
  late final GeneratedColumn<String> caseCategoryId = GeneratedColumn<String>(
    'case_category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES case_categories (id)',
    ),
  );
  static const VerificationMeta _caseNumberMeta = const VerificationMeta(
    'caseNumber',
  );
  @override
  late final GeneratedColumn<String> caseNumber = GeneratedColumn<String>(
    'case_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _honorableJudgesMeta = const VerificationMeta(
    'honorableJudges',
  );
  @override
  late final GeneratedColumn<String> honorableJudges = GeneratedColumn<String>(
    'honorable_judges',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenderNumberMeta = const VerificationMeta(
    'tenderNumber',
  );
  @override
  late final GeneratedColumn<String> tenderNumber = GeneratedColumn<String>(
    'tender_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previousCourtCaseMeta = const VerificationMeta(
    'previousCourtCase',
  );
  @override
  late final GeneratedColumn<String> previousCourtCase =
      GeneratedColumn<String>(
        'previous_court_case',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _districtOfOriginMeta = const VerificationMeta(
    'districtOfOrigin',
  );
  @override
  late final GeneratedColumn<String> districtOfOrigin = GeneratedColumn<String>(
    'district_of_origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _petitionerMeta = const VerificationMeta(
    'petitioner',
  );
  @override
  late final GeneratedColumn<String> petitioner = GeneratedColumn<String>(
    'petitioner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _petitionerLeadCounselMeta =
      const VerificationMeta('petitionerLeadCounsel');
  @override
  late final GeneratedColumn<String> petitionerLeadCounsel =
      GeneratedColumn<String>(
        'petitioner_lead_counsel',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _respondentMeta = const VerificationMeta(
    'respondent',
  );
  @override
  late final GeneratedColumn<String> respondent = GeneratedColumn<String>(
    'respondent',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _respondentLeadCounselMeta =
      const VerificationMeta('respondentLeadCounsel');
  @override
  late final GeneratedColumn<String> respondentLeadCounsel =
      GeneratedColumn<String>(
        'respondent_lead_counsel',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _onBehalfIdMeta = const VerificationMeta(
    'onBehalfId',
  );
  @override
  late final GeneratedColumn<String> onBehalfId = GeneratedColumn<String>(
    'on_behalf_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES on_behalfs (id)',
    ),
  );
  static const VerificationMeta _partyPhoneMeta = const VerificationMeta(
    'partyPhone',
  );
  @override
  late final GeneratedColumn<String> partyPhone = GeneratedColumn<String>(
    'party_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caseTitleAndSectionMeta =
      const VerificationMeta('caseTitleAndSection');
  @override
  late final GeneratedColumn<String> caseTitleAndSection =
      GeneratedColumn<String>(
        'case_title_and_section',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _caseRemarksMeta = const VerificationMeta(
    'caseRemarks',
  );
  @override
  late final GeneratedColumn<String> caseRemarks = GeneratedColumn<String>(
    'case_remarks',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDateMeta = const VerificationMeta(
    'nextDate',
  );
  @override
  late final GeneratedColumn<int> nextDate = GeneratedColumn<int>(
    'next_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastStepMeta = const VerificationMeta(
    'lastStep',
  );
  @override
  late final GeneratedColumn<String> lastStep = GeneratedColumn<String>(
    'last_step',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesResultsMeta = const VerificationMeta(
    'notesResults',
  );
  @override
  late final GeneratedColumn<String> notesResults = GeneratedColumn<String>(
    'notes_results',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    firmId,
    courtId,
    caseType,
    caseCategoryId,
    caseNumber,
    honorableJudges,
    tenderNumber,
    previousCourtCase,
    districtOfOrigin,
    petitioner,
    petitionerLeadCounsel,
    respondent,
    respondentLeadCounsel,
    onBehalfId,
    partyPhone,
    caseTitleAndSection,
    caseRemarks,
    nextDate,
    lastStep,
    notesResults,
    result,
    createdAt,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cases';
  @override
  VerificationContext validateIntegrity(
    Insertable<Case> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('court_id')) {
      context.handle(
        _courtIdMeta,
        courtId.isAcceptableOrUnknown(data['court_id']!, _courtIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courtIdMeta);
    }
    if (data.containsKey('case_type')) {
      context.handle(
        _caseTypeMeta,
        caseType.isAcceptableOrUnknown(data['case_type']!, _caseTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_caseTypeMeta);
    }
    if (data.containsKey('case_category_id')) {
      context.handle(
        _caseCategoryIdMeta,
        caseCategoryId.isAcceptableOrUnknown(
          data['case_category_id']!,
          _caseCategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('case_number')) {
      context.handle(
        _caseNumberMeta,
        caseNumber.isAcceptableOrUnknown(data['case_number']!, _caseNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_caseNumberMeta);
    }
    if (data.containsKey('honorable_judges')) {
      context.handle(
        _honorableJudgesMeta,
        honorableJudges.isAcceptableOrUnknown(
          data['honorable_judges']!,
          _honorableJudgesMeta,
        ),
      );
    }
    if (data.containsKey('tender_number')) {
      context.handle(
        _tenderNumberMeta,
        tenderNumber.isAcceptableOrUnknown(
          data['tender_number']!,
          _tenderNumberMeta,
        ),
      );
    }
    if (data.containsKey('previous_court_case')) {
      context.handle(
        _previousCourtCaseMeta,
        previousCourtCase.isAcceptableOrUnknown(
          data['previous_court_case']!,
          _previousCourtCaseMeta,
        ),
      );
    }
    if (data.containsKey('district_of_origin')) {
      context.handle(
        _districtOfOriginMeta,
        districtOfOrigin.isAcceptableOrUnknown(
          data['district_of_origin']!,
          _districtOfOriginMeta,
        ),
      );
    }
    if (data.containsKey('petitioner')) {
      context.handle(
        _petitionerMeta,
        petitioner.isAcceptableOrUnknown(data['petitioner']!, _petitionerMeta),
      );
    } else if (isInserting) {
      context.missing(_petitionerMeta);
    }
    if (data.containsKey('petitioner_lead_counsel')) {
      context.handle(
        _petitionerLeadCounselMeta,
        petitionerLeadCounsel.isAcceptableOrUnknown(
          data['petitioner_lead_counsel']!,
          _petitionerLeadCounselMeta,
        ),
      );
    }
    if (data.containsKey('respondent')) {
      context.handle(
        _respondentMeta,
        respondent.isAcceptableOrUnknown(data['respondent']!, _respondentMeta),
      );
    } else if (isInserting) {
      context.missing(_respondentMeta);
    }
    if (data.containsKey('respondent_lead_counsel')) {
      context.handle(
        _respondentLeadCounselMeta,
        respondentLeadCounsel.isAcceptableOrUnknown(
          data['respondent_lead_counsel']!,
          _respondentLeadCounselMeta,
        ),
      );
    }
    if (data.containsKey('on_behalf_id')) {
      context.handle(
        _onBehalfIdMeta,
        onBehalfId.isAcceptableOrUnknown(
          data['on_behalf_id']!,
          _onBehalfIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_onBehalfIdMeta);
    }
    if (data.containsKey('party_phone')) {
      context.handle(
        _partyPhoneMeta,
        partyPhone.isAcceptableOrUnknown(data['party_phone']!, _partyPhoneMeta),
      );
    }
    if (data.containsKey('case_title_and_section')) {
      context.handle(
        _caseTitleAndSectionMeta,
        caseTitleAndSection.isAcceptableOrUnknown(
          data['case_title_and_section']!,
          _caseTitleAndSectionMeta,
        ),
      );
    }
    if (data.containsKey('case_remarks')) {
      context.handle(
        _caseRemarksMeta,
        caseRemarks.isAcceptableOrUnknown(
          data['case_remarks']!,
          _caseRemarksMeta,
        ),
      );
    }
    if (data.containsKey('next_date')) {
      context.handle(
        _nextDateMeta,
        nextDate.isAcceptableOrUnknown(data['next_date']!, _nextDateMeta),
      );
    }
    if (data.containsKey('last_step')) {
      context.handle(
        _lastStepMeta,
        lastStep.isAcceptableOrUnknown(data['last_step']!, _lastStepMeta),
      );
    }
    if (data.containsKey('notes_results')) {
      context.handle(
        _notesResultsMeta,
        notesResults.isAcceptableOrUnknown(
          data['notes_results']!,
          _notesResultsMeta,
        ),
      );
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Case map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Case(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      courtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}court_id'],
      )!,
      caseType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_type'],
      )!,
      caseCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_category_id'],
      ),
      caseNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_number'],
      )!,
      honorableJudges: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}honorable_judges'],
      ),
      tenderNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tender_number'],
      ),
      previousCourtCase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_court_case'],
      ),
      districtOfOrigin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}district_of_origin'],
      ),
      petitioner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}petitioner'],
      )!,
      petitionerLeadCounsel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}petitioner_lead_counsel'],
      ),
      respondent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}respondent'],
      )!,
      respondentLeadCounsel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}respondent_lead_counsel'],
      ),
      onBehalfId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}on_behalf_id'],
      )!,
      partyPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_phone'],
      ),
      caseTitleAndSection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_title_and_section'],
      ),
      caseRemarks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_remarks'],
      ),
      nextDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_date'],
      ),
      lastStep: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_step'],
      ),
      notesResults: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes_results'],
      ),
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $CasesTable createAlias(String alias) {
    return $CasesTable(attachedDatabase, alias);
  }
}

class Case extends DataClass implements Insertable<Case> {
  /// UUID primary key.
  final String id;

  /// Owner (lawyer) who created the case.
  final String userId;

  /// Firm scope; null for individual lawyers.
  final String? firmId;

  /// Court this case belongs to.
  final String courtId;

  /// Case type (e.g. "Criminal", "Civil").
  final String caseType;

  /// AD/HCD case-category scope for the selected case type.
  final String? caseCategoryId;

  /// Single text entity such as "110/2021".
  final String caseNumber;

  /// AD/HCD judicial bench or judge names.
  final String? honorableJudges;

  /// Optional tender number; stored as text to preserve leading zeroes.
  final String? tenderNumber;

  /// Case number from the previous court.
  final String? previousCourtCase;

  /// District where the case originated.
  final String? districtOfOrigin;

  /// Petitioner party label.
  final String petitioner;

  /// Petitioner's lead counsel.
  final String? petitionerLeadCounsel;

  /// Respondent party label.
  final String respondent;

  /// Respondent's lead counsel.
  final String? respondentLeadCounsel;

  /// Client representation role (e.g. Plaintiff, Defendant).
  final String onBehalfId;

  /// Complete party phone number, stored in international format.
  final String? partyPhone;

  /// Case description or specific legal sections.
  final String? caseTitleAndSection;

  /// Case summary/remarks.
  final String? caseRemarks;

  /// Next hearing date (epoch ms).
  final int? nextDate;

  /// Most recent court step, denormalized for fast list display.
  final String? lastStep;

  /// Notes or results from the last date.
  final String? notesResults;

  /// Separate result text used for AD/HCD disposal detection.
  final String? result;

  /// Creation timestamp (epoch ms).
  final int createdAt;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const Case({
    required this.id,
    required this.userId,
    this.firmId,
    required this.courtId,
    required this.caseType,
    this.caseCategoryId,
    required this.caseNumber,
    this.honorableJudges,
    this.tenderNumber,
    this.previousCourtCase,
    this.districtOfOrigin,
    required this.petitioner,
    this.petitionerLeadCounsel,
    required this.respondent,
    this.respondentLeadCounsel,
    required this.onBehalfId,
    this.partyPhone,
    this.caseTitleAndSection,
    this.caseRemarks,
    this.nextDate,
    this.lastStep,
    this.notesResults,
    this.result,
    required this.createdAt,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['court_id'] = Variable<String>(courtId);
    map['case_type'] = Variable<String>(caseType);
    if (!nullToAbsent || caseCategoryId != null) {
      map['case_category_id'] = Variable<String>(caseCategoryId);
    }
    map['case_number'] = Variable<String>(caseNumber);
    if (!nullToAbsent || honorableJudges != null) {
      map['honorable_judges'] = Variable<String>(honorableJudges);
    }
    if (!nullToAbsent || tenderNumber != null) {
      map['tender_number'] = Variable<String>(tenderNumber);
    }
    if (!nullToAbsent || previousCourtCase != null) {
      map['previous_court_case'] = Variable<String>(previousCourtCase);
    }
    if (!nullToAbsent || districtOfOrigin != null) {
      map['district_of_origin'] = Variable<String>(districtOfOrigin);
    }
    map['petitioner'] = Variable<String>(petitioner);
    if (!nullToAbsent || petitionerLeadCounsel != null) {
      map['petitioner_lead_counsel'] = Variable<String>(petitionerLeadCounsel);
    }
    map['respondent'] = Variable<String>(respondent);
    if (!nullToAbsent || respondentLeadCounsel != null) {
      map['respondent_lead_counsel'] = Variable<String>(respondentLeadCounsel);
    }
    map['on_behalf_id'] = Variable<String>(onBehalfId);
    if (!nullToAbsent || partyPhone != null) {
      map['party_phone'] = Variable<String>(partyPhone);
    }
    if (!nullToAbsent || caseTitleAndSection != null) {
      map['case_title_and_section'] = Variable<String>(caseTitleAndSection);
    }
    if (!nullToAbsent || caseRemarks != null) {
      map['case_remarks'] = Variable<String>(caseRemarks);
    }
    if (!nullToAbsent || nextDate != null) {
      map['next_date'] = Variable<int>(nextDate);
    }
    if (!nullToAbsent || lastStep != null) {
      map['last_step'] = Variable<String>(lastStep);
    }
    if (!nullToAbsent || notesResults != null) {
      map['notes_results'] = Variable<String>(notesResults);
    }
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  CasesCompanion toCompanion(bool nullToAbsent) {
    return CasesCompanion(
      id: Value(id),
      userId: Value(userId),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      courtId: Value(courtId),
      caseType: Value(caseType),
      caseCategoryId: caseCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(caseCategoryId),
      caseNumber: Value(caseNumber),
      honorableJudges: honorableJudges == null && nullToAbsent
          ? const Value.absent()
          : Value(honorableJudges),
      tenderNumber: tenderNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(tenderNumber),
      previousCourtCase: previousCourtCase == null && nullToAbsent
          ? const Value.absent()
          : Value(previousCourtCase),
      districtOfOrigin: districtOfOrigin == null && nullToAbsent
          ? const Value.absent()
          : Value(districtOfOrigin),
      petitioner: Value(petitioner),
      petitionerLeadCounsel: petitionerLeadCounsel == null && nullToAbsent
          ? const Value.absent()
          : Value(petitionerLeadCounsel),
      respondent: Value(respondent),
      respondentLeadCounsel: respondentLeadCounsel == null && nullToAbsent
          ? const Value.absent()
          : Value(respondentLeadCounsel),
      onBehalfId: Value(onBehalfId),
      partyPhone: partyPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(partyPhone),
      caseTitleAndSection: caseTitleAndSection == null && nullToAbsent
          ? const Value.absent()
          : Value(caseTitleAndSection),
      caseRemarks: caseRemarks == null && nullToAbsent
          ? const Value.absent()
          : Value(caseRemarks),
      nextDate: nextDate == null && nullToAbsent
          ? const Value.absent()
          : Value(nextDate),
      lastStep: lastStep == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStep),
      notesResults: notesResults == null && nullToAbsent
          ? const Value.absent()
          : Value(notesResults),
      result: result == null && nullToAbsent
          ? const Value.absent()
          : Value(result),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory Case.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Case(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      courtId: serializer.fromJson<String>(json['courtId']),
      caseType: serializer.fromJson<String>(json['caseType']),
      caseCategoryId: serializer.fromJson<String?>(json['caseCategoryId']),
      caseNumber: serializer.fromJson<String>(json['caseNumber']),
      honorableJudges: serializer.fromJson<String?>(json['honorableJudges']),
      tenderNumber: serializer.fromJson<String?>(json['tenderNumber']),
      previousCourtCase: serializer.fromJson<String?>(
        json['previousCourtCase'],
      ),
      districtOfOrigin: serializer.fromJson<String?>(json['districtOfOrigin']),
      petitioner: serializer.fromJson<String>(json['petitioner']),
      petitionerLeadCounsel: serializer.fromJson<String?>(
        json['petitionerLeadCounsel'],
      ),
      respondent: serializer.fromJson<String>(json['respondent']),
      respondentLeadCounsel: serializer.fromJson<String?>(
        json['respondentLeadCounsel'],
      ),
      onBehalfId: serializer.fromJson<String>(json['onBehalfId']),
      partyPhone: serializer.fromJson<String?>(json['partyPhone']),
      caseTitleAndSection: serializer.fromJson<String?>(
        json['caseTitleAndSection'],
      ),
      caseRemarks: serializer.fromJson<String?>(json['caseRemarks']),
      nextDate: serializer.fromJson<int?>(json['nextDate']),
      lastStep: serializer.fromJson<String?>(json['lastStep']),
      notesResults: serializer.fromJson<String?>(json['notesResults']),
      result: serializer.fromJson<String?>(json['result']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'firmId': serializer.toJson<String?>(firmId),
      'courtId': serializer.toJson<String>(courtId),
      'caseType': serializer.toJson<String>(caseType),
      'caseCategoryId': serializer.toJson<String?>(caseCategoryId),
      'caseNumber': serializer.toJson<String>(caseNumber),
      'honorableJudges': serializer.toJson<String?>(honorableJudges),
      'tenderNumber': serializer.toJson<String?>(tenderNumber),
      'previousCourtCase': serializer.toJson<String?>(previousCourtCase),
      'districtOfOrigin': serializer.toJson<String?>(districtOfOrigin),
      'petitioner': serializer.toJson<String>(petitioner),
      'petitionerLeadCounsel': serializer.toJson<String?>(
        petitionerLeadCounsel,
      ),
      'respondent': serializer.toJson<String>(respondent),
      'respondentLeadCounsel': serializer.toJson<String?>(
        respondentLeadCounsel,
      ),
      'onBehalfId': serializer.toJson<String>(onBehalfId),
      'partyPhone': serializer.toJson<String?>(partyPhone),
      'caseTitleAndSection': serializer.toJson<String?>(caseTitleAndSection),
      'caseRemarks': serializer.toJson<String?>(caseRemarks),
      'nextDate': serializer.toJson<int?>(nextDate),
      'lastStep': serializer.toJson<String?>(lastStep),
      'notesResults': serializer.toJson<String?>(notesResults),
      'result': serializer.toJson<String?>(result),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  Case copyWith({
    String? id,
    String? userId,
    Value<String?> firmId = const Value.absent(),
    String? courtId,
    String? caseType,
    Value<String?> caseCategoryId = const Value.absent(),
    String? caseNumber,
    Value<String?> honorableJudges = const Value.absent(),
    Value<String?> tenderNumber = const Value.absent(),
    Value<String?> previousCourtCase = const Value.absent(),
    Value<String?> districtOfOrigin = const Value.absent(),
    String? petitioner,
    Value<String?> petitionerLeadCounsel = const Value.absent(),
    String? respondent,
    Value<String?> respondentLeadCounsel = const Value.absent(),
    String? onBehalfId,
    Value<String?> partyPhone = const Value.absent(),
    Value<String?> caseTitleAndSection = const Value.absent(),
    Value<String?> caseRemarks = const Value.absent(),
    Value<int?> nextDate = const Value.absent(),
    Value<String?> lastStep = const Value.absent(),
    Value<String?> notesResults = const Value.absent(),
    Value<String?> result = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => Case(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    firmId: firmId.present ? firmId.value : this.firmId,
    courtId: courtId ?? this.courtId,
    caseType: caseType ?? this.caseType,
    caseCategoryId: caseCategoryId.present
        ? caseCategoryId.value
        : this.caseCategoryId,
    caseNumber: caseNumber ?? this.caseNumber,
    honorableJudges: honorableJudges.present
        ? honorableJudges.value
        : this.honorableJudges,
    tenderNumber: tenderNumber.present ? tenderNumber.value : this.tenderNumber,
    previousCourtCase: previousCourtCase.present
        ? previousCourtCase.value
        : this.previousCourtCase,
    districtOfOrigin: districtOfOrigin.present
        ? districtOfOrigin.value
        : this.districtOfOrigin,
    petitioner: petitioner ?? this.petitioner,
    petitionerLeadCounsel: petitionerLeadCounsel.present
        ? petitionerLeadCounsel.value
        : this.petitionerLeadCounsel,
    respondent: respondent ?? this.respondent,
    respondentLeadCounsel: respondentLeadCounsel.present
        ? respondentLeadCounsel.value
        : this.respondentLeadCounsel,
    onBehalfId: onBehalfId ?? this.onBehalfId,
    partyPhone: partyPhone.present ? partyPhone.value : this.partyPhone,
    caseTitleAndSection: caseTitleAndSection.present
        ? caseTitleAndSection.value
        : this.caseTitleAndSection,
    caseRemarks: caseRemarks.present ? caseRemarks.value : this.caseRemarks,
    nextDate: nextDate.present ? nextDate.value : this.nextDate,
    lastStep: lastStep.present ? lastStep.value : this.lastStep,
    notesResults: notesResults.present ? notesResults.value : this.notesResults,
    result: result.present ? result.value : this.result,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  Case copyWithCompanion(CasesCompanion data) {
    return Case(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      courtId: data.courtId.present ? data.courtId.value : this.courtId,
      caseType: data.caseType.present ? data.caseType.value : this.caseType,
      caseCategoryId: data.caseCategoryId.present
          ? data.caseCategoryId.value
          : this.caseCategoryId,
      caseNumber: data.caseNumber.present
          ? data.caseNumber.value
          : this.caseNumber,
      honorableJudges: data.honorableJudges.present
          ? data.honorableJudges.value
          : this.honorableJudges,
      tenderNumber: data.tenderNumber.present
          ? data.tenderNumber.value
          : this.tenderNumber,
      previousCourtCase: data.previousCourtCase.present
          ? data.previousCourtCase.value
          : this.previousCourtCase,
      districtOfOrigin: data.districtOfOrigin.present
          ? data.districtOfOrigin.value
          : this.districtOfOrigin,
      petitioner: data.petitioner.present
          ? data.petitioner.value
          : this.petitioner,
      petitionerLeadCounsel: data.petitionerLeadCounsel.present
          ? data.petitionerLeadCounsel.value
          : this.petitionerLeadCounsel,
      respondent: data.respondent.present
          ? data.respondent.value
          : this.respondent,
      respondentLeadCounsel: data.respondentLeadCounsel.present
          ? data.respondentLeadCounsel.value
          : this.respondentLeadCounsel,
      onBehalfId: data.onBehalfId.present
          ? data.onBehalfId.value
          : this.onBehalfId,
      partyPhone: data.partyPhone.present
          ? data.partyPhone.value
          : this.partyPhone,
      caseTitleAndSection: data.caseTitleAndSection.present
          ? data.caseTitleAndSection.value
          : this.caseTitleAndSection,
      caseRemarks: data.caseRemarks.present
          ? data.caseRemarks.value
          : this.caseRemarks,
      nextDate: data.nextDate.present ? data.nextDate.value : this.nextDate,
      lastStep: data.lastStep.present ? data.lastStep.value : this.lastStep,
      notesResults: data.notesResults.present
          ? data.notesResults.value
          : this.notesResults,
      result: data.result.present ? data.result.value : this.result,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Case(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('courtId: $courtId, ')
          ..write('caseType: $caseType, ')
          ..write('caseCategoryId: $caseCategoryId, ')
          ..write('caseNumber: $caseNumber, ')
          ..write('honorableJudges: $honorableJudges, ')
          ..write('tenderNumber: $tenderNumber, ')
          ..write('previousCourtCase: $previousCourtCase, ')
          ..write('districtOfOrigin: $districtOfOrigin, ')
          ..write('petitioner: $petitioner, ')
          ..write('petitionerLeadCounsel: $petitionerLeadCounsel, ')
          ..write('respondent: $respondent, ')
          ..write('respondentLeadCounsel: $respondentLeadCounsel, ')
          ..write('onBehalfId: $onBehalfId, ')
          ..write('partyPhone: $partyPhone, ')
          ..write('caseTitleAndSection: $caseTitleAndSection, ')
          ..write('caseRemarks: $caseRemarks, ')
          ..write('nextDate: $nextDate, ')
          ..write('lastStep: $lastStep, ')
          ..write('notesResults: $notesResults, ')
          ..write('result: $result, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    userId,
    firmId,
    courtId,
    caseType,
    caseCategoryId,
    caseNumber,
    honorableJudges,
    tenderNumber,
    previousCourtCase,
    districtOfOrigin,
    petitioner,
    petitionerLeadCounsel,
    respondent,
    respondentLeadCounsel,
    onBehalfId,
    partyPhone,
    caseTitleAndSection,
    caseRemarks,
    nextDate,
    lastStep,
    notesResults,
    result,
    createdAt,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Case &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.firmId == this.firmId &&
          other.courtId == this.courtId &&
          other.caseType == this.caseType &&
          other.caseCategoryId == this.caseCategoryId &&
          other.caseNumber == this.caseNumber &&
          other.honorableJudges == this.honorableJudges &&
          other.tenderNumber == this.tenderNumber &&
          other.previousCourtCase == this.previousCourtCase &&
          other.districtOfOrigin == this.districtOfOrigin &&
          other.petitioner == this.petitioner &&
          other.petitionerLeadCounsel == this.petitionerLeadCounsel &&
          other.respondent == this.respondent &&
          other.respondentLeadCounsel == this.respondentLeadCounsel &&
          other.onBehalfId == this.onBehalfId &&
          other.partyPhone == this.partyPhone &&
          other.caseTitleAndSection == this.caseTitleAndSection &&
          other.caseRemarks == this.caseRemarks &&
          other.nextDate == this.nextDate &&
          other.lastStep == this.lastStep &&
          other.notesResults == this.notesResults &&
          other.result == this.result &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class CasesCompanion extends UpdateCompanion<Case> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> firmId;
  final Value<String> courtId;
  final Value<String> caseType;
  final Value<String?> caseCategoryId;
  final Value<String> caseNumber;
  final Value<String?> honorableJudges;
  final Value<String?> tenderNumber;
  final Value<String?> previousCourtCase;
  final Value<String?> districtOfOrigin;
  final Value<String> petitioner;
  final Value<String?> petitionerLeadCounsel;
  final Value<String> respondent;
  final Value<String?> respondentLeadCounsel;
  final Value<String> onBehalfId;
  final Value<String?> partyPhone;
  final Value<String?> caseTitleAndSection;
  final Value<String?> caseRemarks;
  final Value<int?> nextDate;
  final Value<String?> lastStep;
  final Value<String?> notesResults;
  final Value<String?> result;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const CasesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    this.courtId = const Value.absent(),
    this.caseType = const Value.absent(),
    this.caseCategoryId = const Value.absent(),
    this.caseNumber = const Value.absent(),
    this.honorableJudges = const Value.absent(),
    this.tenderNumber = const Value.absent(),
    this.previousCourtCase = const Value.absent(),
    this.districtOfOrigin = const Value.absent(),
    this.petitioner = const Value.absent(),
    this.petitionerLeadCounsel = const Value.absent(),
    this.respondent = const Value.absent(),
    this.respondentLeadCounsel = const Value.absent(),
    this.onBehalfId = const Value.absent(),
    this.partyPhone = const Value.absent(),
    this.caseTitleAndSection = const Value.absent(),
    this.caseRemarks = const Value.absent(),
    this.nextDate = const Value.absent(),
    this.lastStep = const Value.absent(),
    this.notesResults = const Value.absent(),
    this.result = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CasesCompanion.insert({
    required String id,
    required String userId,
    this.firmId = const Value.absent(),
    required String courtId,
    required String caseType,
    this.caseCategoryId = const Value.absent(),
    required String caseNumber,
    this.honorableJudges = const Value.absent(),
    this.tenderNumber = const Value.absent(),
    this.previousCourtCase = const Value.absent(),
    this.districtOfOrigin = const Value.absent(),
    required String petitioner,
    this.petitionerLeadCounsel = const Value.absent(),
    required String respondent,
    this.respondentLeadCounsel = const Value.absent(),
    required String onBehalfId,
    this.partyPhone = const Value.absent(),
    this.caseTitleAndSection = const Value.absent(),
    this.caseRemarks = const Value.absent(),
    this.nextDate = const Value.absent(),
    this.lastStep = const Value.absent(),
    this.notesResults = const Value.absent(),
    this.result = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       courtId = Value(courtId),
       caseType = Value(caseType),
       caseNumber = Value(caseNumber),
       petitioner = Value(petitioner),
       respondent = Value(respondent),
       onBehalfId = Value(onBehalfId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Case> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? firmId,
    Expression<String>? courtId,
    Expression<String>? caseType,
    Expression<String>? caseCategoryId,
    Expression<String>? caseNumber,
    Expression<String>? honorableJudges,
    Expression<String>? tenderNumber,
    Expression<String>? previousCourtCase,
    Expression<String>? districtOfOrigin,
    Expression<String>? petitioner,
    Expression<String>? petitionerLeadCounsel,
    Expression<String>? respondent,
    Expression<String>? respondentLeadCounsel,
    Expression<String>? onBehalfId,
    Expression<String>? partyPhone,
    Expression<String>? caseTitleAndSection,
    Expression<String>? caseRemarks,
    Expression<int>? nextDate,
    Expression<String>? lastStep,
    Expression<String>? notesResults,
    Expression<String>? result,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (firmId != null) 'firm_id': firmId,
      if (courtId != null) 'court_id': courtId,
      if (caseType != null) 'case_type': caseType,
      if (caseCategoryId != null) 'case_category_id': caseCategoryId,
      if (caseNumber != null) 'case_number': caseNumber,
      if (honorableJudges != null) 'honorable_judges': honorableJudges,
      if (tenderNumber != null) 'tender_number': tenderNumber,
      if (previousCourtCase != null) 'previous_court_case': previousCourtCase,
      if (districtOfOrigin != null) 'district_of_origin': districtOfOrigin,
      if (petitioner != null) 'petitioner': petitioner,
      if (petitionerLeadCounsel != null)
        'petitioner_lead_counsel': petitionerLeadCounsel,
      if (respondent != null) 'respondent': respondent,
      if (respondentLeadCounsel != null)
        'respondent_lead_counsel': respondentLeadCounsel,
      if (onBehalfId != null) 'on_behalf_id': onBehalfId,
      if (partyPhone != null) 'party_phone': partyPhone,
      if (caseTitleAndSection != null)
        'case_title_and_section': caseTitleAndSection,
      if (caseRemarks != null) 'case_remarks': caseRemarks,
      if (nextDate != null) 'next_date': nextDate,
      if (lastStep != null) 'last_step': lastStep,
      if (notesResults != null) 'notes_results': notesResults,
      if (result != null) 'result': result,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CasesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? firmId,
    Value<String>? courtId,
    Value<String>? caseType,
    Value<String?>? caseCategoryId,
    Value<String>? caseNumber,
    Value<String?>? honorableJudges,
    Value<String?>? tenderNumber,
    Value<String?>? previousCourtCase,
    Value<String?>? districtOfOrigin,
    Value<String>? petitioner,
    Value<String?>? petitionerLeadCounsel,
    Value<String>? respondent,
    Value<String?>? respondentLeadCounsel,
    Value<String>? onBehalfId,
    Value<String?>? partyPhone,
    Value<String?>? caseTitleAndSection,
    Value<String?>? caseRemarks,
    Value<int?>? nextDate,
    Value<String?>? lastStep,
    Value<String?>? notesResults,
    Value<String?>? result,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return CasesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firmId: firmId ?? this.firmId,
      courtId: courtId ?? this.courtId,
      caseType: caseType ?? this.caseType,
      caseCategoryId: caseCategoryId ?? this.caseCategoryId,
      caseNumber: caseNumber ?? this.caseNumber,
      honorableJudges: honorableJudges ?? this.honorableJudges,
      tenderNumber: tenderNumber ?? this.tenderNumber,
      previousCourtCase: previousCourtCase ?? this.previousCourtCase,
      districtOfOrigin: districtOfOrigin ?? this.districtOfOrigin,
      petitioner: petitioner ?? this.petitioner,
      petitionerLeadCounsel:
          petitionerLeadCounsel ?? this.petitionerLeadCounsel,
      respondent: respondent ?? this.respondent,
      respondentLeadCounsel:
          respondentLeadCounsel ?? this.respondentLeadCounsel,
      onBehalfId: onBehalfId ?? this.onBehalfId,
      partyPhone: partyPhone ?? this.partyPhone,
      caseTitleAndSection: caseTitleAndSection ?? this.caseTitleAndSection,
      caseRemarks: caseRemarks ?? this.caseRemarks,
      nextDate: nextDate ?? this.nextDate,
      lastStep: lastStep ?? this.lastStep,
      notesResults: notesResults ?? this.notesResults,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (courtId.present) {
      map['court_id'] = Variable<String>(courtId.value);
    }
    if (caseType.present) {
      map['case_type'] = Variable<String>(caseType.value);
    }
    if (caseCategoryId.present) {
      map['case_category_id'] = Variable<String>(caseCategoryId.value);
    }
    if (caseNumber.present) {
      map['case_number'] = Variable<String>(caseNumber.value);
    }
    if (honorableJudges.present) {
      map['honorable_judges'] = Variable<String>(honorableJudges.value);
    }
    if (tenderNumber.present) {
      map['tender_number'] = Variable<String>(tenderNumber.value);
    }
    if (previousCourtCase.present) {
      map['previous_court_case'] = Variable<String>(previousCourtCase.value);
    }
    if (districtOfOrigin.present) {
      map['district_of_origin'] = Variable<String>(districtOfOrigin.value);
    }
    if (petitioner.present) {
      map['petitioner'] = Variable<String>(petitioner.value);
    }
    if (petitionerLeadCounsel.present) {
      map['petitioner_lead_counsel'] = Variable<String>(
        petitionerLeadCounsel.value,
      );
    }
    if (respondent.present) {
      map['respondent'] = Variable<String>(respondent.value);
    }
    if (respondentLeadCounsel.present) {
      map['respondent_lead_counsel'] = Variable<String>(
        respondentLeadCounsel.value,
      );
    }
    if (onBehalfId.present) {
      map['on_behalf_id'] = Variable<String>(onBehalfId.value);
    }
    if (partyPhone.present) {
      map['party_phone'] = Variable<String>(partyPhone.value);
    }
    if (caseTitleAndSection.present) {
      map['case_title_and_section'] = Variable<String>(
        caseTitleAndSection.value,
      );
    }
    if (caseRemarks.present) {
      map['case_remarks'] = Variable<String>(caseRemarks.value);
    }
    if (nextDate.present) {
      map['next_date'] = Variable<int>(nextDate.value);
    }
    if (lastStep.present) {
      map['last_step'] = Variable<String>(lastStep.value);
    }
    if (notesResults.present) {
      map['notes_results'] = Variable<String>(notesResults.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CasesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('courtId: $courtId, ')
          ..write('caseType: $caseType, ')
          ..write('caseCategoryId: $caseCategoryId, ')
          ..write('caseNumber: $caseNumber, ')
          ..write('honorableJudges: $honorableJudges, ')
          ..write('tenderNumber: $tenderNumber, ')
          ..write('previousCourtCase: $previousCourtCase, ')
          ..write('districtOfOrigin: $districtOfOrigin, ')
          ..write('petitioner: $petitioner, ')
          ..write('petitionerLeadCounsel: $petitionerLeadCounsel, ')
          ..write('respondent: $respondent, ')
          ..write('respondentLeadCounsel: $respondentLeadCounsel, ')
          ..write('onBehalfId: $onBehalfId, ')
          ..write('partyPhone: $partyPhone, ')
          ..write('caseTitleAndSection: $caseTitleAndSection, ')
          ..write('caseRemarks: $caseRemarks, ')
          ..write('nextDate: $nextDate, ')
          ..write('lastStep: $lastStep, ')
          ..write('notesResults: $notesResults, ')
          ..write('result: $result, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CaseHistoryTable extends CaseHistory
    with TableInfo<$CaseHistoryTable, CaseHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaseHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caseIdMeta = const VerificationMeta('caseId');
  @override
  late final GeneratedColumn<String> caseId = GeneratedColumn<String>(
    'case_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cases (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hearingDateMeta = const VerificationMeta(
    'hearingDate',
  );
  @override
  late final GeneratedColumn<int> hearingDate = GeneratedColumn<int>(
    'hearing_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastStepMeta = const VerificationMeta(
    'lastStep',
  );
  @override
  late final GeneratedColumn<String> lastStep = GeneratedColumn<String>(
    'last_step',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDateMeta = const VerificationMeta(
    'nextDate',
  );
  @override
  late final GeneratedColumn<int> nextDate = GeneratedColumn<int>(
    'next_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteResultMeta = const VerificationMeta(
    'noteResult',
  );
  @override
  late final GeneratedColumn<String> noteResult = GeneratedColumn<String>(
    'note_result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMutationIdMeta = const VerificationMeta(
    'sourceMutationId',
  );
  @override
  late final GeneratedColumn<String> sourceMutationId = GeneratedColumn<String>(
    'source_mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _baseCaseVersionMeta = const VerificationMeta(
    'baseCaseVersion',
  );
  @override
  late final GeneratedColumn<int> baseCaseVersion = GeneratedColumn<int>(
    'base_case_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultCaseVersionMeta = const VerificationMeta(
    'resultCaseVersion',
  );
  @override
  late final GeneratedColumn<int> resultCaseVersion = GeneratedColumn<int>(
    'result_case_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    caseId,
    userId,
    firmId,
    hearingDate,
    lastStep,
    nextDate,
    noteResult,
    result,
    createdBy,
    sourceMutationId,
    baseCaseVersion,
    resultCaseVersion,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'case_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaseHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('case_id')) {
      context.handle(
        _caseIdMeta,
        caseId.isAcceptableOrUnknown(data['case_id']!, _caseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_caseIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('hearing_date')) {
      context.handle(
        _hearingDateMeta,
        hearingDate.isAcceptableOrUnknown(
          data['hearing_date']!,
          _hearingDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hearingDateMeta);
    }
    if (data.containsKey('last_step')) {
      context.handle(
        _lastStepMeta,
        lastStep.isAcceptableOrUnknown(data['last_step']!, _lastStepMeta),
      );
    }
    if (data.containsKey('next_date')) {
      context.handle(
        _nextDateMeta,
        nextDate.isAcceptableOrUnknown(data['next_date']!, _nextDateMeta),
      );
    }
    if (data.containsKey('note_result')) {
      context.handle(
        _noteResultMeta,
        noteResult.isAcceptableOrUnknown(data['note_result']!, _noteResultMeta),
      );
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('source_mutation_id')) {
      context.handle(
        _sourceMutationIdMeta,
        sourceMutationId.isAcceptableOrUnknown(
          data['source_mutation_id']!,
          _sourceMutationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceMutationIdMeta);
    }
    if (data.containsKey('base_case_version')) {
      context.handle(
        _baseCaseVersionMeta,
        baseCaseVersion.isAcceptableOrUnknown(
          data['base_case_version']!,
          _baseCaseVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseCaseVersionMeta);
    }
    if (data.containsKey('result_case_version')) {
      context.handle(
        _resultCaseVersionMeta,
        resultCaseVersion.isAcceptableOrUnknown(
          data['result_case_version']!,
          _resultCaseVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resultCaseVersionMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaseHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaseHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      caseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      hearingDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hearing_date'],
      )!,
      lastStep: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_step'],
      ),
      nextDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_date'],
      ),
      noteResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_result'],
      ),
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      sourceMutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_mutation_id'],
      )!,
      baseCaseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_case_version'],
      )!,
      resultCaseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}result_case_version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $CaseHistoryTable createAlias(String alias) {
    return $CaseHistoryTable(attachedDatabase, alias);
  }
}

class CaseHistoryRow extends DataClass implements Insertable<CaseHistoryRow> {
  /// UUID primary key.
  final String id;

  /// Parent case.
  final String caseId;

  /// Denormalized owner for Realtime/RLS scoping.
  final String userId;

  /// Denormalized firm scope; null for individuals.
  final String? firmId;

  /// Date of the hearing (epoch ms).
  final int hearingDate;

  /// Court procedure step at this hearing.
  final String? lastStep;

  /// Next date set at this hearing (epoch ms).
  final int? nextDate;

  /// What happened at the hearing.
  final String? noteResult;

  /// AD/HCD result for this hearing (null for lower courts, which use steps).
  /// Snapshot of the case's `result` at the time the entry was frozen.
  final String? result;

  /// UUID of the user who logged this entry.
  final String createdBy;

  /// Unique idempotency key of the accepted mutation that created this row.
  final String sourceMutationId;

  /// Case version the accepted mutation was based on.
  final int baseCaseVersion;

  /// Server-assigned case version produced by the accepted mutation.
  final int resultCaseVersion;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const CaseHistoryRow({
    required this.id,
    required this.caseId,
    required this.userId,
    this.firmId,
    required this.hearingDate,
    this.lastStep,
    this.nextDate,
    this.noteResult,
    this.result,
    required this.createdBy,
    required this.sourceMutationId,
    required this.baseCaseVersion,
    required this.resultCaseVersion,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['case_id'] = Variable<String>(caseId);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['hearing_date'] = Variable<int>(hearingDate);
    if (!nullToAbsent || lastStep != null) {
      map['last_step'] = Variable<String>(lastStep);
    }
    if (!nullToAbsent || nextDate != null) {
      map['next_date'] = Variable<int>(nextDate);
    }
    if (!nullToAbsent || noteResult != null) {
      map['note_result'] = Variable<String>(noteResult);
    }
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    map['created_by'] = Variable<String>(createdBy);
    map['source_mutation_id'] = Variable<String>(sourceMutationId);
    map['base_case_version'] = Variable<int>(baseCaseVersion);
    map['result_case_version'] = Variable<int>(resultCaseVersion);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  CaseHistoryCompanion toCompanion(bool nullToAbsent) {
    return CaseHistoryCompanion(
      id: Value(id),
      caseId: Value(caseId),
      userId: Value(userId),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      hearingDate: Value(hearingDate),
      lastStep: lastStep == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStep),
      nextDate: nextDate == null && nullToAbsent
          ? const Value.absent()
          : Value(nextDate),
      noteResult: noteResult == null && nullToAbsent
          ? const Value.absent()
          : Value(noteResult),
      result: result == null && nullToAbsent
          ? const Value.absent()
          : Value(result),
      createdBy: Value(createdBy),
      sourceMutationId: Value(sourceMutationId),
      baseCaseVersion: Value(baseCaseVersion),
      resultCaseVersion: Value(resultCaseVersion),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory CaseHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaseHistoryRow(
      id: serializer.fromJson<String>(json['id']),
      caseId: serializer.fromJson<String>(json['caseId']),
      userId: serializer.fromJson<String>(json['userId']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      hearingDate: serializer.fromJson<int>(json['hearingDate']),
      lastStep: serializer.fromJson<String?>(json['lastStep']),
      nextDate: serializer.fromJson<int?>(json['nextDate']),
      noteResult: serializer.fromJson<String?>(json['noteResult']),
      result: serializer.fromJson<String?>(json['result']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      sourceMutationId: serializer.fromJson<String>(json['sourceMutationId']),
      baseCaseVersion: serializer.fromJson<int>(json['baseCaseVersion']),
      resultCaseVersion: serializer.fromJson<int>(json['resultCaseVersion']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'caseId': serializer.toJson<String>(caseId),
      'userId': serializer.toJson<String>(userId),
      'firmId': serializer.toJson<String?>(firmId),
      'hearingDate': serializer.toJson<int>(hearingDate),
      'lastStep': serializer.toJson<String?>(lastStep),
      'nextDate': serializer.toJson<int?>(nextDate),
      'noteResult': serializer.toJson<String?>(noteResult),
      'result': serializer.toJson<String?>(result),
      'createdBy': serializer.toJson<String>(createdBy),
      'sourceMutationId': serializer.toJson<String>(sourceMutationId),
      'baseCaseVersion': serializer.toJson<int>(baseCaseVersion),
      'resultCaseVersion': serializer.toJson<int>(resultCaseVersion),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  CaseHistoryRow copyWith({
    String? id,
    String? caseId,
    String? userId,
    Value<String?> firmId = const Value.absent(),
    int? hearingDate,
    Value<String?> lastStep = const Value.absent(),
    Value<int?> nextDate = const Value.absent(),
    Value<String?> noteResult = const Value.absent(),
    Value<String?> result = const Value.absent(),
    String? createdBy,
    String? sourceMutationId,
    int? baseCaseVersion,
    int? resultCaseVersion,
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => CaseHistoryRow(
    id: id ?? this.id,
    caseId: caseId ?? this.caseId,
    userId: userId ?? this.userId,
    firmId: firmId.present ? firmId.value : this.firmId,
    hearingDate: hearingDate ?? this.hearingDate,
    lastStep: lastStep.present ? lastStep.value : this.lastStep,
    nextDate: nextDate.present ? nextDate.value : this.nextDate,
    noteResult: noteResult.present ? noteResult.value : this.noteResult,
    result: result.present ? result.value : this.result,
    createdBy: createdBy ?? this.createdBy,
    sourceMutationId: sourceMutationId ?? this.sourceMutationId,
    baseCaseVersion: baseCaseVersion ?? this.baseCaseVersion,
    resultCaseVersion: resultCaseVersion ?? this.resultCaseVersion,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  CaseHistoryRow copyWithCompanion(CaseHistoryCompanion data) {
    return CaseHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      caseId: data.caseId.present ? data.caseId.value : this.caseId,
      userId: data.userId.present ? data.userId.value : this.userId,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      hearingDate: data.hearingDate.present
          ? data.hearingDate.value
          : this.hearingDate,
      lastStep: data.lastStep.present ? data.lastStep.value : this.lastStep,
      nextDate: data.nextDate.present ? data.nextDate.value : this.nextDate,
      noteResult: data.noteResult.present
          ? data.noteResult.value
          : this.noteResult,
      result: data.result.present ? data.result.value : this.result,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      sourceMutationId: data.sourceMutationId.present
          ? data.sourceMutationId.value
          : this.sourceMutationId,
      baseCaseVersion: data.baseCaseVersion.present
          ? data.baseCaseVersion.value
          : this.baseCaseVersion,
      resultCaseVersion: data.resultCaseVersion.present
          ? data.resultCaseVersion.value
          : this.resultCaseVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaseHistoryRow(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('hearingDate: $hearingDate, ')
          ..write('lastStep: $lastStep, ')
          ..write('nextDate: $nextDate, ')
          ..write('noteResult: $noteResult, ')
          ..write('result: $result, ')
          ..write('createdBy: $createdBy, ')
          ..write('sourceMutationId: $sourceMutationId, ')
          ..write('baseCaseVersion: $baseCaseVersion, ')
          ..write('resultCaseVersion: $resultCaseVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    caseId,
    userId,
    firmId,
    hearingDate,
    lastStep,
    nextDate,
    noteResult,
    result,
    createdBy,
    sourceMutationId,
    baseCaseVersion,
    resultCaseVersion,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaseHistoryRow &&
          other.id == this.id &&
          other.caseId == this.caseId &&
          other.userId == this.userId &&
          other.firmId == this.firmId &&
          other.hearingDate == this.hearingDate &&
          other.lastStep == this.lastStep &&
          other.nextDate == this.nextDate &&
          other.noteResult == this.noteResult &&
          other.result == this.result &&
          other.createdBy == this.createdBy &&
          other.sourceMutationId == this.sourceMutationId &&
          other.baseCaseVersion == this.baseCaseVersion &&
          other.resultCaseVersion == this.resultCaseVersion &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class CaseHistoryCompanion extends UpdateCompanion<CaseHistoryRow> {
  final Value<String> id;
  final Value<String> caseId;
  final Value<String> userId;
  final Value<String?> firmId;
  final Value<int> hearingDate;
  final Value<String?> lastStep;
  final Value<int?> nextDate;
  final Value<String?> noteResult;
  final Value<String?> result;
  final Value<String> createdBy;
  final Value<String> sourceMutationId;
  final Value<int> baseCaseVersion;
  final Value<int> resultCaseVersion;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const CaseHistoryCompanion({
    this.id = const Value.absent(),
    this.caseId = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    this.hearingDate = const Value.absent(),
    this.lastStep = const Value.absent(),
    this.nextDate = const Value.absent(),
    this.noteResult = const Value.absent(),
    this.result = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.sourceMutationId = const Value.absent(),
    this.baseCaseVersion = const Value.absent(),
    this.resultCaseVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaseHistoryCompanion.insert({
    required String id,
    required String caseId,
    required String userId,
    this.firmId = const Value.absent(),
    required int hearingDate,
    this.lastStep = const Value.absent(),
    this.nextDate = const Value.absent(),
    this.noteResult = const Value.absent(),
    this.result = const Value.absent(),
    required String createdBy,
    required String sourceMutationId,
    required int baseCaseVersion,
    required int resultCaseVersion,
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       caseId = Value(caseId),
       userId = Value(userId),
       hearingDate = Value(hearingDate),
       createdBy = Value(createdBy),
       sourceMutationId = Value(sourceMutationId),
       baseCaseVersion = Value(baseCaseVersion),
       resultCaseVersion = Value(resultCaseVersion),
       updatedAt = Value(updatedAt);
  static Insertable<CaseHistoryRow> custom({
    Expression<String>? id,
    Expression<String>? caseId,
    Expression<String>? userId,
    Expression<String>? firmId,
    Expression<int>? hearingDate,
    Expression<String>? lastStep,
    Expression<int>? nextDate,
    Expression<String>? noteResult,
    Expression<String>? result,
    Expression<String>? createdBy,
    Expression<String>? sourceMutationId,
    Expression<int>? baseCaseVersion,
    Expression<int>? resultCaseVersion,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (caseId != null) 'case_id': caseId,
      if (userId != null) 'user_id': userId,
      if (firmId != null) 'firm_id': firmId,
      if (hearingDate != null) 'hearing_date': hearingDate,
      if (lastStep != null) 'last_step': lastStep,
      if (nextDate != null) 'next_date': nextDate,
      if (noteResult != null) 'note_result': noteResult,
      if (result != null) 'result': result,
      if (createdBy != null) 'created_by': createdBy,
      if (sourceMutationId != null) 'source_mutation_id': sourceMutationId,
      if (baseCaseVersion != null) 'base_case_version': baseCaseVersion,
      if (resultCaseVersion != null) 'result_case_version': resultCaseVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaseHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? caseId,
    Value<String>? userId,
    Value<String?>? firmId,
    Value<int>? hearingDate,
    Value<String?>? lastStep,
    Value<int?>? nextDate,
    Value<String?>? noteResult,
    Value<String?>? result,
    Value<String>? createdBy,
    Value<String>? sourceMutationId,
    Value<int>? baseCaseVersion,
    Value<int>? resultCaseVersion,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return CaseHistoryCompanion(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      userId: userId ?? this.userId,
      firmId: firmId ?? this.firmId,
      hearingDate: hearingDate ?? this.hearingDate,
      lastStep: lastStep ?? this.lastStep,
      nextDate: nextDate ?? this.nextDate,
      noteResult: noteResult ?? this.noteResult,
      result: result ?? this.result,
      createdBy: createdBy ?? this.createdBy,
      sourceMutationId: sourceMutationId ?? this.sourceMutationId,
      baseCaseVersion: baseCaseVersion ?? this.baseCaseVersion,
      resultCaseVersion: resultCaseVersion ?? this.resultCaseVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (caseId.present) {
      map['case_id'] = Variable<String>(caseId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (hearingDate.present) {
      map['hearing_date'] = Variable<int>(hearingDate.value);
    }
    if (lastStep.present) {
      map['last_step'] = Variable<String>(lastStep.value);
    }
    if (nextDate.present) {
      map['next_date'] = Variable<int>(nextDate.value);
    }
    if (noteResult.present) {
      map['note_result'] = Variable<String>(noteResult.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (sourceMutationId.present) {
      map['source_mutation_id'] = Variable<String>(sourceMutationId.value);
    }
    if (baseCaseVersion.present) {
      map['base_case_version'] = Variable<int>(baseCaseVersion.value);
    }
    if (resultCaseVersion.present) {
      map['result_case_version'] = Variable<int>(resultCaseVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaseHistoryCompanion(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('hearingDate: $hearingDate, ')
          ..write('lastStep: $lastStep, ')
          ..write('nextDate: $nextDate, ')
          ..write('noteResult: $noteResult, ')
          ..write('result: $result, ')
          ..write('createdBy: $createdBy, ')
          ..write('sourceMutationId: $sourceMutationId, ')
          ..write('baseCaseVersion: $baseCaseVersion, ')
          ..write('resultCaseVersion: $resultCaseVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StepsTable extends Steps with TableInfo<$StepsTable, Step> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courtCategoryIdMeta = const VerificationMeta(
    'courtCategoryId',
  );
  @override
  late final GeneratedColumn<String> courtCategoryId = GeneratedColumn<String>(
    'court_category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES court_categories (id)',
    ),
  );
  static const VerificationMeta _stepNameMeta = const VerificationMeta(
    'stepName',
  );
  @override
  late final GeneratedColumn<String> stepName = GeneratedColumn<String>(
    'step_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isUserModifiedMeta = const VerificationMeta(
    'isUserModified',
  );
  @override
  late final GeneratedColumn<bool> isUserModified = GeneratedColumn<bool>(
    'is_user_modified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_user_modified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courtCategoryId,
    stepName,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'steps';
  @override
  VerificationContext validateIntegrity(
    Insertable<Step> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('court_category_id')) {
      context.handle(
        _courtCategoryIdMeta,
        courtCategoryId.isAcceptableOrUnknown(
          data['court_category_id']!,
          _courtCategoryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courtCategoryIdMeta);
    }
    if (data.containsKey('step_name')) {
      context.handle(
        _stepNameMeta,
        stepName.isAcceptableOrUnknown(data['step_name']!, _stepNameMeta),
      );
    } else if (isInserting) {
      context.missing(_stepNameMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('is_user_modified')) {
      context.handle(
        _isUserModifiedMeta,
        isUserModified.isAcceptableOrUnknown(
          data['is_user_modified']!,
          _isUserModifiedMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Step map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Step(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      courtCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}court_category_id'],
      )!,
      stepName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}step_name'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      isUserModified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_user_modified'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $StepsTable createAlias(String alias) {
    return $StepsTable(attachedDatabase, alias);
  }
}

class Step extends DataClass implements Insertable<Step> {
  /// UUID primary key.
  final String id;

  /// Court category this step belongs to.
  final String courtCategoryId;

  /// Display name of the step.
  final String stepName;

  /// Display order within the category.
  final int orderIndex;

  /// True if added by the user; false if pre-seeded.
  final bool isCustom;

  /// Whether the user/firm has modified a pre-seeded row.
  final bool isUserModified;

  /// Creator of custom step; null for pre-seeded.
  final String? userId;

  /// Firm scope; null for individuals & pre-seeded rows.
  final String? firmId;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const Step({
    required this.id,
    required this.courtCategoryId,
    required this.stepName,
    required this.orderIndex,
    required this.isCustom,
    required this.isUserModified,
    this.userId,
    this.firmId,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['court_category_id'] = Variable<String>(courtCategoryId);
    map['step_name'] = Variable<String>(stepName);
    map['order_index'] = Variable<int>(orderIndex);
    map['is_custom'] = Variable<bool>(isCustom);
    map['is_user_modified'] = Variable<bool>(isUserModified);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  StepsCompanion toCompanion(bool nullToAbsent) {
    return StepsCompanion(
      id: Value(id),
      courtCategoryId: Value(courtCategoryId),
      stepName: Value(stepName),
      orderIndex: Value(orderIndex),
      isCustom: Value(isCustom),
      isUserModified: Value(isUserModified),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory Step.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Step(
      id: serializer.fromJson<String>(json['id']),
      courtCategoryId: serializer.fromJson<String>(json['courtCategoryId']),
      stepName: serializer.fromJson<String>(json['stepName']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      isUserModified: serializer.fromJson<bool>(json['isUserModified']),
      userId: serializer.fromJson<String?>(json['userId']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'courtCategoryId': serializer.toJson<String>(courtCategoryId),
      'stepName': serializer.toJson<String>(stepName),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'isCustom': serializer.toJson<bool>(isCustom),
      'isUserModified': serializer.toJson<bool>(isUserModified),
      'userId': serializer.toJson<String?>(userId),
      'firmId': serializer.toJson<String?>(firmId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  Step copyWith({
    String? id,
    String? courtCategoryId,
    String? stepName,
    int? orderIndex,
    bool? isCustom,
    bool? isUserModified,
    Value<String?> userId = const Value.absent(),
    Value<String?> firmId = const Value.absent(),
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => Step(
    id: id ?? this.id,
    courtCategoryId: courtCategoryId ?? this.courtCategoryId,
    stepName: stepName ?? this.stepName,
    orderIndex: orderIndex ?? this.orderIndex,
    isCustom: isCustom ?? this.isCustom,
    isUserModified: isUserModified ?? this.isUserModified,
    userId: userId.present ? userId.value : this.userId,
    firmId: firmId.present ? firmId.value : this.firmId,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  Step copyWithCompanion(StepsCompanion data) {
    return Step(
      id: data.id.present ? data.id.value : this.id,
      courtCategoryId: data.courtCategoryId.present
          ? data.courtCategoryId.value
          : this.courtCategoryId,
      stepName: data.stepName.present ? data.stepName.value : this.stepName,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      isUserModified: data.isUserModified.present
          ? data.isUserModified.value
          : this.isUserModified,
      userId: data.userId.present ? data.userId.value : this.userId,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Step(')
          ..write('id: $id, ')
          ..write('courtCategoryId: $courtCategoryId, ')
          ..write('stepName: $stepName, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    courtCategoryId,
    stepName,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Step &&
          other.id == this.id &&
          other.courtCategoryId == this.courtCategoryId &&
          other.stepName == this.stepName &&
          other.orderIndex == this.orderIndex &&
          other.isCustom == this.isCustom &&
          other.isUserModified == this.isUserModified &&
          other.userId == this.userId &&
          other.firmId == this.firmId &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class StepsCompanion extends UpdateCompanion<Step> {
  final Value<String> id;
  final Value<String> courtCategoryId;
  final Value<String> stepName;
  final Value<int> orderIndex;
  final Value<bool> isCustom;
  final Value<bool> isUserModified;
  final Value<String?> userId;
  final Value<String?> firmId;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const StepsCompanion({
    this.id = const Value.absent(),
    this.courtCategoryId = const Value.absent(),
    this.stepName = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StepsCompanion.insert({
    required String id,
    required String courtCategoryId,
    required String stepName,
    required int orderIndex,
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courtCategoryId = Value(courtCategoryId),
       stepName = Value(stepName),
       orderIndex = Value(orderIndex),
       updatedAt = Value(updatedAt);
  static Insertable<Step> custom({
    Expression<String>? id,
    Expression<String>? courtCategoryId,
    Expression<String>? stepName,
    Expression<int>? orderIndex,
    Expression<bool>? isCustom,
    Expression<bool>? isUserModified,
    Expression<String>? userId,
    Expression<String>? firmId,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courtCategoryId != null) 'court_category_id': courtCategoryId,
      if (stepName != null) 'step_name': stepName,
      if (orderIndex != null) 'order_index': orderIndex,
      if (isCustom != null) 'is_custom': isCustom,
      if (isUserModified != null) 'is_user_modified': isUserModified,
      if (userId != null) 'user_id': userId,
      if (firmId != null) 'firm_id': firmId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StepsCompanion copyWith({
    Value<String>? id,
    Value<String>? courtCategoryId,
    Value<String>? stepName,
    Value<int>? orderIndex,
    Value<bool>? isCustom,
    Value<bool>? isUserModified,
    Value<String?>? userId,
    Value<String?>? firmId,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return StepsCompanion(
      id: id ?? this.id,
      courtCategoryId: courtCategoryId ?? this.courtCategoryId,
      stepName: stepName ?? this.stepName,
      orderIndex: orderIndex ?? this.orderIndex,
      isCustom: isCustom ?? this.isCustom,
      isUserModified: isUserModified ?? this.isUserModified,
      userId: userId ?? this.userId,
      firmId: firmId ?? this.firmId,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (courtCategoryId.present) {
      map['court_category_id'] = Variable<String>(courtCategoryId.value);
    }
    if (stepName.present) {
      map['step_name'] = Variable<String>(stepName.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (isUserModified.present) {
      map['is_user_modified'] = Variable<bool>(isUserModified.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StepsCompanion(')
          ..write('id: $id, ')
          ..write('courtCategoryId: $courtCategoryId, ')
          ..write('stepName: $stepName, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LawsTable extends Laws with TableInfo<$LawsTable, Law> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LawsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isUserModifiedMeta = const VerificationMeta(
    'isUserModified',
  );
  @override
  late final GeneratedColumn<bool> isUserModified = GeneratedColumn<bool>(
    'is_user_modified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_user_modified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    category,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'laws';
  @override
  VerificationContext validateIntegrity(
    Insertable<Law> instance, {
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
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('is_user_modified')) {
      context.handle(
        _isUserModifiedMeta,
        isUserModified.isAcceptableOrUnknown(
          data['is_user_modified']!,
          _isUserModifiedMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Law map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Law(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      isUserModified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_user_modified'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $LawsTable createAlias(String alias) {
    return $LawsTable(attachedDatabase, alias);
  }
}

class Law extends DataClass implements Insertable<Law> {
  /// Stable seed id for a built-in law, or a UUID for a user-added one.
  final String id;

  /// Display name, e.g. `The Penal Code, 1860`.
  final String name;

  /// The law category this name is listed under, as a stable ID from
  /// `seedLawCategories` (`criminal_law`, `family_personal_law`, …).
  ///
  /// A heading rather than a row: the seven categories are code, and the
  /// heading's label resolves through the matching `lawCategory_*` ARB key, so
  /// the list groups the same way in the app whatever the language. A blank
  /// value is a row an older build wrote before categories existed; it lists
  /// under Other until a seed migration fills it.
  final String category;

  /// Display order; seeded laws keep their seed order, a new name is appended.
  final int orderIndex;

  /// True if added by the user/firm; false if pre-seeded.
  final bool isCustom;

  /// Whether the user/firm has renamed a pre-seeded law.
  final bool isUserModified;

  /// Creator of a custom law; null for pre-seeded rows.
  final String? userId;

  /// Firm scope; null for individuals & pre-seeded rows.
  final String? firmId;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const Law({
    required this.id,
    required this.name,
    required this.category,
    required this.orderIndex,
    required this.isCustom,
    required this.isUserModified,
    this.userId,
    this.firmId,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['order_index'] = Variable<int>(orderIndex);
    map['is_custom'] = Variable<bool>(isCustom);
    map['is_user_modified'] = Variable<bool>(isUserModified);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  LawsCompanion toCompanion(bool nullToAbsent) {
    return LawsCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      orderIndex: Value(orderIndex),
      isCustom: Value(isCustom),
      isUserModified: Value(isUserModified),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory Law.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Law(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      isUserModified: serializer.fromJson<bool>(json['isUserModified']),
      userId: serializer.fromJson<String?>(json['userId']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'isCustom': serializer.toJson<bool>(isCustom),
      'isUserModified': serializer.toJson<bool>(isUserModified),
      'userId': serializer.toJson<String?>(userId),
      'firmId': serializer.toJson<String?>(firmId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  Law copyWith({
    String? id,
    String? name,
    String? category,
    int? orderIndex,
    bool? isCustom,
    bool? isUserModified,
    Value<String?> userId = const Value.absent(),
    Value<String?> firmId = const Value.absent(),
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => Law(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    orderIndex: orderIndex ?? this.orderIndex,
    isCustom: isCustom ?? this.isCustom,
    isUserModified: isUserModified ?? this.isUserModified,
    userId: userId.present ? userId.value : this.userId,
    firmId: firmId.present ? firmId.value : this.firmId,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  Law copyWithCompanion(LawsCompanion data) {
    return Law(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      isUserModified: data.isUserModified.present
          ? data.isUserModified.value
          : this.isUserModified,
      userId: data.userId.present ? data.userId.value : this.userId,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Law(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Law &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.orderIndex == this.orderIndex &&
          other.isCustom == this.isCustom &&
          other.isUserModified == this.isUserModified &&
          other.userId == this.userId &&
          other.firmId == this.firmId &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class LawsCompanion extends UpdateCompanion<Law> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> category;
  final Value<int> orderIndex;
  final Value<bool> isCustom;
  final Value<bool> isUserModified;
  final Value<String?> userId;
  final Value<String?> firmId;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const LawsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LawsCompanion.insert({
    required String id,
    required String name,
    this.category = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<Law> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<int>? orderIndex,
    Expression<bool>? isCustom,
    Expression<bool>? isUserModified,
    Expression<String>? userId,
    Expression<String>? firmId,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (orderIndex != null) 'order_index': orderIndex,
      if (isCustom != null) 'is_custom': isCustom,
      if (isUserModified != null) 'is_user_modified': isUserModified,
      if (userId != null) 'user_id': userId,
      if (firmId != null) 'firm_id': firmId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LawsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? category,
    Value<int>? orderIndex,
    Value<bool>? isCustom,
    Value<bool>? isUserModified,
    Value<String?>? userId,
    Value<String?>? firmId,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return LawsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      orderIndex: orderIndex ?? this.orderIndex,
      isCustom: isCustom ?? this.isCustom,
      isUserModified: isUserModified ?? this.isUserModified,
      userId: userId ?? this.userId,
      firmId: firmId ?? this.firmId,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
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
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (isUserModified.present) {
      map['is_user_modified'] = Variable<bool>(isUserModified.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LawsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CaseTypesTable extends CaseTypes
    with TableInfo<$CaseTypesTable, CaseType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaseTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courtCategoryIdMeta = const VerificationMeta(
    'courtCategoryId',
  );
  @override
  late final GeneratedColumn<String> courtCategoryId = GeneratedColumn<String>(
    'court_category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES court_categories (id)',
    ),
  );
  static const VerificationMeta _caseCategoryIdMeta = const VerificationMeta(
    'caseCategoryId',
  );
  @override
  late final GeneratedColumn<String> caseCategoryId = GeneratedColumn<String>(
    'case_category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES case_categories (id)',
    ),
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
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isUserModifiedMeta = const VerificationMeta(
    'isUserModified',
  );
  @override
  late final GeneratedColumn<bool> isUserModified = GeneratedColumn<bool>(
    'is_user_modified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_user_modified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courtCategoryId,
    caseCategoryId,
    name,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'case_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaseType> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('court_category_id')) {
      context.handle(
        _courtCategoryIdMeta,
        courtCategoryId.isAcceptableOrUnknown(
          data['court_category_id']!,
          _courtCategoryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courtCategoryIdMeta);
    }
    if (data.containsKey('case_category_id')) {
      context.handle(
        _caseCategoryIdMeta,
        caseCategoryId.isAcceptableOrUnknown(
          data['case_category_id']!,
          _caseCategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('is_user_modified')) {
      context.handle(
        _isUserModifiedMeta,
        isUserModified.isAcceptableOrUnknown(
          data['is_user_modified']!,
          _isUserModifiedMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaseType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaseType(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      courtCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}court_category_id'],
      )!,
      caseCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_category_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      isUserModified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_user_modified'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $CaseTypesTable createAlias(String alias) {
    return $CaseTypesTable(attachedDatabase, alias);
  }
}

class CaseType extends DataClass implements Insertable<CaseType> {
  /// UUID primary key.
  final String id;

  /// Court category this case type belongs to.
  final String courtCategoryId;

  /// Non-null only for AD/HCD types; lower-court types remain scoped by
  /// [courtCategoryId] alone.
  final String? caseCategoryId;

  /// Display name of the case type.
  final String name;

  /// Display order within the category.
  final int orderIndex;

  /// True if added by the user; false if pre-seeded.
  final bool isCustom;

  /// Whether the user/firm has modified a pre-seeded row.
  final bool isUserModified;

  /// Creator of custom case type; null for pre-seeded.
  final String? userId;

  /// Firm scope; null for individuals & pre-seeded rows.
  final String? firmId;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const CaseType({
    required this.id,
    required this.courtCategoryId,
    this.caseCategoryId,
    required this.name,
    required this.orderIndex,
    required this.isCustom,
    required this.isUserModified,
    this.userId,
    this.firmId,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['court_category_id'] = Variable<String>(courtCategoryId);
    if (!nullToAbsent || caseCategoryId != null) {
      map['case_category_id'] = Variable<String>(caseCategoryId);
    }
    map['name'] = Variable<String>(name);
    map['order_index'] = Variable<int>(orderIndex);
    map['is_custom'] = Variable<bool>(isCustom);
    map['is_user_modified'] = Variable<bool>(isUserModified);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  CaseTypesCompanion toCompanion(bool nullToAbsent) {
    return CaseTypesCompanion(
      id: Value(id),
      courtCategoryId: Value(courtCategoryId),
      caseCategoryId: caseCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(caseCategoryId),
      name: Value(name),
      orderIndex: Value(orderIndex),
      isCustom: Value(isCustom),
      isUserModified: Value(isUserModified),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory CaseType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaseType(
      id: serializer.fromJson<String>(json['id']),
      courtCategoryId: serializer.fromJson<String>(json['courtCategoryId']),
      caseCategoryId: serializer.fromJson<String?>(json['caseCategoryId']),
      name: serializer.fromJson<String>(json['name']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      isUserModified: serializer.fromJson<bool>(json['isUserModified']),
      userId: serializer.fromJson<String?>(json['userId']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'courtCategoryId': serializer.toJson<String>(courtCategoryId),
      'caseCategoryId': serializer.toJson<String?>(caseCategoryId),
      'name': serializer.toJson<String>(name),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'isCustom': serializer.toJson<bool>(isCustom),
      'isUserModified': serializer.toJson<bool>(isUserModified),
      'userId': serializer.toJson<String?>(userId),
      'firmId': serializer.toJson<String?>(firmId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  CaseType copyWith({
    String? id,
    String? courtCategoryId,
    Value<String?> caseCategoryId = const Value.absent(),
    String? name,
    int? orderIndex,
    bool? isCustom,
    bool? isUserModified,
    Value<String?> userId = const Value.absent(),
    Value<String?> firmId = const Value.absent(),
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => CaseType(
    id: id ?? this.id,
    courtCategoryId: courtCategoryId ?? this.courtCategoryId,
    caseCategoryId: caseCategoryId.present
        ? caseCategoryId.value
        : this.caseCategoryId,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
    isCustom: isCustom ?? this.isCustom,
    isUserModified: isUserModified ?? this.isUserModified,
    userId: userId.present ? userId.value : this.userId,
    firmId: firmId.present ? firmId.value : this.firmId,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  CaseType copyWithCompanion(CaseTypesCompanion data) {
    return CaseType(
      id: data.id.present ? data.id.value : this.id,
      courtCategoryId: data.courtCategoryId.present
          ? data.courtCategoryId.value
          : this.courtCategoryId,
      caseCategoryId: data.caseCategoryId.present
          ? data.caseCategoryId.value
          : this.caseCategoryId,
      name: data.name.present ? data.name.value : this.name,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      isUserModified: data.isUserModified.present
          ? data.isUserModified.value
          : this.isUserModified,
      userId: data.userId.present ? data.userId.value : this.userId,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaseType(')
          ..write('id: $id, ')
          ..write('courtCategoryId: $courtCategoryId, ')
          ..write('caseCategoryId: $caseCategoryId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    courtCategoryId,
    caseCategoryId,
    name,
    orderIndex,
    isCustom,
    isUserModified,
    userId,
    firmId,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaseType &&
          other.id == this.id &&
          other.courtCategoryId == this.courtCategoryId &&
          other.caseCategoryId == this.caseCategoryId &&
          other.name == this.name &&
          other.orderIndex == this.orderIndex &&
          other.isCustom == this.isCustom &&
          other.isUserModified == this.isUserModified &&
          other.userId == this.userId &&
          other.firmId == this.firmId &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class CaseTypesCompanion extends UpdateCompanion<CaseType> {
  final Value<String> id;
  final Value<String> courtCategoryId;
  final Value<String?> caseCategoryId;
  final Value<String> name;
  final Value<int> orderIndex;
  final Value<bool> isCustom;
  final Value<bool> isUserModified;
  final Value<String?> userId;
  final Value<String?> firmId;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const CaseTypesCompanion({
    this.id = const Value.absent(),
    this.courtCategoryId = const Value.absent(),
    this.caseCategoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaseTypesCompanion.insert({
    required String id,
    required String courtCategoryId,
    this.caseCategoryId = const Value.absent(),
    required String name,
    required int orderIndex,
    this.isCustom = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courtCategoryId = Value(courtCategoryId),
       name = Value(name),
       orderIndex = Value(orderIndex),
       updatedAt = Value(updatedAt);
  static Insertable<CaseType> custom({
    Expression<String>? id,
    Expression<String>? courtCategoryId,
    Expression<String>? caseCategoryId,
    Expression<String>? name,
    Expression<int>? orderIndex,
    Expression<bool>? isCustom,
    Expression<bool>? isUserModified,
    Expression<String>? userId,
    Expression<String>? firmId,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courtCategoryId != null) 'court_category_id': courtCategoryId,
      if (caseCategoryId != null) 'case_category_id': caseCategoryId,
      if (name != null) 'name': name,
      if (orderIndex != null) 'order_index': orderIndex,
      if (isCustom != null) 'is_custom': isCustom,
      if (isUserModified != null) 'is_user_modified': isUserModified,
      if (userId != null) 'user_id': userId,
      if (firmId != null) 'firm_id': firmId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaseTypesCompanion copyWith({
    Value<String>? id,
    Value<String>? courtCategoryId,
    Value<String?>? caseCategoryId,
    Value<String>? name,
    Value<int>? orderIndex,
    Value<bool>? isCustom,
    Value<bool>? isUserModified,
    Value<String?>? userId,
    Value<String?>? firmId,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return CaseTypesCompanion(
      id: id ?? this.id,
      courtCategoryId: courtCategoryId ?? this.courtCategoryId,
      caseCategoryId: caseCategoryId ?? this.caseCategoryId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      isCustom: isCustom ?? this.isCustom,
      isUserModified: isUserModified ?? this.isUserModified,
      userId: userId ?? this.userId,
      firmId: firmId ?? this.firmId,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (courtCategoryId.present) {
      map['court_category_id'] = Variable<String>(courtCategoryId.value);
    }
    if (caseCategoryId.present) {
      map['case_category_id'] = Variable<String>(caseCategoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (isUserModified.present) {
      map['is_user_modified'] = Variable<bool>(isUserModified.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaseTypesCompanion(')
          ..write('id: $id, ')
          ..write('courtCategoryId: $courtCategoryId, ')
          ..write('caseCategoryId: $caseCategoryId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isCustom: $isCustom, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsMeta = const VerificationMeta('items');
  @override
  late final GeneratedColumn<String> items = GeneratedColumn<String>(
    'items',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    firmId,
    title,
    body,
    items,
    isPinned,
    createdAt,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('items')) {
      context.handle(
        _itemsMeta,
        items.isAcceptableOrUnknown(data['items']!, _itemsMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      items: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  /// UUID primary key.
  final String id;

  /// Owner.
  final String userId;

  /// Firm scope; null for individual lawyers.
  final String? firmId;

  /// Note title.
  final String title;

  /// Note body.
  ///
  /// For a to-do note this mirrors the item texts, one per line, so the existing
  /// title+body search finds a to-do by what is on its list without parsing
  /// JSON. The checklist itself renders from [items].
  final String body;

  /// To-do checklist as a JSON array of `{text, done}` objects, in display
  /// order. Null for a plain text note; an empty to-do stores `[]`, so its kind
  /// never changes just because it has nothing on it yet.
  final String? items;

  /// Pinned notes appear first.
  final bool isPinned;

  /// Creation timestamp (epoch ms).
  final int createdAt;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const Note({
    required this.id,
    required this.userId,
    this.firmId,
    required this.title,
    required this.body,
    this.items,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || items != null) {
      map['items'] = Variable<String>(items);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      userId: Value(userId),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      title: Value(title),
      body: Value(body),
      items: items == null && nullToAbsent
          ? const Value.absent()
          : Value(items),
      isPinned: Value(isPinned),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      items: serializer.fromJson<String?>(json['items']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'firmId': serializer.toJson<String?>(firmId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'items': serializer.toJson<String?>(items),
      'isPinned': serializer.toJson<bool>(isPinned),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  Note copyWith({
    String? id,
    String? userId,
    Value<String?> firmId = const Value.absent(),
    String? title,
    String? body,
    Value<String?> items = const Value.absent(),
    bool? isPinned,
    int? createdAt,
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => Note(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    firmId: firmId.present ? firmId.value : this.firmId,
    title: title ?? this.title,
    body: body ?? this.body,
    items: items.present ? items.value : this.items,
    isPinned: isPinned ?? this.isPinned,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      items: data.items.present ? data.items.value : this.items,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('items: $items, ')
          ..write('isPinned: $isPinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    firmId,
    title,
    body,
    items,
    isPinned,
    createdAt,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.firmId == this.firmId &&
          other.title == this.title &&
          other.body == this.body &&
          other.items == this.items &&
          other.isPinned == this.isPinned &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> firmId;
  final Value<String> title;
  final Value<String> body;
  final Value<String?> items;
  final Value<bool> isPinned;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.items = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    required String userId,
    this.firmId = const Value.absent(),
    required String title,
    required String body,
    this.items = const Value.absent(),
    this.isPinned = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       title = Value(title),
       body = Value(body),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? firmId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? items,
    Expression<bool>? isPinned,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (firmId != null) 'firm_id': firmId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (items != null) 'items': items,
      if (isPinned != null) 'is_pinned': isPinned,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? firmId,
    Value<String>? title,
    Value<String>? body,
    Value<String?>? items,
    Value<bool>? isPinned,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firmId: firmId ?? this.firmId,
      title: title ?? this.title,
      body: body ?? this.body,
      items: items ?? this.items,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (items.present) {
      map['items'] = Variable<String>(items.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('items: $items, ')
          ..write('isPinned: $isPinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CaseReferencesTable extends CaseReferences
    with TableInfo<$CaseReferencesTable, CaseReference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaseReferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceAndPageNoMeta =
      const VerificationMeta('referenceAndPageNo');
  @override
  late final GeneratedColumn<String> referenceAndPageNo =
      GeneratedColumn<String>(
        'reference_and_page_no',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statuteMeta = const VerificationMeta(
    'statute',
  );
  @override
  late final GeneratedColumn<String> statute = GeneratedColumn<String>(
    'statute',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionOrArticleMeta = const VerificationMeta(
    'sectionOrArticle',
  );
  @override
  late final GeneratedColumn<String> sectionOrArticle = GeneratedColumn<String>(
    'section_or_article',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleAndDescriptionMeta =
      const VerificationMeta('titleAndDescription');
  @override
  late final GeneratedColumn<String> titleAndDescription =
      GeneratedColumn<String>(
        'title_and_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _commentsNotesMeta = const VerificationMeta(
    'commentsNotes',
  );
  @override
  late final GeneratedColumn<String> commentsNotes = GeneratedColumn<String>(
    'comments_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caseNoteMeta = const VerificationMeta(
    'caseNote',
  );
  @override
  late final GeneratedColumn<String> caseNote = GeneratedColumn<String>(
    'case_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    firmId,
    referenceAndPageNo,
    statute,
    sectionOrArticle,
    titleAndDescription,
    commentsNotes,
    caseNote,
    tags,
    isPinned,
    createdAt,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'case_references';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaseReference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('reference_and_page_no')) {
      context.handle(
        _referenceAndPageNoMeta,
        referenceAndPageNo.isAcceptableOrUnknown(
          data['reference_and_page_no']!,
          _referenceAndPageNoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_referenceAndPageNoMeta);
    }
    if (data.containsKey('statute')) {
      context.handle(
        _statuteMeta,
        statute.isAcceptableOrUnknown(data['statute']!, _statuteMeta),
      );
    }
    if (data.containsKey('section_or_article')) {
      context.handle(
        _sectionOrArticleMeta,
        sectionOrArticle.isAcceptableOrUnknown(
          data['section_or_article']!,
          _sectionOrArticleMeta,
        ),
      );
    }
    if (data.containsKey('title_and_description')) {
      context.handle(
        _titleAndDescriptionMeta,
        titleAndDescription.isAcceptableOrUnknown(
          data['title_and_description']!,
          _titleAndDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('comments_notes')) {
      context.handle(
        _commentsNotesMeta,
        commentsNotes.isAcceptableOrUnknown(
          data['comments_notes']!,
          _commentsNotesMeta,
        ),
      );
    }
    if (data.containsKey('case_note')) {
      context.handle(
        _caseNoteMeta,
        caseNote.isAcceptableOrUnknown(data['case_note']!, _caseNoteMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaseReference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaseReference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      referenceAndPageNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_and_page_no'],
      )!,
      statute: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statute'],
      ),
      sectionOrArticle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_or_article'],
      ),
      titleAndDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_and_description'],
      ),
      commentsNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comments_notes'],
      ),
      caseNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_note'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $CaseReferencesTable createAlias(String alias) {
    return $CaseReferencesTable(attachedDatabase, alias);
  }
}

class CaseReference extends DataClass implements Insertable<CaseReference> {
  /// UUID primary key.
  final String id;

  /// Owner.
  final String userId;

  /// Firm scope; null for individual lawyers.
  final String? firmId;

  /// Reference and page number.
  final String referenceAndPageNo;

  /// Statute or act name.
  final String? statute;

  /// Section or article number.
  final String? sectionOrArticle;

  /// Title and description.
  final String? titleAndDescription;

  /// Additional comments or notes.
  final String? commentsNotes;

  /// A note on the case itself, beside the case summary.
  final String? caseNote;

  /// Comma-separated tags used to group and find citations.
  final String? tags;

  /// Pinned references appear first.
  final bool isPinned;

  /// Creation timestamp (epoch ms).
  final int createdAt;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const CaseReference({
    required this.id,
    required this.userId,
    this.firmId,
    required this.referenceAndPageNo,
    this.statute,
    this.sectionOrArticle,
    this.titleAndDescription,
    this.commentsNotes,
    this.caseNote,
    this.tags,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['reference_and_page_no'] = Variable<String>(referenceAndPageNo);
    if (!nullToAbsent || statute != null) {
      map['statute'] = Variable<String>(statute);
    }
    if (!nullToAbsent || sectionOrArticle != null) {
      map['section_or_article'] = Variable<String>(sectionOrArticle);
    }
    if (!nullToAbsent || titleAndDescription != null) {
      map['title_and_description'] = Variable<String>(titleAndDescription);
    }
    if (!nullToAbsent || commentsNotes != null) {
      map['comments_notes'] = Variable<String>(commentsNotes);
    }
    if (!nullToAbsent || caseNote != null) {
      map['case_note'] = Variable<String>(caseNote);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  CaseReferencesCompanion toCompanion(bool nullToAbsent) {
    return CaseReferencesCompanion(
      id: Value(id),
      userId: Value(userId),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      referenceAndPageNo: Value(referenceAndPageNo),
      statute: statute == null && nullToAbsent
          ? const Value.absent()
          : Value(statute),
      sectionOrArticle: sectionOrArticle == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionOrArticle),
      titleAndDescription: titleAndDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(titleAndDescription),
      commentsNotes: commentsNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(commentsNotes),
      caseNote: caseNote == null && nullToAbsent
          ? const Value.absent()
          : Value(caseNote),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      isPinned: Value(isPinned),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory CaseReference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaseReference(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      referenceAndPageNo: serializer.fromJson<String>(
        json['referenceAndPageNo'],
      ),
      statute: serializer.fromJson<String?>(json['statute']),
      sectionOrArticle: serializer.fromJson<String?>(json['sectionOrArticle']),
      titleAndDescription: serializer.fromJson<String?>(
        json['titleAndDescription'],
      ),
      commentsNotes: serializer.fromJson<String?>(json['commentsNotes']),
      caseNote: serializer.fromJson<String?>(json['caseNote']),
      tags: serializer.fromJson<String?>(json['tags']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'firmId': serializer.toJson<String?>(firmId),
      'referenceAndPageNo': serializer.toJson<String>(referenceAndPageNo),
      'statute': serializer.toJson<String?>(statute),
      'sectionOrArticle': serializer.toJson<String?>(sectionOrArticle),
      'titleAndDescription': serializer.toJson<String?>(titleAndDescription),
      'commentsNotes': serializer.toJson<String?>(commentsNotes),
      'caseNote': serializer.toJson<String?>(caseNote),
      'tags': serializer.toJson<String?>(tags),
      'isPinned': serializer.toJson<bool>(isPinned),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  CaseReference copyWith({
    String? id,
    String? userId,
    Value<String?> firmId = const Value.absent(),
    String? referenceAndPageNo,
    Value<String?> statute = const Value.absent(),
    Value<String?> sectionOrArticle = const Value.absent(),
    Value<String?> titleAndDescription = const Value.absent(),
    Value<String?> commentsNotes = const Value.absent(),
    Value<String?> caseNote = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    bool? isPinned,
    int? createdAt,
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => CaseReference(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    firmId: firmId.present ? firmId.value : this.firmId,
    referenceAndPageNo: referenceAndPageNo ?? this.referenceAndPageNo,
    statute: statute.present ? statute.value : this.statute,
    sectionOrArticle: sectionOrArticle.present
        ? sectionOrArticle.value
        : this.sectionOrArticle,
    titleAndDescription: titleAndDescription.present
        ? titleAndDescription.value
        : this.titleAndDescription,
    commentsNotes: commentsNotes.present
        ? commentsNotes.value
        : this.commentsNotes,
    caseNote: caseNote.present ? caseNote.value : this.caseNote,
    tags: tags.present ? tags.value : this.tags,
    isPinned: isPinned ?? this.isPinned,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  CaseReference copyWithCompanion(CaseReferencesCompanion data) {
    return CaseReference(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      referenceAndPageNo: data.referenceAndPageNo.present
          ? data.referenceAndPageNo.value
          : this.referenceAndPageNo,
      statute: data.statute.present ? data.statute.value : this.statute,
      sectionOrArticle: data.sectionOrArticle.present
          ? data.sectionOrArticle.value
          : this.sectionOrArticle,
      titleAndDescription: data.titleAndDescription.present
          ? data.titleAndDescription.value
          : this.titleAndDescription,
      commentsNotes: data.commentsNotes.present
          ? data.commentsNotes.value
          : this.commentsNotes,
      caseNote: data.caseNote.present ? data.caseNote.value : this.caseNote,
      tags: data.tags.present ? data.tags.value : this.tags,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaseReference(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('referenceAndPageNo: $referenceAndPageNo, ')
          ..write('statute: $statute, ')
          ..write('sectionOrArticle: $sectionOrArticle, ')
          ..write('titleAndDescription: $titleAndDescription, ')
          ..write('commentsNotes: $commentsNotes, ')
          ..write('caseNote: $caseNote, ')
          ..write('tags: $tags, ')
          ..write('isPinned: $isPinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    firmId,
    referenceAndPageNo,
    statute,
    sectionOrArticle,
    titleAndDescription,
    commentsNotes,
    caseNote,
    tags,
    isPinned,
    createdAt,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaseReference &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.firmId == this.firmId &&
          other.referenceAndPageNo == this.referenceAndPageNo &&
          other.statute == this.statute &&
          other.sectionOrArticle == this.sectionOrArticle &&
          other.titleAndDescription == this.titleAndDescription &&
          other.commentsNotes == this.commentsNotes &&
          other.caseNote == this.caseNote &&
          other.tags == this.tags &&
          other.isPinned == this.isPinned &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class CaseReferencesCompanion extends UpdateCompanion<CaseReference> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> firmId;
  final Value<String> referenceAndPageNo;
  final Value<String?> statute;
  final Value<String?> sectionOrArticle;
  final Value<String?> titleAndDescription;
  final Value<String?> commentsNotes;
  final Value<String?> caseNote;
  final Value<String?> tags;
  final Value<bool> isPinned;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const CaseReferencesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.firmId = const Value.absent(),
    this.referenceAndPageNo = const Value.absent(),
    this.statute = const Value.absent(),
    this.sectionOrArticle = const Value.absent(),
    this.titleAndDescription = const Value.absent(),
    this.commentsNotes = const Value.absent(),
    this.caseNote = const Value.absent(),
    this.tags = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaseReferencesCompanion.insert({
    required String id,
    required String userId,
    this.firmId = const Value.absent(),
    required String referenceAndPageNo,
    this.statute = const Value.absent(),
    this.sectionOrArticle = const Value.absent(),
    this.titleAndDescription = const Value.absent(),
    this.commentsNotes = const Value.absent(),
    this.caseNote = const Value.absent(),
    this.tags = const Value.absent(),
    this.isPinned = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       referenceAndPageNo = Value(referenceAndPageNo),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CaseReference> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? firmId,
    Expression<String>? referenceAndPageNo,
    Expression<String>? statute,
    Expression<String>? sectionOrArticle,
    Expression<String>? titleAndDescription,
    Expression<String>? commentsNotes,
    Expression<String>? caseNote,
    Expression<String>? tags,
    Expression<bool>? isPinned,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (firmId != null) 'firm_id': firmId,
      if (referenceAndPageNo != null)
        'reference_and_page_no': referenceAndPageNo,
      if (statute != null) 'statute': statute,
      if (sectionOrArticle != null) 'section_or_article': sectionOrArticle,
      if (titleAndDescription != null)
        'title_and_description': titleAndDescription,
      if (commentsNotes != null) 'comments_notes': commentsNotes,
      if (caseNote != null) 'case_note': caseNote,
      if (tags != null) 'tags': tags,
      if (isPinned != null) 'is_pinned': isPinned,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaseReferencesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? firmId,
    Value<String>? referenceAndPageNo,
    Value<String?>? statute,
    Value<String?>? sectionOrArticle,
    Value<String?>? titleAndDescription,
    Value<String?>? commentsNotes,
    Value<String?>? caseNote,
    Value<String?>? tags,
    Value<bool>? isPinned,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return CaseReferencesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firmId: firmId ?? this.firmId,
      referenceAndPageNo: referenceAndPageNo ?? this.referenceAndPageNo,
      statute: statute ?? this.statute,
      sectionOrArticle: sectionOrArticle ?? this.sectionOrArticle,
      titleAndDescription: titleAndDescription ?? this.titleAndDescription,
      commentsNotes: commentsNotes ?? this.commentsNotes,
      caseNote: caseNote ?? this.caseNote,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (referenceAndPageNo.present) {
      map['reference_and_page_no'] = Variable<String>(referenceAndPageNo.value);
    }
    if (statute.present) {
      map['statute'] = Variable<String>(statute.value);
    }
    if (sectionOrArticle.present) {
      map['section_or_article'] = Variable<String>(sectionOrArticle.value);
    }
    if (titleAndDescription.present) {
      map['title_and_description'] = Variable<String>(
        titleAndDescription.value,
      );
    }
    if (commentsNotes.present) {
      map['comments_notes'] = Variable<String>(commentsNotes.value);
    }
    if (caseNote.present) {
      map['case_note'] = Variable<String>(caseNote.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaseReferencesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('firmId: $firmId, ')
          ..write('referenceAndPageNo: $referenceAndPageNo, ')
          ..write('statute: $statute, ')
          ..write('sectionOrArticle: $sectionOrArticle, ')
          ..write('titleAndDescription: $titleAndDescription, ')
          ..write('commentsNotes: $commentsNotes, ')
          ..write('caseNote: $caseNote, ')
          ..write('tags: $tags, ')
          ..write('isPinned: $isPinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeleteRequestsTable extends DeleteRequests
    with TableInfo<$DeleteRequestsTable, DeleteRequest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeleteRequestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entitySnapshotMeta = const VerificationMeta(
    'entitySnapshot',
  );
  @override
  late final GeneratedColumn<String> entitySnapshot = GeneratedColumn<String>(
    'entity_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetBaseVersionMeta = const VerificationMeta(
    'targetBaseVersion',
  );
  @override
  late final GeneratedColumn<int> targetBaseVersion = GeneratedColumn<int>(
    'target_base_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestedByMeta = const VerificationMeta(
    'requestedBy',
  );
  @override
  late final GeneratedColumn<String> requestedBy = GeneratedColumn<String>(
    'requested_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requesterNameMeta = const VerificationMeta(
    'requesterName',
  );
  @override
  late final GeneratedColumn<String> requesterName = GeneratedColumn<String>(
    'requester_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewedByMeta = const VerificationMeta(
    'reviewedBy',
  );
  @override
  late final GeneratedColumn<String> reviewedBy = GeneratedColumn<String>(
    'reviewed_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewNoteMeta = const VerificationMeta(
    'reviewNote',
  );
  @override
  late final GeneratedColumn<String> reviewNote = GeneratedColumn<String>(
    'review_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    firmId,
    entityType,
    entityId,
    entitySnapshot,
    targetBaseVersion,
    requestedBy,
    requesterName,
    status,
    reviewedBy,
    reviewNote,
    createdAt,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'delete_requests';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeleteRequest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('entity_snapshot')) {
      context.handle(
        _entitySnapshotMeta,
        entitySnapshot.isAcceptableOrUnknown(
          data['entity_snapshot']!,
          _entitySnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entitySnapshotMeta);
    }
    if (data.containsKey('target_base_version')) {
      context.handle(
        _targetBaseVersionMeta,
        targetBaseVersion.isAcceptableOrUnknown(
          data['target_base_version']!,
          _targetBaseVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetBaseVersionMeta);
    }
    if (data.containsKey('requested_by')) {
      context.handle(
        _requestedByMeta,
        requestedBy.isAcceptableOrUnknown(
          data['requested_by']!,
          _requestedByMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedByMeta);
    }
    if (data.containsKey('requester_name')) {
      context.handle(
        _requesterNameMeta,
        requesterName.isAcceptableOrUnknown(
          data['requester_name']!,
          _requesterNameMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('reviewed_by')) {
      context.handle(
        _reviewedByMeta,
        reviewedBy.isAcceptableOrUnknown(data['reviewed_by']!, _reviewedByMeta),
      );
    }
    if (data.containsKey('review_note')) {
      context.handle(
        _reviewNoteMeta,
        reviewNote.isAcceptableOrUnknown(data['review_note']!, _reviewNoteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeleteRequest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeleteRequest(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      entitySnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_snapshot'],
      )!,
      targetBaseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_base_version'],
      )!,
      requestedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}requested_by'],
      )!,
      requesterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}requester_name'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      reviewedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reviewed_by'],
      ),
      reviewNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}review_note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $DeleteRequestsTable createAlias(String alias) {
    return $DeleteRequestsTable(attachedDatabase, alias);
  }
}

class DeleteRequest extends DataClass implements Insertable<DeleteRequest> {
  /// UUID primary key.
  final String id;

  /// Firm this request belongs to; null for individual deletions.
  final String? firmId;

  /// Entity type (`case`, `case_history`, `note`, `reference`).
  final String entityType;

  /// UUID of the record to be deleted.
  final String entityId;

  /// JSON snapshot of the target at request time.
  final String entitySnapshot;

  /// Target version observed when the request was created.
  final int targetBaseVersion;

  /// The associate who requested deletion.
  final String requestedBy;

  /// The requester's display name, carried inside the request itself.
  ///
  /// A reviewer has to be able to see who asked while offline, and the
  /// `profiles` cache on their device holds the reader's own row rather than a
  /// colleague's — which is why the name travels on the request. Server-derived
  /// (see `20261026140000_delete_requests_requester_name.sql`), nullable because
  /// a request whose requester had no name yet still has to save.
  final String? requesterName;

  /// `pending`, `approved`, `rejected`, or `stale_review_required`.
  final String status;

  /// The user with can_delete who acted on it.
  final String? reviewedBy;

  /// Optional note from the reviewer.
  final String? reviewNote;

  /// Creation timestamp (epoch ms).
  final int createdAt;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const DeleteRequest({
    required this.id,
    this.firmId,
    required this.entityType,
    required this.entityId,
    required this.entitySnapshot,
    required this.targetBaseVersion,
    required this.requestedBy,
    this.requesterName,
    required this.status,
    this.reviewedBy,
    this.reviewNote,
    required this.createdAt,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['entity_snapshot'] = Variable<String>(entitySnapshot);
    map['target_base_version'] = Variable<int>(targetBaseVersion);
    map['requested_by'] = Variable<String>(requestedBy);
    if (!nullToAbsent || requesterName != null) {
      map['requester_name'] = Variable<String>(requesterName);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || reviewedBy != null) {
      map['reviewed_by'] = Variable<String>(reviewedBy);
    }
    if (!nullToAbsent || reviewNote != null) {
      map['review_note'] = Variable<String>(reviewNote);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  DeleteRequestsCompanion toCompanion(bool nullToAbsent) {
    return DeleteRequestsCompanion(
      id: Value(id),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      entitySnapshot: Value(entitySnapshot),
      targetBaseVersion: Value(targetBaseVersion),
      requestedBy: Value(requestedBy),
      requesterName: requesterName == null && nullToAbsent
          ? const Value.absent()
          : Value(requesterName),
      status: Value(status),
      reviewedBy: reviewedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewedBy),
      reviewNote: reviewNote == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewNote),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory DeleteRequest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeleteRequest(
      id: serializer.fromJson<String>(json['id']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      entitySnapshot: serializer.fromJson<String>(json['entitySnapshot']),
      targetBaseVersion: serializer.fromJson<int>(json['targetBaseVersion']),
      requestedBy: serializer.fromJson<String>(json['requestedBy']),
      requesterName: serializer.fromJson<String?>(json['requesterName']),
      status: serializer.fromJson<String>(json['status']),
      reviewedBy: serializer.fromJson<String?>(json['reviewedBy']),
      reviewNote: serializer.fromJson<String?>(json['reviewNote']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'firmId': serializer.toJson<String?>(firmId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'entitySnapshot': serializer.toJson<String>(entitySnapshot),
      'targetBaseVersion': serializer.toJson<int>(targetBaseVersion),
      'requestedBy': serializer.toJson<String>(requestedBy),
      'requesterName': serializer.toJson<String?>(requesterName),
      'status': serializer.toJson<String>(status),
      'reviewedBy': serializer.toJson<String?>(reviewedBy),
      'reviewNote': serializer.toJson<String?>(reviewNote),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  DeleteRequest copyWith({
    String? id,
    Value<String?> firmId = const Value.absent(),
    String? entityType,
    String? entityId,
    String? entitySnapshot,
    int? targetBaseVersion,
    String? requestedBy,
    Value<String?> requesterName = const Value.absent(),
    String? status,
    Value<String?> reviewedBy = const Value.absent(),
    Value<String?> reviewNote = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => DeleteRequest(
    id: id ?? this.id,
    firmId: firmId.present ? firmId.value : this.firmId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    entitySnapshot: entitySnapshot ?? this.entitySnapshot,
    targetBaseVersion: targetBaseVersion ?? this.targetBaseVersion,
    requestedBy: requestedBy ?? this.requestedBy,
    requesterName: requesterName.present
        ? requesterName.value
        : this.requesterName,
    status: status ?? this.status,
    reviewedBy: reviewedBy.present ? reviewedBy.value : this.reviewedBy,
    reviewNote: reviewNote.present ? reviewNote.value : this.reviewNote,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  DeleteRequest copyWithCompanion(DeleteRequestsCompanion data) {
    return DeleteRequest(
      id: data.id.present ? data.id.value : this.id,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entitySnapshot: data.entitySnapshot.present
          ? data.entitySnapshot.value
          : this.entitySnapshot,
      targetBaseVersion: data.targetBaseVersion.present
          ? data.targetBaseVersion.value
          : this.targetBaseVersion,
      requestedBy: data.requestedBy.present
          ? data.requestedBy.value
          : this.requestedBy,
      requesterName: data.requesterName.present
          ? data.requesterName.value
          : this.requesterName,
      status: data.status.present ? data.status.value : this.status,
      reviewedBy: data.reviewedBy.present
          ? data.reviewedBy.value
          : this.reviewedBy,
      reviewNote: data.reviewNote.present
          ? data.reviewNote.value
          : this.reviewNote,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeleteRequest(')
          ..write('id: $id, ')
          ..write('firmId: $firmId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('entitySnapshot: $entitySnapshot, ')
          ..write('targetBaseVersion: $targetBaseVersion, ')
          ..write('requestedBy: $requestedBy, ')
          ..write('requesterName: $requesterName, ')
          ..write('status: $status, ')
          ..write('reviewedBy: $reviewedBy, ')
          ..write('reviewNote: $reviewNote, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    firmId,
    entityType,
    entityId,
    entitySnapshot,
    targetBaseVersion,
    requestedBy,
    requesterName,
    status,
    reviewedBy,
    reviewNote,
    createdAt,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeleteRequest &&
          other.id == this.id &&
          other.firmId == this.firmId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.entitySnapshot == this.entitySnapshot &&
          other.targetBaseVersion == this.targetBaseVersion &&
          other.requestedBy == this.requestedBy &&
          other.requesterName == this.requesterName &&
          other.status == this.status &&
          other.reviewedBy == this.reviewedBy &&
          other.reviewNote == this.reviewNote &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class DeleteRequestsCompanion extends UpdateCompanion<DeleteRequest> {
  final Value<String> id;
  final Value<String?> firmId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> entitySnapshot;
  final Value<int> targetBaseVersion;
  final Value<String> requestedBy;
  final Value<String?> requesterName;
  final Value<String> status;
  final Value<String?> reviewedBy;
  final Value<String?> reviewNote;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const DeleteRequestsCompanion({
    this.id = const Value.absent(),
    this.firmId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entitySnapshot = const Value.absent(),
    this.targetBaseVersion = const Value.absent(),
    this.requestedBy = const Value.absent(),
    this.requesterName = const Value.absent(),
    this.status = const Value.absent(),
    this.reviewedBy = const Value.absent(),
    this.reviewNote = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeleteRequestsCompanion.insert({
    required String id,
    this.firmId = const Value.absent(),
    required String entityType,
    required String entityId,
    required String entitySnapshot,
    required int targetBaseVersion,
    required String requestedBy,
    this.requesterName = const Value.absent(),
    required String status,
    this.reviewedBy = const Value.absent(),
    this.reviewNote = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityType = Value(entityType),
       entityId = Value(entityId),
       entitySnapshot = Value(entitySnapshot),
       targetBaseVersion = Value(targetBaseVersion),
       requestedBy = Value(requestedBy),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DeleteRequest> custom({
    Expression<String>? id,
    Expression<String>? firmId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? entitySnapshot,
    Expression<int>? targetBaseVersion,
    Expression<String>? requestedBy,
    Expression<String>? requesterName,
    Expression<String>? status,
    Expression<String>? reviewedBy,
    Expression<String>? reviewNote,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (firmId != null) 'firm_id': firmId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (entitySnapshot != null) 'entity_snapshot': entitySnapshot,
      if (targetBaseVersion != null) 'target_base_version': targetBaseVersion,
      if (requestedBy != null) 'requested_by': requestedBy,
      if (requesterName != null) 'requester_name': requesterName,
      if (status != null) 'status': status,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      if (reviewNote != null) 'review_note': reviewNote,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeleteRequestsCompanion copyWith({
    Value<String>? id,
    Value<String?>? firmId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? entitySnapshot,
    Value<int>? targetBaseVersion,
    Value<String>? requestedBy,
    Value<String?>? requesterName,
    Value<String>? status,
    Value<String?>? reviewedBy,
    Value<String?>? reviewNote,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return DeleteRequestsCompanion(
      id: id ?? this.id,
      firmId: firmId ?? this.firmId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      entitySnapshot: entitySnapshot ?? this.entitySnapshot,
      targetBaseVersion: targetBaseVersion ?? this.targetBaseVersion,
      requestedBy: requestedBy ?? this.requestedBy,
      requesterName: requesterName ?? this.requesterName,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNote: reviewNote ?? this.reviewNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (entitySnapshot.present) {
      map['entity_snapshot'] = Variable<String>(entitySnapshot.value);
    }
    if (targetBaseVersion.present) {
      map['target_base_version'] = Variable<int>(targetBaseVersion.value);
    }
    if (requestedBy.present) {
      map['requested_by'] = Variable<String>(requestedBy.value);
    }
    if (requesterName.present) {
      map['requester_name'] = Variable<String>(requesterName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (reviewedBy.present) {
      map['reviewed_by'] = Variable<String>(reviewedBy.value);
    }
    if (reviewNote.present) {
      map['review_note'] = Variable<String>(reviewNote.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeleteRequestsCompanion(')
          ..write('id: $id, ')
          ..write('firmId: $firmId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('entitySnapshot: $entitySnapshot, ')
          ..write('targetBaseVersion: $targetBaseVersion, ')
          ..write('requestedBy: $requestedBy, ')
          ..write('requesterName: $requesterName, ')
          ..write('status: $status, ')
          ..write('reviewedBy: $reviewedBy, ')
          ..write('reviewNote: $reviewNote, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConflictLogTable extends ConflictLog
    with TableInfo<$ConflictLogTable, ConflictLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConflictLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _basePayloadMeta = const VerificationMeta(
    'basePayload',
  );
  @override
  late final GeneratedColumn<String> basePayload = GeneratedColumn<String>(
    'base_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _submittedPayloadMeta = const VerificationMeta(
    'submittedPayload',
  );
  @override
  late final GeneratedColumn<String> submittedPayload = GeneratedColumn<String>(
    'submitted_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changedFieldsMeta = const VerificationMeta(
    'changedFields',
  );
  @override
  late final GeneratedColumn<String> changedFields = GeneratedColumn<String>(
    'changed_fields',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverPayloadMeta = const VerificationMeta(
    'serverPayload',
  );
  @override
  late final GeneratedColumn<String> serverPayload = GeneratedColumn<String>(
    'server_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolutionStateMeta = const VerificationMeta(
    'resolutionState',
  );
  @override
  late final GeneratedColumn<String> resolutionState = GeneratedColumn<String>(
    'resolution_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conflictAtMeta = const VerificationMeta(
    'conflictAt',
  );
  @override
  late final GeneratedColumn<int> conflictAt = GeneratedColumn<int>(
    'conflict_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<int> resolvedAt = GeneratedColumn<int>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDismissedMeta = const VerificationMeta(
    'isDismissed',
  );
  @override
  late final GeneratedColumn<bool> isDismissed = GeneratedColumn<bool>(
    'is_dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_dismissed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _mergeableConflictMeta = const VerificationMeta(
    'mergeableConflict',
  );
  @override
  late final GeneratedColumn<bool> mergeableConflict = GeneratedColumn<bool>(
    'mergeable_conflict',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mergeable_conflict" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedByMeta = const VerificationMeta(
    'lastModifiedBy',
  );
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
    'last_modified_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mutationId,
    entityType,
    entityId,
    baseVersion,
    basePayload,
    submittedPayload,
    changedFields,
    serverVersion,
    serverPayload,
    resolutionState,
    conflictAt,
    resolvedAt,
    isDismissed,
    mergeableConflict,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conflict_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConflictLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseVersionMeta);
    }
    if (data.containsKey('base_payload')) {
      context.handle(
        _basePayloadMeta,
        basePayload.isAcceptableOrUnknown(
          data['base_payload']!,
          _basePayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_basePayloadMeta);
    }
    if (data.containsKey('submitted_payload')) {
      context.handle(
        _submittedPayloadMeta,
        submittedPayload.isAcceptableOrUnknown(
          data['submitted_payload']!,
          _submittedPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_submittedPayloadMeta);
    }
    if (data.containsKey('changed_fields')) {
      context.handle(
        _changedFieldsMeta,
        changedFields.isAcceptableOrUnknown(
          data['changed_fields']!,
          _changedFieldsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_changedFieldsMeta);
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverVersionMeta);
    }
    if (data.containsKey('server_payload')) {
      context.handle(
        _serverPayloadMeta,
        serverPayload.isAcceptableOrUnknown(
          data['server_payload']!,
          _serverPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverPayloadMeta);
    }
    if (data.containsKey('resolution_state')) {
      context.handle(
        _resolutionStateMeta,
        resolutionState.isAcceptableOrUnknown(
          data['resolution_state']!,
          _resolutionStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resolutionStateMeta);
    }
    if (data.containsKey('conflict_at')) {
      context.handle(
        _conflictAtMeta,
        conflictAt.isAcceptableOrUnknown(data['conflict_at']!, _conflictAtMeta),
      );
    } else if (isInserting) {
      context.missing(_conflictAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('is_dismissed')) {
      context.handle(
        _isDismissedMeta,
        isDismissed.isAcceptableOrUnknown(
          data['is_dismissed']!,
          _isDismissedMeta,
        ),
      );
    }
    if (data.containsKey('mergeable_conflict')) {
      context.handle(
        _mergeableConflictMeta,
        mergeableConflict.isAcceptableOrUnknown(
          data['mergeable_conflict']!,
          _mergeableConflictMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
        _lastModifiedByMeta,
        lastModifiedBy.isAcceptableOrUnknown(
          data['last_modified_by']!,
          _lastModifiedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConflictLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConflictLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      )!,
      basePayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_payload'],
      )!,
      submittedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}submitted_payload'],
      )!,
      changedFields: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changed_fields'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      serverPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_payload'],
      )!,
      resolutionState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_state'],
      )!,
      conflictAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}conflict_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolved_at'],
      ),
      isDismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_dismissed'],
      )!,
      mergeableConflict: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mergeable_conflict'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by'],
      ),
    );
  }

  @override
  $ConflictLogTable createAlias(String alias) {
    return $ConflictLogTable(attachedDatabase, alias);
  }
}

class ConflictLogRow extends DataClass implements Insertable<ConflictLogRow> {
  /// UUID primary key shared with the Supabase mirror.
  final String id;

  /// Stable ID of the rejected logical mutation.
  final String mutationId;

  /// Entity type (`case`, `case_history`, `note`, `reference`).
  final String entityType;

  /// UUID of the conflicted record.
  final String entityId;

  /// Server version the attempted mutation was based on.
  final int baseVersion;

  /// JSON snapshot of the common base.
  final String basePayload;

  /// JSON payload the client attempted to apply.
  final String submittedPayload;

  /// JSON array of intentionally changed fields.
  final String changedFields;

  /// Authoritative server version returned by push_changes.
  final int serverVersion;

  /// Authoritative row returned by push_changes.
  final String serverPayload;

  /// `unresolved`, `rebased`, `user_resolved`, or `discarded`.
  final String resolutionState;

  /// Conflict timestamp (epoch ms).
  final int conflictAt;

  /// Resolution timestamp (epoch ms); null while unresolved.
  final int? resolvedAt;

  /// UI acknowledgement only.
  final bool isDismissed;

  /// Whether the three-way comparison could merge this conflict automatically.
  ///
  /// True when the local and server changes touch disjoint fields, so the local
  /// edits can be rebased onto the authoritative row without a person deciding;
  /// false when they overlap, are semantically coupled, or involve a tombstone —
  /// the three cases the Review Conflict screen exists for. It is recorded at
  /// detection time (Task 19 Phase 3) and mirrored, so another device sees the
  /// same verdict instead of recomputing it from its own copy.
  final bool mergeableConflict;
  final int updatedAt;
  final int? version;
  final int? syncedAt;
  final bool isDeleted;
  final String? lastModifiedBy;
  const ConflictLogRow({
    required this.id,
    required this.mutationId,
    required this.entityType,
    required this.entityId,
    required this.baseVersion,
    required this.basePayload,
    required this.submittedPayload,
    required this.changedFields,
    required this.serverVersion,
    required this.serverPayload,
    required this.resolutionState,
    required this.conflictAt,
    this.resolvedAt,
    required this.isDismissed,
    required this.mergeableConflict,
    required this.updatedAt,
    this.version,
    this.syncedAt,
    required this.isDeleted,
    this.lastModifiedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mutation_id'] = Variable<String>(mutationId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['base_version'] = Variable<int>(baseVersion);
    map['base_payload'] = Variable<String>(basePayload);
    map['submitted_payload'] = Variable<String>(submittedPayload);
    map['changed_fields'] = Variable<String>(changedFields);
    map['server_version'] = Variable<int>(serverVersion);
    map['server_payload'] = Variable<String>(serverPayload);
    map['resolution_state'] = Variable<String>(resolutionState);
    map['conflict_at'] = Variable<int>(conflictAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<int>(resolvedAt);
    }
    map['is_dismissed'] = Variable<bool>(isDismissed);
    map['mergeable_conflict'] = Variable<bool>(mergeableConflict);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    return map;
  }

  ConflictLogCompanion toCompanion(bool nullToAbsent) {
    return ConflictLogCompanion(
      id: Value(id),
      mutationId: Value(mutationId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      baseVersion: Value(baseVersion),
      basePayload: Value(basePayload),
      submittedPayload: Value(submittedPayload),
      changedFields: Value(changedFields),
      serverVersion: Value(serverVersion),
      serverPayload: Value(serverPayload),
      resolutionState: Value(resolutionState),
      conflictAt: Value(conflictAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      isDismissed: Value(isDismissed),
      mergeableConflict: Value(mergeableConflict),
      updatedAt: Value(updatedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
    );
  }

  factory ConflictLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConflictLogRow(
      id: serializer.fromJson<String>(json['id']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      baseVersion: serializer.fromJson<int>(json['baseVersion']),
      basePayload: serializer.fromJson<String>(json['basePayload']),
      submittedPayload: serializer.fromJson<String>(json['submittedPayload']),
      changedFields: serializer.fromJson<String>(json['changedFields']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      serverPayload: serializer.fromJson<String>(json['serverPayload']),
      resolutionState: serializer.fromJson<String>(json['resolutionState']),
      conflictAt: serializer.fromJson<int>(json['conflictAt']),
      resolvedAt: serializer.fromJson<int?>(json['resolvedAt']),
      isDismissed: serializer.fromJson<bool>(json['isDismissed']),
      mergeableConflict: serializer.fromJson<bool>(json['mergeableConflict']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int?>(json['version']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mutationId': serializer.toJson<String>(mutationId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'baseVersion': serializer.toJson<int>(baseVersion),
      'basePayload': serializer.toJson<String>(basePayload),
      'submittedPayload': serializer.toJson<String>(submittedPayload),
      'changedFields': serializer.toJson<String>(changedFields),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'serverPayload': serializer.toJson<String>(serverPayload),
      'resolutionState': serializer.toJson<String>(resolutionState),
      'conflictAt': serializer.toJson<int>(conflictAt),
      'resolvedAt': serializer.toJson<int?>(resolvedAt),
      'isDismissed': serializer.toJson<bool>(isDismissed),
      'mergeableConflict': serializer.toJson<bool>(mergeableConflict),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int?>(version),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
    };
  }

  ConflictLogRow copyWith({
    String? id,
    String? mutationId,
    String? entityType,
    String? entityId,
    int? baseVersion,
    String? basePayload,
    String? submittedPayload,
    String? changedFields,
    int? serverVersion,
    String? serverPayload,
    String? resolutionState,
    int? conflictAt,
    Value<int?> resolvedAt = const Value.absent(),
    bool? isDismissed,
    bool? mergeableConflict,
    int? updatedAt,
    Value<int?> version = const Value.absent(),
    Value<int?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<String?> lastModifiedBy = const Value.absent(),
  }) => ConflictLogRow(
    id: id ?? this.id,
    mutationId: mutationId ?? this.mutationId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    baseVersion: baseVersion ?? this.baseVersion,
    basePayload: basePayload ?? this.basePayload,
    submittedPayload: submittedPayload ?? this.submittedPayload,
    changedFields: changedFields ?? this.changedFields,
    serverVersion: serverVersion ?? this.serverVersion,
    serverPayload: serverPayload ?? this.serverPayload,
    resolutionState: resolutionState ?? this.resolutionState,
    conflictAt: conflictAt ?? this.conflictAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    isDismissed: isDismissed ?? this.isDismissed,
    mergeableConflict: mergeableConflict ?? this.mergeableConflict,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version.present ? version.value : this.version,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    lastModifiedBy: lastModifiedBy.present
        ? lastModifiedBy.value
        : this.lastModifiedBy,
  );
  ConflictLogRow copyWithCompanion(ConflictLogCompanion data) {
    return ConflictLogRow(
      id: data.id.present ? data.id.value : this.id,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      basePayload: data.basePayload.present
          ? data.basePayload.value
          : this.basePayload,
      submittedPayload: data.submittedPayload.present
          ? data.submittedPayload.value
          : this.submittedPayload,
      changedFields: data.changedFields.present
          ? data.changedFields.value
          : this.changedFields,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      serverPayload: data.serverPayload.present
          ? data.serverPayload.value
          : this.serverPayload,
      resolutionState: data.resolutionState.present
          ? data.resolutionState.value
          : this.resolutionState,
      conflictAt: data.conflictAt.present
          ? data.conflictAt.value
          : this.conflictAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      isDismissed: data.isDismissed.present
          ? data.isDismissed.value
          : this.isDismissed,
      mergeableConflict: data.mergeableConflict.present
          ? data.mergeableConflict.value
          : this.mergeableConflict,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConflictLogRow(')
          ..write('id: $id, ')
          ..write('mutationId: $mutationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('basePayload: $basePayload, ')
          ..write('submittedPayload: $submittedPayload, ')
          ..write('changedFields: $changedFields, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('serverPayload: $serverPayload, ')
          ..write('resolutionState: $resolutionState, ')
          ..write('conflictAt: $conflictAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('isDismissed: $isDismissed, ')
          ..write('mergeableConflict: $mergeableConflict, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mutationId,
    entityType,
    entityId,
    baseVersion,
    basePayload,
    submittedPayload,
    changedFields,
    serverVersion,
    serverPayload,
    resolutionState,
    conflictAt,
    resolvedAt,
    isDismissed,
    mergeableConflict,
    updatedAt,
    version,
    syncedAt,
    isDeleted,
    lastModifiedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConflictLogRow &&
          other.id == this.id &&
          other.mutationId == this.mutationId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.baseVersion == this.baseVersion &&
          other.basePayload == this.basePayload &&
          other.submittedPayload == this.submittedPayload &&
          other.changedFields == this.changedFields &&
          other.serverVersion == this.serverVersion &&
          other.serverPayload == this.serverPayload &&
          other.resolutionState == this.resolutionState &&
          other.conflictAt == this.conflictAt &&
          other.resolvedAt == this.resolvedAt &&
          other.isDismissed == this.isDismissed &&
          other.mergeableConflict == this.mergeableConflict &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.lastModifiedBy == this.lastModifiedBy);
}

class ConflictLogCompanion extends UpdateCompanion<ConflictLogRow> {
  final Value<String> id;
  final Value<String> mutationId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> baseVersion;
  final Value<String> basePayload;
  final Value<String> submittedPayload;
  final Value<String> changedFields;
  final Value<int> serverVersion;
  final Value<String> serverPayload;
  final Value<String> resolutionState;
  final Value<int> conflictAt;
  final Value<int?> resolvedAt;
  final Value<bool> isDismissed;
  final Value<bool> mergeableConflict;
  final Value<int> updatedAt;
  final Value<int?> version;
  final Value<int?> syncedAt;
  final Value<bool> isDeleted;
  final Value<String?> lastModifiedBy;
  final Value<int> rowid;
  const ConflictLogCompanion({
    this.id = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.basePayload = const Value.absent(),
    this.submittedPayload = const Value.absent(),
    this.changedFields = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.serverPayload = const Value.absent(),
    this.resolutionState = const Value.absent(),
    this.conflictAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.isDismissed = const Value.absent(),
    this.mergeableConflict = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConflictLogCompanion.insert({
    required String id,
    required String mutationId,
    required String entityType,
    required String entityId,
    required int baseVersion,
    required String basePayload,
    required String submittedPayload,
    required String changedFields,
    required int serverVersion,
    required String serverPayload,
    required String resolutionState,
    required int conflictAt,
    this.resolvedAt = const Value.absent(),
    this.isDismissed = const Value.absent(),
    this.mergeableConflict = const Value.absent(),
    required int updatedAt,
    this.version = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mutationId = Value(mutationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       baseVersion = Value(baseVersion),
       basePayload = Value(basePayload),
       submittedPayload = Value(submittedPayload),
       changedFields = Value(changedFields),
       serverVersion = Value(serverVersion),
       serverPayload = Value(serverPayload),
       resolutionState = Value(resolutionState),
       conflictAt = Value(conflictAt),
       updatedAt = Value(updatedAt);
  static Insertable<ConflictLogRow> custom({
    Expression<String>? id,
    Expression<String>? mutationId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? baseVersion,
    Expression<String>? basePayload,
    Expression<String>? submittedPayload,
    Expression<String>? changedFields,
    Expression<int>? serverVersion,
    Expression<String>? serverPayload,
    Expression<String>? resolutionState,
    Expression<int>? conflictAt,
    Expression<int>? resolvedAt,
    Expression<bool>? isDismissed,
    Expression<bool>? mergeableConflict,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<String>? lastModifiedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mutationId != null) 'mutation_id': mutationId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (baseVersion != null) 'base_version': baseVersion,
      if (basePayload != null) 'base_payload': basePayload,
      if (submittedPayload != null) 'submitted_payload': submittedPayload,
      if (changedFields != null) 'changed_fields': changedFields,
      if (serverVersion != null) 'server_version': serverVersion,
      if (serverPayload != null) 'server_payload': serverPayload,
      if (resolutionState != null) 'resolution_state': resolutionState,
      if (conflictAt != null) 'conflict_at': conflictAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (isDismissed != null) 'is_dismissed': isDismissed,
      if (mergeableConflict != null) 'mergeable_conflict': mergeableConflict,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConflictLogCompanion copyWith({
    Value<String>? id,
    Value<String>? mutationId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? baseVersion,
    Value<String>? basePayload,
    Value<String>? submittedPayload,
    Value<String>? changedFields,
    Value<int>? serverVersion,
    Value<String>? serverPayload,
    Value<String>? resolutionState,
    Value<int>? conflictAt,
    Value<int?>? resolvedAt,
    Value<bool>? isDismissed,
    Value<bool>? mergeableConflict,
    Value<int>? updatedAt,
    Value<int?>? version,
    Value<int?>? syncedAt,
    Value<bool>? isDeleted,
    Value<String?>? lastModifiedBy,
    Value<int>? rowid,
  }) {
    return ConflictLogCompanion(
      id: id ?? this.id,
      mutationId: mutationId ?? this.mutationId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      baseVersion: baseVersion ?? this.baseVersion,
      basePayload: basePayload ?? this.basePayload,
      submittedPayload: submittedPayload ?? this.submittedPayload,
      changedFields: changedFields ?? this.changedFields,
      serverVersion: serverVersion ?? this.serverVersion,
      serverPayload: serverPayload ?? this.serverPayload,
      resolutionState: resolutionState ?? this.resolutionState,
      conflictAt: conflictAt ?? this.conflictAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      isDismissed: isDismissed ?? this.isDismissed,
      mergeableConflict: mergeableConflict ?? this.mergeableConflict,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (basePayload.present) {
      map['base_payload'] = Variable<String>(basePayload.value);
    }
    if (submittedPayload.present) {
      map['submitted_payload'] = Variable<String>(submittedPayload.value);
    }
    if (changedFields.present) {
      map['changed_fields'] = Variable<String>(changedFields.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (serverPayload.present) {
      map['server_payload'] = Variable<String>(serverPayload.value);
    }
    if (resolutionState.present) {
      map['resolution_state'] = Variable<String>(resolutionState.value);
    }
    if (conflictAt.present) {
      map['conflict_at'] = Variable<int>(conflictAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<int>(resolvedAt.value);
    }
    if (isDismissed.present) {
      map['is_dismissed'] = Variable<bool>(isDismissed.value);
    }
    if (mergeableConflict.present) {
      map['mergeable_conflict'] = Variable<bool>(mergeableConflict.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConflictLogCompanion(')
          ..write('id: $id, ')
          ..write('mutationId: $mutationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('basePayload: $basePayload, ')
          ..write('submittedPayload: $submittedPayload, ')
          ..write('changedFields: $changedFields, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('serverPayload: $serverPayload, ')
          ..write('resolutionState: $resolutionState, ')
          ..write('conflictAt: $conflictAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('isDismissed: $isDismissed, ')
          ..write('mergeableConflict: $mergeableConflict, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FirmsTable extends Firms with TableInfo<$FirmsTable, Firm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FirmsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _logoPathMeta = const VerificationMeta(
    'logoPath',
  );
  @override
  late final GeneratedColumn<String> logoPath = GeneratedColumn<String>(
    'logo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoVersionMeta = const VerificationMeta(
    'logoVersion',
  );
  @override
  late final GeneratedColumn<int> logoVersion = GeneratedColumn<int>(
    'logo_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subscriptionStatusMeta =
      const VerificationMeta('subscriptionStatus');
  @override
  late final GeneratedColumn<String> subscriptionStatus =
      GeneratedColumn<String>(
        'subscription_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _subscriptionExpiryMeta =
      const VerificationMeta('subscriptionExpiry');
  @override
  late final GeneratedColumn<int> subscriptionExpiry = GeneratedColumn<int>(
    'subscription_expiry',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('free'),
  );
  static const VerificationMeta _tierPendingMeta = const VerificationMeta(
    'tierPending',
  );
  @override
  late final GeneratedColumn<String> tierPending = GeneratedColumn<String>(
    'tier_pending',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tierPendingFromMeta = const VerificationMeta(
    'tierPendingFrom',
  );
  @override
  late final GeneratedColumn<int> tierPendingFrom = GeneratedColumn<int>(
    'tier_pending_from',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    logoPath,
    logoVersion,
    ownerId,
    subscriptionStatus,
    subscriptionExpiry,
    tier,
    tierPending,
    tierPendingFrom,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'firms';
  @override
  VerificationContext validateIntegrity(
    Insertable<Firm> instance, {
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
    if (data.containsKey('logo_path')) {
      context.handle(
        _logoPathMeta,
        logoPath.isAcceptableOrUnknown(data['logo_path']!, _logoPathMeta),
      );
    }
    if (data.containsKey('logo_version')) {
      context.handle(
        _logoVersionMeta,
        logoVersion.isAcceptableOrUnknown(
          data['logo_version']!,
          _logoVersionMeta,
        ),
      );
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('subscription_status')) {
      context.handle(
        _subscriptionStatusMeta,
        subscriptionStatus.isAcceptableOrUnknown(
          data['subscription_status']!,
          _subscriptionStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subscriptionStatusMeta);
    }
    if (data.containsKey('subscription_expiry')) {
      context.handle(
        _subscriptionExpiryMeta,
        subscriptionExpiry.isAcceptableOrUnknown(
          data['subscription_expiry']!,
          _subscriptionExpiryMeta,
        ),
      );
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    }
    if (data.containsKey('tier_pending')) {
      context.handle(
        _tierPendingMeta,
        tierPending.isAcceptableOrUnknown(
          data['tier_pending']!,
          _tierPendingMeta,
        ),
      );
    }
    if (data.containsKey('tier_pending_from')) {
      context.handle(
        _tierPendingFromMeta,
        tierPendingFrom.isAcceptableOrUnknown(
          data['tier_pending_from']!,
          _tierPendingFromMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Firm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Firm(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      logoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_path'],
      ),
      logoVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}logo_version'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      subscriptionStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subscription_status'],
      )!,
      subscriptionExpiry: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subscription_expiry'],
      ),
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      tierPending: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier_pending'],
      ),
      tierPendingFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tier_pending_from'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FirmsTable createAlias(String alias) {
    return $FirmsTable(attachedDatabase, alias);
  }
}

class Firm extends DataClass implements Insertable<Firm> {
  /// UUID primary key (mirrors Supabase PK).
  final String id;

  /// Firm display name.
  final String name;

  /// Object name of the chamber logo in the `firm-avatars` bucket, or null.
  ///
  /// Server-written by the storage trigger, never by a device.
  final String? logoPath;

  /// Bumped by the server on every logo write or delete.
  ///
  /// A member's device compares it with the version it last downloaded, so a
  /// changed or removed logo is noticed on the next profile refresh.
  final int logoVersion;

  /// Firm owner UUID.
  final String ownerId;

  /// Subscription status (e.g. `active`, `trial`, `expired`).
  final String subscriptionStatus;

  /// Subscription expiry converted from Supabase TIMESTAMPTZ to epoch ms.
  final int? subscriptionExpiry;

  /// The chamber's subscription tier, mirrored from its owner's plan:
  /// `free`, `starter`, `pro`, `firm`, `firm_plus` or `enterprise`.
  ///
  /// This row is the chamber's **source of the seat cap** — Starter and Pro 0,
  /// Firm 5, Firm Plus 12, Enterprise unlimited — and the allowance a lapsed
  /// member falls back to, so it is read rather than re-derived from the owner's
  /// expiry. Defaults to `free`, the safe answer for a row cached before the
  /// column existed.
  final String tier;

  /// The tier a mid-term downgrade will fall to, or null when none is waiting.
  final String? tierPending;

  /// The expiry at which [tierPending] starts, epoch ms.
  final int? tierPendingFrom;

  /// Creation timestamp (epoch ms, converted from TIMESTAMPTZ).
  final int createdAt;
  const Firm({
    required this.id,
    required this.name,
    this.logoPath,
    required this.logoVersion,
    required this.ownerId,
    required this.subscriptionStatus,
    this.subscriptionExpiry,
    required this.tier,
    this.tierPending,
    this.tierPendingFrom,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || logoPath != null) {
      map['logo_path'] = Variable<String>(logoPath);
    }
    map['logo_version'] = Variable<int>(logoVersion);
    map['owner_id'] = Variable<String>(ownerId);
    map['subscription_status'] = Variable<String>(subscriptionStatus);
    if (!nullToAbsent || subscriptionExpiry != null) {
      map['subscription_expiry'] = Variable<int>(subscriptionExpiry);
    }
    map['tier'] = Variable<String>(tier);
    if (!nullToAbsent || tierPending != null) {
      map['tier_pending'] = Variable<String>(tierPending);
    }
    if (!nullToAbsent || tierPendingFrom != null) {
      map['tier_pending_from'] = Variable<int>(tierPendingFrom);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  FirmsCompanion toCompanion(bool nullToAbsent) {
    return FirmsCompanion(
      id: Value(id),
      name: Value(name),
      logoPath: logoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(logoPath),
      logoVersion: Value(logoVersion),
      ownerId: Value(ownerId),
      subscriptionStatus: Value(subscriptionStatus),
      subscriptionExpiry: subscriptionExpiry == null && nullToAbsent
          ? const Value.absent()
          : Value(subscriptionExpiry),
      tier: Value(tier),
      tierPending: tierPending == null && nullToAbsent
          ? const Value.absent()
          : Value(tierPending),
      tierPendingFrom: tierPendingFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(tierPendingFrom),
      createdAt: Value(createdAt),
    );
  }

  factory Firm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Firm(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      logoPath: serializer.fromJson<String?>(json['logoPath']),
      logoVersion: serializer.fromJson<int>(json['logoVersion']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      subscriptionStatus: serializer.fromJson<String>(
        json['subscriptionStatus'],
      ),
      subscriptionExpiry: serializer.fromJson<int?>(json['subscriptionExpiry']),
      tier: serializer.fromJson<String>(json['tier']),
      tierPending: serializer.fromJson<String?>(json['tierPending']),
      tierPendingFrom: serializer.fromJson<int?>(json['tierPendingFrom']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'logoPath': serializer.toJson<String?>(logoPath),
      'logoVersion': serializer.toJson<int>(logoVersion),
      'ownerId': serializer.toJson<String>(ownerId),
      'subscriptionStatus': serializer.toJson<String>(subscriptionStatus),
      'subscriptionExpiry': serializer.toJson<int?>(subscriptionExpiry),
      'tier': serializer.toJson<String>(tier),
      'tierPending': serializer.toJson<String?>(tierPending),
      'tierPendingFrom': serializer.toJson<int?>(tierPendingFrom),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Firm copyWith({
    String? id,
    String? name,
    Value<String?> logoPath = const Value.absent(),
    int? logoVersion,
    String? ownerId,
    String? subscriptionStatus,
    Value<int?> subscriptionExpiry = const Value.absent(),
    String? tier,
    Value<String?> tierPending = const Value.absent(),
    Value<int?> tierPendingFrom = const Value.absent(),
    int? createdAt,
  }) => Firm(
    id: id ?? this.id,
    name: name ?? this.name,
    logoPath: logoPath.present ? logoPath.value : this.logoPath,
    logoVersion: logoVersion ?? this.logoVersion,
    ownerId: ownerId ?? this.ownerId,
    subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    subscriptionExpiry: subscriptionExpiry.present
        ? subscriptionExpiry.value
        : this.subscriptionExpiry,
    tier: tier ?? this.tier,
    tierPending: tierPending.present ? tierPending.value : this.tierPending,
    tierPendingFrom: tierPendingFrom.present
        ? tierPendingFrom.value
        : this.tierPendingFrom,
    createdAt: createdAt ?? this.createdAt,
  );
  Firm copyWithCompanion(FirmsCompanion data) {
    return Firm(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      logoPath: data.logoPath.present ? data.logoPath.value : this.logoPath,
      logoVersion: data.logoVersion.present
          ? data.logoVersion.value
          : this.logoVersion,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      subscriptionStatus: data.subscriptionStatus.present
          ? data.subscriptionStatus.value
          : this.subscriptionStatus,
      subscriptionExpiry: data.subscriptionExpiry.present
          ? data.subscriptionExpiry.value
          : this.subscriptionExpiry,
      tier: data.tier.present ? data.tier.value : this.tier,
      tierPending: data.tierPending.present
          ? data.tierPending.value
          : this.tierPending,
      tierPendingFrom: data.tierPendingFrom.present
          ? data.tierPendingFrom.value
          : this.tierPendingFrom,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Firm(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('logoPath: $logoPath, ')
          ..write('logoVersion: $logoVersion, ')
          ..write('ownerId: $ownerId, ')
          ..write('subscriptionStatus: $subscriptionStatus, ')
          ..write('subscriptionExpiry: $subscriptionExpiry, ')
          ..write('tier: $tier, ')
          ..write('tierPending: $tierPending, ')
          ..write('tierPendingFrom: $tierPendingFrom, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    logoPath,
    logoVersion,
    ownerId,
    subscriptionStatus,
    subscriptionExpiry,
    tier,
    tierPending,
    tierPendingFrom,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Firm &&
          other.id == this.id &&
          other.name == this.name &&
          other.logoPath == this.logoPath &&
          other.logoVersion == this.logoVersion &&
          other.ownerId == this.ownerId &&
          other.subscriptionStatus == this.subscriptionStatus &&
          other.subscriptionExpiry == this.subscriptionExpiry &&
          other.tier == this.tier &&
          other.tierPending == this.tierPending &&
          other.tierPendingFrom == this.tierPendingFrom &&
          other.createdAt == this.createdAt);
}

class FirmsCompanion extends UpdateCompanion<Firm> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> logoPath;
  final Value<int> logoVersion;
  final Value<String> ownerId;
  final Value<String> subscriptionStatus;
  final Value<int?> subscriptionExpiry;
  final Value<String> tier;
  final Value<String?> tierPending;
  final Value<int?> tierPendingFrom;
  final Value<int> createdAt;
  final Value<int> rowid;
  const FirmsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.logoPath = const Value.absent(),
    this.logoVersion = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.subscriptionStatus = const Value.absent(),
    this.subscriptionExpiry = const Value.absent(),
    this.tier = const Value.absent(),
    this.tierPending = const Value.absent(),
    this.tierPendingFrom = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FirmsCompanion.insert({
    required String id,
    required String name,
    this.logoPath = const Value.absent(),
    this.logoVersion = const Value.absent(),
    required String ownerId,
    required String subscriptionStatus,
    this.subscriptionExpiry = const Value.absent(),
    this.tier = const Value.absent(),
    this.tierPending = const Value.absent(),
    this.tierPendingFrom = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       ownerId = Value(ownerId),
       subscriptionStatus = Value(subscriptionStatus),
       createdAt = Value(createdAt);
  static Insertable<Firm> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? logoPath,
    Expression<int>? logoVersion,
    Expression<String>? ownerId,
    Expression<String>? subscriptionStatus,
    Expression<int>? subscriptionExpiry,
    Expression<String>? tier,
    Expression<String>? tierPending,
    Expression<int>? tierPendingFrom,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (logoPath != null) 'logo_path': logoPath,
      if (logoVersion != null) 'logo_version': logoVersion,
      if (ownerId != null) 'owner_id': ownerId,
      if (subscriptionStatus != null) 'subscription_status': subscriptionStatus,
      if (subscriptionExpiry != null) 'subscription_expiry': subscriptionExpiry,
      if (tier != null) 'tier': tier,
      if (tierPending != null) 'tier_pending': tierPending,
      if (tierPendingFrom != null) 'tier_pending_from': tierPendingFrom,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FirmsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? logoPath,
    Value<int>? logoVersion,
    Value<String>? ownerId,
    Value<String>? subscriptionStatus,
    Value<int?>? subscriptionExpiry,
    Value<String>? tier,
    Value<String?>? tierPending,
    Value<int?>? tierPendingFrom,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return FirmsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      logoPath: logoPath ?? this.logoPath,
      logoVersion: logoVersion ?? this.logoVersion,
      ownerId: ownerId ?? this.ownerId,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      tier: tier ?? this.tier,
      tierPending: tierPending ?? this.tierPending,
      tierPendingFrom: tierPendingFrom ?? this.tierPendingFrom,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (logoPath.present) {
      map['logo_path'] = Variable<String>(logoPath.value);
    }
    if (logoVersion.present) {
      map['logo_version'] = Variable<int>(logoVersion.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (subscriptionStatus.present) {
      map['subscription_status'] = Variable<String>(subscriptionStatus.value);
    }
    if (subscriptionExpiry.present) {
      map['subscription_expiry'] = Variable<int>(subscriptionExpiry.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (tierPending.present) {
      map['tier_pending'] = Variable<String>(tierPending.value);
    }
    if (tierPendingFrom.present) {
      map['tier_pending_from'] = Variable<int>(tierPendingFrom.value);
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
    return (StringBuffer('FirmsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('logoPath: $logoPath, ')
          ..write('logoVersion: $logoVersion, ')
          ..write('ownerId: $ownerId, ')
          ..write('subscriptionStatus: $subscriptionStatus, ')
          ..write('subscriptionExpiry: $subscriptionExpiry, ')
          ..write('tier: $tier, ')
          ..write('tierPending: $tierPending, ')
          ..write('tierPendingFrom: $tierPendingFrom, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FirmMembersTable extends FirmMembers
    with TableInfo<$FirmMembersTable, FirmMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FirmMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canAddMeta = const VerificationMeta('canAdd');
  @override
  late final GeneratedColumn<bool> canAdd = GeneratedColumn<bool>(
    'can_add',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("can_add" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _canEditMeta = const VerificationMeta(
    'canEdit',
  );
  @override
  late final GeneratedColumn<bool> canEdit = GeneratedColumn<bool>(
    'can_edit',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("can_edit" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _canDeleteMeta = const VerificationMeta(
    'canDelete',
  );
  @override
  late final GeneratedColumn<bool> canDelete = GeneratedColumn<bool>(
    'can_delete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("can_delete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _permissionsSyncedAtMeta =
      const VerificationMeta('permissionsSyncedAt');
  @override
  late final GeneratedColumn<int> permissionsSyncedAt = GeneratedColumn<int>(
    'permissions_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    firmId,
    userId,
    role,
    canAdd,
    canEdit,
    canDelete,
    syncedAt,
    permissionsSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'firm_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<FirmMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_firmIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('can_add')) {
      context.handle(
        _canAddMeta,
        canAdd.isAcceptableOrUnknown(data['can_add']!, _canAddMeta),
      );
    }
    if (data.containsKey('can_edit')) {
      context.handle(
        _canEditMeta,
        canEdit.isAcceptableOrUnknown(data['can_edit']!, _canEditMeta),
      );
    }
    if (data.containsKey('can_delete')) {
      context.handle(
        _canDeleteMeta,
        canDelete.isAcceptableOrUnknown(data['can_delete']!, _canDeleteMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('permissions_synced_at')) {
      context.handle(
        _permissionsSyncedAtMeta,
        permissionsSyncedAt.isAcceptableOrUnknown(
          data['permissions_synced_at']!,
          _permissionsSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FirmMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FirmMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      canAdd: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}can_add'],
      )!,
      canEdit: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}can_edit'],
      )!,
      canDelete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}can_delete'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
      permissionsSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}permissions_synced_at'],
      ),
    );
  }

  @override
  $FirmMembersTable createAlias(String alias) {
    return $FirmMembersTable(attachedDatabase, alias);
  }
}

class FirmMember extends DataClass implements Insertable<FirmMember> {
  /// UUID primary key (mirrors Supabase PK).
  final String id;

  /// Parent firm.
  final String firmId;

  /// Member user UUID.
  final String userId;

  /// Role within the firm (e.g. `owner`, `admin`, `associate`).
  final String role;

  /// Permission: can add cases/records.
  final bool canAdd;

  /// Permission: can edit existing records.
  final bool canEdit;

  /// Permission: can delete (subject to delete-request approval workflow).
  final bool canDelete;

  /// Last time this member row was synced from Supabase (epoch ms).
  final int? syncedAt;

  /// Last time permissions were re-fetched from Supabase (epoch ms).
  final int? permissionsSyncedAt;
  const FirmMember({
    required this.id,
    required this.firmId,
    required this.userId,
    required this.role,
    required this.canAdd,
    required this.canEdit,
    required this.canDelete,
    this.syncedAt,
    this.permissionsSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['firm_id'] = Variable<String>(firmId);
    map['user_id'] = Variable<String>(userId);
    map['role'] = Variable<String>(role);
    map['can_add'] = Variable<bool>(canAdd);
    map['can_edit'] = Variable<bool>(canEdit);
    map['can_delete'] = Variable<bool>(canDelete);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    if (!nullToAbsent || permissionsSyncedAt != null) {
      map['permissions_synced_at'] = Variable<int>(permissionsSyncedAt);
    }
    return map;
  }

  FirmMembersCompanion toCompanion(bool nullToAbsent) {
    return FirmMembersCompanion(
      id: Value(id),
      firmId: Value(firmId),
      userId: Value(userId),
      role: Value(role),
      canAdd: Value(canAdd),
      canEdit: Value(canEdit),
      canDelete: Value(canDelete),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      permissionsSyncedAt: permissionsSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(permissionsSyncedAt),
    );
  }

  factory FirmMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FirmMember(
      id: serializer.fromJson<String>(json['id']),
      firmId: serializer.fromJson<String>(json['firmId']),
      userId: serializer.fromJson<String>(json['userId']),
      role: serializer.fromJson<String>(json['role']),
      canAdd: serializer.fromJson<bool>(json['canAdd']),
      canEdit: serializer.fromJson<bool>(json['canEdit']),
      canDelete: serializer.fromJson<bool>(json['canDelete']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      permissionsSyncedAt: serializer.fromJson<int?>(
        json['permissionsSyncedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'firmId': serializer.toJson<String>(firmId),
      'userId': serializer.toJson<String>(userId),
      'role': serializer.toJson<String>(role),
      'canAdd': serializer.toJson<bool>(canAdd),
      'canEdit': serializer.toJson<bool>(canEdit),
      'canDelete': serializer.toJson<bool>(canDelete),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'permissionsSyncedAt': serializer.toJson<int?>(permissionsSyncedAt),
    };
  }

  FirmMember copyWith({
    String? id,
    String? firmId,
    String? userId,
    String? role,
    bool? canAdd,
    bool? canEdit,
    bool? canDelete,
    Value<int?> syncedAt = const Value.absent(),
    Value<int?> permissionsSyncedAt = const Value.absent(),
  }) => FirmMember(
    id: id ?? this.id,
    firmId: firmId ?? this.firmId,
    userId: userId ?? this.userId,
    role: role ?? this.role,
    canAdd: canAdd ?? this.canAdd,
    canEdit: canEdit ?? this.canEdit,
    canDelete: canDelete ?? this.canDelete,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    permissionsSyncedAt: permissionsSyncedAt.present
        ? permissionsSyncedAt.value
        : this.permissionsSyncedAt,
  );
  FirmMember copyWithCompanion(FirmMembersCompanion data) {
    return FirmMember(
      id: data.id.present ? data.id.value : this.id,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      userId: data.userId.present ? data.userId.value : this.userId,
      role: data.role.present ? data.role.value : this.role,
      canAdd: data.canAdd.present ? data.canAdd.value : this.canAdd,
      canEdit: data.canEdit.present ? data.canEdit.value : this.canEdit,
      canDelete: data.canDelete.present ? data.canDelete.value : this.canDelete,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      permissionsSyncedAt: data.permissionsSyncedAt.present
          ? data.permissionsSyncedAt.value
          : this.permissionsSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FirmMember(')
          ..write('id: $id, ')
          ..write('firmId: $firmId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('canAdd: $canAdd, ')
          ..write('canEdit: $canEdit, ')
          ..write('canDelete: $canDelete, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('permissionsSyncedAt: $permissionsSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    firmId,
    userId,
    role,
    canAdd,
    canEdit,
    canDelete,
    syncedAt,
    permissionsSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FirmMember &&
          other.id == this.id &&
          other.firmId == this.firmId &&
          other.userId == this.userId &&
          other.role == this.role &&
          other.canAdd == this.canAdd &&
          other.canEdit == this.canEdit &&
          other.canDelete == this.canDelete &&
          other.syncedAt == this.syncedAt &&
          other.permissionsSyncedAt == this.permissionsSyncedAt);
}

class FirmMembersCompanion extends UpdateCompanion<FirmMember> {
  final Value<String> id;
  final Value<String> firmId;
  final Value<String> userId;
  final Value<String> role;
  final Value<bool> canAdd;
  final Value<bool> canEdit;
  final Value<bool> canDelete;
  final Value<int?> syncedAt;
  final Value<int?> permissionsSyncedAt;
  final Value<int> rowid;
  const FirmMembersCompanion({
    this.id = const Value.absent(),
    this.firmId = const Value.absent(),
    this.userId = const Value.absent(),
    this.role = const Value.absent(),
    this.canAdd = const Value.absent(),
    this.canEdit = const Value.absent(),
    this.canDelete = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.permissionsSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FirmMembersCompanion.insert({
    required String id,
    required String firmId,
    required String userId,
    required String role,
    this.canAdd = const Value.absent(),
    this.canEdit = const Value.absent(),
    this.canDelete = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.permissionsSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       firmId = Value(firmId),
       userId = Value(userId),
       role = Value(role);
  static Insertable<FirmMember> custom({
    Expression<String>? id,
    Expression<String>? firmId,
    Expression<String>? userId,
    Expression<String>? role,
    Expression<bool>? canAdd,
    Expression<bool>? canEdit,
    Expression<bool>? canDelete,
    Expression<int>? syncedAt,
    Expression<int>? permissionsSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (firmId != null) 'firm_id': firmId,
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
      if (canAdd != null) 'can_add': canAdd,
      if (canEdit != null) 'can_edit': canEdit,
      if (canDelete != null) 'can_delete': canDelete,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (permissionsSyncedAt != null)
        'permissions_synced_at': permissionsSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FirmMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? firmId,
    Value<String>? userId,
    Value<String>? role,
    Value<bool>? canAdd,
    Value<bool>? canEdit,
    Value<bool>? canDelete,
    Value<int?>? syncedAt,
    Value<int?>? permissionsSyncedAt,
    Value<int>? rowid,
  }) {
    return FirmMembersCompanion(
      id: id ?? this.id,
      firmId: firmId ?? this.firmId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      canAdd: canAdd ?? this.canAdd,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      syncedAt: syncedAt ?? this.syncedAt,
      permissionsSyncedAt: permissionsSyncedAt ?? this.permissionsSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (canAdd.present) {
      map['can_add'] = Variable<bool>(canAdd.value);
    }
    if (canEdit.present) {
      map['can_edit'] = Variable<bool>(canEdit.value);
    }
    if (canDelete.present) {
      map['can_delete'] = Variable<bool>(canDelete.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (permissionsSyncedAt.present) {
      map['permissions_synced_at'] = Variable<int>(permissionsSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FirmMembersCompanion(')
          ..write('id: $id, ')
          ..write('firmId: $firmId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('canAdd: $canAdd, ')
          ..write('canEdit: $canEdit, ')
          ..write('canDelete: $canDelete, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('permissionsSyncedAt: $permissionsSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarPathMeta = const VerificationMeta(
    'avatarPath',
  );
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
    'avatar_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarVersionMeta = const VerificationMeta(
    'avatarVersion',
  );
  @override
  late final GeneratedColumn<int> avatarVersion = GeneratedColumn<int>(
    'avatar_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _firmIdMeta = const VerificationMeta('firmId');
  @override
  late final GeneratedColumn<String> firmId = GeneratedColumn<String>(
    'firm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subscriptionStatusMeta =
      const VerificationMeta('subscriptionStatus');
  @override
  late final GeneratedColumn<String> subscriptionStatus =
      GeneratedColumn<String>(
        'subscription_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _subscriptionExpiryMeta =
      const VerificationMeta('subscriptionExpiry');
  @override
  late final GeneratedColumn<int> subscriptionExpiry = GeneratedColumn<int>(
    'subscription_expiry',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('free'),
  );
  static const VerificationMeta _tierPendingMeta = const VerificationMeta(
    'tierPending',
  );
  @override
  late final GeneratedColumn<String> tierPending = GeneratedColumn<String>(
    'tier_pending',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tierPendingFromMeta = const VerificationMeta(
    'tierPendingFrom',
  );
  @override
  late final GeneratedColumn<int> tierPendingFrom = GeneratedColumn<int>(
    'tier_pending_from',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fullName,
    avatarPath,
    avatarVersion,
    firmId,
    role,
    subscriptionStatus,
    subscriptionExpiry,
    tier,
    tierPending,
    tierPendingFrom,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
        _avatarPathMeta,
        avatarPath.isAcceptableOrUnknown(data['avatar_path']!, _avatarPathMeta),
      );
    }
    if (data.containsKey('avatar_version')) {
      context.handle(
        _avatarVersionMeta,
        avatarVersion.isAcceptableOrUnknown(
          data['avatar_version']!,
          _avatarVersionMeta,
        ),
      );
    }
    if (data.containsKey('firm_id')) {
      context.handle(
        _firmIdMeta,
        firmId.isAcceptableOrUnknown(data['firm_id']!, _firmIdMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('subscription_status')) {
      context.handle(
        _subscriptionStatusMeta,
        subscriptionStatus.isAcceptableOrUnknown(
          data['subscription_status']!,
          _subscriptionStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subscriptionStatusMeta);
    }
    if (data.containsKey('subscription_expiry')) {
      context.handle(
        _subscriptionExpiryMeta,
        subscriptionExpiry.isAcceptableOrUnknown(
          data['subscription_expiry']!,
          _subscriptionExpiryMeta,
        ),
      );
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    }
    if (data.containsKey('tier_pending')) {
      context.handle(
        _tierPendingMeta,
        tierPending.isAcceptableOrUnknown(
          data['tier_pending']!,
          _tierPendingMeta,
        ),
      );
    }
    if (data.containsKey('tier_pending_from')) {
      context.handle(
        _tierPendingFromMeta,
        tierPendingFrom.isAcceptableOrUnknown(
          data['tier_pending_from']!,
          _tierPendingFromMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
      avatarPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_path'],
      ),
      avatarVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avatar_version'],
      )!,
      firmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firm_id'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      subscriptionStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subscription_status'],
      )!,
      subscriptionExpiry: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subscription_expiry'],
      ),
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      tierPending: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier_pending'],
      ),
      tierPendingFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tier_pending_from'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  /// UUID primary key (mirrors auth.users / profiles.id).
  final String id;

  /// Display name.
  final String fullName;

  /// Object name of the profile picture in the `individual-avatars` bucket,
  /// or null.
  ///
  /// Server-written by the storage trigger, never by a device. The local
  /// picture stays the offline truth; this is how another device learns that
  /// it exists and changed (0.0.630).
  final String? avatarPath;

  /// Bumped by the server on every profile-picture write or delete.
  final int avatarVersion;

  /// Firm membership; null for individual lawyers.
  final String? firmId;

  /// Role: `owner`, `associate`, `viewer`, or `individual`.
  final String role;

  /// Subscription status (`free`/`premium`) — display/analytics only.
  final String subscriptionStatus;

  /// Premium subscription expiry converted from TIMESTAMPTZ to epoch ms.
  final int? subscriptionExpiry;

  /// The subscription tier this account holds: `free`, `pro`, `firm` or
  /// `firm_plus`, as the server stores it.
  ///
  /// The server writes it at approval and **never clears it on expiry**, so the
  /// column is the record of the last tier held — which is what the lapse
  /// allowance needs. Defaults to `free` so every row cached before this column
  /// existed reads as "no paid tier", the safe answer.
  final String tier;

  /// The tier a mid-term downgrade will fall to when the paid period ends, or
  /// null when no downgrade is waiting.
  final String? tierPending;

  /// The expiry at which [tierPending] starts, epoch ms. A downgrade waits for
  /// the period it was bought for, so the tier in force is never replaced early.
  final int? tierPendingFrom;

  /// Profile creation timestamp (epoch ms, converted from TIMESTAMPTZ).
  final int createdAt;
  const Profile({
    required this.id,
    required this.fullName,
    this.avatarPath,
    required this.avatarVersion,
    this.firmId,
    required this.role,
    required this.subscriptionStatus,
    this.subscriptionExpiry,
    required this.tier,
    this.tierPending,
    this.tierPendingFrom,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['full_name'] = Variable<String>(fullName);
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    map['avatar_version'] = Variable<int>(avatarVersion);
    if (!nullToAbsent || firmId != null) {
      map['firm_id'] = Variable<String>(firmId);
    }
    map['role'] = Variable<String>(role);
    map['subscription_status'] = Variable<String>(subscriptionStatus);
    if (!nullToAbsent || subscriptionExpiry != null) {
      map['subscription_expiry'] = Variable<int>(subscriptionExpiry);
    }
    map['tier'] = Variable<String>(tier);
    if (!nullToAbsent || tierPending != null) {
      map['tier_pending'] = Variable<String>(tierPending);
    }
    if (!nullToAbsent || tierPendingFrom != null) {
      map['tier_pending_from'] = Variable<int>(tierPendingFrom);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      fullName: Value(fullName),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      avatarVersion: Value(avatarVersion),
      firmId: firmId == null && nullToAbsent
          ? const Value.absent()
          : Value(firmId),
      role: Value(role),
      subscriptionStatus: Value(subscriptionStatus),
      subscriptionExpiry: subscriptionExpiry == null && nullToAbsent
          ? const Value.absent()
          : Value(subscriptionExpiry),
      tier: Value(tier),
      tierPending: tierPending == null && nullToAbsent
          ? const Value.absent()
          : Value(tierPending),
      tierPendingFrom: tierPendingFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(tierPendingFrom),
      createdAt: Value(createdAt),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<String>(json['id']),
      fullName: serializer.fromJson<String>(json['fullName']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      avatarVersion: serializer.fromJson<int>(json['avatarVersion']),
      firmId: serializer.fromJson<String?>(json['firmId']),
      role: serializer.fromJson<String>(json['role']),
      subscriptionStatus: serializer.fromJson<String>(
        json['subscriptionStatus'],
      ),
      subscriptionExpiry: serializer.fromJson<int?>(json['subscriptionExpiry']),
      tier: serializer.fromJson<String>(json['tier']),
      tierPending: serializer.fromJson<String?>(json['tierPending']),
      tierPendingFrom: serializer.fromJson<int?>(json['tierPendingFrom']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fullName': serializer.toJson<String>(fullName),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'avatarVersion': serializer.toJson<int>(avatarVersion),
      'firmId': serializer.toJson<String?>(firmId),
      'role': serializer.toJson<String>(role),
      'subscriptionStatus': serializer.toJson<String>(subscriptionStatus),
      'subscriptionExpiry': serializer.toJson<int?>(subscriptionExpiry),
      'tier': serializer.toJson<String>(tier),
      'tierPending': serializer.toJson<String?>(tierPending),
      'tierPendingFrom': serializer.toJson<int?>(tierPendingFrom),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Profile copyWith({
    String? id,
    String? fullName,
    Value<String?> avatarPath = const Value.absent(),
    int? avatarVersion,
    Value<String?> firmId = const Value.absent(),
    String? role,
    String? subscriptionStatus,
    Value<int?> subscriptionExpiry = const Value.absent(),
    String? tier,
    Value<String?> tierPending = const Value.absent(),
    Value<int?> tierPendingFrom = const Value.absent(),
    int? createdAt,
  }) => Profile(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
    avatarVersion: avatarVersion ?? this.avatarVersion,
    firmId: firmId.present ? firmId.value : this.firmId,
    role: role ?? this.role,
    subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    subscriptionExpiry: subscriptionExpiry.present
        ? subscriptionExpiry.value
        : this.subscriptionExpiry,
    tier: tier ?? this.tier,
    tierPending: tierPending.present ? tierPending.value : this.tierPending,
    tierPendingFrom: tierPendingFrom.present
        ? tierPendingFrom.value
        : this.tierPendingFrom,
    createdAt: createdAt ?? this.createdAt,
  );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      avatarPath: data.avatarPath.present
          ? data.avatarPath.value
          : this.avatarPath,
      avatarVersion: data.avatarVersion.present
          ? data.avatarVersion.value
          : this.avatarVersion,
      firmId: data.firmId.present ? data.firmId.value : this.firmId,
      role: data.role.present ? data.role.value : this.role,
      subscriptionStatus: data.subscriptionStatus.present
          ? data.subscriptionStatus.value
          : this.subscriptionStatus,
      subscriptionExpiry: data.subscriptionExpiry.present
          ? data.subscriptionExpiry.value
          : this.subscriptionExpiry,
      tier: data.tier.present ? data.tier.value : this.tier,
      tierPending: data.tierPending.present
          ? data.tierPending.value
          : this.tierPending,
      tierPendingFrom: data.tierPendingFrom.present
          ? data.tierPendingFrom.value
          : this.tierPendingFrom,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('avatarVersion: $avatarVersion, ')
          ..write('firmId: $firmId, ')
          ..write('role: $role, ')
          ..write('subscriptionStatus: $subscriptionStatus, ')
          ..write('subscriptionExpiry: $subscriptionExpiry, ')
          ..write('tier: $tier, ')
          ..write('tierPending: $tierPending, ')
          ..write('tierPendingFrom: $tierPendingFrom, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fullName,
    avatarPath,
    avatarVersion,
    firmId,
    role,
    subscriptionStatus,
    subscriptionExpiry,
    tier,
    tierPending,
    tierPendingFrom,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.fullName == this.fullName &&
          other.avatarPath == this.avatarPath &&
          other.avatarVersion == this.avatarVersion &&
          other.firmId == this.firmId &&
          other.role == this.role &&
          other.subscriptionStatus == this.subscriptionStatus &&
          other.subscriptionExpiry == this.subscriptionExpiry &&
          other.tier == this.tier &&
          other.tierPending == this.tierPending &&
          other.tierPendingFrom == this.tierPendingFrom &&
          other.createdAt == this.createdAt);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<String> id;
  final Value<String> fullName;
  final Value<String?> avatarPath;
  final Value<int> avatarVersion;
  final Value<String?> firmId;
  final Value<String> role;
  final Value<String> subscriptionStatus;
  final Value<int?> subscriptionExpiry;
  final Value<String> tier;
  final Value<String?> tierPending;
  final Value<int?> tierPendingFrom;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.fullName = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.avatarVersion = const Value.absent(),
    this.firmId = const Value.absent(),
    this.role = const Value.absent(),
    this.subscriptionStatus = const Value.absent(),
    this.subscriptionExpiry = const Value.absent(),
    this.tier = const Value.absent(),
    this.tierPending = const Value.absent(),
    this.tierPendingFrom = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String fullName,
    this.avatarPath = const Value.absent(),
    this.avatarVersion = const Value.absent(),
    this.firmId = const Value.absent(),
    required String role,
    required String subscriptionStatus,
    this.subscriptionExpiry = const Value.absent(),
    this.tier = const Value.absent(),
    this.tierPending = const Value.absent(),
    this.tierPendingFrom = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fullName = Value(fullName),
       role = Value(role),
       subscriptionStatus = Value(subscriptionStatus),
       createdAt = Value(createdAt);
  static Insertable<Profile> custom({
    Expression<String>? id,
    Expression<String>? fullName,
    Expression<String>? avatarPath,
    Expression<int>? avatarVersion,
    Expression<String>? firmId,
    Expression<String>? role,
    Expression<String>? subscriptionStatus,
    Expression<int>? subscriptionExpiry,
    Expression<String>? tier,
    Expression<String>? tierPending,
    Expression<int>? tierPendingFrom,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fullName != null) 'full_name': fullName,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (avatarVersion != null) 'avatar_version': avatarVersion,
      if (firmId != null) 'firm_id': firmId,
      if (role != null) 'role': role,
      if (subscriptionStatus != null) 'subscription_status': subscriptionStatus,
      if (subscriptionExpiry != null) 'subscription_expiry': subscriptionExpiry,
      if (tier != null) 'tier': tier,
      if (tierPending != null) 'tier_pending': tierPending,
      if (tierPendingFrom != null) 'tier_pending_from': tierPendingFrom,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? fullName,
    Value<String?>? avatarPath,
    Value<int>? avatarVersion,
    Value<String?>? firmId,
    Value<String>? role,
    Value<String>? subscriptionStatus,
    Value<int?>? subscriptionExpiry,
    Value<String>? tier,
    Value<String?>? tierPending,
    Value<int?>? tierPendingFrom,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarVersion: avatarVersion ?? this.avatarVersion,
      firmId: firmId ?? this.firmId,
      role: role ?? this.role,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      tier: tier ?? this.tier,
      tierPending: tierPending ?? this.tierPending,
      tierPendingFrom: tierPendingFrom ?? this.tierPendingFrom,
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
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (avatarVersion.present) {
      map['avatar_version'] = Variable<int>(avatarVersion.value);
    }
    if (firmId.present) {
      map['firm_id'] = Variable<String>(firmId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (subscriptionStatus.present) {
      map['subscription_status'] = Variable<String>(subscriptionStatus.value);
    }
    if (subscriptionExpiry.present) {
      map['subscription_expiry'] = Variable<int>(subscriptionExpiry.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (tierPending.present) {
      map['tier_pending'] = Variable<String>(tierPending.value);
    }
    if (tierPendingFrom.present) {
      map['tier_pending_from'] = Variable<int>(tierPendingFrom.value);
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
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('avatarVersion: $avatarVersion, ')
          ..write('firmId: $firmId, ')
          ..write('role: $role, ')
          ..write('subscriptionStatus: $subscriptionStatus, ')
          ..write('subscriptionExpiry: $subscriptionExpiry, ')
          ..write('tier: $tier, ')
          ..write('tierPending: $tierPending, ')
          ..write('tierPendingFrom: $tierPendingFrom, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _basePayloadMeta = const VerificationMeta(
    'basePayload',
  );
  @override
  late final GeneratedColumn<String> basePayload = GeneratedColumn<String>(
    'base_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changedFieldsMeta = const VerificationMeta(
    'changedFields',
  );
  @override
  late final GeneratedColumn<String> changedFields = GeneratedColumn<String>(
    'changed_fields',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preMutationPayloadMeta =
      const VerificationMeta('preMutationPayload');
  @override
  late final GeneratedColumn<String> preMutationPayload =
      GeneratedColumn<String>(
        'pre_mutation_payload',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<int> lastAttemptAt = GeneratedColumn<int>(
    'last_attempt_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    operation,
    mutationId,
    baseVersion,
    basePayload,
    changedFields,
    payload,
    preMutationPayload,
    createdAt,
    retryCount,
    lastAttemptAt,
    state,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('base_payload')) {
      context.handle(
        _basePayloadMeta,
        basePayload.isAcceptableOrUnknown(
          data['base_payload']!,
          _basePayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_basePayloadMeta);
    }
    if (data.containsKey('changed_fields')) {
      context.handle(
        _changedFieldsMeta,
        changedFields.isAcceptableOrUnknown(
          data['changed_fields']!,
          _changedFieldsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_changedFieldsMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('pre_mutation_payload')) {
      context.handle(
        _preMutationPayloadMeta,
        preMutationPayload.isAcceptableOrUnknown(
          data['pre_mutation_payload']!,
          _preMutationPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_preMutationPayloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      basePayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_payload'],
      )!,
      changedFields: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changed_fields'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      preMutationPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pre_mutation_payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_attempt_at'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueRow extends DataClass implements Insertable<SyncQueueRow> {
  /// Auto-increment primary key.
  final int id;

  /// Entity type (`case`, `case_history`, `note`, `reference`, `court`,
  /// `step`, `case_type`, `on_behalf`, `conflict_log`, `delete_request`).
  final String entityType;

  /// UUID of the modified record.
  final String entityId;

  /// `insert`, `update`, or `delete`.
  final String operation;

  /// Stable client-generated idempotency key.
  final String mutationId;

  /// Last server version observed when this mutation began.
  final int? baseVersion;

  /// JSON snapshot of the common base for three-way merge/rebase.
  final String basePayload;

  /// JSON array of fields intentionally changed.
  final String changedFields;

  /// JSON-serialized intended record state/patch.
  final String payload;

  /// Snapshot used to roll back a server-rejected permission-sensitive action.
  final String preMutationPayload;

  /// Timestamp when this queue entry was created (epoch ms).
  final int createdAt;

  /// Number of failed push attempts.
  final int retryCount;

  /// Timestamp before the most recent attempt (epoch ms); null if never attempted.
  final int? lastAttemptAt;

  /// `pending`, `pushing`, `conflict_pending`, `blocked`, or `resolved`.
  final String state;

  /// Last error message for diagnostics.
  final String? lastError;
  const SyncQueueRow({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.mutationId,
    this.baseVersion,
    required this.basePayload,
    required this.changedFields,
    required this.payload,
    required this.preMutationPayload,
    required this.createdAt,
    required this.retryCount,
    this.lastAttemptAt,
    required this.state,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['mutation_id'] = Variable<String>(mutationId);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['base_payload'] = Variable<String>(basePayload);
    map['changed_fields'] = Variable<String>(changedFields);
    map['payload'] = Variable<String>(payload);
    map['pre_mutation_payload'] = Variable<String>(preMutationPayload);
    map['created_at'] = Variable<int>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<int>(lastAttemptAt);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      mutationId: Value(mutationId),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      basePayload: Value(basePayload),
      changedFields: Value(changedFields),
      payload: Value(payload),
      preMutationPayload: Value(preMutationPayload),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      state: Value(state),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueRow(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      baseVersion: serializer.fromJson<int?>(json['baseVersion']),
      basePayload: serializer.fromJson<String>(json['basePayload']),
      changedFields: serializer.fromJson<String>(json['changedFields']),
      payload: serializer.fromJson<String>(json['payload']),
      preMutationPayload: serializer.fromJson<String>(
        json['preMutationPayload'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastAttemptAt: serializer.fromJson<int?>(json['lastAttemptAt']),
      state: serializer.fromJson<String>(json['state']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'mutationId': serializer.toJson<String>(mutationId),
      'baseVersion': serializer.toJson<int?>(baseVersion),
      'basePayload': serializer.toJson<String>(basePayload),
      'changedFields': serializer.toJson<String>(changedFields),
      'payload': serializer.toJson<String>(payload),
      'preMutationPayload': serializer.toJson<String>(preMutationPayload),
      'createdAt': serializer.toJson<int>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastAttemptAt': serializer.toJson<int?>(lastAttemptAt),
      'state': serializer.toJson<String>(state),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncQueueRow copyWith({
    int? id,
    String? entityType,
    String? entityId,
    String? operation,
    String? mutationId,
    Value<int?> baseVersion = const Value.absent(),
    String? basePayload,
    String? changedFields,
    String? payload,
    String? preMutationPayload,
    int? createdAt,
    int? retryCount,
    Value<int?> lastAttemptAt = const Value.absent(),
    String? state,
    Value<String?> lastError = const Value.absent(),
  }) => SyncQueueRow(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    mutationId: mutationId ?? this.mutationId,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    basePayload: basePayload ?? this.basePayload,
    changedFields: changedFields ?? this.changedFields,
    payload: payload ?? this.payload,
    preMutationPayload: preMutationPayload ?? this.preMutationPayload,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    state: state ?? this.state,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncQueueRow copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueRow(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      basePayload: data.basePayload.present
          ? data.basePayload.value
          : this.basePayload,
      changedFields: data.changedFields.present
          ? data.changedFields.value
          : this.changedFields,
      payload: data.payload.present ? data.payload.value : this.payload,
      preMutationPayload: data.preMutationPayload.present
          ? data.preMutationPayload.value
          : this.preMutationPayload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      state: data.state.present ? data.state.value : this.state,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueRow(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('mutationId: $mutationId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('basePayload: $basePayload, ')
          ..write('changedFields: $changedFields, ')
          ..write('payload: $payload, ')
          ..write('preMutationPayload: $preMutationPayload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    operation,
    mutationId,
    baseVersion,
    basePayload,
    changedFields,
    payload,
    preMutationPayload,
    createdAt,
    retryCount,
    lastAttemptAt,
    state,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueRow &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.mutationId == this.mutationId &&
          other.baseVersion == this.baseVersion &&
          other.basePayload == this.basePayload &&
          other.changedFields == this.changedFields &&
          other.payload == this.payload &&
          other.preMutationPayload == this.preMutationPayload &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.state == this.state &&
          other.lastError == this.lastError);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueRow> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String> mutationId;
  final Value<int?> baseVersion;
  final Value<String> basePayload;
  final Value<String> changedFields;
  final Value<String> payload;
  final Value<String> preMutationPayload;
  final Value<int> createdAt;
  final Value<int> retryCount;
  final Value<int?> lastAttemptAt;
  final Value<String> state;
  final Value<String?> lastError;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.basePayload = const Value.absent(),
    this.changedFields = const Value.absent(),
    this.payload = const Value.absent(),
    this.preMutationPayload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String entityId,
    required String operation,
    required String mutationId,
    this.baseVersion = const Value.absent(),
    required String basePayload,
    required String changedFields,
    required String payload,
    required String preMutationPayload,
    required int createdAt,
    this.retryCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    required String state,
    this.lastError = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       mutationId = Value(mutationId),
       basePayload = Value(basePayload),
       changedFields = Value(changedFields),
       payload = Value(payload),
       preMutationPayload = Value(preMutationPayload),
       createdAt = Value(createdAt),
       state = Value(state);
  static Insertable<SyncQueueRow> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? mutationId,
    Expression<int>? baseVersion,
    Expression<String>? basePayload,
    Expression<String>? changedFields,
    Expression<String>? payload,
    Expression<String>? preMutationPayload,
    Expression<int>? createdAt,
    Expression<int>? retryCount,
    Expression<int>? lastAttemptAt,
    Expression<String>? state,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (mutationId != null) 'mutation_id': mutationId,
      if (baseVersion != null) 'base_version': baseVersion,
      if (basePayload != null) 'base_payload': basePayload,
      if (changedFields != null) 'changed_fields': changedFields,
      if (payload != null) 'payload': payload,
      if (preMutationPayload != null)
        'pre_mutation_payload': preMutationPayload,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (state != null) 'state': state,
      if (lastError != null) 'last_error': lastError,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String>? mutationId,
    Value<int?>? baseVersion,
    Value<String>? basePayload,
    Value<String>? changedFields,
    Value<String>? payload,
    Value<String>? preMutationPayload,
    Value<int>? createdAt,
    Value<int>? retryCount,
    Value<int?>? lastAttemptAt,
    Value<String>? state,
    Value<String?>? lastError,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      mutationId: mutationId ?? this.mutationId,
      baseVersion: baseVersion ?? this.baseVersion,
      basePayload: basePayload ?? this.basePayload,
      changedFields: changedFields ?? this.changedFields,
      payload: payload ?? this.payload,
      preMutationPayload: preMutationPayload ?? this.preMutationPayload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (basePayload.present) {
      map['base_payload'] = Variable<String>(basePayload.value);
    }
    if (changedFields.present) {
      map['changed_fields'] = Variable<String>(changedFields.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (preMutationPayload.present) {
      map['pre_mutation_payload'] = Variable<String>(preMutationPayload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<int>(lastAttemptAt.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('mutationId: $mutationId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('basePayload: $basePayload, ')
          ..write('changedFields: $changedFields, ')
          ..write('payload: $payload, ')
          ..write('preMutationPayload: $preMutationPayload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataRow> instance, {
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
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataRow extends DataClass implements Insertable<SyncMetadataRow> {
  /// Stable key for this metadata entry (e.g. `cursor.cases`,
  /// `last_successful_sync_at`, `clock_offset_ms`, `recovery_required`,
  /// `archive.path`, `archive.checksum`, `archive.state`,
  /// `atomic_recovery_checkpoint`).
  final String key;

  /// Value as a plain string or JSON-encoded payload.
  final String value;

  /// Timestamp when this entry was last written (epoch ms).
  final int updatedAt;
  const SyncMetadataRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SyncMetadataRow copyWith({String? key, String? value, int? updatedAt}) =>
      SyncMetadataRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SyncMetadataRow copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<SyncMetadataRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
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
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeedMigrationsTable extends SeedMigrations
    with TableInfo<$SeedMigrationsTable, SeedMigration> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeedMigrationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _migrationIdMeta = const VerificationMeta(
    'migrationId',
  );
  @override
  late final GeneratedColumn<String> migrationId = GeneratedColumn<String>(
    'migration_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appliedAtMeta = const VerificationMeta(
    'appliedAt',
  );
  @override
  late final GeneratedColumn<int> appliedAt = GeneratedColumn<int>(
    'applied_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [migrationId, checksum, appliedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seed_migrations';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeedMigration> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('migration_id')) {
      context.handle(
        _migrationIdMeta,
        migrationId.isAcceptableOrUnknown(
          data['migration_id']!,
          _migrationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_migrationIdMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('applied_at')) {
      context.handle(
        _appliedAtMeta,
        appliedAt.isAcceptableOrUnknown(data['applied_at']!, _appliedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_appliedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {migrationId};
  @override
  SeedMigration map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeedMigration(
      migrationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}migration_id'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      appliedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}applied_at'],
      )!,
    );
  }

  @override
  $SeedMigrationsTable createAlias(String alias) {
    return $SeedMigrationsTable(attachedDatabase, alias);
  }
}

class SeedMigration extends DataClass implements Insertable<SeedMigration> {
  /// Migration identifier (e.g. `seed_v1`).
  final String migrationId;

  /// Checksum / hash used to detect tampered or changed migration payloads.
  final String checksum;

  /// Timestamp when the migration was applied (epoch ms).
  final int appliedAt;
  const SeedMigration({
    required this.migrationId,
    required this.checksum,
    required this.appliedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['migration_id'] = Variable<String>(migrationId);
    map['checksum'] = Variable<String>(checksum);
    map['applied_at'] = Variable<int>(appliedAt);
    return map;
  }

  SeedMigrationsCompanion toCompanion(bool nullToAbsent) {
    return SeedMigrationsCompanion(
      migrationId: Value(migrationId),
      checksum: Value(checksum),
      appliedAt: Value(appliedAt),
    );
  }

  factory SeedMigration.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeedMigration(
      migrationId: serializer.fromJson<String>(json['migrationId']),
      checksum: serializer.fromJson<String>(json['checksum']),
      appliedAt: serializer.fromJson<int>(json['appliedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'migrationId': serializer.toJson<String>(migrationId),
      'checksum': serializer.toJson<String>(checksum),
      'appliedAt': serializer.toJson<int>(appliedAt),
    };
  }

  SeedMigration copyWith({
    String? migrationId,
    String? checksum,
    int? appliedAt,
  }) => SeedMigration(
    migrationId: migrationId ?? this.migrationId,
    checksum: checksum ?? this.checksum,
    appliedAt: appliedAt ?? this.appliedAt,
  );
  SeedMigration copyWithCompanion(SeedMigrationsCompanion data) {
    return SeedMigration(
      migrationId: data.migrationId.present
          ? data.migrationId.value
          : this.migrationId,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      appliedAt: data.appliedAt.present ? data.appliedAt.value : this.appliedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeedMigration(')
          ..write('migrationId: $migrationId, ')
          ..write('checksum: $checksum, ')
          ..write('appliedAt: $appliedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(migrationId, checksum, appliedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeedMigration &&
          other.migrationId == this.migrationId &&
          other.checksum == this.checksum &&
          other.appliedAt == this.appliedAt);
}

class SeedMigrationsCompanion extends UpdateCompanion<SeedMigration> {
  final Value<String> migrationId;
  final Value<String> checksum;
  final Value<int> appliedAt;
  final Value<int> rowid;
  const SeedMigrationsCompanion({
    this.migrationId = const Value.absent(),
    this.checksum = const Value.absent(),
    this.appliedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeedMigrationsCompanion.insert({
    required String migrationId,
    required String checksum,
    required int appliedAt,
    this.rowid = const Value.absent(),
  }) : migrationId = Value(migrationId),
       checksum = Value(checksum),
       appliedAt = Value(appliedAt);
  static Insertable<SeedMigration> custom({
    Expression<String>? migrationId,
    Expression<String>? checksum,
    Expression<int>? appliedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (migrationId != null) 'migration_id': migrationId,
      if (checksum != null) 'checksum': checksum,
      if (appliedAt != null) 'applied_at': appliedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeedMigrationsCompanion copyWith({
    Value<String>? migrationId,
    Value<String>? checksum,
    Value<int>? appliedAt,
    Value<int>? rowid,
  }) {
    return SeedMigrationsCompanion(
      migrationId: migrationId ?? this.migrationId,
      checksum: checksum ?? this.checksum,
      appliedAt: appliedAt ?? this.appliedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (migrationId.present) {
      map['migration_id'] = Variable<String>(migrationId.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (appliedAt.present) {
      map['applied_at'] = Variable<int>(appliedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeedMigrationsCompanion(')
          ..write('migrationId: $migrationId, ')
          ..write('checksum: $checksum, ')
          ..write('appliedAt: $appliedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserPreferencesTable extends UserPreferences
    with TableInfo<$UserPreferencesTable, UserPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
    'theme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viewSettingsJsonMeta = const VerificationMeta(
    'viewSettingsJson',
  );
  @override
  late final GeneratedColumn<String> viewSettingsJson = GeneratedColumn<String>(
    'view_settings_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notificationEnabledMeta =
      const VerificationMeta('notificationEnabled');
  @override
  late final GeneratedColumn<bool> notificationEnabled = GeneratedColumn<bool>(
    'notification_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notification_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notificationTimeMeta = const VerificationMeta(
    'notificationTime',
  );
  @override
  late final GeneratedColumn<int> notificationTime = GeneratedColumn<int>(
    'notification_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notificationDefaultOffsetsMeta =
      const VerificationMeta('notificationDefaultOffsets');
  @override
  late final GeneratedColumn<String> notificationDefaultOffsets =
      GeneratedColumn<String>(
        'notification_default_offsets',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _paymentAlertsEnabledMeta =
      const VerificationMeta('paymentAlertsEnabled');
  @override
  late final GeneratedColumn<bool> paymentAlertsEnabled = GeneratedColumn<bool>(
    'payment_alerts_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("payment_alerts_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    language,
    theme,
    viewSettingsJson,
    notificationEnabled,
    notificationTime,
    notificationDefaultOffsets,
    paymentAlertsEnabled,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('theme')) {
      context.handle(
        _themeMeta,
        theme.isAcceptableOrUnknown(data['theme']!, _themeMeta),
      );
    }
    if (data.containsKey('view_settings_json')) {
      context.handle(
        _viewSettingsJsonMeta,
        viewSettingsJson.isAcceptableOrUnknown(
          data['view_settings_json']!,
          _viewSettingsJsonMeta,
        ),
      );
    }
    if (data.containsKey('notification_enabled')) {
      context.handle(
        _notificationEnabledMeta,
        notificationEnabled.isAcceptableOrUnknown(
          data['notification_enabled']!,
          _notificationEnabledMeta,
        ),
      );
    }
    if (data.containsKey('notification_time')) {
      context.handle(
        _notificationTimeMeta,
        notificationTime.isAcceptableOrUnknown(
          data['notification_time']!,
          _notificationTimeMeta,
        ),
      );
    }
    if (data.containsKey('notification_default_offsets')) {
      context.handle(
        _notificationDefaultOffsetsMeta,
        notificationDefaultOffsets.isAcceptableOrUnknown(
          data['notification_default_offsets']!,
          _notificationDefaultOffsetsMeta,
        ),
      );
    }
    if (data.containsKey('payment_alerts_enabled')) {
      context.handle(
        _paymentAlertsEnabledMeta,
        paymentAlertsEnabled.isAcceptableOrUnknown(
          data['payment_alerts_enabled']!,
          _paymentAlertsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  UserPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreference(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      theme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme'],
      ),
      viewSettingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}view_settings_json'],
      ),
      notificationEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notification_enabled'],
      )!,
      notificationTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_time'],
      ),
      notificationDefaultOffsets: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notification_default_offsets'],
      ),
      paymentAlertsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}payment_alerts_enabled'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserPreferencesTable createAlias(String alias) {
    return $UserPreferencesTable(attachedDatabase, alias);
  }
}

class UserPreference extends DataClass implements Insertable<UserPreference> {
  /// User UUID these preferences belong to.
  final String userId;

  /// Selected UI language code (e.g. `en`, `bn`).
  final String? language;

  /// Selected theme mode (e.g. `light`, `dark`, `system`).
  final String? theme;

  /// JSON blob for view settings, navigation tab order, backup-nudge
  /// metadata, and any other per-user view/navigation configuration.
  final String? viewSettingsJson;

  /// Master toggle for notifications.
  ///
  /// Defaults to true (user request, 0.0.697): an account that has never chosen
  /// hears its hearing reminders, and can silence them here. A row written by
  /// an older build keeps the value it stored.
  final bool notificationEnabled;

  /// Preferred notification time of day (epoch ms or minutes-since-midnight;
  /// interpretation left to the notification task).
  final int? notificationTime;

  /// JSON array of default notification day offsets before a hearing.
  final String? notificationDefaultOffsets;

  /// Whether this account wants a push when an admin's payment request is
  /// waiting (Settings → Notifications).
  ///
  /// Defaults to true: an admin who installs the panel wants to hear about
  /// payments waiting, and can silence it. It is synced per-user to
  /// `user_preferences.payment_alerts_enabled`, which the sender reads — an
  /// account whose toggle is off is skipped server-side, so the switch works
  /// even while the app is closed.
  final bool paymentAlertsEnabled;

  /// Timestamp when these preferences were last updated (epoch ms).
  final int updatedAt;
  const UserPreference({
    required this.userId,
    this.language,
    this.theme,
    this.viewSettingsJson,
    required this.notificationEnabled,
    this.notificationTime,
    this.notificationDefaultOffsets,
    required this.paymentAlertsEnabled,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || theme != null) {
      map['theme'] = Variable<String>(theme);
    }
    if (!nullToAbsent || viewSettingsJson != null) {
      map['view_settings_json'] = Variable<String>(viewSettingsJson);
    }
    map['notification_enabled'] = Variable<bool>(notificationEnabled);
    if (!nullToAbsent || notificationTime != null) {
      map['notification_time'] = Variable<int>(notificationTime);
    }
    if (!nullToAbsent || notificationDefaultOffsets != null) {
      map['notification_default_offsets'] = Variable<String>(
        notificationDefaultOffsets,
      );
    }
    map['payment_alerts_enabled'] = Variable<bool>(paymentAlertsEnabled);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  UserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesCompanion(
      userId: Value(userId),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      theme: theme == null && nullToAbsent
          ? const Value.absent()
          : Value(theme),
      viewSettingsJson: viewSettingsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(viewSettingsJson),
      notificationEnabled: Value(notificationEnabled),
      notificationTime: notificationTime == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationTime),
      notificationDefaultOffsets:
          notificationDefaultOffsets == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationDefaultOffsets),
      paymentAlertsEnabled: Value(paymentAlertsEnabled),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreference(
      userId: serializer.fromJson<String>(json['userId']),
      language: serializer.fromJson<String?>(json['language']),
      theme: serializer.fromJson<String?>(json['theme']),
      viewSettingsJson: serializer.fromJson<String?>(json['viewSettingsJson']),
      notificationEnabled: serializer.fromJson<bool>(
        json['notificationEnabled'],
      ),
      notificationTime: serializer.fromJson<int?>(json['notificationTime']),
      notificationDefaultOffsets: serializer.fromJson<String?>(
        json['notificationDefaultOffsets'],
      ),
      paymentAlertsEnabled: serializer.fromJson<bool>(
        json['paymentAlertsEnabled'],
      ),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'language': serializer.toJson<String?>(language),
      'theme': serializer.toJson<String?>(theme),
      'viewSettingsJson': serializer.toJson<String?>(viewSettingsJson),
      'notificationEnabled': serializer.toJson<bool>(notificationEnabled),
      'notificationTime': serializer.toJson<int?>(notificationTime),
      'notificationDefaultOffsets': serializer.toJson<String?>(
        notificationDefaultOffsets,
      ),
      'paymentAlertsEnabled': serializer.toJson<bool>(paymentAlertsEnabled),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  UserPreference copyWith({
    String? userId,
    Value<String?> language = const Value.absent(),
    Value<String?> theme = const Value.absent(),
    Value<String?> viewSettingsJson = const Value.absent(),
    bool? notificationEnabled,
    Value<int?> notificationTime = const Value.absent(),
    Value<String?> notificationDefaultOffsets = const Value.absent(),
    bool? paymentAlertsEnabled,
    int? updatedAt,
  }) => UserPreference(
    userId: userId ?? this.userId,
    language: language.present ? language.value : this.language,
    theme: theme.present ? theme.value : this.theme,
    viewSettingsJson: viewSettingsJson.present
        ? viewSettingsJson.value
        : this.viewSettingsJson,
    notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    notificationTime: notificationTime.present
        ? notificationTime.value
        : this.notificationTime,
    notificationDefaultOffsets: notificationDefaultOffsets.present
        ? notificationDefaultOffsets.value
        : this.notificationDefaultOffsets,
    paymentAlertsEnabled: paymentAlertsEnabled ?? this.paymentAlertsEnabled,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserPreference copyWithCompanion(UserPreferencesCompanion data) {
    return UserPreference(
      userId: data.userId.present ? data.userId.value : this.userId,
      language: data.language.present ? data.language.value : this.language,
      theme: data.theme.present ? data.theme.value : this.theme,
      viewSettingsJson: data.viewSettingsJson.present
          ? data.viewSettingsJson.value
          : this.viewSettingsJson,
      notificationEnabled: data.notificationEnabled.present
          ? data.notificationEnabled.value
          : this.notificationEnabled,
      notificationTime: data.notificationTime.present
          ? data.notificationTime.value
          : this.notificationTime,
      notificationDefaultOffsets: data.notificationDefaultOffsets.present
          ? data.notificationDefaultOffsets.value
          : this.notificationDefaultOffsets,
      paymentAlertsEnabled: data.paymentAlertsEnabled.present
          ? data.paymentAlertsEnabled.value
          : this.paymentAlertsEnabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreference(')
          ..write('userId: $userId, ')
          ..write('language: $language, ')
          ..write('theme: $theme, ')
          ..write('viewSettingsJson: $viewSettingsJson, ')
          ..write('notificationEnabled: $notificationEnabled, ')
          ..write('notificationTime: $notificationTime, ')
          ..write('notificationDefaultOffsets: $notificationDefaultOffsets, ')
          ..write('paymentAlertsEnabled: $paymentAlertsEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    language,
    theme,
    viewSettingsJson,
    notificationEnabled,
    notificationTime,
    notificationDefaultOffsets,
    paymentAlertsEnabled,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreference &&
          other.userId == this.userId &&
          other.language == this.language &&
          other.theme == this.theme &&
          other.viewSettingsJson == this.viewSettingsJson &&
          other.notificationEnabled == this.notificationEnabled &&
          other.notificationTime == this.notificationTime &&
          other.notificationDefaultOffsets == this.notificationDefaultOffsets &&
          other.paymentAlertsEnabled == this.paymentAlertsEnabled &&
          other.updatedAt == this.updatedAt);
}

class UserPreferencesCompanion extends UpdateCompanion<UserPreference> {
  final Value<String> userId;
  final Value<String?> language;
  final Value<String?> theme;
  final Value<String?> viewSettingsJson;
  final Value<bool> notificationEnabled;
  final Value<int?> notificationTime;
  final Value<String?> notificationDefaultOffsets;
  final Value<bool> paymentAlertsEnabled;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const UserPreferencesCompanion({
    this.userId = const Value.absent(),
    this.language = const Value.absent(),
    this.theme = const Value.absent(),
    this.viewSettingsJson = const Value.absent(),
    this.notificationEnabled = const Value.absent(),
    this.notificationTime = const Value.absent(),
    this.notificationDefaultOffsets = const Value.absent(),
    this.paymentAlertsEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserPreferencesCompanion.insert({
    required String userId,
    this.language = const Value.absent(),
    this.theme = const Value.absent(),
    this.viewSettingsJson = const Value.absent(),
    this.notificationEnabled = const Value.absent(),
    this.notificationTime = const Value.absent(),
    this.notificationDefaultOffsets = const Value.absent(),
    this.paymentAlertsEnabled = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       updatedAt = Value(updatedAt);
  static Insertable<UserPreference> custom({
    Expression<String>? userId,
    Expression<String>? language,
    Expression<String>? theme,
    Expression<String>? viewSettingsJson,
    Expression<bool>? notificationEnabled,
    Expression<int>? notificationTime,
    Expression<String>? notificationDefaultOffsets,
    Expression<bool>? paymentAlertsEnabled,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (language != null) 'language': language,
      if (theme != null) 'theme': theme,
      if (viewSettingsJson != null) 'view_settings_json': viewSettingsJson,
      if (notificationEnabled != null)
        'notification_enabled': notificationEnabled,
      if (notificationTime != null) 'notification_time': notificationTime,
      if (notificationDefaultOffsets != null)
        'notification_default_offsets': notificationDefaultOffsets,
      if (paymentAlertsEnabled != null)
        'payment_alerts_enabled': paymentAlertsEnabled,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserPreferencesCompanion copyWith({
    Value<String>? userId,
    Value<String?>? language,
    Value<String?>? theme,
    Value<String?>? viewSettingsJson,
    Value<bool>? notificationEnabled,
    Value<int?>? notificationTime,
    Value<String?>? notificationDefaultOffsets,
    Value<bool>? paymentAlertsEnabled,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserPreferencesCompanion(
      userId: userId ?? this.userId,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      viewSettingsJson: viewSettingsJson ?? this.viewSettingsJson,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      notificationTime: notificationTime ?? this.notificationTime,
      notificationDefaultOffsets:
          notificationDefaultOffsets ?? this.notificationDefaultOffsets,
      paymentAlertsEnabled: paymentAlertsEnabled ?? this.paymentAlertsEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    if (viewSettingsJson.present) {
      map['view_settings_json'] = Variable<String>(viewSettingsJson.value);
    }
    if (notificationEnabled.present) {
      map['notification_enabled'] = Variable<bool>(notificationEnabled.value);
    }
    if (notificationTime.present) {
      map['notification_time'] = Variable<int>(notificationTime.value);
    }
    if (notificationDefaultOffsets.present) {
      map['notification_default_offsets'] = Variable<String>(
        notificationDefaultOffsets.value,
      );
    }
    if (paymentAlertsEnabled.present) {
      map['payment_alerts_enabled'] = Variable<bool>(
        paymentAlertsEnabled.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesCompanion(')
          ..write('userId: $userId, ')
          ..write('language: $language, ')
          ..write('theme: $theme, ')
          ..write('viewSettingsJson: $viewSettingsJson, ')
          ..write('notificationEnabled: $notificationEnabled, ')
          ..write('notificationTime: $notificationTime, ')
          ..write('notificationDefaultOffsets: $notificationDefaultOffsets, ')
          ..write('paymentAlertsEnabled: $paymentAlertsEnabled, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CaseNotificationPreferencesTable extends CaseNotificationPreferences
    with
        TableInfo<
          $CaseNotificationPreferencesTable,
          CaseNotificationPreference
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaseNotificationPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caseIdMeta = const VerificationMeta('caseId');
  @override
  late final GeneratedColumn<String> caseId = GeneratedColumn<String>(
    'case_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _offsetsMeta = const VerificationMeta(
    'offsets',
  );
  @override
  late final GeneratedColumn<String> offsets = GeneratedColumn<String>(
    'offsets',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeMinutesMeta = const VerificationMeta(
    'timeMinutes',
  );
  @override
  late final GeneratedColumn<int> timeMinutes = GeneratedColumn<int>(
    'time_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    caseId,
    enabled,
    offsets,
    timeMinutes,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'case_notification_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaseNotificationPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('case_id')) {
      context.handle(
        _caseIdMeta,
        caseId.isAcceptableOrUnknown(data['case_id']!, _caseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_caseIdMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('offsets')) {
      context.handle(
        _offsetsMeta,
        offsets.isAcceptableOrUnknown(data['offsets']!, _offsetsMeta),
      );
    }
    if (data.containsKey('time_minutes')) {
      context.handle(
        _timeMinutesMeta,
        timeMinutes.isAcceptableOrUnknown(
          data['time_minutes']!,
          _timeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, caseId};
  @override
  CaseNotificationPreference map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaseNotificationPreference(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      caseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_id'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      offsets: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}offsets'],
      ),
      timeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_minutes'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CaseNotificationPreferencesTable createAlias(String alias) {
    return $CaseNotificationPreferencesTable(attachedDatabase, alias);
  }
}

class CaseNotificationPreference extends DataClass
    implements Insertable<CaseNotificationPreference> {
  /// User UUID these preferences belong to.
  final String userId;

  /// Case UUID.
  final String caseId;

  /// Whether notifications are enabled for this case.
  final bool enabled;

  /// JSON array of day offsets for this case; if null, falls back to the
  /// user's default offsets.
  final String? offsets;

  /// Minutes since midnight for this case's alerts; if null, the case follows
  /// the user's default notification time in `user_preferences`. A value here
  /// is a per-case override, so one case can alert at a different time of day.
  final int? timeMinutes;

  /// Timestamp when these preferences were last updated (epoch ms).
  final int updatedAt;
  const CaseNotificationPreference({
    required this.userId,
    required this.caseId,
    required this.enabled,
    this.offsets,
    this.timeMinutes,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['case_id'] = Variable<String>(caseId);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || offsets != null) {
      map['offsets'] = Variable<String>(offsets);
    }
    if (!nullToAbsent || timeMinutes != null) {
      map['time_minutes'] = Variable<int>(timeMinutes);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CaseNotificationPreferencesCompanion toCompanion(bool nullToAbsent) {
    return CaseNotificationPreferencesCompanion(
      userId: Value(userId),
      caseId: Value(caseId),
      enabled: Value(enabled),
      offsets: offsets == null && nullToAbsent
          ? const Value.absent()
          : Value(offsets),
      timeMinutes: timeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(timeMinutes),
      updatedAt: Value(updatedAt),
    );
  }

  factory CaseNotificationPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaseNotificationPreference(
      userId: serializer.fromJson<String>(json['userId']),
      caseId: serializer.fromJson<String>(json['caseId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      offsets: serializer.fromJson<String?>(json['offsets']),
      timeMinutes: serializer.fromJson<int?>(json['timeMinutes']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'caseId': serializer.toJson<String>(caseId),
      'enabled': serializer.toJson<bool>(enabled),
      'offsets': serializer.toJson<String?>(offsets),
      'timeMinutes': serializer.toJson<int?>(timeMinutes),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CaseNotificationPreference copyWith({
    String? userId,
    String? caseId,
    bool? enabled,
    Value<String?> offsets = const Value.absent(),
    Value<int?> timeMinutes = const Value.absent(),
    int? updatedAt,
  }) => CaseNotificationPreference(
    userId: userId ?? this.userId,
    caseId: caseId ?? this.caseId,
    enabled: enabled ?? this.enabled,
    offsets: offsets.present ? offsets.value : this.offsets,
    timeMinutes: timeMinutes.present ? timeMinutes.value : this.timeMinutes,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CaseNotificationPreference copyWithCompanion(
    CaseNotificationPreferencesCompanion data,
  ) {
    return CaseNotificationPreference(
      userId: data.userId.present ? data.userId.value : this.userId,
      caseId: data.caseId.present ? data.caseId.value : this.caseId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      offsets: data.offsets.present ? data.offsets.value : this.offsets,
      timeMinutes: data.timeMinutes.present
          ? data.timeMinutes.value
          : this.timeMinutes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaseNotificationPreference(')
          ..write('userId: $userId, ')
          ..write('caseId: $caseId, ')
          ..write('enabled: $enabled, ')
          ..write('offsets: $offsets, ')
          ..write('timeMinutes: $timeMinutes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, caseId, enabled, offsets, timeMinutes, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaseNotificationPreference &&
          other.userId == this.userId &&
          other.caseId == this.caseId &&
          other.enabled == this.enabled &&
          other.offsets == this.offsets &&
          other.timeMinutes == this.timeMinutes &&
          other.updatedAt == this.updatedAt);
}

class CaseNotificationPreferencesCompanion
    extends UpdateCompanion<CaseNotificationPreference> {
  final Value<String> userId;
  final Value<String> caseId;
  final Value<bool> enabled;
  final Value<String?> offsets;
  final Value<int?> timeMinutes;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CaseNotificationPreferencesCompanion({
    this.userId = const Value.absent(),
    this.caseId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.offsets = const Value.absent(),
    this.timeMinutes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaseNotificationPreferencesCompanion.insert({
    required String userId,
    required String caseId,
    this.enabled = const Value.absent(),
    this.offsets = const Value.absent(),
    this.timeMinutes = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       caseId = Value(caseId),
       updatedAt = Value(updatedAt);
  static Insertable<CaseNotificationPreference> custom({
    Expression<String>? userId,
    Expression<String>? caseId,
    Expression<bool>? enabled,
    Expression<String>? offsets,
    Expression<int>? timeMinutes,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (caseId != null) 'case_id': caseId,
      if (enabled != null) 'enabled': enabled,
      if (offsets != null) 'offsets': offsets,
      if (timeMinutes != null) 'time_minutes': timeMinutes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaseNotificationPreferencesCompanion copyWith({
    Value<String>? userId,
    Value<String>? caseId,
    Value<bool>? enabled,
    Value<String?>? offsets,
    Value<int?>? timeMinutes,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CaseNotificationPreferencesCompanion(
      userId: userId ?? this.userId,
      caseId: caseId ?? this.caseId,
      enabled: enabled ?? this.enabled,
      offsets: offsets ?? this.offsets,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (caseId.present) {
      map['case_id'] = Variable<String>(caseId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (offsets.present) {
      map['offsets'] = Variable<String>(offsets.value);
    }
    if (timeMinutes.present) {
      map['time_minutes'] = Variable<int>(timeMinutes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaseNotificationPreferencesCompanion(')
          ..write('userId: $userId, ')
          ..write('caseId: $caseId, ')
          ..write('enabled: $enabled, ')
          ..write('offsets: $offsets, ')
          ..write('timeMinutes: $timeMinutes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedCaseReferencesTable extends SharedCaseReferences
    with TableInfo<$SharedCaseReferencesTable, SharedCaseReference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedCaseReferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceAndPageNoMeta =
      const VerificationMeta('referenceAndPageNo');
  @override
  late final GeneratedColumn<String> referenceAndPageNo =
      GeneratedColumn<String>(
        'reference_and_page_no',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statuteMeta = const VerificationMeta(
    'statute',
  );
  @override
  late final GeneratedColumn<String> statute = GeneratedColumn<String>(
    'statute',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionOrArticleMeta = const VerificationMeta(
    'sectionOrArticle',
  );
  @override
  late final GeneratedColumn<String> sectionOrArticle = GeneratedColumn<String>(
    'section_or_article',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleAndDescriptionMeta =
      const VerificationMeta('titleAndDescription');
  @override
  late final GeneratedColumn<String> titleAndDescription =
      GeneratedColumn<String>(
        'title_and_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _commentsNotesMeta = const VerificationMeta(
    'commentsNotes',
  );
  @override
  late final GeneratedColumn<String> commentsNotes = GeneratedColumn<String>(
    'comments_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caseNoteMeta = const VerificationMeta(
    'caseNote',
  );
  @override
  late final GeneratedColumn<String> caseNote = GeneratedColumn<String>(
    'case_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    referenceAndPageNo,
    statute,
    sectionOrArticle,
    titleAndDescription,
    commentsNotes,
    caseNote,
    tags,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_case_references';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedCaseReference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('reference_and_page_no')) {
      context.handle(
        _referenceAndPageNoMeta,
        referenceAndPageNo.isAcceptableOrUnknown(
          data['reference_and_page_no']!,
          _referenceAndPageNoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_referenceAndPageNoMeta);
    }
    if (data.containsKey('statute')) {
      context.handle(
        _statuteMeta,
        statute.isAcceptableOrUnknown(data['statute']!, _statuteMeta),
      );
    }
    if (data.containsKey('section_or_article')) {
      context.handle(
        _sectionOrArticleMeta,
        sectionOrArticle.isAcceptableOrUnknown(
          data['section_or_article']!,
          _sectionOrArticleMeta,
        ),
      );
    }
    if (data.containsKey('title_and_description')) {
      context.handle(
        _titleAndDescriptionMeta,
        titleAndDescription.isAcceptableOrUnknown(
          data['title_and_description']!,
          _titleAndDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('comments_notes')) {
      context.handle(
        _commentsNotesMeta,
        commentsNotes.isAcceptableOrUnknown(
          data['comments_notes']!,
          _commentsNotesMeta,
        ),
      );
    }
    if (data.containsKey('case_note')) {
      context.handle(
        _caseNoteMeta,
        caseNote.isAcceptableOrUnknown(data['case_note']!, _caseNoteMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharedCaseReference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedCaseReference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      referenceAndPageNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_and_page_no'],
      )!,
      statute: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statute'],
      ),
      sectionOrArticle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_or_article'],
      ),
      titleAndDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_and_description'],
      ),
      commentsNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comments_notes'],
      ),
      caseNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_note'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $SharedCaseReferencesTable createAlias(String alias) {
    return $SharedCaseReferencesTable(attachedDatabase, alias);
  }
}

class SharedCaseReference extends DataClass
    implements Insertable<SharedCaseReference> {
  /// UUID primary key, assigned by the admin's device.
  final String id;

  /// Reference and page number, e.g. `29 DLR (AD) 69`.
  final String referenceAndPageNo;

  /// The cited Act/statute name, as free text like the user's own references.
  final String? statute;

  /// Section or article number.
  final String? sectionOrArticle;

  /// Title and description of the principle.
  final String? titleAndDescription;

  /// Comments or notes the admin attached.
  final String? commentsNotes;

  /// A note on the case itself, beside the case summary.
  final String? caseNote;

  /// Comma-separated tags used to group and find citations.
  final String? tags;

  /// Tombstone written by the server; a live query filters these out.
  final bool isDeleted;
  const SharedCaseReference({
    required this.id,
    required this.referenceAndPageNo,
    this.statute,
    this.sectionOrArticle,
    this.titleAndDescription,
    this.commentsNotes,
    this.caseNote,
    this.tags,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['reference_and_page_no'] = Variable<String>(referenceAndPageNo);
    if (!nullToAbsent || statute != null) {
      map['statute'] = Variable<String>(statute);
    }
    if (!nullToAbsent || sectionOrArticle != null) {
      map['section_or_article'] = Variable<String>(sectionOrArticle);
    }
    if (!nullToAbsent || titleAndDescription != null) {
      map['title_and_description'] = Variable<String>(titleAndDescription);
    }
    if (!nullToAbsent || commentsNotes != null) {
      map['comments_notes'] = Variable<String>(commentsNotes);
    }
    if (!nullToAbsent || caseNote != null) {
      map['case_note'] = Variable<String>(caseNote);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  SharedCaseReferencesCompanion toCompanion(bool nullToAbsent) {
    return SharedCaseReferencesCompanion(
      id: Value(id),
      referenceAndPageNo: Value(referenceAndPageNo),
      statute: statute == null && nullToAbsent
          ? const Value.absent()
          : Value(statute),
      sectionOrArticle: sectionOrArticle == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionOrArticle),
      titleAndDescription: titleAndDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(titleAndDescription),
      commentsNotes: commentsNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(commentsNotes),
      caseNote: caseNote == null && nullToAbsent
          ? const Value.absent()
          : Value(caseNote),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      isDeleted: Value(isDeleted),
    );
  }

  factory SharedCaseReference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedCaseReference(
      id: serializer.fromJson<String>(json['id']),
      referenceAndPageNo: serializer.fromJson<String>(
        json['referenceAndPageNo'],
      ),
      statute: serializer.fromJson<String?>(json['statute']),
      sectionOrArticle: serializer.fromJson<String?>(json['sectionOrArticle']),
      titleAndDescription: serializer.fromJson<String?>(
        json['titleAndDescription'],
      ),
      commentsNotes: serializer.fromJson<String?>(json['commentsNotes']),
      caseNote: serializer.fromJson<String?>(json['caseNote']),
      tags: serializer.fromJson<String?>(json['tags']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'referenceAndPageNo': serializer.toJson<String>(referenceAndPageNo),
      'statute': serializer.toJson<String?>(statute),
      'sectionOrArticle': serializer.toJson<String?>(sectionOrArticle),
      'titleAndDescription': serializer.toJson<String?>(titleAndDescription),
      'commentsNotes': serializer.toJson<String?>(commentsNotes),
      'caseNote': serializer.toJson<String?>(caseNote),
      'tags': serializer.toJson<String?>(tags),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  SharedCaseReference copyWith({
    String? id,
    String? referenceAndPageNo,
    Value<String?> statute = const Value.absent(),
    Value<String?> sectionOrArticle = const Value.absent(),
    Value<String?> titleAndDescription = const Value.absent(),
    Value<String?> commentsNotes = const Value.absent(),
    Value<String?> caseNote = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    bool? isDeleted,
  }) => SharedCaseReference(
    id: id ?? this.id,
    referenceAndPageNo: referenceAndPageNo ?? this.referenceAndPageNo,
    statute: statute.present ? statute.value : this.statute,
    sectionOrArticle: sectionOrArticle.present
        ? sectionOrArticle.value
        : this.sectionOrArticle,
    titleAndDescription: titleAndDescription.present
        ? titleAndDescription.value
        : this.titleAndDescription,
    commentsNotes: commentsNotes.present
        ? commentsNotes.value
        : this.commentsNotes,
    caseNote: caseNote.present ? caseNote.value : this.caseNote,
    tags: tags.present ? tags.value : this.tags,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  SharedCaseReference copyWithCompanion(SharedCaseReferencesCompanion data) {
    return SharedCaseReference(
      id: data.id.present ? data.id.value : this.id,
      referenceAndPageNo: data.referenceAndPageNo.present
          ? data.referenceAndPageNo.value
          : this.referenceAndPageNo,
      statute: data.statute.present ? data.statute.value : this.statute,
      sectionOrArticle: data.sectionOrArticle.present
          ? data.sectionOrArticle.value
          : this.sectionOrArticle,
      titleAndDescription: data.titleAndDescription.present
          ? data.titleAndDescription.value
          : this.titleAndDescription,
      commentsNotes: data.commentsNotes.present
          ? data.commentsNotes.value
          : this.commentsNotes,
      caseNote: data.caseNote.present ? data.caseNote.value : this.caseNote,
      tags: data.tags.present ? data.tags.value : this.tags,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedCaseReference(')
          ..write('id: $id, ')
          ..write('referenceAndPageNo: $referenceAndPageNo, ')
          ..write('statute: $statute, ')
          ..write('sectionOrArticle: $sectionOrArticle, ')
          ..write('titleAndDescription: $titleAndDescription, ')
          ..write('commentsNotes: $commentsNotes, ')
          ..write('caseNote: $caseNote, ')
          ..write('tags: $tags, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    referenceAndPageNo,
    statute,
    sectionOrArticle,
    titleAndDescription,
    commentsNotes,
    caseNote,
    tags,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedCaseReference &&
          other.id == this.id &&
          other.referenceAndPageNo == this.referenceAndPageNo &&
          other.statute == this.statute &&
          other.sectionOrArticle == this.sectionOrArticle &&
          other.titleAndDescription == this.titleAndDescription &&
          other.commentsNotes == this.commentsNotes &&
          other.caseNote == this.caseNote &&
          other.tags == this.tags &&
          other.isDeleted == this.isDeleted);
}

class SharedCaseReferencesCompanion
    extends UpdateCompanion<SharedCaseReference> {
  final Value<String> id;
  final Value<String> referenceAndPageNo;
  final Value<String?> statute;
  final Value<String?> sectionOrArticle;
  final Value<String?> titleAndDescription;
  final Value<String?> commentsNotes;
  final Value<String?> caseNote;
  final Value<String?> tags;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const SharedCaseReferencesCompanion({
    this.id = const Value.absent(),
    this.referenceAndPageNo = const Value.absent(),
    this.statute = const Value.absent(),
    this.sectionOrArticle = const Value.absent(),
    this.titleAndDescription = const Value.absent(),
    this.commentsNotes = const Value.absent(),
    this.caseNote = const Value.absent(),
    this.tags = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedCaseReferencesCompanion.insert({
    required String id,
    required String referenceAndPageNo,
    this.statute = const Value.absent(),
    this.sectionOrArticle = const Value.absent(),
    this.titleAndDescription = const Value.absent(),
    this.commentsNotes = const Value.absent(),
    this.caseNote = const Value.absent(),
    this.tags = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       referenceAndPageNo = Value(referenceAndPageNo);
  static Insertable<SharedCaseReference> custom({
    Expression<String>? id,
    Expression<String>? referenceAndPageNo,
    Expression<String>? statute,
    Expression<String>? sectionOrArticle,
    Expression<String>? titleAndDescription,
    Expression<String>? commentsNotes,
    Expression<String>? caseNote,
    Expression<String>? tags,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (referenceAndPageNo != null)
        'reference_and_page_no': referenceAndPageNo,
      if (statute != null) 'statute': statute,
      if (sectionOrArticle != null) 'section_or_article': sectionOrArticle,
      if (titleAndDescription != null)
        'title_and_description': titleAndDescription,
      if (commentsNotes != null) 'comments_notes': commentsNotes,
      if (caseNote != null) 'case_note': caseNote,
      if (tags != null) 'tags': tags,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedCaseReferencesCompanion copyWith({
    Value<String>? id,
    Value<String>? referenceAndPageNo,
    Value<String?>? statute,
    Value<String?>? sectionOrArticle,
    Value<String?>? titleAndDescription,
    Value<String?>? commentsNotes,
    Value<String?>? caseNote,
    Value<String?>? tags,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return SharedCaseReferencesCompanion(
      id: id ?? this.id,
      referenceAndPageNo: referenceAndPageNo ?? this.referenceAndPageNo,
      statute: statute ?? this.statute,
      sectionOrArticle: sectionOrArticle ?? this.sectionOrArticle,
      titleAndDescription: titleAndDescription ?? this.titleAndDescription,
      commentsNotes: commentsNotes ?? this.commentsNotes,
      caseNote: caseNote ?? this.caseNote,
      tags: tags ?? this.tags,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (referenceAndPageNo.present) {
      map['reference_and_page_no'] = Variable<String>(referenceAndPageNo.value);
    }
    if (statute.present) {
      map['statute'] = Variable<String>(statute.value);
    }
    if (sectionOrArticle.present) {
      map['section_or_article'] = Variable<String>(sectionOrArticle.value);
    }
    if (titleAndDescription.present) {
      map['title_and_description'] = Variable<String>(
        titleAndDescription.value,
      );
    }
    if (commentsNotes.present) {
      map['comments_notes'] = Variable<String>(commentsNotes.value);
    }
    if (caseNote.present) {
      map['case_note'] = Variable<String>(caseNote.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedCaseReferencesCompanion(')
          ..write('id: $id, ')
          ..write('referenceAndPageNo: $referenceAndPageNo, ')
          ..write('statute: $statute, ')
          ..write('sectionOrArticle: $sectionOrArticle, ')
          ..write('titleAndDescription: $titleAndDescription, ')
          ..write('commentsNotes: $commentsNotes, ')
          ..write('caseNote: $caseNote, ')
          ..write('tags: $tags, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedCaseReferencePinsTable extends SharedCaseReferencePins
    with TableInfo<$SharedCaseReferencePinsTable, SharedCaseReferencePin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedCaseReferencePinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _referenceIdMeta = const VerificationMeta(
    'referenceId',
  );
  @override
  late final GeneratedColumn<String> referenceId = GeneratedColumn<String>(
    'reference_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta(
    'pinnedAt',
  );
  @override
  late final GeneratedColumn<int> pinnedAt = GeneratedColumn<int>(
    'pinned_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [referenceId, pinnedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_case_reference_pins';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedCaseReferencePin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reference_id')) {
      context.handle(
        _referenceIdMeta,
        referenceId.isAcceptableOrUnknown(
          data['reference_id']!,
          _referenceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_referenceIdMeta);
    }
    if (data.containsKey('pinned_at')) {
      context.handle(
        _pinnedAtMeta,
        pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_pinnedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {referenceId};
  @override
  SharedCaseReferencePin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedCaseReferencePin(
      referenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_id'],
      )!,
      pinnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pinned_at'],
      )!,
    );
  }

  @override
  $SharedCaseReferencePinsTable createAlias(String alias) {
    return $SharedCaseReferencePinsTable(attachedDatabase, alias);
  }
}

class SharedCaseReferencePin extends DataClass
    implements Insertable<SharedCaseReferencePin> {
  /// The official reference's id; one pin per reference per device.
  final String referenceId;

  /// When the pin was made (epoch ms), so the list can order pins the same way
  /// the user's own pinned references sort.
  final int pinnedAt;
  const SharedCaseReferencePin({
    required this.referenceId,
    required this.pinnedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['reference_id'] = Variable<String>(referenceId);
    map['pinned_at'] = Variable<int>(pinnedAt);
    return map;
  }

  SharedCaseReferencePinsCompanion toCompanion(bool nullToAbsent) {
    return SharedCaseReferencePinsCompanion(
      referenceId: Value(referenceId),
      pinnedAt: Value(pinnedAt),
    );
  }

  factory SharedCaseReferencePin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedCaseReferencePin(
      referenceId: serializer.fromJson<String>(json['referenceId']),
      pinnedAt: serializer.fromJson<int>(json['pinnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'referenceId': serializer.toJson<String>(referenceId),
      'pinnedAt': serializer.toJson<int>(pinnedAt),
    };
  }

  SharedCaseReferencePin copyWith({String? referenceId, int? pinnedAt}) =>
      SharedCaseReferencePin(
        referenceId: referenceId ?? this.referenceId,
        pinnedAt: pinnedAt ?? this.pinnedAt,
      );
  SharedCaseReferencePin copyWithCompanion(
    SharedCaseReferencePinsCompanion data,
  ) {
    return SharedCaseReferencePin(
      referenceId: data.referenceId.present
          ? data.referenceId.value
          : this.referenceId,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedCaseReferencePin(')
          ..write('referenceId: $referenceId, ')
          ..write('pinnedAt: $pinnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(referenceId, pinnedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedCaseReferencePin &&
          other.referenceId == this.referenceId &&
          other.pinnedAt == this.pinnedAt);
}

class SharedCaseReferencePinsCompanion
    extends UpdateCompanion<SharedCaseReferencePin> {
  final Value<String> referenceId;
  final Value<int> pinnedAt;
  final Value<int> rowid;
  const SharedCaseReferencePinsCompanion({
    this.referenceId = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedCaseReferencePinsCompanion.insert({
    required String referenceId,
    required int pinnedAt,
    this.rowid = const Value.absent(),
  }) : referenceId = Value(referenceId),
       pinnedAt = Value(pinnedAt);
  static Insertable<SharedCaseReferencePin> custom({
    Expression<String>? referenceId,
    Expression<int>? pinnedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (referenceId != null) 'reference_id': referenceId,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedCaseReferencePinsCompanion copyWith({
    Value<String>? referenceId,
    Value<int>? pinnedAt,
    Value<int>? rowid,
  }) {
    return SharedCaseReferencePinsCompanion(
      referenceId: referenceId ?? this.referenceId,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (referenceId.present) {
      map['reference_id'] = Variable<String>(referenceId.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<int>(pinnedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedCaseReferencePinsCompanion(')
          ..write('referenceId: $referenceId, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CourtCategoriesTable courtCategories = $CourtCategoriesTable(
    this,
  );
  late final $CourtsTable courts = $CourtsTable(this);
  late final $CaseCategoriesTable caseCategories = $CaseCategoriesTable(this);
  late final $OnBehalfsTable onBehalfs = $OnBehalfsTable(this);
  late final $CasesTable cases = $CasesTable(this);
  late final $CaseHistoryTable caseHistory = $CaseHistoryTable(this);
  late final $StepsTable steps = $StepsTable(this);
  late final $LawsTable laws = $LawsTable(this);
  late final $CaseTypesTable caseTypes = $CaseTypesTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $CaseReferencesTable caseReferences = $CaseReferencesTable(this);
  late final $DeleteRequestsTable deleteRequests = $DeleteRequestsTable(this);
  late final $ConflictLogTable conflictLog = $ConflictLogTable(this);
  late final $FirmsTable firms = $FirmsTable(this);
  late final $FirmMembersTable firmMembers = $FirmMembersTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  late final $SeedMigrationsTable seedMigrations = $SeedMigrationsTable(this);
  late final $UserPreferencesTable userPreferences = $UserPreferencesTable(
    this,
  );
  late final $CaseNotificationPreferencesTable caseNotificationPreferences =
      $CaseNotificationPreferencesTable(this);
  late final $SharedCaseReferencesTable sharedCaseReferences =
      $SharedCaseReferencesTable(this);
  late final $SharedCaseReferencePinsTable sharedCaseReferencePins =
      $SharedCaseReferencePinsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    courtCategories,
    courts,
    caseCategories,
    onBehalfs,
    cases,
    caseHistory,
    steps,
    laws,
    caseTypes,
    notes,
    caseReferences,
    deleteRequests,
    conflictLog,
    firms,
    firmMembers,
    profiles,
    syncQueue,
    syncMetadata,
    seedMigrations,
    userPreferences,
    caseNotificationPreferences,
    sharedCaseReferences,
    sharedCaseReferencePins,
  ];
}

typedef $$CourtCategoriesTableCreateCompanionBuilder =
    CourtCategoriesCompanion Function({
      required String id,
      required String nameKey,
      required String courtLevel,
      required int orderIndex,
      Value<String?> division,
      Value<String?> district,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$CourtCategoriesTableUpdateCompanionBuilder =
    CourtCategoriesCompanion Function({
      Value<String> id,
      Value<String> nameKey,
      Value<String> courtLevel,
      Value<int> orderIndex,
      Value<String?> division,
      Value<String?> district,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

final class $$CourtCategoriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $CourtCategoriesTable, CourtCategory> {
  $$CourtCategoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CourtsTable, List<Court>> _courtsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.courts,
    aliasName: 'court_categories__id__courts__court_category_id',
  );

  $$CourtsTableProcessedTableManager get courtsRefs {
    final manager = $$CourtsTableTableManager($_db, $_db.courts).filter(
      (f) => f.courtCategoryId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_courtsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CaseCategoriesTable, List<CaseCategory>>
  _caseCategoriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.caseCategories,
    aliasName: 'court_categories__id__case_categories__court_category_id',
  );

  $$CaseCategoriesTableProcessedTableManager get caseCategoriesRefs {
    final manager = $$CaseCategoriesTableTableManager($_db, $_db.caseCategories)
        .filter(
          (f) => f.courtCategoryId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_caseCategoriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OnBehalfsTable, List<OnBehalf>>
  _onBehalfsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.onBehalfs,
    aliasName: 'court_categories__id__on_behalfs__court_category_id',
  );

  $$OnBehalfsTableProcessedTableManager get onBehalfsRefs {
    final manager = $$OnBehalfsTableTableManager($_db, $_db.onBehalfs).filter(
      (f) => f.courtCategoryId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_onBehalfsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StepsTable, List<Step>> _stepsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.steps,
    aliasName: 'court_categories__id__steps__court_category_id',
  );

  $$StepsTableProcessedTableManager get stepsRefs {
    final manager = $$StepsTableTableManager($_db, $_db.steps).filter(
      (f) => f.courtCategoryId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_stepsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CaseTypesTable, List<CaseType>>
  _caseTypesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.caseTypes,
    aliasName: 'court_categories__id__case_types__court_category_id',
  );

  $$CaseTypesTableProcessedTableManager get caseTypesRefs {
    final manager = $$CaseTypesTableTableManager($_db, $_db.caseTypes).filter(
      (f) => f.courtCategoryId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_caseTypesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CourtCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CourtCategoriesTable> {
  $$CourtCategoriesTableFilterComposer({
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

  ColumnFilters<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courtLevel => $composableBuilder(
    column: $table.courtLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get division => $composableBuilder(
    column: $table.division,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> courtsRefs(
    Expression<bool> Function($$CourtsTableFilterComposer f) f,
  ) {
    final $$CourtsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.courts,
      getReferencedColumn: (t) => t.courtCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtsTableFilterComposer(
            $db: $db,
            $table: $db.courts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> caseCategoriesRefs(
    Expression<bool> Function($$CaseCategoriesTableFilterComposer f) f,
  ) {
    final $$CaseCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.caseCategories,
      getReferencedColumn: (t) => t.courtCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.caseCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> onBehalfsRefs(
    Expression<bool> Function($$OnBehalfsTableFilterComposer f) f,
  ) {
    final $$OnBehalfsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.onBehalfs,
      getReferencedColumn: (t) => t.courtCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OnBehalfsTableFilterComposer(
            $db: $db,
            $table: $db.onBehalfs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stepsRefs(
    Expression<bool> Function($$StepsTableFilterComposer f) f,
  ) {
    final $$StepsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.steps,
      getReferencedColumn: (t) => t.courtCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StepsTableFilterComposer(
            $db: $db,
            $table: $db.steps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> caseTypesRefs(
    Expression<bool> Function($$CaseTypesTableFilterComposer f) f,
  ) {
    final $$CaseTypesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.caseTypes,
      getReferencedColumn: (t) => t.courtCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseTypesTableFilterComposer(
            $db: $db,
            $table: $db.caseTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CourtCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CourtCategoriesTable> {
  $$CourtCategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courtLevel => $composableBuilder(
    column: $table.courtLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get division => $composableBuilder(
    column: $table.division,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CourtCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CourtCategoriesTable> {
  $$CourtCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nameKey =>
      $composableBuilder(column: $table.nameKey, builder: (column) => column);

  GeneratedColumn<String> get courtLevel => $composableBuilder(
    column: $table.courtLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get division =>
      $composableBuilder(column: $table.division, builder: (column) => column);

  GeneratedColumn<String> get district =>
      $composableBuilder(column: $table.district, builder: (column) => column);

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );

  Expression<T> courtsRefs<T extends Object>(
    Expression<T> Function($$CourtsTableAnnotationComposer a) f,
  ) {
    final $$CourtsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.courts,
      getReferencedColumn: (t) => t.courtCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtsTableAnnotationComposer(
            $db: $db,
            $table: $db.courts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> caseCategoriesRefs<T extends Object>(
    Expression<T> Function($$CaseCategoriesTableAnnotationComposer a) f,
  ) {
    final $$CaseCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.caseCategories,
      getReferencedColumn: (t) => t.courtCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.caseCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> onBehalfsRefs<T extends Object>(
    Expression<T> Function($$OnBehalfsTableAnnotationComposer a) f,
  ) {
    final $$OnBehalfsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.onBehalfs,
      getReferencedColumn: (t) => t.courtCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OnBehalfsTableAnnotationComposer(
            $db: $db,
            $table: $db.onBehalfs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stepsRefs<T extends Object>(
    Expression<T> Function($$StepsTableAnnotationComposer a) f,
  ) {
    final $$StepsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.steps,
      getReferencedColumn: (t) => t.courtCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StepsTableAnnotationComposer(
            $db: $db,
            $table: $db.steps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> caseTypesRefs<T extends Object>(
    Expression<T> Function($$CaseTypesTableAnnotationComposer a) f,
  ) {
    final $$CaseTypesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.caseTypes,
      getReferencedColumn: (t) => t.courtCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseTypesTableAnnotationComposer(
            $db: $db,
            $table: $db.caseTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CourtCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CourtCategoriesTable,
          CourtCategory,
          $$CourtCategoriesTableFilterComposer,
          $$CourtCategoriesTableOrderingComposer,
          $$CourtCategoriesTableAnnotationComposer,
          $$CourtCategoriesTableCreateCompanionBuilder,
          $$CourtCategoriesTableUpdateCompanionBuilder,
          (CourtCategory, $$CourtCategoriesTableReferences),
          CourtCategory,
          PrefetchHooks Function({
            bool courtsRefs,
            bool caseCategoriesRefs,
            bool onBehalfsRefs,
            bool stepsRefs,
            bool caseTypesRefs,
          })
        > {
  $$CourtCategoriesTableTableManager(
    _$AppDatabase db,
    $CourtCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CourtCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CourtCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CourtCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nameKey = const Value.absent(),
                Value<String> courtLevel = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String?> division = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CourtCategoriesCompanion(
                id: id,
                nameKey: nameKey,
                courtLevel: courtLevel,
                orderIndex: orderIndex,
                division: division,
                district: district,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nameKey,
                required String courtLevel,
                required int orderIndex,
                Value<String?> division = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CourtCategoriesCompanion.insert(
                id: id,
                nameKey: nameKey,
                courtLevel: courtLevel,
                orderIndex: orderIndex,
                division: division,
                district: district,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CourtCategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                courtsRefs = false,
                caseCategoriesRefs = false,
                onBehalfsRefs = false,
                stepsRefs = false,
                caseTypesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (courtsRefs) db.courts,
                    if (caseCategoriesRefs) db.caseCategories,
                    if (onBehalfsRefs) db.onBehalfs,
                    if (stepsRefs) db.steps,
                    if (caseTypesRefs) db.caseTypes,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (courtsRefs)
                        await $_getPrefetchedData<
                          CourtCategory,
                          $CourtCategoriesTable,
                          Court
                        >(
                          currentTable: table,
                          referencedTable: $$CourtCategoriesTableReferences
                              ._courtsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CourtCategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).courtsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.courtCategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (caseCategoriesRefs)
                        await $_getPrefetchedData<
                          CourtCategory,
                          $CourtCategoriesTable,
                          CaseCategory
                        >(
                          currentTable: table,
                          referencedTable: $$CourtCategoriesTableReferences
                              ._caseCategoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CourtCategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).caseCategoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.courtCategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (onBehalfsRefs)
                        await $_getPrefetchedData<
                          CourtCategory,
                          $CourtCategoriesTable,
                          OnBehalf
                        >(
                          currentTable: table,
                          referencedTable: $$CourtCategoriesTableReferences
                              ._onBehalfsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CourtCategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).onBehalfsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.courtCategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stepsRefs)
                        await $_getPrefetchedData<
                          CourtCategory,
                          $CourtCategoriesTable,
                          Step
                        >(
                          currentTable: table,
                          referencedTable: $$CourtCategoriesTableReferences
                              ._stepsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CourtCategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).stepsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.courtCategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (caseTypesRefs)
                        await $_getPrefetchedData<
                          CourtCategory,
                          $CourtCategoriesTable,
                          CaseType
                        >(
                          currentTable: table,
                          referencedTable: $$CourtCategoriesTableReferences
                              ._caseTypesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CourtCategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).caseTypesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.courtCategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CourtCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CourtCategoriesTable,
      CourtCategory,
      $$CourtCategoriesTableFilterComposer,
      $$CourtCategoriesTableOrderingComposer,
      $$CourtCategoriesTableAnnotationComposer,
      $$CourtCategoriesTableCreateCompanionBuilder,
      $$CourtCategoriesTableUpdateCompanionBuilder,
      (CourtCategory, $$CourtCategoriesTableReferences),
      CourtCategory,
      PrefetchHooks Function({
        bool courtsRefs,
        bool caseCategoriesRefs,
        bool onBehalfsRefs,
        bool stepsRefs,
        bool caseTypesRefs,
      })
    >;
typedef $$CourtsTableCreateCompanionBuilder =
    CourtsCompanion Function({
      required String id,
      required String courtName,
      required String higherLowerCourts,
      Value<String?> division,
      Value<String?> district,
      required String courtCategoryId,
      Value<int> orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$CourtsTableUpdateCompanionBuilder =
    CourtsCompanion Function({
      Value<String> id,
      Value<String> courtName,
      Value<String> higherLowerCourts,
      Value<String?> division,
      Value<String?> district,
      Value<String> courtCategoryId,
      Value<int> orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

final class $$CourtsTableReferences
    extends BaseReferences<_$AppDatabase, $CourtsTable, Court> {
  $$CourtsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CourtCategoriesTable _courtCategoryIdTable(_$AppDatabase db) => db
      .courtCategories
      .createAlias('courts__court_category_id__court_categories__id');

  $$CourtCategoriesTableProcessedTableManager get courtCategoryId {
    final $_column = $_itemColumn<String>('court_category_id')!;

    final manager = $$CourtCategoriesTableTableManager(
      $_db,
      $_db.courtCategories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courtCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CasesTable, List<Case>> _casesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cases,
    aliasName: 'courts__id__cases__court_id',
  );

  $$CasesTableProcessedTableManager get casesRefs {
    final manager = $$CasesTableTableManager(
      $_db,
      $_db.cases,
    ).filter((f) => f.courtId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_casesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CourtsTableFilterComposer
    extends Composer<_$AppDatabase, $CourtsTable> {
  $$CourtsTableFilterComposer({
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

  ColumnFilters<String> get courtName => $composableBuilder(
    column: $table.courtName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get higherLowerCourts => $composableBuilder(
    column: $table.higherLowerCourts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get division => $composableBuilder(
    column: $table.division,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );

  $$CourtCategoriesTableFilterComposer get courtCategoryId {
    final $$CourtCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> casesRefs(
    Expression<bool> Function($$CasesTableFilterComposer f) f,
  ) {
    final $$CasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cases,
      getReferencedColumn: (t) => t.courtId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CasesTableFilterComposer(
            $db: $db,
            $table: $db.cases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CourtsTableOrderingComposer
    extends Composer<_$AppDatabase, $CourtsTable> {
  $$CourtsTableOrderingComposer({
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

  ColumnOrderings<String> get courtName => $composableBuilder(
    column: $table.courtName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get higherLowerCourts => $composableBuilder(
    column: $table.higherLowerCourts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get division => $composableBuilder(
    column: $table.division,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );

  $$CourtCategoriesTableOrderingComposer get courtCategoryId {
    final $$CourtCategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CourtsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CourtsTable> {
  $$CourtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get courtName =>
      $composableBuilder(column: $table.courtName, builder: (column) => column);

  GeneratedColumn<String> get higherLowerCourts => $composableBuilder(
    column: $table.higherLowerCourts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get division =>
      $composableBuilder(column: $table.division, builder: (column) => column);

  GeneratedColumn<String> get district =>
      $composableBuilder(column: $table.district, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );

  $$CourtCategoriesTableAnnotationComposer get courtCategoryId {
    final $$CourtCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> casesRefs<T extends Object>(
    Expression<T> Function($$CasesTableAnnotationComposer a) f,
  ) {
    final $$CasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cases,
      getReferencedColumn: (t) => t.courtId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CasesTableAnnotationComposer(
            $db: $db,
            $table: $db.cases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CourtsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CourtsTable,
          Court,
          $$CourtsTableFilterComposer,
          $$CourtsTableOrderingComposer,
          $$CourtsTableAnnotationComposer,
          $$CourtsTableCreateCompanionBuilder,
          $$CourtsTableUpdateCompanionBuilder,
          (Court, $$CourtsTableReferences),
          Court,
          PrefetchHooks Function({bool courtCategoryId, bool casesRefs})
        > {
  $$CourtsTableTableManager(_$AppDatabase db, $CourtsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CourtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CourtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CourtsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> courtName = const Value.absent(),
                Value<String> higherLowerCourts = const Value.absent(),
                Value<String?> division = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<String> courtCategoryId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CourtsCompanion(
                id: id,
                courtName: courtName,
                higherLowerCourts: higherLowerCourts,
                division: division,
                district: district,
                courtCategoryId: courtCategoryId,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String courtName,
                required String higherLowerCourts,
                Value<String?> division = const Value.absent(),
                Value<String?> district = const Value.absent(),
                required String courtCategoryId,
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CourtsCompanion.insert(
                id: id,
                courtName: courtName,
                higherLowerCourts: higherLowerCourts,
                division: division,
                district: district,
                courtCategoryId: courtCategoryId,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CourtsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({courtCategoryId = false, casesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (casesRefs) db.cases],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (courtCategoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.courtCategoryId,
                                    referencedTable: $$CourtsTableReferences
                                        ._courtCategoryIdTable(db),
                                    referencedColumn: $$CourtsTableReferences
                                        ._courtCategoryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (casesRefs)
                        await $_getPrefetchedData<Court, $CourtsTable, Case>(
                          currentTable: table,
                          referencedTable: $$CourtsTableReferences
                              ._casesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CourtsTableReferences(db, table, p0).casesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.courtId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CourtsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CourtsTable,
      Court,
      $$CourtsTableFilterComposer,
      $$CourtsTableOrderingComposer,
      $$CourtsTableAnnotationComposer,
      $$CourtsTableCreateCompanionBuilder,
      $$CourtsTableUpdateCompanionBuilder,
      (Court, $$CourtsTableReferences),
      Court,
      PrefetchHooks Function({bool courtCategoryId, bool casesRefs})
    >;
typedef $$CaseCategoriesTableCreateCompanionBuilder =
    CaseCategoriesCompanion Function({
      required String id,
      required String courtCategoryId,
      required String name,
      required int orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$CaseCategoriesTableUpdateCompanionBuilder =
    CaseCategoriesCompanion Function({
      Value<String> id,
      Value<String> courtCategoryId,
      Value<String> name,
      Value<int> orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

final class $$CaseCategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CaseCategoriesTable, CaseCategory> {
  $$CaseCategoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CourtCategoriesTable _courtCategoryIdTable(_$AppDatabase db) => db
      .courtCategories
      .createAlias('case_categories__court_category_id__court_categories__id');

  $$CourtCategoriesTableProcessedTableManager get courtCategoryId {
    final $_column = $_itemColumn<String>('court_category_id')!;

    final manager = $$CourtCategoriesTableTableManager(
      $_db,
      $_db.courtCategories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courtCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CasesTable, List<Case>> _casesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cases,
    aliasName: 'case_categories__id__cases__case_category_id',
  );

  $$CasesTableProcessedTableManager get casesRefs {
    final manager = $$CasesTableTableManager(
      $_db,
      $_db.cases,
    ).filter((f) => f.caseCategoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_casesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CaseTypesTable, List<CaseType>>
  _caseTypesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.caseTypes,
    aliasName: 'case_categories__id__case_types__case_category_id',
  );

  $$CaseTypesTableProcessedTableManager get caseTypesRefs {
    final manager = $$CaseTypesTableTableManager(
      $_db,
      $_db.caseTypes,
    ).filter((f) => f.caseCategoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_caseTypesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CaseCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CaseCategoriesTable> {
  $$CaseCategoriesTableFilterComposer({
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

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );

  $$CourtCategoriesTableFilterComposer get courtCategoryId {
    final $$CourtCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> casesRefs(
    Expression<bool> Function($$CasesTableFilterComposer f) f,
  ) {
    final $$CasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cases,
      getReferencedColumn: (t) => t.caseCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CasesTableFilterComposer(
            $db: $db,
            $table: $db.cases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> caseTypesRefs(
    Expression<bool> Function($$CaseTypesTableFilterComposer f) f,
  ) {
    final $$CaseTypesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.caseTypes,
      getReferencedColumn: (t) => t.caseCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseTypesTableFilterComposer(
            $db: $db,
            $table: $db.caseTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CaseCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CaseCategoriesTable> {
  $$CaseCategoriesTableOrderingComposer({
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

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );

  $$CourtCategoriesTableOrderingComposer get courtCategoryId {
    final $$CourtCategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CaseCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CaseCategoriesTable> {
  $$CaseCategoriesTableAnnotationComposer({
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

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );

  $$CourtCategoriesTableAnnotationComposer get courtCategoryId {
    final $$CourtCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> casesRefs<T extends Object>(
    Expression<T> Function($$CasesTableAnnotationComposer a) f,
  ) {
    final $$CasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cases,
      getReferencedColumn: (t) => t.caseCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CasesTableAnnotationComposer(
            $db: $db,
            $table: $db.cases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> caseTypesRefs<T extends Object>(
    Expression<T> Function($$CaseTypesTableAnnotationComposer a) f,
  ) {
    final $$CaseTypesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.caseTypes,
      getReferencedColumn: (t) => t.caseCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseTypesTableAnnotationComposer(
            $db: $db,
            $table: $db.caseTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CaseCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CaseCategoriesTable,
          CaseCategory,
          $$CaseCategoriesTableFilterComposer,
          $$CaseCategoriesTableOrderingComposer,
          $$CaseCategoriesTableAnnotationComposer,
          $$CaseCategoriesTableCreateCompanionBuilder,
          $$CaseCategoriesTableUpdateCompanionBuilder,
          (CaseCategory, $$CaseCategoriesTableReferences),
          CaseCategory,
          PrefetchHooks Function({
            bool courtCategoryId,
            bool casesRefs,
            bool caseTypesRefs,
          })
        > {
  $$CaseCategoriesTableTableManager(
    _$AppDatabase db,
    $CaseCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaseCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaseCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaseCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> courtCategoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseCategoriesCompanion(
                id: id,
                courtCategoryId: courtCategoryId,
                name: name,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String courtCategoryId,
                required String name,
                required int orderIndex,
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseCategoriesCompanion.insert(
                id: id,
                courtCategoryId: courtCategoryId,
                name: name,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CaseCategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                courtCategoryId = false,
                casesRefs = false,
                caseTypesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (casesRefs) db.cases,
                    if (caseTypesRefs) db.caseTypes,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (courtCategoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.courtCategoryId,
                                    referencedTable:
                                        $$CaseCategoriesTableReferences
                                            ._courtCategoryIdTable(db),
                                    referencedColumn:
                                        $$CaseCategoriesTableReferences
                                            ._courtCategoryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (casesRefs)
                        await $_getPrefetchedData<
                          CaseCategory,
                          $CaseCategoriesTable,
                          Case
                        >(
                          currentTable: table,
                          referencedTable: $$CaseCategoriesTableReferences
                              ._casesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CaseCategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).casesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.caseCategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (caseTypesRefs)
                        await $_getPrefetchedData<
                          CaseCategory,
                          $CaseCategoriesTable,
                          CaseType
                        >(
                          currentTable: table,
                          referencedTable: $$CaseCategoriesTableReferences
                              ._caseTypesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CaseCategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).caseTypesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.caseCategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CaseCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CaseCategoriesTable,
      CaseCategory,
      $$CaseCategoriesTableFilterComposer,
      $$CaseCategoriesTableOrderingComposer,
      $$CaseCategoriesTableAnnotationComposer,
      $$CaseCategoriesTableCreateCompanionBuilder,
      $$CaseCategoriesTableUpdateCompanionBuilder,
      (CaseCategory, $$CaseCategoriesTableReferences),
      CaseCategory,
      PrefetchHooks Function({
        bool courtCategoryId,
        bool casesRefs,
        bool caseTypesRefs,
      })
    >;
typedef $$OnBehalfsTableCreateCompanionBuilder =
    OnBehalfsCompanion Function({
      required String id,
      required String courtCategoryId,
      required String name,
      required int orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$OnBehalfsTableUpdateCompanionBuilder =
    OnBehalfsCompanion Function({
      Value<String> id,
      Value<String> courtCategoryId,
      Value<String> name,
      Value<int> orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

final class $$OnBehalfsTableReferences
    extends BaseReferences<_$AppDatabase, $OnBehalfsTable, OnBehalf> {
  $$OnBehalfsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CourtCategoriesTable _courtCategoryIdTable(_$AppDatabase db) => db
      .courtCategories
      .createAlias('on_behalfs__court_category_id__court_categories__id');

  $$CourtCategoriesTableProcessedTableManager get courtCategoryId {
    final $_column = $_itemColumn<String>('court_category_id')!;

    final manager = $$CourtCategoriesTableTableManager(
      $_db,
      $_db.courtCategories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courtCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CasesTable, List<Case>> _casesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cases,
    aliasName: 'on_behalfs__id__cases__on_behalf_id',
  );

  $$CasesTableProcessedTableManager get casesRefs {
    final manager = $$CasesTableTableManager(
      $_db,
      $_db.cases,
    ).filter((f) => f.onBehalfId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_casesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$OnBehalfsTableFilterComposer
    extends Composer<_$AppDatabase, $OnBehalfsTable> {
  $$OnBehalfsTableFilterComposer({
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

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );

  $$CourtCategoriesTableFilterComposer get courtCategoryId {
    final $$CourtCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> casesRefs(
    Expression<bool> Function($$CasesTableFilterComposer f) f,
  ) {
    final $$CasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cases,
      getReferencedColumn: (t) => t.onBehalfId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CasesTableFilterComposer(
            $db: $db,
            $table: $db.cases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OnBehalfsTableOrderingComposer
    extends Composer<_$AppDatabase, $OnBehalfsTable> {
  $$OnBehalfsTableOrderingComposer({
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

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );

  $$CourtCategoriesTableOrderingComposer get courtCategoryId {
    final $$CourtCategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OnBehalfsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OnBehalfsTable> {
  $$OnBehalfsTableAnnotationComposer({
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

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );

  $$CourtCategoriesTableAnnotationComposer get courtCategoryId {
    final $$CourtCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> casesRefs<T extends Object>(
    Expression<T> Function($$CasesTableAnnotationComposer a) f,
  ) {
    final $$CasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cases,
      getReferencedColumn: (t) => t.onBehalfId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CasesTableAnnotationComposer(
            $db: $db,
            $table: $db.cases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OnBehalfsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OnBehalfsTable,
          OnBehalf,
          $$OnBehalfsTableFilterComposer,
          $$OnBehalfsTableOrderingComposer,
          $$OnBehalfsTableAnnotationComposer,
          $$OnBehalfsTableCreateCompanionBuilder,
          $$OnBehalfsTableUpdateCompanionBuilder,
          (OnBehalf, $$OnBehalfsTableReferences),
          OnBehalf,
          PrefetchHooks Function({bool courtCategoryId, bool casesRefs})
        > {
  $$OnBehalfsTableTableManager(_$AppDatabase db, $OnBehalfsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnBehalfsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OnBehalfsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OnBehalfsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> courtCategoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnBehalfsCompanion(
                id: id,
                courtCategoryId: courtCategoryId,
                name: name,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String courtCategoryId,
                required String name,
                required int orderIndex,
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnBehalfsCompanion.insert(
                id: id,
                courtCategoryId: courtCategoryId,
                name: name,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OnBehalfsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({courtCategoryId = false, casesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (casesRefs) db.cases],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (courtCategoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.courtCategoryId,
                                    referencedTable: $$OnBehalfsTableReferences
                                        ._courtCategoryIdTable(db),
                                    referencedColumn: $$OnBehalfsTableReferences
                                        ._courtCategoryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (casesRefs)
                        await $_getPrefetchedData<
                          OnBehalf,
                          $OnBehalfsTable,
                          Case
                        >(
                          currentTable: table,
                          referencedTable: $$OnBehalfsTableReferences
                              ._casesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$OnBehalfsTableReferences(
                                db,
                                table,
                                p0,
                              ).casesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.onBehalfId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$OnBehalfsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OnBehalfsTable,
      OnBehalf,
      $$OnBehalfsTableFilterComposer,
      $$OnBehalfsTableOrderingComposer,
      $$OnBehalfsTableAnnotationComposer,
      $$OnBehalfsTableCreateCompanionBuilder,
      $$OnBehalfsTableUpdateCompanionBuilder,
      (OnBehalf, $$OnBehalfsTableReferences),
      OnBehalf,
      PrefetchHooks Function({bool courtCategoryId, bool casesRefs})
    >;
typedef $$CasesTableCreateCompanionBuilder =
    CasesCompanion Function({
      required String id,
      required String userId,
      Value<String?> firmId,
      required String courtId,
      required String caseType,
      Value<String?> caseCategoryId,
      required String caseNumber,
      Value<String?> honorableJudges,
      Value<String?> tenderNumber,
      Value<String?> previousCourtCase,
      Value<String?> districtOfOrigin,
      required String petitioner,
      Value<String?> petitionerLeadCounsel,
      required String respondent,
      Value<String?> respondentLeadCounsel,
      required String onBehalfId,
      Value<String?> partyPhone,
      Value<String?> caseTitleAndSection,
      Value<String?> caseRemarks,
      Value<int?> nextDate,
      Value<String?> lastStep,
      Value<String?> notesResults,
      Value<String?> result,
      required int createdAt,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$CasesTableUpdateCompanionBuilder =
    CasesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String?> firmId,
      Value<String> courtId,
      Value<String> caseType,
      Value<String?> caseCategoryId,
      Value<String> caseNumber,
      Value<String?> honorableJudges,
      Value<String?> tenderNumber,
      Value<String?> previousCourtCase,
      Value<String?> districtOfOrigin,
      Value<String> petitioner,
      Value<String?> petitionerLeadCounsel,
      Value<String> respondent,
      Value<String?> respondentLeadCounsel,
      Value<String> onBehalfId,
      Value<String?> partyPhone,
      Value<String?> caseTitleAndSection,
      Value<String?> caseRemarks,
      Value<int?> nextDate,
      Value<String?> lastStep,
      Value<String?> notesResults,
      Value<String?> result,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

final class $$CasesTableReferences
    extends BaseReferences<_$AppDatabase, $CasesTable, Case> {
  $$CasesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CourtsTable _courtIdTable(_$AppDatabase db) =>
      db.courts.createAlias('cases__court_id__courts__id');

  $$CourtsTableProcessedTableManager get courtId {
    final $_column = $_itemColumn<String>('court_id')!;

    final manager = $$CourtsTableTableManager(
      $_db,
      $_db.courts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courtIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CaseCategoriesTable _caseCategoryIdTable(_$AppDatabase db) => db
      .caseCategories
      .createAlias('cases__case_category_id__case_categories__id');

  $$CaseCategoriesTableProcessedTableManager? get caseCategoryId {
    final $_column = $_itemColumn<String>('case_category_id');
    if ($_column == null) return null;
    final manager = $$CaseCategoriesTableTableManager(
      $_db,
      $_db.caseCategories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_caseCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $OnBehalfsTable _onBehalfIdTable(_$AppDatabase db) =>
      db.onBehalfs.createAlias('cases__on_behalf_id__on_behalfs__id');

  $$OnBehalfsTableProcessedTableManager get onBehalfId {
    final $_column = $_itemColumn<String>('on_behalf_id')!;

    final manager = $$OnBehalfsTableTableManager(
      $_db,
      $_db.onBehalfs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_onBehalfIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CaseHistoryTable, List<CaseHistoryRow>>
  _caseHistoryRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.caseHistory,
    aliasName: 'cases__id__case_history__case_id',
  );

  $$CaseHistoryTableProcessedTableManager get caseHistoryRefs {
    final manager = $$CaseHistoryTableTableManager(
      $_db,
      $_db.caseHistory,
    ).filter((f) => f.caseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_caseHistoryRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CasesTableFilterComposer extends Composer<_$AppDatabase, $CasesTable> {
  $$CasesTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseType => $composableBuilder(
    column: $table.caseType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseNumber => $composableBuilder(
    column: $table.caseNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get honorableJudges => $composableBuilder(
    column: $table.honorableJudges,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenderNumber => $composableBuilder(
    column: $table.tenderNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousCourtCase => $composableBuilder(
    column: $table.previousCourtCase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get districtOfOrigin => $composableBuilder(
    column: $table.districtOfOrigin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get petitioner => $composableBuilder(
    column: $table.petitioner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get petitionerLeadCounsel => $composableBuilder(
    column: $table.petitionerLeadCounsel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get respondent => $composableBuilder(
    column: $table.respondent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get respondentLeadCounsel => $composableBuilder(
    column: $table.respondentLeadCounsel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyPhone => $composableBuilder(
    column: $table.partyPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseTitleAndSection => $composableBuilder(
    column: $table.caseTitleAndSection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseRemarks => $composableBuilder(
    column: $table.caseRemarks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastStep => $composableBuilder(
    column: $table.lastStep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notesResults => $composableBuilder(
    column: $table.notesResults,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );

  $$CourtsTableFilterComposer get courtId {
    final $$CourtsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtId,
      referencedTable: $db.courts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtsTableFilterComposer(
            $db: $db,
            $table: $db.courts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaseCategoriesTableFilterComposer get caseCategoryId {
    final $$CaseCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseCategoryId,
      referencedTable: $db.caseCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.caseCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OnBehalfsTableFilterComposer get onBehalfId {
    final $$OnBehalfsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.onBehalfId,
      referencedTable: $db.onBehalfs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OnBehalfsTableFilterComposer(
            $db: $db,
            $table: $db.onBehalfs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> caseHistoryRefs(
    Expression<bool> Function($$CaseHistoryTableFilterComposer f) f,
  ) {
    final $$CaseHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.caseHistory,
      getReferencedColumn: (t) => t.caseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseHistoryTableFilterComposer(
            $db: $db,
            $table: $db.caseHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CasesTableOrderingComposer
    extends Composer<_$AppDatabase, $CasesTable> {
  $$CasesTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseType => $composableBuilder(
    column: $table.caseType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseNumber => $composableBuilder(
    column: $table.caseNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get honorableJudges => $composableBuilder(
    column: $table.honorableJudges,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenderNumber => $composableBuilder(
    column: $table.tenderNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousCourtCase => $composableBuilder(
    column: $table.previousCourtCase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get districtOfOrigin => $composableBuilder(
    column: $table.districtOfOrigin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get petitioner => $composableBuilder(
    column: $table.petitioner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get petitionerLeadCounsel => $composableBuilder(
    column: $table.petitionerLeadCounsel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get respondent => $composableBuilder(
    column: $table.respondent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get respondentLeadCounsel => $composableBuilder(
    column: $table.respondentLeadCounsel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyPhone => $composableBuilder(
    column: $table.partyPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseTitleAndSection => $composableBuilder(
    column: $table.caseTitleAndSection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseRemarks => $composableBuilder(
    column: $table.caseRemarks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastStep => $composableBuilder(
    column: $table.lastStep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notesResults => $composableBuilder(
    column: $table.notesResults,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );

  $$CourtsTableOrderingComposer get courtId {
    final $$CourtsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtId,
      referencedTable: $db.courts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtsTableOrderingComposer(
            $db: $db,
            $table: $db.courts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaseCategoriesTableOrderingComposer get caseCategoryId {
    final $$CaseCategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseCategoryId,
      referencedTable: $db.caseCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseCategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.caseCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OnBehalfsTableOrderingComposer get onBehalfId {
    final $$OnBehalfsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.onBehalfId,
      referencedTable: $db.onBehalfs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OnBehalfsTableOrderingComposer(
            $db: $db,
            $table: $db.onBehalfs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CasesTable> {
  $$CasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<String> get caseType =>
      $composableBuilder(column: $table.caseType, builder: (column) => column);

  GeneratedColumn<String> get caseNumber => $composableBuilder(
    column: $table.caseNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get honorableJudges => $composableBuilder(
    column: $table.honorableJudges,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenderNumber => $composableBuilder(
    column: $table.tenderNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previousCourtCase => $composableBuilder(
    column: $table.previousCourtCase,
    builder: (column) => column,
  );

  GeneratedColumn<String> get districtOfOrigin => $composableBuilder(
    column: $table.districtOfOrigin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get petitioner => $composableBuilder(
    column: $table.petitioner,
    builder: (column) => column,
  );

  GeneratedColumn<String> get petitionerLeadCounsel => $composableBuilder(
    column: $table.petitionerLeadCounsel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get respondent => $composableBuilder(
    column: $table.respondent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get respondentLeadCounsel => $composableBuilder(
    column: $table.respondentLeadCounsel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get partyPhone => $composableBuilder(
    column: $table.partyPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get caseTitleAndSection => $composableBuilder(
    column: $table.caseTitleAndSection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get caseRemarks => $composableBuilder(
    column: $table.caseRemarks,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextDate =>
      $composableBuilder(column: $table.nextDate, builder: (column) => column);

  GeneratedColumn<String> get lastStep =>
      $composableBuilder(column: $table.lastStep, builder: (column) => column);

  GeneratedColumn<String> get notesResults => $composableBuilder(
    column: $table.notesResults,
    builder: (column) => column,
  );

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );

  $$CourtsTableAnnotationComposer get courtId {
    final $$CourtsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtId,
      referencedTable: $db.courts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtsTableAnnotationComposer(
            $db: $db,
            $table: $db.courts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaseCategoriesTableAnnotationComposer get caseCategoryId {
    final $$CaseCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseCategoryId,
      referencedTable: $db.caseCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.caseCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OnBehalfsTableAnnotationComposer get onBehalfId {
    final $$OnBehalfsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.onBehalfId,
      referencedTable: $db.onBehalfs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OnBehalfsTableAnnotationComposer(
            $db: $db,
            $table: $db.onBehalfs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> caseHistoryRefs<T extends Object>(
    Expression<T> Function($$CaseHistoryTableAnnotationComposer a) f,
  ) {
    final $$CaseHistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.caseHistory,
      getReferencedColumn: (t) => t.caseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseHistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.caseHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CasesTable,
          Case,
          $$CasesTableFilterComposer,
          $$CasesTableOrderingComposer,
          $$CasesTableAnnotationComposer,
          $$CasesTableCreateCompanionBuilder,
          $$CasesTableUpdateCompanionBuilder,
          (Case, $$CasesTableReferences),
          Case,
          PrefetchHooks Function({
            bool courtId,
            bool caseCategoryId,
            bool onBehalfId,
            bool caseHistoryRefs,
          })
        > {
  $$CasesTableTableManager(_$AppDatabase db, $CasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<String> courtId = const Value.absent(),
                Value<String> caseType = const Value.absent(),
                Value<String?> caseCategoryId = const Value.absent(),
                Value<String> caseNumber = const Value.absent(),
                Value<String?> honorableJudges = const Value.absent(),
                Value<String?> tenderNumber = const Value.absent(),
                Value<String?> previousCourtCase = const Value.absent(),
                Value<String?> districtOfOrigin = const Value.absent(),
                Value<String> petitioner = const Value.absent(),
                Value<String?> petitionerLeadCounsel = const Value.absent(),
                Value<String> respondent = const Value.absent(),
                Value<String?> respondentLeadCounsel = const Value.absent(),
                Value<String> onBehalfId = const Value.absent(),
                Value<String?> partyPhone = const Value.absent(),
                Value<String?> caseTitleAndSection = const Value.absent(),
                Value<String?> caseRemarks = const Value.absent(),
                Value<int?> nextDate = const Value.absent(),
                Value<String?> lastStep = const Value.absent(),
                Value<String?> notesResults = const Value.absent(),
                Value<String?> result = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CasesCompanion(
                id: id,
                userId: userId,
                firmId: firmId,
                courtId: courtId,
                caseType: caseType,
                caseCategoryId: caseCategoryId,
                caseNumber: caseNumber,
                honorableJudges: honorableJudges,
                tenderNumber: tenderNumber,
                previousCourtCase: previousCourtCase,
                districtOfOrigin: districtOfOrigin,
                petitioner: petitioner,
                petitionerLeadCounsel: petitionerLeadCounsel,
                respondent: respondent,
                respondentLeadCounsel: respondentLeadCounsel,
                onBehalfId: onBehalfId,
                partyPhone: partyPhone,
                caseTitleAndSection: caseTitleAndSection,
                caseRemarks: caseRemarks,
                nextDate: nextDate,
                lastStep: lastStep,
                notesResults: notesResults,
                result: result,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String?> firmId = const Value.absent(),
                required String courtId,
                required String caseType,
                Value<String?> caseCategoryId = const Value.absent(),
                required String caseNumber,
                Value<String?> honorableJudges = const Value.absent(),
                Value<String?> tenderNumber = const Value.absent(),
                Value<String?> previousCourtCase = const Value.absent(),
                Value<String?> districtOfOrigin = const Value.absent(),
                required String petitioner,
                Value<String?> petitionerLeadCounsel = const Value.absent(),
                required String respondent,
                Value<String?> respondentLeadCounsel = const Value.absent(),
                required String onBehalfId,
                Value<String?> partyPhone = const Value.absent(),
                Value<String?> caseTitleAndSection = const Value.absent(),
                Value<String?> caseRemarks = const Value.absent(),
                Value<int?> nextDate = const Value.absent(),
                Value<String?> lastStep = const Value.absent(),
                Value<String?> notesResults = const Value.absent(),
                Value<String?> result = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CasesCompanion.insert(
                id: id,
                userId: userId,
                firmId: firmId,
                courtId: courtId,
                caseType: caseType,
                caseCategoryId: caseCategoryId,
                caseNumber: caseNumber,
                honorableJudges: honorableJudges,
                tenderNumber: tenderNumber,
                previousCourtCase: previousCourtCase,
                districtOfOrigin: districtOfOrigin,
                petitioner: petitioner,
                petitionerLeadCounsel: petitionerLeadCounsel,
                respondent: respondent,
                respondentLeadCounsel: respondentLeadCounsel,
                onBehalfId: onBehalfId,
                partyPhone: partyPhone,
                caseTitleAndSection: caseTitleAndSection,
                caseRemarks: caseRemarks,
                nextDate: nextDate,
                lastStep: lastStep,
                notesResults: notesResults,
                result: result,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CasesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                courtId = false,
                caseCategoryId = false,
                onBehalfId = false,
                caseHistoryRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (caseHistoryRefs) db.caseHistory,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (courtId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.courtId,
                                    referencedTable: $$CasesTableReferences
                                        ._courtIdTable(db),
                                    referencedColumn: $$CasesTableReferences
                                        ._courtIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (caseCategoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.caseCategoryId,
                                    referencedTable: $$CasesTableReferences
                                        ._caseCategoryIdTable(db),
                                    referencedColumn: $$CasesTableReferences
                                        ._caseCategoryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (onBehalfId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.onBehalfId,
                                    referencedTable: $$CasesTableReferences
                                        ._onBehalfIdTable(db),
                                    referencedColumn: $$CasesTableReferences
                                        ._onBehalfIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (caseHistoryRefs)
                        await $_getPrefetchedData<
                          Case,
                          $CasesTable,
                          CaseHistoryRow
                        >(
                          currentTable: table,
                          referencedTable: $$CasesTableReferences
                              ._caseHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CasesTableReferences(
                                db,
                                table,
                                p0,
                              ).caseHistoryRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.caseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CasesTable,
      Case,
      $$CasesTableFilterComposer,
      $$CasesTableOrderingComposer,
      $$CasesTableAnnotationComposer,
      $$CasesTableCreateCompanionBuilder,
      $$CasesTableUpdateCompanionBuilder,
      (Case, $$CasesTableReferences),
      Case,
      PrefetchHooks Function({
        bool courtId,
        bool caseCategoryId,
        bool onBehalfId,
        bool caseHistoryRefs,
      })
    >;
typedef $$CaseHistoryTableCreateCompanionBuilder =
    CaseHistoryCompanion Function({
      required String id,
      required String caseId,
      required String userId,
      Value<String?> firmId,
      required int hearingDate,
      Value<String?> lastStep,
      Value<int?> nextDate,
      Value<String?> noteResult,
      Value<String?> result,
      required String createdBy,
      required String sourceMutationId,
      required int baseCaseVersion,
      required int resultCaseVersion,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$CaseHistoryTableUpdateCompanionBuilder =
    CaseHistoryCompanion Function({
      Value<String> id,
      Value<String> caseId,
      Value<String> userId,
      Value<String?> firmId,
      Value<int> hearingDate,
      Value<String?> lastStep,
      Value<int?> nextDate,
      Value<String?> noteResult,
      Value<String?> result,
      Value<String> createdBy,
      Value<String> sourceMutationId,
      Value<int> baseCaseVersion,
      Value<int> resultCaseVersion,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

final class $$CaseHistoryTableReferences
    extends BaseReferences<_$AppDatabase, $CaseHistoryTable, CaseHistoryRow> {
  $$CaseHistoryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CasesTable _caseIdTable(_$AppDatabase db) =>
      db.cases.createAlias('case_history__case_id__cases__id');

  $$CasesTableProcessedTableManager get caseId {
    final $_column = $_itemColumn<String>('case_id')!;

    final manager = $$CasesTableTableManager(
      $_db,
      $_db.cases,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_caseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CaseHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $CaseHistoryTable> {
  $$CaseHistoryTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hearingDate => $composableBuilder(
    column: $table.hearingDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastStep => $composableBuilder(
    column: $table.lastStep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteResult => $composableBuilder(
    column: $table.noteResult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMutationId => $composableBuilder(
    column: $table.sourceMutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseCaseVersion => $composableBuilder(
    column: $table.baseCaseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resultCaseVersion => $composableBuilder(
    column: $table.resultCaseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );

  $$CasesTableFilterComposer get caseId {
    final $$CasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseId,
      referencedTable: $db.cases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CasesTableFilterComposer(
            $db: $db,
            $table: $db.cases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CaseHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $CaseHistoryTable> {
  $$CaseHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hearingDate => $composableBuilder(
    column: $table.hearingDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastStep => $composableBuilder(
    column: $table.lastStep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteResult => $composableBuilder(
    column: $table.noteResult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMutationId => $composableBuilder(
    column: $table.sourceMutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseCaseVersion => $composableBuilder(
    column: $table.baseCaseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resultCaseVersion => $composableBuilder(
    column: $table.resultCaseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );

  $$CasesTableOrderingComposer get caseId {
    final $$CasesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseId,
      referencedTable: $db.cases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CasesTableOrderingComposer(
            $db: $db,
            $table: $db.cases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CaseHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $CaseHistoryTable> {
  $$CaseHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<int> get hearingDate => $composableBuilder(
    column: $table.hearingDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastStep =>
      $composableBuilder(column: $table.lastStep, builder: (column) => column);

  GeneratedColumn<int> get nextDate =>
      $composableBuilder(column: $table.nextDate, builder: (column) => column);

  GeneratedColumn<String> get noteResult => $composableBuilder(
    column: $table.noteResult,
    builder: (column) => column,
  );

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get sourceMutationId => $composableBuilder(
    column: $table.sourceMutationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baseCaseVersion => $composableBuilder(
    column: $table.baseCaseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resultCaseVersion => $composableBuilder(
    column: $table.resultCaseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );

  $$CasesTableAnnotationComposer get caseId {
    final $$CasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseId,
      referencedTable: $db.cases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CasesTableAnnotationComposer(
            $db: $db,
            $table: $db.cases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CaseHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CaseHistoryTable,
          CaseHistoryRow,
          $$CaseHistoryTableFilterComposer,
          $$CaseHistoryTableOrderingComposer,
          $$CaseHistoryTableAnnotationComposer,
          $$CaseHistoryTableCreateCompanionBuilder,
          $$CaseHistoryTableUpdateCompanionBuilder,
          (CaseHistoryRow, $$CaseHistoryTableReferences),
          CaseHistoryRow,
          PrefetchHooks Function({bool caseId})
        > {
  $$CaseHistoryTableTableManager(_$AppDatabase db, $CaseHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaseHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaseHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaseHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> caseId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<int> hearingDate = const Value.absent(),
                Value<String?> lastStep = const Value.absent(),
                Value<int?> nextDate = const Value.absent(),
                Value<String?> noteResult = const Value.absent(),
                Value<String?> result = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String> sourceMutationId = const Value.absent(),
                Value<int> baseCaseVersion = const Value.absent(),
                Value<int> resultCaseVersion = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseHistoryCompanion(
                id: id,
                caseId: caseId,
                userId: userId,
                firmId: firmId,
                hearingDate: hearingDate,
                lastStep: lastStep,
                nextDate: nextDate,
                noteResult: noteResult,
                result: result,
                createdBy: createdBy,
                sourceMutationId: sourceMutationId,
                baseCaseVersion: baseCaseVersion,
                resultCaseVersion: resultCaseVersion,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String caseId,
                required String userId,
                Value<String?> firmId = const Value.absent(),
                required int hearingDate,
                Value<String?> lastStep = const Value.absent(),
                Value<int?> nextDate = const Value.absent(),
                Value<String?> noteResult = const Value.absent(),
                Value<String?> result = const Value.absent(),
                required String createdBy,
                required String sourceMutationId,
                required int baseCaseVersion,
                required int resultCaseVersion,
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseHistoryCompanion.insert(
                id: id,
                caseId: caseId,
                userId: userId,
                firmId: firmId,
                hearingDate: hearingDate,
                lastStep: lastStep,
                nextDate: nextDate,
                noteResult: noteResult,
                result: result,
                createdBy: createdBy,
                sourceMutationId: sourceMutationId,
                baseCaseVersion: baseCaseVersion,
                resultCaseVersion: resultCaseVersion,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CaseHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({caseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (caseId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.caseId,
                                referencedTable: $$CaseHistoryTableReferences
                                    ._caseIdTable(db),
                                referencedColumn: $$CaseHistoryTableReferences
                                    ._caseIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CaseHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CaseHistoryTable,
      CaseHistoryRow,
      $$CaseHistoryTableFilterComposer,
      $$CaseHistoryTableOrderingComposer,
      $$CaseHistoryTableAnnotationComposer,
      $$CaseHistoryTableCreateCompanionBuilder,
      $$CaseHistoryTableUpdateCompanionBuilder,
      (CaseHistoryRow, $$CaseHistoryTableReferences),
      CaseHistoryRow,
      PrefetchHooks Function({bool caseId})
    >;
typedef $$StepsTableCreateCompanionBuilder =
    StepsCompanion Function({
      required String id,
      required String courtCategoryId,
      required String stepName,
      required int orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$StepsTableUpdateCompanionBuilder =
    StepsCompanion Function({
      Value<String> id,
      Value<String> courtCategoryId,
      Value<String> stepName,
      Value<int> orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

final class $$StepsTableReferences
    extends BaseReferences<_$AppDatabase, $StepsTable, Step> {
  $$StepsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CourtCategoriesTable _courtCategoryIdTable(_$AppDatabase db) => db
      .courtCategories
      .createAlias('steps__court_category_id__court_categories__id');

  $$CourtCategoriesTableProcessedTableManager get courtCategoryId {
    final $_column = $_itemColumn<String>('court_category_id')!;

    final manager = $$CourtCategoriesTableTableManager(
      $_db,
      $_db.courtCategories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courtCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StepsTableFilterComposer extends Composer<_$AppDatabase, $StepsTable> {
  $$StepsTableFilterComposer({
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

  ColumnFilters<String> get stepName => $composableBuilder(
    column: $table.stepName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );

  $$CourtCategoriesTableFilterComposer get courtCategoryId {
    final $$CourtCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StepsTableOrderingComposer
    extends Composer<_$AppDatabase, $StepsTable> {
  $$StepsTableOrderingComposer({
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

  ColumnOrderings<String> get stepName => $composableBuilder(
    column: $table.stepName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );

  $$CourtCategoriesTableOrderingComposer get courtCategoryId {
    final $$CourtCategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StepsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StepsTable> {
  $$StepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get stepName =>
      $composableBuilder(column: $table.stepName, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );

  $$CourtCategoriesTableAnnotationComposer get courtCategoryId {
    final $$CourtCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StepsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StepsTable,
          Step,
          $$StepsTableFilterComposer,
          $$StepsTableOrderingComposer,
          $$StepsTableAnnotationComposer,
          $$StepsTableCreateCompanionBuilder,
          $$StepsTableUpdateCompanionBuilder,
          (Step, $$StepsTableReferences),
          Step,
          PrefetchHooks Function({bool courtCategoryId})
        > {
  $$StepsTableTableManager(_$AppDatabase db, $StepsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> courtCategoryId = const Value.absent(),
                Value<String> stepName = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StepsCompanion(
                id: id,
                courtCategoryId: courtCategoryId,
                stepName: stepName,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String courtCategoryId,
                required String stepName,
                required int orderIndex,
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StepsCompanion.insert(
                id: id,
                courtCategoryId: courtCategoryId,
                stepName: stepName,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$StepsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({courtCategoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (courtCategoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.courtCategoryId,
                                referencedTable: $$StepsTableReferences
                                    ._courtCategoryIdTable(db),
                                referencedColumn: $$StepsTableReferences
                                    ._courtCategoryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StepsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StepsTable,
      Step,
      $$StepsTableFilterComposer,
      $$StepsTableOrderingComposer,
      $$StepsTableAnnotationComposer,
      $$StepsTableCreateCompanionBuilder,
      $$StepsTableUpdateCompanionBuilder,
      (Step, $$StepsTableReferences),
      Step,
      PrefetchHooks Function({bool courtCategoryId})
    >;
typedef $$LawsTableCreateCompanionBuilder =
    LawsCompanion Function({
      required String id,
      required String name,
      Value<String> category,
      Value<int> orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$LawsTableUpdateCompanionBuilder =
    LawsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> category,
      Value<int> orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

class $$LawsTableFilterComposer extends Composer<_$AppDatabase, $LawsTable> {
  $$LawsTableFilterComposer({
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

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LawsTableOrderingComposer extends Composer<_$AppDatabase, $LawsTable> {
  $$LawsTableOrderingComposer({
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

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LawsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LawsTable> {
  $$LawsTableAnnotationComposer({
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

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );
}

class $$LawsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LawsTable,
          Law,
          $$LawsTableFilterComposer,
          $$LawsTableOrderingComposer,
          $$LawsTableAnnotationComposer,
          $$LawsTableCreateCompanionBuilder,
          $$LawsTableUpdateCompanionBuilder,
          (Law, BaseReferences<_$AppDatabase, $LawsTable, Law>),
          Law,
          PrefetchHooks Function()
        > {
  $$LawsTableTableManager(_$AppDatabase db, $LawsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LawsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LawsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LawsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LawsCompanion(
                id: id,
                name: name,
                category: category,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> category = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LawsCompanion.insert(
                id: id,
                name: name,
                category: category,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LawsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LawsTable,
      Law,
      $$LawsTableFilterComposer,
      $$LawsTableOrderingComposer,
      $$LawsTableAnnotationComposer,
      $$LawsTableCreateCompanionBuilder,
      $$LawsTableUpdateCompanionBuilder,
      (Law, BaseReferences<_$AppDatabase, $LawsTable, Law>),
      Law,
      PrefetchHooks Function()
    >;
typedef $$CaseTypesTableCreateCompanionBuilder =
    CaseTypesCompanion Function({
      required String id,
      required String courtCategoryId,
      Value<String?> caseCategoryId,
      required String name,
      required int orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$CaseTypesTableUpdateCompanionBuilder =
    CaseTypesCompanion Function({
      Value<String> id,
      Value<String> courtCategoryId,
      Value<String?> caseCategoryId,
      Value<String> name,
      Value<int> orderIndex,
      Value<bool> isCustom,
      Value<bool> isUserModified,
      Value<String?> userId,
      Value<String?> firmId,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

final class $$CaseTypesTableReferences
    extends BaseReferences<_$AppDatabase, $CaseTypesTable, CaseType> {
  $$CaseTypesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CourtCategoriesTable _courtCategoryIdTable(_$AppDatabase db) => db
      .courtCategories
      .createAlias('case_types__court_category_id__court_categories__id');

  $$CourtCategoriesTableProcessedTableManager get courtCategoryId {
    final $_column = $_itemColumn<String>('court_category_id')!;

    final manager = $$CourtCategoriesTableTableManager(
      $_db,
      $_db.courtCategories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courtCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CaseCategoriesTable _caseCategoryIdTable(_$AppDatabase db) => db
      .caseCategories
      .createAlias('case_types__case_category_id__case_categories__id');

  $$CaseCategoriesTableProcessedTableManager? get caseCategoryId {
    final $_column = $_itemColumn<String>('case_category_id');
    if ($_column == null) return null;
    final manager = $$CaseCategoriesTableTableManager(
      $_db,
      $_db.caseCategories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_caseCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CaseTypesTableFilterComposer
    extends Composer<_$AppDatabase, $CaseTypesTable> {
  $$CaseTypesTableFilterComposer({
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

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );

  $$CourtCategoriesTableFilterComposer get courtCategoryId {
    final $$CourtCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaseCategoriesTableFilterComposer get caseCategoryId {
    final $$CaseCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseCategoryId,
      referencedTable: $db.caseCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.caseCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CaseTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $CaseTypesTable> {
  $$CaseTypesTableOrderingComposer({
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

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );

  $$CourtCategoriesTableOrderingComposer get courtCategoryId {
    final $$CourtCategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaseCategoriesTableOrderingComposer get caseCategoryId {
    final $$CaseCategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseCategoryId,
      referencedTable: $db.caseCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseCategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.caseCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CaseTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CaseTypesTable> {
  $$CaseTypesTableAnnotationComposer({
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

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<bool> get isUserModified => $composableBuilder(
    column: $table.isUserModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );

  $$CourtCategoriesTableAnnotationComposer get courtCategoryId {
    final $$CourtCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courtCategoryId,
      referencedTable: $db.courtCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourtCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.courtCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaseCategoriesTableAnnotationComposer get caseCategoryId {
    final $$CaseCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseCategoryId,
      referencedTable: $db.caseCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaseCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.caseCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CaseTypesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CaseTypesTable,
          CaseType,
          $$CaseTypesTableFilterComposer,
          $$CaseTypesTableOrderingComposer,
          $$CaseTypesTableAnnotationComposer,
          $$CaseTypesTableCreateCompanionBuilder,
          $$CaseTypesTableUpdateCompanionBuilder,
          (CaseType, $$CaseTypesTableReferences),
          CaseType,
          PrefetchHooks Function({bool courtCategoryId, bool caseCategoryId})
        > {
  $$CaseTypesTableTableManager(_$AppDatabase db, $CaseTypesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaseTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaseTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaseTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> courtCategoryId = const Value.absent(),
                Value<String?> caseCategoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseTypesCompanion(
                id: id,
                courtCategoryId: courtCategoryId,
                caseCategoryId: caseCategoryId,
                name: name,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String courtCategoryId,
                Value<String?> caseCategoryId = const Value.absent(),
                required String name,
                required int orderIndex,
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isUserModified = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseTypesCompanion.insert(
                id: id,
                courtCategoryId: courtCategoryId,
                caseCategoryId: caseCategoryId,
                name: name,
                orderIndex: orderIndex,
                isCustom: isCustom,
                isUserModified: isUserModified,
                userId: userId,
                firmId: firmId,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CaseTypesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({courtCategoryId = false, caseCategoryId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (courtCategoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.courtCategoryId,
                                    referencedTable: $$CaseTypesTableReferences
                                        ._courtCategoryIdTable(db),
                                    referencedColumn: $$CaseTypesTableReferences
                                        ._courtCategoryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (caseCategoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.caseCategoryId,
                                    referencedTable: $$CaseTypesTableReferences
                                        ._caseCategoryIdTable(db),
                                    referencedColumn: $$CaseTypesTableReferences
                                        ._caseCategoryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$CaseTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CaseTypesTable,
      CaseType,
      $$CaseTypesTableFilterComposer,
      $$CaseTypesTableOrderingComposer,
      $$CaseTypesTableAnnotationComposer,
      $$CaseTypesTableCreateCompanionBuilder,
      $$CaseTypesTableUpdateCompanionBuilder,
      (CaseType, $$CaseTypesTableReferences),
      CaseType,
      PrefetchHooks Function({bool courtCategoryId, bool caseCategoryId})
    >;
typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      required String id,
      required String userId,
      Value<String?> firmId,
      required String title,
      required String body,
      Value<String?> items,
      Value<bool> isPinned,
      required int createdAt,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String?> firmId,
      Value<String> title,
      Value<String> body,
      Value<String?> items,
      Value<bool> isPinned,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get items =>
      $composableBuilder(column: $table.items, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> items = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                userId: userId,
                firmId: firmId,
                title: title,
                body: body,
                items: items,
                isPinned: isPinned,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String?> firmId = const Value.absent(),
                required String title,
                required String body,
                Value<String?> items = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                userId: userId,
                firmId: firmId,
                title: title,
                body: body,
                items: items,
                isPinned: isPinned,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$CaseReferencesTableCreateCompanionBuilder =
    CaseReferencesCompanion Function({
      required String id,
      required String userId,
      Value<String?> firmId,
      required String referenceAndPageNo,
      Value<String?> statute,
      Value<String?> sectionOrArticle,
      Value<String?> titleAndDescription,
      Value<String?> commentsNotes,
      Value<String?> caseNote,
      Value<String?> tags,
      Value<bool> isPinned,
      required int createdAt,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$CaseReferencesTableUpdateCompanionBuilder =
    CaseReferencesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String?> firmId,
      Value<String> referenceAndPageNo,
      Value<String?> statute,
      Value<String?> sectionOrArticle,
      Value<String?> titleAndDescription,
      Value<String?> commentsNotes,
      Value<String?> caseNote,
      Value<String?> tags,
      Value<bool> isPinned,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

class $$CaseReferencesTableFilterComposer
    extends Composer<_$AppDatabase, $CaseReferencesTable> {
  $$CaseReferencesTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceAndPageNo => $composableBuilder(
    column: $table.referenceAndPageNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statute => $composableBuilder(
    column: $table.statute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionOrArticle => $composableBuilder(
    column: $table.sectionOrArticle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleAndDescription => $composableBuilder(
    column: $table.titleAndDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commentsNotes => $composableBuilder(
    column: $table.commentsNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseNote => $composableBuilder(
    column: $table.caseNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CaseReferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $CaseReferencesTable> {
  $$CaseReferencesTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceAndPageNo => $composableBuilder(
    column: $table.referenceAndPageNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statute => $composableBuilder(
    column: $table.statute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionOrArticle => $composableBuilder(
    column: $table.sectionOrArticle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleAndDescription => $composableBuilder(
    column: $table.titleAndDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commentsNotes => $composableBuilder(
    column: $table.commentsNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseNote => $composableBuilder(
    column: $table.caseNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CaseReferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CaseReferencesTable> {
  $$CaseReferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<String> get referenceAndPageNo => $composableBuilder(
    column: $table.referenceAndPageNo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get statute =>
      $composableBuilder(column: $table.statute, builder: (column) => column);

  GeneratedColumn<String> get sectionOrArticle => $composableBuilder(
    column: $table.sectionOrArticle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleAndDescription => $composableBuilder(
    column: $table.titleAndDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commentsNotes => $composableBuilder(
    column: $table.commentsNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get caseNote =>
      $composableBuilder(column: $table.caseNote, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );
}

class $$CaseReferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CaseReferencesTable,
          CaseReference,
          $$CaseReferencesTableFilterComposer,
          $$CaseReferencesTableOrderingComposer,
          $$CaseReferencesTableAnnotationComposer,
          $$CaseReferencesTableCreateCompanionBuilder,
          $$CaseReferencesTableUpdateCompanionBuilder,
          (
            CaseReference,
            BaseReferences<_$AppDatabase, $CaseReferencesTable, CaseReference>,
          ),
          CaseReference,
          PrefetchHooks Function()
        > {
  $$CaseReferencesTableTableManager(
    _$AppDatabase db,
    $CaseReferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaseReferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaseReferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaseReferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<String> referenceAndPageNo = const Value.absent(),
                Value<String?> statute = const Value.absent(),
                Value<String?> sectionOrArticle = const Value.absent(),
                Value<String?> titleAndDescription = const Value.absent(),
                Value<String?> commentsNotes = const Value.absent(),
                Value<String?> caseNote = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseReferencesCompanion(
                id: id,
                userId: userId,
                firmId: firmId,
                referenceAndPageNo: referenceAndPageNo,
                statute: statute,
                sectionOrArticle: sectionOrArticle,
                titleAndDescription: titleAndDescription,
                commentsNotes: commentsNotes,
                caseNote: caseNote,
                tags: tags,
                isPinned: isPinned,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String?> firmId = const Value.absent(),
                required String referenceAndPageNo,
                Value<String?> statute = const Value.absent(),
                Value<String?> sectionOrArticle = const Value.absent(),
                Value<String?> titleAndDescription = const Value.absent(),
                Value<String?> commentsNotes = const Value.absent(),
                Value<String?> caseNote = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseReferencesCompanion.insert(
                id: id,
                userId: userId,
                firmId: firmId,
                referenceAndPageNo: referenceAndPageNo,
                statute: statute,
                sectionOrArticle: sectionOrArticle,
                titleAndDescription: titleAndDescription,
                commentsNotes: commentsNotes,
                caseNote: caseNote,
                tags: tags,
                isPinned: isPinned,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CaseReferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CaseReferencesTable,
      CaseReference,
      $$CaseReferencesTableFilterComposer,
      $$CaseReferencesTableOrderingComposer,
      $$CaseReferencesTableAnnotationComposer,
      $$CaseReferencesTableCreateCompanionBuilder,
      $$CaseReferencesTableUpdateCompanionBuilder,
      (
        CaseReference,
        BaseReferences<_$AppDatabase, $CaseReferencesTable, CaseReference>,
      ),
      CaseReference,
      PrefetchHooks Function()
    >;
typedef $$DeleteRequestsTableCreateCompanionBuilder =
    DeleteRequestsCompanion Function({
      required String id,
      Value<String?> firmId,
      required String entityType,
      required String entityId,
      required String entitySnapshot,
      required int targetBaseVersion,
      required String requestedBy,
      Value<String?> requesterName,
      required String status,
      Value<String?> reviewedBy,
      Value<String?> reviewNote,
      required int createdAt,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$DeleteRequestsTableUpdateCompanionBuilder =
    DeleteRequestsCompanion Function({
      Value<String> id,
      Value<String?> firmId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> entitySnapshot,
      Value<int> targetBaseVersion,
      Value<String> requestedBy,
      Value<String?> requesterName,
      Value<String> status,
      Value<String?> reviewedBy,
      Value<String?> reviewNote,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

class $$DeleteRequestsTableFilterComposer
    extends Composer<_$AppDatabase, $DeleteRequestsTable> {
  $$DeleteRequestsTableFilterComposer({
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

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entitySnapshot => $composableBuilder(
    column: $table.entitySnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetBaseVersion => $composableBuilder(
    column: $table.targetBaseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestedBy => $composableBuilder(
    column: $table.requestedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requesterName => $composableBuilder(
    column: $table.requesterName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewedBy => $composableBuilder(
    column: $table.reviewedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewNote => $composableBuilder(
    column: $table.reviewNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeleteRequestsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeleteRequestsTable> {
  $$DeleteRequestsTableOrderingComposer({
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

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entitySnapshot => $composableBuilder(
    column: $table.entitySnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetBaseVersion => $composableBuilder(
    column: $table.targetBaseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestedBy => $composableBuilder(
    column: $table.requestedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requesterName => $composableBuilder(
    column: $table.requesterName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewedBy => $composableBuilder(
    column: $table.reviewedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewNote => $composableBuilder(
    column: $table.reviewNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeleteRequestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeleteRequestsTable> {
  $$DeleteRequestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entitySnapshot => $composableBuilder(
    column: $table.entitySnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetBaseVersion => $composableBuilder(
    column: $table.targetBaseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get requestedBy => $composableBuilder(
    column: $table.requestedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get requesterName => $composableBuilder(
    column: $table.requesterName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get reviewedBy => $composableBuilder(
    column: $table.reviewedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewNote => $composableBuilder(
    column: $table.reviewNote,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );
}

class $$DeleteRequestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeleteRequestsTable,
          DeleteRequest,
          $$DeleteRequestsTableFilterComposer,
          $$DeleteRequestsTableOrderingComposer,
          $$DeleteRequestsTableAnnotationComposer,
          $$DeleteRequestsTableCreateCompanionBuilder,
          $$DeleteRequestsTableUpdateCompanionBuilder,
          (
            DeleteRequest,
            BaseReferences<_$AppDatabase, $DeleteRequestsTable, DeleteRequest>,
          ),
          DeleteRequest,
          PrefetchHooks Function()
        > {
  $$DeleteRequestsTableTableManager(
    _$AppDatabase db,
    $DeleteRequestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeleteRequestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeleteRequestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeleteRequestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> entitySnapshot = const Value.absent(),
                Value<int> targetBaseVersion = const Value.absent(),
                Value<String> requestedBy = const Value.absent(),
                Value<String?> requesterName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> reviewedBy = const Value.absent(),
                Value<String?> reviewNote = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeleteRequestsCompanion(
                id: id,
                firmId: firmId,
                entityType: entityType,
                entityId: entityId,
                entitySnapshot: entitySnapshot,
                targetBaseVersion: targetBaseVersion,
                requestedBy: requestedBy,
                requesterName: requesterName,
                status: status,
                reviewedBy: reviewedBy,
                reviewNote: reviewNote,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> firmId = const Value.absent(),
                required String entityType,
                required String entityId,
                required String entitySnapshot,
                required int targetBaseVersion,
                required String requestedBy,
                Value<String?> requesterName = const Value.absent(),
                required String status,
                Value<String?> reviewedBy = const Value.absent(),
                Value<String?> reviewNote = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeleteRequestsCompanion.insert(
                id: id,
                firmId: firmId,
                entityType: entityType,
                entityId: entityId,
                entitySnapshot: entitySnapshot,
                targetBaseVersion: targetBaseVersion,
                requestedBy: requestedBy,
                requesterName: requesterName,
                status: status,
                reviewedBy: reviewedBy,
                reviewNote: reviewNote,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeleteRequestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeleteRequestsTable,
      DeleteRequest,
      $$DeleteRequestsTableFilterComposer,
      $$DeleteRequestsTableOrderingComposer,
      $$DeleteRequestsTableAnnotationComposer,
      $$DeleteRequestsTableCreateCompanionBuilder,
      $$DeleteRequestsTableUpdateCompanionBuilder,
      (
        DeleteRequest,
        BaseReferences<_$AppDatabase, $DeleteRequestsTable, DeleteRequest>,
      ),
      DeleteRequest,
      PrefetchHooks Function()
    >;
typedef $$ConflictLogTableCreateCompanionBuilder =
    ConflictLogCompanion Function({
      required String id,
      required String mutationId,
      required String entityType,
      required String entityId,
      required int baseVersion,
      required String basePayload,
      required String submittedPayload,
      required String changedFields,
      required int serverVersion,
      required String serverPayload,
      required String resolutionState,
      required int conflictAt,
      Value<int?> resolvedAt,
      Value<bool> isDismissed,
      Value<bool> mergeableConflict,
      required int updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });
typedef $$ConflictLogTableUpdateCompanionBuilder =
    ConflictLogCompanion Function({
      Value<String> id,
      Value<String> mutationId,
      Value<String> entityType,
      Value<String> entityId,
      Value<int> baseVersion,
      Value<String> basePayload,
      Value<String> submittedPayload,
      Value<String> changedFields,
      Value<int> serverVersion,
      Value<String> serverPayload,
      Value<String> resolutionState,
      Value<int> conflictAt,
      Value<int?> resolvedAt,
      Value<bool> isDismissed,
      Value<bool> mergeableConflict,
      Value<int> updatedAt,
      Value<int?> version,
      Value<int?> syncedAt,
      Value<bool> isDeleted,
      Value<String?> lastModifiedBy,
      Value<int> rowid,
    });

class $$ConflictLogTableFilterComposer
    extends Composer<_$AppDatabase, $ConflictLogTable> {
  $$ConflictLogTableFilterComposer({
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

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basePayload => $composableBuilder(
    column: $table.basePayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get submittedPayload => $composableBuilder(
    column: $table.submittedPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changedFields => $composableBuilder(
    column: $table.changedFields,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverPayload => $composableBuilder(
    column: $table.serverPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolutionState => $composableBuilder(
    column: $table.resolutionState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get conflictAt => $composableBuilder(
    column: $table.conflictAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDismissed => $composableBuilder(
    column: $table.isDismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get mergeableConflict => $composableBuilder(
    column: $table.mergeableConflict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConflictLogTableOrderingComposer
    extends Composer<_$AppDatabase, $ConflictLogTable> {
  $$ConflictLogTableOrderingComposer({
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

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basePayload => $composableBuilder(
    column: $table.basePayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get submittedPayload => $composableBuilder(
    column: $table.submittedPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changedFields => $composableBuilder(
    column: $table.changedFields,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverPayload => $composableBuilder(
    column: $table.serverPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolutionState => $composableBuilder(
    column: $table.resolutionState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get conflictAt => $composableBuilder(
    column: $table.conflictAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDismissed => $composableBuilder(
    column: $table.isDismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get mergeableConflict => $composableBuilder(
    column: $table.mergeableConflict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConflictLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConflictLogTable> {
  $$ConflictLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get basePayload => $composableBuilder(
    column: $table.basePayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get submittedPayload => $composableBuilder(
    column: $table.submittedPayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get changedFields => $composableBuilder(
    column: $table.changedFields,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverPayload => $composableBuilder(
    column: $table.serverPayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolutionState => $composableBuilder(
    column: $table.resolutionState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get conflictAt => $composableBuilder(
    column: $table.conflictAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDismissed => $composableBuilder(
    column: $table.isDismissed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get mergeableConflict => $composableBuilder(
    column: $table.mergeableConflict,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
    column: $table.lastModifiedBy,
    builder: (column) => column,
  );
}

class $$ConflictLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConflictLogTable,
          ConflictLogRow,
          $$ConflictLogTableFilterComposer,
          $$ConflictLogTableOrderingComposer,
          $$ConflictLogTableAnnotationComposer,
          $$ConflictLogTableCreateCompanionBuilder,
          $$ConflictLogTableUpdateCompanionBuilder,
          (
            ConflictLogRow,
            BaseReferences<_$AppDatabase, $ConflictLogTable, ConflictLogRow>,
          ),
          ConflictLogRow,
          PrefetchHooks Function()
        > {
  $$ConflictLogTableTableManager(_$AppDatabase db, $ConflictLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConflictLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConflictLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConflictLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> baseVersion = const Value.absent(),
                Value<String> basePayload = const Value.absent(),
                Value<String> submittedPayload = const Value.absent(),
                Value<String> changedFields = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> serverPayload = const Value.absent(),
                Value<String> resolutionState = const Value.absent(),
                Value<int> conflictAt = const Value.absent(),
                Value<int?> resolvedAt = const Value.absent(),
                Value<bool> isDismissed = const Value.absent(),
                Value<bool> mergeableConflict = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConflictLogCompanion(
                id: id,
                mutationId: mutationId,
                entityType: entityType,
                entityId: entityId,
                baseVersion: baseVersion,
                basePayload: basePayload,
                submittedPayload: submittedPayload,
                changedFields: changedFields,
                serverVersion: serverVersion,
                serverPayload: serverPayload,
                resolutionState: resolutionState,
                conflictAt: conflictAt,
                resolvedAt: resolvedAt,
                isDismissed: isDismissed,
                mergeableConflict: mergeableConflict,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String mutationId,
                required String entityType,
                required String entityId,
                required int baseVersion,
                required String basePayload,
                required String submittedPayload,
                required String changedFields,
                required int serverVersion,
                required String serverPayload,
                required String resolutionState,
                required int conflictAt,
                Value<int?> resolvedAt = const Value.absent(),
                Value<bool> isDismissed = const Value.absent(),
                Value<bool> mergeableConflict = const Value.absent(),
                required int updatedAt,
                Value<int?> version = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> lastModifiedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConflictLogCompanion.insert(
                id: id,
                mutationId: mutationId,
                entityType: entityType,
                entityId: entityId,
                baseVersion: baseVersion,
                basePayload: basePayload,
                submittedPayload: submittedPayload,
                changedFields: changedFields,
                serverVersion: serverVersion,
                serverPayload: serverPayload,
                resolutionState: resolutionState,
                conflictAt: conflictAt,
                resolvedAt: resolvedAt,
                isDismissed: isDismissed,
                mergeableConflict: mergeableConflict,
                updatedAt: updatedAt,
                version: version,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                lastModifiedBy: lastModifiedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConflictLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConflictLogTable,
      ConflictLogRow,
      $$ConflictLogTableFilterComposer,
      $$ConflictLogTableOrderingComposer,
      $$ConflictLogTableAnnotationComposer,
      $$ConflictLogTableCreateCompanionBuilder,
      $$ConflictLogTableUpdateCompanionBuilder,
      (
        ConflictLogRow,
        BaseReferences<_$AppDatabase, $ConflictLogTable, ConflictLogRow>,
      ),
      ConflictLogRow,
      PrefetchHooks Function()
    >;
typedef $$FirmsTableCreateCompanionBuilder =
    FirmsCompanion Function({
      required String id,
      required String name,
      Value<String?> logoPath,
      Value<int> logoVersion,
      required String ownerId,
      required String subscriptionStatus,
      Value<int?> subscriptionExpiry,
      Value<String> tier,
      Value<String?> tierPending,
      Value<int?> tierPendingFrom,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$FirmsTableUpdateCompanionBuilder =
    FirmsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> logoPath,
      Value<int> logoVersion,
      Value<String> ownerId,
      Value<String> subscriptionStatus,
      Value<int?> subscriptionExpiry,
      Value<String> tier,
      Value<String?> tierPending,
      Value<int?> tierPendingFrom,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$FirmsTableFilterComposer extends Composer<_$AppDatabase, $FirmsTable> {
  $$FirmsTableFilterComposer({
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

  ColumnFilters<String> get logoPath => $composableBuilder(
    column: $table.logoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get logoVersion => $composableBuilder(
    column: $table.logoVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subscriptionStatus => $composableBuilder(
    column: $table.subscriptionStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subscriptionExpiry => $composableBuilder(
    column: $table.subscriptionExpiry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tierPending => $composableBuilder(
    column: $table.tierPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tierPendingFrom => $composableBuilder(
    column: $table.tierPendingFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FirmsTableOrderingComposer
    extends Composer<_$AppDatabase, $FirmsTable> {
  $$FirmsTableOrderingComposer({
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

  ColumnOrderings<String> get logoPath => $composableBuilder(
    column: $table.logoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get logoVersion => $composableBuilder(
    column: $table.logoVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subscriptionStatus => $composableBuilder(
    column: $table.subscriptionStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subscriptionExpiry => $composableBuilder(
    column: $table.subscriptionExpiry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tierPending => $composableBuilder(
    column: $table.tierPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tierPendingFrom => $composableBuilder(
    column: $table.tierPendingFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FirmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FirmsTable> {
  $$FirmsTableAnnotationComposer({
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

  GeneratedColumn<String> get logoPath =>
      $composableBuilder(column: $table.logoPath, builder: (column) => column);

  GeneratedColumn<int> get logoVersion => $composableBuilder(
    column: $table.logoVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get subscriptionStatus => $composableBuilder(
    column: $table.subscriptionStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subscriptionExpiry => $composableBuilder(
    column: $table.subscriptionExpiry,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get tierPending => $composableBuilder(
    column: $table.tierPending,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tierPendingFrom => $composableBuilder(
    column: $table.tierPendingFrom,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FirmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FirmsTable,
          Firm,
          $$FirmsTableFilterComposer,
          $$FirmsTableOrderingComposer,
          $$FirmsTableAnnotationComposer,
          $$FirmsTableCreateCompanionBuilder,
          $$FirmsTableUpdateCompanionBuilder,
          (Firm, BaseReferences<_$AppDatabase, $FirmsTable, Firm>),
          Firm,
          PrefetchHooks Function()
        > {
  $$FirmsTableTableManager(_$AppDatabase db, $FirmsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FirmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FirmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FirmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> logoPath = const Value.absent(),
                Value<int> logoVersion = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> subscriptionStatus = const Value.absent(),
                Value<int?> subscriptionExpiry = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String?> tierPending = const Value.absent(),
                Value<int?> tierPendingFrom = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FirmsCompanion(
                id: id,
                name: name,
                logoPath: logoPath,
                logoVersion: logoVersion,
                ownerId: ownerId,
                subscriptionStatus: subscriptionStatus,
                subscriptionExpiry: subscriptionExpiry,
                tier: tier,
                tierPending: tierPending,
                tierPendingFrom: tierPendingFrom,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> logoPath = const Value.absent(),
                Value<int> logoVersion = const Value.absent(),
                required String ownerId,
                required String subscriptionStatus,
                Value<int?> subscriptionExpiry = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String?> tierPending = const Value.absent(),
                Value<int?> tierPendingFrom = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FirmsCompanion.insert(
                id: id,
                name: name,
                logoPath: logoPath,
                logoVersion: logoVersion,
                ownerId: ownerId,
                subscriptionStatus: subscriptionStatus,
                subscriptionExpiry: subscriptionExpiry,
                tier: tier,
                tierPending: tierPending,
                tierPendingFrom: tierPendingFrom,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FirmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FirmsTable,
      Firm,
      $$FirmsTableFilterComposer,
      $$FirmsTableOrderingComposer,
      $$FirmsTableAnnotationComposer,
      $$FirmsTableCreateCompanionBuilder,
      $$FirmsTableUpdateCompanionBuilder,
      (Firm, BaseReferences<_$AppDatabase, $FirmsTable, Firm>),
      Firm,
      PrefetchHooks Function()
    >;
typedef $$FirmMembersTableCreateCompanionBuilder =
    FirmMembersCompanion Function({
      required String id,
      required String firmId,
      required String userId,
      required String role,
      Value<bool> canAdd,
      Value<bool> canEdit,
      Value<bool> canDelete,
      Value<int?> syncedAt,
      Value<int?> permissionsSyncedAt,
      Value<int> rowid,
    });
typedef $$FirmMembersTableUpdateCompanionBuilder =
    FirmMembersCompanion Function({
      Value<String> id,
      Value<String> firmId,
      Value<String> userId,
      Value<String> role,
      Value<bool> canAdd,
      Value<bool> canEdit,
      Value<bool> canDelete,
      Value<int?> syncedAt,
      Value<int?> permissionsSyncedAt,
      Value<int> rowid,
    });

class $$FirmMembersTableFilterComposer
    extends Composer<_$AppDatabase, $FirmMembersTable> {
  $$FirmMembersTableFilterComposer({
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

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get canAdd => $composableBuilder(
    column: $table.canAdd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get canEdit => $composableBuilder(
    column: $table.canEdit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get canDelete => $composableBuilder(
    column: $table.canDelete,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get permissionsSyncedAt => $composableBuilder(
    column: $table.permissionsSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FirmMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $FirmMembersTable> {
  $$FirmMembersTableOrderingComposer({
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

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get canAdd => $composableBuilder(
    column: $table.canAdd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get canEdit => $composableBuilder(
    column: $table.canEdit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get canDelete => $composableBuilder(
    column: $table.canDelete,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get permissionsSyncedAt => $composableBuilder(
    column: $table.permissionsSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FirmMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FirmMembersTable> {
  $$FirmMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get canAdd =>
      $composableBuilder(column: $table.canAdd, builder: (column) => column);

  GeneratedColumn<bool> get canEdit =>
      $composableBuilder(column: $table.canEdit, builder: (column) => column);

  GeneratedColumn<bool> get canDelete =>
      $composableBuilder(column: $table.canDelete, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<int> get permissionsSyncedAt => $composableBuilder(
    column: $table.permissionsSyncedAt,
    builder: (column) => column,
  );
}

class $$FirmMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FirmMembersTable,
          FirmMember,
          $$FirmMembersTableFilterComposer,
          $$FirmMembersTableOrderingComposer,
          $$FirmMembersTableAnnotationComposer,
          $$FirmMembersTableCreateCompanionBuilder,
          $$FirmMembersTableUpdateCompanionBuilder,
          (
            FirmMember,
            BaseReferences<_$AppDatabase, $FirmMembersTable, FirmMember>,
          ),
          FirmMember,
          PrefetchHooks Function()
        > {
  $$FirmMembersTableTableManager(_$AppDatabase db, $FirmMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FirmMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FirmMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FirmMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> firmId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<bool> canAdd = const Value.absent(),
                Value<bool> canEdit = const Value.absent(),
                Value<bool> canDelete = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<int?> permissionsSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FirmMembersCompanion(
                id: id,
                firmId: firmId,
                userId: userId,
                role: role,
                canAdd: canAdd,
                canEdit: canEdit,
                canDelete: canDelete,
                syncedAt: syncedAt,
                permissionsSyncedAt: permissionsSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String firmId,
                required String userId,
                required String role,
                Value<bool> canAdd = const Value.absent(),
                Value<bool> canEdit = const Value.absent(),
                Value<bool> canDelete = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
                Value<int?> permissionsSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FirmMembersCompanion.insert(
                id: id,
                firmId: firmId,
                userId: userId,
                role: role,
                canAdd: canAdd,
                canEdit: canEdit,
                canDelete: canDelete,
                syncedAt: syncedAt,
                permissionsSyncedAt: permissionsSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FirmMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FirmMembersTable,
      FirmMember,
      $$FirmMembersTableFilterComposer,
      $$FirmMembersTableOrderingComposer,
      $$FirmMembersTableAnnotationComposer,
      $$FirmMembersTableCreateCompanionBuilder,
      $$FirmMembersTableUpdateCompanionBuilder,
      (
        FirmMember,
        BaseReferences<_$AppDatabase, $FirmMembersTable, FirmMember>,
      ),
      FirmMember,
      PrefetchHooks Function()
    >;
typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      required String id,
      required String fullName,
      Value<String?> avatarPath,
      Value<int> avatarVersion,
      Value<String?> firmId,
      required String role,
      required String subscriptionStatus,
      Value<int?> subscriptionExpiry,
      Value<String> tier,
      Value<String?> tierPending,
      Value<int?> tierPendingFrom,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<String> id,
      Value<String> fullName,
      Value<String?> avatarPath,
      Value<int> avatarVersion,
      Value<String?> firmId,
      Value<String> role,
      Value<String> subscriptionStatus,
      Value<int?> subscriptionExpiry,
      Value<String> tier,
      Value<String?> tierPending,
      Value<int?> tierPendingFrom,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
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

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avatarVersion => $composableBuilder(
    column: $table.avatarVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subscriptionStatus => $composableBuilder(
    column: $table.subscriptionStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subscriptionExpiry => $composableBuilder(
    column: $table.subscriptionExpiry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tierPending => $composableBuilder(
    column: $table.tierPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tierPendingFrom => $composableBuilder(
    column: $table.tierPendingFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avatarVersion => $composableBuilder(
    column: $table.avatarVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmId => $composableBuilder(
    column: $table.firmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subscriptionStatus => $composableBuilder(
    column: $table.subscriptionStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subscriptionExpiry => $composableBuilder(
    column: $table.subscriptionExpiry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tierPending => $composableBuilder(
    column: $table.tierPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tierPendingFrom => $composableBuilder(
    column: $table.tierPendingFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get avatarVersion => $composableBuilder(
    column: $table.avatarVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firmId =>
      $composableBuilder(column: $table.firmId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get subscriptionStatus => $composableBuilder(
    column: $table.subscriptionStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subscriptionExpiry => $composableBuilder(
    column: $table.subscriptionExpiry,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get tierPending => $composableBuilder(
    column: $table.tierPending,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tierPendingFrom => $composableBuilder(
    column: $table.tierPendingFrom,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          Profile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
          Profile,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<int> avatarVersion = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> subscriptionStatus = const Value.absent(),
                Value<int?> subscriptionExpiry = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String?> tierPending = const Value.absent(),
                Value<int?> tierPendingFrom = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                fullName: fullName,
                avatarPath: avatarPath,
                avatarVersion: avatarVersion,
                firmId: firmId,
                role: role,
                subscriptionStatus: subscriptionStatus,
                subscriptionExpiry: subscriptionExpiry,
                tier: tier,
                tierPending: tierPending,
                tierPendingFrom: tierPendingFrom,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fullName,
                Value<String?> avatarPath = const Value.absent(),
                Value<int> avatarVersion = const Value.absent(),
                Value<String?> firmId = const Value.absent(),
                required String role,
                required String subscriptionStatus,
                Value<int?> subscriptionExpiry = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String?> tierPending = const Value.absent(),
                Value<int?> tierPendingFrom = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                fullName: fullName,
                avatarPath: avatarPath,
                avatarVersion: avatarVersion,
                firmId: firmId,
                role: role,
                subscriptionStatus: subscriptionStatus,
                subscriptionExpiry: subscriptionExpiry,
                tier: tier,
                tierPending: tierPending,
                tierPendingFrom: tierPendingFrom,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      Profile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
      Profile,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String entityType,
      required String entityId,
      required String operation,
      required String mutationId,
      Value<int?> baseVersion,
      required String basePayload,
      required String changedFields,
      required String payload,
      required String preMutationPayload,
      required int createdAt,
      Value<int> retryCount,
      Value<int?> lastAttemptAt,
      required String state,
      Value<String?> lastError,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operation,
      Value<String> mutationId,
      Value<int?> baseVersion,
      Value<String> basePayload,
      Value<String> changedFields,
      Value<String> payload,
      Value<String> preMutationPayload,
      Value<int> createdAt,
      Value<int> retryCount,
      Value<int?> lastAttemptAt,
      Value<String> state,
      Value<String?> lastError,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basePayload => $composableBuilder(
    column: $table.basePayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changedFields => $composableBuilder(
    column: $table.changedFields,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preMutationPayload => $composableBuilder(
    column: $table.preMutationPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basePayload => $composableBuilder(
    column: $table.basePayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changedFields => $composableBuilder(
    column: $table.changedFields,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preMutationPayload => $composableBuilder(
    column: $table.preMutationPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get basePayload => $composableBuilder(
    column: $table.basePayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get changedFields => $composableBuilder(
    column: $table.changedFields,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get preMutationPayload => $composableBuilder(
    column: $table.preMutationPayload,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueRow,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueRow,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueRow>,
          ),
          SyncQueueRow,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> basePayload = const Value.absent(),
                Value<String> changedFields = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> preMutationPayload = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int?> lastAttemptAt = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                mutationId: mutationId,
                baseVersion: baseVersion,
                basePayload: basePayload,
                changedFields: changedFields,
                payload: payload,
                preMutationPayload: preMutationPayload,
                createdAt: createdAt,
                retryCount: retryCount,
                lastAttemptAt: lastAttemptAt,
                state: state,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityType,
                required String entityId,
                required String operation,
                required String mutationId,
                Value<int?> baseVersion = const Value.absent(),
                required String basePayload,
                required String changedFields,
                required String payload,
                required String preMutationPayload,
                required int createdAt,
                Value<int> retryCount = const Value.absent(),
                Value<int?> lastAttemptAt = const Value.absent(),
                required String state,
                Value<String?> lastError = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                mutationId: mutationId,
                baseVersion: baseVersion,
                basePayload: basePayload,
                changedFields: changedFields,
                payload: payload,
                preMutationPayload: preMutationPayload,
                createdAt: createdAt,
                retryCount: retryCount,
                lastAttemptAt: lastAttemptAt,
                state: state,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueRow,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueRow,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueRow>,
      ),
      SyncQueueRow,
      PrefetchHooks Function()
    >;
typedef $$SyncMetadataTableCreateCompanionBuilder =
    SyncMetadataCompanion Function({
      required String key,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SyncMetadataTableUpdateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SyncMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
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

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
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

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
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

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetadataTable,
          SyncMetadataRow,
          $$SyncMetadataTableFilterComposer,
          $$SyncMetadataTableOrderingComposer,
          $$SyncMetadataTableAnnotationComposer,
          $$SyncMetadataTableCreateCompanionBuilder,
          $$SyncMetadataTableUpdateCompanionBuilder,
          (
            SyncMetadataRow,
            BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataRow>,
          ),
          SyncMetadataRow,
          PrefetchHooks Function()
        > {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                key: key,
                value: value,
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

typedef $$SyncMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetadataTable,
      SyncMetadataRow,
      $$SyncMetadataTableFilterComposer,
      $$SyncMetadataTableOrderingComposer,
      $$SyncMetadataTableAnnotationComposer,
      $$SyncMetadataTableCreateCompanionBuilder,
      $$SyncMetadataTableUpdateCompanionBuilder,
      (
        SyncMetadataRow,
        BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataRow>,
      ),
      SyncMetadataRow,
      PrefetchHooks Function()
    >;
typedef $$SeedMigrationsTableCreateCompanionBuilder =
    SeedMigrationsCompanion Function({
      required String migrationId,
      required String checksum,
      required int appliedAt,
      Value<int> rowid,
    });
typedef $$SeedMigrationsTableUpdateCompanionBuilder =
    SeedMigrationsCompanion Function({
      Value<String> migrationId,
      Value<String> checksum,
      Value<int> appliedAt,
      Value<int> rowid,
    });

class $$SeedMigrationsTableFilterComposer
    extends Composer<_$AppDatabase, $SeedMigrationsTable> {
  $$SeedMigrationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get migrationId => $composableBuilder(
    column: $table.migrationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeedMigrationsTableOrderingComposer
    extends Composer<_$AppDatabase, $SeedMigrationsTable> {
  $$SeedMigrationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get migrationId => $composableBuilder(
    column: $table.migrationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeedMigrationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeedMigrationsTable> {
  $$SeedMigrationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get migrationId => $composableBuilder(
    column: $table.migrationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<int> get appliedAt =>
      $composableBuilder(column: $table.appliedAt, builder: (column) => column);
}

class $$SeedMigrationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeedMigrationsTable,
          SeedMigration,
          $$SeedMigrationsTableFilterComposer,
          $$SeedMigrationsTableOrderingComposer,
          $$SeedMigrationsTableAnnotationComposer,
          $$SeedMigrationsTableCreateCompanionBuilder,
          $$SeedMigrationsTableUpdateCompanionBuilder,
          (
            SeedMigration,
            BaseReferences<_$AppDatabase, $SeedMigrationsTable, SeedMigration>,
          ),
          SeedMigration,
          PrefetchHooks Function()
        > {
  $$SeedMigrationsTableTableManager(
    _$AppDatabase db,
    $SeedMigrationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeedMigrationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeedMigrationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeedMigrationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> migrationId = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<int> appliedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeedMigrationsCompanion(
                migrationId: migrationId,
                checksum: checksum,
                appliedAt: appliedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String migrationId,
                required String checksum,
                required int appliedAt,
                Value<int> rowid = const Value.absent(),
              }) => SeedMigrationsCompanion.insert(
                migrationId: migrationId,
                checksum: checksum,
                appliedAt: appliedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeedMigrationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeedMigrationsTable,
      SeedMigration,
      $$SeedMigrationsTableFilterComposer,
      $$SeedMigrationsTableOrderingComposer,
      $$SeedMigrationsTableAnnotationComposer,
      $$SeedMigrationsTableCreateCompanionBuilder,
      $$SeedMigrationsTableUpdateCompanionBuilder,
      (
        SeedMigration,
        BaseReferences<_$AppDatabase, $SeedMigrationsTable, SeedMigration>,
      ),
      SeedMigration,
      PrefetchHooks Function()
    >;
typedef $$UserPreferencesTableCreateCompanionBuilder =
    UserPreferencesCompanion Function({
      required String userId,
      Value<String?> language,
      Value<String?> theme,
      Value<String?> viewSettingsJson,
      Value<bool> notificationEnabled,
      Value<int?> notificationTime,
      Value<String?> notificationDefaultOffsets,
      Value<bool> paymentAlertsEnabled,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$UserPreferencesTableUpdateCompanionBuilder =
    UserPreferencesCompanion Function({
      Value<String> userId,
      Value<String?> language,
      Value<String?> theme,
      Value<String?> viewSettingsJson,
      Value<bool> notificationEnabled,
      Value<int?> notificationTime,
      Value<String?> notificationDefaultOffsets,
      Value<bool> paymentAlertsEnabled,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$UserPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viewSettingsJson => $composableBuilder(
    column: $table.viewSettingsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationEnabled => $composableBuilder(
    column: $table.notificationEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationTime => $composableBuilder(
    column: $table.notificationTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notificationDefaultOffsets => $composableBuilder(
    column: $table.notificationDefaultOffsets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get paymentAlertsEnabled => $composableBuilder(
    column: $table.paymentAlertsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viewSettingsJson => $composableBuilder(
    column: $table.viewSettingsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationEnabled => $composableBuilder(
    column: $table.notificationEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationTime => $composableBuilder(
    column: $table.notificationTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notificationDefaultOffsets => $composableBuilder(
    column: $table.notificationDefaultOffsets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get paymentAlertsEnabled => $composableBuilder(
    column: $table.paymentAlertsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<String> get viewSettingsJson => $composableBuilder(
    column: $table.viewSettingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notificationEnabled => $composableBuilder(
    column: $table.notificationEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationTime => $composableBuilder(
    column: $table.notificationTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notificationDefaultOffsets => $composableBuilder(
    column: $table.notificationDefaultOffsets,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get paymentAlertsEnabled => $composableBuilder(
    column: $table.paymentAlertsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserPreferencesTable,
          UserPreference,
          $$UserPreferencesTableFilterComposer,
          $$UserPreferencesTableOrderingComposer,
          $$UserPreferencesTableAnnotationComposer,
          $$UserPreferencesTableCreateCompanionBuilder,
          $$UserPreferencesTableUpdateCompanionBuilder,
          (
            UserPreference,
            BaseReferences<
              _$AppDatabase,
              $UserPreferencesTable,
              UserPreference
            >,
          ),
          UserPreference,
          PrefetchHooks Function()
        > {
  $$UserPreferencesTableTableManager(
    _$AppDatabase db,
    $UserPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> theme = const Value.absent(),
                Value<String?> viewSettingsJson = const Value.absent(),
                Value<bool> notificationEnabled = const Value.absent(),
                Value<int?> notificationTime = const Value.absent(),
                Value<String?> notificationDefaultOffsets =
                    const Value.absent(),
                Value<bool> paymentAlertsEnabled = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesCompanion(
                userId: userId,
                language: language,
                theme: theme,
                viewSettingsJson: viewSettingsJson,
                notificationEnabled: notificationEnabled,
                notificationTime: notificationTime,
                notificationDefaultOffsets: notificationDefaultOffsets,
                paymentAlertsEnabled: paymentAlertsEnabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                Value<String?> language = const Value.absent(),
                Value<String?> theme = const Value.absent(),
                Value<String?> viewSettingsJson = const Value.absent(),
                Value<bool> notificationEnabled = const Value.absent(),
                Value<int?> notificationTime = const Value.absent(),
                Value<String?> notificationDefaultOffsets =
                    const Value.absent(),
                Value<bool> paymentAlertsEnabled = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesCompanion.insert(
                userId: userId,
                language: language,
                theme: theme,
                viewSettingsJson: viewSettingsJson,
                notificationEnabled: notificationEnabled,
                notificationTime: notificationTime,
                notificationDefaultOffsets: notificationDefaultOffsets,
                paymentAlertsEnabled: paymentAlertsEnabled,
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

typedef $$UserPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserPreferencesTable,
      UserPreference,
      $$UserPreferencesTableFilterComposer,
      $$UserPreferencesTableOrderingComposer,
      $$UserPreferencesTableAnnotationComposer,
      $$UserPreferencesTableCreateCompanionBuilder,
      $$UserPreferencesTableUpdateCompanionBuilder,
      (
        UserPreference,
        BaseReferences<_$AppDatabase, $UserPreferencesTable, UserPreference>,
      ),
      UserPreference,
      PrefetchHooks Function()
    >;
typedef $$CaseNotificationPreferencesTableCreateCompanionBuilder =
    CaseNotificationPreferencesCompanion Function({
      required String userId,
      required String caseId,
      Value<bool> enabled,
      Value<String?> offsets,
      Value<int?> timeMinutes,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$CaseNotificationPreferencesTableUpdateCompanionBuilder =
    CaseNotificationPreferencesCompanion Function({
      Value<String> userId,
      Value<String> caseId,
      Value<bool> enabled,
      Value<String?> offsets,
      Value<int?> timeMinutes,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$CaseNotificationPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $CaseNotificationPreferencesTable> {
  $$CaseNotificationPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseId => $composableBuilder(
    column: $table.caseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get offsets => $composableBuilder(
    column: $table.offsets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeMinutes => $composableBuilder(
    column: $table.timeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CaseNotificationPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $CaseNotificationPreferencesTable> {
  $$CaseNotificationPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseId => $composableBuilder(
    column: $table.caseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get offsets => $composableBuilder(
    column: $table.offsets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeMinutes => $composableBuilder(
    column: $table.timeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CaseNotificationPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CaseNotificationPreferencesTable> {
  $$CaseNotificationPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get caseId =>
      $composableBuilder(column: $table.caseId, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get offsets =>
      $composableBuilder(column: $table.offsets, builder: (column) => column);

  GeneratedColumn<int> get timeMinutes => $composableBuilder(
    column: $table.timeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CaseNotificationPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CaseNotificationPreferencesTable,
          CaseNotificationPreference,
          $$CaseNotificationPreferencesTableFilterComposer,
          $$CaseNotificationPreferencesTableOrderingComposer,
          $$CaseNotificationPreferencesTableAnnotationComposer,
          $$CaseNotificationPreferencesTableCreateCompanionBuilder,
          $$CaseNotificationPreferencesTableUpdateCompanionBuilder,
          (
            CaseNotificationPreference,
            BaseReferences<
              _$AppDatabase,
              $CaseNotificationPreferencesTable,
              CaseNotificationPreference
            >,
          ),
          CaseNotificationPreference,
          PrefetchHooks Function()
        > {
  $$CaseNotificationPreferencesTableTableManager(
    _$AppDatabase db,
    $CaseNotificationPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaseNotificationPreferencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CaseNotificationPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CaseNotificationPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> caseId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> offsets = const Value.absent(),
                Value<int?> timeMinutes = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseNotificationPreferencesCompanion(
                userId: userId,
                caseId: caseId,
                enabled: enabled,
                offsets: offsets,
                timeMinutes: timeMinutes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String caseId,
                Value<bool> enabled = const Value.absent(),
                Value<String?> offsets = const Value.absent(),
                Value<int?> timeMinutes = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CaseNotificationPreferencesCompanion.insert(
                userId: userId,
                caseId: caseId,
                enabled: enabled,
                offsets: offsets,
                timeMinutes: timeMinutes,
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

typedef $$CaseNotificationPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CaseNotificationPreferencesTable,
      CaseNotificationPreference,
      $$CaseNotificationPreferencesTableFilterComposer,
      $$CaseNotificationPreferencesTableOrderingComposer,
      $$CaseNotificationPreferencesTableAnnotationComposer,
      $$CaseNotificationPreferencesTableCreateCompanionBuilder,
      $$CaseNotificationPreferencesTableUpdateCompanionBuilder,
      (
        CaseNotificationPreference,
        BaseReferences<
          _$AppDatabase,
          $CaseNotificationPreferencesTable,
          CaseNotificationPreference
        >,
      ),
      CaseNotificationPreference,
      PrefetchHooks Function()
    >;
typedef $$SharedCaseReferencesTableCreateCompanionBuilder =
    SharedCaseReferencesCompanion Function({
      required String id,
      required String referenceAndPageNo,
      Value<String?> statute,
      Value<String?> sectionOrArticle,
      Value<String?> titleAndDescription,
      Value<String?> commentsNotes,
      Value<String?> caseNote,
      Value<String?> tags,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$SharedCaseReferencesTableUpdateCompanionBuilder =
    SharedCaseReferencesCompanion Function({
      Value<String> id,
      Value<String> referenceAndPageNo,
      Value<String?> statute,
      Value<String?> sectionOrArticle,
      Value<String?> titleAndDescription,
      Value<String?> commentsNotes,
      Value<String?> caseNote,
      Value<String?> tags,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

class $$SharedCaseReferencesTableFilterComposer
    extends Composer<_$AppDatabase, $SharedCaseReferencesTable> {
  $$SharedCaseReferencesTableFilterComposer({
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

  ColumnFilters<String> get referenceAndPageNo => $composableBuilder(
    column: $table.referenceAndPageNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statute => $composableBuilder(
    column: $table.statute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionOrArticle => $composableBuilder(
    column: $table.sectionOrArticle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleAndDescription => $composableBuilder(
    column: $table.titleAndDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commentsNotes => $composableBuilder(
    column: $table.commentsNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseNote => $composableBuilder(
    column: $table.caseNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharedCaseReferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $SharedCaseReferencesTable> {
  $$SharedCaseReferencesTableOrderingComposer({
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

  ColumnOrderings<String> get referenceAndPageNo => $composableBuilder(
    column: $table.referenceAndPageNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statute => $composableBuilder(
    column: $table.statute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionOrArticle => $composableBuilder(
    column: $table.sectionOrArticle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleAndDescription => $composableBuilder(
    column: $table.titleAndDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commentsNotes => $composableBuilder(
    column: $table.commentsNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseNote => $composableBuilder(
    column: $table.caseNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharedCaseReferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharedCaseReferencesTable> {
  $$SharedCaseReferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get referenceAndPageNo => $composableBuilder(
    column: $table.referenceAndPageNo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get statute =>
      $composableBuilder(column: $table.statute, builder: (column) => column);

  GeneratedColumn<String> get sectionOrArticle => $composableBuilder(
    column: $table.sectionOrArticle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleAndDescription => $composableBuilder(
    column: $table.titleAndDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commentsNotes => $composableBuilder(
    column: $table.commentsNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get caseNote =>
      $composableBuilder(column: $table.caseNote, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$SharedCaseReferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharedCaseReferencesTable,
          SharedCaseReference,
          $$SharedCaseReferencesTableFilterComposer,
          $$SharedCaseReferencesTableOrderingComposer,
          $$SharedCaseReferencesTableAnnotationComposer,
          $$SharedCaseReferencesTableCreateCompanionBuilder,
          $$SharedCaseReferencesTableUpdateCompanionBuilder,
          (
            SharedCaseReference,
            BaseReferences<
              _$AppDatabase,
              $SharedCaseReferencesTable,
              SharedCaseReference
            >,
          ),
          SharedCaseReference,
          PrefetchHooks Function()
        > {
  $$SharedCaseReferencesTableTableManager(
    _$AppDatabase db,
    $SharedCaseReferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedCaseReferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedCaseReferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SharedCaseReferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> referenceAndPageNo = const Value.absent(),
                Value<String?> statute = const Value.absent(),
                Value<String?> sectionOrArticle = const Value.absent(),
                Value<String?> titleAndDescription = const Value.absent(),
                Value<String?> commentsNotes = const Value.absent(),
                Value<String?> caseNote = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedCaseReferencesCompanion(
                id: id,
                referenceAndPageNo: referenceAndPageNo,
                statute: statute,
                sectionOrArticle: sectionOrArticle,
                titleAndDescription: titleAndDescription,
                commentsNotes: commentsNotes,
                caseNote: caseNote,
                tags: tags,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String referenceAndPageNo,
                Value<String?> statute = const Value.absent(),
                Value<String?> sectionOrArticle = const Value.absent(),
                Value<String?> titleAndDescription = const Value.absent(),
                Value<String?> commentsNotes = const Value.absent(),
                Value<String?> caseNote = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedCaseReferencesCompanion.insert(
                id: id,
                referenceAndPageNo: referenceAndPageNo,
                statute: statute,
                sectionOrArticle: sectionOrArticle,
                titleAndDescription: titleAndDescription,
                commentsNotes: commentsNotes,
                caseNote: caseNote,
                tags: tags,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharedCaseReferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharedCaseReferencesTable,
      SharedCaseReference,
      $$SharedCaseReferencesTableFilterComposer,
      $$SharedCaseReferencesTableOrderingComposer,
      $$SharedCaseReferencesTableAnnotationComposer,
      $$SharedCaseReferencesTableCreateCompanionBuilder,
      $$SharedCaseReferencesTableUpdateCompanionBuilder,
      (
        SharedCaseReference,
        BaseReferences<
          _$AppDatabase,
          $SharedCaseReferencesTable,
          SharedCaseReference
        >,
      ),
      SharedCaseReference,
      PrefetchHooks Function()
    >;
typedef $$SharedCaseReferencePinsTableCreateCompanionBuilder =
    SharedCaseReferencePinsCompanion Function({
      required String referenceId,
      required int pinnedAt,
      Value<int> rowid,
    });
typedef $$SharedCaseReferencePinsTableUpdateCompanionBuilder =
    SharedCaseReferencePinsCompanion Function({
      Value<String> referenceId,
      Value<int> pinnedAt,
      Value<int> rowid,
    });

class $$SharedCaseReferencePinsTableFilterComposer
    extends Composer<_$AppDatabase, $SharedCaseReferencePinsTable> {
  $$SharedCaseReferencePinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharedCaseReferencePinsTableOrderingComposer
    extends Composer<_$AppDatabase, $SharedCaseReferencePinsTable> {
  $$SharedCaseReferencePinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharedCaseReferencePinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharedCaseReferencePinsTable> {
  $$SharedCaseReferencePinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => column);
}

class $$SharedCaseReferencePinsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharedCaseReferencePinsTable,
          SharedCaseReferencePin,
          $$SharedCaseReferencePinsTableFilterComposer,
          $$SharedCaseReferencePinsTableOrderingComposer,
          $$SharedCaseReferencePinsTableAnnotationComposer,
          $$SharedCaseReferencePinsTableCreateCompanionBuilder,
          $$SharedCaseReferencePinsTableUpdateCompanionBuilder,
          (
            SharedCaseReferencePin,
            BaseReferences<
              _$AppDatabase,
              $SharedCaseReferencePinsTable,
              SharedCaseReferencePin
            >,
          ),
          SharedCaseReferencePin,
          PrefetchHooks Function()
        > {
  $$SharedCaseReferencePinsTableTableManager(
    _$AppDatabase db,
    $SharedCaseReferencePinsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedCaseReferencePinsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SharedCaseReferencePinsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SharedCaseReferencePinsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> referenceId = const Value.absent(),
                Value<int> pinnedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedCaseReferencePinsCompanion(
                referenceId: referenceId,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String referenceId,
                required int pinnedAt,
                Value<int> rowid = const Value.absent(),
              }) => SharedCaseReferencePinsCompanion.insert(
                referenceId: referenceId,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharedCaseReferencePinsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharedCaseReferencePinsTable,
      SharedCaseReferencePin,
      $$SharedCaseReferencePinsTableFilterComposer,
      $$SharedCaseReferencePinsTableOrderingComposer,
      $$SharedCaseReferencePinsTableAnnotationComposer,
      $$SharedCaseReferencePinsTableCreateCompanionBuilder,
      $$SharedCaseReferencePinsTableUpdateCompanionBuilder,
      (
        SharedCaseReferencePin,
        BaseReferences<
          _$AppDatabase,
          $SharedCaseReferencePinsTable,
          SharedCaseReferencePin
        >,
      ),
      SharedCaseReferencePin,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CourtCategoriesTableTableManager get courtCategories =>
      $$CourtCategoriesTableTableManager(_db, _db.courtCategories);
  $$CourtsTableTableManager get courts =>
      $$CourtsTableTableManager(_db, _db.courts);
  $$CaseCategoriesTableTableManager get caseCategories =>
      $$CaseCategoriesTableTableManager(_db, _db.caseCategories);
  $$OnBehalfsTableTableManager get onBehalfs =>
      $$OnBehalfsTableTableManager(_db, _db.onBehalfs);
  $$CasesTableTableManager get cases =>
      $$CasesTableTableManager(_db, _db.cases);
  $$CaseHistoryTableTableManager get caseHistory =>
      $$CaseHistoryTableTableManager(_db, _db.caseHistory);
  $$StepsTableTableManager get steps =>
      $$StepsTableTableManager(_db, _db.steps);
  $$LawsTableTableManager get laws => $$LawsTableTableManager(_db, _db.laws);
  $$CaseTypesTableTableManager get caseTypes =>
      $$CaseTypesTableTableManager(_db, _db.caseTypes);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$CaseReferencesTableTableManager get caseReferences =>
      $$CaseReferencesTableTableManager(_db, _db.caseReferences);
  $$DeleteRequestsTableTableManager get deleteRequests =>
      $$DeleteRequestsTableTableManager(_db, _db.deleteRequests);
  $$ConflictLogTableTableManager get conflictLog =>
      $$ConflictLogTableTableManager(_db, _db.conflictLog);
  $$FirmsTableTableManager get firms =>
      $$FirmsTableTableManager(_db, _db.firms);
  $$FirmMembersTableTableManager get firmMembers =>
      $$FirmMembersTableTableManager(_db, _db.firmMembers);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
  $$SeedMigrationsTableTableManager get seedMigrations =>
      $$SeedMigrationsTableTableManager(_db, _db.seedMigrations);
  $$UserPreferencesTableTableManager get userPreferences =>
      $$UserPreferencesTableTableManager(_db, _db.userPreferences);
  $$CaseNotificationPreferencesTableTableManager
  get caseNotificationPreferences =>
      $$CaseNotificationPreferencesTableTableManager(
        _db,
        _db.caseNotificationPreferences,
      );
  $$SharedCaseReferencesTableTableManager get sharedCaseReferences =>
      $$SharedCaseReferencesTableTableManager(_db, _db.sharedCaseReferences);
  $$SharedCaseReferencePinsTableTableManager get sharedCaseReferencePins =>
      $$SharedCaseReferencePinsTableTableManager(
        _db,
        _db.sharedCaseReferencePins,
      );
}
