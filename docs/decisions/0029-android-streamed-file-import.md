# ADR 0029. Stream selected Android files

Accepted 19 November 2026.

Android file selection previously used a picker that creates an app-private
cache copy before FamilyVault validates the file. For documents this copy is
plaintext. A synthetic import on the Moto G34 left the byte-identical copy
in the baseline app cache after saving the encrypted version. The picker also
took a persistable grant by default.

For Android read operations, use the system's Open Document contract and
read the selected content URI through the Android content resolver. Read
bounded chunks on a worker, close each reader at EOF or cancellation, and
close remaining readers when the activity is destroyed. Keep the URI in
memory during the normal lock and unlock handoff. Android grants access for
the activity lifetime. For an unknown document length, stop the size probe once
it exceeds the vault limit. The document repository still checks file type,
length and integrity and creates the encrypted version.

Use the same reader for encrypted backup selection. The backup workflow
still authenticates the prefix, stages ciphertext, and verifies the manifest
before restoring. Camera selection uses the native image picker, and device
verification remains a separate platform gate.
