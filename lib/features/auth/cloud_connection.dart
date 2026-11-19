import '../../core/errors/app_failure.dart';
import '../../core/security/vault_lifecycle.dart';
import '../../core/sync/live_sync.dart';
import '../../core/sync/sync_coordinator.dart';
import '../document_vault/document_key_grant.dart';
import '../document_vault/document_transport.dart';
import '../finance/data/ledger_replay.dart';
import 'cloud_access_gateway.dart';
import 'cloud_cache.dart';
import 'cloud_device_registration.dart';

Future<VaultSession> connectFamily({
  required CloudWorkspaceCache cache,
  required String familyId,
  required String memberId,
  required Future<void> Function(AppFailure) onRevoked,
  String? expectedDevice,
  bool rebuild = false,
}) async {
  final gateway = cache.registration.gateway;
  final user = gateway.userId;
  final authSession = gateway.sessionId;
  const denied = AppFailure(
    FailureCode.unauthorized,
    'Sign in to this family again.',
  );
  if (user == null || authSession == null) throw denied;
  final session = await cache.open(
    familyId,
    memberId,
    expectedDevice: expectedDevice,
    rebuild: rebuild,
  );
  try {
    final access = cache.access;
    access.requireSession(user, authSession);
    final localDevice = CloudDevice(session.identity, session.keys);
    final device = localDevice.proof;
    final documents = gateway.documentTransport(device);
    final ownKeys = documents == null
        ? null
        : await localDevice.publicIdentity();
    if (documents != null) {
      session.documents.attachSharing(
        documents,
        () => access.requireSession(user, authSession),
      );
    }
    (CloudJson, CloudDirectory)? documentDirectory;
    final replay = LedgerReplay(session.db, familyId);
    final worker = SyncCoordinator(
      db: session.db,
      identity: session.identity,
      transport: gateway.syncTransport(device),
      apply: replay.apply,
      refreshAccess: () async {
        documentDirectory = null;
        access.requireSession(user, authSession);
        try {
          final response = await gateway.workspace(device);
          final directory = CloudDirectory.verify(response, session.identity);
          access.requireSession(user, authSession);
          if (session.closed) throw denied;
          await session.db.transaction(() => directory.apply(session.db));
          await access.confirm(user, authSession, session.identity);
          documentDirectory = (response, directory);
        } on AppFailure catch (error) {
          if (error.code == FailureCode.network) {
            await access.allowOffline(user, authSession, session.identity);
          }
          rethrow;
        }
      },
    );
    session.attachSync(
      LiveSync(
        worker: worker,
        checkDocuments: documents == null
            ? null
            : () async {
                final snapshot = documentDirectory;
                if (snapshot == null) return;
                final (response, directory) = snapshot;
                final active = {
                  for (final member in directory.members)
                    if (member.active) member.id,
                };
                final keys = {
                  for (final row in cloudRows(response['devices']))
                    if (row['state'] == 'enrolled' || row['state'] == 'revoked')
                      cloudText(row, 'id'): DocumentDeviceKeys.fromJson(row),
                };
                final current = keys[device.deviceId];
                if (current == null ||
                    current.signing != ownKeys!.signing ||
                    current.exchange != ownKeys.exchange) {
                  throw const AppFailure(
                    FailureCode.integrity,
                    'Family document device keys could not be verified.',
                  );
                }
                await session.documents.synchronize(
                  DocumentRoster(keys, {
                    for (final peer in directory.devices)
                      if (peer.state == 'enrolled' &&
                          active.contains(peer.memberId))
                        peer.id: keys[peer.id]!,
                  }),
                );
              },
        revocations: gateway.identityChanges
            .where((id) => id != user)
            .map<void>((_) {}),
        onRevoked: (error) async {
          final closed = onRevoked(error);
          try {
            await access.revoke(user, session.identity);
          } catch (_) {
            // A locked cache still requires the same live Auth session.
          } finally {
            await closed;
          }
        },
      ),
    );
    return session;
  } catch (_) {
    await session.close();
    rethrow;
  }
}
