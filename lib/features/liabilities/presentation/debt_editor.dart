import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/localization/vault_strings.dart';
import '../../../app/vault_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/finance/fixed_decimal.dart';
import '../../../shared/widgets/record_fields.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../../finance/data/ledger_repository.dart';
import '../data/debt_repository.dart';
import '../domain/loan_calculator.dart';
import 'debt_pages.dart';

List<LedgerAccount> _cashAccounts(FinanceSnapshot finance) => finance.accounts
    .where(
      (a) =>
          a.kind == 'asset' &&
          ['cash', 'bank'].contains(a.subtype) &&
          a.deletedAtUs == null &&
          !finance.managedAccountIds.contains(a.id),
    )
    .toList();

class DebtEditor extends ConsumerStatefulWidget {
  const DebtEditor({super.key, this.id, this.correctPrincipal = false});
  final String? id;
  final bool correctPrincipal;
  @override
  ConsumerState<DebtEditor> createState() => _DebtEditorState();
}

class _DebtEditorState extends ConsumerState<DebtEditor> {
  final _form = GlobalKey<FormState>();
  final _termsPanel = ExpansibleController();
  final _name = TextEditingController(),
      _counterparty = TextEditingController(),
      _principal = TextEditingController();
  final _rate = TextEditingController(),
      _months = TextEditingController(),
      _emi = TextEditingController();
  final _notes = TextEditingController(), _reason = TextEditingController();
  DebtDirection _direction = DebtDirection.bankLoan;
  InterestMethod _method = InterestMethod.unrecorded;
  String _date = LedgerRepository.dateOnly(DateTime.now());
  String? _firstDue, _due, _cash, _operation;
  bool _funded = false, _saving = false;
  int? _revision;
  Object? _error;

  bool get _creating => widget.id == null;
  bool get _correcting => widget.correctPrincipal;
  String get _title => _creating
      ? 'Add a loan'
      : _correcting
      ? 'Correct opening principal'
      : 'Edit loan terms';

  @override
  void dispose() {
    _termsPanel.dispose();
    for (final controller in [
      _name,
      _counterparty,
      _principal,
      _rate,
      _months,
      _emi,
      _notes,
      _reason,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _prepare(
    DebtContract row,
    FinanceSnapshot finance,
    List<LedgerAccount> cash,
  ) {
    if (_revision != null) {
      return;
    }
    _revision = row.revision;
    _direction = DebtDirection.values.firstWhere(
      (v) => v.code == row.direction,
    );
    _name.text = row.name;
    _counterparty.text = row.counterparty;
    _principal.text = minorInput(row.principalMinor);
    _date = row.startedOn;
    _method = InterestMethod.values.byName(row.interestMethod);
    _rate.text = row.annualRateBps == null
        ? ''
        : FixedDecimal.format(row.annualRateBps!, scale: 2);
    _months.text = row.termMonths?.toString() ?? '';
    _emi.text = row.emiMinor == null ? '' : minorInput(row.emiMinor!);
    _firstDue = row.firstDueOn;
    _due = row.dueOn;
    _notes.text = row.notes;
    if (_correcting) {
      final opening = finance.journals
          .where(
            (j) =>
                j.deletedAtUs == null &&
                finance.journalLinks[j.id]?.aggregateId == row.id &&
                finance.journalLinks[j.id]?.purpose == 'opening',
          )
          .firstOrNull;
      final cashIds = cash.map((a) => a.id).toSet();
      _cash = finance.postings
          .where(
            (p) => p.journalId == opening?.id && cashIds.contains(p.accountId),
          )
          .firstOrNull
          ?.accountId;
      _funded = _cash != null;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr(_title))),
    body: DebtView(
      builder: (rows, finance) {
        final row = rows.contracts.where((r) => r.id == widget.id).firstOrNull;
        final cash = _cashAccounts(finance);
        if (!_creating) {
          if (row == null || row.deletedAtUs != null) {
            return VaultContent(
              children: [Text(context.tr('Loan unavailable for editing.'))],
            );
          }
          _prepare(row, finance, cash);
        }
        final enabled = !_saving;
        return VaultContent(
          maxWidth: 700,
          children: [
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_correcting) ...[
                    Text(
                      row!.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr(
                        'Your original record stays in history. The corrected amount and date must still fit the payments you’ve already saved.',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    RecordField(
                      context.tr('Loan name'),
                      _name,
                      required: true,
                      enabled: enabled,
                    ),
                    if (_creating)
                      RecordChoice<DebtDirection>(
                        context.tr('Who received the money?'),
                        _direction,
                        [
                          for (final value in DebtDirection.values)
                            (value, context.tr(debtDirection(value.code))),
                        ],
                        (v) => setState(() => _direction = v),
                        enabled: enabled,
                      ),
                    RecordField(
                      _direction == DebtDirection.lent
                          ? context.tr('Borrower')
                          : context.tr('Lender'),
                      _counterparty,
                      required: true,
                      enabled: enabled,
                    ),
                  ],
                  if (_creating || _correcting) ...[
                    RecordField(
                      context.tr('Original loan amount'),
                      _principal,
                      money: true,
                      required: true,
                      enabled: enabled,
                    ),
                    RecordDate(
                      context.tr('Date the loan started'),
                      _date,
                      (v) => setState(() => _date = v),
                      enabled: enabled,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _funded,
                      title: Text(
                        context.tr(
                          'Also record money going into or out of an account',
                        ),
                      ),
                      subtitle: Text(
                        context.tr(
                          'Turn this on to show the money movement in the account. Leave it off for an existing loan balance.',
                        ),
                      ),
                      onChanged: enabled
                          ? (v) => setState(() => _funded = v)
                          : null,
                    ),
                    if (_funded)
                      RecordChoice<String>(
                        _direction == DebtDirection.lent
                            ? context.tr('Paid from')
                            : context.tr('Received into'),
                        cash.any((a) => a.id == _cash) ? _cash : null,
                        [for (final a in cash) (a.id, a.name)],
                        (v) => setState(() => _cash = v),
                        enabled: enabled,
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (_correcting)
                    RecordField(
                      context.tr('Reason for correction'),
                      _reason,
                      required: true,
                      enabled: enabled,
                      maxLength: 400,
                      lines: 2,
                    )
                  else
                    ExpansionTile(
                      controller: _termsPanel,
                      maintainState: true,
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        context.tr('Interest and payment dates (optional)'),
                      ),
                      children: [
                        RecordChoice<InterestMethod>(
                          context.tr('Interest method'),
                          _method,
                          [
                            for (final method in InterestMethod.values)
                              (method, context.tr(interestLabel(method))),
                          ],
                          (v) => setState(() => _method = v),
                          enabled: enabled,
                        ),
                        if (_method != InterestMethod.unrecorded)
                          RecordField(
                            context.tr('Interest per year (%)'),
                            _rate,
                            scale: 2,
                            required: true,
                            enabled: enabled,
                            hint: context.tr(
                              'Enter zero for a confirmed interest-free loan.',
                            ),
                          ),
                        RecordField(
                          context.tr('Months to repay (optional)'),
                          _months,
                          scale: 0,
                          enabled: enabled,
                        ),
                        RecordField(
                          context.tr('Agreed monthly payment (optional)'),
                          _emi,
                          money: true,
                          enabled: enabled,
                        ),
                        _optionalDate(
                          context.tr('First instalment due'),
                          _firstDue,
                          (v) => setState(() => _firstDue = v),
                        ),
                        _optionalDate(
                          context.tr('Final due date'),
                          _due,
                          (v) => setState(() => _due = v),
                        ),
                        const SizedBox(height: 18),
                        RecordField(
                          context.tr('Notes (optional)'),
                          _notes,
                          maxLength: 4000,
                          lines: 3,
                          enabled: enabled,
                        ),
                      ],
                    ),
                  if (_error != null) FailureNotice(_error!),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: enabled ? _save : null,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _saving
                          ? context.tr('Saving…')
                          : _correcting
                          ? context.tr('Save the corrected loan amount')
                          : context.tr('Save loan'),
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

  Widget _optionalDate(
    String label,
    String? value,
    ValueChanged<String?> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(
          context.tr("Record {dateType}", {'dateType': label}).toLowerCase(),
        ),
        value: value != null,
        onChanged: _saving ? null : (v) => onChanged(v ? _date : null),
      ),
      if (value != null) RecordDate(label, value, onChanged, enabled: !_saving),
    ],
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      if (!_correcting &&
          (_method != InterestMethod.unrecorded ||
              _months.text.isNotEmpty ||
              _emi.text.isNotEmpty)) {
        _termsPanel.expand();
      }
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final session = ref.read(vaultProvider).session!,
          repo = DebtRepository(session.ledger);
      _operation ??= session.ledger.operationId();
      final terms = DebtTerms(
        method: _method,
        annualRateBps: _method == InterestMethod.unrecorded
            ? null
            : FixedDecimal.parse(_rate.text, scale: 2),
        termMonths: optionalText(_months) == null
            ? null
            : FixedDecimal.parse(_months.text, scale: 0),
        emiMinor: optionalMinor(_emi),
        firstDueOn: _firstDue,
        dueOn: _due,
      );
      final funding = _funded ? _cash : null;
      final String id;
      if (_creating) {
        id = await repo.create(
          DebtDraft(
            name: _name.text,
            direction: _direction,
            counterparty: _counterparty.text,
            principalMinor: optionalMinor(_principal)!,
            startedOn: _date,
            cashAccountId: funding,
            terms: terms,
            notes: _notes.text,
          ),
          operationId: _operation,
        );
      } else if (_correcting) {
        id = await repo.correctPrincipal(
          widget.id!,
          _revision!,
          principalMinor: optionalMinor(_principal)!,
          startedOn: _date,
          cashAccountId: funding,
          reason: _reason.text,
          operationId: _operation,
        );
      } else {
        id = await repo.edit(
          widget.id!,
          _revision!,
          name: _name.text,
          counterparty: _counterparty.text,
          terms: terms,
          notes: _notes.text,
          operationId: _operation,
        );
      }
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
        if (_creating) {
          context.pushReplacement('/loan/$id');
        } else {
          context.pop();
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class RepaymentEditor extends ConsumerStatefulWidget {
  const RepaymentEditor({required this.id, super.key, this.repaymentId});
  final String id;
  final String? repaymentId;
  @override
  ConsumerState<RepaymentEditor> createState() => _RepaymentEditorState();
}

class _RepaymentEditorState extends ConsumerState<RepaymentEditor> {
  final _form = GlobalKey<FormState>();
  final _principal = TextEditingController(),
      _interest = TextEditingController(),
      _notes = TextEditingController(),
      _reason = TextEditingController();
  String _date = LedgerRepository.dateOnly(DateTime.now());
  String? _account, _operation;
  int? _revision;
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    for (final controller in [_principal, _interest, _notes, _reason]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.repaymentId == null
            ? context.tr('Record repayment')
            : context.tr('Correct repayment'),
      ),
    ),
    body: DebtView(
      builder: (debts, finance) {
        final row = debts.contracts.where((r) => r.id == widget.id).firstOrNull;
        final original = debts.repayments
            .where(
              (p) => p.id == widget.repaymentId && p.contractId == widget.id,
            )
            .firstOrNull;
        final journal = finance.journals
            .where((j) => j.id == original?.journalId)
            .firstOrNull;
        if (row == null ||
            row.deletedAtUs != null ||
            (widget.repaymentId != null &&
                (journal == null || journal.deletedAtUs != null))) {
          return VaultContent(
            children: [Text(context.tr('Repayment unavailable for editing.'))],
          );
        }
        final cash = _cashAccounts(finance);
        if (_revision == null) {
          _revision = row.revision;
          if (original != null) {
            _principal.text = minorInput(original.principalMinor);
            _interest.text = minorInput(original.interestMinor);
            _notes.text = original.notes;
            _date = original.paidOn;
            final cashIds = cash.map((a) => a.id).toSet();
            _account = finance.postings
                .where(
                  (p) =>
                      p.journalId == original.journalId &&
                      cashIds.contains(p.accountId),
                )
                .firstOrNull
                ?.accountId;
          }
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
                    row.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      'Enter the principal and interest from the actual payment. Leave either blank when it was zero.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  RecordField(
                    context.tr('Amount paid toward the loan'),
                    _principal,
                    money: true,
                    enabled: !_saving,
                  ),
                  RecordField(
                    context.tr('Interest paid'),
                    _interest,
                    money: true,
                    enabled: !_saving,
                  ),
                  RecordChoice<String>(
                    row.direction == 'lent'
                        ? context.tr('Received into')
                        : context.tr('Paid from'),
                    cash.any((a) => a.id == _account) ? _account : null,
                    [for (final a in cash) (a.id, a.name)],
                    (v) => setState(() => _account = v),
                    enabled: !_saving,
                  ),
                  if (cash.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Text(
                        context.tr(
                          'Add a cash or bank account to record a repayment.',
                        ),
                      ),
                    ),
                  RecordDate(
                    context.tr('Payment date'),
                    _date,
                    (v) => setState(() => _date = v),
                    enabled: !_saving,
                  ),
                  RecordField(
                    context.tr('Notes (optional)'),
                    _notes,
                    lines: 3,
                    maxLength: 4000,
                    enabled: !_saving,
                  ),
                  if (original != null)
                    RecordField(
                      context.tr('Reason for correction'),
                      _reason,
                      required: true,
                      maxLength: 400,
                      enabled: !_saving,
                    ),
                  if (_error != null) FailureNotice(_error!),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _saving
                          ? context.tr('Saving…')
                          : original == null
                          ? context.tr('Save repayment')
                          : context.tr('Save repayment correction'),
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
      _saving = true;
      _error = null;
    });
    try {
      final session = ref.read(vaultProvider).session!,
          repo = DebtRepository(session.ledger);
      _operation ??= session.ledger.operationId();
      final draft = RepaymentDraft(
        principalMinor: optionalMinor(_principal) ?? 0,
        interestMinor: optionalMinor(_interest) ?? 0,
        accountId: _account!,
        paidOn: _date,
        notes: _notes.text,
      );
      if (widget.repaymentId == null) {
        await repo.repay(widget.id, _revision!, draft, operationId: _operation);
      } else {
        await repo.correctRepayment(
          widget.id,
          _revision!,
          widget.repaymentId!,
          _reason.text,
          draft,
          operationId: _operation,
        );
      }
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
