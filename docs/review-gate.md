# Revised architecture and database review gate

**Execution update:** the owner's autonomous end-to-end mission supersedes the
old stop-for-human-review gate below and authorizes implementation/engineering
decisions. See ADR 0004. The historical checklist is retained as engineering
acceptance work; it is not marked as a completed human review. Production
deployment and real-data safety boundaries remain in force.

**Status: revised architecture pending human review.** The owner's confirmed
product decisions below are authoritative; they do not approve this revised SQL,
financial implementation, production deployment or handling real family data.
Agents must not mark architecture review complete from automated test results.

## Product decisions confirmed by the owner — 2026-11-13

- [x] INR default, ₹, integer paise, Indian grouping and lakh/crore; extensible currencies and no financial floating point.
- [x] Separate authenticated accounts, shared family view/add/edit, immutable actor history and soft financial deletion.
- [x] Shared family document visibility with individual ownership metadata, authenticated audited access, encryption, enrollment and integrity.
- [x] Both encrypted local and Google Drive backups with independent verified success and clean-device recovery requirements.
- [x] Administrator-only membership/sensitive operations; outsider denial enforced on the backend.

Authority and consequences: [ADR 0003](decisions/0003-confirmed-product-architecture.md).
These are requirements, not claims of working features or completed recovery tests.

## Revised technical review required before financial implementation

Record reviewer/date/accepted changes here or in a reviewed PR. Do not re-open
confirmed product defaults as unresolved; assess their implementation design:

- [ ] Module boundaries and separate unresolved business policy; billing stays unspecified.
- [ ] Shared-write RLS/RPC contract, actor stamping, enrollment/session binding and administrator boundaries.
- [ ] Exact paise input/storage/formatting, accounting model, rounding, time zones and transfer invariants.
- [ ] Liability interest/EMI, business P&L/stock costing, valuation/ownership precision and dashboard formulas.
- [ ] Revised PostgreSQL/future SQLite schema, constraint review and safe Drift v1 migration path.
- [ ] Multi-member conflicts, atomic audit/feed, consistent snapshots, epochs and retention.
- [ ] Family-wide historical document keys, authenticated access gateway, audit integrity and rotation/recovery protocol.
- [ ] Local/Drive backup state/receipt verification, operator/custodian policy and source-independent clean-device recovery.
- [ ] Offline lease/revocation limitations, scheduling, retention and disaster trust/RPO/RTO.

## Evidence additionally required before production family data

- [ ] Real Auth/RLS/RPC/Storage adversarial tests with independent members and a second family.
- [ ] Multi-device replay/conflict/commit-order/epoch/tombstone fault tests.
- [ ] Document crypto/enrollment/gateway access-audit and interrupted-upload tests.
- [ ] Full clean-device restore from **each** backup destination, without source device/catalog/old keystore.
- [ ] Key loss/rotation, revoked membership and backend/Auth-loss disaster exercise.
- [ ] Android/iOS native security, session and background-scheduling tests.
- [ ] Refreshed dependencies/native advisories, export and deletion/retention verification.

The locked foundation may remain as infrastructure. No financial feature or live
backend deployment begins merely because these documentation updates are committed.
