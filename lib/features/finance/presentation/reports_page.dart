import 'package:material_ui/material_ui.dart';

import '../../../core/finance/formatters.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../domain/finance_report.dart';
import '../../business/presentation/business_pages.dart';
import 'finance_charts.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _yearly = false;
  DateTime _date = DateTime.now();
  @override
  Widget build(BuildContext context) => FinanceView(
    builder: (data) {
      final report = FinanceReport(
        data,
        _yearly
            ? ReportPeriod.year(_date.year)
            : ReportPeriod.month(_date.year, _date.month),
      );
      final months = [
        for (var i = 0; i < (_yearly ? 12 : 6); i++)
          _yearly
              ? DateTime(_date.year, i + 1)
              : DateTime(_date.year, _date.month - 5 + i),
      ];
      final trend = [
        for (final month in months)
          FinanceReport(data, ReportPeriod.month(month.year, month.month)),
      ];
      return VaultContent(
        children: [
          SectionHeading(
            'Your money over time',
            action: OutlinedButton.icon(
              onPressed: _chooseDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(report.period.label),
            ),
          ),
          Wrap(
            spacing: 12,
            children: [
              ChoiceChip(
                label: const Text('Monthly'),
                selected: !_yearly,
                onSelected: (_) => setState(() => _yearly = false),
              ),
              ChoiceChip(
                label: const Text('Yearly'),
                selected: _yearly,
                onSelected: (_) => setState(() => _yearly = true),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ResponsiveCards(
            children: [
              MetricCard(
                title: 'Money received',
                value: formatInr(report.income),
                icon: Icons.south_west,
              ),
              MetricCard(
                title: 'Money spent',
                value: formatInr(report.expenses),
                icon: Icons.north_east,
              ),
              MetricCard(
                title: 'Money left this period',
                value: formatInr(report.savings),
                icon: Icons.savings_outlined,
                detail:
                    'Share left ${formatPercentage(report.savings, report.income)}',
              ),
              MetricCard(
                title: 'Estimated family value',
                value: formatInr(report.netWorth),
                icon: Icons.account_balance_outlined,
                detail: 'As of ${report.period.end}',
              ),
            ],
          ),
          const SizedBox(height: 32),
          const SectionHeading('Money in and out'),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IncomeExpenseChart(reports: trend),
            ),
          ),
          const SizedBox(height: 16),
          for (final month in trend)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(month.period.label),
              subtitle: Text(
                'Received ${formatInr(month.income)} · Spent ${formatInr(month.expenses)}',
              ),
            ),
          const SizedBox(height: 24),
          const SectionHeading('Category breakdown'),
          for (final kind in ['income', 'expense']) ...[
            Text(
              kind == 'income'
                  ? 'Where money came from'
                  : 'What money was spent on',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (report.categories(kind).isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('No activity for this period.'),
              ),
            for (final entry in report.categories(kind).entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  data.accounts.where((a) => a.id == entry.key).first.name,
                ),
                subtitle: Text(formatInr(entry.value)),
              ),
          ],
          const SizedBox(height: 24),
          BusinessOverview(
            finance: data,
            from: report.period.start,
            through: report.period.end,
          ),
          const SizedBox(height: 18),
          const SectionHeading('What makes up what we own'),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AllocationChart(
                allocation: report.positiveAssetAllocation,
              ),
            ),
          ),
        ],
      );
    },
  );
  Future<void> _chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1901),
      lastDate: DateTime(2200, 12, 31),
      helpText: _yearly
          ? 'Choose a day in the reporting year'
          : 'Choose a day in the reporting month',
    );
    if (value != null && mounted) {
      setState(() => _date = value);
    }
  }
}
