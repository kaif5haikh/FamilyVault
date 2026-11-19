# FamilyVault migrations

## Upgrade a local vault

Make and verify an independent encrypted backup before installing an update.
Keep the recovery key separately. Install the update using the same signing
certificate, open FamilyVault and unlock the vault. Drift applies pending DDL
in a transaction and retains existing records and operation IDs.

| Version | Local change |
| --- | --- |
| 1 | Original sync queue, cursor and conflict records |
| 2 | Family and device records, ledger, audits, budgets, reconciliation and preferences |
| 3 | Holdings, ownership, valuations, loans, businesses, stock, wages and related journals |
| 4 | Encrypted document metadata, immutable versions and record links |
| 5 | Staged document uploads and retry index |
| 6 | Shared document edit index and updated replay guards |

The generated Drift snapshots under `drift_schemas/vault/` retain each
version. The host suite opens populated earlier fixtures and validates their
records and constraints after upgrade. Reopen a failed upgrade after checking
available storage. Retain the original vault files and the verified backup
for investigation. A recovery copy can open independently on a clean app.
[Backup and recovery](backup-recovery.md).

## Upgrade a development Supabase database

1. Work with the designated development project and synthetic accounts. Save
   a consistent backup of the current database, Storage and configuration.
2. Record the applied migrations and use the files in `supabase/migrations/`
   in their existing order. Apply each version once. Keep `fv_data`,
   `fv_internal` and `fv_auth_bridge` outside the exposed Data API schemas.
3. Apply the private bucket policy after Storage is present and run the
   `vault-object` function in the approved environment. Keep privileged
   service credentials in the server runtime.
4. Update testing clients with the server migrations before allowing new
   asset, loan, business or document-link receipts. Old caches retain their
   saved records and need a current replay client for the new receipt types.
5. Run the local approval-style checks before using provider data, then verify
   a write, pull and restore with separate enrolled test devices.

```bash
source tool/env.sh
bash tool/check_backend.sh
python3 -B tool/check_supabase.py --mobile --storage
```

Both commands use disposable local infrastructure. Coordinate any hosted
changes separately with the family operator. The design proposal SQL lives in
`docs/design/`. Use the executable migrations for deployment.
[Development provisioning](supabase-development.md).
