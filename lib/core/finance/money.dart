import '../errors/app_failure.dart';

final class Currency {
  const Currency(this.code, this.scale, this.symbol);
  static const inr = Currency('INR', 2, '₹');
  final String code;
  final int scale;
  final String symbol;

  @override
  bool operator ==(Object other) =>
      other is Currency && other.code == code && other.scale == scale;
  @override
  int get hashCode => Object.hash(code, scale);
}

/// Exact minor-unit arithmetic; all intermediate financial arithmetic uses BigInt.
final class Money implements Comparable<Money> {
  Money._(this.minor, this.currency);
  factory Money.fromMinor(int minor, {Currency currency = Currency.inr}) {
    if (currency.scale < 0 ||
        currency.scale > 6 ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency.code)) {
      throw const AppFailure(FailureCode.validation, 'Invalid currency.');
    }
    return Money._(_checked(BigInt.from(minor)), currency);
  }
  factory Money.fromJson(Object? value, {Currency currency = Currency.inr}) {
    if (value is! int) {
      throw const AppFailure(
        FailureCode.validation,
        'Money must use integer minor units.',
      );
    }
    return Money.fromMinor(value, currency: currency);
  }
  factory Money.parseInr(String input) {
    var value = input.trim();
    if (value.length > 40) throw _invalid;
    value = value.replaceFirst(RegExp(r'^₹\s*'), '');
    value = value.replaceFirstMapped(
      RegExp(r'^([+-])₹\s*'),
      (match) => match.group(1)!,
    );
    final match = RegExp(
      r'^([+-]?)([0-9]+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3})(?:\.([0-9]{1,2}))?$',
    ).firstMatch(value);
    if (match == null) throw _invalid;
    final whole = BigInt.parse(match.group(2)!.replaceAll(',', ''));
    final fraction = BigInt.parse((match.group(3) ?? '').padRight(2, '0'));
    var amount = whole * BigInt.from(100) + fraction;
    if (match.group(1) == '-') amount = -amount;
    return Money.fromMinor(_checked(amount));
  }

  static const _invalid = AppFailure(
    FailureCode.validation,
    'Enter a valid rupee amount with up to two decimal places.',
  );
  static final _minimum = -(BigInt.one << 63);
  static final _maximum = (BigInt.one << 63) - BigInt.one;
  final int minor;
  final Currency currency;

  static int _checked(BigInt value) {
    if (value < _minimum || value > _maximum) {
      throw const AppFailure(
        FailureCode.validation,
        'Amount exceeds the supported limit.',
      );
    }
    return value.toInt();
  }

  void _same(Money other) {
    if (currency != other.currency) {
      throw const AppFailure(
        FailureCode.validation,
        'Different currencies cannot be combined.',
      );
    }
  }

  Money operator +(Money other) {
    _same(other);
    return Money.fromMinor(
      _checked(BigInt.from(minor) + BigInt.from(other.minor)),
      currency: currency,
    );
  }

  Money operator -(Money other) {
    _same(other);
    return Money.fromMinor(
      _checked(BigInt.from(minor) - BigInt.from(other.minor)),
      currency: currency,
    );
  }

  Money negate() =>
      Money.fromMinor(_checked(-BigInt.from(minor)), currency: currency);
  Money multiplyRatio(int numerator, int denominator) {
    if (denominator <= 0) {
      throw const AppFailure(
        FailureCode.validation,
        'A positive denominator is required.',
      );
    }
    final product = BigInt.from(minor) * BigInt.from(numerator);
    final divisor = BigInt.from(denominator);
    final rounded = (product.abs() + divisor ~/ BigInt.two) ~/ divisor;
    return Money.fromMinor(
      _checked(product.isNegative ? -rounded : rounded),
      currency: currency,
    );
  }

  @override
  int compareTo(Money other) {
    _same(other);
    return minor.compareTo(other.minor);
  }

  String format({bool symbol = true, bool grouping = true}) {
    final absolute = BigInt.from(minor)
        .abs()
        .toString()
        .padLeft(currency.scale + 1, '0');
    final whole = currency.scale == 0
        ? absolute
        : absolute.substring(0, absolute.length - currency.scale);
    final fraction = currency.scale == 0
        ? ''
        : '.${absolute.substring(absolute.length - currency.scale)}';
    final digits = grouping && currency == Currency.inr
        ? indianGrouping(whole)
        : whole;
    return '${minor < 0 ? '-' : ''}${symbol ? currency.symbol : ''}$digits$fraction';
  }

  String compact() {
    if (currency != Currency.inr) return format();
    final value = BigInt.from(minor).abs();
    final crore = BigInt.from(1000000000), lakh = BigInt.from(10000000);
    if (value < lakh) return format();
    final divisor = value >= crore ? crore : lakh;
    final hundredths =
        (value * BigInt.from(100) + divisor ~/ BigInt.two) ~/ divisor;
    final whole = hundredths ~/ BigInt.from(100);
    final fraction = (hundredths % BigInt.from(100))
        .toString()
        .padLeft(2, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '${minor < 0 ? '-' : ''}₹$whole${fraction.isEmpty ? '' : '.$fraction'} ${value >= crore ? 'crore' : 'lakh'}';
  }

  static String indianGrouping(String digits) {
    if (digits.length <= 3) return digits;
    final tail = digits.substring(digits.length - 3);
    var head = digits.substring(0, digits.length - 3);
    final groups = <String>[tail];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) groups.insert(0, head);
    return groups.join(',');
  }

  @override
  bool operator ==(Object other) =>
      other is Money && minor == other.minor && currency == other.currency;
  @override
  int get hashCode => Object.hash(minor, currency);
  @override
  String toString() => 'Money([redacted], ${currency.code})';
}
