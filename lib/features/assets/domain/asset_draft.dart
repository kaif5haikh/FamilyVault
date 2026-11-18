enum AssetKind {
  property,
  land,
  gold,
  silver,
  jewellery,
  vehicle,
  deposit,
  investment,
  other,
}

final class OwnerDraft {
  const OwnerDraft(this.label, this.shareBps, {this.memberId});
  final String label;
  final int shareBps;
  final String? memberId;
  Map<String, Object?> toJson() => {
    'owner_label': label.trim(),
    'share_bps': shareBps,
    'member_id': memberId,
  };
}

final class PropertyDraft {
  const PropertyDraft({
    required this.city,
    required this.location,
    this.recordReference,
    this.areaMilli,
    this.areaUnit,
  });
  final String city, location;
  final String? recordReference, areaUnit;
  final int? areaMilli;
  Map<String, Object?> toJson() => {
    'city': city.trim(),
    'location': location.trim(),
    'record_reference': recordReference?.trim(),
    'area_milli': areaMilli,
    'area_unit': areaUnit?.trim(),
  };
}

final class MetalDraft {
  const MetalDraft({
    required this.metal,
    required this.weightMg,
    this.purityPpm,
    this.purityKind = 'unrecorded',
    this.karat,
    this.purchaseRateMinorPerGram,
    this.makingChargesMinor,
  });
  final String metal, purityKind;
  final int weightMg;
  final int? purityPpm, karat, purchaseRateMinorPerGram, makingChargesMinor;
  Map<String, Object?> toJson() => {
    'metal': metal,
    'weight_mg': weightMg,
    'purity_ppm': purityPpm,
    'purity_kind': purityKind,
    'karat': karat,
    'purchase_rate_minor_per_gram': purchaseRateMinorPerGram,
    'making_charges_minor': makingChargesMinor,
  };
}

final class InvestmentDraft {
  const InvestmentDraft({
    required this.instrument,
    this.symbol,
    this.quantityScaled,
    this.quantityScale,
  });
  final String instrument;
  final String? symbol;
  final int? quantityScaled, quantityScale;
  Map<String, Object?> toJson() => {
    'instrument': instrument.trim(),
    'symbol': symbol?.trim(),
    'quantity_scaled': quantityScaled,
    'quantity_scale': quantityScale,
  };
}

final class AssetDraft {
  const AssetDraft({
    required this.name,
    required this.kind,
    this.familyOwnershipBps = 10000,
    this.purchaseTotalMinor,
    this.purchasedOn,
    this.fundingAccountId,
    this.currentTotalMinor,
    this.valuedOn,
    this.notes = '',
    this.owners = const [],
    this.property,
    this.metal,
    this.investment,
  });
  final String name, notes;
  final AssetKind kind;
  final int familyOwnershipBps;
  final int? purchaseTotalMinor, currentTotalMinor;
  final String? purchasedOn, valuedOn, fundingAccountId;
  final List<OwnerDraft> owners;
  final PropertyDraft? property;
  final MetalDraft? metal;
  final InvestmentDraft? investment;
  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'kind': kind.name,
    'family_ownership_bps': familyOwnershipBps,
    'purchase_total_minor': purchaseTotalMinor,
    'purchased_on': purchasedOn,
    'funding_account_id': fundingAccountId,
    'current_total_minor': currentTotalMinor,
    'valued_on': valuedOn,
    'notes': notes.trim(),
    'owners': owners.map((o) => o.toJson()).toList(),
    'property': property?.toJson(),
    'metal': metal?.toJson(),
    'investment': investment?.toJson(),
  };
}
