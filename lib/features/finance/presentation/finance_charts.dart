import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/localization/vault_strings.dart';
import '../../../core/finance/formatters.dart';
import '../domain/finance_report.dart';

class IncomeExpenseChart extends StatelessWidget {
  const IncomeExpenseChart({required this.reports, super.key});
  final List<FinanceReport> reports;
  @override
  Widget build(BuildContext context) {
    var max = BigInt.zero;
    for (final r in reports) {
      if (r.income.abs() > max) {
        max = r.income.abs();
      }
      if (r.expenses.abs() > max) {
        max = r.expenses.abs();
      }
    }
    if (max == BigInt.zero) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          context.tr(
            'Your income and expense trend appears as you add records.',
          ),
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    final negative = reports.any(
      (r) => r.income.isNegative || r.expenses.isNegative,
    );
    double coordinate(BigInt value) => value.isNegative
        ? -chartRatio(value.abs(), max)
        : chartRatio(value, max);
    final chart = Semantics(
      label: context.tr(
        'Income and expense chart. Exact values follow in the report.',
      ),
      child: ExcludeSemantics(
        child: SizedBox(
          height: 240,
          child: Padding(
            padding: const EdgeInsets.only(top: 16, right: 16),
            child: BarChart(
              BarChartData(
                minY: negative ? -1.1 : 0,
                maxY: 1.1,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: .25,
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 82,
                      interval: .25,
                      getTitlesWidget: (value, meta) => Text(
                        formatInr(
                          (max * BigInt.from((value * 100).round())) ~/
                              BigInt.from(100),
                          compact: true,
                        ),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        return index < 0 || index >= reports.length
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  reports[index].period.start.substring(5, 7),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                          '${reports[group.x].period.label}\n${rodIndex == 0 ? context.tr('Income') : context.tr('Expenses')}\n${formatInr(rodIndex == 0 ? reports[group.x].income : reports[group.x].expenses)}',
                          TextStyle(color: colors.onInverseSurface),
                        ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < reports.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: coordinate(reports[i].income),
                          color: colors.primary,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: coordinate(reports[i].expenses),
                          color: colors.tertiary,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 12, color: colors.primary),
                const SizedBox(width: 6),
                Text(context.tr('Income')),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 12, color: colors.tertiary),
                const SizedBox(width: 6),
                Text(context.tr('Expenses')),
              ],
            ),
          ],
        ),
        chart,
      ],
    );
  }
}

class AllocationChart extends StatelessWidget {
  const AllocationChart({required this.allocation, super.key});
  final Map<String, BigInt> allocation;
  @override
  Widget build(BuildContext context) {
    if (allocation.isEmpty) {
      return Text(context.tr('Add assets to see their allocation.'));
    }
    final colors = Theme.of(context).colorScheme;
    final palette = [
      colors.primary,
      colors.tertiary,
      colors.secondary,
      colors.primaryContainer,
      colors.tertiaryContainer,
      colors.secondaryContainer,
    ];
    final entries = allocation.entries.toList(),
        total = allocation.values.fold(BigInt.zero, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 52,
                sectionsSpace: 3,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: chartRatio(entries[i].value, total),
                      color: palette[i % palette.length],
                      radius: 36,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: palette[i % palette.length],
                ),
                Text(
                  '${context.tr(entries[i].key.replaceAll('_', ' '))} · ${formatInr(entries[i].value)} · ${formatPercentage(entries[i].value, total)}',
                ),
              ],
            ),
          ),
        Text(
          context.tr(
            'Positive asset balances. Overdrafts remain included in net worth.',
          ),
        ),
      ],
    );
  }
}
