/// Local invariant guards. Backend authorization remains an independent control.
List<String> wealthGuards() => [
  for (final table in [
    'wealth_assets',
    'asset_ownerships',
    'debt_contracts',
    'businesses',
    'stock_items',
    'workers',
  ]) ...[
    '''CREATE TRIGGER IF NOT EXISTS ${table}_provenance_v3 BEFORE UPDATE ON $table
       WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id
         OR NEW.created_by IS NOT OLD.created_by OR NEW.created_at_us IS NOT OLD.created_at_us
         OR NEW.revision <> OLD.revision + 1
       BEGIN SELECT RAISE(ABORT, 'Immutable identity or stale revision'); END''',
    '''CREATE TRIGGER IF NOT EXISTS ${table}_no_delete_v3 BEFORE DELETE ON $table
       BEGIN SELECT RAISE(ABORT, 'Use an audited tombstone'); END''',
  ],
  for (final table in [
    'asset_valuations',
    'debt_repayments',
    'stock_movements',
    'salary_payments',
    'aggregate_journal_links',
  ]) ...[
    '''CREATE TRIGGER IF NOT EXISTS ${table}_no_update_v3 BEFORE UPDATE ON $table
       BEGIN SELECT RAISE(ABORT, 'Event is append-only'); END''',
    '''CREATE TRIGGER IF NOT EXISTS ${table}_no_delete_v3 BEFORE DELETE ON $table
       BEGIN SELECT RAISE(ABORT, 'Event is append-only'); END''',
  ],
  for (final table in [
    'property_details',
    'metal_details',
    'investment_details',
  ]) ...[
    '''CREATE TRIGGER IF NOT EXISTS ${table}_identity_v3 BEFORE UPDATE ON $table
       WHEN NEW.asset_id IS NOT OLD.asset_id OR NEW.family_id IS NOT OLD.family_id
       BEGIN SELECT RAISE(ABORT, 'Child identity is immutable'); END''',
    '''CREATE TRIGGER IF NOT EXISTS ${table}_no_delete_v3 BEFORE DELETE ON $table
       BEGIN SELECT RAISE(ABORT, 'Retain asset history'); END''',
  ],
  '''CREATE TRIGGER IF NOT EXISTS wealth_account_scope_v3 BEFORE INSERT ON wealth_assets
     WHEN NOT EXISTS (SELECT 1 FROM ledger_accounts a WHERE a.id = NEW.account_id
       AND a.family_id = NEW.family_id AND a.kind = 'asset' AND a.currency = NEW.currency AND a.deleted_at_us IS NULL)
     BEGIN SELECT RAISE(ABORT, 'Asset needs a family asset account'); END''',
  '''CREATE TRIGGER IF NOT EXISTS wealth_account_identity_v3 BEFORE UPDATE ON wealth_assets
     WHEN NEW.account_id IS NOT OLD.account_id OR NEW.kind IS NOT OLD.kind OR NEW.currency IS NOT OLD.currency
     BEGIN SELECT RAISE(ABORT, 'Asset accounting identity is immutable'); END''',
  '''CREATE TRIGGER IF NOT EXISTS property_type_v3 BEFORE INSERT ON property_details
     WHEN NOT EXISTS (SELECT 1 FROM wealth_assets a WHERE a.id = NEW.asset_id AND a.family_id = NEW.family_id AND a.kind IN ('property', 'land'))
     BEGIN SELECT RAISE(ABORT, 'Property details need a property holding'); END''',
  '''CREATE TRIGGER IF NOT EXISTS metal_type_v3 BEFORE INSERT ON metal_details
     WHEN NOT EXISTS (SELECT 1 FROM wealth_assets a WHERE a.id = NEW.asset_id AND a.family_id = NEW.family_id
       AND (a.kind = NEW.metal OR a.kind = 'jewellery')) OR (NEW.metal = 'silver' AND NEW.karat IS NOT NULL)
     BEGIN SELECT RAISE(ABORT, 'Metal details do not match the holding'); END''',
  '''CREATE TRIGGER IF NOT EXISTS metal_type_update_v3 BEFORE UPDATE ON metal_details
     WHEN NOT EXISTS (SELECT 1 FROM wealth_assets a WHERE a.id = NEW.asset_id AND a.family_id = NEW.family_id
       AND (a.kind = NEW.metal OR a.kind = 'jewellery')) OR (NEW.metal = 'silver' AND NEW.karat IS NOT NULL)
     BEGIN SELECT RAISE(ABORT, 'Metal details do not match the holding'); END''',
  '''CREATE TRIGGER IF NOT EXISTS investment_type_v3 BEFORE INSERT ON investment_details
     WHEN NOT EXISTS (SELECT 1 FROM wealth_assets a WHERE a.id = NEW.asset_id AND a.family_id = NEW.family_id AND a.kind = 'investment')
     BEGIN SELECT RAISE(ABORT, 'Investment details need an investment holding'); END''',
  '''CREATE UNIQUE INDEX IF NOT EXISTS active_asset_owner_v3 ON asset_ownerships(family_id, asset_id, member_id)
     WHERE deleted_at_us IS NULL AND member_id IS NOT NULL''',
  for (final event in ['INSERT', 'UPDATE'])
    '''CREATE TRIGGER IF NOT EXISTS ownership_total_${event.toLowerCase()}_v3 BEFORE $event ON asset_ownerships
       WHEN NEW.deleted_at_us IS NULL AND NEW.share_bps + coalesce((SELECT sum(share_bps) FROM asset_ownerships o
         WHERE o.family_id = NEW.family_id AND o.asset_id = NEW.asset_id AND o.deleted_at_us IS NULL AND o.id <> NEW.id), 0)
         > (SELECT family_ownership_bps FROM wealth_assets WHERE id = NEW.asset_id AND family_id = NEW.family_id)
       BEGIN SELECT RAISE(ABORT, 'Allocated ownership exceeds the family share'); END''',
  '''CREATE TRIGGER IF NOT EXISTS asset_share_update_v3 BEFORE UPDATE OF family_ownership_bps ON wealth_assets
     WHEN NEW.family_ownership_bps < coalesce((SELECT sum(share_bps) FROM asset_ownerships
       WHERE family_id = NEW.family_id AND asset_id = NEW.id AND deleted_at_us IS NULL), 0)
     BEGIN SELECT RAISE(ABORT, 'Reallocate ownership before reducing the family share'); END''',
  '''CREATE TRIGGER IF NOT EXISTS valuation_journal_v3 BEFORE INSERT ON asset_valuations
     WHEN NEW.journal_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM ledger_journals j WHERE j.id = NEW.journal_id
       AND j.family_id = NEW.family_id AND j.status = 'posted' AND j.related_entity_id = NEW.asset_id)
     BEGIN SELECT RAISE(ABORT, 'Valuation needs its posted journal'); END''',
  '''CREATE TRIGGER IF NOT EXISTS valuation_revision_v3 BEFORE INSERT ON asset_valuations
     WHEN NOT EXISTS (SELECT 1 FROM wealth_assets a WHERE a.id = NEW.asset_id AND a.family_id = NEW.family_id AND a.revision = NEW.asset_revision)
     BEGIN SELECT RAISE(ABORT, 'Valuation needs its current asset revision'); END''',
  '''CREATE TRIGGER IF NOT EXISTS valuation_no_silent_post_v3 BEFORE INSERT ON asset_valuations
     WHEN NEW.journal_id IS NULL AND NEW.family_value_minor <> NEW.previous_family_value_minor
     BEGIN SELECT RAISE(ABORT, 'A changed valuation needs a posted journal'); END''',
  '''CREATE TRIGGER IF NOT EXISTS valuation_posting_delta_v3 BEFORE INSERT ON asset_valuations
     WHEN NEW.journal_id IS NOT NULL AND coalesce((SELECT sum(p.amount_minor) FROM ledger_postings p
       JOIN wealth_assets a ON a.account_id = p.account_id AND a.family_id = p.family_id
       WHERE p.journal_id = NEW.journal_id AND a.id = NEW.asset_id), 0)
       <> NEW.family_value_minor - NEW.previous_family_value_minor
     BEGIN SELECT RAISE(ABORT, 'Valuation posting does not match the declared change'); END''',
  '''CREATE TRIGGER IF NOT EXISTS debt_account_v3 BEFORE INSERT ON debt_contracts
     WHEN NOT EXISTS (SELECT 1 FROM ledger_accounts a WHERE a.id = NEW.account_id AND a.family_id = NEW.family_id
       AND a.kind = CASE WHEN NEW.direction = 'lent' THEN 'asset' ELSE 'liability' END
       AND a.currency = NEW.currency AND a.deleted_at_us IS NULL)
     BEGIN SELECT RAISE(ABORT, 'Debt account does not match its direction'); END''',
  '''CREATE TRIGGER IF NOT EXISTS debt_identity_v3 BEFORE UPDATE ON debt_contracts
     WHEN NEW.account_id IS NOT OLD.account_id OR NEW.direction IS NOT OLD.direction OR NEW.currency IS NOT OLD.currency
     BEGIN SELECT RAISE(ABORT, 'Debt accounting identity is immutable'); END''',
  '''CREATE TRIGGER IF NOT EXISTS repayment_journal_v3 BEFORE INSERT ON debt_repayments
     WHEN NOT EXISTS (SELECT 1 FROM ledger_journals j WHERE j.id = NEW.journal_id AND j.family_id = NEW.family_id
       AND j.status = 'posted' AND j.related_entity_id = NEW.contract_id AND j.occurred_on = NEW.paid_on)
     BEGIN SELECT RAISE(ABORT, 'Repayment needs its posted journal'); END''',
  '''CREATE TRIGGER IF NOT EXISTS business_accounts_v3 BEFORE INSERT ON businesses
     WHEN NOT EXISTS (SELECT 1 FROM ledger_accounts a WHERE a.id = NEW.inventory_account_id AND a.family_id = NEW.family_id AND a.kind = 'asset' AND a.currency = NEW.currency)
       OR NOT EXISTS (SELECT 1 FROM ledger_accounts a WHERE a.id = NEW.cost_of_goods_account_id AND a.family_id = NEW.family_id AND a.kind = 'expense' AND a.currency = NEW.currency)
       OR NOT EXISTS (SELECT 1 FROM ledger_accounts a WHERE a.id = NEW.salary_account_id AND a.family_id = NEW.family_id AND a.kind = 'expense' AND a.currency = NEW.currency)
     BEGIN SELECT RAISE(ABORT, 'Business accounts are invalid'); END''',
  '''CREATE TRIGGER IF NOT EXISTS business_identity_v3 BEFORE UPDATE ON businesses
     WHEN NEW.inventory_account_id IS NOT OLD.inventory_account_id OR NEW.cost_of_goods_account_id IS NOT OLD.cost_of_goods_account_id
       OR NEW.salary_account_id IS NOT OLD.salary_account_id OR NEW.currency IS NOT OLD.currency
     BEGIN SELECT RAISE(ABORT, 'Business accounting identity is immutable'); END''',
  '''CREATE TRIGGER IF NOT EXISTS journal_business_v3 BEFORE UPDATE OF status ON ledger_journals
     WHEN NEW.status = 'posted' AND NEW.business_id IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM businesses b WHERE b.id = NEW.business_id AND b.family_id = NEW.family_id AND b.deleted_at_us IS NULL)
     BEGIN SELECT RAISE(ABORT, 'Journal business is unavailable'); END''',
  '''CREATE UNIQUE INDEX IF NOT EXISTS active_stock_sku_v3 ON stock_items(family_id, business_id, sku COLLATE NOCASE)
     WHERE deleted_at_us IS NULL AND sku IS NOT NULL''',
  '''CREATE TRIGGER IF NOT EXISTS stock_position_create_v3 AFTER INSERT ON stock_items
     BEGIN INSERT INTO stock_positions(stock_item_id, family_id, quantity, cost_pool_minor) VALUES (NEW.id, NEW.family_id, 0, 0); END''',
  '''CREATE TRIGGER IF NOT EXISTS stock_event_scope_v3 BEFORE INSERT ON stock_movements
     WHEN NOT EXISTS (SELECT 1 FROM stock_items s JOIN businesses b ON b.id = s.business_id AND b.family_id = s.family_id
       WHERE s.id = NEW.stock_item_id AND s.family_id = NEW.family_id AND s.business_id = NEW.business_id
       AND s.revision = NEW.item_revision
       AND s.deleted_at_us IS NULL AND b.deleted_at_us IS NULL)
       OR (NEW.journal_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM ledger_journals j WHERE j.id = NEW.journal_id
         AND j.family_id = NEW.family_id AND j.business_id = NEW.business_id AND j.related_entity_id = NEW.stock_item_id
         AND j.status = 'posted' AND j.occurred_on = NEW.occurred_on))
     BEGIN SELECT RAISE(ABORT, 'Stock event scope is invalid'); END''',
  '''CREATE TRIGGER IF NOT EXISTS stock_event_chronology_v3 BEFORE INSERT ON stock_movements
     WHEN NEW.reverses_id IS NULL AND EXISTS (SELECT 1 FROM stock_movements m
       WHERE m.family_id = NEW.family_id AND m.stock_item_id = NEW.stock_item_id AND m.reverses_id IS NULL
         AND NOT EXISTS (SELECT 1 FROM stock_movements r WHERE r.reverses_id = m.id) AND m.occurred_on > NEW.occurred_on)
     BEGIN SELECT RAISE(ABORT, 'Stock dates must follow active cost history'); END''',
  '''CREATE TRIGGER IF NOT EXISTS stock_event_reversal_v3 BEFORE INSERT ON stock_movements
     WHEN NEW.reverses_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM stock_movements o
       WHERE o.id = NEW.reverses_id AND o.family_id = NEW.family_id AND o.stock_item_id = NEW.stock_item_id
         AND o.business_id = NEW.business_id AND o.reverses_id IS NULL AND o.occurred_on = NEW.occurred_on
         AND NEW.quantity_delta = -o.quantity_delta AND NEW.value_delta_minor = -o.value_delta_minor
         AND NOT EXISTS (SELECT 1 FROM stock_movements r WHERE r.reverses_id = o.id)
         AND NOT EXISTS (SELECT 1 FROM stock_movements later WHERE later.family_id = NEW.family_id AND later.stock_item_id = NEW.stock_item_id
           AND later.reverses_id IS NULL AND (later.item_revision > o.item_revision OR (later.item_revision = o.item_revision AND later.event_index > o.event_index))
           AND NOT EXISTS (SELECT 1 FROM stock_movements r WHERE r.reverses_id = later.id))
         AND ((o.journal_id IS NULL AND NEW.journal_id IS NULL) OR EXISTS (SELECT 1 FROM ledger_journals j
           WHERE j.id = NEW.journal_id AND j.reverses_id = o.journal_id AND j.status = 'posted')))
     BEGIN SELECT RAISE(ABORT, 'Only the latest active stock event can be reversed exactly'); END''',
  '''CREATE TRIGGER IF NOT EXISTS stock_position_apply_v3 AFTER INSERT ON stock_movements
     BEGIN UPDATE stock_positions SET quantity = quantity + NEW.quantity_delta,
       cost_pool_minor = cost_pool_minor + NEW.value_delta_minor
       WHERE stock_item_id = NEW.stock_item_id AND family_id = NEW.family_id;
       SELECT CASE WHEN changes() <> 1 THEN RAISE(ABORT, 'Stock position is missing') END;
     END''',
  '''CREATE TRIGGER IF NOT EXISTS stock_archive_v3 BEFORE UPDATE OF deleted_at_us ON stock_items
     WHEN NEW.deleted_at_us IS NOT NULL AND EXISTS (SELECT 1 FROM stock_positions WHERE stock_item_id = NEW.id AND quantity <> 0)
     BEGIN SELECT RAISE(ABORT, 'Stock must be empty before archival'); END''',
  '''CREATE TRIGGER IF NOT EXISTS salary_journal_v3 BEFORE INSERT ON salary_payments
     WHEN NOT EXISTS (SELECT 1 FROM ledger_journals j WHERE j.id = NEW.journal_id AND j.family_id = NEW.family_id
       AND j.business_id = NEW.business_id AND j.related_entity_id = NEW.worker_id AND j.status = 'posted' AND j.occurred_on = NEW.paid_on)
     BEGIN SELECT RAISE(ABORT, 'Salary needs its posted journal'); END''',
  '''CREATE TRIGGER IF NOT EXISTS aggregate_link_scope_v3 BEFORE INSERT ON aggregate_journal_links
     WHEN NOT EXISTS (SELECT 1 FROM ledger_journals j WHERE j.id = NEW.journal_id AND j.family_id = NEW.family_id
       AND j.related_entity_id = NEW.aggregate_id AND j.status = 'posted')
       OR (NEW.aggregate_type IN ('asset', 'asset_rent') AND NOT EXISTS (SELECT 1 FROM wealth_assets a WHERE a.id = NEW.aggregate_id AND a.family_id = NEW.family_id))
       OR (NEW.aggregate_type = 'debt' AND NOT EXISTS (SELECT 1 FROM debt_contracts d WHERE d.id = NEW.aggregate_id AND d.family_id = NEW.family_id))
       OR (NEW.aggregate_type = 'stock' AND NOT EXISTS (SELECT 1 FROM stock_items s WHERE s.id = NEW.aggregate_id AND s.family_id = NEW.family_id))
       OR (NEW.aggregate_type = 'salary' AND NOT EXISTS (SELECT 1 FROM workers w WHERE w.id = NEW.aggregate_id AND w.family_id = NEW.family_id))
     BEGIN SELECT RAISE(ABORT, 'Journal aggregate linkage is invalid'); END''',
];
