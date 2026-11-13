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
