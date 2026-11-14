import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/vault_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/finance/formatters.dart';
import '../../../core/finance/money.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../data/ledger_repository.dart';

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
            'Accounts & categories',
            action: FilledButton.icon(
              onPressed: () => context.push('/account/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add account'),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final group in ['Balances', 'Categories', 'Archived'])
                ChoiceChip(
                  label: Text(group),
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
                  ? 'No archived accounts'
                  : 'Your accounts start here',
              message: _group == 'Archived'
                  ? 'Archived accounts keep their complete history.'
                  : 'Add a cash or bank account. Opening balances are optional and recorded in your ledger.',
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
                  title: Text(a.name),
                  subtitle: Text(
                    '${a.kind} · ${a.subtype.replaceAll('_', ' ')}\n${formatInr(a.kind == 'liability' || a.kind == 'income' ? -(balances[a.id] ?? BigInt.zero) : balances[a.id] ?? BigInt.zero)}',
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
  const AccountEditor({super.key, this.initialKind = 'asset', this.accountId});
  final String initialKind;
  final String? accountId;
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
    _subtype = _subtypes(_kind).first;
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
        widget.accountId == null ? 'Add account or category' : 'Rename account',
      ),
    ),
    body: FinanceView(
      builder: (data) {
        if (widget.accountId != null && !_prepared) {
          final row = data.accounts
              .where((a) => a.id == widget.accountId)
              .firstOrNull;
          if (row == null || row.systemAccount || row.deletedAtUs != null) {
            return const VaultContent(
              children: [Text('This account is unavailable for editing.')],
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
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: requiredText,
                  ),
                  const SizedBox(height: 20),
                  if (widget.accountId == null) ...[
                    DropdownButtonFormField<AccountKind>(
                      initialValue: _kind,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Account type',
                      ),
                      items: [
                        for (final kind in AccountKind.values.where(
                          (k) => k != AccountKind.equity,
                        ))
                          DropdownMenuItem(
                            value: kind,
                            child: Text(switch (kind) {
                              AccountKind.asset => 'Asset',
                              AccountKind.liability => 'Liability',
                              AccountKind.income => 'Income category',
                              _ => 'Expense category',
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
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final subtype in _subtypes(_kind))
                          DropdownMenuItem(
                            value: subtype,
                            child: Text(
                              subtype[0].toUpperCase() + subtype.substring(1),
                            ),
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
                        decoration: const InputDecoration(
                          labelText: 'Opening balance (optional)',
                          prefixText: '₹ ',
                          helperText: 'Creates a dated opening entry. Leave empty to start at zero.',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return null;
                          }
                          try {
                            Money.parseInr(v);
                          } on AppFailure catch (e) {
                            return e.message;
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
                        label: Text('Opening date: $_openedOn'),
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
                    label: Text(_busy ? 'Saving…' : 'Save account'),
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
    appBar: AppBar(title: const Text('Account details')),
    body: FinanceView(
      builder: (data) {
        final a = data.accounts.where((a) => a.id == widget.id).firstOrNull;
        if (a == null) {
          return const VaultContent(children: [Text('Account unavailable.')]);
        }
        final balance = data.balances()[a.id] ?? BigInt.zero;
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
              title: a.name,
              value: formatInr(
                ['liability', 'income'].contains(a.kind) ? -balance : balance,
              ),
              icon: Icons.account_balance_outlined,
              detail:
                  '${a.kind} · ${a.subtype} · INR${a.deletedAtUs != null ? ' · Archived' : ''}',
              emphasis: true,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!a.systemAccount && a.deletedAtUs == null)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/account/${a.id}/edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Rename'),
                  ),
                if (a.kind == 'asset' &&
                    ['cash', 'bank'].contains(a.subtype) &&
                    a.deletedAtUs == null)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/account/${a.id}/reconcile'),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Reconcile'),
                  ),
                if (!a.systemAccount)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _archive(a),
                    icon: Icon(
                      a.deletedAtUs == null
                          ? Icons.archive_outlined
                          : Icons.unarchive_outlined,
                    ),
                    label: Text(
                      a.deletedAtUs == null ? 'Archive' : 'Restore account',
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              FailureNotice(_error!),
            ],
            const SizedBox(height: 28),
            const SectionHeading('Account history'),
            if (journals.isEmpty) const Text('No entries in this account yet.'),
            for (final j in journals)
              Card.outlined(
                child: ListTile(
                  title: Text(j.description),
                  subtitle: Text(
                    '${j.occurredOn} · ${j.kind}${j.deletedAtUs != null ? ' · Reversed' : ''}',
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
              ? 'Archive this account?'
              : 'Restore this account?',
        ),
        content: Text(
          a.deletedAtUs == null
              ? 'All entries and audit history stay intact. Accounts with a balance must be reconciled first.'
              : 'The account becomes available for new transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
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
