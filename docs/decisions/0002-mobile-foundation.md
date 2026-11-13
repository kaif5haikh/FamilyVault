# ADR 0002: limited mobile infrastructure

Status: implemented for the foundation; financial architecture review still pending.

## Decisions and reasons

- Use the official Android/iOS Flutter template with a Material 3 theme,
  light/dark modes, adaptive content width and scrollable/text-scalable pages.
  Use `material_ui` rather than the deprecated bundled library in Flutter 3.50.
- Route only welcome, locked access and about/licences pages. Keep the auth
  boundary explicitly unconfigured. No forms, demo records, fake balances,
  Supabase initialization or real-vault opening exist in the shell.
- Provide secure Supabase session and PKCE storage adapters, without activating
  them. Both fail on secure-storage errors; no preferences fallback or key reset.
  iOS storage requires a device passcode and does not synchronize to iCloud.
- Local schema version 1 contains only pending mutation, checkpoint and conflict
  metadata. Native encrypted connections run in a Drift worker, verify cipher
  availability in production, key before any schema access and enable foreign keys.
  The database exposes only the encrypted factory; key-setup errors expose a
  numeric classification rather than SQL/key material.
  The caller supplies a key; provisioning, recovery and local unlock are deferred.
- Persist the version 1 Drift schema snapshot. Unsupported schema changes fail
  without table drops; future upgrades need explicit migration implementations.
- Disable Android cleartext, automatic backup and device-transfer data inclusion;
  remove template debug-key release signing. Enforce iOS ATS and disable file
  sharing. Native iOS and full lifecycle protections remain release gates.
- Bound Gradle memory/workers on this workstation. Isolate ADB/build/tool caches
  in FamilyVault; do not install the app on connected personal devices.
- Supply a manually triggered, pinned-action validation workflow and local check
  commands. No automatic deployment or workflow execution is configured.

## Validation and limits

Native-host tests verify encrypted-file persistence, wrong-key rejection and
recovery, operation-ID uniqueness, incomplete acknowledgement rejection,
transaction rollback, conflict foreign keys and non-destructive future-schema
failure. Unit tests exercise isolated secure session/PKCE storage and error
propagation. Widget tests cover locked navigation and small-screen enlarged text.

These checks do not validate device keystore behavior, iOS binaries, production
auth, RLS/storage rules, document encryption, full sync or backup/restore. The
foundation cannot accept real family records. The human review gate remains open.
