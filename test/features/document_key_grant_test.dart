import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/security/sealed_file.dart';
import 'package:familyvault/core/security/vault_identity.dart';
import 'package:familyvault/core/security/vault_keys.dart';
import 'package:familyvault/features/auth/cloud_device_registration.dart';
import 'package:familyvault/features/document_vault/document_key_grant.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('signed grants are bound to a recipient, version and family', () async {
    const uuid = Uuid();
    final family = uuid.v4(), document = uuid.v4(), version = uuid.v4();
    final first = VaultKeys.generate(),
        second = VaultKeys.generate(),
        other = VaultKeys.generate();
    addTearDown(first.destroy);
    addTearDown(second.destroy);
    addTearDown(other.destroy);
    Future<DocumentDeviceKeys> published(VaultKeys keys) async {
      final id = uuid.v4();
      final public = await CloudDevice(
        VaultIdentity(
          familyId: family,
          deviceId: id,
          memberId: uuid.v4(),
          mode: 'cloud',
        ),
        keys,
      ).publicIdentity();
      return DocumentDeviceKeys(
        id: id,
        signing: public.signing,
        exchange: public.exchange,
      );
    }

    final sender = await published(first), recipient = await published(second);
    final contentKey = SecretKeyData(
      SealedFile.randomBytes(32),
      overwriteWhenDestroyed: true,
    );
    addTearDown(contentKey.destroy);
    final grant = await DocumentKeyGrant.create(
      familyId: family,
      documentId: document,
      versionId: version,
      senderId: sender.id,
      senderKeys: first,
      recipient: recipient,
      contentKey: contentKey,
    );
    Future<SecretKeyData> open(
      DocumentKeyGrant envelope, {
      VaultKeys? signer,
      String? scope,
      String? fileVersion,
      DocumentDeviceKeys? claimed,
    }) => envelope.open(
      familyId: scope ?? family,
      documentId: document,
      versionId: fileVersion ?? version,
      sender: claimed ?? sender,
      recipientId: recipient.id,
      recipientKeys: signer ?? second,
    );
    final recovered = await open(grant);
    addTearDown(recovered.destroy);
    expect(
      hash.sha256.convert(recovered.bytes),
      hash.sha256.convert(contentKey.bytes),
    );
    final invalid = isA<AppFailure>().having(
      (error) => error.code,
      'code',
      FailureCode.integrity,
    );
    await expectLater(open(grant, signer: other), throwsA(invalid));
    await expectLater(open(grant, scope: uuid.v4()), throwsA(invalid));
    await expectLater(open(grant, fileVersion: uuid.v4()), throwsA(invalid));
    await expectLater(
      open(
        grant,
        claimed: DocumentDeviceKeys(
          id: sender.id,
          signing: recipient.signing,
          exchange: sender.exchange,
        ),
      ),
      throwsA(invalid),
    );
    await expectLater(
      open(
        DocumentKeyGrant.fromJson({...grant.fields, 'signature': '0' * 128}),
      ),
      throwsA(invalid),
    );
  });
}
