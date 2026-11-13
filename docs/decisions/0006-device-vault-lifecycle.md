# ADR 0006: device-protected local vault lifecycle

Date: 2026-11-13. Status: implemented, host-tested; Android build verification
recorded separately. Native key-storage/biometric hardware assurance remains open.

The default installation opens a genuine encrypted offline workspace without
requiring production credentials. The owner supplies the vault and display names.
No family identities, balances or documents are fabricated. Offline identity never
claims Supabase membership; configured shared cloud enrollment is a separate scope.

Vault creation/unlock requires OS device authentication (biometrics or device
credentials); an unsupported/unprotected device fails closed. Four independent
CSPRNG 256-bit values cover the database, document wrapping, signing seed and
key-exchange seed. Identity and keys are retained in one versioned OS-secure catalog
write before the database is created. An initializing catalog resumes interrupted
setup idempotently. A ready catalog with a missing database is a recovery error,
never permission to replace it with an empty database. Catalog loss with surviving
files also fails closed and preserves files.

The app masks its contents while inactive, locks/closes the database on background
or five minutes without touch, and invalidates an in-flight unlock on background.
Keys owned by a closed session are zeroed on a best-effort basis. Dart strings,
plugin internals, VM copies and hostile/rooted processes cannot be guaranteed
zeroized by this application. Android FLAG_SECURE blocks normal screenshots and
recents capture; iOS scene masking protects app-switcher snapshots, not user screen
capture. iOS configuration requires compilation and device checks on macOS/Xcode.

OS secure storage protects keys at rest. The local_auth UI gate is not a claim of
hardware-enforced biometric binding of every key operation. Cloud device keys,
revocation and server authorization are additional controls in later milestones.
The framework/platform error handlers emit curated constant messages and lock the
vault; raw exceptions/SQL/payloads are not printed. Route redirects and local
member checks are presentation/local defense, never a substitute for backend RLS.

Host evidence includes persistence/reopen, independent keys, cancelled verification,
storage failure, interrupted catalog write, lock/open race, missing database,
catalog loss/tamper and layout/privacy/navigation tests. Clean-device backup recovery
and native secure storage are still release acceptance requirements.
