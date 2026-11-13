# Confirmed product architecture update — 2026-11-13

Authority: owner's confirmed INR/shared-family/shared-documents/local-plus-Drive
requirements. Scope is architecture/proposals/validation only. Existing application,
released Drift v1 and existing commits remain intact. No real family data,
production infrastructure, cloud credentials or paid service is introduced.

## Inspection and decisions

| Command/check | Verified result |
| --- | --- |
| `pwd`, `cat AGENTS.md`, `git status --short --branch` | Correct FamilyVault workspace; initially clean main tracking origin/main |
| `git remote -v`, `git log -3 --oneline` | Existing private-repository SSH origin; prior commits 93466f6 and 6588061 preserved |
| `gh api user --jq .login`, `gh repo view ... --json nameWithOwner,isPrivate,sshUrl` | Active owner kaif5haikh; repository remains private with designated SSH URL |
| Read architecture/SQL/requirements/security/recovery/review documents, targeted `rg` | Found own-record edits, owner/ACL document visibility, viewer role and optional Drive assumptions inconsistent with new requirements |
| Official Drive scopes/upload/revision/checksum and Supabase download docs | API semantics checked for least-scope Drive proposal and authenticated versus bearer-URL download boundary; no account connection or provider API integration performed |

Created consolidated ADR 0003 with confirmed requirements, consequences, unresolved
risks and implementation/evidence matrix. Updated PRD, system/ER/SQL designs,
permission matrix, threat model, sync, two-destination recovery, testing strategy,
review checklist and cross-references. Added a table-class constraint/backend
authorization review, future SQLite projection design and synthetic probe harness.

PostgreSQL proposal now includes INR metadata, member/admin roles, immutable
provenance and modifier FKs, enrollment/session state, shared document metadata
without per-document ACLs, append-only access audit, and independent backup
artifact/destination/attempt constraints. The future SQLite design mirrors authorized
projections in STRICT tables, with device-private bindings and server-only tables
excluded. The implemented three-table Drift v1 and its snapshot are unchanged.

## Validation

| Command/check | Verified result |
| --- | --- |
| `bash tool/check_proposals.sh` | Isolated UTF-8 PostgreSQL DDL accepted; 36 tables all force RLS; unprivileged role cannot read the synthetic family row; scratch server stopped by trap |
| Same script, `tool/check_design_constraints.py` | **51 PostgreSQL + 50 future SQLite behavioral probes passed**, with expected SQLSTATE/extended codes; valid/invalid cases run in rolled-back synthetic transactions |
| SQLite v1 + future extension checks | v1 integrity/FKs pass; 35 tables in scratch projected design; application user_version remains 1; no future migration applied |
| Probe development feedback | Corrected tests to INSERT invalid audit entries instead of trying to rewrite immutable history, and checked numeric SQLite extended codes because this binding labels STRICT datatype errors as unknown; unrelated guard failures no longer count as intended constraint success |
| `source tool/env.sh; flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub --reporter expanded` | All **9 existing tests passed**; no new financial feature code/tests introduced |
| `git diff --exit-code HEAD -- lib test pubspec.yaml pubspec.lock drift_schemas android ios` | Application/native/dependency files and released schema snapshot unchanged |
| Markdown relative-link check and targeted `rg` consistency audit | New documents resolve; stale creator-only/owner-ACL/optional-Drive defaults removed from active architecture; historical initialization record preserved |

Probe coverage includes INR/Unicode/scale, exact integer defaults/overflow, distinct
creator/modifier, stable creator/tenant, cross-family links, enrollment/session
pairs, immutable audit, document/key uniqueness, SQLite REAL/date rejection,
complete artifact/copy evidence and independent local versus Drive outcomes.
These are **DDL/metadata tests**, not production RLS allow-policy, real Auth,
formatter, cryptography/provider integration or clean-device restore tests.

## Repository handoff

Run shell/Python syntax, indexed filename/ignore/credential policy, staged whitespace,
redacted Gitleaks and manual diff review before the normal documentation commit.
Local hooks repeat pre-commit and private-SSH-origin checks. Push without amending,
rebasing or force-pushing prior history, then compare remote main/HEAD, verify private
visibility and a clean tree. The resulting commit and equality check are reported
in the final handoff; raw transcripts stay ignored under `.cache/checks/`.

Final pre-commit results: shell/Python syntax and local links across 21 Markdown
files pass; 118 indexed files pass repository/ignore/credential checks; staged
whitespace and redacted Gitleaks pass with no findings. Manual scope review confirms
only documentation, proposal SQL and the isolated validation harness changed.

Revised architecture review is still pending. Product confirmations are recorded
separately from outstanding engineering approval. No production deployment,
financial feature, Drive token/connection, document upload or restore drill was
performed, and no unrelated project was accessed or modified.
