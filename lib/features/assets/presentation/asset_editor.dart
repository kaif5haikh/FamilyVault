import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/vault_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/finance/fixed_decimal.dart';
import '../../../core/finance/money.dart';
import '../../../shared/widgets/record_fields.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../../finance/data/ledger_repository.dart';
import '../data/asset_repository.dart';
import '../domain/metal_calculator.dart';
import 'asset_providers.dart';

class AssetEditor extends ConsumerStatefulWidget {
  const AssetEditor({
    super.key,
    this.id,
    this.initialKind = AssetKind.property,
  });
  final String? id;
  final AssetKind initialKind;
  @override
  ConsumerState<AssetEditor> createState() => _AssetEditorState();
}

class _OwnerFields {
  _OwnerFields({String label = '', int? bps, this.memberId})
    : name = TextEditingController(text: label),
      share = TextEditingController(
        text: bps == null ? '' : FixedDecimal.format(bps, scale: 2),
      );
  final TextEditingController name, share;
  final String? memberId;
  void dispose() {
    name.dispose();
    share.dispose();
  }
}

class _AssetEditorState extends ConsumerState<AssetEditor> {
  final _form = GlobalKey<FormState>();
  final _purchasePanel = ExpansibleController();
  final _peoplePanel = ExpansibleController();
  final _name = TextEditingController(),
      _share = TextEditingController(text: '100'),
      _purchase = TextEditingController(),
      _value = TextEditingController(),
      _notes = TextEditingController(),
      _city = TextEditingController(),
      _location = TextEditingController(),
      _area = TextEditingController(),
      _unit = TextEditingController(),
      _reference = TextEditingController(),
      _weight = TextEditingController(),
      _assay = TextEditingController(),
      _rate = TextEditingController(),
      _making = TextEditingController(),
      _instrument = TextEditingController(),
      _symbol = TextEditingController(),
      _units = TextEditingController();
  final _owners = <_OwnerFields>[];
  late AssetKind _kind;
  String _metal = 'gold', _purity = 'unrecorded';
  String? _funding, _operation;
  bool _pay = false, _knownDate = false, _busy = false, _prepared = false;
  Object? _error;
  int? _revision;
  int _quantityScale = 6;
  String _purchasedOn = LedgerRepository.dateOnly(DateTime.now()),
      _valuedOn = LedgerRepository.dateOnly(DateTime.now());
  bool get _editing => widget.id != null;
  bool get _isProperty => [AssetKind.property, AssetKind.land].contains(_kind);
  bool get _isMetal =>
      [AssetKind.gold, AssetKind.silver, AssetKind.jewellery].contains(_kind);
  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _metal = _kind == AssetKind.silver ? 'silver' : 'gold';
  }

  @override
  void dispose() {
    _purchasePanel.dispose();
    _peoplePanel.dispose();
    for (final c in [
      _name,
      _share,
      _purchase,
      _value,
      _notes,
      _city,
      _location,
      _area,
      _unit,
      _reference,
      _weight,
      _assay,
      _rate,
      _making,
      _instrument,
      _symbol,
      _units,
    ]) {
      c.dispose();
    }
    for (final o in _owners) {
      o.dispose();
    }
    super.dispose();
  }

  void _prepare(AssetSnapshot s) {
    if (!_editing || _prepared) {
      return;
    }
    final a = s.assets.where((a) => a.id == widget.id).firstOrNull;
    if (a == null) {
      return;
    }
    _revision = a.revision;
    _name.text = a.name;
    _notes.text = a.notes;
    _kind = AssetKind.values.byName(a.kind);
    _share.text = FixedDecimal.format(a.familyOwnershipBps, scale: 2);
    _purchase.text = a.purchaseTotalMinor == null
        ? ''
        : minorInput(a.purchaseTotalMinor!);
    _purchasedOn = a.purchasedOn ?? _purchasedOn;
    _knownDate = a.purchasedOn != null;
    for (final o in s.owners.where(
      (o) => o.assetId == a.id && o.deletedAtUs == null,
    )) {
      _owners.add(
        _OwnerFields(
          label: o.ownerLabel,
          bps: o.shareBps,
          memberId: o.memberId,
        ),
      );
    }
    final p = s.properties.where((p) => p.assetId == a.id).firstOrNull;
    if (p != null) {
      _city.text = p.city;
      _location.text = p.location;
      _reference.text = p.recordReference ?? '';
      _area.text = p.areaMilli == null
          ? ''
          : FixedDecimal.format(p.areaMilli!, scale: 3);
      _unit.text = p.areaUnit ?? '';
    }
    final m = s.metals.where((m) => m.assetId == a.id).firstOrNull;
    if (m != null) {
      _metal = m.metal;
      _weight.text = FixedDecimal.format(m.weightMg, scale: 3);
      _purity = m.purityKind == 'nominal' ? '${m.karat}' : m.purityKind;
      _assay.text = m.purityPpm == null
          ? ''
          : FixedDecimal.format(m.purityPpm!, scale: 4);
      _rate.text = m.purchaseRateMinorPerGram == null
          ? ''
          : minorInput(m.purchaseRateMinorPerGram!);
      _making.text = m.makingChargesMinor == null
          ? ''
          : minorInput(m.makingChargesMinor!);
    }
    final i = s.investments.where((i) => i.assetId == a.id).firstOrNull;
    if (i != null) {
      _instrument.text = i.instrument;
      _symbol.text = i.symbol ?? '';
      _quantityScale = i.quantityScale ?? 6;
      _units.text = i.quantityScaled == null
          ? ''
          : FixedDecimal.format(i.quantityScaled!, scale: _quantityScale);
    }
    _prepared = true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_editing ? 'Edit item details' : 'Add something we own'),
    ),
    body: AssetView(
      builder: (assets) => FinanceView(
        builder: (finance) {
          _prepare(assets);
          if (_editing &&
              (!_prepared ||
                  assets.assets.any(
                    (a) => a.id == widget.id && a.closedOn != null,
                  ))) {
            return const VaultContent(
              children: [Text('We couldn’t open that item for changes.')],
            );
          }
          final liquid = finance.accounts
              .where(
                (a) =>
                    a.kind == 'asset' &&
                    ['cash', 'bank'].contains(a.subtype) &&
                    a.deletedAtUs == null,
              )
              .toList();
          if (!liquid.any((a) => a.id == _funding)) {
            _funding = liquid.firstOrNull?.id;
          }
          return VaultContent(
            maxWidth: 720,
            children: [
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _editing ? 'Earlier details stay in the item’s history.' : 'Enter details for the whole item. Your family summary counts just the share you own.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    RecordField(
                      'Item name',
                      _name,
                      required: true,
                      enabled: !_busy,
                    ),
                    RecordChoice<AssetKind>(
                      'Kind of item',
                      _kind,
                      [
                        for (final k in AssetKind.values)
                          (k, assetLabel(k.name)),
                      ],
                      (v) => setState(() {
                        _kind = v;
                        _metal = v == AssetKind.silver ? 'silver' : 'gold';
                        _purity = 'unrecorded';
                      }),
                      enabled: !_busy && !_editing,
                    ),
                    RecordField(
                      'Family share (%)',
                      _share,
                      required: true,
                      scale: 2,
                      enabled: !_busy && !_editing,
                      hint: 'Use 100% if your family owns the whole item.',
                    ),
                    if (_isProperty) ...[
                      const SectionHeading('Property & location'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final city in ['Mumbai', 'Ballia'])
                            ActionChip(
                              label: Text(city),
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _city.text = city),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RecordField(
                        'City or district',
                        _city,
                        required: true,
                        enabled: !_busy,
                      ),
                      RecordField(
                        'Location or address (optional)',
                        _location,
                        enabled: !_busy,
                        lines: 2,
                        maxLength: 500,
                      ),
                      RecordField(
                        'Area (optional)',
                        _area,
                        scale: 3,
                        enabled: !_busy,
                      ),
                      RecordField(
                        'Recorded area unit (optional)',
                        _unit,
                        maxLength: 24,
                        enabled: !_busy,
                        hint: 'For example, square feet or the unit stated in the deed.',
                      ),
                      RecordField(
                        'Property record reference (optional)',
                        _reference,
                        maxLength: 200,
                        enabled: !_busy,
                      ),
                    ],
                    if (_isMetal) ...[
                      const SectionHeading('Metal details'),
                      if (_kind == AssetKind.jewellery)
                        RecordChoice<String>(
                          'Metal',
                          _metal,
                          const [('gold', 'Gold'), ('silver', 'Silver')],
                          (v) => setState(() {
                            _metal = v;
                            _purity = 'unrecorded';
                          }),
                          enabled: !_busy,
                        ),
                      RecordField(
                        'Weight in grams',
                        _weight,
                        required: true,
                        scale: 3,
                        enabled: !_busy,
                      ),
                      RecordChoice<String>(
                        'Purity',
                        _purity,
                        [
                          ('unrecorded', 'Unrecorded'),
                          if (_metal == 'gold') ...[
                            ('18', '18K nominal'),
                            ('22', '22K nominal'),
                            ('24', '24K nominal'),
                          ],
                          ('assayed', 'Recorded assay (%)'),
                        ],
                        (v) => setState(() => _purity = v),
                        enabled: !_busy,
                      ),
                      if (_purity == 'assayed')
                        RecordField(
                          'Assayed purity (%)',
                          _assay,
                          required: true,
                          scale: 4,
                          enabled: !_busy,
                        ),
                      RecordField(
                        'Purchase rate per gram (optional)',
                        _rate,
                        money: true,
                        enabled: !_busy,
                      ),
                      RecordField(
                        'Making charges (optional)',
                        _making,
                        money: true,
                        enabled: !_busy,
                      ),
                      if (!_editing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () {
                                    try {
                                      if (optionalText(_rate) == null ||
                                          optionalText(_making) == null) {
                                        throw const AppFailure(
                                          FailureCode.validation,
                                          'Enter the purchase rate and making charges, including zero if applicable.',
                                        );
                                      }
                                      final cost = MetalCalculator.purchaseCost(
                                        weightMg: FixedDecimal.parse(
                                          _weight.text,
                                          scale: 3,
                                        ),
                                        rateAtRecordedPurity: Money.parseInr(
                                          _rate.text,
                                        ),
                                        makingCharges: Money.parseInr(
                                          _making.text,
                                        ),
                                      );
                                      setState(() {
                                        _purchase.text = minorInput(cost.minor);
                                        _error = null;
                                      });
                                    } catch (e) {
                                      setState(() => _error = e);
                                    }
                                  },
                            icon: const Icon(Icons.calculate_outlined),
                            label: const Text('Calculate purchase cost'),
                          ),
                        ),
                    ],
                    if (_kind == AssetKind.investment) ...[
                      const SectionHeading('Investment details'),
                      RecordField(
                        'Instrument',
                        _instrument,
                        required: true,
                        enabled: !_busy,
                      ),
                      RecordField(
                        'Symbol or reference (optional)',
                        _symbol,
                        maxLength: 80,
                        enabled: !_busy,
                      ),
                      RecordField(
                        'Units (optional)',
                        _units,
                        scale: _quantityScale,
                        enabled: !_busy,
                      ),
                    ],
                    if (!_editing) ...[
                      RecordField(
                        'Estimated value of the whole item (optional)',
                        _value,
                        money: true,
                        enabled: !_busy,
                        hint: 'Use the most recent amount you know.',
                      ),
                      RecordDate(
                        'Date of estimate',
                        _valuedOn,
                        (v) => setState(() => _valuedOn = v),
                        enabled: !_busy,
                      ),
                    ],
                    ExpansionTile(
                      controller: _purchasePanel,
                      maintainState: true,
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Purchase and payment details'),
                      children: [
                        RecordField(
                          'Price paid for the whole item (optional)',
                          _purchase,
                          money: true,
                          enabled: !_busy && !_editing,
                          hint: _editing
                              ? 'Acquisition entries retain their posted history.'
                              : 'Leave blank when unknown. Enter zero only for a known zero price.',
                        ),
                        if (!_editing) ...[
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Record known purchase date'),
                            value: _knownDate,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _knownDate = v),
                          ),
                          RecordDate(
                            'Purchase date',
                            _purchasedOn,
                            (v) => setState(() {
                              _purchasedOn = v;
                              _knownDate = true;
                            }),
                            enabled: !_busy,
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Record payment from cash or bank',
                            ),
                            subtitle: const Text(
                              'For a new purchase. Leave off for an already owned opening holding.',
                            ),
                            value: _pay,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _pay = v),
                          ),
                          if (_pay)
                            RecordChoice<String>(
                              'Payment account',
                              _funding,
                              [for (final a in liquid) (a.id, a.name)],
                              (v) => setState(() => _funding = v),
                              enabled: !_busy,
                            ),
                        ],
                      ],
                    ),
                    ExpansionTile(
                      controller: _peoplePanel,
                      maintainState: true,
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Individual shares and notes (optional)',
                      ),
                      children: [
                        const Text(
                          'Enter each person’s share of the whole item. Together these shares must fit within the family share.',
                        ),
                        const SizedBox(height: 16),
                        for (var index = 0; index < _owners.length; index++)
                          Card.outlined(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  RecordField(
                                    'Owner ${index + 1} name',
                                    _owners[index].name,
                                    required: true,
                                    enabled: !_busy,
                                  ),
                                  RecordField(
                                    'Owner ${index + 1} share (%)',
                                    _owners[index].share,
                                    required: true,
                                    scale: 2,
                                    enabled: !_busy,
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => setState(() {
                                              final o = _owners.removeAt(index);
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback(
                                                    (_) => o.dispose(),
                                                  );
                                            }),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      label: const Text(
                                        'Remove person’s share',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () =>
                                    setState(() => _owners.add(_OwnerFields())),
                          icon: const Icon(Icons.person_add_alt_outlined),
                          label: const Text('Add a person’s share'),
                        ),
                        const SizedBox(height: 20),
                        RecordField(
                          'Notes (optional)',
                          _notes,
                          lines: 3,
                          maxLength: 4000,
                          enabled: !_busy,
                        ),
                      ],
                    ),
                    if (_error != null) FailureNotice(_error!),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.check),
                      label: Text(_busy ? 'Saving…' : 'Save item'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) {
      if (_purchase.text.isNotEmpty || _pay) _purchasePanel.expand();
      if (_owners.isNotEmpty) _peoplePanel.expand();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = ref.read(vaultProvider).session!,
          repo = AssetRepository(session.ledger);
      _operation ??= session.ledger.operationId();
      if (!_editing && optionalText(_purchase) != null && !_knownDate) {
        throw const AppFailure(
          FailureCode.validation,
          'Choose the purchase date before recording its price.',
        );
      }

      final owners = [
        for (final o in _owners)
          OwnerDraft(
            o.name.text,
            FixedDecimal.parse(o.share.text, scale: 2),
            memberId: o.memberId,
          ),
      ];
      final property = !_isProperty
          ? null
          : PropertyDraft(
              city: _city.text,
              location: _location.text,
              areaMilli: optionalText(_area) == null
                  ? null
                  : FixedDecimal.parse(_area.text, scale: 3),
              areaUnit: optionalText(_unit),
              recordReference: optionalText(_reference),
            );
      final nominal = int.tryParse(_purity);
      final metal = !_isMetal
          ? null
          : MetalDraft(
              metal: _metal,
              weightMg: FixedDecimal.parse(_weight.text, scale: 3),
              purityKind: nominal != null ? 'nominal' : _purity,
              purityPpm: nominal != null
                  ? MetalCalculator.nominalPurity(nominal)
                  : _purity == 'assayed'
                  ? FixedDecimal.parse(_assay.text, scale: 4)
                  : null,
              karat: nominal,
              purchaseRateMinorPerGram: optionalMinor(_rate),
              makingChargesMinor: optionalMinor(_making),
            );
      final investment = _kind != AssetKind.investment
          ? null
          : InvestmentDraft(
              instrument: _instrument.text,
              symbol: optionalText(_symbol),
              quantityScaled: optionalText(_units) == null
                  ? null
                  : FixedDecimal.parse(_units.text, scale: _quantityScale),
              quantityScale: optionalText(_units) == null
                  ? null
                  : _quantityScale,
            );
      final id = _editing
          ? await repo.edit(
              widget.id!,
              _revision!,
              name: _name.text,
              notes: _notes.text,
              owners: owners,
              property: property,
              metal: metal,
              investment: investment,
              operationId: _operation,
            )
          : await repo.create(
              AssetDraft(
                name: _name.text,
                kind: _kind,
                familyOwnershipBps: FixedDecimal.parse(_share.text, scale: 2),
                purchaseTotalMinor: optionalMinor(_purchase),
                purchasedOn: _knownDate ? _purchasedOn : null,
                fundingAccountId: _pay ? _funding : null,
                currentTotalMinor: optionalMinor(_value),
                valuedOn: optionalText(_value) == null ? null : _valuedOn,
                notes: _notes.text,
                owners: owners,
                property: property,
                metal: metal,
                investment: investment,
              ),
              operationId: _operation,
            );
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
        context.pushReplacement('/asset/$id');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
