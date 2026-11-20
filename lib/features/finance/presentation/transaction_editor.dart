import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import 'account_labels.dart';
import '../../../app/vault_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/finance/money.dart';
import '../../../core/localization/vault_strings.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../data/ledger_repository.dart';

class TransactionEditor extends ConsumerStatefulWidget {
  const TransactionEditor({
    super.key,
    this.journalId,
    this.initialKind,
    this.guided = false,
  });
  final String? journalId;
  final EntryKind? initialKind;
  final bool guided;
  @override
  ConsumerState<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends ConsumerState<TransactionEditor> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(),
      _description = TextEditingController(),
      _reason = TextEditingController();
  final _operation = const Uuid().v4();
  late EntryKind _kind;
  String? _account, _counter;
  String _date = LedgerRepository.dateOnly(DateTime.now());
  bool _busy = false, _prepared = false;
  Object? _error;
  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind ?? EntryKind.expense;
  }

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
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.text(
            widget.journalId == null
                ? _label(_kind, action: true)
                : 'editRecord',
          ),
        ),
      ),
      body: FinanceView(
        builder: (data) {
          _prepare(data);
          final originals = data.journals.where(
            (j) => j.id == widget.journalId,
          );
          if (widget.journalId != null &&
              (originals.isEmpty ||
                  data.journalLinks.containsKey(widget.journalId) ||
                  originals.single.deletedAtUs != null ||
                  ![
                    'income',
                    'expense',
                    'transfer',
                  ].contains(originals.single.kind))) {
            return VaultContent(
              children: [
                EmptyNotice(
                  icon: Icons.history,
                  title: context.tr('This record can’t be corrected here'),
                  message: context.tr(
                    'Open the latest record or see the earlier changes.',
                  ),
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
          if (!assets.any((a) => a.id == _account)) {
            _account = assets.length == 1 ? assets.single.id : null;
          }
          final counters = data.accounts
              .where(
                (a) =>
                    a.kind == counterKind &&
                    a.deletedAtUs == null &&
                    !data.managedAccountIds.contains(a.id) &&
                    a.id != _account,
              )
              .toList();
          if (!counters.any((a) => a.id == _counter)) {
            _counter = null;
          }
          final needsAccount =
              assets.isEmpty ||
              (_kind == EntryKind.transfer && assets.length < 2);
          if (needsAccount) {
            return VaultContent(
              children: [
                EmptyNotice(
                  icon: Icons.account_balance_outlined,
                  title: assets.isEmpty
                      ? strings.text('noAccount')
                      : strings.text('twoAccounts'),
                  message: assets.isEmpty
                      ? strings.text('firstAccountHelp')
                      : strings.text('moveExplain'),
                  action: FilledButton(
                    onPressed: () => context.push('/account/new'),
                    child: Text(strings.text('addAccount')),
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
                      Text(strings.text('correctionExplain')),
                      const SizedBox(height: 12),
                    ],
                    if (widget.guided || _kind == EntryKind.transfer) ...[
                      Card.filled(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            strings.text(switch (_kind) {
                              EntryKind.income => 'moneyHelpIn',
                              EntryKind.expense => 'moneyHelpOut',
                              _ => 'moveExplain',
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.initialKind == null)
                      DropdownButtonFormField<EntryKind>(
                        initialValue: _kind,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: strings.text('recordType'),
                        ),
                        items: [
                          for (final type in [
                            EntryKind.income,
                            EntryKind.expense,
                            EntryKind.transfer,
                          ])
                            DropdownMenuItem(
                              value: type,
                              child: Text(strings.text(_label(type))),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                _kind = value!;
                                _counter = null;
                              }),
                      ),
                    if (widget.initialKind == null) const SizedBox(height: 12),
                    TextFormField(
                      controller: _amount,
                      enabled: !_busy,
                      maxLength: 32,
                      buildCounter: (
                        _, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) => null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: Theme.of(context).textTheme.headlineMedium,
                      decoration: InputDecoration(
                        labelText: strings.text('recordAmount'),
                        prefixText: '₹ ',
                        hintText: '0.00',
                      ),
                      validator: context.localizedValidator(positiveAmount),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('source-$_account'),
                      initialValue: _account,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: strings.text(switch (_kind) {
                          EntryKind.income => 'receivedInto',
                          EntryKind.transfer => 'moveFrom',
                          _ => 'paidFrom',
                        }),
                      ),
                      items: [
                        for (final a in assets)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              accountDisplayName(context, a),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                      validator: (v) =>
                          v == null ? strings.text('chooseAccount') : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('counter-${_kind.name}-$_counter'),
                      initialValue: _counter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: strings.text(switch (_kind) {
                          EntryKind.transfer => 'moveTo',
                          EntryKind.income => 'receivedReason',
                          _ => 'spentReason',
                        }),
                      ),
                      items: [
                        for (final a in counters)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              accountDisplayName(context, a),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _counter = value),
                      validator: (v) => v == null
                          ? strings.text(
                              _kind == EntryKind.transfer
                                  ? 'chooseAnother'
                                  : 'chooseCategory',
                            )
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.push(
                                '/account/new?kind=$counterKind',
                              ),
                        child: Text(
                          strings.text(
                            _kind == EntryKind.transfer
                                ? 'addAccount'
                                : 'addCategory',
                          ),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _chooseDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        '${strings.text('recordDate')} · ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(_date))}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      enabled: !_busy,
                      maxLength: 500,
                      maxLines: 2,
                      buildCounter: (
                        _, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) => null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: strings.text('optionalNote'),
                      ),
                    ),
                    if (widget.journalId != null) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _reason,
                        enabled: !_busy,
                        maxLength: 400,
                        decoration: InputDecoration(
                          labelText: strings.text('correctedReason'),
                        ),
                        validator: context.localizedValidator(requiredText),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      FailureNotice(_error!),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _save(
                              counters
                                  .where((account) => account.id == _counter)
                                  .firstOrNull
                                  ?.name,
                            ),
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _busy
                            ? strings.text('saving')
                            : strings.text(
                                widget.journalId == null
                                    ? 'saveRecord'
                                    : 'saveCorrection',
                              ),
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
  }

  static String _label(EntryKind kind, {bool action = false}) => switch (kind) {
    EntryKind.income => action ? 'addIncome' : 'income',
    EntryKind.expense => action ? 'addExpense' : 'expense',
    _ => 'transfer',
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

  Future<void> _save(String? selectedName) async {
    if (_busy || !_form.currentState!.validate()) {
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
      final note = _description.text.trim();
      final description = note.isNotEmpty
          ? note
          : _kind == EntryKind.transfer
          ? VaultStrings.of(context).text('transfer')
          : selectedName!;
      final String id;
      if (widget.journalId == null) {
        id = await session.ledger.recordTransaction(
          kind: _kind,
          accountId: _account!,
          counterAccountId: _counter!,
          amount: Money.parseInr(_amount.text),
          occurredOn: _date,
          description: description,
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
          description: description,
          reason: _reason.text,
          operationId: _operation,
        );
      }
      if (mounted) {
        savedNotice(
          context,
          cloud: session.identity.isCloud,
          message: VaultStrings.of(context).text('recordSaved'),
        );
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
