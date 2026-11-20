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
- [x] Exercise signed build 4 on the Moto G34. The in-place update, language
  switch, tour, guided help and offline restart were verified on the device.
- [x] Ship English and conversational Hindi choices, preserve the original
  Marathi catalog and verify the language preference and large Hindi text.
- [x] Build and verify signed build 5 with the original certificate.
- [ ] Install build 5 on the Moto G34 and repeat English and Hindi checks
  when the wired device is available to ADB.

See the [Android validation report](../testing/android-physical-device-validation.md#2026-11-20-usb-retest-and-language-correction)
for commands, digests and evidence.
