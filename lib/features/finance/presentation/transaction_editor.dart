import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../app/vault_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/finance/money.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../data/ledger_repository.dart';

class TransactionEditor extends ConsumerStatefulWidget {
  const TransactionEditor({super.key, this.journalId});
  final String? journalId;
  @override
  ConsumerState<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends ConsumerState<TransactionEditor> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(),
      _description = TextEditingController(),
      _reason = TextEditingController();
  final _operation = const Uuid().v4();
  EntryKind _kind = EntryKind.expense;
  String? _account, _counter;
  String _date = LedgerRepository.dateOnly(DateTime.now());
  bool _busy = false, _prepared = false;
  Object? _error;
  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _prepare(FinanceSnapshot data) {
    if (_prepared) {
      return;
    }
    _prepared = true;
    if (widget.journalId == null) {
      return;
    }
    final matches = data.journals
        .where((j) => j.id == widget.journalId)
        .toList();
    if (matches.isEmpty) {
      return;
    }
    final journal = matches.single;
    if (!['income', 'expense', 'transfer'].contains(journal.kind)) {
      return;
    }
    _kind = EntryKind.values.byName(journal.kind);
    _description.text = journal.description;
    _date = journal.occurredOn;
    final postings = data.postings
        .where((p) => p.journalId == journal.id)
        .toList();
    final accounts = {for (final a in data.accounts) a.id: a};
    for (final p in postings) {
      if (accounts[p.accountId]?.kind == 'asset' &&
          (_kind == EntryKind.income ? p.amountMinor > 0 : p.amountMinor < 0)) {
        _account = p.accountId;
        _amount.text = Money.fromMinor(p.amountMinor)
            .negateIfNegative()
            .format(symbol: false, grouping: false);
      } else {
        _counter = p.accountId;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.journalId == null ? 'Add transaction' : 'Correct transaction',
      ),
    ),
    body: FinanceView(
      builder: (data) {
        _prepare(data);
        final originals = data.journals.where((j) => j.id == widget.journalId);
        if (widget.journalId != null &&
            (originals.isEmpty ||
                data.journalLinks.containsKey(widget.journalId) ||
                originals.single.deletedAtUs != null ||
                ![
                  'income',
                  'expense',
                  'transfer',
                ].contains(originals.single.kind))) {
          return const VaultContent(
            children: [
              EmptyNotice(
                icon: Icons.history,
                title: 'Entry unavailable for correction',
                message:
                    'Open the current transaction or use its audit history.',
              ),
            ],
          );
        }
        final assets = data.accounts
            .where(
              (a) =>
                  a.kind == 'asset' &&
                  a.deletedAtUs == null &&
                  !data.managedAccountIds.contains(a.id),
            )
            .toList();
        final counterKind = _kind == EntryKind.income
            ? 'income'
            : _kind == EntryKind.expense
            ? 'expense'
            : 'asset';
        final counters = data.accounts
            .where(
              (a) =>
                  a.kind == counterKind &&
                  a.deletedAtUs == null &&
                  !data.managedAccountIds.contains(a.id) &&
                  a.id != _account,
            )
            .toList();
        if (!assets.any((a) => a.id == _account)) {
          _account = null;
        }
        if (!counters.any((a) => a.id == _counter)) {
          _counter = null;
        }
        if (assets.isEmpty) {
          return VaultContent(
            children: [
              EmptyNotice(
                icon: Icons.account_balance_outlined,
                title: 'Add your first account',
                message: 'Choose a cash or bank account before recording income and expenses.',
                action: FilledButton(
                  onPressed: () => context.push('/account/new'),
                  child: const Text('Add account'),
                ),
              ),
            ],
          );
        }
        return VaultContent(
          maxWidth: 680,
          children: [
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.journalId != null) ...[
                    const Text(
                      'Your original entry is preserved. Saving appends a reversal and the corrected entry.',
                    ),
                    const SizedBox(height: 24),
                  ],
                  DropdownButtonFormField<EntryKind>(
                    initialValue: _kind,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final type in [
                        EntryKind.income,
                        EntryKind.expense,
                        EntryKind.transfer,
                      ])
                        DropdownMenuItem(
                          value: type,
                          child: Text(_label(type)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _kind = value!;
                            _counter = null;
                          }),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _amount,
                    enabled: !_busy,
                    maxLength: 32,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      hintText: '0.00',
                    ),
                    validator: positiveAmount,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('source-$_account'),
                    initialValue: _account,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _kind == EntryKind.income
                          ? 'Received into'
                          : 'Paid from',
                    ),
                    items: [
                      for (final a in assets)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _account = value;
                            if (_counter == value) {
                              _counter = null;
                            }
                          }),
                    validator: (v) => v == null ? 'Choose an account.' : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    key: ValueKey('counter-${_kind.name}-$_counter'),
                    initialValue: _counter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _kind == EntryKind.transfer
                          ? 'Transferred to'
                          : 'Category',
                    ),
                    items: [
                      for (final a in counters)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _counter = value),
                    validator: (v) => v == null
                        ? 'Choose ${_kind == EntryKind.transfer ? 'another account' : 'a category'}.'
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () =>
                                context.push('/account/new?kind=$counterKind'),
                      child: Text(
                        _kind == EntryKind.transfer
                            ? 'Add another account'
                            : 'Add a category',
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _chooseDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Date: $_date'),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _description,
                    enabled: !_busy,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: requiredText,
                  ),
                  if (widget.journalId != null) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reason,
                      enabled: !_busy,
                      maxLength: 400,
                      decoration: const InputDecoration(
                        labelText: 'Reason for correction',
                      ),
                      validator: requiredText,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    FailureNotice(_error!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _busy
                          ? 'Saving…'
                          : widget.journalId == null
                          ? 'Save transaction'
                          : 'Save correction',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Recorded in INR, with an immutable history of who created or corrected it.',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
  static String _label(EntryKind kind) => switch (kind) {
    EntryKind.income => 'Income',
    EntryKind.expense => 'Expense',
    _ => 'Transfer',
  };
  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
    );
    if (date != null && mounted) {
      setState(() => _date = LedgerRepository.dateOnly(date));
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = ref.read(vaultProvider).session;
      if (session == null || session.closed) {
        throw const AppFailure(
          FailureCode.locked,
          'Unlock your vault to continue.',
        );
      }
      final String id;
      if (widget.journalId == null) {
        id = await session.ledger.recordTransaction(
          kind: _kind,
          accountId: _account!,
          counterAccountId: _counter!,
          amount: Money.parseInr(_amount.text),
          occurredOn: _date,
          description: _description.text,
          operationId: _operation,
        );
      } else {
        id = await session.ledger.correct(
          widget.journalId!,
          kind: _kind,
          accountId: _account!,
          counterAccountId: _counter!,
          amount: Money.parseInr(_amount.text),
          occurredOn: _date,
          description: _description.text,
          reason: _reason.text,
          operationId: _operation,
        );
      }
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
        context.pushReplacement('/transaction/$id');
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

String? positiveAmount(String? value) {
  try {
    if (Money.parseInr(value ?? '').minor <= 0) {
      return 'Enter an amount greater than zero.';
    }
  } on AppFailure catch (e) {
    return e.message;
  }
  return null;
}

extension on Money {
  Money negateIfNegative() => minor < 0 ? negate() : this;
}
