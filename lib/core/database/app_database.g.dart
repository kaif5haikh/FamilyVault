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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PendingMutationsTableTableManager get pendingMutations =>
      $$PendingMutationsTableTableManager(_db, _db.pendingMutations);
  $$SyncCheckpointsTableTableManager get syncCheckpoints =>
      $$SyncCheckpointsTableTableManager(_db, _db.syncCheckpoints);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
}
