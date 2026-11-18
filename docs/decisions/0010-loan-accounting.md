# ADR 0010: principal, paid interest and loan estimates

Status: implemented and tested in the local vault.

Borrowing credits a dedicated liability account. Money lent debits a dedicated
receivable account. Record a cash or bank movement when funds change hands, or
carry in an existing opening balance against equity. Reports derive outstanding
principal from the ledger at the selected date.

A repayment records principal and paid interest separately. Only interest
affects income or expense. A repayment cannot exceed the outstanding principal
or predate the opening. Correcting an opening reverses its original journal and
posts a replacement with a principal and date that fit the existing repayments.
Repayment corrections likewise reverse and replace in one database transaction.
The contract revision, original and replacement journals, payment and audit
travel in the same sync envelope. Settled loans can be archived and restored.

An unrecorded annual rate remains unknown. A confirmed zero rate is allowed.
Estimates use the selected method, original terms and documented rounding from
ADR 0008. The simple-interest view assumes constant opening principal for its
date range. Monthly estimates show a projected schedule. Actual payments are
separate events. Estimates create no ledger entries or accrued interest.
