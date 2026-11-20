import 'money.dart';

/// Reports can exceed one posting's int64 range; never truncate them to int.
String formatInr(BigInt paise, {bool compact = false, bool hindi = false}) {
  final digits = paise.abs().toString().padLeft(3, '0');
  final sign = paise.isNegative ? '-' : '';
  if (compact && paise.abs() >= BigInt.from(10000000)) {
    final crore = paise.abs() >= BigInt.from(1000000000);
    final divisor = BigInt.from(crore ? 1000000000 : 10000000);
    final rounded =
        (paise.abs() * BigInt.from(100) + divisor ~/ BigInt.two) ~/ divisor;
    final whole = rounded ~/ BigInt.from(100);
    final fraction = (rounded % BigInt.from(100))
        .toString()
        .padLeft(2, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    final unit = crore ? (hindi ? 'करोड़' : 'crore') : (hindi ? 'लाख' : 'lakh');
    return '$sign₹$whole${fraction.isEmpty ? '' : '.$fraction'} $unit';
  }
  return '$sign₹${Money.indianGrouping(digits.substring(0, digits.length - 2))}.${digits.substring(digits.length - 2)}';
}

String formatPercentage(BigInt numerator, BigInt denominator) {
  if (denominator <= BigInt.zero) {
    return '—';
  }
  final scaled = numerator * BigInt.from(10000);
  final result = (scaled.abs() + denominator ~/ BigInt.two) ~/ denominator;
  return '${scaled.isNegative ? '-' : ''}${result ~/ BigInt.from(100)}.${(result % BigInt.from(100)).toString().padLeft(2, '0')}%';
}

/// Dimensionless chart geometry only; labels and all financial totals stay exact.
double chartRatio(BigInt numerator, BigInt denominator) {
  if (denominator <= BigInt.zero || numerator <= BigInt.zero) {
    return 0;
  }
  if (numerator >= denominator) {
    return 1;
  }
  return ((numerator * BigInt.from(1000000)) ~/ denominator).toInt() / 1000000;
}
