import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'account_labels.dart';
import '../../../core/localization/vault_strings.dart';
import '../../../app/vault_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/finance/formatters.dart';
import '../../../core/finance/money.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../data/ledger_repository.dart';

String _accountLabel(LedgerAccount account) => switch (account.kind) {
  'income' => 'Money received',
  'expense' => 'Money spent',
  'liability' => 'Money owed',
  _ => _subtypeLabel(account.subtype),
};

String _subtypeLabel(String subtype) => switch (subtype) {
  'cash' => 'Cash',
  'bank' => 'Bank account',
  'deposit' => 'Bank deposit',
  'investment' => 'Investment',
  'loan' => 'Loan',
  'borrowed' => 'Borrowed money',
  'category' => 'Category',
  _ => 'Other account',
};

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  String _group = 'Balances';
  @override
  Widget build(BuildContext context) => FinanceView(
    builder: (data) {
      final balances = data.balances();
      final accounts = data.accounts
          .where(
            (a) => _group == 'Archived'
                ? a.deletedAtUs != null
                : a.deletedAtUs == null &&
                      (_group == 'Balances'
                          ? ['asset', 'liability'].contains(a.kind)
                          : ['income', 'expense'].contains(a.kind)),
          )
          .toList();
      return VaultContent(
        children: [
          SectionHeading(
            context.tr('Your accounts'),
            action: FilledButton.icon(
              onPressed: () => context.push('/account/new'),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Add account')),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final group in ['Balances', 'Categories', 'Archived'])
                ChoiceChip(
                  label: Text(context.tr(group)),
                  selected: _group == group,
                  onSelected: (_) => setState(() => _group = group),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (accounts.isEmpty)
            EmptyNotice(
              icon: Icons.account_balance_outlined,
              title: _group == 'Archived'
                  ? context.tr('No archived accounts')
                  : context.tr('No accounts here yet'),
              message: _group == 'Archived'
                  ? context.tr('Archived accounts keep their complete history.')
                  : context.tr(
                      'Add the cash or bank account you use. Starting with zero is fine.',
                    ),
            ),
          for (final a in accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card.outlined(
                child: ListTile(
                  leading: Icon(
                    a.kind == 'asset'
                        ? Icons.account_balance_wallet_outlined
                        : a.kind == 'liability'
                        ? Icons.request_quote_outlined
                        : Icons.category_outlined,
                  ),
                  title: Text(accountDisplayName(context, a)),
                  subtitle: Text(
                    '${context.tr(_accountLabel(a))}\n${formatInr(a.kind == 'liability' || a.kind == 'income' ? -(balances[a.id] ?? BigInt.zero) : balances[a.id] ?? BigInt.zero)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/account/${a.id}'),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class AccountEditor extends ConsumerStatefulWidget {
  const AccountEditor({
    super.key,
    this.initialKind = 'asset',
    this.accountId,
    this.initialSubtype,
  });
  final String initialKind;
  final String? accountId, initialSubtype;
  @override
  ConsumerState<AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends ConsumerState<AccountEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _opening = TextEditingController();
  late AccountKind _kind;
  String _subtype = 'cash';
  String _openedOn = LedgerRepository.dateOnly(DateTime.now());
  bool _prepared = false, _busy = false;
  Object? _error;
  int? _revision;
  @override
  void initState() {
    super.initState();
    _kind =
        AccountKind.values
            .where(
              (k) => k.name == widget.initialKind && k != AccountKind.equity,
            )
            .firstOrNull ??
        AccountKind.asset;
    final available = _subtypes(_kind);
    final requested = widget.initialSubtype;
    _subtype = requested != null && available.contains(requested)
        ? requested
        : available.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  static List<String> _subtypes(AccountKind kind) => switch (kind) {
    AccountKind.asset => ['cash', 'bank', 'deposit', 'investment', 'other'],
    AccountKind.liability => ['loan', 'borrowed', 'other'],
    _ => ['category'],
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.accountId == null
            ? context.tr('Add account or category')
            : context.tr('Rename account'),
      ),
    ),
    body: FinanceView(
      builder: (data) {
        if (widget.accountId != null && !_prepared) {
          final row = data.accounts
              .where((a) => a.id == widget.accountId)
              .firstOrNull;
          if (row == null ||
              row.systemAccount ||
              row.deletedAtUs != null ||
              data.managedAccountIds.contains(row.id)) {
            return VaultContent(
              children: [
                Text(context.tr('This account is unavailable for editing.')),
              ],
            );
          }
          _name.text = row.name;
          _kind = AccountKind.values.byName(row.kind);
          _subtype = row.subtype;
          _revision = row.revision;
          _prepared = true;
        }
        return VaultContent(
          maxWidth: 680,
          children: [
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: context.tr('Name')),
                    validator: context.localizedValidator(requiredText),
                  ),
                  const SizedBox(height: 20),
                  if (widget.accountId == null) ...[
                    DropdownButtonFormField<AccountKind>(
                      initialValue: _kind,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Kind of account'),
                      ),
                      items: [
                        for (final kind in AccountKind.values.where(
                          (k) => k != AccountKind.equity,
                        ))
                          DropdownMenuItem(
                            value: kind,
                            child: Text(switch (kind) {
                              AccountKind.asset => context.tr(
                                'Cash, bank or property',
                              ),
                              AccountKind.liability => context.tr('Money owed'),
                              AccountKind.income => context.tr(
                                'Kind of money received',
                              ),
                              _ => context.tr('Kind of spending'),
                            }),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _kind = value!;
                              _subtype = _subtypes(_kind).first;
                            }),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_kind),
                      initialValue: _subtype,
                      decoration: InputDecoration(
                        labelText: context.tr('Category'),
                      ),
                      items: [
                        for (final subtype in _subtypes(_kind))
                          DropdownMenuItem(
                            value: subtype,
                            child: Text(context.tr(_subtypeLabel(subtype))),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _subtype = value!),
                    ),
                    if (_kind == AccountKind.asset ||
                        _kind == AccountKind.liability) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _opening,
                        enabled: !_busy,
                        maxLength: 32,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.tr('Starting amount (optional)'),
                          prefixText: '₹ ',
                          helperText: context.tr(
                            'Enter what was there when you started your records. Leave empty to start at zero.',
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return null;
                          }
                          try {
                            Money.parseInr(v);
                          } on AppFailure catch (e) {
                            return VaultStrings.of(context).failure(e);
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.parse(_openedOn),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(2200, 12, 31),
                                );
                                if (date != null && mounted) {
                                  setState(
                                    () => _openedOn = LedgerRepository.dateOnly(
                                      date,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          context.tr("Opening date: {date}", {
                            'date': _openedOn,
                          }),
                        ),
                      ),
                    ],
                  ],
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
                          : context.tr('Save account'),
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
      final account = widget.accountId == null
          ? await session.ledger.createAccount(
              name: _name.text,
              kind: _kind,
              subtype: _subtype,
              openedOn: _openedOn,
              openingBalance:
                  _opening.text.trim().isEmpty ||
                      ![
                        AccountKind.asset,
                        AccountKind.liability,
                      ].contains(_kind)
                  ? null
                  : Money.parseInr(_opening.text),
            )
          : await session.ledger.renameAccount(
              widget.accountId!,
              _name.text,
              _revision!,
            );
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
        context.pushReplacement('/account/${account.id}');
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

class AccountDetailPage extends ConsumerStatefulWidget {
  const AccountDetailPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {
  bool _busy = false;
  Object? _error;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Account details'))),
    body: FinanceView(
      builder: (data) {
        final a = data.accounts.where((a) => a.id == widget.id).firstOrNull;
        if (a == null) {
          return VaultContent(
            children: [Text(context.tr('Account unavailable.'))],
          );
        }
        final balance = data.balances()[a.id] ?? BigInt.zero;
        final managed = data.managedAccountIds.contains(a.id);
        final journalIds = data.postings
            .where((p) => p.accountId == a.id)
            .map((p) => p.journalId)
            .toSet();
        final journals = data.journals
            .where((j) => journalIds.contains(j.id))
            .toList();
        return VaultContent(
          maxWidth: 800,
          children: [
            MetricCard(
              title: accountDisplayName(context, a),
              value: formatInr(
                ['liability', 'income'].contains(a.kind) ? -balance : balance,
              ),
              icon: Icons.account_balance_outlined,
              detail:
                  '${context.tr(_accountLabel(a))}${a.deletedAtUs != null ? context.tr(' · Archived') : ''}',
              emphasis: true,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!managed && !a.systemAccount && a.deletedAtUs == null)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/account/${a.id}/edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(context.tr('Rename')),
                  ),
                if (a.kind == 'asset' &&
                    ['cash', 'bank'].contains(a.subtype) &&
                    a.deletedAtUs == null)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/account/${a.id}/reconcile'),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(context.tr('Check the amount')),
                  ),
                if (!managed && !a.systemAccount)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _archive(a),
                    icon: Icon(
                      a.deletedAtUs == null
                          ? Icons.archive_outlined
                          : Icons.unarchive_outlined,
                    ),
                    label: Text(
                      a.deletedAtUs == null
                          ? context.tr('Archive')
                          : context.tr('Restore account'),
                    ),
                  ),
              ],
            ),
            if (managed)
              Text(
                context.tr(
                  'To change this amount, open the related item, loan or business.',
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              FailureNotice(_error!),
            ],
            const SizedBox(height: 28),
            SectionHeading(context.tr('Account history')),
            if (journals.isEmpty)
              Text(context.tr('No entries in this account yet.')),
            for (final j in journals)
              Card.outlined(
                child: ListTile(
                  title: Text(j.description),
                  subtitle: Text(
                    '${j.occurredOn} · ${j.kind}${j.deletedAtUs != null ? context.tr(' · Reversed') : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/transaction/${j.id}'),
                ),
              ),
          ],
        );
      },
    ),
  );
  Future<void> _archive(LedgerAccount a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          a.deletedAtUs == null
              ? context.tr('Archive this account?')
              : context.tr('Restore this account?'),
        ),
        content: Text(
          a.deletedAtUs == null
              ? context.tr(
                  'All entries and audit history stay intact. Accounts with a balance must be reconciled first.',
                )
              : context.tr(
                  'The account becomes available for new transactions.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Continue')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ledger = ref.read(vaultProvider).session!.ledger;
      if (a.deletedAtUs == null) {
        await ledger.archiveAccount(a.id, a.revision);
      } else {
        await ledger.restoreAccount(a.id, a.revision);
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
