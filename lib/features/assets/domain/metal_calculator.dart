import '../../../core/errors/app_failure.dart';
import '../../../core/finance/fixed_decimal.dart';
import '../../../core/finance/money.dart';

abstract final class MetalCalculator {
  static const _invalid = AppFailure(
    FailureCode.validation,
    'Check metal weight, purity and the quoted rate.',
  );

  /// Nominal karat ratio; this is never represented as a physical assay.
  static int nominalPurity(int karat) {
    if (![18, 22, 24].contains(karat)) {
      throw _invalid;
    }
    return roundRatio(BigInt.from(karat * 1000000), BigInt.from(24)).toInt();
  }

  static Money estimate({
    required int weightMg,
    required int holdingPurityPpm,
    required Money ratePerGram,
    required int quotePurityPpm,
  }) {
    if (weightMg <= 0 ||
        holdingPurityPpm < 1 ||
        holdingPurityPpm > 1000000 ||
        quotePurityPpm < 1 ||
        quotePurityPpm > 1000000 ||
        ratePerGram.currency != Currency.inr ||
        ratePerGram.minor < 0) {
      throw _invalid;
    }
    return Money.fromMinor(
      checkedInt64(
        roundRatio(
          BigInt.from(weightMg) *
              BigInt.from(ratePerGram.minor) *
              BigInt.from(holdingPurityPpm),
          BigInt.from(1000) * BigInt.from(quotePurityPpm),
        ),
      ),
    );
  }

  static Money purchaseCost({
    required int weightMg,
    required Money rateAtRecordedPurity,
    required Money makingCharges,
  }) {
    if (weightMg <= 0 ||
        rateAtRecordedPurity.currency != Currency.inr ||
        makingCharges.currency != Currency.inr ||
        rateAtRecordedPurity.minor < 0 ||
        makingCharges.minor < 0) {
      throw _invalid;
    }
    return Money.fromMinor(
      checkedInt64(
        roundRatio(
              BigInt.from(weightMg) * BigInt.from(rateAtRecordedPurity.minor),
              BigInt.from(1000),
            ) +
            BigInt.from(makingCharges.minor),
      ),
    );
  }
}
