# UI work and verification

Baseline `6b5d93c`. Device signed build 3 and its digests are preserved in
`.local/qa/ux-moto-20261119/baseline/`. Task-owned paths are recorded in
`.local/qa/ux-moto-20261119/manifest.txt`.

- [x] Audit feature routes, screens, labels, previous device evidence and the
  signed baseline lock screen on Android 15.
- [x] Implement the shared visual system, navigation and short home overview.
- [x] Simplify daily money fields, history, ownership, debts and document flows.
- [x] Add onboarding, offline help and localized entry points.
- [x] Review family, settings, safe copies, updates and business.
- [x] Finish host regression and local provider checks and review the final
  synthetic captures.
- [x] Build and verify the signed APK and App Bundle under the original certificate.
- [x] Collect evidence and verify task-owned path and service cleanup.
- [ ] Exercise signed build 4 on the Moto G34. No Motorola USB device was
  available during the resumed session. The clean emulator could install an
  earlier candidate but exited before launch.

See the [Android validation report](../testing/android-physical-device-validation.md#2026-11-20-family-usability-update)
for commands, digests and evidence.
