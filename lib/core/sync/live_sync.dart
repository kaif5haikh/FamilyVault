import 'dart:async';

import 'package:drift/drift.dart';

import '../errors/app_failure.dart';
import 'sync_coordinator.dart';

final class SyncFeedback {
  const SyncFeedback({this.checking = false, this.pending, this.failure});
  final bool checking;
  final int? pending;
  final AppFailure? failure;
}

/// Foreground polling recovers from missed notifications and connectivity loss.
/// This object lives only as long as the unlocked vault session.
final class LiveSync {
  LiveSync({
    required this.worker,
    required this.revocations,
    required this.onRevoked,
  });
  final SyncCoordinator worker;
  final Stream<void> revocations;
  final Future<void> Function(AppFailure) onRevoked;
  final _events = StreamController<SyncFeedback>.broadcast();
  SyncFeedback _status = const SyncFeedback();
  SyncFeedback get status => _status;
  Stream<SyncFeedback> get changes => _events.stream;
  Timer? _timer;
  StreamSubscription<void>? _subscription;
  bool _checking = false, _closed = false;

  void start() {
    if (_closed || _timer != null) return;
    _subscription = revocations.listen((_) {
      unawaited(
        onRevoked(
          const AppFailure(
            FailureCode.unauthorized,
            'Family access changed. Verify your account again.',
          ),
        ),
      );
    }, onError: (Object _) {});
    _timer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => unawaited(check()),
    );
    unawaited(check());
  }

  Future<void> check() async {
    if (_closed || _checking) return;
    _checking = true;
    _publish(SyncFeedback(checking: true, pending: _status.pending));
    AppFailure? failure;
    try {
      await worker.run();
    } on AppFailure catch (error) {
      failure = error;
    }
    if (_closed) return;
    if (failure?.code == FailureCode.unauthorized) {
      await onRevoked(failure!);
      return;
    }
    try {
      final db = worker.db;
      final row = await db
          .customSelect(
            "SELECT count(*) AS total FROM pending_mutations WHERE family_id = ? AND state <> 'acknowledged'",
            variables: [Variable(worker.identity.familyId)],
            readsFrom: {db.pendingMutations},
          )
          .getSingle();
      _publish(SyncFeedback(failure: failure, pending: row.read<int>('total')));
    } catch (_) {
      _publish(
        const SyncFeedback(
          failure: AppFailure(
            FailureCode.storage,
            'Sync status is unavailable.',
          ),
        ),
      );
    } finally {
      _checking = false;
    }
  }

  void _publish(SyncFeedback value) {
    if (_closed) return;
    _status = value;
    _events.add(value);
  }

  Future<void> close() async {
    _closed = true;
    _timer?.cancel();
    await _subscription?.cancel();
    await worker.stop();
    await _events.close();
  }
}
