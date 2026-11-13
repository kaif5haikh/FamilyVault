# Security threat model — initial design

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
| Cross-family or role escalation | Current membership RLS, composite FKs, module/document ACL, no direct domain DML | Adversarial multi-user RLS tests; no production policies claimed |
| Cloud operator/document exposure | Client-side AEAD document encryption, independent keys, opaque paths, encrypted metadata where needed | Server can still see traffic sizes/access and unencrypted finance metadata |
| Storage URL leakage | Private buckets, authorized reads, short TTL, no URL logs, local decryption | URL expiry is not retroactive erasure of downloaded ciphertext/plaintext |
| Sync replay/overwrite/double-count | Idempotency receipts bound to payload, expected revisions, immutable postings, atomic aggregate validation | Fault tests and explicit semantic duplicate UX |
| Missing data from feed/cursor race | Family lock and transactional sequence, page/cursor atomicity, auth epoch and bootstrap | Concurrency/revocation/backfill tests before sync release |
| Tampered documents/backups | Authenticated encryption binding tenant/entity/version; ciphertext digest; versioned signed/authenticated manifest | Tamper/truncate/wrong-key tests and restore drill |
| Key loss or malicious grant | Authenticated device/public-key enrollment, independent recovery key, rotation and key-version envelopes | Key exchange/recovery protocol review is a release gate |
| Plaintext leaks through logs/cache/backups | No payload logging, private temp files, OS backup exclusions, blur app switcher, cleanup after viewing | Native tests; document recipient screenshots cannot be fully prevented |
| Malicious PDF/image or huge import | Enforce allowlisted decoded formats and size/page/pixel limits before encryption; maintained viewer; no executable parsing server-side | Fuzz/malformed file tests; thresholds need product review |
| Dependency/CI compromise | Lock dependencies, review changelogs/native sources/advisories, pin CI actions, least permissions, no production secrets in CI | Registry/advisory coverage incomplete; require release review |
| Disgruntled authorized user | Least privilege, append-only server audit, encrypted backup separation and reauthentication for exports | An authorized recipient can copy accessible data |
| Offline revocation delay | Cache authorization lease, local lock and foreground revalidation, purge revoked access on reconnect | Instant remote wipe/offline grant revocation is impossible |

## Key management proposal

Generate 256-bit random device vault keys using a CSPRNG and store them in
Android Keystore-backed secure storage/iOS Keychain with device-only accessibility.
Separate DB, document, key-wrapping and backup purposes using independent keys or
reviewed HKDF contexts. Never derive encryption keys from an access/refresh token.

Documents use a fresh AEAD key per version with a unique nonce. Authenticate
family ID, document ID, version ID, algorithm/envelope version and content-type
metadata as associated data. Recipients get per-user/device key envelopes;
the backend stores wrapped keys, never the plaintext document key. Authenticate
recipient public keys via an approved enrollment/verification protocol rather
than trusting arbitrary server key substitution. Key exchange/enrollment is not
implemented here; do not claim end-to-end document protection until reviewed.

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

Native release gates: disable Android cleartext and automatic app-data backup;
exclude iOS protected data from automatic backup or ensure no plaintext artifacts;
prevent unreviewed exported components; exact deep-link allowlists; no sensitive
crash telemetry; app-switcher protection, lock-on-background and clipboard/viewer
cleanup. Only controls actually verified in code may be described as implemented.
