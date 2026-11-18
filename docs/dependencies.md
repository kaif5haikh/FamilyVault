# Dependency review — 2026-11-13

Registry metadata, current stable versions and SDK constraints were fetched from
the official pub.dev API before adoption. None of the reviewed packages was
marked discontinued. Exact application resolutions belong in `pubspec.lock`.

Flutter **3.50.0 stable / Dart 3.14.0** satisfies the direct minimum SDK constraints.
The SDK archive SHA-256 was verified against the official release manifest.
Platform compilation, code generation and tests determine actual compatibility;
a registry version match alone is not proof.

| Package | Reviewed stable | Published (UTC) | Purpose / security and maintenance decision |
| --- | --- | --- | --- |
| [material_ui](https://pub.dev/packages/material_ui/versions/1.11.0) | 1.11.0 | 2026-11-09 | Official Flutter Material 3 library; source, SDK constraints and maintenance status reviewed. Use standalone widget types consistently with GoRouter 18. |
| [flutter_riverpod](https://pub.dev/packages/flutter_riverpod/versions/3.5.0) | 3.5.0 | 2026-11-06 | State management. Active upstream; use stable manual providers first, avoid unnecessary generator coupling. |
| [go_router](https://pub.dev/packages/go_router/versions/18.1.4) | 18.1.4 | 2026-11-09 | Navigation. Flutter-maintained router; redirects are presentation gates, never backend authorization. |
| [fl_chart](https://pub.dev/packages/fl_chart/versions/1.3.1) | 1.3.1 | 2026-11-09 | Future analytics presentation. Active upstream; selected for later authorized projections, no placeholder financial charts. |
| [drift](https://pub.dev/packages/drift/versions/2.35.4) | 2.35.4 | 2026-11-08 | Local typed persistence. Maintained SQL generator/runtime; versioned migrations, explicit transactions; database is not encrypted by Drift alone. |
| [sqlite3](https://pub.dev/packages/sqlite3/versions/3.9.1) | 3.9.1 | 2026-11-08 | Native encrypted engine. Use source: sqlite3mc build hook, checksum-verified upstream native assets and a runtime cipher check that remains in release builds. |
| [supabase_flutter](https://pub.dev/packages/supabase_flutter/versions/2.18.3) | 2.18.3 | 2026-10-12 | Cloud adapter boundary. Official Supabase SDK; replace both default session and PKCE preferences storage; disable debug/deep-link auto-detection. |
| [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage/versions/11.2.0) | 11.2.0 | 2026-09-16 | OS-backed credential/key storage. Active upstream; disable resetOnError to avoid silently erasing keys; device-only iOS access; native device validation remains required. |
| [path_provider](https://pub.dev/packages/path_provider/versions/2.1.6) | 2.1.6 | 2026-06-15 | Future private app-directory integration. Flutter-maintained native plugin; selected but defer adoption until vault lifecycle is implemented. |
| [path](https://pub.dev/packages/path/versions/1.9.1) | 1.9.1 | 2024-10-17 | Safe local path construction. Stable Dart-maintained library; old publication alone is not evidence of abandonment. |
| [uuid](https://pub.dev/packages/uuid/versions/4.6.0) | 4.6.0 | 2026-07-15 | Stable operation/entity identifiers. Use CSPRNG UUIDv4; IDs do not replace authorization. |
| [cryptography](https://pub.dev/packages/cryptography/versions/2.9.0) | 2.9.0 | 2025-11-21 | Device Ed25519 and X25519 keys and authenticated local document files. Key delivery and archive formats require separate tests. |
| [drift_dev](https://pub.dev/packages/drift_dev/versions/2.35.3) | 2.35.3 | 2026-11-08 | Drift code generation. Companion generator may have a different patch version from runtime; verify build_runner output and schema checks. |
| [build_runner](https://pub.dev/packages/build_runner/versions/2.17.1) | 2.17.1 | 2026-10-14 | Code generation. Build-time tool; lock full graph and run generation without blanket deletion flags. |
| [flutter_lints](https://pub.dev/packages/flutter_lints/versions/6.0.0) | 6.0.0 | 2025-05-27 | Static analysis. Flutter/Dart lint defaults plus project checks. |
| [flutter_dotenv](https://pub.dev/packages/flutter_dotenv/versions/6.0.1) | 6.0.1 | 2026-04-21 | Not adopted. No secrets in bundled dotenv; compile-time public config is extractable. Initial app does not initialize cloud services. |
| [connectivity_plus](https://pub.dev/packages/connectivity_plus/versions/7.3.2) | 7.3.2 | 2026-10-01 | Not adopted yet. Reachability does not prove server availability. Add only when a durable coordinator needs a wake-up hint. |


The document screens pin File Picker 13.3.3, Image Picker 1.2.4 and pdfrx
2.12.1. They support the project's Flutter and Dart constraints and the iOS
15 deployment target. The file adapter uses native selection and streams bytes.
Camera capture uses the Flutter-maintained plugin and cleans its own app-cache
capture after save or cancellation. [File Picker 13.3.3](https://pub.dev/packages/file_picker/versions/13.3.3) · [Image Picker](https://pub.dev/packages/image_picker)

The PDF viewer receives verified bytes from memory and disables external links
and text selection. The resolved `pdfium_dart` 0.4.4 hook pins PDFium
`chromium/8125` and verifies the downloaded archive against its SHA-256 table.
Linux host tests compile the hook's C gate with clang. On x86-64 Linux the
project's existing Android NDK clang is a fallback. OSV scanned 177 resolved
packages with zero advisory matches. Native PDFium and OS security updates
require their own review. [pdfrx 2.12.1](https://pub.dev/packages/pdfrx/versions/2.12.1) · [pdfium_dart 0.4.4](https://pub.dev/packages/pdfium_dart/versions/0.4.4)

## Security and supply chain

The OSV querybatch API returned no advisory matches for the 16 direct candidate
package/version pairs checked on 2026-11-13. This is a scoped observation, not
a security certification. Repeat against the resolved transitive Pub graph.
Native Android/iOS/SQLite/cipher dependencies need separate vendor-advisory
review; absence in the Pub advisory ecosystem does not cover them.

After resolving the application, `python3 tool/audit_dependencies.py` checked all
**138 hosted packages** in the lockfile graph, including `material_ui`, and
returned no advisory matches on 2026-11-13. The repeatable script reports an
unavailable service as a failed audit, never as a clean result.

Direct runtime licence files were inspected: Riverpod, FL Chart, Drift, sqlite3
and Supabase are MIT; GoRouter, Material UI and flutter_secure_storage use BSD
licences. Preserve upstream notices. The app exposes Flutter's licence registry.

Flutter 3.50 formally deprecates the bundled Material library. The foundation
uses the official standalone package after checking the
[Flutter migration guidance](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui).
This also avoids mixing widget types with the current GoRouter/FL Chart versions.

Review upstream source/changelog and licence files on adoption; retain required
third-party notices in distributions. No licence has been granted to the FamilyVault
application by initialization; keep the private source proprietary unless the owner
chooses otherwise. Do not assume a package publisher has audited the application.

Supabase 2.18.3 source was inspected: the version in use exposes `LocalStorage`
for session persistence and `GotrueAsyncStorage` for PKCE. Both defaults use
preferences unless overridden. Implement adapters against this actual version,
rather than relying on examples for a newer API. Secure storage 11.2.0 uses
modern Android wrapping/storage ciphers; major upgrades can invalidate legacy
keys and require migration review. There are no existing FamilyVault keys to migrate.

[Drift encryption guidance](https://drift.simonbinder.eu/platforms/encryption/)
and the sqlite3 build-hook source confirm the supported SQLite3MultipleCiphers
route and native asset checksum verification. Do not add obsolete
`sqlcipher_flutter_libs` alongside this setup.

## Release evidence still required

The official Flutter template selects AGP 9.3.1, Kotlin Gradle plugin 2.4.20 and
Gradle 9.5.0. The Gradle distribution checksum is pinned to the official checksum
endpoint. OSV Maven queries for AGP, Kotlin Gradle plugin and Kotlin standard
library at those versions returned no advisory matches. JDK 21 and Android API
36 are used for the local build; native/toolchain advisories must still be
refreshed before release. The selected Gradle version's compatibility/release
notes are available from [Gradle](https://docs.gradle.org/9.5.0/release-notes.html).

A successful local analyzer/test/build is recorded in the operation log when run.
Before real data, require Android/iOS encryption and secure-storage tests on devices,
RLS/storage adversarial tests, key recovery/backup drills and a refreshed dependency
and native-binary advisory review. Cloud SDK inclusion alone provides no offline sync.

## Autonomous implementation additions — M02/M03

Promoted uuid 4.6.0 (MIT), path 1.9.1 (BSD), path_provider 2.1.6 (BSD),
intl 0.20.3 (BSD) and crypto 3.0.8 (BSD) to direct dependencies. Added cryptography
2.9.0 (Apache-2.0) for upcoming authenticated document/backup/key envelopes and
local_auth 3.0.2 (Flutter BSD) for the device-credential/biometric unlock gate.
Official registry SDK constraints, release status, upstream source and licences
were inspected; registry source archive SHA-256 values were verified. None of
these reviewed versions is discontinued. Native authentication still needs mobile
build/runtime validation. No biometric or key data is logged.

The M02 resolved-graph audit checked **145 hosted packages** and returned no OSV
matches on 2026-11-13. This does not cover platform/vendor advisories or certify
application security. Exact graph remains in the committed lockfile.
