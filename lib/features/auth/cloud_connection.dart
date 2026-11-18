import '../../core/errors/app_failure.dart';
import '../../core/security/vault_lifecycle.dart';
import '../../core/sync/live_sync.dart';
import '../../core/sync/sync_coordinator.dart';
import '../finance/data/ledger_replay.dart';
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
    final device = CloudDevice(session.identity, session.keys).proof;
    final replay = LedgerReplay(session.db, familyId);
    final worker = SyncCoordinator(
      db: session.db,
      identity: session.identity,
      transport: gateway.syncTransport(device),
      apply: replay.apply,
      refreshAccess: () async {
        access.requireSession(user, authSession);
        try {
          final directory = CloudDirectory.verify(
            await gateway.workspace(device),
            session.identity,
          );
          access.requireSession(user, authSession);
          if (session.closed) throw denied;
          await session.db.transaction(() => directory.apply(session.db));
          await access.confirm(user, authSession, session.identity);
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
