# ADR 0026 Shared business accounting

**Status** Shared profiles, revenue and ordinary business expenses were tested
with two enrolled devices on 2026-11-19. Inventory and salaries follow.

Keep each business in the family ledger with three managed accounts for stock
value, stock cost and wages. A business profile creates or renames its related
accounts and writes one accepted receipt. Other ledger operations cannot
rename those accounts directly.

Revenue and operating expenses use the ordinary journal protocol. Each
business reference must identify an active business in the same family.
The two postings must match the selected transaction kind and use ordinary
accounts. An exact reversal and any replacement retain the business
attribution. Stock and salary journal effects use separate typed scopes.

Profit and loss use the posted ledger for the business and include the
reversals, so corrections preserve the original amounts and affect the net
report only once. The restricted billing extension remains unspecified.
