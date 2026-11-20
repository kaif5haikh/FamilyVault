import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/vault_providers.dart';
import '../../../core/finance/fixed_decimal.dart';
import '../../../core/finance/money.dart';
import '../../../shared/widgets/record_fields.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../../finance/data/ledger_repository.dart';
import '../data/asset_repository.dart';
import '../domain/metal_calculator.dart';
import 'asset_providers.dart';

class AssetActionEditor extends ConsumerStatefulWidget {
  const AssetActionEditor({required this.id, required this.action, super.key});
  final String id, action;
  @override
  ConsumerState<AssetActionEditor> createState() => _AssetActionEditorState();
}

class _AssetActionEditorState extends ConsumerState<AssetActionEditor> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(),
      _note = TextEditingController(),
      _rate = TextEditingController(),
      _share = TextEditingController();
  String _date = LedgerRepository.dateOnly(DateTime.now());
  String? _account, _operation;
  int? _revision;
  int _quotePurity = 1000000;
  bool _busy = false, _prepared = false, _metalQuote = false;
  Object? _error;
  bool get _value => widget.action == 'value';
  bool get _ownership => widget.action == 'ownership';
  bool get _quote => _value || _ownership;
  bool get _rent => widget.action == 'rent';
  String get _title => _value
      ? 'Update estimated value'
      : _rent
      ? 'Add rent received'
      : _ownership
      ? 'Change family share'
      : 'Close this item';
  bool get _needsAccount {
    if (_rent) {
      return true;
    }
    if (_quote) {
      return false;
    }
    try {
      return Money.parseInr(_amount.text).minor > 0;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _rate.dispose();
    _share.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title)),
    body: AssetView(
      builder: (assets) => FinanceView(
        builder: (finance) {
          final a = assets.assets.where((a) => a.id == widget.id).firstOrNull;
          if (a == null || (a.closedOn != null && !_value)) {
            return const VaultContent(
              children: [Text('We couldn’t open that item.')],
            );
          }
          final metal = assets.metals
              .where((m) => m.assetId == a.id)
              .firstOrNull;
          if (!_prepared) {
            _revision = a.revision;
            _date = a.closedOn ?? _date;
            _share.text = FixedDecimal.format(a.familyOwnershipBps, scale: 2);
            if (_quote) {
              final v = assets.latest(a.id);
              if (v != null) {
                _amount.text = minorInput(v.totalValueMinor);
              }
            }
            _prepared = true;
          }
          final liquid = finance.accounts
              .where(
                (a) =>
                    a.kind == 'asset' &&
                    ['cash', 'bank'].contains(a.subtype) &&
                    a.deletedAtUs == null,
              )
              .toList();
          if (!liquid.any((a) => a.id == _account)) {
            _account = liquid.firstOrNull?.id;
          }
          return VaultContent(
            maxWidth: 700,
            children: [
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      a.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _value
                          ? 'Record a whole-holding estimate. The family share is calculated once. Later recorded valuations stay intact when adding historical values.'
                          : _ownership
                          ? 'Record the new family share and the whole holding’s value on that date. Earlier valuations retain their recorded share.'
                          : _rent
                          ? 'Rental income posts to your chosen cash or bank account and stays linked to this property.'
                          : 'Record the family’s actual proceeds, including zero for a gift or write-off. Prior values and accounting entries remain in history.',
                    ),
                    const SizedBox(height: 24),
                    if (_value && metal?.purityPpm != null) ...[
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Estimate from a metal rate'),
                        value: _metalQuote,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _metalQuote = v),
                      ),
                      if (_metalQuote) ...[
                        RecordField(
                          'Quoted rate per gram',
                          _rate,
                          money: true,
                          required: true,
                          enabled: !_busy,
                        ),
                        RecordChoice<int>(
                          'Quoted rate purity',
                          _quotePurity,
                          [
                            (1000000, '24K / 100% nominal'),
                            if (metal!.metal == 'gold') ...[
                              (
                                MetalCalculator.nominalPurity(22),
                                '22K nominal',
                              ),
                              (
                                MetalCalculator.nominalPurity(18),
                                '18K nominal',
                              ),
                            ],
                          ],
                          (v) => setState(() => _quotePurity = v),
                          enabled: !_busy,
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () {
                                  try {
                                    final value = MetalCalculator.estimate(
                                      weightMg: metal.weightMg,
                                      holdingPurityPpm: metal.purityPpm!,
                                      ratePerGram: Money.parseInr(_rate.text),
                                      quotePurityPpm: _quotePurity,
                                    );
                                    setState(() {
                                      _amount.text = minorInput(value.minor);
                                      _error = null;
                                    });
                                  } catch (e) {
                                    setState(() => _error = e);
                                  }
                                },
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('Calculate estimate'),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ],
                    if (_ownership)
                      RecordField(
                        'New family ownership (%)',
                        _share,
                        scale: 2,
                        required: true,
                        enabled: !_busy,
                      ),
                    RecordField(
                      _quote
                          ? 'Value of the whole item'
                          : _rent
                          ? 'Rent received'
                          : 'Family proceeds',
                      _amount,
                      money: true,
                      required: true,
                      enabled: !_busy,
                      onChanged: (_) => setState(() {}),
                    ),
                    RecordDate(
                      _ownership
                          ? 'Effective date'
                          : _value
                          ? 'Valuation date'
                          : _rent
                          ? 'Received on'
                          : 'Closed on',
                      _date,
                      (v) => setState(() => _date = v),
                      enabled: !_busy,
                    ),
                    if (_needsAccount) ...[
                      if (liquid.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 18),
                          child: Text(
                            'Add a cash or bank account before recording a payment.',
                          ),
                        ),
                      RecordChoice<String>(
                        'Received into',
                        _account,
                        [for (final a in liquid) (a.id, a.name)],
                        (v) => setState(() => _account = v),
                        enabled: !_busy,
                      ),
                    ],
                    RecordField(
                      _ownership
                          ? 'Reason for share change'
                          : _value
                          ? 'Where did the estimate come from?'
                          : _rent
                          ? 'Description'
                          : 'Closure reason',
                      _note,
                      required: true,
                      lines: 3,
                      maxLength: _quote ? 1000 : 400,
                      enabled: !_busy,
                    ),
                    if (_error != null) FailureNotice(_error!),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.check),
                      label: Text(
                        _busy
                            ? 'Saving…'
                            : _value
                            ? 'Save estimate'
                            : _rent
                            ? 'Save rent'
                            : _ownership
                            ? 'Save family share'
                            : 'Close this item',
                      ),
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
    if (!_form.currentState!.validate()) {
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
      if (_value) {
        await repo.value(
          widget.id,
          _revision!,
          total: Money.parseInr(_amount.text),
          valuedOn: _date,
          notes: _note.text,
          metalRate: _metalQuote ? Money.parseInr(_rate.text) : null,
          quotePurityPpm: _metalQuote ? _quotePurity : null,
          operationId: _operation,
        );
      } else if (_ownership) {
        await repo.changeOwnership(
          widget.id,
          _revision!,
          shareBps: FixedDecimal.parse(_share.text, scale: 2),
          wholeValue: Money.parseInr(_amount.text),
          effectiveOn: _date,
          reason: _note.text,
          operationId: _operation,
        );
      } else if (_rent) {
        await repo.recordRent(
          widget.id,
          _revision!,
          amount: Money.parseInr(_amount.text),
          accountId: _account!,
          receivedOn: _date,
          description: _note.text,
          operationId: _operation,
        );
      } else {
        await repo.close(
          widget.id,
          _revision!,
          closedOn: _date,
          proceeds: Money.parseInr(_amount.text),
          accountId: _needsAccount ? _account : null,
          reason: _note.text,
          operationId: _operation,
        );
      }
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
        context.pop();
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
