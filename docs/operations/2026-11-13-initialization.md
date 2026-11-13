# Initialization record — 2026-11-13

Only FamilyVault is in scope. No sibling project was inspected or modified.
Logs describe commands and outcomes, never credentials, personal records or tokens.
Machine downloads and raw build logs live in ignored `.tools/` and `.cache/`.

## Phase 0: initial inspection

| Command/check | Verified outcome |
| --- | --- |
| `pwd`, `ls -la`, `rg --files --hidden` | Correct FamilyVault path; initially empty, no existing files to preserve |
| `.git` existence, conditional `git status` and `git remote -v` | No local Git initialization or remote |
| `uname -srmo`, `/etc/os-release` | Fedora Linux 44 KDE, x86_64; recovered path says Arch but this host is Fedora |
| `command -v` development tools | Git, gh, SSH, Java, ADB, PostgreSQL server/client, Podman, Python, GCC, CMake, Ninja available |
| `git --version`, `gh --version` | Git 2.56.0; GitHub CLI 2.97.0 |
| `gh auth status`, `gh api user` | Authenticated active account and intended repository owner inferred as `kaif5haikh`, account ID 156950645; credentials unchanged |
| `gh config get git_protocol --host github.com` | Already `ssh`; no shared configuration modification needed |
| `ssh -o BatchMode=yes -o ConnectTimeout=20 -T git@github.com` | GitHub reports successful authentication as `kaif5haikh`; exit 1 is GitHub's normal no-shell result |
| `gh api repos/kaif5haikh/FamilyVault` | HTTP 404; private repository can be created without overwriting another repository |
| `git var GIT_AUTHOR_IDENT` | No usable author identity; use verified owner's noreply identity locally in this repository |
| `java -version`, `adb version` | OpenJDK 25.0.4.1; ADB 37.0.0p1 |
| Flutter/Dart and Android SDK searches at known installation paths | Not installed/on PATH; Android emulator absent |
| `/dev/kvm` | Available; no emulator/system image initially installed |
| `df -h .`, `free -h` | Approximately 62 GiB free disk, 14 GiB RAM; project-local tooling feasible |
| Initial Flutter manifest URL with an extra `/flutter/` component | HTTP 404; corrected using the official release manifest location |

## Scope and constraints

- GitHub repository must be `kaif5haikh/FamilyVault`, **private**, SSH remote.
- No global Git identity changes, account switching, billing setup, production migrations or cloud provisioning.
- Architecture and financial schemas remain proposals until human review.
- Phase 3 may build infrastructure only; no financial or billing features.
- Linux cannot validate iOS binaries or signing; macOS/Xcode remains required.
- No Supabase project credentials were supplied; cloud authentication/storage/sync must remain disabled.

Further installation, checks, commits and remote verification are recorded below as they occur.

## Phase 1: design and tooling

| Command/check | Verified outcome |
| --- | --- |
| Official Flutter Linux release manifest fetch | Stable 3.50.0, Dart 3.14.0; archive SHA-256 `6ea2d806fd57269ae783e6788e2a81fc26eaad782f1e0d0ff38623bb765ff9f5` verified before extraction |
| Official Android Studio download table/tools archive fetch | Command-line tools 23.0; SHA-256 `4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583` verified |
| Adoptium API request | API endpoint returned HTTP 403; incorrect release repository spelling returned 404; corrected official `adoptium/temurin21-binaries` repository supplied the JDK |
| Official Temurin release/checksum download | JDK 21.0.13+9, SHA-256 `d7f5d5cf865a2902b70ff549b97586a7d3f234e016f041ab447ea740c7d66d1c` verified; system Java untouched |
| `source tool/env.sh; flutter --version; flutter doctor -v` | Flutter/Dart operational; initial doctor flags missing Android SDK packages and out-of-scope web/Linux desktop tools |
| `sdkmanager --sdk_root="$ANDROID_HOME" --list --channel=0` | Stable platform 36/build-tools 36.0.0/emulator available; packages installed in a subsequent step |
| `flutter create --empty --platforms=android,ios --project-name familyvault --org app.familyvault --no-pub .cache/scaffold` | Official mobile template generated in ignored scratch directory; existing documents preserved |
| pub.dev package API and upstream source inspection | 16 direct candidates reviewed for SDK bounds/discontinued status; Supabase secure session + PKCE storage extension points verified |
| OSV `v1/querybatch`, direct candidate versions | No advisory matches in the Pub ecosystem for these 16 versions; native/transitive coverage remains separate |
| `bash tool/check_proposals.sh` | SQLite schema/integrity/foreign-key check passed; isolated PostgreSQL accepted 32 tables, all with forced RLS; synthetic row hidden from unprivileged role; scratch server stopped |
| Official Gitleaks v8.30.1 release/checksums | Archive verified and installed in ignored `.tools/gitleaks/` |

Created PRD, architecture/module boundaries, ER diagram and SQL proposals, durable
sync design, threat model, permission matrix, recovery/export/deletion design,
dependency review and explicit human review gate. SQL checks do not validate
production RLS policies or financial invariants; those remain unimplemented.

## Phase 2: private repository setup

| Command/check | Verified outcome |
| --- | --- |
| `git init --initial-branch=main` | New local repository, no existing history overwritten |
| `git config --local user.name kaif5haikh` | Repository-local author name set; global identity untouched |
| `git config --local user.email 156950645+kaif5haikh@users.noreply.github.com` | Verified account's noreply identity used locally |
| `git config --local core.hooksPath .githooks` | Local pre-commit index policy and redacted Gitleaks scan enabled |
| Repeated `gh api user` / `gh config get git_protocol --host github.com` | Same owner `kaif5haikh`, transport `ssh`; no credential switching |
| Repeated repository API lookup | Still HTTP 404 before creation |
| `gh repo create kaif5haikh/FamilyVault --private --source=. --remote=origin --description ...` | Repository created successfully |
| `gh repo view ... --json nameWithOwner,isPrivate,sshUrl,isEmpty` | Correct owner/name, `isPrivate: true`, initially empty |
| `git remote -v` | Fetch/push `git@github.com:kaif5haikh/FamilyVault.git` |
| `sdkmanager --licenses`, install platform-tools/platform 36/build-tools 36.0.0/emulator | Completed with exit 0 in project-local SDK; no paid infrastructure |

The initial commit/push is verified after the staged index policy, whitespace,
redacted Gitleaks and manual diff review. Its resulting hash will be recorded in
the next milestone's log entry, avoiding a self-referential commit hash.

## Initial push verification

`git add` staged 25 documentation/policy/tool files. `git diff --cached --check`,
`python3 tool/check_repository.py` (25 indexed files and ignore probes), redacted
`gitleaks stdin` and manual content/path review passed. No secrets or family data
were staged. The pre-commit hook repeated the index and secret checks successfully.

`git commit -m 'docs: establish FamilyVault architecture and security foundation'`
created **658806114ec0fe9a572ad37c352b7bcfee073173**.
`git push --set-upstream origin main` succeeded. `git rev-parse HEAD` and
`git ls-remote --heads origin main` both returned that exact hash; `gh repo view`
confirmed private visibility and the expected SSH URL. Worktree was clean then.

## Phase 3: mobile foundation

Official template Android/iOS files were copied from ignored scratch into the
project without replacing the architecture documents. Added Material 3 theme,
three safe shell routes, Riverpod unconfigured access boundary, secure session
and PKCE persistence adapters, encrypted Drift sync metadata and schema version 1.
The app does not initialize Supabase, open a real vault or accept financial data.

| Command/check | Verified outcome |
| --- | --- |
| `source tool/env.sh; flutter doctor -v` after SDK installation | Android toolchain passes, all Android licences accepted; emulator 37.2.13 available; unrelated web/Linux desktop warnings remain |
| Android package installation | platform-tools 37.0.1, platform 36 revision 2, build-tools 36.0.0 and emulator 37.2.13 installed locally |
| `flutter pub get` | Resolved 143 packages, including 138 hosted; application lockfile retained |
| First `flutter analyze --no-pub` / test compilation | Exposed an incorrect executor return type and Flutter 3.50's Material library deprecation; both corrected, standalone official Material UI dependency reviewed/adopted |
| `dart run build_runner build` | Drift code generation succeeded; no overwrite/deletion conflict flag used |
| `dart run drift_dev make-migrations` | Version 1 schema snapshot saved under `drift_schemas/vault/` |
| `dart format lib test` | Source/tests formatted |
| `flutter analyze --no-pub` after corrections | No issues found |
| First native tests | Actual security failures were rejected correctly, but expectations needed to unwrap Drift worker exceptions; corrected matchers now check precise SQLite result codes |
| `flutter test --no-pub --reporter expanded` | **9 tests passed**: encryption/reopen/wrong-key recovery; duplicate and incomplete acknowledgement rejection; rollback and FK integrity; non-destructive future schema rejection; key validation/redaction; secure session/PKCE isolation; secure-store failure; locked navigation; small-screen enlarged text |
| `python3 tool/audit_dependencies.py` | All 138 resolved hosted Pub packages checked, no advisory matches returned; not a native security certification |
| Android manifest XML / iOS plist parsing | Explicit no-cleartext/no-automatic-backup settings, ATS and file-sharing settings parse and match the intended baseline; iOS binaries not built |

Added a pre-push destination/private-visibility check. Pinned action revisions in a
**manual-only** validation workflow; it has not been run. No app installation on
personal devices, cloud provisioning, production migration, account switch,
global identity change, paid subscription or real document upload occurred.

Build caches, temporary directories and an isolated ADB daemon port are scoped
to FamilyVault. Raw local build logs remain ignored under `.cache/checks/`;
the checked-in log deliberately omits device identifiers and credentials.

## Final foundation verification

- First Android build completed successfully after installing the required
  NDK 28.2.13676358, platform 35 and CMake 3.22.1 into the project-local SDK.
  `flutter build apk --debug --no-pub --target-platform android-arm64` passed;
  the incremental build with bounded Gradle memory and pinned distribution
  checksum also passed (13.9 seconds).
- Debug artifact: `build/app/outputs/flutter-apk/app-debug.apk`, SHA-256
  `b47bd68ab845c69082158c4ff9c3712d8ae10fa7ae94c3992bacf253bdde3463`.
  APK is ignored, not uploaded to GitHub. Its ARM64 native assets include
  `libsqlite3mc.so`; packaging is not a device encryption test.
- `aapt2 dump xmltree ... --file AndroidManifest.xml` confirms min API 24,
  target API 36, `allowBackup=false`, `fullBackupContent=false`,
  `usesCleartextTraffic=false` and configured data extraction rules.
- Tightened the database API to expose only its encrypted factory and sanitized
  key-setup failures so no failing key statement is returned to callers.
- Re-ran schema checks after adding immutable change-event snapshots and a
  consistent bootstrap design: all 32 proposal tables still validate with forced
  deny-all RLS. This remains a proposal, not a deployed Supabase schema.
- Gradle 9.5.0 checksum pinned; three Android build-library Maven advisory queries
  returned no matches. Exact public SDK/tool archive URLs and verified digests
  recorded in `tool/toolchains.json`.
- All 23 tracked native PNG images match the official Flutter template bytes;
  no personal pictures were added. Indexed policy/ignore probes and redacted
  Gitleaks scans passed during staging; hooks repeat them before commit/push.
- After the final database hardening, `flutter analyze --no-pub` reports no
  issues and all 9 tests pass again. Shell/Python/JSON syntax checks pass.
  Final staged review covers 112 indexed files; policy/ignore probes, whitespace
  checks and redacted Gitleaks pass. No secrets or personal/financial records
  are included. Build artifacts, SDKs, local test databases and caches are ignored.

Final Git operation: commit the reviewed foundation using
`feat: add secure Flutter mobile foundation`, push normally to `origin/main`,
then compare local `HEAD` with `git ls-remote` and verify private visibility.
The resulting commit and remote equality are reported with the final handoff.

Remaining gates: human architecture/database review; real Supabase authorization,
full sync, document key distribution/encryption, offline unlock and recovery;
native device security tests; macOS/Xcode iOS validation. No financial or billing
features are implemented or authorized past the review gate by this initialization.
