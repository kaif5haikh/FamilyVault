import '../../../core/errors/app_failure.dart';
import '../../../core/finance/fixed_decimal.dart';
import '../../../core/finance/money.dart';

final class InventoryPosition {
  InventoryPosition({required this.quantity, required this.costPoolMinor}) {
    if (quantity < 0 ||
        costPoolMinor < 0 ||
        (quantity == 0 && costPoolMinor != 0)) {
      throw _invalid;
    }
  }
  static const _invalid = AppFailure(
    FailureCode.validation,
    'Check stock quantity and recorded cost.',
  );
  final int quantity, costPoolMinor;
  InventoryPosition receive({required int units, required Money totalCost}) {
    if (units <= 0 ||
        totalCost.minor < 0 ||
        totalCost.currency != Currency.inr) {
      throw _invalid;
    }
    return InventoryPosition(
      quantity: checkedInt64(BigInt.from(quantity) + BigInt.from(units)),
      costPoolMinor: checkedInt64(
        BigInt.from(costPoolMinor) + BigInt.from(totalCost.minor),
      ),
    );
  }

  InventoryIssue issue(int units) {
    if (units <= 0 || units > quantity) {
      throw const AppFailure(
        FailureCode.validation,
        'There is not enough recorded stock.',
      );
    }
    final cost = units == quantity
        ? costPoolMinor
        : checkedInt64(
            roundRatio(
              BigInt.from(costPoolMinor) * BigInt.from(units),
              BigInt.from(quantity),
            ),
          );
    return InventoryIssue(
      costMinor: cost,
      remaining: InventoryPosition(
        quantity: quantity - units,
        costPoolMinor: costPoolMinor - cost,
      ),
    );
  }

  @override
  String toString() => 'InventoryPosition([redacted])';
}

final class InventoryIssue {
  const InventoryIssue({required this.costMinor, required this.remaining});
  final int costMinor;
  final InventoryPosition remaining;
  @override
  String toString() => 'InventoryIssue([redacted])';
}
