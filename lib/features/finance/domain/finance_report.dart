import '../../../core/errors/app_failure.dart';
import '../data/ledger_repository.dart';

final class ReportPeriod {
  ReportPeriod._(this.start, this.end, this.label);
  factory ReportPeriod.month(int year, int month) {
    if (year < 1900 || year > 2200 || month < 1 || month > 12) {
      throw const AppFailure(
        FailureCode.validation,
        'Choose a valid reporting month.',
      );
    }
    return ReportPeriod._(
      LedgerRepository.dateOnly(DateTime(year, month)),
      LedgerRepository.dateOnly(DateTime(year, month + 1, 0)),
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}',
    );
  }
  factory ReportPeriod.year(int year) {
    if (year < 1900 || year > 2200) {
      throw const AppFailure(
        FailureCode.validation,
        'Choose a valid reporting year.',
      );
    }
    return ReportPeriod._(
      '$year-01-01',
      '$year-12-31',
      '$year (calendar year)',
    );
  }
  final String start, end, label;
}

final class FinanceReport {
  FinanceReport(this.snapshot, this.period) {
    activity = snapshot.balances(from: period.start, through: period.end);
    closing = snapshot.balances(through: period.end);
  }
  final FinanceSnapshot snapshot;
  final ReportPeriod period;
  late final Map<String, BigInt> activity, closing;
  BigInt _sum(String kind, Map<String, BigInt> values) => snapshot.accounts
      .where((a) => a.kind == kind)
      .fold(BigInt.zero, (sum, a) => sum + (values[a.id] ?? BigInt.zero));
  BigInt get income => -_sum('income', activity);
  BigInt get expenses => _sum('expense', activity);
  BigInt get savings => income - expenses;
  BigInt get assets => _sum('asset', closing);
  BigInt get liabilities => -_sum('liability', closing);
  BigInt get netWorth => assets - liabilities;
  Map<String, BigInt> categories(String kind) => {
    for (final a in snapshot.accounts.where((a) => a.kind == kind))
      if ((activity[a.id] ?? BigInt.zero) != BigInt.zero)
        a.id: kind == 'income' ? -activity[a.id]! : activity[a.id]!,
  };
  Map<String, BigInt> get positiveAssetAllocation {
    final result = <String, BigInt>{};
    for (final a in snapshot.accounts.where((a) => a.kind == 'asset')) {
      final value = closing[a.id] ?? BigInt.zero;
      if (value > BigInt.zero) {
        result.update(a.subtype, (v) => v + value, ifAbsent: () => value);
      }
    }
    return result;
  }
}
