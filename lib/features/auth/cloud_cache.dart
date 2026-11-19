import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/encrypted_connection.dart';
import '../../core/database/mutation_writer.dart';
import '../../core/errors/app_failure.dart';
import '../../core/security/vault_identity.dart';
import '../../core/security/vault_lifecycle.dart';
import '../../core/sync/database_record.dart';
import '../../core/sync/sync_coordinator.dart';
import '../finance/data/ledger_replay.dart';
import 'cloud_access_gateway.dart';
import 'cloud_cache_access.dart';
import 'cloud_device_registration.dart';

const _invalid = AppFailure(
  FailureCode.integrity,
  'Family cache verification failed. Existing files have been preserved.',
);

final _fileName = RegExp(
  r'^vault(?:-[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})?\.sqlite3$',
);

final class _CacheCatalog {
  const _CacheCatalog(this.ready, this.file, this.retained);
  factory _CacheCatalog.decode(String? raw) {
    if (raw == null || raw == 'initializing' || raw == 'ready') {
      return _CacheCatalog(raw == 'ready', 'vault.sqlite3', const []);
    }
    try {
      final json = jsonDecode(raw) as CloudJson;
      final file = json['file']! as String;
      final retained = (json['retained']! as List<Object?>).cast<String>();
      if (json['version'] == 1 &&
          _fileName.hasMatch(file) &&
          retained.every(_fileName.hasMatch) &&
          !retained.contains(file) &&
          retained.toSet().length == retained.length) {
        return _CacheCatalog(true, file, retained);
      }
    } catch (_) {
      // A corrupt manifest must leave every file available for recovery.
    }
    throw _invalid;
  }

  final bool ready;
  final String file;
  final List<String> retained;

  String replace(String next) => jsonEncode({
    'version': 1,
    'file': next,
    'retained': [...retained, file],
  });
}

/// Server-owned metadata needed for provenance and local foreign keys.
final class CloudDirectory {
  CloudDirectory._(this.family, this.members, this.devices);

  factory CloudDirectory.verify(CloudJson response, VaultIdentity identity) {
    CloudDeviceRegistration.verifyWorkspace(response, identity);
    final family = readDatabaseRecord(
      response['family']! as CloudJson,
      FamilySpace.fromJson,
    );
    final members = [
      for (final row in cloudRows(response['members']))
        readDatabaseRecord({
          ...row,
          'auth_user_id': null,
        }, FamilyMember.fromJson),
    ];
    final deviceRows = cloudRows(response['devices']);
    final devices = [
      for (final row in deviceRows)
        readDatabaseRecord({
          for (final field in [
            'id',
            'family_id',
            'member_id',
            'state',
            'created_at_us',
          ])
            field: row[field],
        }, VaultDevice.fromJson),
    ];
    final memberIds = members.map((member) => member.id).toSet();
    final deviceIds = devices.map((device) => device.id).toSet();
    if (family.id != identity.familyId ||
        family.mode != 'cloud' ||
        family.currency != 'INR' ||
        memberIds.length != members.length ||
        deviceIds.length != devices.length ||
        ![
          ...memberIds,
          ...deviceIds,
        ].every((id) => Uuid.isValidUUID(fromString: id)) ||
        members.any((member) => member.familyId != family.id) ||
        devices.any(
          (device) =>
              device.familyId != family.id ||
              !memberIds.contains(device.memberId),
        )) {
      throw _invalid;
    }
    if (!members.any(
          (member) =>
              member.id == identity.memberId &&
              member.active &&
              member.role == response['role'],
        ) ||
        !devices.any(
          (device) =>
              device.id == identity.deviceId &&
              device.memberId == identity.memberId &&
              device.state == 'enrolled',
        )) {
      throw const AppFailure(
        FailureCode.unauthorized,
        'The family has not approved this device.',
      );
    }
    return CloudDirectory._(family, members, devices);
  }

  final FamilySpace family;
  final List<FamilyMember> members;
  final List<VaultDevice> devices;

  Future<void> apply(AppDatabase db) async {
    final stored = await db.select(db.familySpaces).get();
    if (stored.any((row) => row.id != family.id || row.mode != 'cloud')) {
      throw _invalid;
    }
    await db.into(db.familySpaces).insertOnConflictUpdate(family);
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.familyMembers, members);
      batch.insertAllOnConflictUpdate(db.vaultDevices, devices);
    });
  }
}

/// Opens a separate encrypted projection after live enrollment verification.
final class CloudWorkspaceCache {
  CloudWorkspaceCache(
    this.registration, {
    required this.root,
    DateTime Function()? clock,
  }) : access = CloudCacheAccess(registration, clock: clock);
  final CloudDeviceRegistration registration;
  final Future<Directory> Function() root;
  final CloudCacheAccess access;

  static const _chartKinds = {
    'opening': 'equity',
    'reconciliation': 'equity',
    'asset_revaluation': 'equity',
    'capital_disposals': 'equity',
    'salary': 'income',
    'business_income': 'income',
    'rental': 'income',
    'other_income': 'income',
    'interest_received': 'income',
    'household': 'expense',
    'groceries': 'expense',
    'utilities': 'expense',
    'transport': 'expense',
    'shopping': 'expense',
    'medical': 'expense',
    'education': 'expense',
    'business_expense': 'expense',
    'other_expense': 'expense',
    'interest_paid': 'expense',
  };

  Future<VaultSession> open(
    String familyId,
    String memberId, {
    String? expectedDevice,
    bool rebuild = false,
  }) async {
    final gateway = registration.gateway;
    final user = gateway.userId;
    final authSession = gateway.sessionId;
    if (user == null || authSession == null) throw cloudAccessExpired;
    VaultSession? vault;
    try {
      return await registration.withVerifiedDevice(
        familyId,
        memberId,
        action: (device) async {
          final identity = device.identity;
          if (expectedDevice != null && identity.deviceId != expectedDevice) {
            throw cloudAccessExpired;
          }
          final proof = device.proof;
          CloudDirectory? metadata;
          List<CloudJson>? chart;
          try {
            await gateway.bind(proof);
            final response = await gateway.workspace(proof);
            metadata = CloudDirectory.verify(response, identity);
            final ownDevice = cloudRows(response['devices'])
                .singleWhere((row) => row['id'] == identity.deviceId);
            final publicKeys = await device.publicIdentity();
            if (ownDevice['signing_public'] != publicKeys.signing ||
                ownDevice['exchange_public'] != publicKeys.exchange ||
                ownDevice['fingerprint'] != publicKeys.fingerprint) {
              throw _invalid;
            }
            chart = await gateway.chart(proof);
          } on AppFailure catch (failure) {
            if (failure.code == FailureCode.unauthorized) {
              await access.revoke(user, identity);
            }
            if (failure.code != FailureCode.network) rethrow;
            if (rebuild) rethrow;
            await access.allowOffline(user, authSession, identity);
          }
          access.requireSession(user, authSession);
          vault = await _open(
            device,
            user,
            authSession,
            metadata,
            chart,
            rebuild: rebuild,
          );
          if (chart != null) {
            await access.confirm(user, authSession, identity, remember: true);
          }
          access.requireSession(user, authSession);
          return vault!;
        },
      );
    } catch (_) {
      await vault?.close();
      rethrow;
    }
  }

  Future<VaultSession> _open(
    CloudDevice device,
    String user,
    String authSession,
    CloudDirectory? metadata,
    List<CloudJson>? rows, {
    required bool rebuild,
  }) => storageBoundary(() async {
    final identity = device.identity;
    final scope = access.scope(user, identity);
    final directory = Directory(
      p.join((await root()).path, 'cloud-vaults', scope),
    );
    final catalog = 'familyvault.cache.$scope.v1';
    final raw = await registration.store.read(catalog);
    final slots = _CacheCatalog.decode(raw);
    if (!slots.ready && (rows == null || rebuild)) {
      throw cloudAccessExpired;
    }
    final existing = File(p.join(directory.path, slots.file));
    if (slots.ready && !await existing.exists()) throw _invalid;
    if (raw == null) {
      if (await directory.exists() && !await directory.list().isEmpty) {
        throw _invalid;
      }
      await registration.store.write(catalog, 'initializing');
    }
    await directory.create(recursive: true);
    final replacement = rebuild
        ? 'vault-${const Uuid().v4()}.sqlite3'
        : slots.file;
    final file = File(p.join(directory.path, replacement));
    final keys = device.keys.copy();
    final db = AppDatabase.encrypted(
      file: file,
      key: VaultDatabaseKey.fromBytes(keys.database),
    );
    final session = VaultSession(
      db: db,
      identity: identity,
      keys: keys,
      directory: directory,
    );
    try {
      await db.transaction(() async {
        if (rows != null) {
          await metadata!.apply(db);
          final chart = [
            for (final row in rows)
              readDatabaseRecord(row, LedgerAccount.fromJson),
          ];
          final definitions = {for (final row in chart) row.subtype: row.kind};
          if (_chartKinds.entries.any(
                (def) => definitions[def.key] != def.value,
              ) ||
              definitions.length != chart.length ||
              chart.any(
                (row) =>
                    !row.systemAccount ||
                    row.familyId != identity.familyId ||
                    row.id != session.ledger.chartId(row.subtype) ||
                    row.currency != 'INR' ||
                    row.deletedAtUs != null,
              )) {
            throw _invalid;
          }
          await db.batch(
            (batch) =>
                batch.insertAllOnConflictUpdate(db.ledgerAccounts, chart),
          );
        }
        await session.ledger.mutations.authorize();
      });
      if (rebuild) {
        final gateway = registration.gateway;
        final proof = device.proof;
        final replay = LedgerReplay(db, identity.familyId);
        final worker = SyncCoordinator(
          db: db,
          identity: identity,
          transport: gateway.syncTransport(proof),
          apply: replay.apply,
        );
        try {
          await worker.replayAll();
        } finally {
          await worker.stop();
        }
        final directory = CloudDirectory.verify(
          await gateway.workspace(proof),
          identity,
        );
        await db.transaction(() async {
          await directory.apply(db);
          await _restoreDocumentTransfers(existing, session);
        });
        await session.ledger.mutations.audit(
          operationId: const Uuid().v4(),
          entityType: 'sync_recovery',
          entityId: identity.familyId,
          action: 'restore',
          after: {'retained_device_history': true},
        );
      }
      final check = await db.customSelect('PRAGMA quick_check').getSingle();
      if (check.read<String>('quick_check') != 'ok') throw _invalid;
      access.requireSession(user, authSession);
      if (rebuild) {
        await registration.store.write(catalog, slots.replace(replacement));
      } else if (!slots.ready) {
        await registration.store.write(catalog, 'ready');
      }
      return session;
    } catch (_) {
      await session.close();
      rethrow;
    }
  });

  Future<void> _restoreDocumentTransfers(
    File source,
    VaultSession session,
  ) async {
    final previous = AppDatabase.encrypted(
      file: source,
      key: VaultDatabaseKey.fromBytes(session.keys.database),
    );
    try {
      await previous.customStatement('PRAGMA query_only = ON');
      final uploads = await previous
          .select(previous.vaultDocumentUploads)
          .get();
      final audit =
          await (previous.select(previous.localAuditEvents)..where(
                (t) => t.entityType.isIn([
                  'document',
                  'document_transfer',
                  'document_access',
                  'document_link',
                ]),
              ))
              .get();
      await session.db.batch((batch) {
        batch.insertAll(session.db.vaultDocumentUploads, uploads);
        batch.insertAll(session.db.localAuditEvents, audit);
      });
    } finally {
      await previous.close();
    }
  }

  Future<List<({PendingMutation local, SyncConflict? competing})>> savedChanges(
    VaultSession session,
  ) => storageBoundary(() async {
    final user = registration.gateway.userId,
        authSession = registration.gateway.sessionId;
    if (user == null ||
        authSession == null ||
        session.closed ||
        !session.identity.isCloud) {
      throw cloudAccessExpired;
    }
    final scope = access.scope(user, session.identity);
    if (p.basename(session.directory.path) != scope) throw cloudAccessExpired;
    final raw = await registration.store.read('familyvault.cache.$scope.v1');
    final slots = _CacheCatalog.decode(raw);
    final saved = <({PendingMutation local, SyncConflict? competing})>[];
    for (final file in slots.retained) {
      access.requireSession(user, authSession);
      final path = File(p.join(session.directory.path, file));
      if (!await path.exists()) throw _invalid;
      final db = AppDatabase.encrypted(
        file: path,
        key: VaultDatabaseKey.fromBytes(session.keys.database),
      );
      try {
        await db.customStatement('PRAGMA query_only = ON');
        final outbox = await db.select(db.pendingMutations).get();
        final conflicts = {
          for (final row in await db.select(db.syncConflicts).get())
            row.operationId: row,
        };
        for (final row in outbox.where(
          (row) =>
              row.familyId == session.identity.familyId &&
              row.state != 'acknowledged',
        )) {
          saved.add((local: row, competing: conflicts[row.operationId]));
        }
      } finally {
        await db.close();
      }
    }
    access.requireSession(user, authSession);
    if (session.closed) throw cloudAccessExpired;
    return saved;
  });
}
