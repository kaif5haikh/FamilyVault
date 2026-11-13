// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PendingMutationsTable extends PendingMutations
    with TableInfo<$PendingMutationsTable, PendingMutation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
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
  static const VerificationMeta _mutationKindMeta = const VerificationMeta(
    'mutationKind',
  );
  @override
  late final GeneratedColumn<String> mutationKind = GeneratedColumn<String>(
    'mutation_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseRevisionMeta = const VerificationMeta(
    'baseRevision',
  );
  @override
  late final GeneratedColumn<int> baseRevision = GeneratedColumn<int>(
    'base_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadDigestMeta = const VerificationMeta(
    'payloadDigest',
  );
  @override
  late final GeneratedColumn<String> payloadDigest = GeneratedColumn<String>(
    'payload_digest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _protocolVersionMeta = const VerificationMeta(
    'protocolVersion',
  );
  @override
  late final GeneratedColumn<int> protocolVersion = GeneratedColumn<int>(
    'protocol_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<int> createdAtUs = GeneratedColumn<int>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptAtUsMeta = const VerificationMeta(
    'nextAttemptAtUs',
  );
  @override
  late final GeneratedColumn<int> nextAttemptAtUs = GeneratedColumn<int>(
    'next_attempt_at_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseExpiresAtUsMeta = const VerificationMeta(
    'leaseExpiresAtUs',
  );
  @override
  late final GeneratedColumn<int> leaseExpiresAtUs = GeneratedColumn<int>(
    'lease_expires_at_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acceptedRevisionMeta = const VerificationMeta(
    'acceptedRevision',
  );
  @override
  late final GeneratedColumn<int> acceptedRevision = GeneratedColumn<int>(
    'accepted_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    familyId,
    deviceId,
    entityType,
    entityId,
    mutationKind,
    baseRevision,
    payloadJson,
    payloadDigest,
    protocolVersion,
    state,
    attempts,
    createdAtUs,
    nextAttemptAtUs,
    leaseExpiresAtUs,
    acceptedRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_mutations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingMutation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
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
    if (data.containsKey('mutation_kind')) {
      context.handle(
        _mutationKindMeta,
        mutationKind.isAcceptableOrUnknown(
          data['mutation_kind']!,
          _mutationKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mutationKindMeta);
    }
    if (data.containsKey('base_revision')) {
      context.handle(
        _baseRevisionMeta,
        baseRevision.isAcceptableOrUnknown(
          data['base_revision']!,
          _baseRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseRevisionMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('payload_digest')) {
      context.handle(
        _payloadDigestMeta,
        payloadDigest.isAcceptableOrUnknown(
          data['payload_digest']!,
          _payloadDigestMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadDigestMeta);
    }
    if (data.containsKey('protocol_version')) {
      context.handle(
        _protocolVersionMeta,
        protocolVersion.isAcceptableOrUnknown(
          data['protocol_version']!,
          _protocolVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_protocolVersionMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    if (data.containsKey('next_attempt_at_us')) {
      context.handle(
        _nextAttemptAtUsMeta,
        nextAttemptAtUs.isAcceptableOrUnknown(
          data['next_attempt_at_us']!,
          _nextAttemptAtUsMeta,
        ),
      );
    }
    if (data.containsKey('lease_expires_at_us')) {
      context.handle(
        _leaseExpiresAtUsMeta,
        leaseExpiresAtUs.isAcceptableOrUnknown(
          data['lease_expires_at_us']!,
          _leaseExpiresAtUsMeta,
        ),
      );
    }
    if (data.containsKey('accepted_revision')) {
      context.handle(
        _acceptedRevisionMeta,
        acceptedRevision.isAcceptableOrUnknown(
          data['accepted_revision']!,
          _acceptedRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  PendingMutation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingMutation(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      mutationKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_kind'],
      )!,
      baseRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_revision'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      payloadDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_digest'],
      )!,
      protocolVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protocol_version'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_us'],
      )!,
      nextAttemptAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at_us'],
      ),
      leaseExpiresAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lease_expires_at_us'],
      ),
      acceptedRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accepted_revision'],
      ),
    );
  }

  @override
  $PendingMutationsTable createAlias(String alias) {
    return $PendingMutationsTable(attachedDatabase, alias);
  }
}

class PendingMutation extends DataClass implements Insertable<PendingMutation> {
  final String operationId;
  final String familyId;
  final String deviceId;
  final String entityType;
  final String entityId;
  final String mutationKind;
  final int baseRevision;
  final String payloadJson;
  final String payloadDigest;
  final int protocolVersion;
  final String state;
  final int attempts;
  final int createdAtUs;
  final int? nextAttemptAtUs;
  final int? leaseExpiresAtUs;
  final int? acceptedRevision;
  const PendingMutation({
    required this.operationId,
    required this.familyId,
    required this.deviceId,
    required this.entityType,
    required this.entityId,
    required this.mutationKind,
    required this.baseRevision,
    required this.payloadJson,
    required this.payloadDigest,
    required this.protocolVersion,
    required this.state,
    required this.attempts,
    required this.createdAtUs,
    this.nextAttemptAtUs,
    this.leaseExpiresAtUs,
    this.acceptedRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['family_id'] = Variable<String>(familyId);
    map['device_id'] = Variable<String>(deviceId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['mutation_kind'] = Variable<String>(mutationKind);
    map['base_revision'] = Variable<int>(baseRevision);
    map['payload_json'] = Variable<String>(payloadJson);
    map['payload_digest'] = Variable<String>(payloadDigest);
    map['protocol_version'] = Variable<int>(protocolVersion);
    map['state'] = Variable<String>(state);
    map['attempts'] = Variable<int>(attempts);
    map['created_at_us'] = Variable<int>(createdAtUs);
    if (!nullToAbsent || nextAttemptAtUs != null) {
      map['next_attempt_at_us'] = Variable<int>(nextAttemptAtUs);
    }
    if (!nullToAbsent || leaseExpiresAtUs != null) {
      map['lease_expires_at_us'] = Variable<int>(leaseExpiresAtUs);
    }
    if (!nullToAbsent || acceptedRevision != null) {
      map['accepted_revision'] = Variable<int>(acceptedRevision);
    }
    return map;
  }

  PendingMutationsCompanion toCompanion(bool nullToAbsent) {
    return PendingMutationsCompanion(
      operationId: Value(operationId),
      familyId: Value(familyId),
      deviceId: Value(deviceId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      mutationKind: Value(mutationKind),
      baseRevision: Value(baseRevision),
      payloadJson: Value(payloadJson),
      payloadDigest: Value(payloadDigest),
      protocolVersion: Value(protocolVersion),
      state: Value(state),
      attempts: Value(attempts),
      createdAtUs: Value(createdAtUs),
      nextAttemptAtUs: nextAttemptAtUs == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAtUs),
      leaseExpiresAtUs: leaseExpiresAtUs == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseExpiresAtUs),
      acceptedRevision: acceptedRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptedRevision),
    );
  }

  factory PendingMutation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingMutation(
      operationId: serializer.fromJson<String>(json['operationId']),
      familyId: serializer.fromJson<String>(json['familyId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      mutationKind: serializer.fromJson<String>(json['mutationKind']),
      baseRevision: serializer.fromJson<int>(json['baseRevision']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      payloadDigest: serializer.fromJson<String>(json['payloadDigest']),
      protocolVersion: serializer.fromJson<int>(json['protocolVersion']),
      state: serializer.fromJson<String>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      createdAtUs: serializer.fromJson<int>(json['createdAtUs']),
      nextAttemptAtUs: serializer.fromJson<int?>(json['nextAttemptAtUs']),
      leaseExpiresAtUs: serializer.fromJson<int?>(json['leaseExpiresAtUs']),
      acceptedRevision: serializer.fromJson<int?>(json['acceptedRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'familyId': serializer.toJson<String>(familyId),
      'deviceId': serializer.toJson<String>(deviceId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'mutationKind': serializer.toJson<String>(mutationKind),
      'baseRevision': serializer.toJson<int>(baseRevision),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'payloadDigest': serializer.toJson<String>(payloadDigest),
      'protocolVersion': serializer.toJson<int>(protocolVersion),
      'state': serializer.toJson<String>(state),
      'attempts': serializer.toJson<int>(attempts),
      'createdAtUs': serializer.toJson<int>(createdAtUs),
      'nextAttemptAtUs': serializer.toJson<int?>(nextAttemptAtUs),
      'leaseExpiresAtUs': serializer.toJson<int?>(leaseExpiresAtUs),
      'acceptedRevision': serializer.toJson<int?>(acceptedRevision),
    };
  }

  PendingMutation copyWith({
    String? operationId,
    String? familyId,
    String? deviceId,
    String? entityType,
    String? entityId,
    String? mutationKind,
    int? baseRevision,
    String? payloadJson,
    String? payloadDigest,
    int? protocolVersion,
    String? state,
    int? attempts,
    int? createdAtUs,
    Value<int?> nextAttemptAtUs = const Value.absent(),
    Value<int?> leaseExpiresAtUs = const Value.absent(),
    Value<int?> acceptedRevision = const Value.absent(),
  }) => PendingMutation(
    operationId: operationId ?? this.operationId,
    familyId: familyId ?? this.familyId,
    deviceId: deviceId ?? this.deviceId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    mutationKind: mutationKind ?? this.mutationKind,
    baseRevision: baseRevision ?? this.baseRevision,
    payloadJson: payloadJson ?? this.payloadJson,
    payloadDigest: payloadDigest ?? this.payloadDigest,
    protocolVersion: protocolVersion ?? this.protocolVersion,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    createdAtUs: createdAtUs ?? this.createdAtUs,
    nextAttemptAtUs: nextAttemptAtUs.present
        ? nextAttemptAtUs.value
        : this.nextAttemptAtUs,
    leaseExpiresAtUs: leaseExpiresAtUs.present
        ? leaseExpiresAtUs.value
        : this.leaseExpiresAtUs,
    acceptedRevision: acceptedRevision.present
        ? acceptedRevision.value
        : this.acceptedRevision,
  );
  PendingMutation copyWithCompanion(PendingMutationsCompanion data) {
    return PendingMutation(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      mutationKind: data.mutationKind.present
          ? data.mutationKind.value
          : this.mutationKind,
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      payloadDigest: data.payloadDigest.present
          ? data.payloadDigest.value
          : this.payloadDigest,
      protocolVersion: data.protocolVersion.present
          ? data.protocolVersion.value
          : this.protocolVersion,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
      nextAttemptAtUs: data.nextAttemptAtUs.present
          ? data.nextAttemptAtUs.value
          : this.nextAttemptAtUs,
      leaseExpiresAtUs: data.leaseExpiresAtUs.present
          ? data.leaseExpiresAtUs.value
          : this.leaseExpiresAtUs,
      acceptedRevision: data.acceptedRevision.present
          ? data.acceptedRevision.value
          : this.acceptedRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutation(')
          ..write('operationId: $operationId, ')
          ..write('familyId: $familyId, ')
          ..write('deviceId: $deviceId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('mutationKind: $mutationKind, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('payloadDigest: $payloadDigest, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('nextAttemptAtUs: $nextAttemptAtUs, ')
          ..write('leaseExpiresAtUs: $leaseExpiresAtUs, ')
          ..write('acceptedRevision: $acceptedRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    familyId,
    deviceId,
    entityType,
    entityId,
    mutationKind,
    baseRevision,
    payloadJson,
    payloadDigest,
    protocolVersion,
    state,
    attempts,
    createdAtUs,
    nextAttemptAtUs,
    leaseExpiresAtUs,
    acceptedRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMutation &&
          other.operationId == this.operationId &&
          other.familyId == this.familyId &&
          other.deviceId == this.deviceId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.mutationKind == this.mutationKind &&
          other.baseRevision == this.baseRevision &&
          other.payloadJson == this.payloadJson &&
          other.payloadDigest == this.payloadDigest &&
          other.protocolVersion == this.protocolVersion &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.createdAtUs == this.createdAtUs &&
          other.nextAttemptAtUs == this.nextAttemptAtUs &&
          other.leaseExpiresAtUs == this.leaseExpiresAtUs &&
          other.acceptedRevision == this.acceptedRevision);
}

class PendingMutationsCompanion extends UpdateCompanion<PendingMutation> {
  final Value<String> operationId;
  final Value<String> familyId;
  final Value<String> deviceId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> mutationKind;
  final Value<int> baseRevision;
  final Value<String> payloadJson;
  final Value<String> payloadDigest;
  final Value<int> protocolVersion;
  final Value<String> state;
  final Value<int> attempts;
  final Value<int> createdAtUs;
  final Value<int?> nextAttemptAtUs;
  final Value<int?> leaseExpiresAtUs;
  final Value<int?> acceptedRevision;
  final Value<int> rowid;
  const PendingMutationsCompanion({
    this.operationId = const Value.absent(),
    this.familyId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.mutationKind = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.payloadDigest = const Value.absent(),
    this.protocolVersion = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.nextAttemptAtUs = const Value.absent(),
    this.leaseExpiresAtUs = const Value.absent(),
    this.acceptedRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingMutationsCompanion.insert({
    required String operationId,
    required String familyId,
    required String deviceId,
    required String entityType,
    required String entityId,
    required String mutationKind,
    required int baseRevision,
    required String payloadJson,
    required String payloadDigest,
    required int protocolVersion,
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    required int createdAtUs,
    this.nextAttemptAtUs = const Value.absent(),
    this.leaseExpiresAtUs = const Value.absent(),
    this.acceptedRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       familyId = Value(familyId),
       deviceId = Value(deviceId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       mutationKind = Value(mutationKind),
       baseRevision = Value(baseRevision),
       payloadJson = Value(payloadJson),
       payloadDigest = Value(payloadDigest),
       protocolVersion = Value(protocolVersion),
       createdAtUs = Value(createdAtUs);
  static Insertable<PendingMutation> custom({
    Expression<String>? operationId,
    Expression<String>? familyId,
    Expression<String>? deviceId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? mutationKind,
    Expression<int>? baseRevision,
    Expression<String>? payloadJson,
    Expression<String>? payloadDigest,
    Expression<int>? protocolVersion,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<int>? createdAtUs,
    Expression<int>? nextAttemptAtUs,
    Expression<int>? leaseExpiresAtUs,
    Expression<int>? acceptedRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (familyId != null) 'family_id': familyId,
      if (deviceId != null) 'device_id': deviceId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (mutationKind != null) 'mutation_kind': mutationKind,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (payloadDigest != null) 'payload_digest': payloadDigest,
      if (protocolVersion != null) 'protocol_version': protocolVersion,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (nextAttemptAtUs != null) 'next_attempt_at_us': nextAttemptAtUs,
      if (leaseExpiresAtUs != null) 'lease_expires_at_us': leaseExpiresAtUs,
      if (acceptedRevision != null) 'accepted_revision': acceptedRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingMutationsCompanion copyWith({
    Value<String>? operationId,
    Value<String>? familyId,
    Value<String>? deviceId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? mutationKind,
    Value<int>? baseRevision,
    Value<String>? payloadJson,
    Value<String>? payloadDigest,
    Value<int>? protocolVersion,
    Value<String>? state,
    Value<int>? attempts,
    Value<int>? createdAtUs,
    Value<int?>? nextAttemptAtUs,
    Value<int?>? leaseExpiresAtUs,
    Value<int?>? acceptedRevision,
    Value<int>? rowid,
  }) {
    return PendingMutationsCompanion(
      operationId: operationId ?? this.operationId,
      familyId: familyId ?? this.familyId,
      deviceId: deviceId ?? this.deviceId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      mutationKind: mutationKind ?? this.mutationKind,
      baseRevision: baseRevision ?? this.baseRevision,
      payloadJson: payloadJson ?? this.payloadJson,
      payloadDigest: payloadDigest ?? this.payloadDigest,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      nextAttemptAtUs: nextAttemptAtUs ?? this.nextAttemptAtUs,
      leaseExpiresAtUs: leaseExpiresAtUs ?? this.leaseExpiresAtUs,
      acceptedRevision: acceptedRevision ?? this.acceptedRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (mutationKind.present) {
      map['mutation_kind'] = Variable<String>(mutationKind.value);
    }
    if (baseRevision.present) {
      map['base_revision'] = Variable<int>(baseRevision.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (payloadDigest.present) {
      map['payload_digest'] = Variable<String>(payloadDigest.value);
    }
    if (protocolVersion.present) {
      map['protocol_version'] = Variable<int>(protocolVersion.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<int>(createdAtUs.value);
    }
    if (nextAttemptAtUs.present) {
      map['next_attempt_at_us'] = Variable<int>(nextAttemptAtUs.value);
    }
    if (leaseExpiresAtUs.present) {
      map['lease_expires_at_us'] = Variable<int>(leaseExpiresAtUs.value);
    }
    if (acceptedRevision.present) {
      map['accepted_revision'] = Variable<int>(acceptedRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutationsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('familyId: $familyId, ')
          ..write('deviceId: $deviceId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('mutationKind: $mutationKind, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('payloadDigest: $payloadDigest, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('nextAttemptAtUs: $nextAttemptAtUs, ')
          ..write('leaseExpiresAtUs: $leaseExpiresAtUs, ')
          ..write('acceptedRevision: $acceptedRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCheckpointsTable extends SyncCheckpoints
    with TableInfo<$SyncCheckpointsTable, SyncCheckpoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCheckpointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSequenceMeta = const VerificationMeta(
    'lastSequence',
  );
  @override
  late final GeneratedColumn<int> lastSequence = GeneratedColumn<int>(
    'last_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _authorizationEpochMeta =
      const VerificationMeta('authorizationEpoch');
  @override
  late final GeneratedColumn<int> authorizationEpoch = GeneratedColumn<int>(
    'authorization_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUs = GeneratedColumn<int>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    familyId,
    lastSequence,
    authorizationEpoch,
    updatedAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_checkpoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCheckpoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('last_sequence')) {
      context.handle(
        _lastSequenceMeta,
        lastSequence.isAcceptableOrUnknown(
          data['last_sequence']!,
          _lastSequenceMeta,
        ),
      );
    }
    if (data.containsKey('authorization_epoch')) {
      context.handle(
        _authorizationEpochMeta,
        authorizationEpoch.isAcceptableOrUnknown(
          data['authorization_epoch']!,
          _authorizationEpochMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {familyId};
  @override
  SyncCheckpoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCheckpoint(
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      lastSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sequence'],
      )!,
      authorizationEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}authorization_epoch'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_us'],
      )!,
    );
  }

  @override
  $SyncCheckpointsTable createAlias(String alias) {
    return $SyncCheckpointsTable(attachedDatabase, alias);
  }
}

class SyncCheckpoint extends DataClass implements Insertable<SyncCheckpoint> {
  final String familyId;
  final int lastSequence;
  final int authorizationEpoch;
  final int updatedAtUs;
  const SyncCheckpoint({
    required this.familyId,
    required this.lastSequence,
    required this.authorizationEpoch,
    required this.updatedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['family_id'] = Variable<String>(familyId);
    map['last_sequence'] = Variable<int>(lastSequence);
    map['authorization_epoch'] = Variable<int>(authorizationEpoch);
    map['updated_at_us'] = Variable<int>(updatedAtUs);
    return map;
  }

  SyncCheckpointsCompanion toCompanion(bool nullToAbsent) {
    return SyncCheckpointsCompanion(
      familyId: Value(familyId),
      lastSequence: Value(lastSequence),
      authorizationEpoch: Value(authorizationEpoch),
      updatedAtUs: Value(updatedAtUs),
    );
  }

  factory SyncCheckpoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCheckpoint(
      familyId: serializer.fromJson<String>(json['familyId']),
      lastSequence: serializer.fromJson<int>(json['lastSequence']),
      authorizationEpoch: serializer.fromJson<int>(json['authorizationEpoch']),
      updatedAtUs: serializer.fromJson<int>(json['updatedAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'familyId': serializer.toJson<String>(familyId),
      'lastSequence': serializer.toJson<int>(lastSequence),
      'authorizationEpoch': serializer.toJson<int>(authorizationEpoch),
      'updatedAtUs': serializer.toJson<int>(updatedAtUs),
    };
  }

  SyncCheckpoint copyWith({
    String? familyId,
    int? lastSequence,
    int? authorizationEpoch,
    int? updatedAtUs,
  }) => SyncCheckpoint(
    familyId: familyId ?? this.familyId,
    lastSequence: lastSequence ?? this.lastSequence,
    authorizationEpoch: authorizationEpoch ?? this.authorizationEpoch,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
  );
  SyncCheckpoint copyWithCompanion(SyncCheckpointsCompanion data) {
    return SyncCheckpoint(
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      lastSequence: data.lastSequence.present
          ? data.lastSequence.value
          : this.lastSequence,
      authorizationEpoch: data.authorizationEpoch.present
          ? data.authorizationEpoch.value
          : this.authorizationEpoch,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCheckpoint(')
          ..write('familyId: $familyId, ')
          ..write('lastSequence: $lastSequence, ')
          ..write('authorizationEpoch: $authorizationEpoch, ')
          ..write('updatedAtUs: $updatedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(familyId, lastSequence, authorizationEpoch, updatedAtUs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCheckpoint &&
          other.familyId == this.familyId &&
          other.lastSequence == this.lastSequence &&
          other.authorizationEpoch == this.authorizationEpoch &&
          other.updatedAtUs == this.updatedAtUs);
}

class SyncCheckpointsCompanion extends UpdateCompanion<SyncCheckpoint> {
  final Value<String> familyId;
  final Value<int> lastSequence;
  final Value<int> authorizationEpoch;
  final Value<int> updatedAtUs;
  final Value<int> rowid;
  const SyncCheckpointsCompanion({
    this.familyId = const Value.absent(),
    this.lastSequence = const Value.absent(),
    this.authorizationEpoch = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCheckpointsCompanion.insert({
    required String familyId,
    this.lastSequence = const Value.absent(),
    this.authorizationEpoch = const Value.absent(),
    required int updatedAtUs,
    this.rowid = const Value.absent(),
  }) : familyId = Value(familyId),
       updatedAtUs = Value(updatedAtUs);
  static Insertable<SyncCheckpoint> custom({
    Expression<String>? familyId,
    Expression<int>? lastSequence,
    Expression<int>? authorizationEpoch,
    Expression<int>? updatedAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (familyId != null) 'family_id': familyId,
      if (lastSequence != null) 'last_sequence': lastSequence,
      if (authorizationEpoch != null) 'authorization_epoch': authorizationEpoch,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCheckpointsCompanion copyWith({
    Value<String>? familyId,
    Value<int>? lastSequence,
    Value<int>? authorizationEpoch,
    Value<int>? updatedAtUs,
    Value<int>? rowid,
  }) {
    return SyncCheckpointsCompanion(
      familyId: familyId ?? this.familyId,
      lastSequence: lastSequence ?? this.lastSequence,
      authorizationEpoch: authorizationEpoch ?? this.authorizationEpoch,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (lastSequence.present) {
      map['last_sequence'] = Variable<int>(lastSequence.value);
    }
    if (authorizationEpoch.present) {
      map['authorization_epoch'] = Variable<int>(authorizationEpoch.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<int>(updatedAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCheckpointsCompanion(')
          ..write('familyId: $familyId, ')
          ..write('lastSequence: $lastSequence, ')
          ..write('authorizationEpoch: $authorizationEpoch, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES pending_mutations (operation_id)',
    ),
  );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverSnapshotJsonMeta =
      const VerificationMeta('serverSnapshotJson');
  @override
  late final GeneratedColumn<String> serverSnapshotJson =
      GeneratedColumn<String>(
        'server_snapshot_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _detectedAtUsMeta = const VerificationMeta(
    'detectedAtUs',
  );
  @override
  late final GeneratedColumn<int> detectedAtUs = GeneratedColumn<int>(
    'detected_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtUsMeta = const VerificationMeta(
    'resolvedAtUs',
  );
  @override
  late final GeneratedColumn<int> resolvedAtUs = GeneratedColumn<int>(
    'resolved_at_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operationId,
    serverRevision,
    serverSnapshotJson,
    detectedAtUs,
    resolvedAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverRevisionMeta);
    }
    if (data.containsKey('server_snapshot_json')) {
      context.handle(
        _serverSnapshotJsonMeta,
        serverSnapshotJson.isAcceptableOrUnknown(
          data['server_snapshot_json']!,
          _serverSnapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverSnapshotJsonMeta);
    }
    if (data.containsKey('detected_at_us')) {
      context.handle(
        _detectedAtUsMeta,
        detectedAtUs.isAcceptableOrUnknown(
          data['detected_at_us']!,
          _detectedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_detectedAtUsMeta);
    }
    if (data.containsKey('resolved_at_us')) {
      context.handle(
        _resolvedAtUsMeta,
        resolvedAtUs.isAcceptableOrUnknown(
          data['resolved_at_us']!,
          _resolvedAtUsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflict(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
      serverSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_snapshot_json'],
      )!,
      detectedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detected_at_us'],
      )!,
      resolvedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolved_at_us'],
      ),
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }
}

class SyncConflict extends DataClass implements Insertable<SyncConflict> {
  final String id;
  final String operationId;
  final int serverRevision;
  final String serverSnapshotJson;
  final int detectedAtUs;
  final int? resolvedAtUs;
  const SyncConflict({
    required this.id,
    required this.operationId,
    required this.serverRevision,
    required this.serverSnapshotJson,
    required this.detectedAtUs,
    this.resolvedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['operation_id'] = Variable<String>(operationId);
    map['server_revision'] = Variable<int>(serverRevision);
    map['server_snapshot_json'] = Variable<String>(serverSnapshotJson);
    map['detected_at_us'] = Variable<int>(detectedAtUs);
    if (!nullToAbsent || resolvedAtUs != null) {
      map['resolved_at_us'] = Variable<int>(resolvedAtUs);
    }
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      id: Value(id),
      operationId: Value(operationId),
      serverRevision: Value(serverRevision),
      serverSnapshotJson: Value(serverSnapshotJson),
      detectedAtUs: Value(detectedAtUs),
      resolvedAtUs: resolvedAtUs == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAtUs),
    );
  }

  factory SyncConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflict(
      id: serializer.fromJson<String>(json['id']),
      operationId: serializer.fromJson<String>(json['operationId']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
      serverSnapshotJson: serializer.fromJson<String>(
        json['serverSnapshotJson'],
      ),
      detectedAtUs: serializer.fromJson<int>(json['detectedAtUs']),
      resolvedAtUs: serializer.fromJson<int?>(json['resolvedAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'operationId': serializer.toJson<String>(operationId),
      'serverRevision': serializer.toJson<int>(serverRevision),
      'serverSnapshotJson': serializer.toJson<String>(serverSnapshotJson),
      'detectedAtUs': serializer.toJson<int>(detectedAtUs),
      'resolvedAtUs': serializer.toJson<int?>(resolvedAtUs),
    };
  }

  SyncConflict copyWith({
    String? id,
    String? operationId,
    int? serverRevision,
    String? serverSnapshotJson,
    int? detectedAtUs,
    Value<int?> resolvedAtUs = const Value.absent(),
  }) => SyncConflict(
    id: id ?? this.id,
    operationId: operationId ?? this.operationId,
    serverRevision: serverRevision ?? this.serverRevision,
    serverSnapshotJson: serverSnapshotJson ?? this.serverSnapshotJson,
    detectedAtUs: detectedAtUs ?? this.detectedAtUs,
    resolvedAtUs: resolvedAtUs.present ? resolvedAtUs.value : this.resolvedAtUs,
  );
  SyncConflict copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflict(
      id: data.id.present ? data.id.value : this.id,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
      serverSnapshotJson: data.serverSnapshotJson.present
          ? data.serverSnapshotJson.value
          : this.serverSnapshotJson,
      detectedAtUs: data.detectedAtUs.present
          ? data.detectedAtUs.value
          : this.detectedAtUs,
      resolvedAtUs: data.resolvedAtUs.present
          ? data.resolvedAtUs.value
          : this.resolvedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflict(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('serverSnapshotJson: $serverSnapshotJson, ')
          ..write('detectedAtUs: $detectedAtUs, ')
          ..write('resolvedAtUs: $resolvedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operationId,
    serverRevision,
    serverSnapshotJson,
    detectedAtUs,
    resolvedAtUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflict &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.serverRevision == this.serverRevision &&
          other.serverSnapshotJson == this.serverSnapshotJson &&
          other.detectedAtUs == this.detectedAtUs &&
          other.resolvedAtUs == this.resolvedAtUs);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflict> {
  final Value<String> id;
  final Value<String> operationId;
  final Value<int> serverRevision;
  final Value<String> serverSnapshotJson;
  final Value<int> detectedAtUs;
  final Value<int?> resolvedAtUs;
  final Value<int> rowid;
  const SyncConflictsCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.serverSnapshotJson = const Value.absent(),
    this.detectedAtUs = const Value.absent(),
    this.resolvedAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    required String id,
    required String operationId,
    required int serverRevision,
    required String serverSnapshotJson,
    required int detectedAtUs,
    this.resolvedAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       operationId = Value(operationId),
       serverRevision = Value(serverRevision),
       serverSnapshotJson = Value(serverSnapshotJson),
       detectedAtUs = Value(detectedAtUs);
  static Insertable<SyncConflict> custom({
    Expression<String>? id,
    Expression<String>? operationId,
    Expression<int>? serverRevision,
    Expression<String>? serverSnapshotJson,
    Expression<int>? detectedAtUs,
    Expression<int>? resolvedAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (serverSnapshotJson != null)
        'server_snapshot_json': serverSnapshotJson,
      if (detectedAtUs != null) 'detected_at_us': detectedAtUs,
      if (resolvedAtUs != null) 'resolved_at_us': resolvedAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<String>? id,
    Value<String>? operationId,
    Value<int>? serverRevision,
    Value<String>? serverSnapshotJson,
    Value<int>? detectedAtUs,
    Value<int?>? resolvedAtUs,
    Value<int>? rowid,
  }) {
    return SyncConflictsCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      serverRevision: serverRevision ?? this.serverRevision,
      serverSnapshotJson: serverSnapshotJson ?? this.serverSnapshotJson,
      detectedAtUs: detectedAtUs ?? this.detectedAtUs,
      resolvedAtUs: resolvedAtUs ?? this.resolvedAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (serverSnapshotJson.present) {
      map['server_snapshot_json'] = Variable<String>(serverSnapshotJson.value);
    }
    if (detectedAtUs.present) {
      map['detected_at_us'] = Variable<int>(detectedAtUs.value);
    }
    if (resolvedAtUs.present) {
      map['resolved_at_us'] = Variable<int>(resolvedAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('serverSnapshotJson: $serverSnapshotJson, ')
          ..write('detectedAtUs: $detectedAtUs, ')
          ..write('resolvedAtUs: $resolvedAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilySpacesTable extends FamilySpaces
    with TableInfo<$FamilySpacesTable, FamilySpace> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilySpacesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<int> createdAtUs = GeneratedColumn<int>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, mode, currency, createdAtUs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_spaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilySpace> instance, {
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
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FamilySpace map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilySpace(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_us'],
      )!,
    );
  }

  @override
  $FamilySpacesTable createAlias(String alias) {
    return $FamilySpacesTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class FamilySpace extends DataClass implements Insertable<FamilySpace> {
  final String id;
  final String name;
  final String mode;
  final String currency;
  final int createdAtUs;
  const FamilySpace({
    required this.id,
    required this.name,
    required this.mode,
    required this.currency,
    required this.createdAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['mode'] = Variable<String>(mode);
    map['currency'] = Variable<String>(currency);
    map['created_at_us'] = Variable<int>(createdAtUs);
    return map;
  }

  FamilySpacesCompanion toCompanion(bool nullToAbsent) {
    return FamilySpacesCompanion(
      id: Value(id),
      name: Value(name),
      mode: Value(mode),
      currency: Value(currency),
      createdAtUs: Value(createdAtUs),
    );
  }

  factory FamilySpace.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilySpace(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      mode: serializer.fromJson<String>(json['mode']),
      currency: serializer.fromJson<String>(json['currency']),
      createdAtUs: serializer.fromJson<int>(json['createdAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'mode': serializer.toJson<String>(mode),
      'currency': serializer.toJson<String>(currency),
      'createdAtUs': serializer.toJson<int>(createdAtUs),
    };
  }

  FamilySpace copyWith({
    String? id,
    String? name,
    String? mode,
    String? currency,
    int? createdAtUs,
  }) => FamilySpace(
    id: id ?? this.id,
    name: name ?? this.name,
    mode: mode ?? this.mode,
    currency: currency ?? this.currency,
    createdAtUs: createdAtUs ?? this.createdAtUs,
  );
  FamilySpace copyWithCompanion(FamilySpacesCompanion data) {
    return FamilySpace(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      mode: data.mode.present ? data.mode.value : this.mode,
      currency: data.currency.present ? data.currency.value : this.currency,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilySpace(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mode: $mode, ')
          ..write('currency: $currency, ')
          ..write('createdAtUs: $createdAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, mode, currency, createdAtUs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilySpace &&
          other.id == this.id &&
          other.name == this.name &&
          other.mode == this.mode &&
          other.currency == this.currency &&
          other.createdAtUs == this.createdAtUs);
}

class FamilySpacesCompanion extends UpdateCompanion<FamilySpace> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> mode;
  final Value<String> currency;
  final Value<int> createdAtUs;
  final Value<int> rowid;
  const FamilySpacesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.mode = const Value.absent(),
    this.currency = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilySpacesCompanion.insert({
    required String id,
    required String name,
    required String mode,
    this.currency = const Value.absent(),
    required int createdAtUs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       mode = Value(mode),
       createdAtUs = Value(createdAtUs);
  static Insertable<FamilySpace> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? mode,
    Expression<String>? currency,
    Expression<int>? createdAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (mode != null) 'mode': mode,
      if (currency != null) 'currency': currency,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilySpacesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? mode,
    Value<String>? currency,
    Value<int>? createdAtUs,
    Value<int>? rowid,
  }) {
    return FamilySpacesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      currency: currency ?? this.currency,
      createdAtUs: createdAtUs ?? this.createdAtUs,
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
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<int>(createdAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilySpacesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mode: $mode, ')
          ..write('currency: $currency, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyMembersTable extends FamilyMembers
    with TableInfo<$FamilyMembersTable, FamilyMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES family_spaces (id)',
    ),
  );
  static const VerificationMeta _authUserIdMeta = const VerificationMeta(
    'authUserId',
  );
  @override
  late final GeneratedColumn<String> authUserId = GeneratedColumn<String>(
    'auth_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relationshipMeta = const VerificationMeta(
    'relationship',
  );
  @override
  late final GeneratedColumn<String> relationship = GeneratedColumn<String>(
    'relationship',
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
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<int> createdAtUs = GeneratedColumn<int>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    authUserId,
    displayName,
    relationship,
    role,
    active,
    revision,
    createdAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('auth_user_id')) {
      context.handle(
        _authUserIdMeta,
        authUserId.isAcceptableOrUnknown(
          data['auth_user_id']!,
          _authUserIdMeta,
        ),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('relationship')) {
      context.handle(
        _relationshipMeta,
        relationship.isAcceptableOrUnknown(
          data['relationship']!,
          _relationshipMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relationshipMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FamilyMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      authUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_user_id'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      relationship: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relationship'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_us'],
      )!,
    );
  }

  @override
  $FamilyMembersTable createAlias(String alias) {
    return $FamilyMembersTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class FamilyMember extends DataClass implements Insertable<FamilyMember> {
  final String id;
  final String familyId;
  final String? authUserId;
  final String displayName;
  final String relationship;
  final String role;
  final bool active;
  final int revision;
  final int createdAtUs;
  const FamilyMember({
    required this.id,
    required this.familyId,
    this.authUserId,
    required this.displayName,
    required this.relationship,
    required this.role,
    required this.active,
    required this.revision,
    required this.createdAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    if (!nullToAbsent || authUserId != null) {
      map['auth_user_id'] = Variable<String>(authUserId);
    }
    map['display_name'] = Variable<String>(displayName);
    map['relationship'] = Variable<String>(relationship);
    map['role'] = Variable<String>(role);
    map['active'] = Variable<bool>(active);
    map['revision'] = Variable<int>(revision);
    map['created_at_us'] = Variable<int>(createdAtUs);
    return map;
  }

  FamilyMembersCompanion toCompanion(bool nullToAbsent) {
    return FamilyMembersCompanion(
      id: Value(id),
      familyId: Value(familyId),
      authUserId: authUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(authUserId),
      displayName: Value(displayName),
      relationship: Value(relationship),
      role: Value(role),
      active: Value(active),
      revision: Value(revision),
      createdAtUs: Value(createdAtUs),
    );
  }

  factory FamilyMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyMember(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      authUserId: serializer.fromJson<String?>(json['authUserId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      relationship: serializer.fromJson<String>(json['relationship']),
      role: serializer.fromJson<String>(json['role']),
      active: serializer.fromJson<bool>(json['active']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAtUs: serializer.fromJson<int>(json['createdAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'authUserId': serializer.toJson<String?>(authUserId),
      'displayName': serializer.toJson<String>(displayName),
      'relationship': serializer.toJson<String>(relationship),
      'role': serializer.toJson<String>(role),
      'active': serializer.toJson<bool>(active),
      'revision': serializer.toJson<int>(revision),
      'createdAtUs': serializer.toJson<int>(createdAtUs),
    };
  }

  FamilyMember copyWith({
    String? id,
    String? familyId,
    Value<String?> authUserId = const Value.absent(),
    String? displayName,
    String? relationship,
    String? role,
    bool? active,
    int? revision,
    int? createdAtUs,
  }) => FamilyMember(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    authUserId: authUserId.present ? authUserId.value : this.authUserId,
    displayName: displayName ?? this.displayName,
    relationship: relationship ?? this.relationship,
    role: role ?? this.role,
    active: active ?? this.active,
    revision: revision ?? this.revision,
    createdAtUs: createdAtUs ?? this.createdAtUs,
  );
  FamilyMember copyWithCompanion(FamilyMembersCompanion data) {
    return FamilyMember(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      authUserId: data.authUserId.present
          ? data.authUserId.value
          : this.authUserId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      relationship: data.relationship.present
          ? data.relationship.value
          : this.relationship,
      role: data.role.present ? data.role.value : this.role,
      active: data.active.present ? data.active.value : this.active,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyMember(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('authUserId: $authUserId, ')
          ..write('displayName: $displayName, ')
          ..write('relationship: $relationship, ')
          ..write('role: $role, ')
          ..write('active: $active, ')
          ..write('revision: $revision, ')
          ..write('createdAtUs: $createdAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    familyId,
    authUserId,
    displayName,
    relationship,
    role,
    active,
    revision,
    createdAtUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyMember &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.authUserId == this.authUserId &&
          other.displayName == this.displayName &&
          other.relationship == this.relationship &&
          other.role == this.role &&
          other.active == this.active &&
          other.revision == this.revision &&
          other.createdAtUs == this.createdAtUs);
}

class FamilyMembersCompanion extends UpdateCompanion<FamilyMember> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<String?> authUserId;
  final Value<String> displayName;
  final Value<String> relationship;
  final Value<String> role;
  final Value<bool> active;
  final Value<int> revision;
  final Value<int> createdAtUs;
  final Value<int> rowid;
  const FamilyMembersCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.authUserId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.relationship = const Value.absent(),
    this.role = const Value.absent(),
    this.active = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyMembersCompanion.insert({
    required String id,
    required String familyId,
    this.authUserId = const Value.absent(),
    required String displayName,
    required String relationship,
    required String role,
    this.active = const Value.absent(),
    this.revision = const Value.absent(),
    required int createdAtUs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       displayName = Value(displayName),
       relationship = Value(relationship),
       role = Value(role),
       createdAtUs = Value(createdAtUs);
  static Insertable<FamilyMember> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? authUserId,
    Expression<String>? displayName,
    Expression<String>? relationship,
    Expression<String>? role,
    Expression<bool>? active,
    Expression<int>? revision,
    Expression<int>? createdAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (authUserId != null) 'auth_user_id': authUserId,
      if (displayName != null) 'display_name': displayName,
      if (relationship != null) 'relationship': relationship,
      if (role != null) 'role': role,
      if (active != null) 'active': active,
      if (revision != null) 'revision': revision,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<String?>? authUserId,
    Value<String>? displayName,
    Value<String>? relationship,
    Value<String>? role,
    Value<bool>? active,
    Value<int>? revision,
    Value<int>? createdAtUs,
    Value<int>? rowid,
  }) {
    return FamilyMembersCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      authUserId: authUserId ?? this.authUserId,
      displayName: displayName ?? this.displayName,
      relationship: relationship ?? this.relationship,
      role: role ?? this.role,
      active: active ?? this.active,
      revision: revision ?? this.revision,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (authUserId.present) {
      map['auth_user_id'] = Variable<String>(authUserId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (relationship.present) {
      map['relationship'] = Variable<String>(relationship.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<int>(createdAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyMembersCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('authUserId: $authUserId, ')
          ..write('displayName: $displayName, ')
          ..write('relationship: $relationship, ')
          ..write('role: $role, ')
          ..write('active: $active, ')
          ..write('revision: $revision, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultDevicesTable extends VaultDevices
    with TableInfo<$VaultDevicesTable, VaultDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  @override
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<int> createdAtUs = GeneratedColumn<int>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    memberId,
    state,
    createdAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultDevice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memberIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultDevice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_us'],
      )!,
    );
  }

  @override
  $VaultDevicesTable createAlias(String alias) {
    return $VaultDevicesTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class VaultDevice extends DataClass implements Insertable<VaultDevice> {
  final String id;
  final String familyId;
  final String memberId;
  final String state;
  final int createdAtUs;
  const VaultDevice({
    required this.id,
    required this.familyId,
    required this.memberId,
    required this.state,
    required this.createdAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['member_id'] = Variable<String>(memberId);
    map['state'] = Variable<String>(state);
    map['created_at_us'] = Variable<int>(createdAtUs);
    return map;
  }

  VaultDevicesCompanion toCompanion(bool nullToAbsent) {
    return VaultDevicesCompanion(
      id: Value(id),
      familyId: Value(familyId),
      memberId: Value(memberId),
      state: Value(state),
      createdAtUs: Value(createdAtUs),
    );
  }

  factory VaultDevice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultDevice(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      memberId: serializer.fromJson<String>(json['memberId']),
      state: serializer.fromJson<String>(json['state']),
      createdAtUs: serializer.fromJson<int>(json['createdAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'memberId': serializer.toJson<String>(memberId),
      'state': serializer.toJson<String>(state),
      'createdAtUs': serializer.toJson<int>(createdAtUs),
    };
  }

  VaultDevice copyWith({
    String? id,
    String? familyId,
    String? memberId,
    String? state,
    int? createdAtUs,
  }) => VaultDevice(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    memberId: memberId ?? this.memberId,
    state: state ?? this.state,
    createdAtUs: createdAtUs ?? this.createdAtUs,
  );
  VaultDevice copyWithCompanion(VaultDevicesCompanion data) {
    return VaultDevice(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      state: data.state.present ? data.state.value : this.state,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultDevice(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('memberId: $memberId, ')
          ..write('state: $state, ')
          ..write('createdAtUs: $createdAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, familyId, memberId, state, createdAtUs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultDevice &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.memberId == this.memberId &&
          other.state == this.state &&
          other.createdAtUs == this.createdAtUs);
}

class VaultDevicesCompanion extends UpdateCompanion<VaultDevice> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<String> memberId;
  final Value<String> state;
  final Value<int> createdAtUs;
  final Value<int> rowid;
  const VaultDevicesCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.memberId = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultDevicesCompanion.insert({
    required String id,
    required String familyId,
    required String memberId,
    required String state,
    required int createdAtUs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       memberId = Value(memberId),
       state = Value(state),
       createdAtUs = Value(createdAtUs);
  static Insertable<VaultDevice> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? memberId,
    Expression<String>? state,
    Expression<int>? createdAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (memberId != null) 'member_id': memberId,
      if (state != null) 'state': state,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultDevicesCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<String>? memberId,
    Value<String>? state,
    Value<int>? createdAtUs,
    Value<int>? rowid,
  }) {
    return VaultDevicesCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      memberId: memberId ?? this.memberId,
      state: state ?? this.state,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<int>(createdAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultDevicesCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('memberId: $memberId, ')
          ..write('state: $state, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerAccountsTable extends LedgerAccounts
    with TableInfo<$LedgerAccountsTable, LedgerAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES family_spaces (id)',
    ),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<int> createdAtUs = GeneratedColumn<int>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUs = GeneratedColumn<int>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUsMeta = const VerificationMeta(
    'deletedAtUs',
  );
  @override
  late final GeneratedColumn<int> deletedAtUs = GeneratedColumn<int>(
    'deleted_at_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtypeMeta = const VerificationMeta(
    'subtype',
  );
  @override
  late final GeneratedColumn<String> subtype = GeneratedColumn<String>(
    'subtype',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _systemAccountMeta = const VerificationMeta(
    'systemAccount',
  );
  @override
  late final GeneratedColumn<bool> systemAccount = GeneratedColumn<bool>(
    'system_account',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("system_account" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    revision,
    createdBy,
    updatedBy,
    createdAtUs,
    updatedAtUs,
    deletedAtUs,
    name,
    kind,
    subtype,
    currency,
    systemAccount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
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
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedByMeta);
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    if (data.containsKey('deleted_at_us')) {
      context.handle(
        _deletedAtUsMeta,
        deletedAtUs.isAcceptableOrUnknown(
          data['deleted_at_us']!,
          _deletedAtUsMeta,
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
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('subtype')) {
      context.handle(
        _subtypeMeta,
        subtype.isAcceptableOrUnknown(data['subtype']!, _subtypeMeta),
      );
    } else if (isInserting) {
      context.missing(_subtypeMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('system_account')) {
      context.handle(
        _systemAccountMeta,
        systemAccount.isAcceptableOrUnknown(
          data['system_account']!,
          _systemAccountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerAccount(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      )!,
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_us'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_us'],
      )!,
      deletedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_us'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      subtype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtype'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      systemAccount: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}system_account'],
      )!,
    );
  }

  @override
  $LedgerAccountsTable createAlias(String alias) {
    return $LedgerAccountsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class LedgerAccount extends DataClass implements Insertable<LedgerAccount> {
  final String id;
  final String familyId;
  final int revision;
  final String createdBy;
  final String updatedBy;
  final int createdAtUs;
  final int updatedAtUs;
  final int? deletedAtUs;
  final String name;
  final String kind;
  final String subtype;
  final String currency;
  final bool systemAccount;
  const LedgerAccount({
    required this.id,
    required this.familyId,
    required this.revision,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAtUs,
    required this.updatedAtUs,
    this.deletedAtUs,
    required this.name,
    required this.kind,
    required this.subtype,
    required this.currency,
    required this.systemAccount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['revision'] = Variable<int>(revision);
    map['created_by'] = Variable<String>(createdBy);
    map['updated_by'] = Variable<String>(updatedBy);
    map['created_at_us'] = Variable<int>(createdAtUs);
    map['updated_at_us'] = Variable<int>(updatedAtUs);
    if (!nullToAbsent || deletedAtUs != null) {
      map['deleted_at_us'] = Variable<int>(deletedAtUs);
    }
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['subtype'] = Variable<String>(subtype);
    map['currency'] = Variable<String>(currency);
    map['system_account'] = Variable<bool>(systemAccount);
    return map;
  }

  LedgerAccountsCompanion toCompanion(bool nullToAbsent) {
    return LedgerAccountsCompanion(
      id: Value(id),
      familyId: Value(familyId),
      revision: Value(revision),
      createdBy: Value(createdBy),
      updatedBy: Value(updatedBy),
      createdAtUs: Value(createdAtUs),
      updatedAtUs: Value(updatedAtUs),
      deletedAtUs: deletedAtUs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUs),
      name: Value(name),
      kind: Value(kind),
      subtype: Value(subtype),
      currency: Value(currency),
      systemAccount: Value(systemAccount),
    );
  }

  factory LedgerAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerAccount(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      revision: serializer.fromJson<int>(json['revision']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      updatedBy: serializer.fromJson<String>(json['updatedBy']),
      createdAtUs: serializer.fromJson<int>(json['createdAtUs']),
      updatedAtUs: serializer.fromJson<int>(json['updatedAtUs']),
      deletedAtUs: serializer.fromJson<int?>(json['deletedAtUs']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      subtype: serializer.fromJson<String>(json['subtype']),
      currency: serializer.fromJson<String>(json['currency']),
      systemAccount: serializer.fromJson<bool>(json['systemAccount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'revision': serializer.toJson<int>(revision),
      'createdBy': serializer.toJson<String>(createdBy),
      'updatedBy': serializer.toJson<String>(updatedBy),
      'createdAtUs': serializer.toJson<int>(createdAtUs),
      'updatedAtUs': serializer.toJson<int>(updatedAtUs),
      'deletedAtUs': serializer.toJson<int?>(deletedAtUs),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'subtype': serializer.toJson<String>(subtype),
      'currency': serializer.toJson<String>(currency),
      'systemAccount': serializer.toJson<bool>(systemAccount),
    };
  }

  LedgerAccount copyWith({
    String? id,
    String? familyId,
    int? revision,
    String? createdBy,
    String? updatedBy,
    int? createdAtUs,
    int? updatedAtUs,
    Value<int?> deletedAtUs = const Value.absent(),
    String? name,
    String? kind,
    String? subtype,
    String? currency,
    bool? systemAccount,
  }) => LedgerAccount(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    revision: revision ?? this.revision,
    createdBy: createdBy ?? this.createdBy,
    updatedBy: updatedBy ?? this.updatedBy,
    createdAtUs: createdAtUs ?? this.createdAtUs,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
    deletedAtUs: deletedAtUs.present ? deletedAtUs.value : this.deletedAtUs,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    subtype: subtype ?? this.subtype,
    currency: currency ?? this.currency,
    systemAccount: systemAccount ?? this.systemAccount,
  );
  LedgerAccount copyWithCompanion(LedgerAccountsCompanion data) {
    return LedgerAccount(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
      deletedAtUs: data.deletedAtUs.present
          ? data.deletedAtUs.value
          : this.deletedAtUs,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      subtype: data.subtype.present ? data.subtype.value : this.subtype,
      currency: data.currency.present ? data.currency.value : this.currency,
      systemAccount: data.systemAccount.present
          ? data.systemAccount.value
          : this.systemAccount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerAccount(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('revision: $revision, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('deletedAtUs: $deletedAtUs, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('subtype: $subtype, ')
          ..write('currency: $currency, ')
          ..write('systemAccount: $systemAccount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    familyId,
    revision,
    createdBy,
    updatedBy,
    createdAtUs,
    updatedAtUs,
    deletedAtUs,
    name,
    kind,
    subtype,
    currency,
    systemAccount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerAccount &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.revision == this.revision &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAtUs == this.createdAtUs &&
          other.updatedAtUs == this.updatedAtUs &&
          other.deletedAtUs == this.deletedAtUs &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.subtype == this.subtype &&
          other.currency == this.currency &&
          other.systemAccount == this.systemAccount);
}

class LedgerAccountsCompanion extends UpdateCompanion<LedgerAccount> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<int> revision;
  final Value<String> createdBy;
  final Value<String> updatedBy;
  final Value<int> createdAtUs;
  final Value<int> updatedAtUs;
  final Value<int?> deletedAtUs;
  final Value<String> name;
  final Value<String> kind;
  final Value<String> subtype;
  final Value<String> currency;
  final Value<bool> systemAccount;
  final Value<int> rowid;
  const LedgerAccountsCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
    this.deletedAtUs = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.subtype = const Value.absent(),
    this.currency = const Value.absent(),
    this.systemAccount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerAccountsCompanion.insert({
    required String id,
    required String familyId,
    this.revision = const Value.absent(),
    required String createdBy,
    required String updatedBy,
    required int createdAtUs,
    required int updatedAtUs,
    this.deletedAtUs = const Value.absent(),
    required String name,
    required String kind,
    required String subtype,
    this.currency = const Value.absent(),
    this.systemAccount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       createdBy = Value(createdBy),
       updatedBy = Value(updatedBy),
       createdAtUs = Value(createdAtUs),
       updatedAtUs = Value(updatedAtUs),
       name = Value(name),
       kind = Value(kind),
       subtype = Value(subtype);
  static Insertable<LedgerAccount> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<int>? revision,
    Expression<String>? createdBy,
    Expression<String>? updatedBy,
    Expression<int>? createdAtUs,
    Expression<int>? updatedAtUs,
    Expression<int>? deletedAtUs,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? subtype,
    Expression<String>? currency,
    Expression<bool>? systemAccount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (revision != null) 'revision': revision,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
      if (deletedAtUs != null) 'deleted_at_us': deletedAtUs,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (subtype != null) 'subtype': subtype,
      if (currency != null) 'currency': currency,
      if (systemAccount != null) 'system_account': systemAccount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerAccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<int>? revision,
    Value<String>? createdBy,
    Value<String>? updatedBy,
    Value<int>? createdAtUs,
    Value<int>? updatedAtUs,
    Value<int?>? deletedAtUs,
    Value<String>? name,
    Value<String>? kind,
    Value<String>? subtype,
    Value<String>? currency,
    Value<bool>? systemAccount,
    Value<int>? rowid,
  }) {
    return LedgerAccountsCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      revision: revision ?? this.revision,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
      deletedAtUs: deletedAtUs ?? this.deletedAtUs,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      subtype: subtype ?? this.subtype,
      currency: currency ?? this.currency,
      systemAccount: systemAccount ?? this.systemAccount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<int>(createdAtUs.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<int>(updatedAtUs.value);
    }
    if (deletedAtUs.present) {
      map['deleted_at_us'] = Variable<int>(deletedAtUs.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (subtype.present) {
      map['subtype'] = Variable<String>(subtype.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (systemAccount.present) {
      map['system_account'] = Variable<bool>(systemAccount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerAccountsCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('revision: $revision, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('deletedAtUs: $deletedAtUs, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('subtype: $subtype, ')
          ..write('currency: $currency, ')
          ..write('systemAccount: $systemAccount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerJournalsTable extends LedgerJournals
    with TableInfo<$LedgerJournalsTable, LedgerJournal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerJournalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES family_spaces (id)',
    ),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<int> createdAtUs = GeneratedColumn<int>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUs = GeneratedColumn<int>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUsMeta = const VerificationMeta(
    'deletedAtUs',
  );
  @override
  late final GeneratedColumn<int> deletedAtUs = GeneratedColumn<int>(
    'deleted_at_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredOnMeta = const VerificationMeta(
    'occurredOn',
  );
  @override
  late final GeneratedColumn<String> occurredOn = GeneratedColumn<String>(
    'occurred_on',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _reversesIdMeta = const VerificationMeta(
    'reversesId',
  );
  @override
  late final GeneratedColumn<String> reversesId = GeneratedColumn<String>(
    'reverses_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relatedEntityIdMeta = const VerificationMeta(
    'relatedEntityId',
  );
  @override
  late final GeneratedColumn<String> relatedEntityId = GeneratedColumn<String>(
    'related_entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    revision,
    createdBy,
    updatedBy,
    createdAtUs,
    updatedAtUs,
    deletedAtUs,
    kind,
    occurredOn,
    description,
    currency,
    status,
    reversesId,
    businessId,
    relatedEntityId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_journals';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerJournal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
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
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedByMeta);
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    if (data.containsKey('deleted_at_us')) {
      context.handle(
        _deletedAtUsMeta,
        deletedAtUs.isAcceptableOrUnknown(
          data['deleted_at_us']!,
          _deletedAtUsMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('occurred_on')) {
      context.handle(
        _occurredOnMeta,
        occurredOn.isAcceptableOrUnknown(data['occurred_on']!, _occurredOnMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredOnMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('reverses_id')) {
      context.handle(
        _reversesIdMeta,
        reversesId.isAcceptableOrUnknown(data['reverses_id']!, _reversesIdMeta),
      );
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    }
    if (data.containsKey('related_entity_id')) {
      context.handle(
        _relatedEntityIdMeta,
        relatedEntityId.isAcceptableOrUnknown(
          data['related_entity_id']!,
          _relatedEntityIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerJournal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerJournal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      )!,
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_us'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_us'],
      )!,
      deletedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_us'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      occurredOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_on'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      reversesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reverses_id'],
      ),
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      ),
      relatedEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_entity_id'],
      ),
    );
  }

  @override
  $LedgerJournalsTable createAlias(String alias) {
    return $LedgerJournalsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class LedgerJournal extends DataClass implements Insertable<LedgerJournal> {
  final String id;
  final String familyId;
  final int revision;
  final String createdBy;
  final String updatedBy;
  final int createdAtUs;
  final int updatedAtUs;
  final int? deletedAtUs;
  final String kind;
  final String occurredOn;
  final String description;
  final String currency;
  final String status;
  final String? reversesId;
  final String? businessId;
  final String? relatedEntityId;
  const LedgerJournal({
    required this.id,
    required this.familyId,
    required this.revision,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAtUs,
    required this.updatedAtUs,
    this.deletedAtUs,
    required this.kind,
    required this.occurredOn,
    required this.description,
    required this.currency,
    required this.status,
    this.reversesId,
    this.businessId,
    this.relatedEntityId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['revision'] = Variable<int>(revision);
    map['created_by'] = Variable<String>(createdBy);
    map['updated_by'] = Variable<String>(updatedBy);
    map['created_at_us'] = Variable<int>(createdAtUs);
    map['updated_at_us'] = Variable<int>(updatedAtUs);
    if (!nullToAbsent || deletedAtUs != null) {
      map['deleted_at_us'] = Variable<int>(deletedAtUs);
    }
    map['kind'] = Variable<String>(kind);
    map['occurred_on'] = Variable<String>(occurredOn);
    map['description'] = Variable<String>(description);
    map['currency'] = Variable<String>(currency);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || reversesId != null) {
      map['reverses_id'] = Variable<String>(reversesId);
    }
    if (!nullToAbsent || businessId != null) {
      map['business_id'] = Variable<String>(businessId);
    }
    if (!nullToAbsent || relatedEntityId != null) {
      map['related_entity_id'] = Variable<String>(relatedEntityId);
    }
    return map;
  }

  LedgerJournalsCompanion toCompanion(bool nullToAbsent) {
    return LedgerJournalsCompanion(
      id: Value(id),
      familyId: Value(familyId),
      revision: Value(revision),
      createdBy: Value(createdBy),
      updatedBy: Value(updatedBy),
      createdAtUs: Value(createdAtUs),
      updatedAtUs: Value(updatedAtUs),
      deletedAtUs: deletedAtUs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUs),
      kind: Value(kind),
      occurredOn: Value(occurredOn),
      description: Value(description),
      currency: Value(currency),
      status: Value(status),
      reversesId: reversesId == null && nullToAbsent
          ? const Value.absent()
          : Value(reversesId),
      businessId: businessId == null && nullToAbsent
          ? const Value.absent()
          : Value(businessId),
      relatedEntityId: relatedEntityId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedEntityId),
    );
  }

  factory LedgerJournal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerJournal(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      revision: serializer.fromJson<int>(json['revision']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      updatedBy: serializer.fromJson<String>(json['updatedBy']),
      createdAtUs: serializer.fromJson<int>(json['createdAtUs']),
      updatedAtUs: serializer.fromJson<int>(json['updatedAtUs']),
      deletedAtUs: serializer.fromJson<int?>(json['deletedAtUs']),
      kind: serializer.fromJson<String>(json['kind']),
      occurredOn: serializer.fromJson<String>(json['occurredOn']),
      description: serializer.fromJson<String>(json['description']),
      currency: serializer.fromJson<String>(json['currency']),
      status: serializer.fromJson<String>(json['status']),
      reversesId: serializer.fromJson<String?>(json['reversesId']),
      businessId: serializer.fromJson<String?>(json['businessId']),
      relatedEntityId: serializer.fromJson<String?>(json['relatedEntityId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'revision': serializer.toJson<int>(revision),
      'createdBy': serializer.toJson<String>(createdBy),
      'updatedBy': serializer.toJson<String>(updatedBy),
      'createdAtUs': serializer.toJson<int>(createdAtUs),
      'updatedAtUs': serializer.toJson<int>(updatedAtUs),
      'deletedAtUs': serializer.toJson<int?>(deletedAtUs),
      'kind': serializer.toJson<String>(kind),
      'occurredOn': serializer.toJson<String>(occurredOn),
      'description': serializer.toJson<String>(description),
      'currency': serializer.toJson<String>(currency),
      'status': serializer.toJson<String>(status),
      'reversesId': serializer.toJson<String?>(reversesId),
      'businessId': serializer.toJson<String?>(businessId),
      'relatedEntityId': serializer.toJson<String?>(relatedEntityId),
    };
  }

  LedgerJournal copyWith({
    String? id,
    String? familyId,
    int? revision,
    String? createdBy,
    String? updatedBy,
    int? createdAtUs,
    int? updatedAtUs,
    Value<int?> deletedAtUs = const Value.absent(),
    String? kind,
    String? occurredOn,
    String? description,
    String? currency,
    String? status,
    Value<String?> reversesId = const Value.absent(),
    Value<String?> businessId = const Value.absent(),
    Value<String?> relatedEntityId = const Value.absent(),
  }) => LedgerJournal(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    revision: revision ?? this.revision,
    createdBy: createdBy ?? this.createdBy,
    updatedBy: updatedBy ?? this.updatedBy,
    createdAtUs: createdAtUs ?? this.createdAtUs,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
    deletedAtUs: deletedAtUs.present ? deletedAtUs.value : this.deletedAtUs,
    kind: kind ?? this.kind,
    occurredOn: occurredOn ?? this.occurredOn,
    description: description ?? this.description,
    currency: currency ?? this.currency,
    status: status ?? this.status,
    reversesId: reversesId.present ? reversesId.value : this.reversesId,
    businessId: businessId.present ? businessId.value : this.businessId,
    relatedEntityId: relatedEntityId.present
        ? relatedEntityId.value
        : this.relatedEntityId,
  );
  LedgerJournal copyWithCompanion(LedgerJournalsCompanion data) {
    return LedgerJournal(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
      deletedAtUs: data.deletedAtUs.present
          ? data.deletedAtUs.value
          : this.deletedAtUs,
      kind: data.kind.present ? data.kind.value : this.kind,
      occurredOn: data.occurredOn.present
          ? data.occurredOn.value
          : this.occurredOn,
      description: data.description.present
          ? data.description.value
          : this.description,
      currency: data.currency.present ? data.currency.value : this.currency,
      status: data.status.present ? data.status.value : this.status,
      reversesId: data.reversesId.present
          ? data.reversesId.value
          : this.reversesId,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      relatedEntityId: data.relatedEntityId.present
          ? data.relatedEntityId.value
          : this.relatedEntityId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerJournal(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('revision: $revision, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('deletedAtUs: $deletedAtUs, ')
          ..write('kind: $kind, ')
          ..write('occurredOn: $occurredOn, ')
          ..write('description: $description, ')
          ..write('currency: $currency, ')
          ..write('status: $status, ')
          ..write('reversesId: $reversesId, ')
          ..write('businessId: $businessId, ')
          ..write('relatedEntityId: $relatedEntityId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    familyId,
    revision,
    createdBy,
    updatedBy,
    createdAtUs,
    updatedAtUs,
    deletedAtUs,
    kind,
    occurredOn,
    description,
    currency,
    status,
    reversesId,
    businessId,
    relatedEntityId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerJournal &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.revision == this.revision &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAtUs == this.createdAtUs &&
          other.updatedAtUs == this.updatedAtUs &&
          other.deletedAtUs == this.deletedAtUs &&
          other.kind == this.kind &&
          other.occurredOn == this.occurredOn &&
          other.description == this.description &&
          other.currency == this.currency &&
          other.status == this.status &&
          other.reversesId == this.reversesId &&
          other.businessId == this.businessId &&
          other.relatedEntityId == this.relatedEntityId);
}

class LedgerJournalsCompanion extends UpdateCompanion<LedgerJournal> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<int> revision;
  final Value<String> createdBy;
  final Value<String> updatedBy;
  final Value<int> createdAtUs;
  final Value<int> updatedAtUs;
  final Value<int?> deletedAtUs;
  final Value<String> kind;
  final Value<String> occurredOn;
  final Value<String> description;
  final Value<String> currency;
  final Value<String> status;
  final Value<String?> reversesId;
  final Value<String?> businessId;
  final Value<String?> relatedEntityId;
  final Value<int> rowid;
  const LedgerJournalsCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
    this.deletedAtUs = const Value.absent(),
    this.kind = const Value.absent(),
    this.occurredOn = const Value.absent(),
    this.description = const Value.absent(),
    this.currency = const Value.absent(),
    this.status = const Value.absent(),
    this.reversesId = const Value.absent(),
    this.businessId = const Value.absent(),
    this.relatedEntityId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerJournalsCompanion.insert({
    required String id,
    required String familyId,
    this.revision = const Value.absent(),
    required String createdBy,
    required String updatedBy,
    required int createdAtUs,
    required int updatedAtUs,
    this.deletedAtUs = const Value.absent(),
    required String kind,
    required String occurredOn,
    required String description,
    this.currency = const Value.absent(),
    this.status = const Value.absent(),
    this.reversesId = const Value.absent(),
    this.businessId = const Value.absent(),
    this.relatedEntityId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       createdBy = Value(createdBy),
       updatedBy = Value(updatedBy),
       createdAtUs = Value(createdAtUs),
       updatedAtUs = Value(updatedAtUs),
       kind = Value(kind),
       occurredOn = Value(occurredOn),
       description = Value(description);
  static Insertable<LedgerJournal> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<int>? revision,
    Expression<String>? createdBy,
    Expression<String>? updatedBy,
    Expression<int>? createdAtUs,
    Expression<int>? updatedAtUs,
    Expression<int>? deletedAtUs,
    Expression<String>? kind,
    Expression<String>? occurredOn,
    Expression<String>? description,
    Expression<String>? currency,
    Expression<String>? status,
    Expression<String>? reversesId,
    Expression<String>? businessId,
    Expression<String>? relatedEntityId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (revision != null) 'revision': revision,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
      if (deletedAtUs != null) 'deleted_at_us': deletedAtUs,
      if (kind != null) 'kind': kind,
      if (occurredOn != null) 'occurred_on': occurredOn,
      if (description != null) 'description': description,
      if (currency != null) 'currency': currency,
      if (status != null) 'status': status,
      if (reversesId != null) 'reverses_id': reversesId,
      if (businessId != null) 'business_id': businessId,
      if (relatedEntityId != null) 'related_entity_id': relatedEntityId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerJournalsCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<int>? revision,
    Value<String>? createdBy,
    Value<String>? updatedBy,
    Value<int>? createdAtUs,
    Value<int>? updatedAtUs,
    Value<int?>? deletedAtUs,
    Value<String>? kind,
    Value<String>? occurredOn,
    Value<String>? description,
    Value<String>? currency,
    Value<String>? status,
    Value<String?>? reversesId,
    Value<String?>? businessId,
    Value<String?>? relatedEntityId,
    Value<int>? rowid,
  }) {
    return LedgerJournalsCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      revision: revision ?? this.revision,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
      deletedAtUs: deletedAtUs ?? this.deletedAtUs,
      kind: kind ?? this.kind,
      occurredOn: occurredOn ?? this.occurredOn,
      description: description ?? this.description,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      reversesId: reversesId ?? this.reversesId,
      businessId: businessId ?? this.businessId,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<int>(createdAtUs.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<int>(updatedAtUs.value);
    }
    if (deletedAtUs.present) {
      map['deleted_at_us'] = Variable<int>(deletedAtUs.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (occurredOn.present) {
      map['occurred_on'] = Variable<String>(occurredOn.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (reversesId.present) {
      map['reverses_id'] = Variable<String>(reversesId.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (relatedEntityId.present) {
      map['related_entity_id'] = Variable<String>(relatedEntityId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerJournalsCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('revision: $revision, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('deletedAtUs: $deletedAtUs, ')
          ..write('kind: $kind, ')
          ..write('occurredOn: $occurredOn, ')
          ..write('description: $description, ')
          ..write('currency: $currency, ')
          ..write('status: $status, ')
          ..write('reversesId: $reversesId, ')
          ..write('businessId: $businessId, ')
          ..write('relatedEntityId: $relatedEntityId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerPostingsTable extends LedgerPostings
    with TableInfo<$LedgerPostingsTable, LedgerPosting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerPostingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _journalIdMeta = const VerificationMeta(
    'journalId',
  );
  @override
  late final GeneratedColumn<String> journalId = GeneratedColumn<String>(
    'journal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
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
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    journalId,
    accountId,
    position,
    amountMinor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_postings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerPosting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('journal_id')) {
      context.handle(
        _journalIdMeta,
        journalId.isAcceptableOrUnknown(data['journal_id']!, _journalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_journalIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerPosting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerPosting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      journalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}journal_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
    );
  }

  @override
  $LedgerPostingsTable createAlias(String alias) {
    return $LedgerPostingsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class LedgerPosting extends DataClass implements Insertable<LedgerPosting> {
  final String id;
  final String familyId;
  final String journalId;
  final String accountId;
  final int position;
  final int amountMinor;
  const LedgerPosting({
    required this.id,
    required this.familyId,
    required this.journalId,
    required this.accountId,
    required this.position,
    required this.amountMinor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['journal_id'] = Variable<String>(journalId);
    map['account_id'] = Variable<String>(accountId);
    map['position'] = Variable<int>(position);
    map['amount_minor'] = Variable<int>(amountMinor);
    return map;
  }

  LedgerPostingsCompanion toCompanion(bool nullToAbsent) {
    return LedgerPostingsCompanion(
      id: Value(id),
      familyId: Value(familyId),
      journalId: Value(journalId),
      accountId: Value(accountId),
      position: Value(position),
      amountMinor: Value(amountMinor),
    );
  }

  factory LedgerPosting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerPosting(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      journalId: serializer.fromJson<String>(json['journalId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      position: serializer.fromJson<int>(json['position']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'journalId': serializer.toJson<String>(journalId),
      'accountId': serializer.toJson<String>(accountId),
      'position': serializer.toJson<int>(position),
      'amountMinor': serializer.toJson<int>(amountMinor),
    };
  }

  LedgerPosting copyWith({
    String? id,
    String? familyId,
    String? journalId,
    String? accountId,
    int? position,
    int? amountMinor,
  }) => LedgerPosting(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    journalId: journalId ?? this.journalId,
    accountId: accountId ?? this.accountId,
    position: position ?? this.position,
    amountMinor: amountMinor ?? this.amountMinor,
  );
  LedgerPosting copyWithCompanion(LedgerPostingsCompanion data) {
    return LedgerPosting(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      journalId: data.journalId.present ? data.journalId.value : this.journalId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      position: data.position.present ? data.position.value : this.position,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerPosting(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('journalId: $journalId, ')
          ..write('accountId: $accountId, ')
          ..write('position: $position, ')
          ..write('amountMinor: $amountMinor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, familyId, journalId, accountId, position, amountMinor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerPosting &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.journalId == this.journalId &&
          other.accountId == this.accountId &&
          other.position == this.position &&
          other.amountMinor == this.amountMinor);
}

class LedgerPostingsCompanion extends UpdateCompanion<LedgerPosting> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<String> journalId;
  final Value<String> accountId;
  final Value<int> position;
  final Value<int> amountMinor;
  final Value<int> rowid;
  const LedgerPostingsCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.journalId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.position = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerPostingsCompanion.insert({
    required String id,
    required String familyId,
    required String journalId,
    required String accountId,
    required int position,
    required int amountMinor,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       journalId = Value(journalId),
       accountId = Value(accountId),
       position = Value(position),
       amountMinor = Value(amountMinor);
  static Insertable<LedgerPosting> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? journalId,
    Expression<String>? accountId,
    Expression<int>? position,
    Expression<int>? amountMinor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (journalId != null) 'journal_id': journalId,
      if (accountId != null) 'account_id': accountId,
      if (position != null) 'position': position,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerPostingsCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<String>? journalId,
    Value<String>? accountId,
    Value<int>? position,
    Value<int>? amountMinor,
    Value<int>? rowid,
  }) {
    return LedgerPostingsCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      journalId: journalId ?? this.journalId,
      accountId: accountId ?? this.accountId,
      position: position ?? this.position,
      amountMinor: amountMinor ?? this.amountMinor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (journalId.present) {
      map['journal_id'] = Variable<String>(journalId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerPostingsCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('journalId: $journalId, ')
          ..write('accountId: $accountId, ')
          ..write('position: $position, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAuditEventsTable extends LocalAuditEvents
    with TableInfo<$LocalAuditEventsTable, LocalAuditEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAuditEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
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
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeJsonMeta = const VerificationMeta(
    'beforeJson',
  );
  @override
  late final GeneratedColumn<String> beforeJson = GeneratedColumn<String>(
    'before_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _afterJsonMeta = const VerificationMeta(
    'afterJson',
  );
  @override
  late final GeneratedColumn<String> afterJson = GeneratedColumn<String>(
    'after_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<int> createdAtUs = GeneratedColumn<int>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    actorId,
    deviceId,
    operationId,
    entityType,
    entityId,
    action,
    beforeJson,
    afterJson,
    createdAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_audit_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAuditEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_actorIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
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
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('before_json')) {
      context.handle(
        _beforeJsonMeta,
        beforeJson.isAcceptableOrUnknown(data['before_json']!, _beforeJsonMeta),
      );
    }
    if (data.containsKey('after_json')) {
      context.handle(
        _afterJsonMeta,
        afterJson.isAcceptableOrUnknown(data['after_json']!, _afterJsonMeta),
      );
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAuditEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAuditEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      beforeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_json'],
      ),
      afterJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_json'],
      ),
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_us'],
      )!,
    );
  }

  @override
  $LocalAuditEventsTable createAlias(String alias) {
    return $LocalAuditEventsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class LocalAuditEvent extends DataClass implements Insertable<LocalAuditEvent> {
  final String id;
  final String familyId;
  final String actorId;
  final String deviceId;
  final String operationId;
  final String entityType;
  final String entityId;
  final String action;
  final String? beforeJson;
  final String? afterJson;
  final int createdAtUs;
  const LocalAuditEvent({
    required this.id,
    required this.familyId,
    required this.actorId,
    required this.deviceId,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.beforeJson,
    this.afterJson,
    required this.createdAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['actor_id'] = Variable<String>(actorId);
    map['device_id'] = Variable<String>(deviceId);
    map['operation_id'] = Variable<String>(operationId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || beforeJson != null) {
      map['before_json'] = Variable<String>(beforeJson);
    }
    if (!nullToAbsent || afterJson != null) {
      map['after_json'] = Variable<String>(afterJson);
    }
    map['created_at_us'] = Variable<int>(createdAtUs);
    return map;
  }

  LocalAuditEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalAuditEventsCompanion(
      id: Value(id),
      familyId: Value(familyId),
      actorId: Value(actorId),
      deviceId: Value(deviceId),
      operationId: Value(operationId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      action: Value(action),
      beforeJson: beforeJson == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeJson),
      afterJson: afterJson == null && nullToAbsent
          ? const Value.absent()
          : Value(afterJson),
      createdAtUs: Value(createdAtUs),
    );
  }

  factory LocalAuditEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAuditEvent(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      actorId: serializer.fromJson<String>(json['actorId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      action: serializer.fromJson<String>(json['action']),
      beforeJson: serializer.fromJson<String?>(json['beforeJson']),
      afterJson: serializer.fromJson<String?>(json['afterJson']),
      createdAtUs: serializer.fromJson<int>(json['createdAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'actorId': serializer.toJson<String>(actorId),
      'deviceId': serializer.toJson<String>(deviceId),
      'operationId': serializer.toJson<String>(operationId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'action': serializer.toJson<String>(action),
      'beforeJson': serializer.toJson<String?>(beforeJson),
      'afterJson': serializer.toJson<String?>(afterJson),
      'createdAtUs': serializer.toJson<int>(createdAtUs),
    };
  }

  LocalAuditEvent copyWith({
    String? id,
    String? familyId,
    String? actorId,
    String? deviceId,
    String? operationId,
    String? entityType,
    String? entityId,
    String? action,
    Value<String?> beforeJson = const Value.absent(),
    Value<String?> afterJson = const Value.absent(),
    int? createdAtUs,
  }) => LocalAuditEvent(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    actorId: actorId ?? this.actorId,
    deviceId: deviceId ?? this.deviceId,
    operationId: operationId ?? this.operationId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    action: action ?? this.action,
    beforeJson: beforeJson.present ? beforeJson.value : this.beforeJson,
    afterJson: afterJson.present ? afterJson.value : this.afterJson,
    createdAtUs: createdAtUs ?? this.createdAtUs,
  );
  LocalAuditEvent copyWithCompanion(LocalAuditEventsCompanion data) {
    return LocalAuditEvent(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      action: data.action.present ? data.action.value : this.action,
      beforeJson: data.beforeJson.present
          ? data.beforeJson.value
          : this.beforeJson,
      afterJson: data.afterJson.present ? data.afterJson.value : this.afterJson,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAuditEvent(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('actorId: $actorId, ')
          ..write('deviceId: $deviceId, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('afterJson: $afterJson, ')
          ..write('createdAtUs: $createdAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    familyId,
    actorId,
    deviceId,
    operationId,
    entityType,
    entityId,
    action,
    beforeJson,
    afterJson,
    createdAtUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAuditEvent &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.actorId == this.actorId &&
          other.deviceId == this.deviceId &&
          other.operationId == this.operationId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.action == this.action &&
          other.beforeJson == this.beforeJson &&
          other.afterJson == this.afterJson &&
          other.createdAtUs == this.createdAtUs);
}

class LocalAuditEventsCompanion extends UpdateCompanion<LocalAuditEvent> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<String> actorId;
  final Value<String> deviceId;
  final Value<String> operationId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> action;
  final Value<String?> beforeJson;
  final Value<String?> afterJson;
  final Value<int> createdAtUs;
  final Value<int> rowid;
  const LocalAuditEventsCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.actorId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.action = const Value.absent(),
    this.beforeJson = const Value.absent(),
    this.afterJson = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAuditEventsCompanion.insert({
    required String id,
    required String familyId,
    required String actorId,
    required String deviceId,
    required String operationId,
    required String entityType,
    required String entityId,
    required String action,
    this.beforeJson = const Value.absent(),
    this.afterJson = const Value.absent(),
    required int createdAtUs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       actorId = Value(actorId),
       deviceId = Value(deviceId),
       operationId = Value(operationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       action = Value(action),
       createdAtUs = Value(createdAtUs);
  static Insertable<LocalAuditEvent> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? actorId,
    Expression<String>? deviceId,
    Expression<String>? operationId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? action,
    Expression<String>? beforeJson,
    Expression<String>? afterJson,
    Expression<int>? createdAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (actorId != null) 'actor_id': actorId,
      if (deviceId != null) 'device_id': deviceId,
      if (operationId != null) 'operation_id': operationId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (action != null) 'action': action,
      if (beforeJson != null) 'before_json': beforeJson,
      if (afterJson != null) 'after_json': afterJson,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAuditEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<String>? actorId,
    Value<String>? deviceId,
    Value<String>? operationId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? action,
    Value<String?>? beforeJson,
    Value<String?>? afterJson,
    Value<int>? createdAtUs,
    Value<int>? rowid,
  }) {
    return LocalAuditEventsCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      actorId: actorId ?? this.actorId,
      deviceId: deviceId ?? this.deviceId,
      operationId: operationId ?? this.operationId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      beforeJson: beforeJson ?? this.beforeJson,
      afterJson: afterJson ?? this.afterJson,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (beforeJson.present) {
      map['before_json'] = Variable<String>(beforeJson.value);
    }
    if (afterJson.present) {
      map['after_json'] = Variable<String>(afterJson.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<int>(createdAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAuditEventsCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('actorId: $actorId, ')
          ..write('deviceId: $deviceId, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('afterJson: $afterJson, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MonthlyBudgetsTable extends MonthlyBudgets
    with TableInfo<$MonthlyBudgetsTable, MonthlyBudget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonthlyBudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES family_spaces (id)',
    ),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<int> createdAtUs = GeneratedColumn<int>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUs = GeneratedColumn<int>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUsMeta = const VerificationMeta(
    'deletedAtUs',
  );
  @override
  late final GeneratedColumn<int> deletedAtUs = GeneratedColumn<int>(
    'deleted_at_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    revision,
    createdBy,
    updatedBy,
    createdAtUs,
    updatedAtUs,
    deletedAtUs,
    accountId,
    month,
    amountMinor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'monthly_budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<MonthlyBudget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
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
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedByMeta);
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    if (data.containsKey('deleted_at_us')) {
      context.handle(
        _deletedAtUsMeta,
        deletedAtUs.isAcceptableOrUnknown(
          data['deleted_at_us']!,
          _deletedAtUsMeta,
        ),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MonthlyBudget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonthlyBudget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      )!,
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_us'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_us'],
      )!,
      deletedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_us'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
    );
  }

  @override
  $MonthlyBudgetsTable createAlias(String alias) {
    return $MonthlyBudgetsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class MonthlyBudget extends DataClass implements Insertable<MonthlyBudget> {
  final String id;
  final String familyId;
  final int revision;
  final String createdBy;
  final String updatedBy;
  final int createdAtUs;
  final int updatedAtUs;
  final int? deletedAtUs;
  final String accountId;
  final String month;
  final int amountMinor;
  const MonthlyBudget({
    required this.id,
    required this.familyId,
    required this.revision,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAtUs,
    required this.updatedAtUs,
    this.deletedAtUs,
    required this.accountId,
    required this.month,
    required this.amountMinor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['revision'] = Variable<int>(revision);
    map['created_by'] = Variable<String>(createdBy);
    map['updated_by'] = Variable<String>(updatedBy);
    map['created_at_us'] = Variable<int>(createdAtUs);
    map['updated_at_us'] = Variable<int>(updatedAtUs);
    if (!nullToAbsent || deletedAtUs != null) {
      map['deleted_at_us'] = Variable<int>(deletedAtUs);
    }
    map['account_id'] = Variable<String>(accountId);
    map['month'] = Variable<String>(month);
    map['amount_minor'] = Variable<int>(amountMinor);
    return map;
  }

  MonthlyBudgetsCompanion toCompanion(bool nullToAbsent) {
    return MonthlyBudgetsCompanion(
      id: Value(id),
      familyId: Value(familyId),
      revision: Value(revision),
      createdBy: Value(createdBy),
      updatedBy: Value(updatedBy),
      createdAtUs: Value(createdAtUs),
      updatedAtUs: Value(updatedAtUs),
      deletedAtUs: deletedAtUs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUs),
      accountId: Value(accountId),
      month: Value(month),
      amountMinor: Value(amountMinor),
    );
  }

  factory MonthlyBudget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonthlyBudget(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      revision: serializer.fromJson<int>(json['revision']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      updatedBy: serializer.fromJson<String>(json['updatedBy']),
      createdAtUs: serializer.fromJson<int>(json['createdAtUs']),
      updatedAtUs: serializer.fromJson<int>(json['updatedAtUs']),
      deletedAtUs: serializer.fromJson<int?>(json['deletedAtUs']),
      accountId: serializer.fromJson<String>(json['accountId']),
      month: serializer.fromJson<String>(json['month']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'revision': serializer.toJson<int>(revision),
      'createdBy': serializer.toJson<String>(createdBy),
      'updatedBy': serializer.toJson<String>(updatedBy),
      'createdAtUs': serializer.toJson<int>(createdAtUs),
      'updatedAtUs': serializer.toJson<int>(updatedAtUs),
      'deletedAtUs': serializer.toJson<int?>(deletedAtUs),
      'accountId': serializer.toJson<String>(accountId),
      'month': serializer.toJson<String>(month),
      'amountMinor': serializer.toJson<int>(amountMinor),
    };
  }

  MonthlyBudget copyWith({
    String? id,
    String? familyId,
    int? revision,
    String? createdBy,
    String? updatedBy,
    int? createdAtUs,
    int? updatedAtUs,
    Value<int?> deletedAtUs = const Value.absent(),
    String? accountId,
    String? month,
    int? amountMinor,
  }) => MonthlyBudget(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    revision: revision ?? this.revision,
    createdBy: createdBy ?? this.createdBy,
    updatedBy: updatedBy ?? this.updatedBy,
    createdAtUs: createdAtUs ?? this.createdAtUs,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
    deletedAtUs: deletedAtUs.present ? deletedAtUs.value : this.deletedAtUs,
    accountId: accountId ?? this.accountId,
    month: month ?? this.month,
    amountMinor: amountMinor ?? this.amountMinor,
  );
  MonthlyBudget copyWithCompanion(MonthlyBudgetsCompanion data) {
    return MonthlyBudget(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
      deletedAtUs: data.deletedAtUs.present
          ? data.deletedAtUs.value
          : this.deletedAtUs,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      month: data.month.present ? data.month.value : this.month,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonthlyBudget(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('revision: $revision, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('deletedAtUs: $deletedAtUs, ')
          ..write('accountId: $accountId, ')
          ..write('month: $month, ')
          ..write('amountMinor: $amountMinor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    familyId,
    revision,
    createdBy,
    updatedBy,
    createdAtUs,
    updatedAtUs,
    deletedAtUs,
    accountId,
    month,
    amountMinor,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthlyBudget &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.revision == this.revision &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAtUs == this.createdAtUs &&
          other.updatedAtUs == this.updatedAtUs &&
          other.deletedAtUs == this.deletedAtUs &&
          other.accountId == this.accountId &&
          other.month == this.month &&
          other.amountMinor == this.amountMinor);
}

class MonthlyBudgetsCompanion extends UpdateCompanion<MonthlyBudget> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<int> revision;
  final Value<String> createdBy;
  final Value<String> updatedBy;
  final Value<int> createdAtUs;
  final Value<int> updatedAtUs;
  final Value<int?> deletedAtUs;
  final Value<String> accountId;
  final Value<String> month;
  final Value<int> amountMinor;
  final Value<int> rowid;
  const MonthlyBudgetsCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
    this.deletedAtUs = const Value.absent(),
    this.accountId = const Value.absent(),
    this.month = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MonthlyBudgetsCompanion.insert({
    required String id,
    required String familyId,
    this.revision = const Value.absent(),
    required String createdBy,
    required String updatedBy,
    required int createdAtUs,
    required int updatedAtUs,
    this.deletedAtUs = const Value.absent(),
    required String accountId,
    required String month,
    required int amountMinor,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       createdBy = Value(createdBy),
       updatedBy = Value(updatedBy),
       createdAtUs = Value(createdAtUs),
       updatedAtUs = Value(updatedAtUs),
       accountId = Value(accountId),
       month = Value(month),
       amountMinor = Value(amountMinor);
  static Insertable<MonthlyBudget> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<int>? revision,
    Expression<String>? createdBy,
    Expression<String>? updatedBy,
    Expression<int>? createdAtUs,
    Expression<int>? updatedAtUs,
    Expression<int>? deletedAtUs,
    Expression<String>? accountId,
    Expression<String>? month,
    Expression<int>? amountMinor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (revision != null) 'revision': revision,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
      if (deletedAtUs != null) 'deleted_at_us': deletedAtUs,
      if (accountId != null) 'account_id': accountId,
      if (month != null) 'month': month,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MonthlyBudgetsCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<int>? revision,
    Value<String>? createdBy,
    Value<String>? updatedBy,
    Value<int>? createdAtUs,
    Value<int>? updatedAtUs,
    Value<int?>? deletedAtUs,
    Value<String>? accountId,
    Value<String>? month,
    Value<int>? amountMinor,
    Value<int>? rowid,
  }) {
    return MonthlyBudgetsCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      revision: revision ?? this.revision,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
      deletedAtUs: deletedAtUs ?? this.deletedAtUs,
      accountId: accountId ?? this.accountId,
      month: month ?? this.month,
      amountMinor: amountMinor ?? this.amountMinor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<int>(createdAtUs.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<int>(updatedAtUs.value);
    }
    if (deletedAtUs.present) {
      map['deleted_at_us'] = Variable<int>(deletedAtUs.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonthlyBudgetsCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('revision: $revision, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('deletedAtUs: $deletedAtUs, ')
          ..write('accountId: $accountId, ')
          ..write('month: $month, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReconciliationChecksTable extends ReconciliationChecks
    with TableInfo<$ReconciliationChecksTable, ReconciliationCheck> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReconciliationChecksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES family_spaces (id)',
    ),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<int> createdAtUs = GeneratedColumn<int>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<int> updatedAtUs = GeneratedColumn<int>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUsMeta = const VerificationMeta(
    'deletedAtUs',
  );
  @override
  late final GeneratedColumn<int> deletedAtUs = GeneratedColumn<int>(
    'deleted_at_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statementDateMeta = const VerificationMeta(
    'statementDate',
  );
  @override
  late final GeneratedColumn<String> statementDate = GeneratedColumn<String>(
    'statement_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statementMinorMeta = const VerificationMeta(
    'statementMinor',
  );
  @override
  late final GeneratedColumn<int> statementMinor = GeneratedColumn<int>(
    'statement_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ledgerMinorMeta = const VerificationMeta(
    'ledgerMinor',
  );
  @override
  late final GeneratedColumn<int> ledgerMinor = GeneratedColumn<int>(
    'ledger_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    revision,
    createdBy,
    updatedBy,
    createdAtUs,
    updatedAtUs,
    deletedAtUs,
    accountId,
    statementDate,
    statementMinor,
    ledgerMinor,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reconciliation_checks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReconciliationCheck> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
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
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedByMeta);
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    if (data.containsKey('deleted_at_us')) {
      context.handle(
        _deletedAtUsMeta,
        deletedAtUs.isAcceptableOrUnknown(
          data['deleted_at_us']!,
          _deletedAtUsMeta,
        ),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('statement_date')) {
      context.handle(
        _statementDateMeta,
        statementDate.isAcceptableOrUnknown(
          data['statement_date']!,
          _statementDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_statementDateMeta);
    }
    if (data.containsKey('statement_minor')) {
      context.handle(
        _statementMinorMeta,
        statementMinor.isAcceptableOrUnknown(
          data['statement_minor']!,
          _statementMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_statementMinorMeta);
    }
    if (data.containsKey('ledger_minor')) {
      context.handle(
        _ledgerMinorMeta,
        ledgerMinor.isAcceptableOrUnknown(
          data['ledger_minor']!,
          _ledgerMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ledgerMinorMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReconciliationCheck map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReconciliationCheck(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      )!,
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_us'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_us'],
      )!,
      deletedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_us'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      statementDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statement_date'],
      )!,
      statementMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}statement_minor'],
      )!,
      ledgerMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ledger_minor'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
    );
  }

  @override
  $ReconciliationChecksTable createAlias(String alias) {
    return $ReconciliationChecksTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class ReconciliationCheck extends DataClass
    implements Insertable<ReconciliationCheck> {
  final String id;
  final String familyId;
  final int revision;
  final String createdBy;
  final String updatedBy;
  final int createdAtUs;
  final int updatedAtUs;
  final int? deletedAtUs;
  final String accountId;
  final String statementDate;
  final int statementMinor;
  final int ledgerMinor;
  final String notes;
  const ReconciliationCheck({
    required this.id,
    required this.familyId,
    required this.revision,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAtUs,
    required this.updatedAtUs,
    this.deletedAtUs,
    required this.accountId,
    required this.statementDate,
    required this.statementMinor,
    required this.ledgerMinor,
    required this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['revision'] = Variable<int>(revision);
    map['created_by'] = Variable<String>(createdBy);
    map['updated_by'] = Variable<String>(updatedBy);
    map['created_at_us'] = Variable<int>(createdAtUs);
    map['updated_at_us'] = Variable<int>(updatedAtUs);
    if (!nullToAbsent || deletedAtUs != null) {
      map['deleted_at_us'] = Variable<int>(deletedAtUs);
    }
    map['account_id'] = Variable<String>(accountId);
    map['statement_date'] = Variable<String>(statementDate);
    map['statement_minor'] = Variable<int>(statementMinor);
    map['ledger_minor'] = Variable<int>(ledgerMinor);
    map['notes'] = Variable<String>(notes);
    return map;
  }

  ReconciliationChecksCompanion toCompanion(bool nullToAbsent) {
    return ReconciliationChecksCompanion(
      id: Value(id),
      familyId: Value(familyId),
      revision: Value(revision),
      createdBy: Value(createdBy),
      updatedBy: Value(updatedBy),
      createdAtUs: Value(createdAtUs),
      updatedAtUs: Value(updatedAtUs),
      deletedAtUs: deletedAtUs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUs),
      accountId: Value(accountId),
      statementDate: Value(statementDate),
      statementMinor: Value(statementMinor),
      ledgerMinor: Value(ledgerMinor),
      notes: Value(notes),
    );
  }

  factory ReconciliationCheck.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReconciliationCheck(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      revision: serializer.fromJson<int>(json['revision']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      updatedBy: serializer.fromJson<String>(json['updatedBy']),
      createdAtUs: serializer.fromJson<int>(json['createdAtUs']),
      updatedAtUs: serializer.fromJson<int>(json['updatedAtUs']),
      deletedAtUs: serializer.fromJson<int?>(json['deletedAtUs']),
      accountId: serializer.fromJson<String>(json['accountId']),
      statementDate: serializer.fromJson<String>(json['statementDate']),
      statementMinor: serializer.fromJson<int>(json['statementMinor']),
      ledgerMinor: serializer.fromJson<int>(json['ledgerMinor']),
      notes: serializer.fromJson<String>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'revision': serializer.toJson<int>(revision),
      'createdBy': serializer.toJson<String>(createdBy),
      'updatedBy': serializer.toJson<String>(updatedBy),
      'createdAtUs': serializer.toJson<int>(createdAtUs),
      'updatedAtUs': serializer.toJson<int>(updatedAtUs),
      'deletedAtUs': serializer.toJson<int?>(deletedAtUs),
      'accountId': serializer.toJson<String>(accountId),
      'statementDate': serializer.toJson<String>(statementDate),
      'statementMinor': serializer.toJson<int>(statementMinor),
      'ledgerMinor': serializer.toJson<int>(ledgerMinor),
      'notes': serializer.toJson<String>(notes),
    };
  }

  ReconciliationCheck copyWith({
    String? id,
    String? familyId,
    int? revision,
    String? createdBy,
    String? updatedBy,
    int? createdAtUs,
    int? updatedAtUs,
    Value<int?> deletedAtUs = const Value.absent(),
    String? accountId,
    String? statementDate,
    int? statementMinor,
    int? ledgerMinor,
    String? notes,
  }) => ReconciliationCheck(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    revision: revision ?? this.revision,
    createdBy: createdBy ?? this.createdBy,
    updatedBy: updatedBy ?? this.updatedBy,
    createdAtUs: createdAtUs ?? this.createdAtUs,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
    deletedAtUs: deletedAtUs.present ? deletedAtUs.value : this.deletedAtUs,
    accountId: accountId ?? this.accountId,
    statementDate: statementDate ?? this.statementDate,
    statementMinor: statementMinor ?? this.statementMinor,
    ledgerMinor: ledgerMinor ?? this.ledgerMinor,
    notes: notes ?? this.notes,
  );
  ReconciliationCheck copyWithCompanion(ReconciliationChecksCompanion data) {
    return ReconciliationCheck(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
      deletedAtUs: data.deletedAtUs.present
          ? data.deletedAtUs.value
          : this.deletedAtUs,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      statementDate: data.statementDate.present
          ? data.statementDate.value
          : this.statementDate,
      statementMinor: data.statementMinor.present
          ? data.statementMinor.value
          : this.statementMinor,
      ledgerMinor: data.ledgerMinor.present
          ? data.ledgerMinor.value
          : this.ledgerMinor,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReconciliationCheck(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('revision: $revision, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('deletedAtUs: $deletedAtUs, ')
          ..write('accountId: $accountId, ')
          ..write('statementDate: $statementDate, ')
          ..write('statementMinor: $statementMinor, ')
          ..write('ledgerMinor: $ledgerMinor, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    familyId,
    revision,
    createdBy,
    updatedBy,
    createdAtUs,
    updatedAtUs,
    deletedAtUs,
    accountId,
    statementDate,
    statementMinor,
    ledgerMinor,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReconciliationCheck &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.revision == this.revision &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAtUs == this.createdAtUs &&
          other.updatedAtUs == this.updatedAtUs &&
          other.deletedAtUs == this.deletedAtUs &&
          other.accountId == this.accountId &&
          other.statementDate == this.statementDate &&
          other.statementMinor == this.statementMinor &&
          other.ledgerMinor == this.ledgerMinor &&
          other.notes == this.notes);
}

class ReconciliationChecksCompanion
    extends UpdateCompanion<ReconciliationCheck> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<int> revision;
  final Value<String> createdBy;
  final Value<String> updatedBy;
  final Value<int> createdAtUs;
  final Value<int> updatedAtUs;
  final Value<int?> deletedAtUs;
  final Value<String> accountId;
  final Value<String> statementDate;
  final Value<int> statementMinor;
  final Value<int> ledgerMinor;
  final Value<String> notes;
  final Value<int> rowid;
  const ReconciliationChecksCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
    this.deletedAtUs = const Value.absent(),
    this.accountId = const Value.absent(),
    this.statementDate = const Value.absent(),
    this.statementMinor = const Value.absent(),
    this.ledgerMinor = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReconciliationChecksCompanion.insert({
    required String id,
    required String familyId,
    this.revision = const Value.absent(),
    required String createdBy,
    required String updatedBy,
    required int createdAtUs,
    required int updatedAtUs,
    this.deletedAtUs = const Value.absent(),
    required String accountId,
    required String statementDate,
    required int statementMinor,
    required int ledgerMinor,
    required String notes,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       createdBy = Value(createdBy),
       updatedBy = Value(updatedBy),
       createdAtUs = Value(createdAtUs),
       updatedAtUs = Value(updatedAtUs),
       accountId = Value(accountId),
       statementDate = Value(statementDate),
       statementMinor = Value(statementMinor),
       ledgerMinor = Value(ledgerMinor),
       notes = Value(notes);
  static Insertable<ReconciliationCheck> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<int>? revision,
    Expression<String>? createdBy,
    Expression<String>? updatedBy,
    Expression<int>? createdAtUs,
    Expression<int>? updatedAtUs,
    Expression<int>? deletedAtUs,
    Expression<String>? accountId,
    Expression<String>? statementDate,
    Expression<int>? statementMinor,
    Expression<int>? ledgerMinor,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (revision != null) 'revision': revision,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
      if (deletedAtUs != null) 'deleted_at_us': deletedAtUs,
      if (accountId != null) 'account_id': accountId,
      if (statementDate != null) 'statement_date': statementDate,
      if (statementMinor != null) 'statement_minor': statementMinor,
      if (ledgerMinor != null) 'ledger_minor': ledgerMinor,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReconciliationChecksCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<int>? revision,
    Value<String>? createdBy,
    Value<String>? updatedBy,
    Value<int>? createdAtUs,
    Value<int>? updatedAtUs,
    Value<int?>? deletedAtUs,
    Value<String>? accountId,
    Value<String>? statementDate,
    Value<int>? statementMinor,
    Value<int>? ledgerMinor,
    Value<String>? notes,
    Value<int>? rowid,
  }) {
    return ReconciliationChecksCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      revision: revision ?? this.revision,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
      deletedAtUs: deletedAtUs ?? this.deletedAtUs,
      accountId: accountId ?? this.accountId,
      statementDate: statementDate ?? this.statementDate,
      statementMinor: statementMinor ?? this.statementMinor,
      ledgerMinor: ledgerMinor ?? this.ledgerMinor,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<int>(createdAtUs.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<int>(updatedAtUs.value);
    }
    if (deletedAtUs.present) {
      map['deleted_at_us'] = Variable<int>(deletedAtUs.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (statementDate.present) {
      map['statement_date'] = Variable<String>(statementDate.value);
    }
    if (statementMinor.present) {
      map['statement_minor'] = Variable<int>(statementMinor.value);
    }
    if (ledgerMinor.present) {
      map['ledger_minor'] = Variable<int>(ledgerMinor.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReconciliationChecksCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('revision: $revision, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('deletedAtUs: $deletedAtUs, ')
          ..write('accountId: $accountId, ')
          ..write('statementDate: $statementDate, ')
          ..write('statementMinor: $statementMinor, ')
          ..write('ledgerMinor: $ledgerMinor, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultPreferencesTable extends VaultPreferences
    with TableInfo<$VaultPreferencesTable, VaultPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultPreferencesTable(this.attachedDatabase, [this._alias]);
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
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultPreference> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  VaultPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultPreference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $VaultPreferencesTable createAlias(String alias) {
    return $VaultPreferencesTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class VaultPreference extends DataClass implements Insertable<VaultPreference> {
  final String key;
  final String value;
  const VaultPreference({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  VaultPreferencesCompanion toCompanion(bool nullToAbsent) {
    return VaultPreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory VaultPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultPreference(
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

  VaultPreference copyWith({String? key, String? value}) =>
      VaultPreference(key: key ?? this.key, value: value ?? this.value);
  VaultPreference copyWithCompanion(VaultPreferencesCompanion data) {
    return VaultPreference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultPreference(')
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
      (other is VaultPreference &&
          other.key == this.key &&
          other.value == this.value);
}

class VaultPreferencesCompanion extends UpdateCompanion<VaultPreference> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const VaultPreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultPreferencesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<VaultPreference> custom({
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

  VaultPreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return VaultPreferencesCompanion(
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
    return (StringBuffer('VaultPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PendingMutationsTable pendingMutations = $PendingMutationsTable(
    this,
  );
  late final $SyncCheckpointsTable syncCheckpoints = $SyncCheckpointsTable(
    this,
  );
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  late final $FamilySpacesTable familySpaces = $FamilySpacesTable(this);
  late final $FamilyMembersTable familyMembers = $FamilyMembersTable(this);
  late final $VaultDevicesTable vaultDevices = $VaultDevicesTable(this);
  late final $LedgerAccountsTable ledgerAccounts = $LedgerAccountsTable(this);
  late final $LedgerJournalsTable ledgerJournals = $LedgerJournalsTable(this);
  late final $LedgerPostingsTable ledgerPostings = $LedgerPostingsTable(this);
  late final $LocalAuditEventsTable localAuditEvents = $LocalAuditEventsTable(
    this,
  );
  late final $MonthlyBudgetsTable monthlyBudgets = $MonthlyBudgetsTable(this);
  late final $ReconciliationChecksTable reconciliationChecks =
      $ReconciliationChecksTable(this);
  late final $VaultPreferencesTable vaultPreferences = $VaultPreferencesTable(
    this,
  );
  late final Index pendingMutationsRetry = Index(
    'pending_mutations_retry',
    'CREATE INDEX pending_mutations_retry ON pending_mutations (state, next_attempt_at_us)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    pendingMutations,
    syncCheckpoints,
    syncConflicts,
    familySpaces,
    familyMembers,
    vaultDevices,
    ledgerAccounts,
    ledgerJournals,
    ledgerPostings,
    localAuditEvents,
    monthlyBudgets,
    reconciliationChecks,
    vaultPreferences,
    pendingMutationsRetry,
  ];
}

typedef $$PendingMutationsTableCreateCompanionBuilder =
    PendingMutationsCompanion Function({
      required String operationId,
      required String familyId,
      required String deviceId,
      required String entityType,
      required String entityId,
      required String mutationKind,
      required int baseRevision,
      required String payloadJson,
      required String payloadDigest,
      required int protocolVersion,
      Value<String> state,
      Value<int> attempts,
      required int createdAtUs,
      Value<int?> nextAttemptAtUs,
      Value<int?> leaseExpiresAtUs,
      Value<int?> acceptedRevision,
      Value<int> rowid,
    });
typedef $$PendingMutationsTableUpdateCompanionBuilder =
    PendingMutationsCompanion Function({
      Value<String> operationId,
      Value<String> familyId,
      Value<String> deviceId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> mutationKind,
      Value<int> baseRevision,
      Value<String> payloadJson,
      Value<String> payloadDigest,
      Value<int> protocolVersion,
      Value<String> state,
      Value<int> attempts,
      Value<int> createdAtUs,
      Value<int?> nextAttemptAtUs,
      Value<int?> leaseExpiresAtUs,
      Value<int?> acceptedRevision,
      Value<int> rowid,
    });

final class $$PendingMutationsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PendingMutationsTable, PendingMutation> {
  $$PendingMutationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SyncConflictsTable, List<SyncConflict>>
  _syncConflictsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.syncConflicts,
    aliasName: 'pending_mutations__operation_id__sync_conflicts__operation_id',
  );

  $$SyncConflictsTableProcessedTableManager get syncConflictsRefs {
    final manager = $$SyncConflictsTableTableManager($_db, $_db.syncConflicts)
        .filter(
          (f) => f.operationId.operationId.sqlEquals(
            $_itemColumn<String>('operation_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_syncConflictsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PendingMutationsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
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

  ColumnFilters<String> get mutationKind => $composableBuilder(
    column: $table.mutationKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadDigest => $composableBuilder(
    column: $table.payloadDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAtUs => $composableBuilder(
    column: $table.nextAttemptAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leaseExpiresAtUs => $composableBuilder(
    column: $table.leaseExpiresAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acceptedRevision => $composableBuilder(
    column: $table.acceptedRevision,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> syncConflictsRefs(
    Expression<bool> Function($$SyncConflictsTableFilterComposer f) f,
  ) {
    final $$SyncConflictsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.syncConflicts,
      getReferencedColumn: (t) => t.operationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncConflictsTableFilterComposer(
            $db: $db,
            $table: $db.syncConflicts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PendingMutationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
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

  ColumnOrderings<String> get mutationKind => $composableBuilder(
    column: $table.mutationKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadDigest => $composableBuilder(
    column: $table.payloadDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAtUs => $composableBuilder(
    column: $table.nextAttemptAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leaseExpiresAtUs => $composableBuilder(
    column: $table.leaseExpiresAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acceptedRevision => $composableBuilder(
    column: $table.acceptedRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingMutationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get mutationKind => $composableBuilder(
    column: $table.mutationKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadDigest => $composableBuilder(
    column: $table.payloadDigest,
    builder: (column) => column,
  );

  GeneratedColumn<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextAttemptAtUs => $composableBuilder(
    column: $table.nextAttemptAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get leaseExpiresAtUs => $composableBuilder(
    column: $table.leaseExpiresAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get acceptedRevision => $composableBuilder(
    column: $table.acceptedRevision,
    builder: (column) => column,
  );

  Expression<T> syncConflictsRefs<T extends Object>(
    Expression<T> Function($$SyncConflictsTableAnnotationComposer a) f,
  ) {
    final $$SyncConflictsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.syncConflicts,
      getReferencedColumn: (t) => t.operationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncConflictsTableAnnotationComposer(
            $db: $db,
            $table: $db.syncConflicts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PendingMutationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingMutationsTable,
          PendingMutation,
          $$PendingMutationsTableFilterComposer,
          $$PendingMutationsTableOrderingComposer,
          $$PendingMutationsTableAnnotationComposer,
          $$PendingMutationsTableCreateCompanionBuilder,
          $$PendingMutationsTableUpdateCompanionBuilder,
          (PendingMutation, $$PendingMutationsTableReferences),
          PendingMutation,
          PrefetchHooks Function({bool syncConflictsRefs})
        > {
  $$PendingMutationsTableTableManager(
    _$AppDatabase db,
    $PendingMutationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingMutationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingMutationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingMutationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> mutationKind = const Value.absent(),
                Value<int> baseRevision = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> payloadDigest = const Value.absent(),
                Value<int> protocolVersion = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> createdAtUs = const Value.absent(),
                Value<int?> nextAttemptAtUs = const Value.absent(),
                Value<int?> leaseExpiresAtUs = const Value.absent(),
                Value<int?> acceptedRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingMutationsCompanion(
                operationId: operationId,
                familyId: familyId,
                deviceId: deviceId,
                entityType: entityType,
                entityId: entityId,
                mutationKind: mutationKind,
                baseRevision: baseRevision,
                payloadJson: payloadJson,
                payloadDigest: payloadDigest,
                protocolVersion: protocolVersion,
                state: state,
                attempts: attempts,
                createdAtUs: createdAtUs,
                nextAttemptAtUs: nextAttemptAtUs,
                leaseExpiresAtUs: leaseExpiresAtUs,
                acceptedRevision: acceptedRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String familyId,
                required String deviceId,
                required String entityType,
                required String entityId,
                required String mutationKind,
                required int baseRevision,
                required String payloadJson,
                required String payloadDigest,
                required int protocolVersion,
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                required int createdAtUs,
                Value<int?> nextAttemptAtUs = const Value.absent(),
                Value<int?> leaseExpiresAtUs = const Value.absent(),
                Value<int?> acceptedRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingMutationsCompanion.insert(
                operationId: operationId,
                familyId: familyId,
                deviceId: deviceId,
                entityType: entityType,
                entityId: entityId,
                mutationKind: mutationKind,
                baseRevision: baseRevision,
                payloadJson: payloadJson,
                payloadDigest: payloadDigest,
                protocolVersion: protocolVersion,
                state: state,
                attempts: attempts,
                createdAtUs: createdAtUs,
                nextAttemptAtUs: nextAttemptAtUs,
                leaseExpiresAtUs: leaseExpiresAtUs,
                acceptedRevision: acceptedRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingMutationsTable, PendingMutation>(table),
                  $$PendingMutationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({syncConflictsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (syncConflictsRefs) db.syncConflicts,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (syncConflictsRefs)
                    await $_getPrefetchedDataByColumns<
                      PendingMutation,
                      $PendingMutationsTable,
                      SyncConflict,
                      $SyncConflictsTable
                    >(
                      currentTable: table,
                      referencedTable: $$PendingMutationsTableReferences
                          ._syncConflictsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PendingMutationsTableReferences(
                            db,
                            table,
                            p0,
                          ).syncConflictsRefs,
                      currentColumn: 'operation_id',
                      referencedColumn: 'operation_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PendingMutationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingMutationsTable,
      PendingMutation,
      $$PendingMutationsTableFilterComposer,
      $$PendingMutationsTableOrderingComposer,
      $$PendingMutationsTableAnnotationComposer,
      $$PendingMutationsTableCreateCompanionBuilder,
      $$PendingMutationsTableUpdateCompanionBuilder,
      (PendingMutation, $$PendingMutationsTableReferences),
      PendingMutation,
      PrefetchHooks Function({bool syncConflictsRefs})
    >;
typedef $$SyncCheckpointsTableCreateCompanionBuilder =
    SyncCheckpointsCompanion Function({
      required String familyId,
      Value<int> lastSequence,
      Value<int> authorizationEpoch,
      required int updatedAtUs,
      Value<int> rowid,
    });
typedef $$SyncCheckpointsTableUpdateCompanionBuilder =
    SyncCheckpointsCompanion Function({
      Value<String> familyId,
      Value<int> lastSequence,
      Value<int> authorizationEpoch,
      Value<int> updatedAtUs,
      Value<int> rowid,
    });

class $$SyncCheckpointsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCheckpointsTable> {
  $$SyncCheckpointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSequence => $composableBuilder(
    column: $table.lastSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get authorizationEpoch => $composableBuilder(
    column: $table.authorizationEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCheckpointsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCheckpointsTable> {
  $$SyncCheckpointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSequence => $composableBuilder(
    column: $table.lastSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get authorizationEpoch => $composableBuilder(
    column: $table.authorizationEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCheckpointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCheckpointsTable> {
  $$SyncCheckpointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<int> get lastSequence => $composableBuilder(
    column: $table.lastSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get authorizationEpoch => $composableBuilder(
    column: $table.authorizationEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );
}

class $$SyncCheckpointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCheckpointsTable,
          SyncCheckpoint,
          $$SyncCheckpointsTableFilterComposer,
          $$SyncCheckpointsTableOrderingComposer,
          $$SyncCheckpointsTableAnnotationComposer,
          $$SyncCheckpointsTableCreateCompanionBuilder,
          $$SyncCheckpointsTableUpdateCompanionBuilder,
          (
            SyncCheckpoint,
            BaseReferences<
              _$AppDatabase,
              $SyncCheckpointsTable,
              SyncCheckpoint
            >,
          ),
          SyncCheckpoint,
          PrefetchHooks Function()
        > {
  $$SyncCheckpointsTableTableManager(
    _$AppDatabase db,
    $SyncCheckpointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCheckpointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCheckpointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCheckpointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> familyId = const Value.absent(),
                Value<int> lastSequence = const Value.absent(),
                Value<int> authorizationEpoch = const Value.absent(),
                Value<int> updatedAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCheckpointsCompanion(
                familyId: familyId,
                lastSequence: lastSequence,
                authorizationEpoch: authorizationEpoch,
                updatedAtUs: updatedAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String familyId,
                Value<int> lastSequence = const Value.absent(),
                Value<int> authorizationEpoch = const Value.absent(),
                required int updatedAtUs,
                Value<int> rowid = const Value.absent(),
              }) => SyncCheckpointsCompanion.insert(
                familyId: familyId,
                lastSequence: lastSequence,
                authorizationEpoch: authorizationEpoch,
                updatedAtUs: updatedAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncCheckpointsTable, SyncCheckpoint>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncCheckpointsTable,
                    SyncCheckpoint
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCheckpointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCheckpointsTable,
      SyncCheckpoint,
      $$SyncCheckpointsTableFilterComposer,
      $$SyncCheckpointsTableOrderingComposer,
      $$SyncCheckpointsTableAnnotationComposer,
      $$SyncCheckpointsTableCreateCompanionBuilder,
      $$SyncCheckpointsTableUpdateCompanionBuilder,
      (
        SyncCheckpoint,
        BaseReferences<_$AppDatabase, $SyncCheckpointsTable, SyncCheckpoint>,
      ),
      SyncCheckpoint,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      required String id,
      required String operationId,
      required int serverRevision,
      required String serverSnapshotJson,
      required int detectedAtUs,
      Value<int?> resolvedAtUs,
      Value<int> rowid,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<String> id,
      Value<String> operationId,
      Value<int> serverRevision,
      Value<String> serverSnapshotJson,
      Value<int> detectedAtUs,
      Value<int?> resolvedAtUs,
      Value<int> rowid,
    });

final class $$SyncConflictsTableReferences
    extends BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict> {
  $$SyncConflictsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PendingMutationsTable _operationIdTable(_$AppDatabase db) =>
      db.pendingMutations.createAlias(
        'sync_conflicts__operation_id__pending_mutations__operation_id',
      );

  $$PendingMutationsTableProcessedTableManager get operationId {
    final $_column = $_itemColumn<String>('operation_id')!;

    final manager = $$PendingMutationsTableTableManager(
      $_db,
      $_db.pendingMutations,
    ).filter((f) => f.operationId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_operationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SyncConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
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

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverSnapshotJson => $composableBuilder(
    column: $table.serverSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detectedAtUs => $composableBuilder(
    column: $table.detectedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolvedAtUs => $composableBuilder(
    column: $table.resolvedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  $$PendingMutationsTableFilterComposer get operationId {
    final $$PendingMutationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.pendingMutations,
      getReferencedColumn: (t) => t.operationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingMutationsTableFilterComposer(
            $db: $db,
            $table: $db.pendingMutations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
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

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverSnapshotJson => $composableBuilder(
    column: $table.serverSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detectedAtUs => $composableBuilder(
    column: $table.detectedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolvedAtUs => $composableBuilder(
    column: $table.resolvedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  $$PendingMutationsTableOrderingComposer get operationId {
    final $$PendingMutationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.pendingMutations,
      getReferencedColumn: (t) => t.operationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingMutationsTableOrderingComposer(
            $db: $db,
            $table: $db.pendingMutations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverSnapshotJson => $composableBuilder(
    column: $table.serverSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get detectedAtUs => $composableBuilder(
    column: $table.detectedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resolvedAtUs => $composableBuilder(
    column: $table.resolvedAtUs,
    builder: (column) => column,
  );

  $$PendingMutationsTableAnnotationComposer get operationId {
    final $$PendingMutationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.pendingMutations,
      getReferencedColumn: (t) => t.operationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingMutationsTableAnnotationComposer(
            $db: $db,
            $table: $db.pendingMutations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTable,
          SyncConflict,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (SyncConflict, $$SyncConflictsTableReferences),
          SyncConflict,
          PrefetchHooks Function({bool operationId})
        > {
  $$SyncConflictsTableTableManager(_$AppDatabase db, $SyncConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<String> serverSnapshotJson = const Value.absent(),
                Value<int> detectedAtUs = const Value.absent(),
                Value<int?> resolvedAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion(
                id: id,
                operationId: operationId,
                serverRevision: serverRevision,
                serverSnapshotJson: serverSnapshotJson,
                detectedAtUs: detectedAtUs,
                resolvedAtUs: resolvedAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String operationId,
                required int serverRevision,
                required String serverSnapshotJson,
                required int detectedAtUs,
                Value<int?> resolvedAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion.insert(
                id: id,
                operationId: operationId,
                serverRevision: serverRevision,
                serverSnapshotJson: serverSnapshotJson,
                detectedAtUs: detectedAtUs,
                resolvedAtUs: resolvedAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncConflictsTable, SyncConflict>(table),
                  $$SyncConflictsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({operationId = false}) {
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
                    if (operationId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.operationId,
                        referencedTable: $$SyncConflictsTableReferences
                            ._operationIdTable(db),
                        referencedColumn: $$SyncConflictsTableReferences
                            ._operationIdTable(db)
                            .operationId,
                      ) as T;
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

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTable,
      SyncConflict,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (SyncConflict, $$SyncConflictsTableReferences),
      SyncConflict,
      PrefetchHooks Function({bool operationId})
    >;
typedef $$FamilySpacesTableCreateCompanionBuilder =
    FamilySpacesCompanion Function({
      required String id,
      required String name,
      required String mode,
      Value<String> currency,
      required int createdAtUs,
      Value<int> rowid,
    });
typedef $$FamilySpacesTableUpdateCompanionBuilder =
    FamilySpacesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> mode,
      Value<String> currency,
      Value<int> createdAtUs,
      Value<int> rowid,
    });

final class $$FamilySpacesTableReferences
    extends BaseReferences<_$AppDatabase, $FamilySpacesTable, FamilySpace> {
  $$FamilySpacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FamilyMembersTable, List<FamilyMember>>
  _familyMembersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.familyMembers,
    aliasName: 'family_spaces__id__family_members__family_id',
  );

  $$FamilyMembersTableProcessedTableManager get familyMembersRefs {
    final manager = $$FamilyMembersTableTableManager(
      $_db,
      $_db.familyMembers,
    ).filter((f) => f.familyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_familyMembersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LedgerAccountsTable, List<LedgerAccount>>
  _ledgerAccountsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.ledgerAccounts,
    aliasName: 'family_spaces__id__ledger_accounts__family_id',
  );

  $$LedgerAccountsTableProcessedTableManager get ledgerAccountsRefs {
    final manager = $$LedgerAccountsTableTableManager(
      $_db,
      $_db.ledgerAccounts,
    ).filter((f) => f.familyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_ledgerAccountsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LedgerJournalsTable, List<LedgerJournal>>
  _ledgerJournalsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.ledgerJournals,
    aliasName: 'family_spaces__id__ledger_journals__family_id',
  );

  $$LedgerJournalsTableProcessedTableManager get ledgerJournalsRefs {
    final manager = $$LedgerJournalsTableTableManager(
      $_db,
      $_db.ledgerJournals,
    ).filter((f) => f.familyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_ledgerJournalsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MonthlyBudgetsTable, List<MonthlyBudget>>
  _monthlyBudgetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.monthlyBudgets,
    aliasName: 'family_spaces__id__monthly_budgets__family_id',
  );

  $$MonthlyBudgetsTableProcessedTableManager get monthlyBudgetsRefs {
    final manager = $$MonthlyBudgetsTableTableManager(
      $_db,
      $_db.monthlyBudgets,
    ).filter((f) => f.familyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_monthlyBudgetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ReconciliationChecksTable,
    List<ReconciliationCheck>
  >
  _reconciliationChecksRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.reconciliationChecks,
        aliasName: 'family_spaces__id__reconciliation_checks__family_id',
      );

  $$ReconciliationChecksTableProcessedTableManager
  get reconciliationChecksRefs {
    final manager = $$ReconciliationChecksTableTableManager(
      $_db,
      $_db.reconciliationChecks,
    ).filter((f) => f.familyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _reconciliationChecksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FamilySpacesTableFilterComposer
    extends Composer<_$AppDatabase, $FamilySpacesTable> {
  $$FamilySpacesTableFilterComposer({
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

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> familyMembersRefs(
    Expression<bool> Function($$FamilyMembersTableFilterComposer f) f,
  ) {
    final $$FamilyMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.familyMembers,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyMembersTableFilterComposer(
            $db: $db,
            $table: $db.familyMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> ledgerAccountsRefs(
    Expression<bool> Function($$LedgerAccountsTableFilterComposer f) f,
  ) {
    final $$LedgerAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableFilterComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> ledgerJournalsRefs(
    Expression<bool> Function($$LedgerJournalsTableFilterComposer f) f,
  ) {
    final $$LedgerJournalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ledgerJournals,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerJournalsTableFilterComposer(
            $db: $db,
            $table: $db.ledgerJournals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> monthlyBudgetsRefs(
    Expression<bool> Function($$MonthlyBudgetsTableFilterComposer f) f,
  ) {
    final $$MonthlyBudgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.monthlyBudgets,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthlyBudgetsTableFilterComposer(
            $db: $db,
            $table: $db.monthlyBudgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> reconciliationChecksRefs(
    Expression<bool> Function($$ReconciliationChecksTableFilterComposer f) f,
  ) {
    final $$ReconciliationChecksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reconciliationChecks,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReconciliationChecksTableFilterComposer(
            $db: $db,
            $table: $db.reconciliationChecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FamilySpacesTableOrderingComposer
    extends Composer<_$AppDatabase, $FamilySpacesTable> {
  $$FamilySpacesTableOrderingComposer({
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

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamilySpacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamilySpacesTable> {
  $$FamilySpacesTableAnnotationComposer({
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

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );

  Expression<T> familyMembersRefs<T extends Object>(
    Expression<T> Function($$FamilyMembersTableAnnotationComposer a) f,
  ) {
    final $$FamilyMembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.familyMembers,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyMembersTableAnnotationComposer(
            $db: $db,
            $table: $db.familyMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> ledgerAccountsRefs<T extends Object>(
    Expression<T> Function($$LedgerAccountsTableAnnotationComposer a) f,
  ) {
    final $$LedgerAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> ledgerJournalsRefs<T extends Object>(
    Expression<T> Function($$LedgerJournalsTableAnnotationComposer a) f,
  ) {
    final $$LedgerJournalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ledgerJournals,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerJournalsTableAnnotationComposer(
            $db: $db,
            $table: $db.ledgerJournals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> monthlyBudgetsRefs<T extends Object>(
    Expression<T> Function($$MonthlyBudgetsTableAnnotationComposer a) f,
  ) {
    final $$MonthlyBudgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.monthlyBudgets,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthlyBudgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.monthlyBudgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> reconciliationChecksRefs<T extends Object>(
    Expression<T> Function($$ReconciliationChecksTableAnnotationComposer a) f,
  ) {
    final $$ReconciliationChecksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.reconciliationChecks,
          getReferencedColumn: (t) => t.familyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ReconciliationChecksTableAnnotationComposer(
                $db: $db,
                $table: $db.reconciliationChecks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FamilySpacesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamilySpacesTable,
          FamilySpace,
          $$FamilySpacesTableFilterComposer,
          $$FamilySpacesTableOrderingComposer,
          $$FamilySpacesTableAnnotationComposer,
          $$FamilySpacesTableCreateCompanionBuilder,
          $$FamilySpacesTableUpdateCompanionBuilder,
          (FamilySpace, $$FamilySpacesTableReferences),
          FamilySpace,
          PrefetchHooks Function({
            bool familyMembersRefs,
            bool ledgerAccountsRefs,
            bool ledgerJournalsRefs,
            bool monthlyBudgetsRefs,
            bool reconciliationChecksRefs,
          })
        > {
  $$FamilySpacesTableTableManager(_$AppDatabase db, $FamilySpacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilySpacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilySpacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FamilySpacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> createdAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilySpacesCompanion(
                id: id,
                name: name,
                mode: mode,
                currency: currency,
                createdAtUs: createdAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String mode,
                Value<String> currency = const Value.absent(),
                required int createdAtUs,
                Value<int> rowid = const Value.absent(),
              }) => FamilySpacesCompanion.insert(
                id: id,
                name: name,
                mode: mode,
                currency: currency,
                createdAtUs: createdAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FamilySpacesTable, FamilySpace>(table),
                  $$FamilySpacesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                familyMembersRefs = false,
                ledgerAccountsRefs = false,
                ledgerJournalsRefs = false,
                monthlyBudgetsRefs = false,
                reconciliationChecksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (familyMembersRefs) db.familyMembers,
                    if (ledgerAccountsRefs) db.ledgerAccounts,
                    if (ledgerJournalsRefs) db.ledgerJournals,
                    if (monthlyBudgetsRefs) db.monthlyBudgets,
                    if (reconciliationChecksRefs) db.reconciliationChecks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (familyMembersRefs)
                        await $_getPrefetchedDataByColumns<
                          FamilySpace,
                          $FamilySpacesTable,
                          FamilyMember,
                          $FamilyMembersTable
                        >(
                          currentTable: table,
                          referencedTable: $$FamilySpacesTableReferences
                              ._familyMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FamilySpacesTableReferences(
                                db,
                                table,
                                p0,
                              ).familyMembersRefs,
                          currentColumn: 'id',
                          referencedColumn: 'family_id',
                          typedResults: items,
                        ),
                      if (ledgerAccountsRefs)
                        await $_getPrefetchedDataByColumns<
                          FamilySpace,
                          $FamilySpacesTable,
                          LedgerAccount,
                          $LedgerAccountsTable
                        >(
                          currentTable: table,
                          referencedTable: $$FamilySpacesTableReferences
                              ._ledgerAccountsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FamilySpacesTableReferences(
                                db,
                                table,
                                p0,
                              ).ledgerAccountsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'family_id',
                          typedResults: items,
                        ),
                      if (ledgerJournalsRefs)
                        await $_getPrefetchedDataByColumns<
                          FamilySpace,
                          $FamilySpacesTable,
                          LedgerJournal,
                          $LedgerJournalsTable
                        >(
                          currentTable: table,
                          referencedTable: $$FamilySpacesTableReferences
                              ._ledgerJournalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FamilySpacesTableReferences(
                                db,
                                table,
                                p0,
                              ).ledgerJournalsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'family_id',
                          typedResults: items,
                        ),
                      if (monthlyBudgetsRefs)
                        await $_getPrefetchedDataByColumns<
                          FamilySpace,
                          $FamilySpacesTable,
                          MonthlyBudget,
                          $MonthlyBudgetsTable
                        >(
                          currentTable: table,
                          referencedTable: $$FamilySpacesTableReferences
                              ._monthlyBudgetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FamilySpacesTableReferences(
                                db,
                                table,
                                p0,
                              ).monthlyBudgetsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'family_id',
                          typedResults: items,
                        ),
                      if (reconciliationChecksRefs)
                        await $_getPrefetchedDataByColumns<
                          FamilySpace,
                          $FamilySpacesTable,
                          ReconciliationCheck,
                          $ReconciliationChecksTable
                        >(
                          currentTable: table,
                          referencedTable: $$FamilySpacesTableReferences
                              ._reconciliationChecksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FamilySpacesTableReferences(
                                db,
                                table,
                                p0,
                              ).reconciliationChecksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'family_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FamilySpacesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamilySpacesTable,
      FamilySpace,
      $$FamilySpacesTableFilterComposer,
      $$FamilySpacesTableOrderingComposer,
      $$FamilySpacesTableAnnotationComposer,
      $$FamilySpacesTableCreateCompanionBuilder,
      $$FamilySpacesTableUpdateCompanionBuilder,
      (FamilySpace, $$FamilySpacesTableReferences),
      FamilySpace,
      PrefetchHooks Function({
        bool familyMembersRefs,
        bool ledgerAccountsRefs,
        bool ledgerJournalsRefs,
        bool monthlyBudgetsRefs,
        bool reconciliationChecksRefs,
      })
    >;
typedef $$FamilyMembersTableCreateCompanionBuilder =
    FamilyMembersCompanion Function({
      required String id,
      required String familyId,
      Value<String?> authUserId,
      required String displayName,
      required String relationship,
      required String role,
      Value<bool> active,
      Value<int> revision,
      required int createdAtUs,
      Value<int> rowid,
    });
typedef $$FamilyMembersTableUpdateCompanionBuilder =
    FamilyMembersCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<String?> authUserId,
      Value<String> displayName,
      Value<String> relationship,
      Value<String> role,
      Value<bool> active,
      Value<int> revision,
      Value<int> createdAtUs,
      Value<int> rowid,
    });

final class $$FamilyMembersTableReferences
    extends BaseReferences<_$AppDatabase, $FamilyMembersTable, FamilyMember> {
  $$FamilyMembersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FamilySpacesTable _familyIdTable(_$AppDatabase db) => db.familySpaces
      .createAlias('family_members__family_id__family_spaces__id');

  $$FamilySpacesTableProcessedTableManager get familyId {
    final $_column = $_itemColumn<String>('family_id')!;

    final manager = $$FamilySpacesTableTableManager(
      $_db,
      $_db.familySpaces,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_familyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FamilyMembersTableFilterComposer
    extends Composer<_$AppDatabase, $FamilyMembersTable> {
  $$FamilyMembersTableFilterComposer({
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

  ColumnFilters<String> get authUserId => $composableBuilder(
    column: $table.authUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );

  $$FamilySpacesTableFilterComposer get familyId {
    final $$FamilySpacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableFilterComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $FamilyMembersTable> {
  $$FamilyMembersTableOrderingComposer({
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

  ColumnOrderings<String> get authUserId => $composableBuilder(
    column: $table.authUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  $$FamilySpacesTableOrderingComposer get familyId {
    final $$FamilySpacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableOrderingComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamilyMembersTable> {
  $$FamilyMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get authUserId => $composableBuilder(
    column: $table.authUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );

  $$FamilySpacesTableAnnotationComposer get familyId {
    final $$FamilySpacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableAnnotationComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamilyMembersTable,
          FamilyMember,
          $$FamilyMembersTableFilterComposer,
          $$FamilyMembersTableOrderingComposer,
          $$FamilyMembersTableAnnotationComposer,
          $$FamilyMembersTableCreateCompanionBuilder,
          $$FamilyMembersTableUpdateCompanionBuilder,
          (FamilyMember, $$FamilyMembersTableReferences),
          FamilyMember,
          PrefetchHooks Function({bool familyId})
        > {
  $$FamilyMembersTableTableManager(_$AppDatabase db, $FamilyMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilyMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FamilyMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String?> authUserId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> relationship = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> createdAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyMembersCompanion(
                id: id,
                familyId: familyId,
                authUserId: authUserId,
                displayName: displayName,
                relationship: relationship,
                role: role,
                active: active,
                revision: revision,
                createdAtUs: createdAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                Value<String?> authUserId = const Value.absent(),
                required String displayName,
                required String relationship,
                required String role,
                Value<bool> active = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required int createdAtUs,
                Value<int> rowid = const Value.absent(),
              }) => FamilyMembersCompanion.insert(
                id: id,
                familyId: familyId,
                authUserId: authUserId,
                displayName: displayName,
                relationship: relationship,
                role: role,
                active: active,
                revision: revision,
                createdAtUs: createdAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FamilyMembersTable, FamilyMember>(table),
                  $$FamilyMembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({familyId = false}) {
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
                    if (familyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.familyId,
                        referencedTable: $$FamilyMembersTableReferences
                            ._familyIdTable(db),
                        referencedColumn: $$FamilyMembersTableReferences
                            ._familyIdTable(db)
                            .id,
                      ) as T;
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

typedef $$FamilyMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamilyMembersTable,
      FamilyMember,
      $$FamilyMembersTableFilterComposer,
      $$FamilyMembersTableOrderingComposer,
      $$FamilyMembersTableAnnotationComposer,
      $$FamilyMembersTableCreateCompanionBuilder,
      $$FamilyMembersTableUpdateCompanionBuilder,
      (FamilyMember, $$FamilyMembersTableReferences),
      FamilyMember,
      PrefetchHooks Function({bool familyId})
    >;
typedef $$VaultDevicesTableCreateCompanionBuilder =
    VaultDevicesCompanion Function({
      required String id,
      required String familyId,
      required String memberId,
      required String state,
      required int createdAtUs,
      Value<int> rowid,
    });
typedef $$VaultDevicesTableUpdateCompanionBuilder =
    VaultDevicesCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<String> memberId,
      Value<String> state,
      Value<int> createdAtUs,
      Value<int> rowid,
    });

class $$VaultDevicesTableFilterComposer
    extends Composer<_$AppDatabase, $VaultDevicesTable> {
  $$VaultDevicesTableFilterComposer({
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

  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultDevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultDevicesTable> {
  $$VaultDevicesTableOrderingComposer({
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

  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultDevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultDevicesTable> {
  $$VaultDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );
}

class $$VaultDevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultDevicesTable,
          VaultDevice,
          $$VaultDevicesTableFilterComposer,
          $$VaultDevicesTableOrderingComposer,
          $$VaultDevicesTableAnnotationComposer,
          $$VaultDevicesTableCreateCompanionBuilder,
          $$VaultDevicesTableUpdateCompanionBuilder,
          (
            VaultDevice,
            BaseReferences<_$AppDatabase, $VaultDevicesTable, VaultDevice>,
          ),
          VaultDevice,
          PrefetchHooks Function()
        > {
  $$VaultDevicesTableTableManager(_$AppDatabase db, $VaultDevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> memberId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> createdAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultDevicesCompanion(
                id: id,
                familyId: familyId,
                memberId: memberId,
                state: state,
                createdAtUs: createdAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                required String memberId,
                required String state,
                required int createdAtUs,
                Value<int> rowid = const Value.absent(),
              }) => VaultDevicesCompanion.insert(
                id: id,
                familyId: familyId,
                memberId: memberId,
                state: state,
                createdAtUs: createdAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultDevicesTable, VaultDevice>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $VaultDevicesTable,
                    VaultDevice
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultDevicesTable,
      VaultDevice,
      $$VaultDevicesTableFilterComposer,
      $$VaultDevicesTableOrderingComposer,
      $$VaultDevicesTableAnnotationComposer,
      $$VaultDevicesTableCreateCompanionBuilder,
      $$VaultDevicesTableUpdateCompanionBuilder,
      (
        VaultDevice,
        BaseReferences<_$AppDatabase, $VaultDevicesTable, VaultDevice>,
      ),
      VaultDevice,
      PrefetchHooks Function()
    >;
typedef $$LedgerAccountsTableCreateCompanionBuilder =
    LedgerAccountsCompanion Function({
      required String id,
      required String familyId,
      Value<int> revision,
      required String createdBy,
      required String updatedBy,
      required int createdAtUs,
      required int updatedAtUs,
      Value<int?> deletedAtUs,
      required String name,
      required String kind,
      required String subtype,
      Value<String> currency,
      Value<bool> systemAccount,
      Value<int> rowid,
    });
typedef $$LedgerAccountsTableUpdateCompanionBuilder =
    LedgerAccountsCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<int> revision,
      Value<String> createdBy,
      Value<String> updatedBy,
      Value<int> createdAtUs,
      Value<int> updatedAtUs,
      Value<int?> deletedAtUs,
      Value<String> name,
      Value<String> kind,
      Value<String> subtype,
      Value<String> currency,
      Value<bool> systemAccount,
      Value<int> rowid,
    });

final class $$LedgerAccountsTableReferences
    extends BaseReferences<_$AppDatabase, $LedgerAccountsTable, LedgerAccount> {
  $$LedgerAccountsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FamilySpacesTable _familyIdTable(_$AppDatabase db) => db.familySpaces
      .createAlias('ledger_accounts__family_id__family_spaces__id');

  $$FamilySpacesTableProcessedTableManager get familyId {
    final $_column = $_itemColumn<String>('family_id')!;

    final manager = $$FamilySpacesTableTableManager(
      $_db,
      $_db.familySpaces,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_familyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LedgerAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerAccountsTable> {
  $$LedgerAccountsTableFilterComposer({
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

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get systemAccount => $composableBuilder(
    column: $table.systemAccount,
    builder: (column) => ColumnFilters(column),
  );

  $$FamilySpacesTableFilterComposer get familyId {
    final $$FamilySpacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableFilterComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LedgerAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerAccountsTable> {
  $$LedgerAccountsTableOrderingComposer({
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

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get systemAccount => $composableBuilder(
    column: $table.systemAccount,
    builder: (column) => ColumnOrderings(column),
  );

  $$FamilySpacesTableOrderingComposer get familyId {
    final $$FamilySpacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableOrderingComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LedgerAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerAccountsTable> {
  $$LedgerAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get subtype =>
      $composableBuilder(column: $table.subtype, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<bool> get systemAccount => $composableBuilder(
    column: $table.systemAccount,
    builder: (column) => column,
  );

  $$FamilySpacesTableAnnotationComposer get familyId {
    final $$FamilySpacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableAnnotationComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LedgerAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerAccountsTable,
          LedgerAccount,
          $$LedgerAccountsTableFilterComposer,
          $$LedgerAccountsTableOrderingComposer,
          $$LedgerAccountsTableAnnotationComposer,
          $$LedgerAccountsTableCreateCompanionBuilder,
          $$LedgerAccountsTableUpdateCompanionBuilder,
          (LedgerAccount, $$LedgerAccountsTableReferences),
          LedgerAccount,
          PrefetchHooks Function({bool familyId})
        > {
  $$LedgerAccountsTableTableManager(
    _$AppDatabase db,
    $LedgerAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String> updatedBy = const Value.absent(),
                Value<int> createdAtUs = const Value.absent(),
                Value<int> updatedAtUs = const Value.absent(),
                Value<int?> deletedAtUs = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> subtype = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<bool> systemAccount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerAccountsCompanion(
                id: id,
                familyId: familyId,
                revision: revision,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                deletedAtUs: deletedAtUs,
                name: name,
                kind: kind,
                subtype: subtype,
                currency: currency,
                systemAccount: systemAccount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                Value<int> revision = const Value.absent(),
                required String createdBy,
                required String updatedBy,
                required int createdAtUs,
                required int updatedAtUs,
                Value<int?> deletedAtUs = const Value.absent(),
                required String name,
                required String kind,
                required String subtype,
                Value<String> currency = const Value.absent(),
                Value<bool> systemAccount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerAccountsCompanion.insert(
                id: id,
                familyId: familyId,
                revision: revision,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                deletedAtUs: deletedAtUs,
                name: name,
                kind: kind,
                subtype: subtype,
                currency: currency,
                systemAccount: systemAccount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerAccountsTable, LedgerAccount>(table),
                  $$LedgerAccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({familyId = false}) {
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
                    if (familyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.familyId,
                        referencedTable: $$LedgerAccountsTableReferences
                            ._familyIdTable(db),
                        referencedColumn: $$LedgerAccountsTableReferences
                            ._familyIdTable(db)
                            .id,
                      ) as T;
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

typedef $$LedgerAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerAccountsTable,
      LedgerAccount,
      $$LedgerAccountsTableFilterComposer,
      $$LedgerAccountsTableOrderingComposer,
      $$LedgerAccountsTableAnnotationComposer,
      $$LedgerAccountsTableCreateCompanionBuilder,
      $$LedgerAccountsTableUpdateCompanionBuilder,
      (LedgerAccount, $$LedgerAccountsTableReferences),
      LedgerAccount,
      PrefetchHooks Function({bool familyId})
    >;
typedef $$LedgerJournalsTableCreateCompanionBuilder =
    LedgerJournalsCompanion Function({
      required String id,
      required String familyId,
      Value<int> revision,
      required String createdBy,
      required String updatedBy,
      required int createdAtUs,
      required int updatedAtUs,
      Value<int?> deletedAtUs,
      required String kind,
      required String occurredOn,
      required String description,
      Value<String> currency,
      Value<String> status,
      Value<String?> reversesId,
      Value<String?> businessId,
      Value<String?> relatedEntityId,
      Value<int> rowid,
    });
typedef $$LedgerJournalsTableUpdateCompanionBuilder =
    LedgerJournalsCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<int> revision,
      Value<String> createdBy,
      Value<String> updatedBy,
      Value<int> createdAtUs,
      Value<int> updatedAtUs,
      Value<int?> deletedAtUs,
      Value<String> kind,
      Value<String> occurredOn,
      Value<String> description,
      Value<String> currency,
      Value<String> status,
      Value<String?> reversesId,
      Value<String?> businessId,
      Value<String?> relatedEntityId,
      Value<int> rowid,
    });

final class $$LedgerJournalsTableReferences
    extends BaseReferences<_$AppDatabase, $LedgerJournalsTable, LedgerJournal> {
  $$LedgerJournalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FamilySpacesTable _familyIdTable(_$AppDatabase db) => db.familySpaces
      .createAlias('ledger_journals__family_id__family_spaces__id');

  $$FamilySpacesTableProcessedTableManager get familyId {
    final $_column = $_itemColumn<String>('family_id')!;

    final manager = $$FamilySpacesTableTableManager(
      $_db,
      $_db.familySpaces,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_familyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LedgerJournalsTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerJournalsTable> {
  $$LedgerJournalsTableFilterComposer({
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

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredOn => $composableBuilder(
    column: $table.occurredOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reversesId => $composableBuilder(
    column: $table.reversesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relatedEntityId => $composableBuilder(
    column: $table.relatedEntityId,
    builder: (column) => ColumnFilters(column),
  );

  $$FamilySpacesTableFilterComposer get familyId {
    final $$FamilySpacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableFilterComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LedgerJournalsTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerJournalsTable> {
  $$LedgerJournalsTableOrderingComposer({
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

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredOn => $composableBuilder(
    column: $table.occurredOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reversesId => $composableBuilder(
    column: $table.reversesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedEntityId => $composableBuilder(
    column: $table.relatedEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  $$FamilySpacesTableOrderingComposer get familyId {
    final $$FamilySpacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableOrderingComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LedgerJournalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerJournalsTable> {
  $$LedgerJournalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get occurredOn => $composableBuilder(
    column: $table.occurredOn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get reversesId => $composableBuilder(
    column: $table.reversesId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relatedEntityId => $composableBuilder(
    column: $table.relatedEntityId,
    builder: (column) => column,
  );

  $$FamilySpacesTableAnnotationComposer get familyId {
    final $$FamilySpacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableAnnotationComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LedgerJournalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerJournalsTable,
          LedgerJournal,
          $$LedgerJournalsTableFilterComposer,
          $$LedgerJournalsTableOrderingComposer,
          $$LedgerJournalsTableAnnotationComposer,
          $$LedgerJournalsTableCreateCompanionBuilder,
          $$LedgerJournalsTableUpdateCompanionBuilder,
          (LedgerJournal, $$LedgerJournalsTableReferences),
          LedgerJournal,
          PrefetchHooks Function({bool familyId})
        > {
  $$LedgerJournalsTableTableManager(
    _$AppDatabase db,
    $LedgerJournalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerJournalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerJournalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerJournalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String> updatedBy = const Value.absent(),
                Value<int> createdAtUs = const Value.absent(),
                Value<int> updatedAtUs = const Value.absent(),
                Value<int?> deletedAtUs = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> occurredOn = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> reversesId = const Value.absent(),
                Value<String?> businessId = const Value.absent(),
                Value<String?> relatedEntityId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerJournalsCompanion(
                id: id,
                familyId: familyId,
                revision: revision,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                deletedAtUs: deletedAtUs,
                kind: kind,
                occurredOn: occurredOn,
                description: description,
                currency: currency,
                status: status,
                reversesId: reversesId,
                businessId: businessId,
                relatedEntityId: relatedEntityId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                Value<int> revision = const Value.absent(),
                required String createdBy,
                required String updatedBy,
                required int createdAtUs,
                required int updatedAtUs,
                Value<int?> deletedAtUs = const Value.absent(),
                required String kind,
                required String occurredOn,
                required String description,
                Value<String> currency = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> reversesId = const Value.absent(),
                Value<String?> businessId = const Value.absent(),
                Value<String?> relatedEntityId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerJournalsCompanion.insert(
                id: id,
                familyId: familyId,
                revision: revision,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                deletedAtUs: deletedAtUs,
                kind: kind,
                occurredOn: occurredOn,
                description: description,
                currency: currency,
                status: status,
                reversesId: reversesId,
                businessId: businessId,
                relatedEntityId: relatedEntityId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerJournalsTable, LedgerJournal>(table),
                  $$LedgerJournalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({familyId = false}) {
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
                    if (familyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.familyId,
                        referencedTable: $$LedgerJournalsTableReferences
                            ._familyIdTable(db),
                        referencedColumn: $$LedgerJournalsTableReferences
                            ._familyIdTable(db)
                            .id,
                      ) as T;
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

typedef $$LedgerJournalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerJournalsTable,
      LedgerJournal,
      $$LedgerJournalsTableFilterComposer,
      $$LedgerJournalsTableOrderingComposer,
      $$LedgerJournalsTableAnnotationComposer,
      $$LedgerJournalsTableCreateCompanionBuilder,
      $$LedgerJournalsTableUpdateCompanionBuilder,
      (LedgerJournal, $$LedgerJournalsTableReferences),
      LedgerJournal,
      PrefetchHooks Function({bool familyId})
    >;
typedef $$LedgerPostingsTableCreateCompanionBuilder =
    LedgerPostingsCompanion Function({
      required String id,
      required String familyId,
      required String journalId,
      required String accountId,
      required int position,
      required int amountMinor,
      Value<int> rowid,
    });
typedef $$LedgerPostingsTableUpdateCompanionBuilder =
    LedgerPostingsCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<String> journalId,
      Value<String> accountId,
      Value<int> position,
      Value<int> amountMinor,
      Value<int> rowid,
    });

class $$LedgerPostingsTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerPostingsTable> {
  $$LedgerPostingsTableFilterComposer({
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

  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get journalId => $composableBuilder(
    column: $table.journalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgerPostingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerPostingsTable> {
  $$LedgerPostingsTableOrderingComposer({
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

  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get journalId => $composableBuilder(
    column: $table.journalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerPostingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerPostingsTable> {
  $$LedgerPostingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<String> get journalId =>
      $composableBuilder(column: $table.journalId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );
}

class $$LedgerPostingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerPostingsTable,
          LedgerPosting,
          $$LedgerPostingsTableFilterComposer,
          $$LedgerPostingsTableOrderingComposer,
          $$LedgerPostingsTableAnnotationComposer,
          $$LedgerPostingsTableCreateCompanionBuilder,
          $$LedgerPostingsTableUpdateCompanionBuilder,
          (
            LedgerPosting,
            BaseReferences<_$AppDatabase, $LedgerPostingsTable, LedgerPosting>,
          ),
          LedgerPosting,
          PrefetchHooks Function()
        > {
  $$LedgerPostingsTableTableManager(
    _$AppDatabase db,
    $LedgerPostingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerPostingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerPostingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerPostingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> journalId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerPostingsCompanion(
                id: id,
                familyId: familyId,
                journalId: journalId,
                accountId: accountId,
                position: position,
                amountMinor: amountMinor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                required String journalId,
                required String accountId,
                required int position,
                required int amountMinor,
                Value<int> rowid = const Value.absent(),
              }) => LedgerPostingsCompanion.insert(
                id: id,
                familyId: familyId,
                journalId: journalId,
                accountId: accountId,
                position: position,
                amountMinor: amountMinor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerPostingsTable, LedgerPosting>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LedgerPostingsTable,
                    LedgerPosting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerPostingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerPostingsTable,
      LedgerPosting,
      $$LedgerPostingsTableFilterComposer,
      $$LedgerPostingsTableOrderingComposer,
      $$LedgerPostingsTableAnnotationComposer,
      $$LedgerPostingsTableCreateCompanionBuilder,
      $$LedgerPostingsTableUpdateCompanionBuilder,
      (
        LedgerPosting,
        BaseReferences<_$AppDatabase, $LedgerPostingsTable, LedgerPosting>,
      ),
      LedgerPosting,
      PrefetchHooks Function()
    >;
typedef $$LocalAuditEventsTableCreateCompanionBuilder =
    LocalAuditEventsCompanion Function({
      required String id,
      required String familyId,
      required String actorId,
      required String deviceId,
      required String operationId,
      required String entityType,
      required String entityId,
      required String action,
      Value<String?> beforeJson,
      Value<String?> afterJson,
      required int createdAtUs,
      Value<int> rowid,
    });
typedef $$LocalAuditEventsTableUpdateCompanionBuilder =
    LocalAuditEventsCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<String> actorId,
      Value<String> deviceId,
      Value<String> operationId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> action,
      Value<String?> beforeJson,
      Value<String?> afterJson,
      Value<int> createdAtUs,
      Value<int> rowid,
    });

class $$LocalAuditEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAuditEventsTable> {
  $$LocalAuditEventsTableFilterComposer({
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

  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
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

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afterJson => $composableBuilder(
    column: $table.afterJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAuditEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAuditEventsTable> {
  $$LocalAuditEventsTableOrderingComposer({
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

  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
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

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afterJson => $composableBuilder(
    column: $table.afterJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAuditEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAuditEventsTable> {
  $$LocalAuditEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afterJson =>
      $composableBuilder(column: $table.afterJson, builder: (column) => column);

  GeneratedColumn<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );
}

class $$LocalAuditEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAuditEventsTable,
          LocalAuditEvent,
          $$LocalAuditEventsTableFilterComposer,
          $$LocalAuditEventsTableOrderingComposer,
          $$LocalAuditEventsTableAnnotationComposer,
          $$LocalAuditEventsTableCreateCompanionBuilder,
          $$LocalAuditEventsTableUpdateCompanionBuilder,
          (
            LocalAuditEvent,
            BaseReferences<
              _$AppDatabase,
              $LocalAuditEventsTable,
              LocalAuditEvent
            >,
          ),
          LocalAuditEvent,
          PrefetchHooks Function()
        > {
  $$LocalAuditEventsTableTableManager(
    _$AppDatabase db,
    $LocalAuditEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAuditEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAuditEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAuditEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> actorId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String?> beforeJson = const Value.absent(),
                Value<String?> afterJson = const Value.absent(),
                Value<int> createdAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAuditEventsCompanion(
                id: id,
                familyId: familyId,
                actorId: actorId,
                deviceId: deviceId,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                action: action,
                beforeJson: beforeJson,
                afterJson: afterJson,
                createdAtUs: createdAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                required String actorId,
                required String deviceId,
                required String operationId,
                required String entityType,
                required String entityId,
                required String action,
                Value<String?> beforeJson = const Value.absent(),
                Value<String?> afterJson = const Value.absent(),
                required int createdAtUs,
                Value<int> rowid = const Value.absent(),
              }) => LocalAuditEventsCompanion.insert(
                id: id,
                familyId: familyId,
                actorId: actorId,
                deviceId: deviceId,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                action: action,
                beforeJson: beforeJson,
                afterJson: afterJson,
                createdAtUs: createdAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalAuditEventsTable, LocalAuditEvent>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalAuditEventsTable,
                    LocalAuditEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAuditEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAuditEventsTable,
      LocalAuditEvent,
      $$LocalAuditEventsTableFilterComposer,
      $$LocalAuditEventsTableOrderingComposer,
      $$LocalAuditEventsTableAnnotationComposer,
      $$LocalAuditEventsTableCreateCompanionBuilder,
      $$LocalAuditEventsTableUpdateCompanionBuilder,
      (
        LocalAuditEvent,
        BaseReferences<_$AppDatabase, $LocalAuditEventsTable, LocalAuditEvent>,
      ),
      LocalAuditEvent,
      PrefetchHooks Function()
    >;
typedef $$MonthlyBudgetsTableCreateCompanionBuilder =
    MonthlyBudgetsCompanion Function({
      required String id,
      required String familyId,
      Value<int> revision,
      required String createdBy,
      required String updatedBy,
      required int createdAtUs,
      required int updatedAtUs,
      Value<int?> deletedAtUs,
      required String accountId,
      required String month,
      required int amountMinor,
      Value<int> rowid,
    });
typedef $$MonthlyBudgetsTableUpdateCompanionBuilder =
    MonthlyBudgetsCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<int> revision,
      Value<String> createdBy,
      Value<String> updatedBy,
      Value<int> createdAtUs,
      Value<int> updatedAtUs,
      Value<int?> deletedAtUs,
      Value<String> accountId,
      Value<String> month,
      Value<int> amountMinor,
      Value<int> rowid,
    });

final class $$MonthlyBudgetsTableReferences
    extends BaseReferences<_$AppDatabase, $MonthlyBudgetsTable, MonthlyBudget> {
  $$MonthlyBudgetsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FamilySpacesTable _familyIdTable(_$AppDatabase db) => db.familySpaces
      .createAlias('monthly_budgets__family_id__family_spaces__id');

  $$FamilySpacesTableProcessedTableManager get familyId {
    final $_column = $_itemColumn<String>('family_id')!;

    final manager = $$FamilySpacesTableTableManager(
      $_db,
      $_db.familySpaces,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_familyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MonthlyBudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $MonthlyBudgetsTable> {
  $$MonthlyBudgetsTableFilterComposer({
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

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  $$FamilySpacesTableFilterComposer get familyId {
    final $$FamilySpacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableFilterComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyBudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $MonthlyBudgetsTable> {
  $$MonthlyBudgetsTableOrderingComposer({
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

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  $$FamilySpacesTableOrderingComposer get familyId {
    final $$FamilySpacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableOrderingComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyBudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MonthlyBudgetsTable> {
  $$MonthlyBudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  $$FamilySpacesTableAnnotationComposer get familyId {
    final $$FamilySpacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableAnnotationComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyBudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MonthlyBudgetsTable,
          MonthlyBudget,
          $$MonthlyBudgetsTableFilterComposer,
          $$MonthlyBudgetsTableOrderingComposer,
          $$MonthlyBudgetsTableAnnotationComposer,
          $$MonthlyBudgetsTableCreateCompanionBuilder,
          $$MonthlyBudgetsTableUpdateCompanionBuilder,
          (MonthlyBudget, $$MonthlyBudgetsTableReferences),
          MonthlyBudget,
          PrefetchHooks Function({bool familyId})
        > {
  $$MonthlyBudgetsTableTableManager(
    _$AppDatabase db,
    $MonthlyBudgetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MonthlyBudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MonthlyBudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MonthlyBudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String> updatedBy = const Value.absent(),
                Value<int> createdAtUs = const Value.absent(),
                Value<int> updatedAtUs = const Value.absent(),
                Value<int?> deletedAtUs = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MonthlyBudgetsCompanion(
                id: id,
                familyId: familyId,
                revision: revision,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                deletedAtUs: deletedAtUs,
                accountId: accountId,
                month: month,
                amountMinor: amountMinor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                Value<int> revision = const Value.absent(),
                required String createdBy,
                required String updatedBy,
                required int createdAtUs,
                required int updatedAtUs,
                Value<int?> deletedAtUs = const Value.absent(),
                required String accountId,
                required String month,
                required int amountMinor,
                Value<int> rowid = const Value.absent(),
              }) => MonthlyBudgetsCompanion.insert(
                id: id,
                familyId: familyId,
                revision: revision,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                deletedAtUs: deletedAtUs,
                accountId: accountId,
                month: month,
                amountMinor: amountMinor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MonthlyBudgetsTable, MonthlyBudget>(table),
                  $$MonthlyBudgetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({familyId = false}) {
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
                    if (familyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.familyId,
                        referencedTable: $$MonthlyBudgetsTableReferences
                            ._familyIdTable(db),
                        referencedColumn: $$MonthlyBudgetsTableReferences
                            ._familyIdTable(db)
                            .id,
                      ) as T;
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

typedef $$MonthlyBudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MonthlyBudgetsTable,
      MonthlyBudget,
      $$MonthlyBudgetsTableFilterComposer,
      $$MonthlyBudgetsTableOrderingComposer,
      $$MonthlyBudgetsTableAnnotationComposer,
      $$MonthlyBudgetsTableCreateCompanionBuilder,
      $$MonthlyBudgetsTableUpdateCompanionBuilder,
      (MonthlyBudget, $$MonthlyBudgetsTableReferences),
      MonthlyBudget,
      PrefetchHooks Function({bool familyId})
    >;
typedef $$ReconciliationChecksTableCreateCompanionBuilder =
    ReconciliationChecksCompanion Function({
      required String id,
      required String familyId,
      Value<int> revision,
      required String createdBy,
      required String updatedBy,
      required int createdAtUs,
      required int updatedAtUs,
      Value<int?> deletedAtUs,
      required String accountId,
      required String statementDate,
      required int statementMinor,
      required int ledgerMinor,
      required String notes,
      Value<int> rowid,
    });
typedef $$ReconciliationChecksTableUpdateCompanionBuilder =
    ReconciliationChecksCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<int> revision,
      Value<String> createdBy,
      Value<String> updatedBy,
      Value<int> createdAtUs,
      Value<int> updatedAtUs,
      Value<int?> deletedAtUs,
      Value<String> accountId,
      Value<String> statementDate,
      Value<int> statementMinor,
      Value<int> ledgerMinor,
      Value<String> notes,
      Value<int> rowid,
    });

final class $$ReconciliationChecksTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ReconciliationChecksTable,
          ReconciliationCheck
        > {
  $$ReconciliationChecksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FamilySpacesTable _familyIdTable(_$AppDatabase db) => db.familySpaces
      .createAlias('reconciliation_checks__family_id__family_spaces__id');

  $$FamilySpacesTableProcessedTableManager get familyId {
    final $_column = $_itemColumn<String>('family_id')!;

    final manager = $$FamilySpacesTableTableManager(
      $_db,
      $_db.familySpaces,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_familyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReconciliationChecksTableFilterComposer
    extends Composer<_$AppDatabase, $ReconciliationChecksTable> {
  $$ReconciliationChecksTableFilterComposer({
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

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statementDate => $composableBuilder(
    column: $table.statementDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statementMinor => $composableBuilder(
    column: $table.statementMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ledgerMinor => $composableBuilder(
    column: $table.ledgerMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$FamilySpacesTableFilterComposer get familyId {
    final $$FamilySpacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableFilterComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReconciliationChecksTableOrderingComposer
    extends Composer<_$AppDatabase, $ReconciliationChecksTable> {
  $$ReconciliationChecksTableOrderingComposer({
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

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statementDate => $composableBuilder(
    column: $table.statementDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statementMinor => $composableBuilder(
    column: $table.statementMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ledgerMinor => $composableBuilder(
    column: $table.ledgerMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$FamilySpacesTableOrderingComposer get familyId {
    final $$FamilySpacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableOrderingComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReconciliationChecksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReconciliationChecksTable> {
  $$ReconciliationChecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUs => $composableBuilder(
    column: $table.deletedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get statementDate => $composableBuilder(
    column: $table.statementDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get statementMinor => $composableBuilder(
    column: $table.statementMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ledgerMinor => $composableBuilder(
    column: $table.ledgerMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$FamilySpacesTableAnnotationComposer get familyId {
    final $$FamilySpacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familySpaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilySpacesTableAnnotationComposer(
            $db: $db,
            $table: $db.familySpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReconciliationChecksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReconciliationChecksTable,
          ReconciliationCheck,
          $$ReconciliationChecksTableFilterComposer,
          $$ReconciliationChecksTableOrderingComposer,
          $$ReconciliationChecksTableAnnotationComposer,
          $$ReconciliationChecksTableCreateCompanionBuilder,
          $$ReconciliationChecksTableUpdateCompanionBuilder,
          (ReconciliationCheck, $$ReconciliationChecksTableReferences),
          ReconciliationCheck,
          PrefetchHooks Function({bool familyId})
        > {
  $$ReconciliationChecksTableTableManager(
    _$AppDatabase db,
    $ReconciliationChecksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReconciliationChecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReconciliationChecksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ReconciliationChecksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String> updatedBy = const Value.absent(),
                Value<int> createdAtUs = const Value.absent(),
                Value<int> updatedAtUs = const Value.absent(),
                Value<int?> deletedAtUs = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> statementDate = const Value.absent(),
                Value<int> statementMinor = const Value.absent(),
                Value<int> ledgerMinor = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReconciliationChecksCompanion(
                id: id,
                familyId: familyId,
                revision: revision,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                deletedAtUs: deletedAtUs,
                accountId: accountId,
                statementDate: statementDate,
                statementMinor: statementMinor,
                ledgerMinor: ledgerMinor,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                Value<int> revision = const Value.absent(),
                required String createdBy,
                required String updatedBy,
                required int createdAtUs,
                required int updatedAtUs,
                Value<int?> deletedAtUs = const Value.absent(),
                required String accountId,
                required String statementDate,
                required int statementMinor,
                required int ledgerMinor,
                required String notes,
                Value<int> rowid = const Value.absent(),
              }) => ReconciliationChecksCompanion.insert(
                id: id,
                familyId: familyId,
                revision: revision,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                deletedAtUs: deletedAtUs,
                accountId: accountId,
                statementDate: statementDate,
                statementMinor: statementMinor,
                ledgerMinor: ledgerMinor,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReconciliationChecksTable, ReconciliationCheck>(
                    table,
                  ),
                  $$ReconciliationChecksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({familyId = false}) {
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
                    if (familyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.familyId,
                        referencedTable: $$ReconciliationChecksTableReferences
                            ._familyIdTable(db),
                        referencedColumn: $$ReconciliationChecksTableReferences
                            ._familyIdTable(db)
                            .id,
                      ) as T;
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

typedef $$ReconciliationChecksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReconciliationChecksTable,
      ReconciliationCheck,
      $$ReconciliationChecksTableFilterComposer,
      $$ReconciliationChecksTableOrderingComposer,
      $$ReconciliationChecksTableAnnotationComposer,
      $$ReconciliationChecksTableCreateCompanionBuilder,
      $$ReconciliationChecksTableUpdateCompanionBuilder,
      (ReconciliationCheck, $$ReconciliationChecksTableReferences),
      ReconciliationCheck,
      PrefetchHooks Function({bool familyId})
    >;
typedef $$VaultPreferencesTableCreateCompanionBuilder =
    VaultPreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$VaultPreferencesTableUpdateCompanionBuilder =
    VaultPreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$VaultPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $VaultPreferencesTable> {
  $$VaultPreferencesTableFilterComposer({
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
}

class $$VaultPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultPreferencesTable> {
  $$VaultPreferencesTableOrderingComposer({
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
}

class $$VaultPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultPreferencesTable> {
  $$VaultPreferencesTableAnnotationComposer({
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

class $$VaultPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultPreferencesTable,
          VaultPreference,
          $$VaultPreferencesTableFilterComposer,
          $$VaultPreferencesTableOrderingComposer,
          $$VaultPreferencesTableAnnotationComposer,
          $$VaultPreferencesTableCreateCompanionBuilder,
          $$VaultPreferencesTableUpdateCompanionBuilder,
          (
            VaultPreference,
            BaseReferences<
              _$AppDatabase,
              $VaultPreferencesTable,
              VaultPreference
            >,
          ),
          VaultPreference,
          PrefetchHooks Function()
        > {
  $$VaultPreferencesTableTableManager(
    _$AppDatabase db,
    $VaultPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => VaultPreferencesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => VaultPreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultPreferencesTable, VaultPreference>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $VaultPreferencesTable,
                    VaultPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultPreferencesTable,
      VaultPreference,
      $$VaultPreferencesTableFilterComposer,
      $$VaultPreferencesTableOrderingComposer,
      $$VaultPreferencesTableAnnotationComposer,
      $$VaultPreferencesTableCreateCompanionBuilder,
      $$VaultPreferencesTableUpdateCompanionBuilder,
      (
        VaultPreference,
        BaseReferences<_$AppDatabase, $VaultPreferencesTable, VaultPreference>,
      ),
      VaultPreference,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PendingMutationsTableTableManager get pendingMutations =>
      $$PendingMutationsTableTableManager(_db, _db.pendingMutations);
  $$SyncCheckpointsTableTableManager get syncCheckpoints =>
      $$SyncCheckpointsTableTableManager(_db, _db.syncCheckpoints);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
  $$FamilySpacesTableTableManager get familySpaces =>
      $$FamilySpacesTableTableManager(_db, _db.familySpaces);
  $$FamilyMembersTableTableManager get familyMembers =>
      $$FamilyMembersTableTableManager(_db, _db.familyMembers);
  $$VaultDevicesTableTableManager get vaultDevices =>
      $$VaultDevicesTableTableManager(_db, _db.vaultDevices);
  $$LedgerAccountsTableTableManager get ledgerAccounts =>
      $$LedgerAccountsTableTableManager(_db, _db.ledgerAccounts);
  $$LedgerJournalsTableTableManager get ledgerJournals =>
      $$LedgerJournalsTableTableManager(_db, _db.ledgerJournals);
  $$LedgerPostingsTableTableManager get ledgerPostings =>
      $$LedgerPostingsTableTableManager(_db, _db.ledgerPostings);
  $$LocalAuditEventsTableTableManager get localAuditEvents =>
      $$LocalAuditEventsTableTableManager(_db, _db.localAuditEvents);
  $$MonthlyBudgetsTableTableManager get monthlyBudgets =>
      $$MonthlyBudgetsTableTableManager(_db, _db.monthlyBudgets);
  $$ReconciliationChecksTableTableManager get reconciliationChecks =>
      $$ReconciliationChecksTableTableManager(_db, _db.reconciliationChecks);
  $$VaultPreferencesTableTableManager get vaultPreferences =>
      $$VaultPreferencesTableTableManager(_db, _db.vaultPreferences);
}
