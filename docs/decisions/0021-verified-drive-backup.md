# ADR 0021 Verified Google Drive copies

**Status** Transport implemented and exercised with a local Drive API fixture
on 2026-11-19. Google account consent and native screens follow separately.

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

A clean restore can list and download versions with the same authorized Google
account. Keep the recovery key separately. The encrypted archive must pass
authentication, database integrity and document verification before activation.
The fixture verified an interrupted upload, an expired session, a rejected
foreign upload endpoint, absence of duplicate files, readback when SHA-256
metadata is absent, corrupt content rejection and independent clean recovery.

The scope and resumable protocol come from Google's API documentation.
[Drive scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth).
[Resumable uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads).
[File metadata](https://developers.google.com/workspace/drive/api/reference/rest/v3/files).
