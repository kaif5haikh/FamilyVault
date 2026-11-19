#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/env.sh"
cd -- "$FAMILYVAULT_ROOT"

if [[ ! -f android/key.properties ]]; then
  printf '%s\n' 'Configure local signing in android/key.properties. See docs/installation.md.' >&2
  exit 1
fi
android_tools="$ANDROID_HOME/build-tools/36.0.0"
familyvault_bundletool="${FAMILYVAULT_BUNDLETOOL_JAR:-.tools/bundletool/bundletool-all-1.18.3.jar}"
if [[ ! -x "$android_tools/apksigner" || ! -f "$familyvault_bundletool" ]]; then
  printf '%s\n' 'Install Android Build Tools 36.0.0 and bundletool as described in docs/installation.md.' >&2
  exit 1
fi

mkdir -p .cache/checks
flutter pub get --enforce-lockfile
flutter build apk --release --no-pub "$@"
flutter build appbundle --release --no-pub "$@"

apk=build/app/outputs/flutter-apk/app-release.apk
bundle=build/app/outputs/bundle/release/app-release.aab
"$android_tools/apksigner" verify --verbose --print-certs -Werr "$apk" |
  tee .cache/checks/android-release-apk-signature.txt
"$android_tools/zipalign" -c -P 16 -v 4 "$apk" > .cache/checks/android-release-alignment.txt
jarsigner -J-Duser.language=en -J-Duser.country=US -verify "$bundle" |
  tee .cache/checks/android-release-bundle-signature.txt
rg -q '^jar verified\.$' .cache/checks/android-release-bundle-signature.txt
if rg -qi 'contains unsigned entries' .cache/checks/android-release-bundle-signature.txt; then
  printf '%s\n' 'App Bundle contains unsigned payload entries.' >&2
  exit 1
fi
apk_signer=$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' .cache/checks/android-release-apk-signature.txt)
bundle_signer=$(keytool -J-Duser.language=en -J-Duser.country=US -printcert -jarfile "$bundle" |
  awk '/SHA256:/ { gsub(":", "", $2); print tolower($2) }')
if [[ ! "$apk_signer" =~ ^[0-9a-f]{64}$ || "$apk_signer" != "$bundle_signer" ]]; then
  printf '%s\n' 'APK and App Bundle certificates differ or could not be verified.' >&2
  exit 1
fi
java -jar "$familyvault_bundletool" validate --bundle="$bundle"
sha256sum "$apk" "$bundle" | tee .cache/checks/android-release-sha256.txt
