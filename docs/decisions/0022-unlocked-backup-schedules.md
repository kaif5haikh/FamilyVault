# ADR 0022 Backups during an unlocked session

**Status** Implemented and tested with synthetic vaults on 2026-11-19.

An operator may opt into a daily or weekly backup after keeping the recovery
key independently. Store the key and schedule in OS secure storage scoped to
the vault's family, member and device. Remove that schedule entry when disabled.
Turn off scheduled capture by default. OS secure storage entries are excluded
from the backup archive.

The app checks for due work when a vault opens, when the foreground resumes
and every two minutes while the vault remains open. The interval starts at
enrollment and restarts after a verified capture. Schedule checks stop when
the app is obscured or the session closes. The capture engine rechecks vault
authorization before publishing a complete archive. A scheduled capture uses
the same rekeyed snapshot and recovery verification as a manual capture.

Keep scheduled receipts separate from manual capture receipts. Give a schedule
its own receipt scope so a changed key or destination cannot reuse an older
schedule's copy. A scheduled local archive can be exported through Files with
the normal readback verification. The operator can also designate the currently
connected Google account. Record a hash of that account and upload only when
the active Drive connection matches it. At restart, the app can resume a
pending Drive upload after the operator reconnects that account.

Retry failed attempts after ten minutes while the vault is open. The app records
local capture and Drive verification separately. Disabling a schedule preserves
existing ciphertext files and independent copies. This release implements
foreground scheduling. Locked-device and OS background scheduling are unverified.
