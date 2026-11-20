import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/vault_strings.dart';
import '../features/assets/presentation/asset_action_editor.dart';
import '../features/assets/presentation/asset_editor.dart';
import '../features/assets/presentation/assets_pages.dart';
import '../features/auth/sync_recovery_page.dart';
import '../features/auth/family_page.dart';
import '../features/assets/domain/asset_draft.dart';
import '../features/backup/backups_page.dart';
import '../features/backup/restore_backup_page.dart';
import '../features/business/presentation/business_detail_pages.dart';
import '../features/business/presentation/business_entry_editor.dart';
import '../features/business/presentation/business_pages.dart';
import '../features/business/presentation/business_record_editor.dart';
import '../features/document_vault/document_detail.dart';
import '../features/document_vault/document_inputs.dart';
import '../features/document_vault/document_pages.dart';
import '../features/foundation/foundation_pages.dart';
import '../features/finance/presentation/finance_home_page.dart';
import '../features/finance/presentation/money_page.dart';
import '../features/finance/data/ledger_repository.dart';
import '../features/guidance/guided_help.dart';
import '../features/guidance/welcome_tour.dart';
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
  ref.listen(documentIntakeProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/',
    navigatorKey: rootNavigator,
    refreshListenable: refresh,
    redirect: (context, route) {
      final session = ref.read(vaultProvider).session;
      final open = session != null && !session.closed;
      final path = route.uri.path;
      final publicPage =
          {
            '/',
            '/access',
            '/about',
            '/restore',
            '/welcome-tour',
            '/help',
          }.contains(path) ||
          path.startsWith('/help/');
      if (!publicPage && !open) {
        return '/access';
      }
      if (open && (path == '/' || path == '/access' || path == '/restore')) {
        final selection = ref.read(documentIntakeProvider);
        if (selection?.belongsTo(session.identity) == true) {
          return '/document/import';
        }
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
      GoRoute(path: '/access', builder: (context, state) => const AccessPage()),
      GoRoute(path: '/restore', builder: (_, _) => const RestoreBackupPage()),
      GoRoute(path: '/about', builder: (context, state) => const AboutPage()),
      GoRoute(
        path: '/welcome-tour',
        builder: (_, _) => const WelcomeTourPage(),
      ),
      GoRoute(path: '/help', builder: (_, _) => const HelpPage()),
      GoRoute(
        path: '/help/:topic',
        builder: (_, state) {
          final topic = HelpTopic.values
              .where((topic) => topic.name == state.pathParameters['topic'])
              .firstOrNull;
          return topic == null ? const HelpPage() : TopicGuidePage(topic);
        },
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, navigation) => NoTransitionPage<void>(
          key: state.pageKey,
          child: VaultShell(navigation: navigation),
        ),
        branches: [
          StatefulShellBranch(
            routes: [_workspaceRoute('/home', const FinanceHomePage())],
          ),
          StatefulShellBranch(
            routes: [_workspaceRoute('/money', const MoneyPage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/documents',
                pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: DocumentsPage(
                    guide: DocumentGuide.values
                        .where(
                          (guide) =>
                              guide.name == state.uri.queryParameters['guide'],
                        )
                        .firstOrNull,
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [_workspaceRoute('/family', const FamilyPage())],
          ),
          StatefulShellBranch(
            routes: [_workspaceRoute('/more', const MorePage())],
          ),
        ],
      ),
      _sectionRoute('/transactions', 'transactions', const TransactionsPage()),
      _sectionRoute('/accounts', 'accounts', const AccountsPage()),
      _sectionRoute('/assets', 'assets', const AssetsPage()),
      _sectionRoute('/loans', 'liabilities', const DebtsPage()),
      _sectionRoute('/planning', 'budgets', const PlanningPage()),
      _sectionRoute('/reports', 'reports', const ReportsPage()),
      _sectionRoute(
        '/settings',
        'settings',
        const SettingsPage(),
        from: '/more',
      ),
      _sectionRoute(
        '/businesses',
        'business',
        const BusinessesPage(),
        from: '/more',
      ),
      GoRoute(path: '/backups', builder: (_, _) => const BackupsPage()),
      GoRoute(
        path: '/document/import',
        builder: (_, _) => const DocumentEditorPage(),
      ),
      GoRoute(
        path: '/document/:id/edit',
        builder: (_, state) =>
            DocumentEditorPage(documentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/document/:id/version/:version',
        builder: (_, state) => DocumentPreviewPage(
          documentId: state.pathParameters['id']!,
          versionId: state.pathParameters['version']!,
        ),
      ),
      GoRoute(
        path: '/document/:id',
        builder: (_, state) =>
            DocumentDetailPage(documentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/family-recovery',
        builder: (_, _) => const SyncRecoveryPage(),
      ),
      GoRoute(
        path: '/transaction/new',
        builder: (_, state) => TransactionEditor(
          initialKind: [EntryKind.income, EntryKind.expense, EntryKind.transfer]
              .where((kind) => kind.name == state.uri.queryParameters['kind'])
              .firstOrNull,
          guided: state.uri.queryParameters['guide'] == '1',
        ),
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
          initialSubtype: state.uri.queryParameters['subtype'],
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
      GoRoute(
        path: '/asset/new',
        builder: (_, state) => AssetEditor(
          initialKind:
              AssetKind.values
                  .where(
                    (kind) => kind.name == state.uri.queryParameters['kind'],
                  )
                  .firstOrNull ??
              AssetKind.property,
        ),
      ),
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
      appBar: AppBar(title: Text(context.tr('Page unavailable'))),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: Text(context.tr('Return to FamilyVault')),
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
  pageBuilder: (context, state) =>
      NoTransitionPage<void>(key: state.pageKey, child: child),
);

GoRoute _sectionRoute(
  String path,
  String title,
  Widget child, {
  String from = '/money',
}) => GoRoute(
  path: path,
  pageBuilder: (context, state) => NoTransitionPage<void>(
    key: state.pageKey,
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(from);
            }
          },
        ),
        title: Text(VaultStrings.of(context).text(title)),
      ),
      body: child,
    ),
  ),
);
