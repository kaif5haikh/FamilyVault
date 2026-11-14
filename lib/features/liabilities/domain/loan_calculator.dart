import '../../../core/errors/app_failure.dart';
import '../../../core/finance/fixed_decimal.dart';
import '../../../core/finance/money.dart';

enum InterestMethod {
  unrecorded,
  simpleActual365,
  flatMonthly,
  reducingMonthly,
}

final class Installment {
  const Installment({
    required this.number,
    required this.dueOn,
    required this.principalMinor,
    required this.interestMinor,
    required this.balanceMinor,
  });
  final int number, principalMinor, interestMinor, balanceMinor;
  final DateTime dueOn;
  Money get payment => Money.fromMinor(
    checkedInt64(BigInt.from(principalMinor) + BigInt.from(interestMinor)),
  );
  @override
  String toString() => 'Installment([redacted])';
}

/// Estimates only. These routines never post interest or alter a contract ledger.
abstract final class LoanCalculator {
  static const _invalid = AppFailure(
    FailureCode.validation,
    'Check principal, rate and term (1–600 months).',
  );
  static void _validate(Money principal, int annualRateBps, int months) {
    if (principal.currency != Currency.inr ||
        principal.minor <= 0 ||
        annualRateBps < 0 ||
        annualRateBps > 1000000 ||
        months < 1 ||
        months > 600) {
      throw _invalid;
    }
  }

  static Money simpleInterest({
    required Money principal,
    required int annualRateBps,
    required DateTime from,
    required DateTime through,
  }) {
    _validate(principal, annualRateBps, 1);
    final first = DateTime.utc(from.year, from.month, from.day),
        last = DateTime.utc(through.year, through.month, through.day);
    final days = last.difference(first).inDays;
    if (days < 0 || days > 366 * 100) {
      throw _invalid;
    }
    return Money.fromMinor(
      checkedInt64(
        roundRatio(
          BigInt.from(principal.minor) *
              BigInt.from(annualRateBps) *
              BigInt.from(days),
          BigInt.from(10000 * 365),
        ),
      ),
    );
  }

  static Money reducingEmi({
    required Money principal,
    required int annualRateBps,
    required int months,
  }) {
    _validate(principal, annualRateBps, months);
    final p = BigInt.from(principal.minor), n = BigInt.from(months);
    if (annualRateBps == 0) {
      return Money.fromMinor(checkedInt64(roundRatio(p, n)));
    }
    final r = BigInt.from(annualRateBps), denominator = BigInt.from(120000);
    final power = (denominator + r).pow(months), base = denominator.pow(months);
    return Money.fromMinor(
      checkedInt64(roundRatio(p * r * power, denominator * (power - base))),
    );
  }

  static List<Installment> schedule({
    required Money principal,
    required int annualRateBps,
    required int months,
    required DateTime firstDueOn,
    required InterestMethod method,
  }) {
    _validate(principal, annualRateBps, months);
    if (method != InterestMethod.flatMonthly &&
        method != InterestMethod.reducingMonthly) {
      throw _invalid;
    }
    final p = BigInt.from(principal.minor),
        rate = BigInt.from(annualRateBps),
        divisor = BigInt.from(120000);
    final monthly = method == InterestMethod.reducingMonthly
        ? BigInt.from(
            reducingEmi(
              principal: principal,
              annualRateBps: annualRateBps,
              months: months,
            ).minor,
          )
        : roundRatio(p, BigInt.from(months)) + roundRatio(p * rate, divisor);
    checkedInt64(monthly);
    var remaining = p;
    final rows = <Installment>[];
    for (var i = 0; i < months && remaining > BigInt.zero; i++) {
      final interest = roundRatio(
        (method == InterestMethod.flatMonthly ? p : remaining) * rate,
        divisor,
      );
      var paidPrincipal = monthly - interest;
      if (paidPrincipal < BigInt.zero) {
        throw _invalid;
      }
      if (i == months - 1 || paidPrincipal > remaining) {
        paidPrincipal = remaining;
      }
      remaining -= paidPrincipal;
      checkedInt64(paidPrincipal + interest);
      final target = DateTime(firstDueOn.year, firstDueOn.month + i);
      final lastDay = DateTime(target.year, target.month + 1, 0).day;
      final day = firstDueOn.day > lastDay ? lastDay : firstDueOn.day;
      rows.add(
        Installment(
          number: i + 1,
          dueOn: DateTime(target.year, target.month, day),
          principalMinor: checkedInt64(paidPrincipal),
          interestMinor: checkedInt64(interest),
          balanceMinor: checkedInt64(remaining),
        ),
      );
    }
    return List.unmodifiable(rows);
  }
}
