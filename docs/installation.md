# Install FamilyVault

## Android

Use Android 7.0 or newer with a device passcode or biometrics. The
installable release APK is `build/app/outputs/flutter-apk/app-release.apk`.
Copy it to the phone and open it, or install it with Android platform-tools
on a device you have selected for testing.

```bash
adb devices
adb -s DEVICE_SERIAL install build/app/outputs/flutter-apk/app-release.apk
```

The release test package uses the project's development certificate. Android
updates require a matching signing certificate. If your phone has a version
signed with another certificate, keep the existing installation and make a
verified independent backup before changing it. A separate phone or Android
profile can hold a clean installation for the recovery drill.

The App Bundle is `build/app/outputs/bundle/release/app-release.aab`.
Use the APK for direct installation. The bundle is a packaging input for
Android distribution and for local tests with bundletool.
[Android bundletool](https://developer.android.com/tools/bundletool).

## Build signed Android artifacts

Use the toolchain in the [development setup](development.md). Keep your
signing key and password in private storage. Set up an ignored
`android/key.properties` file with the following entries. Paths are relative
to the Android project directory.

```properties
storeFile=../.local/signing/YOUR_KEYSTORE.p12
storeType=PKCS12
keyAlias=YOUR_ALIAS
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
```

Install the official bundletool 1.18.3 release under
`.tools/bundletool/bundletool-all-1.18.3.jar` or set `FAMILYVAULT_BUNDLETOOL_JAR`
to its location. The release URL and SHA-256 checksum are recorded in
`tool/toolchains.json`.
Run the build and verification from the FamilyVault root.
[bundletool 1.18.3](https://github.com/google/bundletool/releases/tag/1.18.3).

```bash
bash tool/build_android_release.sh
```

The helper builds the APK and App Bundle, checks their signatures and matching
signer, verifies APK alignment and validates the bundle. It writes the artifact
SHA-256 checksums to `.cache/checks/android-release-sha256.txt`. Retain the same
signing key for updates to installations made from these artifacts.
[Flutter release signing](https://docs.flutter.dev/deployment/android).

## Connect a family and Google Drive

The default build can open a local encrypted vault without service credentials.
For connected use, provision an approved test family with separate Auth
accounts and devices. Supply `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`
through an ignored defines file, and pass it when building. The release build
requires an HTTPS endpoint. Google Drive is optional and uses its own consent
flow after its platform client is configured.
[Supabase setup](supabase-development.md). [Google Drive setup](backup-recovery.md#configure-a-development-build).

```bash
bash tool/build_android_release.sh --dart-define-from-file=config/local/mobile.json
```

## iOS

Use a Mac with supported Xcode and iOS 15 or newer. Open the included Runner
project and use the `app.familyvault.familyvault` bundle identifier or the
identifier approved for your signed build. Set the Xcode signing team for a
device installation. Supply the same test backend configuration with Flutter
defines and the separate iOS Drive settings if needed.

```bash
flutter pub get --enforce-lockfile
flutter build ios --release --no-codesign
```

iOS compilation, device signing and runtime checks need a macOS test host.
Follow the same [user guide](user-guide.md) once the app is installed.
