# Security threat model — revised shared-family design

Confirmed sharing/currency/backup decisions come from
[ADR 0003](decisions/0003-confirmed-product-architecture.md). Controls described
below are requirements/proposals unless explicitly identified as tested in the
foundation or the current operation record.

## Assets, actors and boundaries

Assets: financial history, identity/medical/property documents, ownership, keys,
refresh tokens, recovery material and permission state. Actors: family members,
administrator, trusted backend operators, unauthorized remote users, a malicious
or compromised member/device, stolen-device holder and dependency attacker.

Boundaries: mobile UI/process; app-private files/OS keystore; network; Supabase
Auth; PostgreSQL/RPC/RLS; private Storage; authorized recipient; encrypted backup
destination; development repository/CI. Repository privacy never replaces crypto.

| Threat | Required mitigation | Verification/residual risk |
| --- | --- | --- |
| Lost device or extracted app files | Ciphered SQLite/files; random keys in OS secure storage, device-bound where available; local unlock/lock lifecycle | Real-device locked/unlocked tests; rooted/unlocked compromise remains possible |
| Account takeover/token theft | Invite-only auth, MFA for admin/sensitive actions, PKCE/verified redirects, secure session persistence | Auth integration and token-log review; MFA/config not completed in this phase |
| Cross-family or role escalation | Current membership/enrolled-session checks, composite actor/device FKs, admin-only control plane, no direct domain DML | All members share ordinary access; adversarial real-backend tests still required |
| Cloud operator/document exposure | Client-side AEAD document encryption, independent keys, opaque paths, encrypted metadata where needed | Server can still see traffic sizes/access and unencrypted finance metadata |
| Storage URL leakage or unaudited download | Private buckets; authenticated audited gateway, no direct reads/client signed-URL minting; local decryption | A bearer signed URL alone cannot meet authenticated per-download audit requirements |
| Sync replay/overwrite/double-count | Idempotency receipts bound to payload, expected revisions, immutable postings, atomic aggregate validation | Fault tests and explicit semantic duplicate UX |
| Missing data from feed/cursor race | Family lock and transactional sequence, page/cursor atomicity, auth epoch and bootstrap | Concurrency/revocation/backfill tests before sync release |
| Tampered documents/backups | Authenticated encryption binding tenant/entity/version; ciphertext digest; versioned signed/authenticated manifest | Tamper/truncate/wrong-key tests and restore drill |
| Key loss or malicious grant | Authenticated device/public-key enrollment, independent recovery key, rotation and key-version envelopes | Key exchange/recovery protocol review is a release gate |
| Plaintext leaks through logs/cache/backups | No payload logging, private temp files, OS backup exclusions, blur app switcher, cleanup after viewing | Native tests; document recipient screenshots cannot be fully prevented |
| Malicious PDF/image or huge import | Enforce allowlisted decoded formats and size/page/pixel limits before encryption; maintained viewer; no executable parsing server-side | Fuzz/malformed file tests; thresholds need product review |
| Dependency/CI compromise | Lock dependencies, review changelogs/native sources/advisories, pin CI actions, least permissions, no production secrets in CI | Registry/advisory coverage incomplete; require release review |
| Disgruntled authorized user | Shared reads/edits with immutable provenance/audit; separate admin permissions; independent encrypted backups | Every authorized member can read/copy identity and medical documents; ownership does not narrow this confirmed sharing |
| Offline revocation delay | Cache authorization lease, local lock and foreground revalidation, purge revoked access on reconnect | Instant remote wipe/offline grant revocation is impossible |
| Forged ownership or creator-only access regression | Owner remains metadata; creator immutable; modifier comes from session; all family members edit shared records | Regression cases must include one member editing/uploading for another |
| Enrollment/session spoofing | Private-key challenge, trusted admin approval, verified JWT session binding, current device state | Device UUID headers, copied database rows or restored approval metadata are not enrollment |
| Premature/false backup success | Complete authenticated archive, destination acknowledgement/readback, digest/size and receipt checks | DDL evidence markers are necessary but cannot prove actual bytes were verified |
| Drive token compromise/quota/deletion | Narrow proposed drive.file scope, OS secure token storage, immutable encrypted snapshot files, independent local copies | Provider identity/access and recovery keys remain independent; no automatic paid quota |
| Backup rollback or old permissions restored | Authenticated lineage/watermark, current online grants, isolated recovery and receipt reconciliation | A valid old archive or hash chain alone cannot prove it is the newest; offline disaster trust must be reviewed |

## Key management proposal

Generate 256-bit random device vault keys using a CSPRNG and store them in
Android Keystore-backed secure storage/iOS Keychain with device-only accessibility.
Separate DB, document, key-wrapping and backup purposes using independent keys or
reviewed HKDF contexts. Never derive encryption keys from an access/refresh token.

All authorized members can read shared documents; ownership is never a private
ACL. Documents use a fresh AEAD key per version with a unique nonce. Authenticate
family ID, document ID, version ID, algorithm/envelope version and content-type
metadata as associated data. Recipients get per-user/device key envelopes;
the backend stores wrapped keys, never the plaintext document key. Authenticate
recipient public keys via an approved enrollment/verification protocol rather
than trusting arbitrary server key substitution. Key exchange/enrollment is not
implemented here; do not claim end-to-end document protection until reviewed.

Wrap keys to all authorized enrolled recipients, including historical versions
after enrollment. The server storing ciphertext cannot generally rewrap a lost
document key without an authorized key holder or reviewed recovery mechanism.
Treat key-backfill delays as readiness failures, never as owner-only permission.
Do not expose other devices' private keys or key envelopes as shared family data.

Revocation blocks future access and rotates future version keys. Re-encrypting
older versions may reduce future cloud exposure but cannot revoke copies already
downloaded. Recovery needs a separately held random recovery key and authenticated
manifest; losing every key and recovery copy means data cannot be recovered.
Document large-file chunking/nonce scheme and algorithm limits require a reviewed
envelope specification before implementation; avoid custom cryptographic primitives.

## Authentication/session handling

Keep Supabase debug logging off. Secure storage failure must stop authentication,
not fall back to plaintext preferences. Signout clears credentials and stops sync;
server-side session/device revocation is separate from local token deletion.
JWTs can remain valid until expiry, so check current membership and device/session
state on sensitive operations. Short-lived signed URLs are bearer capabilities;
issue them only after authorization and keep keys separate.

For this shared vault, proposed ordinary downloads instead use an authenticated
gateway: membership/device/session checks, committed access-start event, stream
and terminal audit. No app-readable bypass to raw Storage or signing credentials.
Audit failure blocks online release of bytes. Distinguish attempted/completed
transfer and delayed offline cache reports; a compromised client can suppress
local reports or copy already decrypted data. Append-only SQL triggers protect
ordinary DML, not a database superuser who can change DDL or an unlocked device.

Required backup checks include independent local/Drive status, no missing
attachments/recovery envelopes, authenticated manifests, safe temporary files,
readback verification and clean-device restore. Device-bound keys and sole-source
local files cannot provide disaster recovery by themselves. No restore drill or
Drive integration has yet established these controls in the application.

Native release gates: disable Android cleartext and automatic app-data backup;
exclude iOS protected data from automatic backup or ensure no plaintext artifacts;
prevent unreviewed exported components; exact deep-link allowlists; no sensitive
crash telemetry; app-switcher protection, lock-on-background and clipboard/viewer
cleanup. Only controls actually verified in code may be described as implemented.
