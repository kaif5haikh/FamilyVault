import 'dart:math';

import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/fixed_decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'quantities, ownership percentages and signed boundaries parse exactly',
    () {
      expect(FixedDecimal.parse('12.345', scale: 3), 12345);
      expect(FixedDecimal.parse('25.50', scale: 2), 2550);
      expect(
        FixedDecimal.parse('-9223372036854775.808', scale: 3, signed: true),
        -9223372036854775808,
      );
      expect(
        FixedDecimal.format(-9223372036854775808, scale: 3),
        '-9223372036854775.808',
      );
      for (final text in ['1.0001', '-1', '1,000', 'NaN', '1e3', '1.2.3', '']) {
        expect(
          () => FixedDecimal.parse(text, scale: 3),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(
        () => FixedDecimal.parse('9223372036854775.808', scale: 3),
        throwsA(isA<AppFailure>()),
      );
      final random = Random(20261114);
      for (var i = 0; i < 1000; i++) {
        final value = random.nextInt(1000000000) - 500000000,
            scale = random.nextInt(10);
        expect(
          FixedDecimal.parse(
            FixedDecimal.format(value, scale: scale),
            scale: scale,
            signed: true,
          ),
          value,
        );
      }
      expect(roundRatio(BigInt.from(-5), BigInt.two), BigInt.from(-3));
      expect(roundRatio(BigInt.from(5), BigInt.two), BigInt.from(3));
    },
  );
}
