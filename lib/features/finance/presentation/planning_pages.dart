import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'account_labels.dart';
import '../../../core/localization/vault_strings.dart';
import '../../../app/vault_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/finance/formatters.dart';
import '../../../core/finance/money.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../data/ledger_repository.dart';

String monthOf(DateTime date) =>
    LedgerRepository.dateOnly(date).substring(0, 7);

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});
  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  Widget build(BuildContext context) => FinanceView(
    builder: (data) {
      final month = monthOf(_month),
          end = LedgerRepository.dateOnly(
            DateTime(_month.year, _month.month + 1, 0),
          );
      final budgets = data.budgets.where((b) => b.month == month).toList();
      final spent = data.balances(from: '$month-01', through: end);
      final target = budgets.fold(
        BigInt.zero,
        (total, b) => total + BigInt.from(b.amountMinor),
      );
      final expenses = data.total(
        AccountKind.expense,
        from: '$month-01',
        through: end,
      );
      return VaultContent(
        children: [
          SectionHeading(
            context.tr('Plan for this month'),
            action: FilledButton.icon(
              onPressed: () => context.push('/budget/new?month=$month'),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Plan spending')),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: context.tr('Previous month'),
                onPressed: _month.year <= 1900
                    ? null
                    : () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  month,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: context.tr('Next month'),
                onPressed: _month.year >= 2200
                    ? null
                    : () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ResponsiveCards(
            children: [
              MetricCard(
                title: context.tr('Planned spending'),
                value: formatInr(target),
                icon: Icons.savings_outlined,
              ),
              MetricCard(
                title: context.tr('Money spent this month'),
                value: formatInr(expenses),
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (budgets.isEmpty)
            EmptyNotice(
              icon: Icons.savings_outlined,
              title: context.tr('No spending plans yet'),
              message: context.tr(
                'Choose what you’re planning to spend on and set an amount for this month.',
              ),
            ),
          for (final budget in budgets)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card.outlined(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.push('/budget/${budget.id}/edit'),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Builder(
                      builder: (context) {
                        final actual = spent[budget.accountId] ?? BigInt.zero,
                            limit = BigInt.from(budget.amountMinor);
                        final progress = limit == BigInt.zero
                            ? (actual > BigInt.zero ? 1.0 : 0.0)
                            : chartRatio(actual, limit);
                        final account = data.accounts
                            .where((a) => a.id == budget.accountId)
                            .firstOrNull;
                        final name = account == null
                            ? context.tr('Expense category')
                            : accountDisplayName(context, account);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr("{used} of {total}", {
                                'used': formatInr(actual),
                                'total': formatInr(limit),
                              }),
                            ),
                            const SizedBox(height: 14),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(6),
                              color: actual > limit
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              actual > limit
                                  ? context.tr("{extra} above budget", {
                                      'extra': formatInr(actual - limit),
                                    })
                                  : context.tr("{amount} remaining", {
                                      'amount': formatInr(limit - actual),
                                    }),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class BudgetEditor extends ConsumerStatefulWidget {
  const BudgetEditor({super.key, this.id, this.month});
  final String? id, month;
  @override
  ConsumerState<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<BudgetEditor> {
  final _form = GlobalKey<FormState>(),
      _amount = TextEditingController(),
      _month = TextEditingController();
  String? _category;
  int _revision = 0;
  bool _prepared = false, _busy = false;
  Object? _error;
  @override
  void initState() {
    super.initState();
    _month.text = widget.month ?? monthOf(DateTime.now());
  }

  @override
  void dispose() {
    _amount.dispose();
    _month.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.id == null
            ? context.tr('Plan monthly spending')
            : context.tr('Edit spending plan'),
      ),
    ),
    body: FinanceView(
      builder: (data) {
        if (widget.id != null && !_prepared) {
          final b = data.budgets.where((b) => b.id == widget.id).firstOrNull;
          if (b == null) {
            return VaultContent(
              children: [Text(context.tr('This budget is unavailable.'))],
            );
          }
          _month.text = b.month;
          _category = b.accountId;
          _amount.text = Money.fromMinor(b.amountMinor)
              .format(symbol: false, grouping: false);
          _revision = b.revision;
          _prepared = true;
        }
        final categories = data.accounts
            .where(
              (a) =>
                  a.kind == 'expense' &&
                  (a.deletedAtUs == null || a.id == _category),
            )
            .toList();
        return VaultContent(
          maxWidth: 680,
          children: [
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Expense category'),
                    ),
                    items: [
                      for (final a in categories)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            accountDisplayName(context, a),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _busy || widget.id != null
                        ? null
                        : (v) => setState(() => _category = v),
                    validator: (v) =>
                        v == null ? context.tr('Choose a category.') : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _month,
                    enabled: !_busy && widget.id == null,
                    maxLength: 7,
                    decoration: InputDecoration(
                      labelText: context.tr('Month (YYYY-MM)'),
                    ),
                    validator: (v) {
                      try {
                        LedgerRepository.validateDate('${v ?? ''}-01');
                      } on AppFailure catch (e) {
                        return VaultStrings.of(context).failure(e);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    enabled: !_busy,
                    maxLength: 32,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('Monthly limit'),
                      prefixText: '₹ ',
                    ),
                    validator: (v) {
                      try {
                        if (Money.parseInr(v ?? '').minor < 0) {
                          return context.tr('Use zero or a positive amount.');
                        }
                      } on AppFailure catch (e) {
                        return VaultStrings.of(context).failure(e);
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    FailureNotice(_error!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _busy
                          ? context.tr('Saving…')
                          : context.tr('Save spending plan'),
                    ),
                  ),
                  if (widget.id != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _remove,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.tr('Remove budget')),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    await _run(
      () => ref
          .read(vaultProvider)
          .session!
          .ledger
          .setBudget(
            accountId: _category!,
            month: _month.text,
            amount: Money.parseInr(_amount.text),
            expectedRevision: _revision,
          ),
    );
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove this budget?')),
        content: Text(
          context.tr(
            'Your expenses and the budget audit history are preserved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Remove')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () => ref
            .read(vaultProvider)
            .session!
            .ledger
            .deleteBudget(widget.id!, _revision),
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        savedNotice(context);
        context.go('/planning');
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

class ReconciliationEditor extends ConsumerStatefulWidget {
  const ReconciliationEditor({required this.accountId, super.key});
  final String accountId;
  @override
  ConsumerState<ReconciliationEditor> createState() =>
      _ReconciliationEditorState();
}

class _ReconciliationEditorState extends ConsumerState<ReconciliationEditor> {
  final _form = GlobalKey<FormState>(),
      _statement = TextEditingController(),
      _notes = TextEditingController();
  String _date = LedgerRepository.dateOnly(DateTime.now());
  bool _adjust = false, _busy = false;
  Object? _error;
  @override
  void dispose() {
    _statement.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Check that the amounts match'))),
    body: FinanceView(
      builder: (data) {
        final a = data.accounts
            .where((a) => a.id == widget.accountId)
            .firstOrNull;
        if (a == null) {
          return VaultContent(
            children: [Text(context.tr('Account unavailable.'))],
          );
        }
        final balance = data.balances(through: _date)[a.id] ?? BigInt.zero;
        return VaultContent(
          maxWidth: 680,
          children: [
            Text(a.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              context.tr("Amount in FamilyVault on {date}: {amount}", {
                'date': _date,
                'amount': formatInr(balance),
              }),
            ),
            const SizedBox(height: 24),
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.parse(_date),
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2200, 12, 31),
                            );
                            if (date != null && mounted) {
                              setState(
                                () => _date = LedgerRepository.dateOnly(date),
                              );
                            }
                          },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      context.tr("Statement date: {date}", {'date': _date}),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _statement,
                    enabled: !_busy,
                    maxLength: 32,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('Balance on your statement'),
                      prefixText: '₹ ',
                    ),
                    validator: (v) {
                      try {
                        Money.parseInr(v ?? '');
                      } on AppFailure catch (e) {
                        return VaultStrings.of(context).failure(e);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _notes,
                    enabled: !_busy,
                    maxLength: 400,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: context.tr('Notes / reason'),
                    ),
                    validator: context.localizedValidator(requiredText),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _adjust,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _adjust = v),
                    title: Text(context.tr('Save a change for the difference')),
                    subtitle: Text(
                      context.tr(
                        'Off by default. Adds a separate balanced entry against reconciliation equity; it never edits past transactions.',
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    FailureNotice(_error!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(
                      _busy
                          ? context.tr('Saving…')
                          : context.tr('Save reconciliation'),
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
  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = ref.read(vaultProvider).session!;
      await session.ledger.reconcile(
        accountId: widget.accountId,
        statementDate: _date,
        statementBalance: Money.parseInr(_statement.text),
        notes: _notes.text,
        postAdjustment: _adjust,
      );
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
        context.go('/account/${widget.accountId}');
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
