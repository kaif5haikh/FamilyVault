import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assets/presentation/asset_action_editor.dart';
import '../features/assets/presentation/asset_editor.dart';
import '../features/assets/presentation/assets_pages.dart';
import '../features/business/presentation/business_detail_pages.dart';
import '../features/business/presentation/business_entry_editor.dart';
import '../features/business/presentation/business_pages.dart';
import '../features/business/presentation/business_record_editor.dart';
import '../features/foundation/foundation_pages.dart';
import '../features/finance/presentation/finance_home_page.dart';
import '../features/finance/presentation/accounts_pages.dart';
import '../features/finance/presentation/transactions_pages.dart';
import '../features/finance/presentation/transaction_editor.dart';
import '../features/finance/presentation/planning_pages.dart';
import '../features/finance/presentation/reports_page.dart';
import '../features/liabilities/presentation/debt_editor.dart';
import '../features/liabilities/presentation/debt_pages.dart';
import '../features/settings/settings_pages.dart';
import 'vault_providers.dart';
import 'vault_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  final rootNavigator = GlobalKey<NavigatorState>(
    debugLabel: 'familyvault.root',
  );
  ref.listen(vaultProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/',
    navigatorKey: rootNavigator,
    refreshListenable: refresh,
    redirect: (context, route) {
      final session = ref.read(vaultProvider).session;
      final open = session != null && !session.closed;
      final path = route.uri.path;
      if (!{'/', '/access', '/about'}.contains(path) && !open) {
        return '/access';
      }
      if (open && (path == '/' || path == '/access')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
      GoRoute(path: '/access', builder: (context, state) => const AccessPage()),
      GoRoute(path: '/about', builder: (context, state) => const AboutPage()),
      _workspaceRoute('/home', const FinanceHomePage()),
      _workspaceRoute('/transactions', const TransactionsPage()),
      _workspaceRoute('/accounts', const AccountsPage()),
      _workspaceRoute('/assets', const AssetsPage()),
      _workspaceRoute('/loans', const DebtsPage()),
      _workspaceRoute('/businesses', const BusinessesPage()),
      _workspaceRoute('/planning', const PlanningPage()),
      _workspaceRoute('/reports', const ReportsPage()),
      _workspaceRoute('/settings', const SettingsPage()),
      _workspaceRoute('/more', const MorePage()),
      GoRoute(
        path: '/transaction/new',
        builder: (_, _) => const TransactionEditor(),
      ),
      GoRoute(
        path: '/transaction/:id/edit',
        builder: (_, state) =>
            TransactionEditor(journalId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/transaction/:id',
        builder: (_, state) =>
            JournalDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/account/new',
        builder: (_, state) => AccountEditor(
          initialKind: state.uri.queryParameters['kind'] ?? 'asset',
        ),
      ),
      GoRoute(
        path: '/account/:id/edit',
        builder: (_, state) =>
            AccountEditor(accountId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/account/:id/reconcile',
        builder: (_, state) =>
            ReconciliationEditor(accountId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/account/:id',
        builder: (_, state) =>
            AccountDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/budget/new',
        builder: (_, state) =>
            BudgetEditor(month: state.uri.queryParameters['month']),
      ),
      GoRoute(
        path: '/budget/:id/edit',
        builder: (_, state) => BudgetEditor(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/asset/new', builder: (_, _) => const AssetEditor()),
      GoRoute(
        path: '/asset/:id/edit',
        builder: (_, state) => AssetEditor(id: state.pathParameters['id']!),
      ),
      for (final action in ['value', 'rent', 'close', 'ownership'])
        GoRoute(
          path: '/asset/:id/$action',
          builder: (_, state) => AssetActionEditor(
            id: state.pathParameters['id']!,
            action: action,
          ),
        ),
      GoRoute(
        path: '/asset/:id',
        builder: (_, state) => AssetDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/loan/new', builder: (_, _) => const DebtEditor()),
      GoRoute(
        path: '/loan/:id/edit',
        builder: (_, state) => DebtEditor(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/loan/:id/principal',
        builder: (_, state) =>
            DebtEditor(id: state.pathParameters['id']!, correctPrincipal: true),
      ),
      GoRoute(
        path: '/loan/:id/repay',
        builder: (_, state) => RepaymentEditor(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/loan/:id/repay/:payment',
        builder: (_, state) => RepaymentEditor(
          id: state.pathParameters['id']!,
          repaymentId: state.pathParameters['payment']!,
        ),
      ),
      GoRoute(
        path: '/loan/:id/estimate',
        builder: (_, state) =>
            DebtEstimatePage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/loan/:id',
        builder: (_, state) => DebtDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/business/new',
        builder: (_, _) =>
            const BusinessRecordEditor(kind: BusinessRecordKind.business),
      ),
      GoRoute(
        path: '/business/:id/edit',
        builder: (_, state) => BusinessRecordEditor(
          kind: BusinessRecordKind.business,
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/business/:id/item',
        builder: (_, state) => BusinessRecordEditor(
          kind: BusinessRecordKind.stock,
          businessId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/business/:id/worker',
        builder: (_, state) => BusinessRecordEditor(
          kind: BusinessRecordKind.worker,
          businessId: state.pathParameters['id']!,
        ),
      ),
      for (final mode in [BusinessEntryMode.revenue, BusinessEntryMode.expense])
        GoRoute(
          path: '/business/:id/${mode.name}',
          builder: (_, state) =>
              BusinessEntryEditor(id: state.pathParameters['id']!, mode: mode),
        ),
      GoRoute(
        path: '/business/:id',
        builder: (_, state) => BusinessPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/stock/:id/edit',
        builder: (_, state) => BusinessRecordEditor(
          kind: BusinessRecordKind.stock,
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/stock/:id/move',
        builder: (_, state) => BusinessEntryEditor(
          id: state.pathParameters['id']!,
          mode: BusinessEntryMode.stock,
        ),
      ),
      GoRoute(
        path: '/stock/:id/move/:entry',
        builder: (_, state) => BusinessEntryEditor(
          id: state.pathParameters['id']!,
          mode: BusinessEntryMode.stock,
          originalId: state.pathParameters['entry']!,
        ),
      ),
      GoRoute(
        path: '/stock/:id',
        builder: (_, state) =>
            WorkRecordPage(id: state.pathParameters['id']!, isStock: true),
      ),
      GoRoute(
        path: '/worker/:id/edit',
        builder: (_, state) => BusinessRecordEditor(
          kind: BusinessRecordKind.worker,
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/worker/:id/pay',
        builder: (_, state) => BusinessEntryEditor(
          id: state.pathParameters['id']!,
          mode: BusinessEntryMode.salary,
        ),
      ),
      GoRoute(
        path: '/worker/:id/pay/:entry',
        builder: (_, state) => BusinessEntryEditor(
          id: state.pathParameters['id']!,
          mode: BusinessEntryMode.salary,
          originalId: state.pathParameters['entry']!,
        ),
      ),
      GoRoute(
        path: '/worker/:id',
        builder: (_, state) =>
            WorkRecordPage(id: state.pathParameters['id']!, isStock: false),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Return to FamilyVault'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);
  return router;
});

GoRoute _workspaceRoute(String path, Widget child) => GoRoute(
  path: path,
  pageBuilder: (context, state) => NoTransitionPage<void>(
    key: state.pageKey,
    child: VaultShell(path: state.uri.path, child: child),
  ),
);
