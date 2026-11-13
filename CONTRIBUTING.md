# Contributing

This repository is private. Keep all work scoped to FamilyVault. Do not inspect
or change other projects. Never add real family data to fixtures, issues, commits,
screenshots, test output or logs.

## Workflow

1. Read the architecture, threat model and [review gate](docs/review-gate.md).
2. Keep changes small and include the reason for meaningful design choices in
   `docs/decisions/`. Financial features wait for architecture/database review.
3. Evaluate dependencies against their maintained upstream, supported SDK/platform
   versions, licence, advisories and transitive graph; update the review record.
4. Run the relevant checks described in `docs/development.md` and inspect the diff.
5. Scan staged content and filenames for secrets and personal information before
   committing. `.gitignore` is a convenience, not a security guarantee.
6. Push only to the verified private SSH origin. Never force-push shared history.

Use Conventional Commits: `docs:`, `feat:`, `fix:`, `test:`, `build:`, `ci:`,
`chore:`, optionally scoped, e.g. `feat(storage): add encrypted local metadata`.
Describe the concrete change and its validation in PR descriptions.

## Engineering rules

- UI consumes local repositories; network adapters do not become UI data stores.
- Use exact integers for money and measured quantities; never binary floating
  point for accounting. Currency, rounding and interest rules require review.
- Persist mutations and their outbox operation atomically. Server receipts, not
  optimistic UI or object upload success, acknowledge synchronization.
- Separate account/family caches and keys; deny access when permissions are unknown.
- Add reversible versioned database migrations and migration tests when changing
  a released schema. No automatic destructive fallback on migration failure.
- Do not use plaintext preferences for refresh tokens or encryption keys.
- Keep generated Drift code and the application's `pubspec.lock` in version control.
- Do not deploy SQL under `docs/design/`; it is a proposal, not a migration.
- Never put secrets in `--dart-define`; compiled values can be extracted.

No paid infrastructure, public repository changes or destructive production
operations without explicit authorization. Routine local checks and commits do
not need an additional approval.
