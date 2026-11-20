# FamilyVault 0.1.0

This development release is for testing with sample records. The Android APK
and App Bundle use a project-local development certificate. Existing vaults
keep their history through Drift v6.

## Included

- Offline INR ledger, budgets, reconciliation, exact balances and reports.
- Shared family accounts, device approval, financial corrections and private
  PostgreSQL sync.
- Properties, metals, loans, business revenue, stock and worker payments.
- Encrypted documents with versions, search, record links, expiry dates and
  opt-in local notifications.
- Verified encrypted backups, daily or weekly capture while unlocked, Google
  Drive backup support and clean local restore.

## Verification

The host checks include Flutter analysis and tests, populated Drift migrations,
PostgreSQL constraints and authorization, and Deno gateway tests. The joined
local Supabase fixture drives independent Dart clients through Auth, Data API
and private Storage. The Drive fixture tests retry, independent file checks and
clean recovery with a separate key. [Test results](development/TEST_RESULTS.md).

Android build 3 fixes plaintext picker copies and preserves document history
when restoring an archived document or clearing an expiry date. On the Moto
G34 5G, the test run exercised signed installation, exact local finance,
Android Files and clean encrypted restore. The device report lists remaining
camera, notification and hosted-service checks. Live Supabase and Google
Drive require approved service and OAuth configuration. iOS build and runtime
validation require macOS with Xcode. [Physical Android validation](testing/android-physical-device-validation.md).

Android build 4 adds the five-tab layout, a shorter Home, separate received
and spent forms, clearer ownership and debt screens, an optional tour and
offline Show me how. The exact signed APK was updated in place on the
Moto G34. The app reopened a known synthetic transaction after an offline
restart and remembered the selected language.
[Family usability results](testing/android-physical-device-validation.md#2026-11-20-usb-retest-and-language-correction).

Android build 5 uses English by default and offers conversational Hindi.
The welcome screen and Settings have the same language picker. Hindi covers
the tour, help, money, documents, family management and safe copies. The
signed files passed release checks and await the handset retest.
[Hindi copy audit](UIUX/hindi-copy-audit.md). [Build 5 details](testing/android-physical-device-validation.md#signed-build-5-with-english-and-hindi).

[Installation](installation.md). [User guide](user-guide.md). [Migration guide](migration-guide.md). [Recovery](backup-recovery.md).
