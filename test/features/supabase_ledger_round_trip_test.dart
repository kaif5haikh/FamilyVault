import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/vault_identity.dart';
import 'package:familyvault/core/sync/database_record.dart';
import 'package:familyvault/core/sync/sync_coordinator.dart';
import 'package:familyvault/features/auth/cloud_access_gateway.dart';
import 'package:familyvault/features/auth/cloud_cache.dart';
import 'package:familyvault/features/finance/data/ledger_replay.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/vault_fixture.dart';

void main() {
  final fixturePath = Platform.environment['FAMILYVAULT_TEST_SUPABASE_FIXTURE'];
  test(
    'two Dart clients exchange exact paise through the local Data API',
    () async {
      final fixture =
          jsonDecode(await File(fixturePath!).readAsString()) as CloudJson;
      final url = Uri.parse(cloudText(fixture, 'url'));
      expect(url.scheme, 'http');
      expect(url.host, '127.0.0.1');
      final family = cloudText(fixture, 'family');
      final originalWarning =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            originalWarning,
      );
      final clients = <({VaultFixture vault, SyncCoordinator sync})>[];
      for (final user in cloudRows(fixture['users'])) {
        final client = SupabaseClient(
          url.toString(),
          'synthetic-local-client',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);
        final gateway = SupabaseAccessGateway(client);
        await gateway.signIn(
          cloudText(user, 'email'),
          cloudText(user, 'password'),
        );
        expect(gateway.sessionId, isA<String>());
        final device = DeviceProof(
          cloudText(user, 'p_device'),
          cloudText(user, 'p_proof'),
        );
        await gateway.bind(device);
        final workspace = await gateway.workspace(device);
        final identity = VaultIdentity(
          familyId: family,
          memberId: cloudText(workspace, 'member_id'),
          deviceId: device.deviceId,
          mode: 'cloud',
        );
        final vault = await VaultFixture.create(
          bootstrap: false,
          identity: identity,
        );
        addTearDown(vault.dispose);
        final metadata = CloudDirectory.verify(workspace, identity);
        final chart = await gateway.chart(device);
        await vault.db.transaction(() async {
          await metadata.apply(vault.db);
          await vault.db.batch(
            (batch) => batch.insertAll(vault.db.ledgerAccounts, [
              for (final row in chart)
                readDatabaseRecord(row, LedgerAccount.fromJson),
            ]),
          );
        });
        final sync = SyncCoordinator(
          db: vault.db,
          identity: identity,
          transport: gateway.syncTransport(device),
          apply: LedgerReplay(vault.db, family).apply,
        );
        addTearDown(sync.stop);
        await sync.run();
        clients.add((vault: vault, sync: sync));
      }
      final first = clients.first, second = clients.last;
      expect(
        first.vault.identity.memberId == second.vault.identity.memberId,
        isFalse,
      );
      const amount = 9007199254740993;
      final account = await first.vault.ledger.createAccount(
        name: 'Synthetic mobile bank',
        kind: AccountKind.asset,
        subtype: 'bank',
        openingBalance: Money.fromMinor(amount),
      );
      await first.sync.run();
      await second.sync.run();
      final posted = (await second.vault.ledger.snapshot())
          .balances()[account.id];
      expect(posted, BigInt.from(amount));
      final received = await second.vault.ledger.account(account.id);
      expect(received.createdBy, first.vault.identity.memberId);
      await second.vault.ledger.renameAccount(
        account.id,
        'Synthetic member edit',
        received.revision,
      );
      await second.sync.run();
      await first.sync.run();
      final renamed = await first.vault.ledger.account(account.id);
      expect(renamed.name, 'Synthetic member edit');
      expect(renamed.createdBy, first.vault.identity.memberId);
      expect(renamed.updatedBy, second.vault.identity.memberId);
      for (final client in clients) {
        final outbox = await client.vault.db
            .select(client.vault.db.pendingMutations)
            .get();
        expect(outbox.single.state, 'acknowledged');
        expect(outbox.single.acceptedRevision, greaterThan(0));
      }
    },
    skip: fixturePath == null
        ? 'Start the isolated provider check with --mobile'
        : false,
  );
}
