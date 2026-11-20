import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/vault_providers.dart';
import '../../../core/finance/formatters.dart';
import '../../../shared/widgets/record_audit.dart';
import '../../../shared/widgets/record_fields.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../../finance/data/ledger_repository.dart';
import '../../finance/domain/finance_report.dart';
import '../data/business_repository.dart';

final businessProvider = StreamProvider.autoDispose<BusinessSnapshot>((ref) {
  final session = ref.watch(vaultProvider).session;
  return session == null || session.closed
      ? const Stream.empty()
      : BusinessRepository(session.ledger).watch();
});

class BusinessView extends ConsumerWidget {
  const BusinessView({required this.builder, super.key});
  final Widget Function(BusinessSnapshot, FinanceSnapshot) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(businessProvider)
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => VaultContent(
          children: [
            FailureNotice(e),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(businessProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
        data: (data) =>
            FinanceView(builder: (finance) => builder(data, finance)),
      );
}

class BusinessesPage extends StatelessWidget {
  const BusinessesPage({super.key});
  @override
  Widget build(BuildContext context) => BusinessView(
    builder: (data, finance) => VaultContent(
      children: [
        SectionHeading(
          'Your businesses',
          action: FilledButton.icon(
            onPressed: () => context.push('/business/new'),
            icon: const Icon(Icons.add),
            label: const Text('Add business'),
          ),
        ),
        if (data.businesses.isEmpty)
          const EmptyNotice(
            icon: Icons.storefront_outlined,
            title: 'No businesses recorded yet',
            message: 'Add a business to keep its sales, bills, stock and wages together.',
          ),
        for (final row in data.businesses)
          Card.outlined(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(row.name),
              subtitle: Text(
                row.notes.isEmpty ? 'Money, stock and wages' : row.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/business/${row.id}'),
            ),
          ),
      ],
    ),
  );
}

class BusinessPage extends StatefulWidget {
  const BusinessPage({required this.id, super.key});
  final String id;
  @override
  State<BusinessPage> createState() => _BusinessPageState();
}

class _BusinessPageState extends State<BusinessPage> {
  String _date = LedgerRepository.dateOnly(DateTime.now());
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business details')),
    body: BusinessView(
      builder: (data, finance) {
        final business = data.businesses
            .where((r) => r.id == widget.id)
            .firstOrNull;
        if (business == null || business.deletedAtUs != null) {
          return const VaultContent(children: [Text('Business unavailable.')]);
        }
        final month = DateTime.parse(_date),
            period = ReportPeriod.month(month.year, month.month);
        final profit = BusinessProfit.forPeriod(
          business,
          finance,
          from: period.start,
          through: period.end,
        );
        final stock = data.items.where(
          (row) =>
              row.businessId == business.id &&
              (_showArchived || row.deletedAtUs == null),
        );
        final workers = data.workers.where(
          (row) =>
              row.businessId == business.id &&
              (_showArchived || row.deletedAtUs == null),
        );
        final entries = finance.journals.where(
          (j) =>
              j.businessId == business.id &&
              j.occurredOn.compareTo(period.start) >= 0 &&
              j.occurredOn.compareTo(period.end) <= 0,
        );
        return VaultContent(
          children: [
            SectionHeading(
              business.name,
              action: OutlinedButton.icon(
                onPressed: () => context.push('/business/${business.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit business'),
              ),
            ),
            if (business.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(business.notes),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/business/${business.id}/revenue'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add money from sales'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/business/${business.id}/expense'),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Add a business cost'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RecordDate(
              'Report month',
              _date,
              (value) => setState(() => _date = value),
            ),
            ResponsiveCards(
              children: [
                MetricCard(
                  title: 'Business profit',
                  value: formatInr(profit.net),
                  icon: Icons.insights_outlined,
                  detail: period.label,
                  emphasis: true,
                ),
                MetricCard(
                  title: 'Money from sales',
                  value: formatInr(profit.revenue),
                  icon: Icons.trending_up,
                ),
                MetricCard(
                  title: 'Value of stock left',
                  value: formatInr(
                    finance.balances()[business.inventoryAccountId] ??
                        BigInt.zero,
                  ),
                  icon: Icons.inventory_2_outlined,
                  detail: 'Based on what you paid for it',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card.outlined(
              child: ExpansionTile(
                title: const Text('How profit is worked out'),
                children: [
                  _ProfitLine('Cost of stock used', profit.costOfGoods),
                  _ProfitLine('Sales minus stock costs', profit.gross),
                  _ProfitLine('Wages paid', profit.salaries),
                  _ProfitLine('Business costs', profit.operatingExpenses),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show archived items and workers'),
              value: _showArchived,
              onChanged: (v) => setState(() => _showArchived = v),
            ),
            SectionHeading(
              'Stock',
              action: OutlinedButton.icon(
                onPressed: () => context.push('/business/${business.id}/item'),
                icon: const Icon(Icons.add),
                label: const Text('Add stock item'),
              ),
            ),
            if (stock.isEmpty)
              const Text(
                'Add a stock item before recording purchases or issues.',
              ),
            for (final item in stock)
              Card.outlined(
                child: ListTile(
                  title: Text(item.name),
                  leading: const Icon(Icons.inventory_2_outlined),
                  subtitle: Text(
                    '${data.positions[item.id]?.quantity ?? 0} pieces · ${formatInr(BigInt.from(data.positions[item.id]?.costPoolMinor ?? 0))}${item.deletedAtUs == null ? '' : ' · Archived'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/stock/${item.id}'),
                ),
              ),
            const SizedBox(height: 24),
            SectionHeading(
              'Workers',
              action: OutlinedButton.icon(
                onPressed: () =>
                    context.push('/business/${business.id}/worker'),
                icon: const Icon(Icons.person_add_alt_outlined),
                label: const Text('Add worker'),
              ),
            ),
            if (workers.isEmpty)
              const Text(
                'Worker records keep agreed wages and actual payment history.',
              ),
            for (final worker in workers)
              Card.outlined(
                child: ListTile(
                  title: Text(worker.name),
                  leading: const Icon(Icons.person_outline),
                  subtitle: Text(
                    worker.deletedAtUs != null
                        ? 'Archived'
                        : worker.monthlySalaryMinor == null
                        ? 'Monthly pay unrecorded'
                        : '${formatInr(BigInt.from(worker.monthlySalaryMinor!))} agreed monthly pay',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/worker/${worker.id}'),
                ),
              ),
            const SizedBox(height: 24),
            SectionHeading('Money activity · ${period.label}'),
            if (entries.isEmpty)
              const Text('No business entries in this month.'),
            for (final row in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.description),
                subtitle: Text(
                  '${row.occurredOn}${row.deletedAtUs == null ? '' : ' · Reversed'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/transaction/${row.id}'),
              ),
            RecordAudit(entityId: business.id),
          ],
        );
      },
    ),
  );
}

class _ProfitLine extends StatelessWidget {
  const _ProfitLine(this.label, this.amount);
  final String label;
  final BigInt amount;
  @override
  Widget build(BuildContext context) =>
      ListTile(title: Text(label), subtitle: Text(formatInr(amount)));
}

class BusinessOverview extends ConsumerWidget {
  const BusinessOverview({
    required this.finance,
    required this.from,
    required this.through,
    super.key,
  });
  final FinanceSnapshot finance;
  final String from, through;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(businessProvider).asData?.value.businesses;
    if (rows == null || rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final amount = rows.fold(
      BigInt.zero,
      (sum, row) =>
          sum +
          BusinessProfit.forPeriod(
            row,
            finance,
            from: from,
            through: through,
          ).net,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card.filled(
        child: ListTile(
          leading: const Icon(Icons.storefront_outlined),
          title: const Text('Business profit for this period'),
          subtitle: Text(formatInr(amount)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/businesses'),
        ),
      ),
    );
  }
}
