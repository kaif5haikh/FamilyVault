import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/mutation_writer.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/finance/fixed_decimal.dart';
import '../../../core/finance/money.dart';
import '../../../core/sync/canonical_json.dart';
import '../../../core/sync/database_record.dart';
import '../../finance/data/ledger_repository.dart';
import '../domain/asset_draft.dart';
import '../domain/metal_calculator.dart';

export '../domain/asset_draft.dart';

final class AssetSnapshot {
  const AssetSnapshot({
    required this.assets,
    required this.properties,
    required this.metals,
    required this.investments,
    required this.owners,
    required this.valuations,
  });
  final List<WealthAsset> assets;
  final List<PropertyDetail> properties;
  final List<MetalDetail> metals;
  final List<InvestmentDetail> investments;
  final List<AssetOwnership> owners;
  final List<AssetValuation> valuations;
  AssetValuation? latest(String id, {String? through}) => valuations
      .where(
        (v) =>
            v.assetId == id &&
            (through == null || v.valuedOn.compareTo(through) <= 0),
      )
      .firstOrNull;
}

/// Dated asset observations and their exact family portion share a ledger.
final class AssetRepository {
  AssetRepository(this.ledger);
  final LedgerRepository ledger;
  AppDatabase get db => ledger.db;
  String get family => ledger.identity.familyId;
  String get actor => ledger.identity.memberId;
  int get now => ledger.mutations.now;
  static const _invalid = AppFailure(
    FailureCode.validation,
    'Check the holding details, ownership, value and date.',
  );
  static const _stale = AppFailure(
    FailureCode.conflict,
    'This holding changed. Refresh before saving.',
  );

  static int familyValue(int total, int bps) {
    if (total < 0 || bps < 1 || bps > 10000) {
      throw _invalid;
    }
    return checkedInt64(
      roundRatio(BigInt.from(total) * BigInt.from(bps), BigInt.from(10000)),
    );
  }

  static String _text(String value, int max, {bool empty = false}) {
    value = value.trim();
    if ((!empty && value.isEmpty) ||
        value.length > max ||
        value.contains('\u0000')) {
      throw _invalid;
    }
    return value;
  }

  Future<WealthAsset> asset(String id) async {
    final a =
        await (db.select(db.wealthAssets)
              ..where((t) => t.familyId.equals(family) & t.id.equals(id)))
            .getSingleOrNull();
    if (a == null) {
      throw const AppFailure(
        FailureCode.validation,
        'This holding is unavailable in this family.',
      );
    }
    return a;
  }

  Future<WealthAsset> _current(
    String id,
    int revision, {
    bool closed = false,
  }) async {
    final a = await asset(id);
    if (a.revision != revision || (!closed && a.deletedAtUs != null)) {
      throw _stale;
    }
    return a;
  }

  Future<String> create(AssetDraft draft, {String? operationId}) {
    final op = operationId ?? ledger.operationId();
    // The root ID follows the stable command, independent of names or values.
    final root = ledger.aggregateId(op, 'asset');
    return ledger.runAggregate(
      operationId: op,
      entityType: 'asset',
      entityId: root,
      baseRevision: 0,
      action: 'create',
      command: draft.toJson(),
      change: (tx) async {
        _validate(draft);
        final account = await tx.createAccount(
          label: 'holding',
          name: draft.name,
          kind: AccountKind.asset,
          subtype: 'managed_${draft.kind.name}',
        );
        await db
            .into(db.wealthAssets)
            .insert(
              WealthAssetsCompanion.insert(
                id: root,
                familyId: family,
                createdBy: actor,
                updatedBy: actor,
                createdAtUs: now,
                updatedAtUs: now,
                name: draft.name.trim(),
                kind: draft.kind.name,
                accountId: account.id,
                familyOwnershipBps: draft.familyOwnershipBps,
                purchaseOwnershipBps: draft.familyOwnershipBps,
                valuationState: Value(
                  draft.currentTotalMinor != null ||
                          draft.purchaseTotalMinor != null
                      ? 'recorded'
                      : 'unrecorded',
                ),
                purchaseTotalMinor: Value(draft.purchaseTotalMinor),
                purchasedOn: Value(draft.purchasedOn),
                notes: Value(draft.notes.trim()),
              ),
            );
        await _details(root, draft, tx);
        var index = 0;
        if (draft.purchaseTotalMinor != null) {
          String? contra;
          if (draft.fundingAccountId != null) {
            contra = (await tx.liquidAccount(draft.fundingAccountId!)).id;
          }
          await _quote(
            tx,
            await asset(root),
            total: draft.purchaseTotalMinor!,
            bps: draft.familyOwnershipBps,
            date: draft.purchasedOn!,
            source: 'purchase',
            notes: 'Recorded acquisition cost',
            index: index++,
            contra: contra ?? ledger.chartId('opening'),
            purpose: contra == null ? 'opening' : 'acquisition',
          );
        }
        if (draft.currentTotalMinor != null) {
          await _quote(
            tx,
            await asset(root),
            total: draft.currentTotalMinor!,
            bps: draft.familyOwnershipBps,
            date: draft.valuedOn!,
            source: 'manual',
            notes: 'Recorded valuation',
            index: index,
          );
        }
        return databaseRecord(await asset(root));
      },
    );
  }

  void _validate(AssetDraft d) {
    _text(d.name, 120);
    _text(d.notes, 4000, empty: true);
    familyValue(0, d.familyOwnershipBps);
    if (d.purchaseTotalMinor != null &&
        (d.purchaseTotalMinor! < 0 || d.purchasedOn == null)) {
      throw _invalid;
    }
    if (d.currentTotalMinor != null &&
        (d.currentTotalMinor! < 0 || d.valuedOn == null)) {
      throw _invalid;
    }
    if (d.fundingAccountId != null && d.purchaseTotalMinor == null) {
      throw _invalid;
    }
    for (final date in [d.purchasedOn, d.valuedOn].nonNulls) {
      LedgerRepository.validateDate(date);
    }
    if (d.purchasedOn != null &&
        d.valuedOn != null &&
        d.valuedOn!.compareTo(d.purchasedOn!) < 0) {
      throw _invalid;
    }
    if ((d.kind == AssetKind.property || d.kind == AssetKind.land) !=
            (d.property != null) ||
        [
              AssetKind.gold,
              AssetKind.silver,
              AssetKind.jewellery,
            ].contains(d.kind) !=
            (d.metal != null) ||
        (d.kind == AssetKind.investment) != (d.investment != null)) {
      throw _invalid;
    }
    if (d.property case final p?) {
      _text(p.city, 120);
      _text(p.location, 500, empty: true);
      if (p.recordReference != null) {
        _text(p.recordReference!, 200, empty: true);
      }
      if ((p.areaMilli == null) != (p.areaUnit == null) ||
          (p.areaMilli != null && p.areaMilli! <= 0)) {
        throw _invalid;
      }
      if (p.areaUnit != null) {
        _text(p.areaUnit!, 24);
      }
    }
    if (d.metal case final m?) {
      if (!['gold', 'silver'].contains(m.metal) ||
          m.weightMg <= 0 ||
          (d.kind != AssetKind.jewellery && d.kind.name != m.metal) ||
          !['unrecorded', 'nominal', 'assayed'].contains(m.purityKind) ||
          (m.purityKind == 'unrecorded') != (m.purityPpm == null) ||
          (m.purityPpm != null &&
              (m.purityPpm! < 1 || m.purityPpm! > 1000000)) ||
          (m.karat != null && ![18, 22, 24].contains(m.karat)) ||
          (m.metal == 'silver' && m.karat != null) ||
          (m.purityKind == 'nominal' &&
              (m.karat == null ||
                  m.purityPpm != MetalCalculator.nominalPurity(m.karat!))) ||
          (m.purchaseRateMinorPerGram != null &&
              m.purchaseRateMinorPerGram! < 0) ||
          (m.makingChargesMinor != null && m.makingChargesMinor! < 0)) {
        throw _invalid;
      }
    }
    if (d.investment case final i?) {
      _text(i.instrument, 120);
      if (i.symbol != null) {
        _text(i.symbol!, 80, empty: true);
      }
      if ((i.quantityScaled == null) != (i.quantityScale == null) ||
          (i.quantityScaled != null && i.quantityScaled! <= 0) ||
          (i.quantityScale != null &&
              (i.quantityScale! < 0 || i.quantityScale! > 9))) {
        throw _invalid;
      }
    }
    _validateOwners(d.owners, d.familyOwnershipBps);
  }

  void _validateOwners(List<OwnerDraft> owners, int bps) {
    var total = BigInt.zero;
    final members = <String>{};
    if (owners.length > 100) {
      throw _invalid;
    }
    for (final o in owners) {
      _text(o.label, 120);
      if (o.shareBps < 1 ||
          o.shareBps > 10000 ||
          (o.memberId != null && !members.add(o.memberId!))) {
        throw _invalid;
      }
      total += BigInt.from(o.shareBps);
    }
    if (total > BigInt.from(bps)) {
      throw _invalid;
    }
  }

  Future<void> _details(String id, AssetDraft d, LedgerAggregate tx) async {
    if (d.property case final p?) {
      await db
          .into(db.propertyDetails)
          .insert(
            PropertyDetailsCompanion.insert(
              assetId: id,
              familyId: family,
              city: p.city.trim(),
              location: p.location.trim(),
              recordReference: Value(p.recordReference?.trim()),
              areaMilli: Value(p.areaMilli),
              areaUnit: Value(p.areaUnit?.trim()),
            ),
          );
      tx.include(
        'property',
        databaseRecord(
          await (db.select(
            db.propertyDetails,
          )..where((t) => t.assetId.equals(id))).getSingle(),
        ),
      );
    }
    if (d.metal case final m?) {
      await db
          .into(db.metalDetails)
          .insert(
            MetalDetailsCompanion.insert(
              assetId: id,
              familyId: family,
              weightMg: m.weightMg,
              metal: m.metal,
              purityPpm: Value(m.purityPpm),
              purityKind: Value(m.purityKind),
              karat: Value(m.karat),
              purchaseRateMinorPerGram: Value(m.purchaseRateMinorPerGram),
              makingChargesMinor: Value(m.makingChargesMinor),
            ),
          );
      tx.include(
        'metal',
        databaseRecord(
          await (db.select(
            db.metalDetails,
          )..where((t) => t.assetId.equals(id))).getSingle(),
        ),
      );
    }
    if (d.investment case final i?) {
      await db
          .into(db.investmentDetails)
          .insert(
            InvestmentDetailsCompanion.insert(
              assetId: id,
              familyId: family,
              instrument: i.instrument.trim(),
              symbol: Value(i.symbol?.trim()),
              quantityScaled: Value(i.quantityScaled),
              quantityScale: Value(i.quantityScale),
            ),
          );
      tx.include(
        'investment',
        databaseRecord(
          await (db.select(
            db.investmentDetails,
          )..where((t) => t.assetId.equals(id))).getSingle(),
        ),
      );
    }
    await _owners(tx, id, d.owners);
  }

  Future<void> _owners(
    LedgerAggregate tx,
    String id,
    List<OwnerDraft> owners,
  ) async {
    final old =
        await (db.select(db.assetOwnerships)..where(
              (t) =>
                  t.familyId.equals(family) &
                  t.assetId.equals(id) &
                  t.deletedAtUs.isNull(),
            ))
            .get();
    final retained = <Map<String, Object?>>[];
    for (final o in old) {
      await (db.update(
        db.assetOwnerships,
      )..where((t) => t.id.equals(o.id))).write(
        AssetOwnershipsCompanion(
          revision: Value(o.revision + 1),
          updatedBy: Value(actor),
          updatedAtUs: Value(now),
          deletedAtUs: Value(now),
        ),
      );
      retained.add(
        databaseRecord(
          await (db.select(
            db.assetOwnerships,
          )..where((t) => t.id.equals(o.id))).getSingle(),
        ),
      );
    }
    for (var index = 0; index < owners.length; index++) {
      final o = owners[index];
      if (o.memberId != null) {
        final member =
            await (db.select(db.familyMembers)..where(
                  (t) => t.familyId.equals(family) & t.id.equals(o.memberId!),
                ))
                .getSingleOrNull();
        if (member == null) {
          throw _invalid;
        }
      }
      final key = tx.id('owner/$index');
      await db
          .into(db.assetOwnerships)
          .insert(
            AssetOwnershipsCompanion.insert(
              id: key,
              familyId: family,
              createdBy: actor,
              updatedBy: actor,
              createdAtUs: now,
              updatedAtUs: now,
              assetId: id,
              memberId: Value(o.memberId),
              ownerLabel: o.label.trim(),
              shareBps: o.shareBps,
            ),
          );
      retained.add(
        databaseRecord(
          await (db.select(
            db.assetOwnerships,
          )..where((t) => t.id.equals(key))).getSingle(),
        ),
      );
    }
    tx.include('ownerships', retained);
  }

  // A quote values the holding before its disposal, including on the sale date.
  Future<int> _book(
    String account,
    String date, {
    bool beforeClosure = false,
  }) async => checkedInt64(
    await ledger.accountBalance(
      account,
      through: date,
      beforeAssetClosure: beforeClosure,
    ),
  );

  Future<String?> _delta(
    LedgerAggregate tx,
    WealthAsset a,
    int amount,
    String date,
    String purpose, {
    String? contra,
  }) async {
    if (amount == 0) {
      return null;
    }
    final equity =
        contra ??
        (await tx.systemAccount(
          'asset_revaluation',
          'Asset valuation reserve',
          AccountKind.equity,
        )).id;
    return tx.post(
      kind: purpose == 'opening' ? EntryKind.opening : EntryKind.adjustment,
      occurredOn: date,
      description: purpose == 'acquisition'
          ? 'Asset acquisition'
          : 'Asset valuation',
      postings: [
        PostingInput(a.accountId, amount),
        PostingInput(equity, Money.fromMinor(amount).negate().minor),
      ],
      purpose: purpose,
    );
  }

  Future<void> _quote(
    LedgerAggregate tx,
    WealthAsset a, {
    required int total,
    required int bps,
    required String date,
    required String source,
    required String notes,
    required int index,
    String? contra,
    String purpose = 'valuation',
    Map<String, Object?> basis = const {},
  }) async {
    final before = await _book(
          a.accountId,
          date,
          beforeClosure: a.closedOn != null,
        ),
        value = familyValue(total, bps);
    final delta = checkedInt64(BigInt.from(value) - BigInt.from(before));
    final journal = await _delta(tx, a, delta, date, purpose, contra: contra);
    final key = tx.id('valuation/$index');
    await db
        .into(db.assetValuations)
        .insert(
          AssetValuationsCompanion.insert(
            id: key,
            familyId: family,
            createdBy: actor,
            deviceId: ledger.identity.deviceId,
            createdAtUs: now,
            assetId: a.id,
            assetRevision: a.revision,
            eventIndex: Value(index),
            journalId: Value(journal),
            valuedOn: date,
            totalValueMinor: total,
            familyValueMinor: value,
            previousFamilyValueMinor: before,
            ownershipBps: bps,
            source: source,
            notes: notes,
            basisJson: Value(canonicalJson(basis)),
          ),
        );
    final events =
        await (db.select(db.assetValuations)..where(
              (t) =>
                  t.assetId.equals(a.id) &
                  t.familyId.equals(family) &
                  t.assetRevision.equals(a.revision),
            ))
            .get();
    tx.include('valuations', events.map(databaseRecord).toList());
  }

  Future<String> value(
    String id,
    int expectedRevision, {
    required Money total,
    required String valuedOn,
    required String notes,
    String? operationId,
    Money? metalRate,
    int? quotePurityPpm,
  }) {
    final op = operationId ?? ledger.operationId();
    return ledger.runAggregate(
      operationId: op,
      entityType: 'asset',
      entityId: id,
      baseRevision: expectedRevision,
      command: {
        'value_minor': total.minor,
        'currency': total.currency.code,
        'valued_on': valuedOn,
        'notes': notes.trim(),
        'metal_rate_minor': metalRate?.minor,
        'metal_rate_currency': metalRate?.currency.code,
        'quote_purity_ppm': quotePurityPpm,
      },
      change: (tx) async {
        final a = await _current(id, expectedRevision, closed: true);
        LedgerRepository.validateDate(valuedOn);
        _text(notes, 1000);
        if (total.currency != Currency.inr ||
            total.minor < 0 ||
            (a.purchasedOn != null && valuedOn.compareTo(a.purchasedOn!) < 0) ||
            (a.closedOn != null && valuedOn.compareTo(a.closedOn!) > 0)) {
          throw _invalid;
        }
        var source = 'manual';
        final basis = <String, Object?>{};
        if (metalRate != null || quotePurityPpm != null) {
          final metal =
              await (db.select(db.metalDetails)..where(
                    (t) => t.familyId.equals(family) & t.assetId.equals(id),
                  ))
                  .getSingleOrNull();
          if (metal == null ||
              metal.purityPpm == null ||
              metalRate == null ||
              quotePurityPpm == null) {
            throw _invalid;
          }
          final estimate = MetalCalculator.estimate(
            weightMg: metal.weightMg,
            holdingPurityPpm: metal.purityPpm!,
            ratePerGram: metalRate,
            quotePurityPpm: quotePurityPpm,
          );
          if (estimate != total) {
            throw _invalid;
          }
          source = 'metal_rate';
          basis.addAll({
            'weight_mg': metal.weightMg,
            'holding_purity_ppm': metal.purityPpm,
            'rate_minor_per_gram': metalRate.minor,
            'quote_purity_ppm': quotePurityPpm,
          });
        }
        final historicalShare =
            (await _lastQuote(id, through: valuedOn))?.ownershipBps ??
            a.purchaseOwnershipBps;
        final following =
            await (db.select(db.assetValuations)
                  ..where(
                    (t) =>
                        t.familyId.equals(family) &
                        t.assetId.equals(id) &
                        t.valuedOn.isBiggerThanValue(valuedOn),
                  )
                  ..orderBy([
                    (t) => OrderingTerm.asc(t.valuedOn),
                    (t) => OrderingTerm.desc(t.assetRevision),
                    (t) => OrderingTerm.desc(t.eventIndex),
                  ])
                  ..limit(1))
                .getSingleOrNull();
        tx.before = databaseRecord(a);
        await (db.update(db.wealthAssets)..where((t) => t.id.equals(id))).write(
          WealthAssetsCompanion(
            revision: Value(a.revision + 1),
            updatedBy: Value(actor),
            updatedAtUs: Value(now),
            valuationState: Value(a.closedOn == null ? 'recorded' : 'closed'),
          ),
        );
        final updated = await asset(id);
        await _quote(
          tx,
          updated,
          total: total.minor,
          bps: historicalShare,
          date: valuedOn,
          source: source,
          notes: notes.trim(),
          index: 0,
          basis: basis,
        );
        if (following != null) {
          await _quote(
            tx,
            updated,
            total: following.totalValueMinor,
            bps: following.ownershipBps,
            date: following.valuedOn,
            source: 'carry_forward',
            notes: 'Retain the later recorded valuation',
            index: 1,
            purpose: 'valuation_bridge',
            basis: {'preserves_valuation_id': following.id},
          );
        }
        if (a.closedOn != null) {
          final book = await _book(a.accountId, a.closedOn!);
          await _delta(
            tx,
            updated,
            Money.fromMinor(book).negate().minor,
            a.closedOn!,
            'disposal_bridge',
          );
        }
        return databaseRecord(updated);
      },
    );
  }

  Future<AssetValuation?> _lastQuote(String id, {String? through}) =>
      (db.select(db.assetValuations)
            ..where(
              (t) =>
                  t.familyId.equals(family) &
                  t.assetId.equals(id) &
                  (through == null
                      ? const Constant(true)
                      : t.valuedOn.isSmallerOrEqualValue(through)),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.valuedOn),
              (t) => OrderingTerm.desc(t.assetRevision),
              (t) => OrderingTerm.desc(t.eventIndex),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<String> changeOwnership(
    String id,
    int expectedRevision, {
    required int shareBps,
    required Money wholeValue,
    required String effectiveOn,
    required String reason,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'asset',
    entityId: id,
    baseRevision: expectedRevision,
    command: {
      'share_bps': shareBps,
      'value_minor': wholeValue.minor,
      'currency': wholeValue.currency.code,
      'effective_on': effectiveOn,
      'reason': reason.trim(),
    },
    change: (tx) async {
      final a = await _current(id, expectedRevision),
          last = await _lastQuote(id);
      LedgerRepository.validateDate(effectiveOn);
      _text(reason, 1000);
      final priorDate = last?.valuedOn ?? a.purchasedOn;
      if (wholeValue.currency != Currency.inr ||
          wholeValue.minor < 0 ||
          shareBps == a.familyOwnershipBps ||
          (priorDate != null && effectiveOn.compareTo(priorDate) < 0)) {
        throw const AppFailure(
          FailureCode.validation,
          'Choose a different share and a date on or after the last recorded valuation or purchase.',
        );
      }
      familyValue(wholeValue.minor, shareBps);
      final owners =
          await (db.select(db.assetOwnerships)..where(
                (t) =>
                    t.familyId.equals(family) &
                    t.assetId.equals(id) &
                    t.deletedAtUs.isNull(),
              ))
              .get();
      if (owners.fold(0, (sum, row) => sum + row.shareBps) > shareBps) {
        throw const AppFailure(
          FailureCode.validation,
          'Edit individual owner allocations before reducing the family share.',
        );
      }
      tx.before = databaseRecord(a);
      await (db.update(db.wealthAssets)..where((t) => t.id.equals(id))).write(
        WealthAssetsCompanion(
          familyOwnershipBps: Value(shareBps),
          valuationState: const Value('recorded'),
          revision: Value(a.revision + 1),
          updatedBy: Value(actor),
          updatedAtUs: Value(now),
        ),
      );
      final updated = await asset(id);
      await _quote(
        tx,
        updated,
        total: wholeValue.minor,
        bps: shareBps,
        date: effectiveOn,
        source: 'manual',
        notes: reason.trim(),
        index: 0,
        basis: {'previous_ownership_bps': a.familyOwnershipBps},
      );
      return databaseRecord(updated);
    },
  );

  Future<String> edit(
    String id,
    int expectedRevision, {
    required String name,
    required String notes,
    required List<OwnerDraft> owners,
    PropertyDraft? property,
    MetalDraft? metal,
    InvestmentDraft? investment,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'asset',
    entityId: id,
    baseRevision: expectedRevision,
    command: {
      'name': name.trim(),
      'notes': notes.trim(),
      'owners': owners.map((o) => o.toJson()).toList(),
      'property': property?.toJson(),
      'metal': metal?.toJson(),
      'investment': investment?.toJson(),
    },
    change: (tx) async {
      final a = await _current(id, expectedRevision);
      final draft = AssetDraft(
        name: name,
        kind: AssetKind.values.byName(a.kind),
        familyOwnershipBps: a.familyOwnershipBps,
        owners: owners,
        notes: notes,
        property: property,
        metal: metal,
        investment: investment,
      );
      _validate(draft);
      tx.before = databaseRecord(a);
      await (db.update(db.wealthAssets)..where((t) => t.id.equals(id))).write(
        WealthAssetsCompanion(
          name: Value(name.trim()),
          notes: Value(notes.trim()),
          revision: Value(a.revision + 1),
          updatedBy: Value(actor),
          updatedAtUs: Value(now),
        ),
      );
      // Child fields are part of this root revision; old values remain in audit.
      final old = await snapshot();
      tx.include('previous_details', {
        'property': old.properties
            .where((p) => p.assetId == id)
            .map(databaseRecord)
            .toList(),
        'metal': old.metals
            .where((m) => m.assetId == id)
            .map(databaseRecord)
            .toList(),
        'investment': old.investments
            .where((i) => i.assetId == id)
            .map(databaseRecord)
            .toList(),
      });
      if (property != null) {
        await (db.update(
          db.propertyDetails,
        )..where((t) => t.assetId.equals(id))).write(
          PropertyDetailsCompanion(
            city: Value(property.city.trim()),
            location: Value(property.location.trim()),
            recordReference: Value(property.recordReference?.trim()),
            areaMilli: Value(property.areaMilli),
            areaUnit: Value(property.areaUnit?.trim()),
          ),
        );
        tx.include(
          'property',
          databaseRecord(
            await (db.select(
              db.propertyDetails,
            )..where((t) => t.assetId.equals(id))).getSingle(),
          ),
        );
      }
      if (metal != null) {
        await (db.update(
          db.metalDetails,
        )..where((t) => t.assetId.equals(id))).write(
          MetalDetailsCompanion(
            metal: Value(metal.metal),
            weightMg: Value(metal.weightMg),
            purityKind: Value(metal.purityKind),
            purityPpm: Value(metal.purityPpm),
            karat: Value(metal.karat),
            purchaseRateMinorPerGram: Value(metal.purchaseRateMinorPerGram),
            makingChargesMinor: Value(metal.makingChargesMinor),
          ),
        );
        tx.include(
          'metal',
          databaseRecord(
            await (db.select(
              db.metalDetails,
            )..where((t) => t.assetId.equals(id))).getSingle(),
          ),
        );
      }
      if (investment != null) {
        await (db.update(
          db.investmentDetails,
        )..where((t) => t.assetId.equals(id))).write(
          InvestmentDetailsCompanion(
            instrument: Value(investment.instrument.trim()),
            symbol: Value(investment.symbol?.trim()),
            quantityScaled: Value(investment.quantityScaled),
            quantityScale: Value(investment.quantityScale),
          ),
        );
        tx.include(
          'investment',
          databaseRecord(
            await (db.select(
              db.investmentDetails,
            )..where((t) => t.assetId.equals(id))).getSingle(),
          ),
        );
      }
      await _owners(tx, id, owners);
      await tx.renameAccount(a.accountId, name.trim());
      return databaseRecord(await asset(id));
    },
  );

  Future<String> close(
    String id,
    int expectedRevision, {
    required String closedOn,
    required Money proceeds,
    String? accountId,
    required String reason,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'asset',
    entityId: id,
    baseRevision: expectedRevision,
    action: 'delete',
    command: {
      'closed_on': closedOn,
      'proceeds_minor': proceeds.minor,
      'currency': proceeds.currency.code,
      'account_id': accountId,
      'reason': reason.trim(),
    },
    change: (tx) async {
      final a = await _current(id, expectedRevision);
      LedgerRepository.validateDate(closedOn);
      _text(reason, 400);
      final latest = (await snapshot()).latest(id);
      if (proceeds.currency != Currency.inr ||
          proceeds.minor < 0 ||
          (a.purchasedOn != null && closedOn.compareTo(a.purchasedOn!) < 0) ||
          (latest != null && closedOn.compareTo(latest.valuedOn) < 0) ||
          (proceeds.minor > 0 && accountId == null)) {
        throw _invalid;
      }
      if (accountId != null) {
        await tx.liquidAccount(accountId);
      }
      final book = await _book(a.accountId, closedOn);
      if (book < 0) {
        throw _invalid;
      }
      final equity = (await tx.systemAccount(
        'capital_disposals',
        'Capital disposal reserve',
        AccountKind.equity,
      )).id;
      final rows = [
        PostingInput(a.accountId, -book),
        if (proceeds.minor != 0) PostingInput(accountId!, proceeds.minor),
        PostingInput(
          equity,
          checkedInt64(BigInt.from(book) - BigInt.from(proceeds.minor)),
        ),
      ].where((p) => p.amountMinor != 0).toList();
      if (rows.isNotEmpty) {
        await tx.post(
          kind: EntryKind.adjustment,
          occurredOn: closedOn,
          description: reason.trim(),
          postings: rows,
          purpose: 'disposal',
        );
      }
      tx.before = databaseRecord(a);
      await (db.update(db.wealthAssets)..where((t) => t.id.equals(id))).write(
        WealthAssetsCompanion(
          revision: Value(a.revision + 1),
          updatedBy: Value(actor),
          updatedAtUs: Value(now),
          valuationState: const Value('closed'),
          closedOn: Value(closedOn),
          deletedAtUs: Value(now),
        ),
      );
      return databaseRecord(await asset(id));
    },
  );

  Future<String> undoClose(
    String id,
    int expectedRevision, {
    required String reason,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'asset',
    entityId: id,
    baseRevision: expectedRevision,
    action: 'restore',
    command: {'undo_close': true, 'reason': reason.trim()},
    change: (tx) async {
      final a = await _current(id, expectedRevision, closed: true);
      if (a.closedOn == null) {
        throw _stale;
      }
      _text(reason, 400);
      final links =
          await (db.select(db.aggregateJournalLinks)..where(
                (t) =>
                    t.familyId.equals(family) &
                    t.aggregateId.equals(id) &
                    t.aggregateType.equals('asset') &
                    t.purpose.isIn(['disposal', 'disposal_bridge']),
              ))
              .get();
      for (final l in links) {
        final j = (await ledger.detail(l.journalId)).journal;
        if (j.deletedAtUs == null) {
          await tx.reverse(j.id, reason);
        }
      }
      tx.before = databaseRecord(a);
      final known = (await snapshot()).valuations.any((v) => v.assetId == id);
      await (db.update(db.wealthAssets)..where((t) => t.id.equals(id))).write(
        WealthAssetsCompanion(
          revision: Value(a.revision + 1),
          updatedBy: Value(actor),
          updatedAtUs: Value(now),
          valuationState: Value(known ? 'recorded' : 'unrecorded'),
          closedOn: const Value(null),
          deletedAtUs: const Value(null),
        ),
      );
      return databaseRecord(await asset(id));
    },
  );

  Future<String> recordRent(
    String id,
    int expectedRevision, {
    required Money amount,
    required String accountId,
    required String receivedOn,
    required String description,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'asset',
    entityId: id,
    baseRevision: expectedRevision,
    command: {
      'amount_minor': amount.minor,
      'currency': amount.currency.code,
      'account_id': accountId,
      'received_on': receivedOn,
      'description': description.trim(),
    },
    change: (tx) async {
      final a = await _current(id, expectedRevision, closed: true);
      LedgerRepository.validateDate(receivedOn);
      if (!['property', 'land'].contains(a.kind) ||
          amount.currency != Currency.inr ||
          amount.minor <= 0 ||
          (a.purchasedOn != null && receivedOn.compareTo(a.purchasedOn!) < 0) ||
          (a.closedOn != null && receivedOn.compareTo(a.closedOn!) > 0)) {
        throw _invalid;
      }
      await tx.liquidAccount(accountId);
      tx.before = databaseRecord(a);
      await (db.update(db.wealthAssets)..where((t) => t.id.equals(id))).write(
        WealthAssetsCompanion(
          revision: Value(a.revision + 1),
          updatedBy: Value(actor),
          updatedAtUs: Value(now),
        ),
      );
      await tx.post(
        kind: EntryKind.income,
        occurredOn: receivedOn,
        description: description,
        postings: [
          PostingInput(accountId, amount.minor),
          PostingInput(ledger.chartId('rental'), -amount.minor),
        ],
        purpose: 'rent',
        aggregateType: 'asset_rent',
      );
      return databaseRecord(await asset(id));
    },
  );

  Future<String> reverseRent(
    String id,
    int expectedRevision,
    String journalId,
    String reason, {
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'asset',
    entityId: id,
    baseRevision: expectedRevision,
    command: {'reverse_rent': journalId, 'reason': reason.trim()},
    change: (tx) async {
      final a = await _current(id, expectedRevision, closed: true);
      await tx.reverse(journalId, reason, aggregateType: 'asset_rent');
      tx.before = databaseRecord(a);
      await (db.update(db.wealthAssets)..where((t) => t.id.equals(id))).write(
        WealthAssetsCompanion(
          revision: Value(a.revision + 1),
          updatedBy: Value(actor),
          updatedAtUs: Value(now),
        ),
      );
      return databaseRecord(await asset(id));
    },
  );

  Future<AssetSnapshot> snapshot() => storageBoundary(
    () => db.transaction(() async {
      await ledger.mutations.authorize();
      return AssetSnapshot(
        assets:
            await (db.select(db.wealthAssets)
                  ..where((t) => t.familyId.equals(family))
                  ..orderBy([(t) => OrderingTerm.asc(t.name)]))
                .get(),
        properties: await (db.select(
          db.propertyDetails,
        )..where((t) => t.familyId.equals(family))).get(),
        metals: await (db.select(
          db.metalDetails,
        )..where((t) => t.familyId.equals(family))).get(),
        investments: await (db.select(
          db.investmentDetails,
        )..where((t) => t.familyId.equals(family))).get(),
        owners: await (db.select(
          db.assetOwnerships,
        )..where((t) => t.familyId.equals(family))).get(),
        valuations:
            await (db.select(db.assetValuations)
                  ..where((t) => t.familyId.equals(family))
                  ..orderBy([
                    (t) => OrderingTerm.desc(t.valuedOn),
                    (t) => OrderingTerm.desc(t.assetRevision),
                    (t) => OrderingTerm.desc(t.eventIndex),
                  ]))
                .get(),
      );
    }),
  );
  Stream<AssetSnapshot> watch() => db
      .customSelect(
        'SELECT 1 /* asset projection */',
        readsFrom: {
          db.wealthAssets,
          db.propertyDetails,
          db.metalDetails,
          db.investmentDetails,
          db.assetOwnerships,
          db.assetValuations,
          db.familyMembers,
          db.vaultDevices,
        },
      )
      .watch()
      .asyncMap((_) => snapshot());
}
