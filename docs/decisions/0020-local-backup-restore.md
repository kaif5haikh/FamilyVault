# ADR 0020 Local backup delivery and restore

The app exposes encrypted backups in Settings and restore during local vault
setup. Creating a backup verifies its complete contents before recording a
device-local artifact. A separate Files operation streams the same ciphertext
to the user-selected destination. A destination receipt needs an exact length
and SHA-256 measured by reopening the external copy. The most recent verified
artifact and export timestamp are scoped to the unlocked device and stored in
secure storage. [Android document creation](https://developer.android.com/reference/androidx/activity/result/contract/ActivityResultContracts.CreateDocument) · [iOS directory access](https://developer.apple.com/documentation/uikit/providing-access-to-directories)

The restore screen verifies the key, database, relationships and every file
before offering to install. The installation checks for an empty local vault
and requires device authentication. It gives the database a new encryption key
and the device fresh signing and exchange keys. It retains the document wrapping
key needed for existing versions and does not republish saved operations.
Restored family caches keep their chart IDs and open as independent local copies.

Secure storage records the recovery stage and new keys before the completed
directory is moved into place. Normal unlock resumes from either the staged or
installed directory after an interruption. Ambiguous or missing paths fail
with the existing files preserved.

Development tests verify restoration from local and connected backups, restart
after an interrupted catalog write, preserved pending work and exact financial
values. The app's Files outcome test checks readback using a disposable
destination. Android compiled the native adapter. Physical Files behavior and
the iOS build remain open.
