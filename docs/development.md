# Development setup

Run commands from the FamilyVault root. Initialization detected Fedora Linux 44,
not Arch Linux. No global shell/Git identity settings or other projects are changed.

## Toolchain

Installed locally under ignored `.tools/`: Flutter 3.50.0 stable (Dart 3.14.0),
Temurin JDK 21.0.13+9, Android command-line tools 23.0, and Gitleaks 8.30.1.
Archive digests were checked against official upstream manifests/checksum files.
Exact public download URLs and digests are recorded in `tool/toolchains.json`.
The writable Pub, Gradle, Android and XDG caches are scoped under `.cache/`.

```bash
source tool/env.sh
flutter --version
dart --version
flutter doctor -v
sdkmanager --sdk_root="$ANDROID_HOME" --list_installed
git config --local core.hooksPath .githooks
```

The host's existing JRE 25 had no `javac`; project-local JDK 21 avoids changing the
system runtime. Android platform 36, build-tools 36.0.0, platform-tools and emulator
are installed via `sdkmanager` during setup; see the operation log for actual
completion. Emulator binary availability does not mean an AVD/system image exists
or that a device test has passed. Web/Linux desktop SDK warnings are outside the
Android/iOS targets and do not require unrelated tool installation.

On another Linux workstation, install the same stable SDK/JDK and Android SDK
from official distributions, verify their published checksums and place them at
the paths expected by `tool/env.sh`, or adjust that script locally for a reviewed
toolchain change. Do not download random installer scripts or commit SDK archives.
Android SDK licence acceptance is required for package installation.

iOS requires a macOS host, supported Xcode/SDK and device/signing setup. These
cannot be installed or validated on Linux. Distribution bundle IDs/signing teams
remain provisional and must be chosen before release.

## Checks

The schema proposal check uses an **isolated** temporary PostgreSQL cluster under
`.cache/`, a private Unix socket and no TCP listener. It never connects to a user
database or cloud project. Scratch data is preserved and the server is stopped
by a trap. PostgreSQL server tools and Python 3 are required.

```bash
bash tool/check_proposals.sh
git diff --check
git diff --cached --check
python3 tool/check_repository.py
git diff --cached --binary -- . | .tools/gitleaks/gitleaks stdin --no-banner --redact
```

Do not upload private data to validate scanners. Read the staged diff manually;
filename/credential rules cannot reliably detect every financial/identity record.
Phase 3 commands:

```bash
source tool/env.sh
flutter pub get --enforce-lockfile
dart run build_runner build
dart run drift_dev make-migrations
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
python3 tool/audit_dependencies.py
flutter build apk --debug --no-pub --target-platform android-arm64
```

`bash tool/check.sh` combines the regular local checks. `make-migrations` saves
schema snapshots under `drift_schemas/`; once version 1 is released, retain it and
add explicit, tested steps for later versions. Commit generated Drift Dart and
the lockfile. Do not use generator deletion/reset flags to bypass conflicts.

The app shell does not connect to a backend or open a vault. Start it on a
deliberately selected authorized development device with `flutter run -d <id>`.
The provisional bundle/application identifier is `app.familyvault.familyvault`;
Android minimum API is Flutter's 24, target/compile API 36. Distribution identities
and support policy still need review. Release signing is intentionally absent.

The Android debug artifact is `build/app/outputs/flutter-apk/app-debug.apk` when
the build succeeds. It is excluded from Git. Building is distinct from installing
or passing a physical-device test. Local ADB uses a separate port (5039), and the
setup does not install an app on connected personal devices.

`.github/workflows/validate.yml` is manually triggered only. Its action revisions
are pinned; it requires no app secrets and performs no deployment. It has not
been executed merely by pushing the repository. iOS needs a separate macOS check
before an iOS validation claim can be made.

## Configuration and deployment boundary

There is no configured Supabase backend, no API key and no service-role credential.
Cloud provisioning, executable financial migrations, auth redirects and key
recovery need their own reviewed milestone. Never run `docs/design/postgresql.sql`
against Supabase. Public client configuration is not secret, but the mobile app
must never contain privileged keys. No automatic production deployment is set up.
