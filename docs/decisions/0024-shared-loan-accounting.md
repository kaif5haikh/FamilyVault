# ADR 0024 Shared loans and repayments

**Status** Implemented and tested with two approved devices using local
Supabase on 2026-11-19.

A loan keeps its original direction, managed account and creator. The
server applies edits by exact revision and retains the terms, repayment
rows and linked journal history. A repayment records the actual split
between principal and interest in paise. Authorized members can view the same
outstanding principal and history. Terms metadata supports the local
interest and EMI estimates.

Before accepting a repayment, derive signed outstanding principal from the
posted ledger. Require the cash, principal and interest lines to equal the
declared payment exactly and use that family's approved accounts. A repayment
cannot move the outstanding principal below zero. Corrections use an exact
reversal and a replacement payment where supplied. A principal correction
reverses the active opening journal and creates a fresh one that covers the
historical repayments. The new start date must precede those repayments.

Allow archiving after principal is settled and preserve every journal and
repayment. Restore by revision with explicit nulls in the receiving cache.
Accept the loan mutation and allocate its receipt in the same PostgreSQL
transaction. The Drift v6 loan tables remain the local projection.
