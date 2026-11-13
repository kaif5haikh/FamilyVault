# Architecture and database review gate

**Status: pending human review.** Writing these documents or running a schema
check does not constitute approval. Phase 3 infrastructure can proceed; financial
features, financial migrations and real data entry cannot.

Before the first financial implementation, record the reviewer, date, decisions
and accepted changes here or in a linked reviewed PR:

- [ ] Product scope and module boundaries; restricted billing remains deferred.
- [ ] Role assignments, resource visibility and administrator access to private documents.
- [ ] Currency, precision, time zones, accounting model and transfer invariants.
- [ ] Liability interest/EMI rules and business P&L/stock costing basis.
- [ ] Asset ownership and dated valuation rules; dashboard formulas.
- [ ] PostgreSQL/SQLite schema, tenant-safe foreign keys and migration policy.
- [ ] Durable sync ordering, conflict UX, revocation epoch, tombstone retention.
- [ ] Document encryption, grant distribution, recovery and key rotation protocol.
- [ ] Offline unlock/revocation limits; backup retention and recovery objectives.

Before any production family data, additionally require:

- [ ] Executable RLS and storage-policy adversarial tests with distinct users/families.
- [ ] Server mutation receipt and commit-order feed implementation plus multi-device fault tests.
- [ ] Document encryption and interrupted-upload finalization tests.
- [ ] Key recovery and encrypted backup/restore exercise on an isolated installation.
- [ ] Android and iOS native security, session lifecycle and device tests.
- [ ] Dependency/native-binary vulnerability review and export/deletion verification.

No item is implicitly checked by autonomous repository initialization.
