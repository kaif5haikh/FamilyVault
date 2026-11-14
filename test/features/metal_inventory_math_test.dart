import 'dart:math';

import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/features/assets/domain/metal_calculator.dart';
import 'package:familyvault/features/business/domain/inventory_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('metal estimates retain milligrams and distinguish nominal purity from assays', () {
    expect(MetalCalculator.nominalPurity(18), 750000);
    expect(MetalCalculator.nominalPurity(22), 916667);
    expect(MetalCalculator.nominalPurity(24), 1000000);
    expect(
      MetalCalculator.estimate(
        weightMg: 10125,
        holdingPurityPpm: 750000,
        ratePerGram: Money.parseInr('5000'),
        quotePurityPpm: 1000000,
      ),
      Money.parseInr('37968.75'),
    );
    expect(
      MetalCalculator.purchaseCost(
        weightMg: 12345,
        rateAtRecordedPurity: Money.parseInr('6000'),
        makingCharges: Money.parseInr('500'),
      ),
      Money.parseInr('74570'),
    );
    expect(
      MetalCalculator.estimate(
        weightMg: 1,
        holdingPurityPpm: 1000000,
        ratePerGram: Money.parseInr('5'),
        quotePurityPpm: 1000000,
      ).minor,
      1,
    );
    expect(
      () => MetalCalculator.estimate(
        weightMg: 9223372036854775807,
        holdingPurityPpm: 1000000,
        ratePerGram: Money.fromMinor(9223372036854775807),
        quotePurityPpm: 1000000,
      ),
      throwsA(isA<AppFailure>()),
    );
  });
  test('weighted stock costing conserves every paise and gives the final unit its remainder', () {
    var position = InventoryPosition(
      quantity: 0,
      costPoolMinor: 0,
    ).receive(units: 3, totalCost: Money.fromMinor(100));
    final costs = <int>[];
    for (var i = 0; i < 3; i++) {
      final issue = position.issue(1);
      costs.add(issue.costMinor);
      position = issue.remaining;
    }
    expect(costs, [33, 34, 33]);
    expect(position.quantity, 0);
    expect(position.costPoolMinor, 0);
    expect(() => position.issue(1), throwsA(isA<AppFailure>()));
    expect(
      () => InventoryPosition(
        quantity: 1,
        costPoolMinor: 9223372036854775807,
      ).receive(units: 1, totalCost: Money.fromMinor(1)),
      throwsA(isA<AppFailure>()),
    );
  });
  test('a thousand mixed stock operations conserve cost and quantity without floating point', () {
    final random = Random(20261114);
    var position = InventoryPosition(quantity: 0, costPoolMinor: 0);
    var incoming = BigInt.zero, issued = BigInt.zero;
    for (var i = 0; i < 1000; i++) {
      if (position.quantity == 0 || random.nextBool()) {
        final units = random.nextInt(50) + 1, cost = random.nextInt(100000);
        position = position.receive(
          units: units,
          totalCost: Money.fromMinor(cost),
        );
        incoming += BigInt.from(cost);
      } else {
        final issue = position.issue(random.nextInt(position.quantity) + 1);
        position = issue.remaining;
        issued += BigInt.from(issue.costMinor);
      }
      expect(BigInt.from(position.costPoolMinor) + issued, incoming);
    }
    if (position.quantity > 0) {
      final finalIssue = position.issue(position.quantity);
      issued += BigInt.from(finalIssue.costMinor);
      position = finalIssue.remaining;
    }
    expect(issued, incoming);
    expect(position.quantity, 0);
    expect(position.costPoolMinor, 0);
  });
}
