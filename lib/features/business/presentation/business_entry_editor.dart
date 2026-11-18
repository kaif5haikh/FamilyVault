import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/vault_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/finance/fixed_decimal.dart';
import '../../../core/finance/money.dart';
import '../../../shared/widgets/record_fields.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../../finance/data/ledger_repository.dart';
import '../data/business_repository.dart';
import 'business_detail_pages.dart';
import 'business_pages.dart';

enum BusinessEntryMode { revenue, expense, stock, salary }

class BusinessEntryEditor extends ConsumerStatefulWidget {
  const BusinessEntryEditor({
    required this.id,
    required this.mode,
    super.key,
    this.originalId,
  });
  final String id;
  final BusinessEntryMode mode;
  final String? originalId;
  @override
  ConsumerState<BusinessEntryEditor> createState() =>
      _BusinessEntryEditorState();
}

class _BusinessEntryEditorState extends ConsumerState<BusinessEntryEditor> {
  final _amount = TextEditingController(), _notes = TextEditingController();
  final _units = TextEditingController(), _period = TextEditingController();
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _date = LedgerRepository.dateOnly(DateTime.now());
  String? _cashId, _operationId;
  StockEntryKind _stockKind = StockEntryKind.opening;
  int? _revision;
  bool _prepared = false, _busy = false;
  Object? _error;
  bool get _stock => widget.mode == BusinessEntryMode.stock;
  bool get _salary => widget.mode == BusinessEntryMode.salary;
  bool get _correcting => widget.originalId != null;
  bool get _needsCash => !_stock || _stockKind == StockEntryKind.purchase;

  String get _title => switch (widget.mode) {
    BusinessEntryMode.stock =>
      _correcting ? 'Correct stock movement' : 'Record stock movement',
    BusinessEntryMode.salary =>
      _correcting ? 'Correct salary payment' : 'Record salary payment',
    BusinessEntryMode.revenue => 'Record revenue',
    BusinessEntryMode.expense => 'Record operating expense',
  };

  @override
  void dispose() {
    for (final controller in [_amount, _notes, _units, _period, _reason]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _load(
    BusinessSnapshot data,
    FinanceSnapshot finance,
    Set<String> cashIds,
  ) {
    String? journal;
    final String label;
    if (_stock) {
      final item = data.items
          .where((r) => r.id == widget.id && r.deletedAtUs == null)
          .firstOrNull;
      if (item == null) {
        return null;
      }
      label = item.name;
      final latest = data.activeMovements(item.id).firstOrNull;
      if (_correcting && latest?.id != widget.originalId) {
        return null;
      }
      if (!_prepared) {
        _revision = item.revision;
        _stockKind = latest == null
            ? StockEntryKind.opening
            : StockEntryKind.purchase;
        if (_correcting && latest != null) {
          _stockKind = StockEntryKind.values.firstWhere(
            (v) => v.code == latest.kind,
          );
          _date = latest.occurredOn;
          _units.text = latest.quantityDelta.abs().toString();
          _amount.text = _stockKind.isReceipt
              ? minorInput(latest.valueDeltaMinor)
              : '';
          _notes.text = latest.notes;
          journal = latest.journalId;
        }
      }
    } else if (_salary) {
      final worker = data.workers
          .where((r) => r.id == widget.id && r.deletedAtUs == null)
          .firstOrNull;
      if (worker == null) {
        return null;
      }
      label = worker.name;
      final payment = data.salaries
          .where((r) => r.id == widget.originalId && r.workerId == worker.id)
          .firstOrNull;
      final original = finance.journals
          .where((j) => j.id == payment?.journalId && j.deletedAtUs == null)
          .firstOrNull;
      if (_correcting && (payment == null || original == null)) {
        return null;
      }
      if (!_prepared) {
        _revision = worker.revision;
        final amount = payment?.amountMinor ?? worker.monthlySalaryMinor;
        _amount.text = amount == null ? '' : minorInput(amount);
        _date = payment?.paidOn ?? _date;
        _period.text = payment?.period ?? _date.substring(0, 7);
        _notes.text = payment?.notes ?? '';
        journal = payment?.journalId;
      }
    } else {
      final business = data.businesses
          .where((r) => r.id == widget.id && r.deletedAtUs == null)
          .firstOrNull;
      if (business == null) {
        return null;
      }
      label = business.name;
    }
    if (!_prepared && journal != null) {
      _cashId = finance.postings
          .where((p) => p.journalId == journal && cashIds.contains(p.accountId))
          .firstOrNull
          ?.accountId;
    }
    _prepared = true;
    return label;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title)),
    body: BusinessView(
      builder: (data, finance) {
        final cash = finance.accounts.where(_isLiquid).toList();
        final cashIds = cash.map((a) => a.id).toSet();
        final label = _load(data, finance, cashIds);
        if (label == null) {
          return const VaultContent(
            children: [
              Text('This record is unavailable for the selected action.'),
            ],
          );
        }
        return VaultContent(
          maxWidth: 700,
          children: [
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  if (_correcting)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: Text(
                        'The original entry will stay in the history with its reversal and replacement.',
                      ),
                    ),
                  if (_stock) ...[
                    RecordChoice<StockEntryKind>(
                      'Movement type',
                      _stockKind,
                      [
                        for (final k in StockEntryKind.values)
                          (k, stockLabel(k.code)),
                      ],
                      (kind) => setState(() => _stockKind = kind),
                      enabled: !_busy,
                    ),
                    RecordField(
                      'Quantity in pieces',
                      _units,
                      required: true,
                      scale: 0,
                      enabled: !_busy,
                    ),
                    if (!_stockKind.isReceipt)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 18),
                        child: Text(
                          'Stock issued uses the weighted cost of the pieces on hand.',
                        ),
                      ),
                  ],
                  if (!_stock || _stockKind.isReceipt)
                    RecordField(
                      _stock
                          ? 'Total stock cost'
                          : _salary
                          ? 'Amount paid'
                          : 'Amount',
                      _amount,
                      required: true,
                      money: true,
                      enabled: !_busy,
                    ),
                  if (_needsCash) ...[
                    if (cash.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 18),
                        child: Text(
                          'Add a cash or bank account before recording money moving.',
                        ),
                      ),
                    RecordChoice<String>(
                      widget.mode == BusinessEntryMode.revenue
                          ? 'Received into'
                          : 'Paid from',
                      cashIds.contains(_cashId) ? _cashId : null,
                      [for (final a in cash) (a.id, a.name)],
                      (id) => setState(() => _cashId = id),
                      enabled: !_busy,
                    ),
                  ],
                  RecordDate(
                    _stock ? 'Movement date' : 'Payment date',
                    _date,
                    (value) => setState(() => _date = value),
                    enabled: !_busy,
                  ),
                  if (_salary)
                    RecordField(
                      'Salary month (YYYY-MM)',
                      _period,
                      required: true,
                      maxLength: 7,
                      enabled: !_busy,
                    ),
                  RecordField(
                    _stock || _salary ? 'Notes (optional)' : 'Description',
                    _notes,
                    lines: 2,
                    maxLength: _stock || _salary ? 4000 : 500,
                    required: !_stock && !_salary,
                    enabled: !_busy,
                  ),
                  if (_correcting)
                    RecordField(
                      'Reason for correction',
                      _reason,
                      required: true,
                      maxLength: 400,
                      enabled: !_busy,
                    ),
                  if (_error != null) FailureNotice(_error!),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _busy
                          ? 'Saving…'
                          : _correcting
                          ? 'Save correction'
                          : 'Save entry',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  bool _isLiquid(LedgerAccount row) =>
      row.kind == 'asset' &&
      ['cash', 'bank'].contains(row.subtype) &&
      row.deletedAtUs == null;

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
          repo = BusinessRepository(session.ledger);
      _operationId ??= session.ledger.operationId();
      final id = widget.id, original = widget.originalId;
      final String route;
      if (_stock) {
        final draft = StockEntryDraft(
          kind: _stockKind,
          units: FixedDecimal.parse(_units.text, scale: 0),
          date: _date,
          costMinor: _stockKind.isReceipt ? optionalMinor(_amount) : null,
          cashAccountId: _needsCash ? _cashId : null,
          notes: _notes.text,
        );
        if (original == null) {
          await repo.moveStock(
            id,
            _revision!,
            draft,
            operationId: _operationId,
          );
        } else {
          await repo.correctStock(
            id,
            _revision!,
            original,
            _reason.text,
            replacement: draft,
            operationId: _operationId,
          );
        }
        route = '/stock/$id';
      } else if (_salary) {
        final draft = SalaryDraft(
          amountMinor: optionalMinor(_amount)!,
          period: _period.text.trim(),
          paidOn: _date,
          cashAccountId: _cashId!,
          notes: _notes.text,
        );
        if (original == null) {
          await repo.paySalary(
            id,
            _revision!,
            draft,
            operationId: _operationId,
          );
        } else {
          await repo.correctSalary(
            id,
            _revision!,
            original,
            _reason.text,
            replacement: draft,
            operationId: _operationId,
          );
        }
        route = '/worker/$id';
      } else {
        await repo.cashEntry(
          id,
          revenue: widget.mode == BusinessEntryMode.revenue,
          amount: Money.parseInr(_amount.text),
          accountId: _cashId!,
          date: _date,
          description: _notes.text,
          operationId: _operationId,
        );
        route = '/business/$id';
      }
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(route);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
