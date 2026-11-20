import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/localization/vault_strings.dart';
import '../../../shared/widgets/vault_widgets.dart';

class MoneyPage extends StatelessWidget {
  const MoneyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    return VaultContent(
      maxWidth: 680,
      children: [
        const MoneyActions(),
        const SizedBox(height: 20),
        for (final (key, path, icon) in const [
          ('accounts', '/accounts', Icons.account_balance_outlined),
          ('transactions', '/transactions', Icons.history_rounded),
          ('assets', '/assets', Icons.home_work_outlined),
          ('liabilities', '/loans', Icons.payments_outlined),
          ('budgets', '/planning', Icons.savings_outlined),
          ('reports', '/reports', Icons.insights_outlined),
        ])
          VaultLink(
            icon: icon,
            title: strings.text(key),
            onTap: () => context.push(path),
          ),
      ],
    );
  }
}

class MoneyActions extends StatelessWidget {
  const MoneyActions({this.onDocument, super.key});

  final VoidCallback? onDocument;

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn =
            MediaQuery.textScalerOf(context).scale(14) > 18 ||
            constraints.maxWidth < 300;
        final width = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 8) / 2;
        final actions = [
          (
            'addIncome',
            Icons.south_west,
            () => context.push('/transaction/new?kind=income'),
          ),
          (
            'addExpense',
            Icons.north_east,
            () => context.push('/transaction/new?kind=expense'),
          ),
          (
            'transfer',
            Icons.swap_horiz,
            () => context.push('/transaction/new?kind=transfer'),
          ),
          if (onDocument case final action?)
            ('addDocument', Icons.note_add_outlined, action),
        ];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, icon, open) in actions)
              SizedBox(
                width: width,
                child: OutlinedButton.icon(
                  key: ValueKey('action-$label'),
                  onPressed: open,
                  icon: Icon(icon, size: 19),
                  label: Text(strings.text(label), textAlign: TextAlign.center),
                ),
              ),
          ],
        );
      },
    );
  }
}
