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
| [cryptography](https://pub.dev/packages/cryptography/versions/2.9.0) | 2.9.0 | 2025-11-21 | Future document/backup envelopes. Selected candidate; maintained cross-platform primitives, envelope/key-exchange audit still required; defer adoption until that milestone. |
| [drift_dev](https://pub.dev/packages/drift_dev/versions/2.35.3) | 2.35.3 | 2026-11-08 | Drift code generation. Companion generator may have a different patch version from runtime; verify build_runner output and schema checks. |
| [build_runner](https://pub.dev/packages/build_runner/versions/2.17.1) | 2.17.1 | 2026-10-14 | Code generation. Build-time tool; lock full graph and run generation without blanket deletion flags. |
| [flutter_lints](https://pub.dev/packages/flutter_lints/versions/6.0.0) | 6.0.0 | 2025-05-27 | Static analysis. Flutter/Dart lint defaults plus project checks. |
| [flutter_dotenv](https://pub.dev/packages/flutter_dotenv/versions/6.0.1) | 6.0.1 | 2026-04-21 | Not adopted. No secrets in bundled dotenv; compile-time public config is extractable. Initial app does not initialize cloud services. |
| [connectivity_plus](https://pub.dev/packages/connectivity_plus/versions/7.3.2) | 7.3.2 | 2026-10-01 | Not adopted yet. Reachability does not prove server availability. Add only when a durable coordinator needs a wake-up hint. |

## Security and supply chain

The OSV querybatch API returned no advisory matches for the 16 direct candidate
package/version pairs checked on 2026-11-13. This is a scoped observation, not
a security certification. Repeat against the resolved transitive Pub graph.
Native Android/iOS/SQLite/cipher dependencies need separate vendor-advisory
review; absence in the Pub advisory ecosystem does not cover them.

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

A successful local analyzer/test/build is recorded in the operation log when run.
Before real data, require Android/iOS encryption and secure-storage tests on devices,
RLS/storage adversarial tests, key recovery/backup drills and a refreshed dependency
and native-binary advisory review. Cloud SDK inclusion alone provides no offline sync.
