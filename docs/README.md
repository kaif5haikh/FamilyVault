# Project documentation

| Document | Purpose |
| --- | --- |
| [Product requirements](product-requirements.md) | Requested scope, acceptance criteria and unresolved product decisions |
| [System architecture](architecture.md) | Layers, module boundaries and lifecycle |
| [Database design](database.md) | ER diagram, types, invariants, local/cloud proposals |
| [PostgreSQL proposal](design/postgresql.sql) | Non-deployable review schema; no production migration |
| [SQLite proposal](design/sqlite.sql) | Local sync metadata schema |
| [Sync design](sync.md) | Durable outbox, receipts, ordering, conflicts and attachment finalization |
| [Threat model](security-threat-model.md) | Trust boundaries, threats, controls and residual risks |
| [Permission matrix](permissions.md) | Roles, resource grants and RLS boundaries |
| [Backup/recovery](backup-recovery.md) | Encrypted backup, restore, export and deletion |
| [Dependency review](dependencies.md) | Upstream evidence and compatibility/security evaluation |
| [Development setup](development.md) | Reproducible commands and platform constraints |
| [Review gate](review-gate.md) | Required architecture/database decisions before financial features |
| [Decisions](decisions/0001-foundation.md) | Engineering decisions and alternatives |
| [Operations](operations/2026-11-13-initialization.md) | Command/result record and verified milestones |

All financial designs are **proposed**, not approved for production use.
