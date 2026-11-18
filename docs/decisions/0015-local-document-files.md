# ADR 0015 Encrypted local document versions

Implemented and tested in the local repository on 2026-11-18. Native file
selection, preview and shared cloud delivery are separate implementation units.

Drift v4 adds documents, immutable versions and property or journal links.
Titles, ownership, categories and expiry dates stay in encrypted SQLite.
Ownership describes whose document it is. Access checks use the unlocked
workspace, enrolled device and active membership. Versions preserve their
creator and device. Metadata edits and archive actions preserve provenance.
Audit events for preview and download contain IDs, actions and timestamps.

Each version receives a fresh random 256-bit key. The file format uses
XChaCha20-Poly1305, a random 128-bit nonce prefix and a distinct 64-bit counter
for each 256 KiB block. The authenticated data includes the header, counter,
family, document, version, MIME type and clear byte length. The workspace's
separate document key wraps the content key. Reads confirm exact file length,
ciphertext SHA-256 and every block tag before returning bytes. The local version
limit is 24 MiB. Format inspection checks file signatures. Preview will still
need the platform image and PDF parsers. [Dart cryptography primitives](https://pub.dev/documentation/cryptography/latest/dart/DartCryptography-class.html)

The repository flushes an encrypted staging file and moves it to a UUID-derived
path before committing metadata and its audit event together. A crash or failed
transaction can leave an encrypted file without a row. Such a file is absent
from searches and version history. Missing or corrupted content fails integrity
verification. Physical power-loss durability and cloud delivery require their
own validation.

The v4 migration adds tables and guards in one transaction and preserves the
earlier schema snapshots. Tested upgrades start from populated encrypted v1,
v2 and v3 files. The local format does not involve shared recipient keys.
The cloud work will verify device-specific key delivery and acknowledged private
Storage transfers before accepting shared document records.
