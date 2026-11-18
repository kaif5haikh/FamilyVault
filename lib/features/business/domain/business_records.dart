enum StockEntryKind {
  opening('opening'),
  purchase('purchase'),
  stockOut('stock_out'),
  adjustment('adjustment');

  const StockEntryKind(this.code);
  final String code;
  bool get isReceipt => this == opening || this == purchase;
}

final class StockEntryDraft {
  const StockEntryDraft({
    required this.kind,
    required this.units,
    required this.date,
    this.costMinor,
    this.cashAccountId,
    this.notes = '',
  });
  final StockEntryKind kind;
  final int units;
  final int? costMinor;
  final String date, notes;
  final String? cashAccountId;

  Map<String, Object?> toJson() => {
    'kind': kind.code,
    'units': units,
    'date': date,
    'cost_minor': costMinor,
    'cash_account_id': cashAccountId,
    'notes': notes.trim(),
  };
}

final class SalaryDraft {
  const SalaryDraft({
    required this.amountMinor,
    required this.period,
    required this.paidOn,
    required this.cashAccountId,
    this.notes = '',
  });
  final int amountMinor;
  final String period, paidOn, cashAccountId, notes;

  Map<String, Object?> toJson() => {
    'amount_minor': amountMinor,
    'period': period,
    'paid_on': paidOn,
    'cash_account_id': cashAccountId,
    'notes': notes.trim(),
  };
}
