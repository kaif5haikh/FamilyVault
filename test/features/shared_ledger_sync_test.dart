import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/vault_identity.dart';
import 'package:familyvault/core/sync/sync_coordinator.dart';
import 'package:familyvault/core/sync/sync_protocol.dart';
import 'package:familyvault/features/finance/data/ledger_replay.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../support/vault_fixture.dart';

class _ServerFixture {
  final history = <SyncJson>[];
  final accounts = <String, int>{};
  final received = <String>[];

  SyncJson accept(SyncEnvelope envelope) {
    received.add(envelope.operationId);
    for (final event in history) {
      if (event['operation_id'] == envelope.operationId) {
        if (event['payload_digest'] != envelope.digest) {
          throw syncIntegrityFailure;
        }
        return event;
      }
    }
    if (envelope.entityType == 'account') {
      if ((accounts[envelope.entityId] ?? 0) != envelope.baseRevision) {
        throw const AppFailure(
          FailureCode.conflict,
          'Synthetic stale revision',
        );
      }
      accounts[envelope.entityId] = envelope.record['revision']! as int;
    }
    final event = <String, Object?>{
      'operation_id': envelope.operationId,
      'sequence': history.length + 1,
      'payload_digest': envelope.digest,
      'payload_json': envelope.raw,
      'accepted_at_us': history.length + 1,
    };
    history.add(event);
    return event;
  }
}

class _Link implements SyncTransport {
  _Link(this.server);
  final _ServerFixture server;
  bool offline = false,
      loseReceipt = false,
      badReceipt = false,
      badPage = false;

  static const network = AppFailure(
    FailureCode.network,
    'Synthetic transport interruption',
  );

  @override
  Future<SyncReceipt> push(SyncEnvelope envelope) async {
    if (offline) throw network;
    final event = server.accept(envelope);
    if (loseReceipt) throw network;
    return SyncReceipt.fromJson({
      ...event,
      if (badReceipt) 'payload_digest': '0' * 64,
    });
  }

  @override
  Future<SyncPage> pull(int after) async {
    if (offline) throw network;
    final rows = server.history.skip(after).take(50).toList();
    return SyncPage.fromJson({
      'watermark': server.history.length,
      'changes': [
        for (final row in rows)
          if (badPage)
            {...row, 'sequence': (row['sequence']! as int) + 1}
          else
            row,
      ],
    });
  }
}

void main() {
  late VaultFixture a, b;
  late _ServerFixture server;
  late _Link linkA, linkB;
  late DateTime clock;
  late SyncCoordinator syncA, syncB;
  const uuid = Uuid();
  final originalWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(
    () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = originalWarning,
  );

  Matcher failure(FailureCode code) =>
      isA<AppFailure>().having((e) => e.code, 'code', code);

  SyncCoordinator client(
    VaultFixture vault,
    _Link link, {
    Future<void> Function(SyncChange)? apply,
  }) => SyncCoordinator(
    db: vault.db,
    identity: vault.identity,
    transport: link,
    apply: apply ?? LedgerReplay(vault.db, vault.identity.familyId).apply,
    clock: () => clock,
  );

  setUp(() async {
    final family = uuid.v4();
    VaultIdentity member() => VaultIdentity(
      familyId: family,
      memberId: uuid.v4(),
      deviceId: uuid.v4(),
      mode: 'cloud',
    );
    final members = [member(), member()];
    a = await VaultFixture.create(bootstrap: false, identity: members.first);
    b = await VaultFixture.create(bootstrap: false, identity: members.last);
    for (final vault in [a, b]) {
      final db = vault.db;
      await db
          .into(db.familySpaces)
          .insert(
            FamilySpacesCompanion.insert(
              id: family,
              name: 'Synthetic family',
              mode: 'cloud',
              createdAtUs: 1,
            ),
          );
      for (final person in members) {
        await db
            .into(db.familyMembers)
            .insert(
              FamilyMembersCompanion.insert(
                id: person.memberId,
                familyId: family,
                displayName: 'Synthetic member',
                relationship: 'member',
                role: 'member',
                createdAtUs: 1,
              ),
            );
        await db
            .into(db.vaultDevices)
            .insert(
              VaultDevicesCompanion.insert(
                id: person.deviceId,
                familyId: family,
                memberId: person.memberId,
                state: 'enrolled',
                createdAtUs: 1,
              ),
            );
      }
      for (final (code, kind) in [
        ('opening', 'equity'),
        ('reconciliation', 'equity'),
        ('salary', 'income'),
        ('groceries', 'expense'),
      ]) {
        await db
            .into(db.ledgerAccounts)
            .insert(
              LedgerAccountsCompanion.insert(
                id: vault.ledger.chartId(code),
                familyId: family,
                name: code,
                kind: kind,
                subtype: code,
                createdBy: members.first.memberId,
                updatedBy: members.first.memberId,
                createdAtUs: 1,
                updatedAtUs: 1,
                systemAccount: const Value(true),
              ),
            );
      }
    }
    clock = DateTime.utc(2026, 11, 18);
    server = _ServerFixture();
    linkA = _Link(server);
    linkB = _Link(server);
    syncA = client(a, linkA);
    syncB = client(b, linkB);
  });
  tearDown(() async {
    await syncA.stop();
    await syncB.stop();
    await a.dispose();
    await b.dispose();
  });

  Future<List<PendingMutation>> outbox(VaultFixture vault) =>
      vault.db.select(vault.db.pendingMutations).get();
  Future<int> cursor(VaultFixture vault) async =>
      (await vault.db.select(vault.db.syncCheckpoints).getSingleOrNull())
          ?.lastSequence ??
      0;
  Future<LedgerAccount> account(VaultFixture vault, {int amount = 0}) =>
      vault.ledger.createAccount(
        name: 'Synthetic bank',
        kind: AccountKind.asset,
        subtype: 'bank',
        openingBalance: Money.fromMinor(amount),
      );

  test('isolated offline writes replay exactly after a lost receipt and include corrections', () async {
    const opening = 9007199254740993;
    final bank = await account(a, amount: opening);
    final salary = a.ledger.chartId('salary');
    final journal = await a.ledger.recordTransaction(
      kind: EntryKind.income,
      accountId: bank.id,
      counterAccountId: salary,
      amount: Money.fromMinor(500),
      occurredOn: '2026-11-18',
      description: 'Synthetic receipt',
    );
    linkA.offline = true;
    await expectLater(syncA.run(), throwsA(failure(FailureCode.network)));
    expect(server.history, isEmpty);
    expect(
      (await outbox(a)).any((row) => row.state == 'acknowledged'),
      isFalse,
    );

    clock = clock.add(const Duration(minutes: 2));
    linkA.offline = false;
    linkA.loseReceipt = true;
    await expectLater(syncA.run(), throwsA(failure(FailureCode.network)));
    expect(server.history, hasLength(1));
    expect(await cursor(a), 0);
    expect(
      (await outbox(a)).any((row) => row.state == 'acknowledged'),
      isFalse,
    );
    await syncB.run();
    expect(
      (await b.ledger.snapshot()).balances()[bank.id],
      BigInt.from(opening),
    );

    clock = clock.add(const Duration(minutes: 2));
    linkA.loseReceipt = false;
    await syncA.run();
    await syncB.run();
    expect(server.received[0], server.received[1]);
    expect(await cursor(a), 2);
    expect(await cursor(b), 2);
    expect(
      (await outbox(a)).every((row) => row.state == 'acknowledged'),
      isTrue,
    );

    await b.ledger.correct(
      journal,
      kind: EntryKind.income,
      accountId: bank.id,
      counterAccountId: salary,
      amount: Money.fromMinor(450),
      occurredOn: '2026-11-18',
      description: 'Synthetic correction',
      reason: 'Correct statement amount',
    );
    await syncB.run();
    await syncA.run();
    expect(await cursor(a), 3);
    for (final vault in [a, b]) {
      final snapshot = await vault.ledger.snapshot();
      expect(snapshot.journals, hasLength(4));
      expect(
        snapshot.balances()[bank.id],
        BigInt.from(opening) + BigInt.from(450),
      );
      final original = (await vault.ledger.detail(journal)).journal;
      expect(original.createdBy, a.identity.memberId);
      expect(original.updatedBy, b.identity.memberId);
      expect(original.deletedAtUs, isNotNull);
    }
  });

  test(
    'competing offline edits retain both snapshots and stop dependent delivery',
    () async {
      final bank = await account(a);
      await syncA.run();
      await syncB.run();
      await a.ledger.renameAccount(bank.id, 'Synthetic accepted name', 1);
      await b.ledger.renameAccount(bank.id, 'Synthetic competing name', 1);
      await account(b);
      await syncA.run();
      await expectLater(syncB.run(), throwsA(failure(FailureCode.conflict)));
      expect(await cursor(b), 1);
      expect(server.history, hasLength(2));
      expect(
        (await b.ledger.account(bank.id)).name,
        'Synthetic competing name',
      );
      final conflict = await b.db.select(b.db.syncConflicts).getSingle();
      expect(conflict.serverRevision, 2);
      expect(conflict.serverSnapshotJson, contains('Synthetic accepted name'));
      expect(
        (await outbox(b)).map((row) => row.state),
        unorderedEquals(['conflicted', 'pending']),
      );
    },
  );

  test('bad receipt, skipped sequence and interrupted page cannot advance local confirmation', () async {
    final first = await account(a);
    final second = await account(a);
    linkA.badReceipt = true;
    await expectLater(syncA.run(), throwsA(failure(FailureCode.integrity)));
    expect(await cursor(a), 0);
    expect(
      (await outbox(a)).any((row) => row.state == 'acknowledged'),
      isFalse,
    );
    clock = clock.add(const Duration(minutes: 2));
    linkA.badReceipt = false;
    await syncA.run();
    linkB.badPage = true;
    await expectLater(syncB.run(), throwsA(failure(FailureCode.integrity)));
    expect(await cursor(b), 0);
    final replay = LedgerReplay(b.db, b.identity.familyId);
    final interrupted = client(
      b,
      linkB,
      apply: (change) async {
        await replay.apply(change);
        if (change.receipt.sequence == 2) throw _Link.network;
      },
    );
    linkB.badPage = false;
    await expectLater(interrupted.run(), throwsA(failure(FailureCode.network)));
    expect(await cursor(b), 0);
    expect(
      (await b.ledger.snapshot()).accounts.any(
        (row) => row.id == first.id || row.id == second.id,
      ),
      isFalse,
    );
    await interrupted.stop();
    await syncB.run();
    expect(await cursor(b), 2);
    expect((await b.ledger.account(first.id)).id, first.id);
    expect((await b.ledger.account(second.id)).id, second.id);
  });

  test('new worker recovers a request committed just before a crash', () async {
    await account(a, amount: 123);
    final row = (await outbox(a)).single;
    await (a.db.update(
      a.db.pendingMutations,
    )..where((t) => t.operationId.equals(row.operationId))).write(
      PendingMutationsCompanion(
        state: const Value('in_flight'),
        attempts: const Value(1),
        leaseExpiresAtUs: Value(
          clock.add(const Duration(minutes: 1)).microsecondsSinceEpoch,
        ),
      ),
    );
    server.accept(SyncEnvelope.verify(row.payloadJson, row.payloadDigest));
    await syncA.stop();
    syncA = client(a, linkA);
    await syncA.run();
    expect((await outbox(a)).single.state, 'acknowledged');
    expect((await outbox(a)).single.acceptedRevision, 1);
    expect((await a.ledger.snapshot()).journals, hasLength(1));
    expect(server.received, hasLength(1));
  });
}
