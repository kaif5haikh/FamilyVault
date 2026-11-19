# ADR 0016 Shared document delivery

The PostgreSQL receipt protocol, private bucket policy, Deno gateway,
recipient key codec and Flutter transfer queue are implemented and tested in
development. Shared views use confirmed versions and show pending files from
the current device.

Documents belong to the family. The owner ID provides context while the enrolled
member and device determine access. The server keeps a document revision, its
creator and modifier, immutable versions and an append-only access history.
Sensitive metadata and contents arrive encrypted. A version's key is addressed
to each approved family device through ephemeral X25519, HKDF-SHA256 and
XChaCha20-Poly1305. An Ed25519 signature binds its grant to the family, document,
version, sender and recipient public key. Recipients verify the sender against
the approved directory and reject a changed signature or context.

The app reserves an opaque object path under the enrolled session. The gateway
can issue a write-only Storage token after checking that reservation and the
private bucket. An upload alone leaves the version pending. A trusted gateway
reads back the full object, calculates its byte count and SHA-256, and records
the result using a server-only database function. The final document revision,
version, recipient grants and receipt then commit together under the app's live
device authorization. A retry of the same reservation returns its original
receipt. Partial or corrupted bytes cannot reach the finalized state.

Ordinary user and anonymous Storage access is denied for the document bucket.
Downloads stream ciphertext through the authenticated gateway after the database
records authorization for the addressed device. This avoids a reusable download
link. The client also verifies length, digest and the encrypted file before
displaying it. Unconfirmed reservations expire after one hour. The same
authorized device can resume an expired reservation with the exact original
request while its base revision remains current. Provider upload tokens can
outlive a reservation and any resulting orphan stays private.

Approval trusts the authenticated directory and the administrator's device
fingerprint check. Protection against an active compromise that replaces the
server directory needs a pinned administrator trust anchor. PostgreSQL lets an
approved key holder find missing recipient grants and add them idempotently
for active enrolled devices. A new device cannot give itself a historical
grant. An approved holder must come online with its keys. Instant removal of
copies already received on a device is outside the revocation mechanism.

The Data API test uses real Auth sessions and a synthetic worker receipt. The
joined local provider check additionally verifies actual Storage upload and
readback with the Deno gateway and PostgreSQL. Hosted deployment remains pending.
[Private Storage access](https://supabase.com/docs/guides/storage/security/access-control) · [Function secrets](https://supabase.com/docs/guides/functions/secrets)
