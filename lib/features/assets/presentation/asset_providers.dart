import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/localization/vault_strings.dart';
import '../../../app/vault_providers.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../data/asset_repository.dart';

final assetsProvider = StreamProvider.autoDispose<AssetSnapshot>((ref) {
  final session = ref.watch(vaultProvider).session;
  if (session == null || session.closed) {
    return const Stream.empty();
  }
  return AssetRepository(session.ledger).watch();
});

class AssetView extends ConsumerWidget {
  const AssetView({required this.builder, super.key});
  final Widget Function(AssetSnapshot) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(assetsProvider)
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => VaultContent(
          children: [
            FailureNotice(e),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(assetsProvider),
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('Try again')),
            ),
          ],
        ),
        data: builder,
      );
}

String assetLabel(String kind) => switch (kind) {
  'property' => 'Property',
  'land' => 'Land',
  'gold' => 'Gold',
  'silver' => 'Silver',
  'jewellery' => 'Jewellery',
  'vehicle' => 'Vehicle',
  'deposit' => 'Bank deposit',
  'investment' => 'Investment',
  _ => 'Something else',
};
IconData assetIcon(String kind) => switch (kind) {
  'property' || 'land' => Icons.home_work_outlined,
  'gold' || 'silver' || 'jewellery' => Icons.diamond_outlined,
  'vehicle' => Icons.directions_car_outlined,
  'investment' || 'deposit' => Icons.trending_up,
  _ => Icons.inventory_2_outlined,
};
