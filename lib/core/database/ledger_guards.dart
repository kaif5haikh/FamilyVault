/// SQL guards complement repository validation and remain active in release builds.
const ledgerGuards = <String>[
  '''CREATE TRIGGER IF NOT EXISTS ledger_no_posted_insert BEFORE INSERT ON ledger_journals
     WHEN NEW.status = 'posted' BEGIN SELECT RAISE(ABORT, 'Seal a balanced draft'); END''',
  '''CREATE TRIGGER IF NOT EXISTS ledger_seal BEFORE UPDATE OF status ON ledger_journals
     WHEN NEW.status = 'posted' AND OLD.status = 'draft'
     BEGIN
       SELECT CASE WHEN (SELECT count(*) FROM ledger_postings WHERE journal_id = NEW.id) < 2
         OR (SELECT coalesce(sum(amount_minor), 0) FROM ledger_postings WHERE journal_id = NEW.id) <> 0
         THEN RAISE(ABORT, 'Unbalanced journal') END;
       SELECT CASE WHEN EXISTS (SELECT 1 FROM ledger_postings p JOIN ledger_accounts a ON a.id = p.account_id
         WHERE p.journal_id = NEW.id AND (a.family_id <> NEW.family_id OR a.currency <> NEW.currency OR a.deleted_at_us IS NOT NULL))
         THEN RAISE(ABORT, 'Invalid posting account') END;
       SELECT CASE WHEN (NEW.kind = 'reversal') <> (NEW.reverses_id IS NOT NULL)
         THEN RAISE(ABORT, 'Invalid reversal') END;
       SELECT CASE WHEN NEW.reverses_id IS NOT NULL AND (
         NOT EXISTS (SELECT 1 FROM ledger_journals j WHERE j.id = NEW.reverses_id AND j.family_id = NEW.family_id
           AND j.status = 'posted' AND j.kind <> 'reversal' AND j.deleted_at_us IS NULL AND j.occurred_on = NEW.occurred_on)
         OR (SELECT count(*) FROM ledger_postings WHERE journal_id = NEW.id) <>
            (SELECT count(*) FROM ledger_postings WHERE journal_id = NEW.reverses_id)
         OR EXISTS (SELECT 1 FROM ledger_postings p WHERE p.journal_id = NEW.id AND NOT EXISTS
           (SELECT 1 FROM ledger_postings o WHERE o.journal_id = NEW.reverses_id AND o.position = p.position
             AND o.account_id = p.account_id AND o.amount_minor = -p.amount_minor)))
         THEN RAISE(ABORT, 'Reversal must exactly negate original') END;
     END''',
  '''CREATE TRIGGER IF NOT EXISTS posted_journal_immutable BEFORE UPDATE ON ledger_journals
     WHEN OLD.status = 'posted' AND (
       NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
       OR NEW.kind IS NOT OLD.kind OR NEW.occurred_on IS NOT OLD.occurred_on OR NEW.description IS NOT OLD.description
       OR NEW.currency IS NOT OLD.currency OR NEW.status IS NOT OLD.status OR NEW.reverses_id IS NOT OLD.reverses_id
       OR NEW.business_id IS NOT OLD.business_id OR NEW.related_entity_id IS NOT OLD.related_entity_id
       OR NEW.created_at_us IS NOT OLD.created_at_us OR NEW.revision <> OLD.revision + 1
       OR OLD.deleted_at_us IS NOT NULL OR NEW.deleted_at_us IS NULL
       OR NOT EXISTS (SELECT 1 FROM ledger_journals r WHERE r.reverses_id = OLD.id AND r.status = 'posted'))
     BEGIN SELECT RAISE(ABORT, 'Posted journal is immutable'); END''',
  '''CREATE TRIGGER IF NOT EXISTS used_account_identity BEFORE UPDATE ON ledger_accounts
     WHEN EXISTS (SELECT 1 FROM ledger_postings WHERE account_id = OLD.id) AND
       (NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.kind IS NOT OLD.kind
        OR NEW.subtype IS NOT OLD.subtype OR NEW.currency IS NOT OLD.currency
        OR NEW.system_account IS NOT OLD.system_account OR NEW.created_by IS NOT OLD.created_by
        OR NEW.created_at_us IS NOT OLD.created_at_us)
     BEGIN SELECT RAISE(ABORT, 'Used account identity is immutable'); END''',
  '''CREATE TRIGGER IF NOT EXISTS posted_journal_no_delete BEFORE DELETE ON ledger_journals
     WHEN OLD.status = 'posted' BEGIN SELECT RAISE(ABORT, 'Use an audited reversal'); END''',
  '''CREATE TRIGGER IF NOT EXISTS posted_posting_no_insert BEFORE INSERT ON ledger_postings
     WHEN (SELECT status FROM ledger_journals WHERE id = NEW.journal_id) = 'posted'
     BEGIN SELECT RAISE(ABORT, 'Posted journal is immutable'); END''',
  '''CREATE TRIGGER IF NOT EXISTS posted_posting_no_update BEFORE UPDATE ON ledger_postings
     WHEN (SELECT status FROM ledger_journals WHERE id = OLD.journal_id) = 'posted'
       OR (SELECT status FROM ledger_journals WHERE id = NEW.journal_id) = 'posted'
     BEGIN SELECT RAISE(ABORT, 'Posted journal is immutable'); END''',
  '''CREATE TRIGGER IF NOT EXISTS posted_posting_no_delete BEFORE DELETE ON ledger_postings
     WHEN (SELECT status FROM ledger_journals WHERE id = OLD.journal_id) = 'posted'
     BEGIN SELECT RAISE(ABORT, 'Posted journal is immutable'); END''',
  '''CREATE TRIGGER IF NOT EXISTS local_audit_no_update BEFORE UPDATE ON local_audit_events
     BEGIN SELECT RAISE(ABORT, 'Audit is append-only'); END''',
  '''CREATE TRIGGER IF NOT EXISTS local_audit_no_delete BEFORE DELETE ON local_audit_events
     BEGIN SELECT RAISE(ABORT, 'Audit is append-only'); END''',
  '''CREATE UNIQUE INDEX IF NOT EXISTS active_monthly_budget ON monthly_budgets(family_id, account_id, month)
     WHERE deleted_at_us IS NULL''',
];
