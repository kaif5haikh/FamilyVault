# System architecture — proposal

The local encrypted database is the mobile read model. Supabase PostgreSQL is the
authoritative shared store. Sync reconciles them; Realtime only prompts a pull.
There is no Google Drive live-sync dependency.

```mermaid
flowchart TD
  UI[Flutter UI / design system] --> State[Riverpod application controllers]
  State --> Repo[Module repository interfaces]
  Repo --> Local[Drift / encrypted SQLite]
  Local --> Outbox[Durable mutation outbox]
  Outbox --> Sync[Sync coordinator]
  Sync --> RPC[Authenticated mutation and pull RPCs]
  RPC --> PG[Supabase PostgreSQL / RLS / audit]
  Sync --> Auth[Supabase Auth / secure session storage]
  Scan[Camera / file importer] --> Crypto[Client document encryption]
  Crypto --> Files[Private encrypted local attachment files]
  Files --> Sync
  Sync --> Storage[Private Supabase Storage]
  PG -.wake hint.-> Sync
  Local --> Backup[Consistent encrypted backup / export service]
  Files --> Backup
  Backup --> Destination[User-selected encrypted destination / optional Drive]
```

## Module boundaries

| Boundary | Owns | Allowed dependencies |
| --- | --- | --- |
| Core | Configuration, typed errors, clock/IDs, secure storage, key access, database execution | Platform APIs and reviewed infrastructure packages |
| Identity/access | Auth session, local unlock, membership, roles, device revocation, cached grants | Core and server access adapter |
| Sync | Outbox, cursor, replay receipts, conflicts, attachment lifecycle | Core, access policy, typed module serializers |
| Family finance | Accounts, journal, budgets, savings/report projections | Core and sync contracts; exposes journal service |
| Wealth | Asset records, ownership and valuation observations | Core; journal links through application services |
| Liabilities | Contracts, approved schedules and repayments | Core; journal service for settlement |
| Business | Business scope, expenses/revenue, payroll records, inventory movement | Core, journal service; future billing adapter boundary only |
| Document vault | Document metadata, immutable versions, grants, encryption envelopes | Core, access, sync and private storage adapter |
| Analytics | Permission-filtered projections of authorized module records | Read-only module query contracts, FL Chart presentation |
| Backup/export | Snapshot manifests, archive encryption, recovery validation | Core and module export contracts |

Avoid direct module-to-module table writes. Use application services to coordinate
cross-module transactions. Derived dashboards have no independent editable totals.
The future billing module receives no schema/workflow in this phase.

## Mobile layout

`lib/app/` owns theme/router/app lifecycle; `lib/core/` owns infrastructure;
`lib/features/auth/` owns the session boundary; later modules get their own
`domain/`, `application/`, `data/`, `presentation/` only as they are implemented.
Do not build empty classes/folders for every future feature.

Riverpod injects repositories and owns disposal; GoRouter enforces presentation
gates. Neither is an authorization boundary. RLS and mutation RPCs independently
authorize requests. Unknown/expired permissions fail closed.

## Authentication and local unlock

Supabase Auth handles online identity. Store refresh/session data only in secure
platform storage. Disable implicit deep-link handling until exact verified links
and redirect allowlists are configured. No open registration; members are invited
by a trusted administrator through a server-only control plane.

Authentication, local unlock and authorization are separate states. On startup,
background, timeout and account change, close protected repositories and release
keys. A cached JWT alone does not unlock a cache. Production offline unlock needs
a previously authorized device, OS-backed key access and an approved lease policy.
Revoked/offline devices cannot be remotely erased instantly; communicate this limit.

Use separate encrypted database/files/key namespace per `(user, family, device)`;
never reuse a prior account's singleton database. Logout revokes tokens and clears
local credentials; user-visible pending-operation handling must precede destruction
of the only recoverable offline copy. Until that flow exists, protected data
features remain disabled.

## Implementation boundary of Phase 3

Only an app shell, theme/navigation, auth adapter boundary, encrypted local sync
metadata tables and tests may be implemented. The running shell must not create
family members, collect financial data, assume a working backend, unlock a real
vault or present fake financial reports. Full sync, document crypto/key exchange,
offline unlock and feature migrations remain later milestones after review.

## Backend execution

Typed security-invoker RPCs are preferred. Any required security-definer helper
has a fixed empty search path, qualified identifiers, minimal owner privileges,
explicit caller checks and restricted EXECUTE grants. Use database membership
state, not editable JWT user metadata, for current roles. Server time/revision,
mutation receipts, audit events and change-feed events commit atomically.
No administrative credentials enter Flutter. No cloud resources are created here.
