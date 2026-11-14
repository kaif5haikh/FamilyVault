import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/features/liabilities/domain/loan_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reducing EMI matches independent high-precision Decimal reference fixtures', () {
    // Oracle: Python Decimal precision=100, HALF_UP to paise, nominal APR/12.
    for (final fixture in <(String, int, int, String)>[
      ('100000', 1200, 12, '8884.88'),
      ('2500000', 850, 240, '21695.58'),
      ('500000', 1025, 60, '10685.13'),
    ]) {
      expect(
        LoanCalculator.reducingEmi(
          principal: Money.parseInr(fixture.$1),
          annualRateBps: fixture.$2,
          months: fixture.$3,
        ),
        Money.parseInr(fixture.$4),
      );
    }
    expect(
      LoanCalculator.reducingEmi(
        principal: Money.parseInr('100'),
        annualRateBps: 0,
        months: 3,
      ),
      Money.parseInr('33.33'),
    );
  });
  test(
    'schedules conserve principal, clamp month end and adjust the final paise',
    () {
      final principal = Money.parseInr('100000');
      for (final method in [
        InterestMethod.flatMonthly,
        InterestMethod.reducingMonthly,
      ]) {
        final rows = LoanCalculator.schedule(
          principal: principal,
          annualRateBps: 1200,
          months: 12,
          firstDueOn: DateTime(2024, 1, 31),
          method: method,
        );
        expect(rows.length, 12);
        expect(rows.last.balanceMinor, 0);
        expect(
          rows
              .map((r) => r.principalMinor)
              .fold(BigInt.zero, (a, b) => a + BigInt.from(b)),
          BigInt.from(principal.minor),
        );
        expect(rows[1].dueOn, DateTime(2024, 2, 29));
        expect(rows[2].dueOn, DateTime(2024, 3, 31));
        expect(
          rows.every(
            (r) =>
                r.interestMinor >= 0 &&
                r.balanceMinor >= 0 &&
                r.payment.minor >= 0,
          ),
          isTrue,
        );
        if (method == InterestMethod.flatMonthly) {
          expect(rows.fold(0, (sum, r) => sum + r.interestMinor), 1200000);
          expect(rows.last.principalMinor, 833337);
        }
      }
      final tiny = LoanCalculator.schedule(
        principal: Money.fromMinor(1),
        annualRateBps: 0,
        months: 12,
        firstDueOn: DateTime(2026, 1, 1),
        method: InterestMethod.reducingMonthly,
      );
      expect(tiny.last.payment.minor, 1);
      expect(tiny.last.balanceMinor, 0);
    },
  );
  test(
    'ACT/365 leap-year interest is explicit; invalid terms and overflow fail',
    () {
      expect(
        LoanCalculator.simpleInterest(
          principal: Money.parseInr('100000'),
          annualRateBps: 1200,
          from: DateTime(2024, 1, 1),
          through: DateTime(2025, 1, 1),
        ),
        Money.parseInr('12032.88'),
      );
      expect(
        () => LoanCalculator.reducingEmi(
          principal: Money.fromMinor(9223372036854775807),
          annualRateBps: 1000000,
          months: 1,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => LoanCalculator.reducingEmi(
          principal: Money.parseInr('100'),
          annualRateBps: -1,
          months: 12,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => LoanCalculator.schedule(
          principal: Money.parseInr('100'),
          annualRateBps: 1200,
          months: 12,
          firstDueOn: DateTime(2026),
          method: InterestMethod.unrecorded,
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}
