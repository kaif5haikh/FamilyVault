# ADR 0019 Encrypted backup envelope

The backup engine takes a consistent snapshot of the unlocked device vault.
The SQLite Online Backup API reads from a pinned database transaction and
writes to a new encrypted SQLite database with an independent key. The source
database and WAL remain under SQLite control. A snapshot includes the accepted
records, local pending operations and immutable audit from that device's active
database. [SQLite Online Backup API](https://sqlite.org/backup.html) · [SQLite3 Multiple Ciphers](https://utelle.github.io/SQLite3MultipleCiphers/)

Each archive has its own random content key. A separately held 256-bit recovery
key wraps it with XChaCha20-Poly1305. `FVBACK01` and the wrapped key prefix
authenticate the chunk stream context. The encrypted manifest identifies the
snapshot, schema and family and carries the snapshot database key, document
wrapping key and file sizes and digests. Device signing and exchange seeds,
account sessions and provider tokens are absent. Reading and writing use
bounded chunks while the authenticated manifest stays in memory.

The builder validates every accepted or staged file reference, including its
locally wrapped key. The verifier authenticates and extracts only the manifest's
approved paths, checks SQLite integrity and foreign keys, and decrypts each
referenced document before the producer renames an archive to its final name.
Extraction stays in a private staging directory with the database and files
still encrypted. A missing file or invalid reference blocks publication.

This unit implements the archive engine and verifies restoration with a fresh
directory and the recovery key. Installing a recovered vault through the app,
verified Files and Drive destinations and scheduled jobs are separate units.
A connected-device snapshot preserves the data that device has received and
queued. Its scope does not include unsynchronized data on other devices.
