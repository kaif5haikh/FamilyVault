# ADR 0011: business ledger, inventory and wages

Status: implemented and tested in the local vault.

Business records use the same family membership and ledger as household
records. Each business has separate inventory, stock-cost and wage accounts.
Tag revenue and operating expenses with the business ID so period reports can
separate them from household entries and from other businesses. Salaries record
actual payments. Agreed monthly wages do not create automatic expenses.

Purchases credit the chosen cash or bank account and debit inventory at the
recorded price. Opening stock uses equity. Issuing stock debits cost of goods
and credits inventory at the weighted average cost. Exact paise rounding and
the last-unit remainder rule preserve the full original cost. A stock-count
decrease uses the same cost rule. Sales revenue is recorded separately.

Stock corrections append the reversal of the latest active movement and
optionally its replacement. Stock, accounting, audit and outbox changes commit
together. Salary corrections follow the same journal reversal pattern. The
inventory and wage accounts are protected from generic ledger writes.

The business report sums posted revenue and expenses, including reversals,
within the chosen month. It describes recorded profit. Future tax or billing
requirements will be handled separately when specified.
