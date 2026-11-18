import 'loan_calculator.dart';

enum DebtDirection {
  borrowed('borrowed'),
  bankLoan('bank_loan'),
  lent('lent');

  const DebtDirection(this.code);
  final String code;
}

final class DebtTerms {
  const DebtTerms({
    this.method = InterestMethod.unrecorded,
    this.annualRateBps,
    this.termMonths,
    this.emiMinor,
    this.firstDueOn,
    this.dueOn,
  });
  final InterestMethod method;
  final int? annualRateBps, termMonths, emiMinor;
  final String? firstDueOn, dueOn;

  Map<String, Object?> toJson() => {
    'interest_method': method.name,
    'annual_rate_bps': annualRateBps,
    'term_months': termMonths,
    'emi_minor': emiMinor,
    'first_due_on': firstDueOn,
    'due_on': dueOn,
  };
}

final class DebtDraft {
  const DebtDraft({
    required this.name,
    required this.direction,
    required this.counterparty,
    required this.principalMinor,
    required this.startedOn,
    this.cashAccountId,
    this.terms = const DebtTerms(),
    this.notes = '',
  });
  final String name, counterparty, startedOn, notes;
  final DebtDirection direction;
  final int principalMinor;
  final String? cashAccountId;
  final DebtTerms terms;

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'direction': direction.code,
    'counterparty': counterparty.trim(),
    'principal_minor': principalMinor,
    'started_on': startedOn,
    'cash_account_id': cashAccountId,
    ...terms.toJson(),
    'notes': notes.trim(),
  };
}

final class RepaymentDraft {
  const RepaymentDraft({
    required this.principalMinor,
    required this.interestMinor,
    required this.accountId,
    required this.paidOn,
    this.notes = '',
  });
  final int principalMinor, interestMinor;
  final String accountId, paidOn, notes;
  Map<String, Object?> toJson() => {
    'principal_minor': principalMinor,
    'interest_minor': interestMinor,
    'account_id': accountId,
    'paid_on': paidOn,
    'notes': notes.trim(),
  };
}
