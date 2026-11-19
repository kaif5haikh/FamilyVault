# ADR 0021 Verified Google Drive copies

**Status** Transport and mobile screens implemented on 2026-11-19. Local
fixture tests passed. Live consent and hosted recovery still require setup.

A verified local backup is the source of an independent Drive copy. Use
`drive.file` permission and create one opaque file per backup. Preallocate the
Drive ID and save it with the snapshot ID, length and ciphertext digest before
issuing a create request. The attempt record belongs to the Google account,
family, member and source device. Store the resumable upload URL in device
secure storage. The public filename and app metadata carry a random snapshot ID
and omit family identity and document details.

Continue from the byte range Drive confirms. When a session expires, start
another one with the same preallocated file ID. After completion or a lost
reply, check the file ID, snapshot ID, byte length and SHA-256 from metadata.
Stream the completed object and compute SHA-256 when metadata omits it. Record
the independent Drive receipt only after those checks succeed.

Use Flutter's maintained `google_sign_in` 7.2.0 plugin for native consent.
The lockfile resolves Android 7.2.19 and iOS 6.4.0, compatible with the app's
Android API 24 and iOS 15 targets. Android uses Credential Manager and Google
identity libraries. iOS verifies that the bundled callback scheme matches the
configured OAuth client before invoking the native SDK. Supabase family login
remains separate from the operator's Google backup connection. Obtain an
account-scoped access token in memory for each request and clear rejected
cached tokens. The user must initiate the connection and any new consent.
[Flutter plugin](https://pub.dev/packages/google_sign_in).
[Android setup](https://pub.dev/packages/google_sign_in_android).
[iOS setup](https://pub.dev/packages/google_sign_in_ios).

A clean restore can list and download versions with the same authorized Google
account. Keep the recovery key separately. The encrypted archive must pass
authentication, database integrity and document verification before activation.
Authenticate the supplied recovery key against the archive prefix before
writing the downloaded bytes. The installed vault uses a fresh device identity.
The fixture verified an interrupted upload, an expired session, a rejected
foreign upload endpoint, absence of duplicate files, readback when SHA-256
metadata is absent, corrupt content rejection and independent clean recovery.

The scope and resumable protocol come from Google's API documentation.
[Drive scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth).
[Resumable uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads).
[File metadata](https://developers.google.com/workspace/drive/api/reference/rest/v3/files).
