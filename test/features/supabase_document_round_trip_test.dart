import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/vault_identity.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/auth/cloud_access_gateway.dart';
import 'package:familyvault/features/auth/cloud_cache.dart';
import 'package:familyvault/features/auth/cloud_connection.dart';
import 'package:familyvault/features/auth/cloud_device_registration.dart';
import 'package:familyvault/features/document_vault/document_repository.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/security_fakes.dart';

void main() {
  final fixturePath = Platform.environment['FAMILYVAULT_TEST_DOCUMENT_FIXTURE'];
  test(
    'Dart devices share encrypted versions through Storage, recover a lost reply and share old keys',
    () async {
      final fixture =
          jsonDecode(await File(fixturePath!).readAsString()) as CloudJson;
      final url = Uri.parse(cloudText(fixture, 'url'));
      expect(url.scheme, 'http');
      expect(url.host, '127.0.0.1');
      final family = cloudText(fixture, 'family');
      final parent = await Directory('.cache/test-vaults')
          .create(recursive: true);
      final root = await parent.createTemp('document-provider-');
      addTearDown(() => root.delete(recursive: true));
      final previousWarning =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            previousWarning,
      );

      Future<Future<VaultSession> Function()> clientFor(CloudJson user) async {
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
        final identity = VaultIdentity(
          familyId: family,
          memberId: cloudText(user, 'member_id'),
          deviceId: cloudText(user, 'p_device'),
          mode: 'cloud',
        );
        final store = MemorySecureStore();
        final registration = CloudDeviceRegistration(
          store: store,
          gate: FakeDeviceGate(),
          gateway: gateway,
          namespace: 'provider-test',
        );
        await store.write(
          registration.profileKey(gateway.userId!, family),
          jsonEncode({'identity': identity.toJson(), 'keys': user['keys']}),
        );
        final directory = await root.createTemp('replica-');
        final cache = CloudWorkspaceCache(
          registration,
          root: () async => directory,
        );
        return () async {
          final session = await connectFamily(
            cache: cache,
            familyId: family,
            memberId: identity.memberId,
            onRevoked: (_) =>
                fail('The synthetic approved session was revoked.'),
          );
          addTearDown(session.close);
          return session;
        };
      }

      final users = cloudRows(fixture['users']);
      final reopenOwner = await clientFor(users.first);
      var owner = await reopenOwner();
      final receiver = await (await clientFor(users.last))();
      final bytes = Uint8List.fromList([
        ...ascii.encode('%PDF-1.4\nSynthetic test content\n'),
        ...List<int>.filled(300 * 1024, 65),
        ...ascii.encode('\n%%EOF'),
      ]);
      final file = await File('${root.path}/sample.pdf').writeAsBytes(bytes);
      final staged = await owner.documents.add(
        details: DocumentDetails(
          title: 'Synthetic family document',
          category: DocumentCategory.education,
          ownerId: receiver.identity.memberId,
          expiryOn: '2031-06-15',
        ),
        source: file,
      );
      expect(await owner.documents.watch().first, isEmpty);
      expect(
        await owner.documents.read(
          staged.documentId,
          staged.id,
          DocumentAccess.preview,
        ),
        bytes,
      );
      final pending = (await owner.documents.watchUploads().first).single;
      await owner.sync!.check();
      expect(owner.sync!.status.documentFailure?.code, FailureCode.network);
      expect(
        (await owner.documents.watchUploads().first).single.state,
        'pending',
      );

      await receiver.sync!.check();
      expect(receiver.sync!.status.documentFailure?.code, isNull);
      final shared = await receiver.documents.document(staged.documentId);
      expect(shared.title, 'Synthetic family document');
      expect(shared.createdBy, owner.identity.memberId);
      expect(shared.ownerId, receiver.identity.memberId);
      expect(shared.category, 'education');
      expect(shared.expiryOn, '2031-06-15');
      expect(await receiver.documents.ciphertext(staged.id).exists(), isFalse);
      expect(
        await receiver.documents.read(
          staged.documentId,
          staged.id,
          DocumentAccess.preview,
        ),
        bytes,
      );
      expect(await receiver.documents.ciphertext(staged.id).exists(), isTrue);

      await owner.close();
      owner = await reopenOwner();
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      await owner.sync!.check();
      expect(owner.sync!.status.documentFailure?.code, isNull);
      final receipt = await owner.db
          .select(owner.db.vaultDocumentUploads)
          .getSingle();
      expect(receipt.operationId, pending.operationId);
      expect(receipt.state, 'acknowledged');
      expect(await owner.documents.watchUploads().first, isEmpty);
      expect(await owner.documents.versions(staged.documentId), hasLength(1));

      final accepted = await owner.documents.addVersion(
        staged.documentId,
        1,
        file,
      );
      final competing = await receiver.documents.addVersion(
        staged.documentId,
        1,
        file,
      );
      await owner.sync!.check();
      expect(owner.sync!.status.documentFailure?.code, isNull);
      await receiver.sync!.check();
      expect(receiver.sync!.status.documentFailure?.code, isNull);
      expect(
        (await receiver.documents.versions(staged.documentId))
            .map((item) => item.id),
        [accepted.id, staged.id],
      );
      expect(
        (await receiver.documents.watchUploads().first).single.state,
        'conflicted',
      );
      expect(
        await receiver.documents.read(
          staged.documentId,
          competing.id,
          DocumentAccess.preview,
        ),
        bytes,
      );

      await receiver.documents.update(
        staged.documentId,
        2,
        DocumentDetails(
          title: 'Synthetic renamed document',
          category: DocumentCategory.general,
          ownerId: owner.identity.memberId,
        ),
      );
      expect(
        (await receiver.documents.watchDocumentEdits().first).single.state,
        'pending',
      );
      await expectLater(
        receiver.documents.addVersion(staged.documentId, 2, file),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', FailureCode.conflict),
        ),
      );
      await owner.documents.archive(staged.documentId, 2);
      await receiver.sync!.check();
      expect(receiver.sync!.status.documentFailure?.code, isNull);
      expect(await receiver.documents.watchDocumentEdits().first, isEmpty);
      await owner.sync!.check();
      final renamed = await owner.documents.document(staged.documentId);
      expect(renamed.revision, 3);
      expect(renamed.title, 'Synthetic renamed document');
      expect(renamed.ownerId, owner.identity.memberId);
      expect(renamed.updatedBy, receiver.identity.memberId);
      expect(
        (await owner.documents.watchDocumentEdits().first).single.state,
        'conflicted',
      );
      await owner.documents.archive(staged.documentId, 3);
      await owner.sync!.check();
      expect(owner.sync!.status.documentFailure?.code, isNull);
      expect(await owner.documents.watch().first, isEmpty);
      expect(
        (await owner.documents.watch(archived: true).first).single.revision,
        4,
      );

      final http = HttpClient();
      addTearDown(() => http.close(force: true));
      final response = await (await http.postUrl(
        url.resolve('/__fixture/approve_late'),
      )).close();
      expect(response.statusCode, 204);
      await response.drain<void>();
      final later = await (await clientFor(
        fixture['late_device']! as CloudJson,
      ))();
      await later.sync!.check();
      expect(
        later.sync!.status.documentFailure?.code,
        FailureCode.configuration,
      );
      expect(await later.documents.watch().first, isEmpty);

      await owner.sync!.check();
      await later.sync!.check();
      expect(later.sync!.status.documentFailure?.code, isNull);
      expect(
        (await later.documents.watch(archived: true).first).single.revision,
        4,
      );
      expect(
        (await later.documents.versions(staged.documentId))
            .map((item) => item.id),
        [accepted.id, staged.id],
      );
      expect(
        await later.documents.read(
          staged.documentId,
          staged.id,
          DocumentAccess.download,
        ),
        bytes,
      );
      await later.documents.archive(staged.documentId, 4, restore: true);
      await later.sync!.check();
      await receiver.sync!.check();
      expect(receiver.sync!.status.documentFailure?.code, isNull);
      expect((await receiver.documents.watch().first).single.revision, 5);
      expect(
        await receiver.documents.versions(staged.documentId),
        hasLength(2),
      );
      final cash = await receiver.ledger.createAccount(
        name: 'Synthetic attachment account',
        kind: AccountKind.asset,
        subtype: 'cash',
        openingBalance: Money.fromMinor(4123),
      );
      final journal = (await receiver.ledger.snapshot()).postings
          .firstWhere((p) => p.accountId == cash.id)
          .journalId;
      final link = await receiver.documents.link(
        staged.documentId,
        journalId: journal,
      );
      expect(await receiver.documents.links(staged.documentId), isEmpty);
      await receiver.sync!.check();
      expect(receiver.sync!.status.documentFailure?.code, isNull);
      expect(
        (await receiver.documents.links(staged.documentId)).single.id,
        link,
      );
      await later.sync!.check();
      expect(
        (await later.documents.watchLinked(journalId: journal).first).single.id,
        staged.documentId,
      );
      expect(
        (await later.documents.links(staged.documentId)).single.createdBy,
        receiver.identity.memberId,
      );

      await later.documents.unlink(link);
      await later.sync!.check();
      expect(
        await later.documents.watchLinked(journalId: journal).first,
        isEmpty,
      );
      final relinked = await later.documents.link(
        staged.documentId,
        journalId: journal,
      );
      expect(relinked, isNot(link));
      await later.sync!.check();
      await receiver.sync!.check();
      expect(receiver.sync!.status.documentFailure?.code, isNull);
      expect(
        (await receiver.documents.links(staged.documentId)).single.id,
        relinked,
      );
      final history = await receiver.db
          .select(receiver.db.vaultDocumentLinks)
          .get();
      expect(history.singleWhere((row) => row.id == link).revision, 2);
      expect(
        (await receiver.ledger.snapshot()).balances()[cash.id],
        BigInt.from(4123),
      );
      final replacement = await receiver.documents.retryDraft(
        staged.documentId,
        competing.id,
        8,
      );
      expect(
        (await receiver.documents.watchUploads().first).single.id,
        replacement.id,
      );
      await receiver.sync!.check();
      await later.sync!.check();
      expect(later.sync!.status.documentFailure?.code, isNull);
      expect(
        (await later.documents.versions(staged.documentId)).map((v) => v.id),
        [replacement.id, accepted.id, staged.id],
      );
      expect(await receiver.documents.watchUploads().first, isEmpty);
      expect(
        await receiver.documents.read(
          staged.documentId,
          competing.id,
          DocumentAccess.preview,
        ),
        bytes,
      );
    },
    skip: fixturePath == null
        ? 'Start the isolated provider check with --mobile --storage'
        : false,
  );
}
