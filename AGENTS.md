# FamilyVault working instructions

- Work only in this project. Never inspect or modify sibling projects. Preserve existing user data and files.
- Read `docs/architecture.md`, `docs/database.md`, ADR 0003 and ADR 0004 before
  implementation. The owner's autonomous end-to-end mission supersedes the prior
  per-phase human approval gate and authorizes implementation/engineering choices.
  Do not describe that authorization as a completed human architecture review.
  Preserve additive migrations/history, test milestones and keep production
  deployment and real-data handling within the owner's explicit safety boundaries.
- `docs/decisions/0003-confirmed-product-architecture.md` records authoritative
  INR/paise, shared family editing/documents and both local/Drive backup decisions.
  Ownership is metadata, never a private document ACL. Do not re-open these defaults.
- Restricted billing remains unspecified; do not invent its requirements.
- Routine project file edits, free tool installation, local checks, commits and
  pushes to the designated SSH origin are authorized. Do not repeatedly request approval.
- Keep keys/tokens/private documents/databases/exports out of Git and logs. No
  service-role credentials in Flutter, public document buckets or paid services.
- Source `tool/env.sh` for local tooling/caches. Use `bash tool/check.sh` and
  relevant mobile builds. Commit lockfile, generated Drift Dart and schema snapshots.
- Never use destructive database-reset/migration fallback or force-push. Ask
  before permanently deleting important data or overwriting a repository.
- Update `docs/decisions/` for major engineering decisions and the operation log
  for verified commands/results. Distinguish proposals from implemented controls.
- Inspect indexed content, run the repository policy check and redacted Gitleaks
  before commits. Preserve the designated SSH origin and verify the owner-approved visibility.
  The owner requested public repository visibility on 2026-11-18.
