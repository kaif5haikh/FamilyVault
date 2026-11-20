# FamilyVault 0.1.0 physical Android validation

Validation began on 19 November 2026 with `de634ac` on the USB-connected
Motorola Moto G34 5G. The test vault and its records use synthetic data.

## Device and signed baseline

| Item | Observed |
| --- | --- |
| Hardware | Motorola moto g34 5G (`fogos`), authorized USB debugging |
| OS and architecture | Android 15, API 35, production user build, arm64-v8a, 4 KiB memory pages |
| Display | 720 × 1600 physical pixels at 280 dpi |
| Capacity at discovery | 7,672,196 kB RAM, 3,169,340 kB available, 16 GiB free reported by `df -h /data` |
| App | `app.familyvault.familyvault`, version 0.1.0, version code 1 |
| SDK range | Minimum API 24, target API 36 |
| Packaged ABIs | arm64-v8a, armeabi-v7a, x86_64 |
| Release certificate SHA-256 | `1e1f07c0060bc0206c4ee8d9984646ecd08a2f8f286fdc1208acaf697973be86` |
| Original APK | 94,751,413 bytes, SHA-256 `d900f013614051efacf0f3017df365a70fc9901afc22c9e0c6f46b834c80d729` |
| Original AAB | 83,618,739 bytes, SHA-256 `d0c76023cebc75fe2e49b7507fee672a92f6f14a7efb810e89d3b3792f846f32` |

- `adb devices -l`, `getprop`, `df`, `wm`, and `/proc/meminfo`
  confirmed the device properties. The retained discovery result omits the serial.
- `aapt dump badging` and the APK/AAB manifest checks confirmed the app ID,
  SDK range, `allowBackup=false`, `usesCleartextTraffic=false`, and a
  non-debuggable release. `apksigner verify -Werr --print-certs`,
  `zipalign -c -P 16`, `bundletool validate`, and `jarsigner -verify` passed.
- `adb install --streaming --user 0` installed the original signed APK. No
  FamilyVault package was installed for that Android user at discovery.
  `am start -W` returned `Status: ok` and a first-launch cold time of
  1,063 ms to the welcome activity. Device verification then opened a new
  synthetic local vault and its zero-balance dashboard.
- The original artifacts are retained under
  `.local/qa/moto-g34-20261119/original/`. Manifest, certificate, device and
  installation evidence is under `.local/qa/moto-g34-20261119/evidence/`.
  These are ignored local paths.

## Ledger, reports and offline behavior

| Case | Device result |
| --- | --- |
| Opening balances | Cash ₹1,000.05 and bank ₹200.03. Dashboard cash and bank total ₹1,200.08. |
| Invalid amounts | Income form rejected `1.001` and `-5.10`. |
| Income, expense and internal transfer | Income ₹1,200.19, groceries ₹18.07 and transfer ₹125.11 posted with the synthetic actor and audit. A rapid double tap on income produced one visible entry and one balance change. |
| Independent check | In paise, cash `100005 + 120019 - 1807 - 12511 = 205706` and bank `20003 + 12511 = 32514`. Accounts showed ₹2,057.06 and ₹325.14. |
| Airplane mode | Android exposed `cmd connectivity airplane-mode` and verified its enabled state. The app posted a ₹0.29 expense and renamed the cash account. Both updates saved locally. |
| Restart and reconnection | A cold restart while airplane mode was enabled returned to the device-authentication gate. Airplane mode was restored to disabled. After authentication, the renamed account and one ₹0.29 expense were present. The dashboard showed ₹2,381.91. |
| Monthly and yearly reports | The release showed ₹1,200.19 income, ₹18.36 expenses and ₹1,181.83 savings. The transfer and openings do not contribute to income or expenses. Reached the trend section on the physical screen. |
| Correction | Saved a replacement for ₹19.07 and confirmed that the original ₹18.07 entry was still visible as reversed, with its original post and reversal audit events. |
| Property | Saved a 50% family share of a synthetic Mumbai holding. The new valuation showed the whole ₹12,50,000.25 and the rounded family share ₹6,25,000.13. |
| Loan | Saved a synthetic loan and verified ₹500.37 of outstanding principal and an opening audit entry. |
| Business | Created a synthetic tyre business and recorded ₹100.07 of revenue. The business summary displayed ₹100.07 of revenue and recorded profit for the month. |

The phone uses an offline-only vault. The reconnect test verifies local
persistence and duplicate count. A disposable local Supabase run confirmed
actual acknowledgments and private Storage operations from two independent
Dart clients on the development host.

The first radio test left Wi-Fi active in airplane mode. In a second run
using the isolated package, the Android connectivity service confirmed
there was no default network. The app saved a ₹0.23 expense and preserved
the exact ₹41.75 balance after restart while still disconnected. The initial
Wi-Fi and airplane settings were restored, the default network returned,
and search showed one matching entry. See
`native-offline-and-notifications.txt`.

## Evidence and privacy

- `finance-on-device.txt`, `offline-on-device.txt` and
  `reports-on-device.txt` record synthetic UI assertions. The release
  welcome hierarchy is in `release-welcome-semantics.txt`.
- `overview-capture-protection.png` is an ADB screenshot cropped to the
  720 × 1334 app region. All pixels in that crop are black. Android
  capture protection is active. Use the UI assertions for dashboard evidence.
- `local-supabase.txt` records both opt-in Flutter tests and the real Auth,
  Data API and Storage fixture results. Checked MFA, enrollment, stale tokens,
  idempotent receipts, concurrent revisions, exact paise, encrypted delivery
  and recovery after a lost finalization reply.

## Manifest and data protection

The launcher activity is exported. Google Play Services' sign-in revocation
service requires its revocation-notification permission. The AndroidX profile
installer receiver requires `android.permission.DUMP`. The vault and
`FileProvider` components have no public document access. The manifest declares
Internet, biometric and fingerprint, reminder notification and boot receiver
permissions with no broad storage or contacts permission. Android reported
notifications as initially denied. No signing files were in the index, and a
redacted Gitleaks scan found no matches across the 40 baseline commits.

## Defects fixed

| Defect | Cause and correction | Regression evidence |
| --- | --- | --- |
| Plaintext copy remained after picking a document on Android | The original picker materialized its own copy. On the Moto G34 an isolated baseline build kept a byte-identical app-private PDF after the document was sealed. The updated picker streams the selected provider URI into the encryption path. Backup import uses the same reader. | Four new Flutter tests verify repeated bounded reads, the missing-size limit, cancellation and cleanup after provider failure. Baseline evidence is in `baseline-android-files.txt`. |
| Document restoration and expiry removal left old values in place | Drift's data-class update omitted null fields. Marking the archive timestamp and expiry date as explicitly present lets SQLite write null when clearing either field. Version and audit history are preserved. | The restored-document and removed-expiry assertions failed before the fix and passed afterward. See `document-archive-regression-before.txt` and `document-archive-regression-after.txt`. |
| PostgreSQL checks retained disposable data directories | The exit handler stopped PostgreSQL and left the isolated cluster on disk. The new handler stops the process and removes exactly the directory it created. It preserves the original exit status. | Both scripts passed as part of the full check. An injected `initdb` failure preserved exit status 42 and left the original directory inventory unchanged. Evidence is in `postgres-failure-cleanup.txt`. |

## First signed rebuild

`bash tool/build_android_release.sh` built version `0.1.0+2`. The APK and
AAB verified under the original certificate. Jarsigner reports the expected
self-signed development certificate chain warning. The APK signature, package
versions, manifest settings and ELF library headers were verified again. Every
arm64 library has a minimum load alignment of 16,384 bytes. This handset uses
4,096-byte pages.

| Version 0.1.0+2 artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `build/app/outputs/flutter-apk/app-release.apk` | 94,751,417 | `f7f9ace5df51470bb7649f595d8e6f655cb10e081bbe63b08edda39cacfbb416` |
| `build/app/outputs/bundle/release/app-release.aab` | 83,611,182 | `a66856734ed27937d6f2d71c7de530ab8c80c1bede3f543cfe9c5b88f16905c4` |

`adb install --streaming -r --user 0` succeeded. The device's installed base
APK matched the rebuilt APK digest. A cold start took 747 ms to the protected
activity. Android denied `run-as` access on the signed release. The same
vault, property, liability and account balances reopened after verification.
See `signed-final-build.txt`, `final-native-artifacts.txt`, and
`final-device-install.txt` for the local evidence.

## Documents and backup export on the handset

- The signed `0.1.0+2` release imported and opened a generated PDF. The
  details showed its Education category, synthetic owner, expiry and version.
  A copy exported through Android Files matched the original PDF byte for
  byte. Evidence is in `final-device-documents.txt`.
- The Android reauthentication prompt remained open on a later picker return.
  Several repeatable native tests used an isolated debug FamilyVault package
  with a test authentication gate. The phone still used its Android keystore,
  system picker, file resolver and SQLite libraries.
- In the isolated package, importing a PNG and saving a JPEG as the second
  version created zero additional picker cache files. Both image previews
  loaded with native decoding. Compared the exact cache inventory against
  the one pre-fix copy in the same test package.
- The backup export wrote 608,531 bytes to the synthetic Android Files
  destination. FamilyVault read the file back and verified it. An independent
  byte scan found no clear record title, PDF header, SQLite header or recovery
  key. The recovery key stayed separate from the backup files.
  See `fixed-android-files-and-backup.txt`.
- A fresh isolated package rejected both the truncated file and the
  end-byte tampering. It verified the valid backup before offering to
  restore, then showed the ₹42.17 balance and all three encrypted versions.
  The repaired build returned the archived document to the active list
  while retaining its two versions. The restored database had an encrypted
  header, the three version files were sealed, and the picker cache folder
  was absent. See `clean-android-restore.txt`.

## Physical UI and performance

| Check | Observed on the Moto G34 |
| --- | --- |
| Activity launch | The original first cold launch took 1,063 ms. Its later offline cold restart took 557 ms. The first signed update took 747 ms to the locked activity. |
| Database and list | The isolated debug benchmark posted 300 transactions of 101 paise in 23,010 ms and checked the exact 30,300-paise balance. A snapshot of 301 journals and 602 postings loaded in 85 ms. The phone opened and scrolled the list. |
| Memory and log checks | With the 301-row list visible in the isolated debug app, total PSS was 501,186 KiB and total RSS was 605,660 KiB. Its process log contained zero matching fatal, SQLite, out-of-memory, framework, or permission errors during the measured run. |
| Theme and size | Switched Dark, Light and Device default. Android reported the selected option. The dashboard exposed its metric controls in portrait and landscape, and the original portrait rotation setting was restored. The portrait Overview tab bounds were 180 × 140 pixels. |
| Camera | FamilyVault launched Motorola Camera and returned after cancellation without adding anything. A full capture needs a controlled synthetic target. |
| Notifications | The isolated app requested Android's notification permission and Android recorded the grant. Delivery of a scheduled expiry reminder remains unverified. |
| Capture protection | The handset's dashboard and document-preview screenshot crops contain only black pixels. The app's Android capture protection stayed enabled. |

The benchmark uses a separate debug package and its Android SQLite libraries
on the handset. Its transaction timing includes writes under the active UI.
Release dashboard or list frame timing and controlled battery drain remain
unmeasured. See `native-ux-performance.txt` and the local
`overview-capture-protection.png` and
`document-preview-capture-protection.png` captures.

## Final signed artifacts

The archive and expiry correction is in `8c39822`. The matching
`0.1.0+3` artifacts passed `apksigner`, `zipalign`, `bundletool validate`
and `jarsigner -verify`. The APK and AAB match the certificate from the
original artifact. Both original file digests were rechecked after the builds.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `build/app/outputs/flutter-apk/app-release.apk` | 94,751,417 | `5a3734e82430af33273080b61d8b0f264174c8cb24d0b3e206d58efd36c5e1ac` |
| `build/app/outputs/bundle/release/app-release.aab` | 83,612,513 | `34a46520502d6781f98a754d2d6a8cf8d09beaaade7486197b96cff26d7e3564` |

An in-place installation succeeded and the installed base APK matched the
host SHA-256. ADB measured 722 ms for a cold launch and 82 ms for a hot
return to the existing activity, both to the locked gate. The signed app's
locked screen used 99,287 KiB PSS and 200,092 KiB RSS in this sample. Its
scoped process log showed zero matching fatal, framework, SQLite, memory
or permission errors. See `release-code3-device-install.txt`.

After Android device verification, build 3 reopened the existing vault
with its expected ₹2,480.98 cash and bank total. On the signed build,
removing the PDF expiry cleared its alert, and archive followed by restore
returned the same document with Version 1 intact. Its PSS was 120,107 KiB
with the document open, and the scoped error counts remained zero.

## Automated checks

- `bash tool/check.sh` passed final Flutter formatting, Drift generation,
  analysis, 130 Flutter tests, SQLite and PostgreSQL probes, database
  migrations, access rules and five Deno gateway tests. OSV returned no
  matches for 184 hosted Pub packages. Two opt-in provider tests ran
  separately against the local Supabase fixture.
- `python3 -B tool/check_supabase.py --mobile --storage` exercised two
  Dart clients against real local Supabase Auth, PostgreSQL and Storage
  services. It tested MFA, invitation and enrollment, stale-session denial,
  duplicate replay, concurrent updates, private document transfer and a
  lost-finalization-reply retry.
- `adb` UI checks used Android accessibility bounds and selected only
  the FamilyVault screen or the known synthetic Files provider. Host
  checks cover additional loan amortization, inventory, backup scheduling,
  Drive provider behavior and small-screen or increased-text layouts.

## Remaining validation

- Hosted family sign-in, authorization, device revocation and sync require an
  approved Supabase deployment and operator accounts on real clients.
  Authorization and server acknowledgments in this run came from the local
  provider suite.
- Google Drive backup and restore passed the host provider fixture. Real
  consent, upload and download require configured Google OAuth. The phone's
  release was built for local use.
- Camera capture needs a synthetic target. Scheduled notification delivery,
  power-loss durability, controlled battery measurement and release frame
  timings remain unverified.
- Android versions outside the tested Android 15 handset, iOS hardware and
  iOS distribution builds remain outside this validation.
- The streamed picker prevents new plaintext cache copies. Earlier versions
  may have left copies in their own caches. The reproduced legacy copy
  belonged to a disposable QA package and was removed with that package.

## Cleanup and assessment

The release stayed installed with its synthetic vault locked. Verified removal
of both test-only FamilyVault packages and the companion Files provider
after reviewing their synthetic databases and eight fixture files. Removed
the recorded project-local temporary tree and the separate synthetic recovery
key. Android Wi-Fi, airplane mode and portrait rotation returned to their
initial settings. No installed release app data was cleared.

Checked the recorded task paths, `/tmp`, `/var/tmp`, PostgreSQL sockets,
Supabase pods and volumes, and stopped the Gradle daemon started for this
validation. The older Kotlin log, 86 pre-existing PostgreSQL cache
directories and the existing USB ADB daemon were preserved. The original
signed binaries, final APK and AAB, report, terminal evidence and two
capture-protection screenshots remain. See `cleanup.txt` and
`host-services-cleanup.txt`.

The signed build passed install, unlock, ledger retention, PDF handling and
the document correction retest on the Moto G34. Isolated native tests passed
disconnected persistence, encrypted export and clean recovery. The release
is validated for these local workflows on this handset. Hosted and hardware
checks listed above remain open.

## Execution checklist

- [x] Device discovery, original artifact audit and preservation.
- [x] Signed installation, welcome screen and secure local vault setup.
- [x] Core physical finance flows, offline mode and restart persistence.
- [x] Local backend authorization and real multi-client sync.
- [x] Physical document and export flows, camera launch and cancellation.
- [x] Backup, corruption checks and clean application restore.
- [x] Startup, memory, themes, rotation and capture protection measurements.
- [x] Regression checks, final artifact verification and signed physical retest.
- [x] Evidence retained, temporary files verified removed, and fixes pushed.

## 2026-11-20 Family usability update

The handset baseline for this update was the Motorola Moto G34 5G with
Android 15, API 35, arm64 and a 720 × 1600 display at 280 dpi. On 19 November
ADB brought the existing signed build 3 to its locked screen. The hot return
took 175 ms in that sample. Both build 3 binaries were copied to
`.local/qa/ux-moto-20261119/baseline/` and their digests rechecked.

After the session resumed on 20 November, repeated USB discovery found no
Motorola device. Installation, first use, accessibility, restart and timing
for the redesigned build on that handset remain pending. The physical results
above describe build 3.

### Recorded validation

| Check | Result |
| --- | --- |
| `bash tool/check.sh` | Formatter, code generation, analysis, 137 Flutter cases, five Deno cases, migration, SQL and dependency checks passed. |
| Local Supabase with `--mobile --storage` | Two joined tests passed using independent clients with local Auth, Data API and private Storage. |
| First use and help | Host tests finished and skipped the tour, reopened the app with saved preferences, searched offline and followed real money and document routes. Marathi choices persisted. |
| Money and records | Host tests verified exact received, spent, moved and corrected amounts, assets, loans and business stock with encrypted Drift. A transfer shows the source before the receiving account. |
| Privacy and accessibility | Host tests checked device lock with document views and pending streams, Android button target sizes, 320-point layouts at 200% text and wide layouts at 1200 points. |
| Documents and safe copies | Host tests covered picker handoff through lock, opening, export, access audit and verified local and mock Drive restore. |
| Temporary Android 16 emulator | Installed the first signed build 4 candidate and matched its installed APK digest. The emulator process stopped before the activity launched. Two alternate renderer configurations were tried. The captured host exits were 139, 132 and 139. |

The source changes fixed duplicate navigation state on rapid route changes,
an earlier save notice covering the correction form, and races between
record views detaching and the encrypted database closing. Rendered checks
also found a long label splitting on the smallest navigation layout.

### Rendered evidence

These screenshots came from host widget tests using synthetic records, the
phone-sized viewport and Flutter SDK fonts. The Android app keeps its platform
capture protection.

| Local evidence under `.local/qa/ux-moto-20261119/evidence/` | View checked |
| --- | --- |
| `home-synthetic.png` | Home totals, direct daily actions and activity at 390 logical points |
| `home-320-large-text.png` | Cash total and both rows of navigation at 320 points and 200% text |
| `welcome-tour.png` and `guide-money-received.png` | Optional tour and help before opening the real form |
| `money-received.png` | Amount, account, category, date and optional note in one normal-sized view |
| `documents-search.png` and `family-local.png` | Document search and explicit local family access |

The corresponding host and emulator command output is in
`full-check-final.txt`, `local-supabase.txt`, `large-label-regression.txt` and
`emulator-validation.txt`. Hosted Supabase, Google OAuth and iOS builds
require separate validation.

### Signed build 4

`bash tool/build_android_release.sh` built 0.1.0+4. APK signature and
alignment, App Bundle signature and structure checks passed. Both files
match the existing development certificate SHA-256
`1e1f07c0060bc0206c4ee8d9984646ecd08a2f8f286fdc1208acaf697973be86`.
The package ID is `app.familyvault.familyvault`, with minimum SDK 24,
target SDK 36 and arm64-v8a, armeabi-v7a and x86_64 libraries. Android app
backup, debugging and cleartext traffic are disabled. The permission audit
matched build 3.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `build/app/outputs/flutter-apk/app-release.apk` | 94,752,841 | `057eeb5764150f58c6b15449182e84afaef4726d312b2745d5ef79c5ba8c5e0c` |
| `build/app/outputs/bundle/release/app-release.aab` | 83,563,683 | `93e3d1526e312da77678c667a4fe911d1d905586c64ebf38c108b2e2eb45f617` |

The final files and checks are recorded in `final-artifacts.txt` and
`release-build-final.txt`. Validate installation, the first-use tour, returning
access, accessibility and core workflows on the Moto G34 once USB is
available. The emulated installation receipt belongs to the earlier signed
candidate and its automated launch could not be exercised.

### Cleanup

Removed the recorded scratch tree and the three synthetic vaults from
interrupted host runs. Disposed of both temporary emulator configurations,
their app data and the synthetic passcode. Verified that the QA listeners,
disposable Pods, test cluster paths and task-named system temporary paths
were gone. The Moto G34 received no new fixture files. The original signed
binaries, final release files and local evidence are retained.
See `manifest.txt` and `evidence/cleanup.txt`.
