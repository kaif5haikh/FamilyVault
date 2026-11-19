# ADR 0028 Signed Android development builds

Use the existing Android application identifier and release build type.
Gradle reads signing settings from the ignored `android/key.properties` file.
The approved local development signer is kept in project-local private
storage. Testing artifacts use the same signer so Android can recognize
updates made from this setup.

The release helper verifies the APK signature and alignment, the App Bundle
signature, the matching signer and the bundle structure. It records SHA-256
checksums. Tool versions and source digests are recorded separately from the
private signing configuration. [Android APK verification](https://developer.android.com/tools/apksigner).
[Android Bundle verification](https://developer.android.com/tools/bundletool).

Package the Flutter-maintained Cupertino Icons 2.0.0 asset. It restores the
glyphs used by the adaptive Cupertino controls and fits Flutter 3.50 and Dart
3.14. The package adds the font without runtime code or a new native plugin.
Android and iOS use original launcher artwork in the app's green palette.
[Cupertino assets](https://pub.dev/packages/cupertino_icons).

Local release artifacts are used for device testing. Hosted credentials,
platform distribution signing and physical runtime confirmation remain
separate from this packaging procedure.
