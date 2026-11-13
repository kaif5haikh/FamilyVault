# Project documentation

| Document | Purpose |
| --- | --- |
| [Consolidated confirmed-decision ADR](decisions/0003-confirmed-product-architecture.md) | Authoritative product choices, consequences, unresolved risks and implementation/evidence boundary |
| [Product requirements](product-requirements.md) | Requested scope, acceptance criteria and unresolved product decisions |
| [System architecture](architecture.md) | Layers, module boundaries and lifecycle |
| [Database design](database.md) | ER diagram, types, invariants, local/cloud proposals |
| [PostgreSQL proposal](design/postgresql.sql) | Non-deployable review schema; no production migration |
| [SQLite v1 baseline](design/sqlite.sql) / [future projections](design/sqlite-next.sql) | Implemented metadata baseline versus review-only financial/document/backup design |
| [Constraint/authorization review](database-constraint-review.md) | All table classes, tested DDL guards and required backend enforcement |
| [Testing strategy](testing-strategy.md) | Current executable evidence and future backend/device/Drive/restore acceptance |
| [Sync design](sync.md) | Durable outbox, receipts, ordering, conflicts and attachment finalization |
| [Threat model](security-threat-model.md) | Trust boundaries, threats, controls and residual risks |
| [Permission matrix](permissions.md) | Roles, resource grants and RLS boundaries |
| [Backup/recovery](backup-recovery.md) | Encrypted backup, restore, export and deletion |
| [Dependency review](dependencies.md) | Upstream evidence and compatibility/security evaluation |
| [Development setup](development.md) | Reproducible commands and platform constraints |
| [Review gate](review-gate.md) | Required architecture/database decisions before financial features |
| [Decisions](decisions/0001-foundation.md) | Engineering decisions and alternatives |
| [Operations](operations/2026-11-13-initialization.md) | Command/result record and verified milestones |
| [Architecture update record](operations/2026-11-13-architecture-update.md) | Confirmed decisions, revised proposal validation and verified repository handoff |

All financial designs are **proposed**, not approved for production use.

INR, shared finance/documents and both backup destinations are owner-confirmed
requirements. The revised technical design remains pending review; requirement
confirmation does not imply implementation, integration tests or deployment.
