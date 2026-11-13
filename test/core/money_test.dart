import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/errors/app_failure.dart';

void main() {
  test('Indian exact formatting and compact presentation', () {
    expect(Money.fromMinor(0).format(), '₹0.00');
    expect(Money.fromMinor(1).format(), '₹0.01');
    expect(Money.fromMinor(123456789).format(), '₹12,34,567.89');
    expect(Money.fromMinor(10000000).compact(), '₹1 lakh');
    expect(Money.fromMinor(1000000000).compact(), '₹1 crore');
    expect(Money.fromMinor(-10000000).compact(), '-₹1 lakh');
    expect(
      Money.fromMinor(-9223372036854775808).format(),
      '-₹92,23,37,20,36,85,47,758.08',
    );
  });
  test('exact decimal parsing, no floating point or malformed grouping', () {
    for (final input in ['1234567.89', '₹12,34,567.89', '12,34,567.89']) {
      expect(Money.parseInr(input).minor, 123456789);
    }
    expect(Money.parseInr('-0.01').minor, -1);
    expect(Money.parseInr('₹1.2').minor, 120);
    expect(Money.parseInr('-₹1.20').minor, -120);
    expect(Money.parseInr('₹-1.20').minor, -120);
    for (final invalid in [
      'NaN',
      'Infinity',
      '1e4',
      '1.001',
      '1,23',
      '1,234,567',
      '',
      '.50',
    ]) {
      expect(
        () => Money.parseInr(invalid),
        throwsA(isA<AppFailure>()),
        reason: invalid,
      );
    }
    for (final invalid in [1.0, true, '100', null]) {
      expect(() => Money.fromJson(invalid), throwsA(isA<AppFailure>()));
    }
  });
  test('boundary overflow fails before native integer wrapping', () {
    expect(
      () => Money.fromMinor(9223372036854775807) + Money.fromMinor(1),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => Money.fromMinor(-9223372036854775808).negate(),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => Money.parseInr('92233720368547758.08'),
      throwsA(isA<AppFailure>()),
    );
    expect(Money.parseInr('-92233720368547758.08').minor, -9223372036854775808);
    expect(Money.fromMinor(1).multiplyRatio(1, 2).minor, 1);
    expect(Money.fromMinor(-1).multiplyRatio(1, 2).minor, -1);
    expect(
      () =>
          Money.fromMinor(1) +
          Money.fromMinor(1, currency: const Currency('USD', 2, r'$')),
      throwsA(isA<AppFailure>()),
    );
  });
  test('deterministic arithmetic and format/parse round trips', () {
    final random = Random(7431);
    for (var i = 0; i < 1000; i++) {
      final a = random.nextInt(1 << 30) - (1 << 29),
          b = random.nextInt(1 << 30);
      final first = Money.fromMinor(a), second = Money.fromMinor(b);
      expect((first + second).minor, (BigInt.from(a) + BigInt.from(b)).toInt());
      expect(Money.parseInr(first.format()).minor, a);
    }
    expect(Money.fromMinor(100).toString(), isNot(contains('100')));
  });
}
