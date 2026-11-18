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
import 'cloud_access_gateway.dart';
import 'cloud_cache_access.dart';
import 'cloud_device_registration.dart';

const _invalid = AppFailure(
  FailureCode.integrity,
  'Family cache verification failed. Existing files have been preserved.',
);

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
            await access.allowOffline(user, authSession, identity);
          }
          access.requireSession(user, authSession);
          vault = await _open(device, user, metadata, chart);
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
    CloudDirectory? metadata,
    List<CloudJson>? rows,
  ) => storageBoundary(() async {
    final identity = device.identity;
    final scope = access.scope(user, identity);
    final directory = Directory(
      p.join((await root()).path, 'cloud-vaults', scope),
    );
    final file = File(p.join(directory.path, 'vault.sqlite3'));
    final catalog = 'familyvault.cache.$scope.v1';
    final state = await registration.store.read(catalog);
    if (rows == null && state != 'ready') throw cloudAccessExpired;
    if (state == null) {
      if (await directory.exists() && !await directory.list().isEmpty) {
        throw _invalid;
      }
      await registration.store.write(catalog, 'initializing');
    } else if (state == 'ready') {
      if (!await file.exists()) throw _invalid;
    } else if (state != 'initializing') {
      throw _invalid;
    }
    await directory.create(recursive: true);
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
      final check = await db.customSelect('PRAGMA quick_check').getSingle();
      if (check.read<String>('quick_check') != 'ok') throw _invalid;
      if (state != 'ready') await registration.store.write(catalog, 'ready');
      return session;
    } catch (_) {
      await session.close();
      rethrow;
    }
  });
}
