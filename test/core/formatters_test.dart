import 'package:familyvault/core/finance/formatters.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report formatting remains exact beyond a signed 64-bit posting', () {
    final value = BigInt.parse('18446744073709551614');
    expect(formatInr(value), '₹1,84,46,74,40,73,70,95,516.14');
    for (final minor in [
      0,
      1,
      -1,
      10000000,
      -1500000000,
      9223372036854775807,
    ]) {
      expect(formatInr(BigInt.from(minor)), Money.fromMinor(minor).format());
      expect(
        formatInr(BigInt.from(minor), compact: true),
        Money.fromMinor(minor).compact(),
      );
    }
    expect(formatPercentage(BigInt.one, BigInt.from(3)), '33.33%');
    expect(formatPercentage(-BigInt.one, BigInt.from(3)), '-33.33%');
    expect(formatPercentage(BigInt.one, BigInt.zero), '—');
    final huge = BigInt.one << 150;
    expect(chartRatio(huge, huge * BigInt.two), .5);
    expect(chartRatio(huge * BigInt.two, huge), 1);
    expect(chartRatio(-huge, huge), 0);
  });
}
