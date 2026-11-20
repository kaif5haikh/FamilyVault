import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/localization/vault_strings.dart';
import '../../../app/vault_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/finance/fixed_decimal.dart';
import '../../../core/finance/formatters.dart';
import '../../../core/finance/money.dart';
import '../../../shared/widgets/record_audit.dart';
import '../../../shared/widgets/record_fields.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../../finance/data/ledger_repository.dart';
import '../data/debt_repository.dart';
import '../domain/loan_calculator.dart';

final _debtsProvider = StreamProvider.autoDispose<DebtSnapshot>((ref) {
  final session = ref.watch(vaultProvider).session;
  if (session == null || session.closed) {
    return const Stream.empty();
  }
  return DebtRepository(session.ledger).watch();
});

class DebtView extends ConsumerWidget {
  const DebtView({required this.builder, super.key});
  final Widget Function(DebtSnapshot, FinanceSnapshot) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_debtsProvider)
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => VaultContent(
          children: [
            FailureNotice(error),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(_debtsProvider),
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('Try again')),
            ),
          ],
        ),
        data: (debts) =>
            FinanceView(builder: (finance) => builder(debts, finance)),
      );
}

String debtDirection(String direction) => switch (direction) {
  'bank_loan' => 'Bank loan',
  'lent' => 'Money lent',
  _ => 'Money borrowed',
};

String interestLabel(InterestMethod method) => switch (method) {
  InterestMethod.unrecorded => 'Unrecorded',
  InterestMethod.simpleActual365 => 'Simple interest based on days',
  InterestMethod.flatMonthly => 'Flat monthly interest',
  InterestMethod.reducingMonthly => 'Interest on the amount left',
};

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});
  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  bool _archived = false;
  @override
  Widget build(BuildContext context) => DebtView(
    builder: (debts, finance) {
      final balances = finance.balances();
      BigInt amount(DebtContract row) => DebtRepository.outstanding(
        row,
        balances[row.accountId] ?? BigInt.zero,
      );
      final borrowed = debts.contracts
          .where((row) => row.direction != 'lent')
          .fold(BigInt.zero, (sum, row) => sum + amount(row));
      final lent = debts.contracts
          .where((row) => row.direction == 'lent')
          .fold(BigInt.zero, (sum, row) => sum + amount(row));
      final rows = debts.contracts.where(
        (row) => (row.deletedAtUs != null) == _archived,
      );
      return VaultContent(
        children: [
          SectionHeading(
            context.tr('Loans and money lent'),
            action: FilledButton.icon(
              onPressed: () => context.push('/loan/new'),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Add loan')),
            ),
          ),
          Card.filled(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.north_east),
                    title: Text(context.tr('Loan amounts we still owe')),
                    subtitle: Text(
                      formatInr(borrowed),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.south_west),
                    title: Text(context.tr('Loan amounts owed to us')),
                    subtitle: Text(
                      formatInr(lent),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            children: [
              for (final archived in [false, true])
                ChoiceChip(
                  label: Text(
                    archived ? context.tr('Archived') : context.tr('Current'),
                  ),
                  selected: _archived == archived,
                  onSelected: (_) => setState(() => _archived = archived),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            EmptyNotice(
              icon: Icons.request_quote_outlined,
              title: _archived
                  ? context.tr('No archived loans')
                  : context.tr('No loans recorded yet'),
              message: _archived
                  ? context.tr(
                      'Settled loans can be archived from their details.',
                    )
                  : context.tr(
                      'Record a bank loan, money you borrowed or money you lent to someone.',
                    ),
            ),
          for (final row in rows)
            Card.outlined(
              child: ListTile(
                leading: Icon(
                  row.direction == 'lent'
                      ? Icons.call_received
                      : Icons.call_made,
                ),
                title: Text(row.name),
                subtitle: Text(
                  context.tr("{kind} · {person}\n{amount} left to pay", {
                    'kind': context.tr(debtDirection(row.direction)),
                    'person': row.counterparty,
                    'amount': formatInr(amount(row)),
                  }),
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/loan/${row.id}'),
              ),
            ),
        ],
      );
    },
  );
}

class DebtDetailPage extends ConsumerStatefulWidget {
  const DebtDetailPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<DebtDetailPage> createState() => _DebtDetailPageState();
}

class _DebtDetailPageState extends ConsumerState<DebtDetailPage> {
  Object? _error;
  bool _busy = false;

  Future<void> _change(Future<void> Function(DebtRepository) action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = ref.read(vaultProvider).session!;
      await action(DebtRepository(session.ledger));
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
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

  Future<void> _reverse(DebtContract loan, DebtRepayment repayment) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => ReasonDialog(
        title: context.tr('Reverse this repayment?'),
        message: context.tr(
          'The outstanding balance will reflect the reversal. The original repayment stays in history.',
        ),
        confirmLabel: context.tr('Undo payment'),
      ),
    );
    if (reason == null || !mounted) {
      return;
    }
    await _change(
      (repo) =>
          repo.reverseRepayment(loan.id, loan.revision, repayment.id, reason),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Loan details'))),
    body: DebtView(
      builder: (debts, finance) {
        final loan = debts.contracts
            .where((row) => row.id == widget.id)
            .firstOrNull;
        if (loan == null) {
          return VaultContent(
            children: [Text(context.tr('Loan unavailable.'))],
          );
        }
        final archived = loan.deletedAtUs != null;
        final outstanding = DebtRepository.outstanding(
          loan,
          finance.balances()[loan.accountId] ?? BigInt.zero,
        );
        final payments = debts.repayments.where(
          (row) => row.contractId == loan.id,
        );
        final journals = {for (final row in finance.journals) row.id: row};
        final active = payments.where(
          (p) => journals[p.journalId]?.deletedAtUs == null,
        );
        final totalTowardLoan = active.fold(
          BigInt.zero,
          (sum, payment) => sum + BigInt.from(payment.principalMinor),
        );
        final totalInterest = active.fold(
          BigInt.zero,
          (sum, p) => sum + BigInt.from(p.interestMinor),
        );
        final method = InterestMethod.values.byName(loan.interestMethod);
        return VaultContent(
          maxWidth: 830,
          children: [
            MetricCard(
              title: loan.name,
              value: formatInr(outstanding),
              icon: Icons.request_quote_outlined,
              detail: context.tr(
                "{kind} · {person}\nLoan amount still left{status}",
                {
                  'kind': context.tr(debtDirection(loan.direction)),
                  'person': loan.counterparty,
                  'status': archived ? context.tr(' · Archived') : '',
                },
              ),
              emphasis: true,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!archived) ...[
                  FilledButton.icon(
                    onPressed: () => context.push('/loan/${loan.id}/repay'),
                    icon: const Icon(Icons.add),
                    label: Text(context.tr('Add a payment')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/loan/${loan.id}/edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(context.tr('Edit loan details')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/loan/${loan.id}/principal'),
                    icon: const Icon(Icons.history),
                    label: Text(context.tr('Correct the original amount')),
                  ),
                ],
                if (method != InterestMethod.unrecorded)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/loan/${loan.id}/estimate'),
                    icon: const Icon(Icons.calculate_outlined),
                    label: Text(context.tr('Interest estimate')),
                  ),
                if (outstanding == BigInt.zero || archived)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _change(
                            (repo) => repo.archive(
                              loan.id,
                              loan.revision,
                              restore: archived,
                            ),
                          ),
                    icon: Icon(
                      archived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                    label: Text(
                      archived
                          ? context.tr('Restore loan')
                          : context.tr('Archive settled loan'),
                    ),
                  ),
              ],
            ),
            if (_error != null) FailureNotice(_error!),
            const SizedBox(height: 24),
            SectionHeading(context.tr('About this loan')),
            Text(
              context.tr("Original loan amount: {amount}\nStarted: {date}", {
                'amount': formatInr(BigInt.from(loan.principalMinor)),
                'date': loan.startedOn,
              }),
            ),
            Text(
              context.tr("How interest is worked out: {method}", {
                'method': context.tr(interestLabel(method)),
              }),
            ),
            if (loan.annualRateBps != null)
              Text(
                context.tr("Annual rate: {rate}%", {
                  'rate': FixedDecimal.format(loan.annualRateBps!, scale: 2),
                }),
              ),
            if (loan.termMonths != null)
              Text(
                context.tr("Term: {months} months", {
                  'months': loan.termMonths,
                }),
              ),
            if (loan.emiMinor != null)
              Text(
                context.tr("Agreed monthly payment: {amount}", {
                  'amount': formatInr(BigInt.from(loan.emiMinor!)),
                }),
              ),
            if (loan.firstDueOn != null)
              Text(
                context.tr("First instalment due: {date}", {
                  'date': loan.firstDueOn,
                }),
              ),
            if (loan.dueOn != null)
              Text(context.tr("Final due date: {date}", {'date': loan.dueOn})),
            if (loan.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(loan.notes),
              ),
            const SizedBox(height: 28),
            SectionHeading(context.tr('Payment history')),
            Text(
              context.tr("Paid toward the loan: {amount}", {
                'amount': formatInr(totalTowardLoan),
              }),
            ),
            Text(
              context.tr("Recorded {interest}: {amount}", {
                'interest': loan.direction == 'lent'
                    ? context.tr('interest received')
                    : context.tr('interest paid'),
                'amount': formatInr(totalInterest),
              }),
            ),
            const SizedBox(height: 12),
            if (payments.isEmpty) Text(context.tr('No payments recorded yet.')),
            for (final p in payments)
              Card.outlined(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        '${p.paidOn}${journals[p.journalId]?.deletedAtUs != null ? context.tr(' · Reversed') : ''}',
                      ),
                      subtitle: Text(
                        context.tr(
                          "Toward the loan {principal}\nInterest {interest}{note}",
                          {
                            'principal': formatInr(
                              BigInt.from(p.principalMinor),
                            ),
                            'interest': formatInr(BigInt.from(p.interestMinor)),
                            'note': p.notes.isEmpty ? '' : '\n${p.notes}',
                          },
                        ),
                      ),
                      onTap: () => context.push('/transaction/${p.journalId}'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                    if (!archived && journals[p.journalId]?.deletedAtUs == null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => context.push(
                                      '/loan/${loan.id}/repay/${p.id}',
                                    ),
                              child: Text(context.tr('Correct payment')),
                            ),
                            TextButton(
                              onPressed: _busy ? null : () => _reverse(loan, p),
                              child: Text(context.tr('Undo payment')),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            RecordAudit(entityId: loan.id),
          ],
        );
      },
    ),
  );
}

class DebtEstimatePage extends StatefulWidget {
  const DebtEstimatePage({required this.id, super.key});
  final String id;
  @override
  State<DebtEstimatePage> createState() => _DebtEstimatePageState();
}

class _DebtEstimatePageState extends State<DebtEstimatePage> {
  String? _through;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Interest estimate'))),
    body: DebtView(
      builder: (debts, _) {
        final loan = debts.contracts
            .where((row) => row.id == widget.id)
            .firstOrNull;
        if (loan == null || loan.annualRateBps == null) {
          return VaultContent(
            children: [
              Text(
                context.tr(
                  'Add an annual rate and interest method to estimate interest.',
                ),
              ),
            ],
          );
        }
        final principal = Money.fromMinor(loan.principalMinor);
        final method = InterestMethod.values.byName(loan.interestMethod);
        if (method == InterestMethod.simpleActual365) {
          final today = LedgerRepository.dateOnly(DateTime.now());
          final through =
              _through ??
              (today.compareTo(loan.startedOn) >= 0 ? today : loan.startedOn);
          Widget estimate;
          try {
            final value = LoanCalculator.simpleInterest(
              principal: principal,
              annualRateBps: loan.annualRateBps!,
              from: DateTime.parse(loan.startedOn),
              through: DateTime.parse(through),
            );
            estimate = MetricCard(
              title: context.tr('Estimated interest'),
              value: formatInr(BigInt.from(value.minor)),
              icon: Icons.calculate_outlined,
            );
          } catch (e) {
            estimate = FailureNotice(e);
          }
          return VaultContent(
            children: [
              Text(
                context.tr(
                  'Estimate on the opening principal over the chosen dates. This calculation assumes the principal stayed constant.',
                ),
              ),
              const SizedBox(height: 20),
              RecordDate(
                context.tr('Estimate through'),
                through,
                (v) => setState(() => _through = v),
              ),
              estimate,
            ],
          );
        }
        if (loan.termMonths == null || loan.firstDueOn == null) {
          return VaultContent(
            children: [
              Text(
                context.tr(
                  'Add the loan term and first due date to estimate monthly instalments.',
                ),
              ),
            ],
          );
        }
        try {
          final schedule = LoanCalculator.schedule(
            principal: principal,
            annualRateBps: loan.annualRateBps!,
            months: loan.termMonths!,
            firstDueOn: DateTime.parse(loan.firstDueOn!),
            method: method,
          );
          final interest = schedule.fold(
            BigInt.zero,
            (sum, row) => sum + BigInt.from(row.interestMinor),
          );
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: schedule.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MetricCard(
                    title: context.tr('Estimated total interest'),
                    value: formatInr(interest),
                    icon: Icons.calculate_outlined,
                    detail: context.tr(
                      "{method}. Projected from opening terms. Actual payments are recorded separately.",
                      {'method': context.tr(interestLabel(method))},
                    ),
                  ),
                );
              }
              final row = schedule[index - 1];
              return Card.outlined(
                child: ListTile(
                  title: Text(
                    '${LedgerRepository.dateOnly(row.dueOn)} · ${formatInr(BigInt.from(row.payment.minor))}',
                  ),
                  subtitle: Text(
                    context.tr(
                      "Toward the loan {principal}\nInterest {interest}\nRemaining {remaining}",
                      {
                        'principal': formatInr(BigInt.from(row.principalMinor)),
                        'interest': formatInr(BigInt.from(row.interestMinor)),
                        'remaining': formatInr(BigInt.from(row.balanceMinor)),
                      },
                    ),
                  ),
                ),
              );
            },
          );
        } catch (e) {
          return VaultContent(children: [FailureNotice(e)]);
        }
      },
    ),
  );
}
