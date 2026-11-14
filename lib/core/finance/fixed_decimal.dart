import '../errors/app_failure.dart';

/// Quantities, percentages and rates use explicit integer scales, never double.
abstract final class FixedDecimal {
  static int parse(String input, {required int scale, bool signed = false}) {
    if (scale < 0 || scale > 9 || input.length > 40) {
      throw _invalid;
    }
    final text = input.trim();
    final pattern = scale == 0
        ? r'([0-9]+)'
        : '([0-9]+)(?:\\.([0-9]{1,$scale}))?';
    final match = RegExp('^${signed ? r'([+-]?)' : '()'}$pattern\$')
        .firstMatch(text);
    if (match == null) {
      throw _invalid;
    }
    var value = BigInt.parse(match.group(2)!) * BigInt.from(10).pow(scale);
    if (scale > 0) {
      value += BigInt.parse((match.group(3) ?? '').padRight(scale, '0'));
    }
    if (match.group(1) == '-') {
      value = -value;
    }
    return checkedInt64(value);
  }

  static String format(int value, {required int scale, bool trim = true}) {
    if (scale < 0 || scale > 9) {
      throw _invalid;
    }
    final digits = BigInt.from(value).abs().toString().padLeft(scale + 1, '0');
    final sign = value < 0 ? '-' : '';
    if (scale == 0) {
      return '$sign$digits';
    }
    final whole = digits.substring(0, digits.length - scale);
    var fraction = digits.substring(digits.length - scale);
    if (trim) {
      fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    }
    return '$sign$whole${fraction.isEmpty ? '' : '.$fraction'}';
  }

  static const _invalid = AppFailure(
    FailureCode.validation,
    'Enter a valid number with the supported decimal precision.',
  );
}

int checkedInt64(BigInt value) {
  if (value < -(BigInt.one << 63) || value > (BigInt.one << 63) - BigInt.one) {
    throw const AppFailure(
      FailureCode.validation,
      'This calculation exceeds the supported limit.',
    );
  }
  return value.toInt();
}

/// Round rational values to the nearest integer, with exact halves away from zero.
BigInt roundRatio(BigInt numerator, BigInt denominator) {
  if (denominator <= BigInt.zero) {
    throw const AppFailure(
      FailureCode.validation,
      'Use a positive calculation denominator.',
    );
  }
  final rounded = (numerator.abs() + denominator ~/ BigInt.two) ~/ denominator;
  return numerator.isNegative ? -rounded : rounded;
}
