import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../features/finance/data/ledger_repository.dart';
import '../database/app_database.dart';
import '../database/encrypted_connection.dart';
import '../errors/app_failure.dart';
import '../sync/live_sync.dart';
import 'device_gate.dart';
import 'secure_store.dart';
import 'vault_identity.dart';
import 'vault_keys.dart';

enum VaultPhase { loading, setup, locked, opening, open, unavailable }

final class VaultStatus {
  const VaultStatus(
    this.phase, {
    this.session,
    this.failure,
    this.hasVault = false,
  });
  final VaultPhase phase;
  final VaultSession? session;
  final AppFailure? failure;
  final bool hasVault;
}

final class VaultSession {
  VaultSession({
    required this.db,
    required this.identity,
    required this.keys,
    required this.directory,
  }) : ledger = LedgerRepository(db, identity);
  final AppDatabase db;
  final VaultIdentity identity;
  final VaultKeys keys;
  final Directory directory;
  final LedgerRepository ledger;
  LiveSync? _sync;
  LiveSync? get sync => _sync;
  bool closed = false;

  void attachSync(LiveSync sync) {
    if (closed || !identity.isCloud || _sync != null) {
      throw StateError('The connected session is unavailable');
    }
    _sync = sync;
  }

  Future<void> close() async {
    if (closed) {
      return;
    }
    closed = true;
    try {
      try {
        await _sync?.close();
      } finally {
        await db.close();
      }
    } finally {
      keys.destroy();
    }
  }

  @override
  String toString() => 'VaultSession([redacted])';
}

/// Owns native key/database lifetimes independently from widget navigation.
/// One OS-secure catalog write retains identity and keys before database creation.
/// Interrupted setup is resumed; a missing ready database is never recreated.
final class VaultLifecycle {
  VaultLifecycle({required this.store, required this.gate, required this.root});
  final SecureStore store;
  final DeviceGate gate;
  final Future<Directory> Function() root;
  static const catalogKey = 'familyvault.vault.catalog.v1';
  static const uuid = Uuid();
  final _events = StreamController<VaultStatus>.broadcast(sync: true);
  VaultStatus _status = const VaultStatus(VaultPhase.loading);
  VaultStatus get status => _status;
  Stream<VaultStatus> get changes => _events.stream;
  int _epoch = 0;
  bool _busy = false, _disposed = false;
  Future<void>? _closing;

  void _set(VaultStatus value) {
    if (_disposed) {
      return;
    }
    _status = value;
    _events.add(value);
  }

  Future<void> initialize() async {
    if (_busy || _disposed || _status.session != null) {
      return;
    }
    _busy = true;
    try {
      final saved = await _readCatalog();
      if (saved == null) {
        final vaults = Directory(p.join((await root()).path, 'vaults'));
        if (await vaults.exists() && await vaults.list().isEmpty == false) {
          throw const AppFailure(
            FailureCode.integrity,
            'Existing vault files were found without device keys. Restore with your recovery key.',
          );
        }
      }
      _set(
        VaultStatus(
          saved == null ? VaultPhase.setup : VaultPhase.locked,
          hasVault: saved != null,
        ),
      );
    } catch (error) {
      _set(VaultStatus(VaultPhase.unavailable, failure: _safe(error)));
    } finally {
      _busy = false;
    }
  }

  Future<Map<String, Object?>?> _readCatalog() async {
    final value = await store.read(catalogKey);
    if (value == null) {
      return null;
    }
    try {
      final result = jsonDecode(value) as Map<String, Object?>;
      if (result['version'] != 1 ||
          !['initializing', 'ready'].contains(result['state'])) {
        throw const FormatException();
      }
      final identity = VaultIdentity.fromJson(
        result['identity']! as Map<String, Object?>,
      );
      if (![
            identity.familyId,
            identity.memberId,
            identity.deviceId,
          ].every((id) => Uuid.isValidUUID(fromString: id)) ||
          !['offline', 'cloud'].contains(identity.mode)) {
        throw const FormatException();
      }
      return result;
    } catch (_) {
      throw const AppFailure(
        FailureCode.integrity,
        'The device vault catalog is invalid. Restore with your recovery key.',
      );
    }
  }

  Future<void> createOffline({
    required String familyName,
    required String ownerName,
  }) => _open(create: true, familyName: familyName, ownerName: ownerName);
  Future<void> unlock() => _open();

  Future<void> openConnected(Future<VaultSession> Function() open) async {
    if (_busy || _disposed || _status.session != null) {
      throw const AppFailure(
        FailureCode.locked,
        'Wait for the current vault action to finish.',
      );
    }
    _busy = true;
    final epoch = ++_epoch;
    final hasLocalVault = _status.hasVault;
    _set(VaultStatus(VaultPhase.opening, hasVault: hasLocalVault));
    VaultSession? candidate;
    try {
      await _closing;
      _checkEpoch(epoch);
      candidate = await open();
      _checkEpoch(epoch);
      if (!candidate.identity.isCloud ||
          candidate.closed ||
          candidate.sync == null) {
        throw const AppFailure(
          FailureCode.integrity,
          'Family access could not be verified.',
        );
      }
      _set(
        VaultStatus(
          VaultPhase.open,
          session: candidate,
          hasVault: hasLocalVault,
        ),
      );
      candidate.sync!.start();
      candidate = null;
    } catch (error) {
      if (epoch == _epoch) {
        _set(
          VaultStatus(
            hasLocalVault ? VaultPhase.locked : VaultPhase.setup,
            hasVault: hasLocalVault,
          ),
        );
      }
      throw _safe(error);
    } finally {
      await candidate?.close();
      _busy = false;
    }
  }

  Future<void> _open({
    bool create = false,
    String? familyName,
    String? ownerName,
  }) async {
    if (_busy || _disposed || _status.phase == VaultPhase.open) {
      return;
    }
    _busy = true;
    final epoch = ++_epoch;
    _set(VaultStatus(VaultPhase.opening, hasVault: _status.hasVault));
    VaultSession? candidate;
    VaultKeys? keys;
    try {
      await _closing;
      _checkEpoch(epoch);
      if (!await gate.authenticate()) {
        throw const AppFailure(
          FailureCode.locked,
          'Device verification was cancelled.',
        );
      }
      _checkEpoch(epoch);
      var catalog = await _readCatalog();
      _checkEpoch(epoch);
      if (create) {
        if (catalog != null) {
          throw const AppFailure(
            FailureCode.conflict,
            'A vault already exists. Unlock it to continue.',
          );
        }
        if (familyName == null ||
            ownerName == null ||
            familyName.trim().isEmpty ||
            ownerName.trim().isEmpty ||
            familyName.length > 80 ||
            ownerName.length > 80) {
          throw const AppFailure(
            FailureCode.validation,
            'Enter a vault name and your name (up to 80 characters).',
          );
        }
        final directory = Directory(p.join((await root()).path, 'vaults'));
        if (await directory.exists() &&
            await directory.list().isEmpty == false) {
          throw const AppFailure(
            FailureCode.integrity,
            'Existing vault files require recovery. They will be preserved.',
          );
        }
        keys = VaultKeys.generate();
        final identity = VaultIdentity(
          familyId: uuid.v4(),
          memberId: uuid.v4(),
          deviceId: uuid.v4(),
          mode: 'offline',
        );
        catalog = {
          'version': 1,
          'state': 'initializing',
          'identity': identity.toJson(),
          'keys': keys.toJson(),
          'initial_family_name': familyName.trim(),
          'initial_owner_name': ownerName.trim(),
        };
        _checkEpoch(epoch);
        await store.write(catalogKey, jsonEncode(catalog));
        _checkEpoch(epoch);
        _set(const VaultStatus(VaultPhase.opening, hasVault: true));
      }
      if (catalog == null) {
        throw const AppFailure(
          FailureCode.configuration,
          'Create or restore your vault first.',
        );
      }
      keys ??= VaultKeys.fromJson(catalog['keys']! as Map<String, Object?>);
      final identity = VaultIdentity.fromJson(
        catalog['identity']! as Map<String, Object?>,
      );
      final directory = Directory(
        p.join((await root()).path, 'vaults', identity.familyId),
      );
      final file = File(p.join(directory.path, 'vault.sqlite3'));
      if (catalog['state'] == 'ready' && !await file.exists()) {
        throw const AppFailure(
          FailureCode.integrity,
          'The vault database is missing. Restore an encrypted backup.',
        );
      }
      _checkEpoch(epoch);
      await directory.create(recursive: true);
      candidate = VaultSession(
        db: AppDatabase.encrypted(
          file: file,
          key: VaultDatabaseKey.fromBytes(keys.database),
        ),
        identity: identity,
        keys: keys,
        directory: directory,
      );
      if (catalog['state'] == 'initializing') {
        if (identity.isCloud) {
          throw const AppFailure(
            FailureCode.configuration,
            'Cloud enrollment requires server confirmation.',
          );
        }
        await candidate.ledger.createOfflineWorkspace(
          familyName: catalog['initial_family_name']! as String,
          ownerName: catalog['initial_owner_name']! as String,
        );
      }
      await candidate.ledger.mutations.authorize();
      final integrity = await candidate.db
          .customSelect('PRAGMA quick_check')
          .getSingle();
      if (integrity.read<String>('quick_check') != 'ok') {
        throw const AppFailure(
          FailureCode.integrity,
          'Vault integrity verification failed. Restore a verified backup.',
        );
      }
      _checkEpoch(epoch);
      if (catalog['state'] != 'ready') {
        catalog.remove('initial_family_name');
        catalog.remove('initial_owner_name');
        catalog['state'] = 'ready';
        await store.write(catalogKey, jsonEncode(catalog));
      }
      _checkEpoch(epoch);
      _set(VaultStatus(VaultPhase.open, session: candidate, hasVault: true));
      candidate = null;
      keys = null;
    } catch (error) {
      await candidate?.close();
      keys?.destroy();
      if (epoch == _epoch) {
        final safe = _safe(error);
        _set(
          VaultStatus(
            _status.hasVault ? VaultPhase.locked : VaultPhase.setup,
            hasVault: _status.hasVault,
            failure: safe,
          ),
        );
      }
    } finally {
      _busy = false;
    }
  }

  void _checkEpoch(int expected) {
    if (_disposed || _epoch != expected) {
      throw const AppFailure(
        FailureCode.locked,
        'The vault was locked. Unlock it again to continue.',
      );
    }
  }

  static AppFailure _safe(Object error) => error is AppFailure
      ? error
      : const AppFailure(
          FailureCode.storage,
          'Secure storage or the vault is unavailable. Existing files and keys are preserved.',
        );

  Future<void> lock({AppFailure? reason}) async {
    ++_epoch;
    final session = _status.session;
    _set(
      VaultStatus(
        _status.phase == VaultPhase.unavailable
            ? VaultPhase.unavailable
            : _status.hasVault
            ? VaultPhase.locked
            : VaultPhase.setup,
        hasVault: _status.hasVault,
        failure:
            reason ??
            (_status.phase == VaultPhase.unavailable ? _status.failure : null),
      ),
    );
    if (session != null) {
      final closing = session.close();
      _closing = closing;
      try {
        await closing;
      } finally {
        if (identical(_closing, closing)) _closing = null;
      }
    }
  }

  Future<void> dispose() async {
    ++_epoch;
    _disposed = true;
    await _closing;
    await _status.session?.close();
    await _events.close();
  }
}
