import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/localization/vault_strings.dart';
import '../../../app/vault_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/finance/fixed_decimal.dart';
import '../../../core/finance/formatters.dart';
import '../../../shared/widgets/record_audit.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../../document_vault/linked_documents.dart';
import '../data/asset_repository.dart';
import 'asset_providers.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});
  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  String _search = '', _filter = 'Active';
  @override
  Widget build(BuildContext context) => AssetView(
    builder: (assets) => FinanceView(
      builder: (finance) {
        final balances = finance.balances();
        final active = assets.assets
            .where((a) => a.deletedAtUs == null)
            .toList();
        final total = active.fold(
          BigInt.zero,
          (v, a) => v + (balances[a.accountId] ?? BigInt.zero),
        );
        final unknown = active
            .where((a) => a.valuationState == 'unrecorded')
            .length;
        final rows = assets.assets
            .where(
              (a) =>
                  (_filter == 'Closed'
                      ? a.deletedAtUs != null
                      : a.deletedAtUs == null) &&
                  '${a.name} ${assetLabel(a.kind)} ${assets.properties.where((p) => p.assetId == a.id).map((p) => '${p.city} ${p.location}').join(' ')}'
                      .toLowerCase()
                      .contains(_search.toLowerCase()),
            )
            .toList();
        return VaultContent(
          children: [
            SectionHeading(
              context.tr('Items and property'),
              action: FilledButton.icon(
                onPressed: () => context.push('/asset/new'),
                icon: const Icon(Icons.add),
                label: Text(context.tr('Add an item')),
              ),
            ),
            MetricCard(
              title: context.tr('Estimated value of our items'),
              value: formatInr(total),
              icon: Icons.diamond_outlined,
              detail: context.tr("Only your family’s share is counted{more}", {
                'more': unknown > 0
                    ? '\n${context.tr(unknown == 1 ? '1 item without an estimate' : '{count} items without an estimate', {'count': unknown})}'
                    : '',
              }),
              emphasis: true,
            ),
            const SizedBox(height: 24),
            TextField(
              decoration: InputDecoration(
                labelText: context.tr('Search name or place'),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final label in ['Active', 'Closed'])
                  ChoiceChip(
                    label: Text(context.tr(label)),
                    selected: _filter == label,
                    onSelected: (_) => setState(() => _filter = label),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (rows.isEmpty)
              EmptyNotice(
                icon: Icons.home_work_outlined,
                title: context.tr('Nothing recorded yet'),
                message: _search.isEmpty
                    ? context.tr(
                        'Add a home, land, gold, a vehicle or an investment. You can add an estimate later.',
                      )
                    : context.tr('No items match that search.'),
              ),
            for (final a in rows)
              Card.outlined(
                child: ListTile(
                  leading: Icon(assetIcon(a.kind)),
                  title: Text(a.name),
                  subtitle: Text(
                    context.tr("{item} · {share}% family share\n{value}", {
                      'item': context.tr(assetLabel(a.kind)),
                      'share': FixedDecimal.format(
                        a.familyOwnershipBps,
                        scale: 2,
                      ),
                      'value': a.valuationState == 'unrecorded'
                          ? context.tr('No value added yet')
                          : a.valuationState == 'closed'
                          ? context.tr('Closed {date}', {'date': a.closedOn})
                          : formatInr(balances[a.accountId] ?? BigInt.zero),
                    }),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/asset/${a.id}'),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class AssetDetailPage extends ConsumerStatefulWidget {
  const AssetDetailPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends ConsumerState<AssetDetailPage> {
  Object? _error;
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Item details'))),
    body: AssetView(
      builder: (assets) => FinanceView(
        builder: (finance) {
          final a = assets.assets.where((a) => a.id == widget.id).firstOrNull;
          if (a == null) {
            return VaultContent(
              children: [Text(context.tr('We couldn’t find that item.'))],
            );
          }
          final property = assets.properties
              .where((p) => p.assetId == a.id)
              .firstOrNull;
          final metal = assets.metals
              .where((m) => m.assetId == a.id)
              .firstOrNull;
          final investment = assets.investments
              .where((i) => i.assetId == a.id)
              .firstOrNull;
          final owners = assets.owners.where(
            (o) => o.assetId == a.id && o.deletedAtUs == null,
          );
          final history = assets.valuations
              .where((v) => v.assetId == a.id)
              .toList();
          final journals = finance.journals
              .where((j) => j.relatedEntityId == a.id)
              .toList();
          final current = finance.balances()[a.accountId] ?? BigInt.zero;
          return VaultContent(
            maxWidth: 850,
            children: [
              MetricCard(
                title: a.name,
                value: a.valuationState == 'unrecorded'
                    ? context.tr('No value added yet')
                    : formatInr(current),
                icon: assetIcon(a.kind),
                detail: context.tr("{item} · {share}% family share{status}", {
                  'item': context.tr(assetLabel(a.kind)),
                  'share': FixedDecimal.format(a.familyOwnershipBps, scale: 2),
                  'status': a.closedOn == null
                      ? ''
                      : '\n${context.tr('Closed {date}', {'date': a.closedOn})}',
                }),
                emphasis: true,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (a.closedOn == null) ...[
                    FilledButton.icon(
                      onPressed: () => context.push('/asset/${a.id}/value'),
                      icon: const Icon(Icons.trending_up),
                      label: Text(context.tr('Update estimated value')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/asset/${a.id}/edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(context.tr('Edit details')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/asset/${a.id}/ownership'),
                      icon: const Icon(Icons.groups_outlined),
                      label: Text(context.tr('Change family share')),
                    ),
                    if (property != null)
                      OutlinedButton.icon(
                        onPressed: () => context.push('/asset/${a.id}/rent'),
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(context.tr('Add rent received')),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/asset/${a.id}/close'),
                      icon: const Icon(Icons.archive_outlined),
                      label: Text(context.tr('Close this item')),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () => context.push('/asset/${a.id}/value'),
                      icon: const Icon(Icons.history),
                      label: Text(context.tr('Add an older estimate')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              final reason = await showDialog<String>(
                                context: context,
                                builder: (_) => ReasonDialog(
                                  title: context.tr('Undo this closure?'),
                                  message: context.tr(
                                    'This puts the item back in your list and keeps the earlier change in history. If you bought it again, add it as a new item.',
                                  ),
                                  confirmLabel: context.tr('Undo closure'),
                                ),
                              );
                              if (reason == null || !mounted) {
                                return;
                              }
                              setState(() {
                                _busy = true;
                                _error = null;
                              });
                              try {
                                await AssetRepository(
                                  ref.read(vaultProvider).session!.ledger,
                                ).undoClose(a.id, a.revision, reason: reason);
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _error = e);
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _busy = false);
                                }
                              }
                            },
                      icon: const Icon(Icons.unarchive_outlined),
                      label: Text(
                        _busy
                            ? context.tr('Restoring…')
                            : context.tr('Undo closure'),
                      ),
                    ),
                  ],
                ],
              ),
              if (_error != null) FailureNotice(_error!),
              const SizedBox(height: 28),
              SectionHeading(context.tr('About this item')),
              Text(
                context.tr(
                  "Price paid for the whole item: {price}\nPurchase date: {date}",
                  {
                    'price': a.purchaseTotalMinor == null
                        ? context.tr('Unrecorded')
                        : formatInr(BigInt.from(a.purchaseTotalMinor!)),
                    'date': a.purchasedOn ?? context.tr('Unrecorded'),
                  },
                ),
              ),
              if (property != null) ...[
                const SizedBox(height: 12),
                Text('${property.city}\n${property.location}'),
                if (property.areaMilli != null)
                  Text(
                    context.tr("Area: {size} {unit}", {
                      'size': FixedDecimal.format(
                        property.areaMilli!,
                        scale: 3,
                      ),
                      'unit': property.areaUnit,
                    }),
                  ),
                if (property.recordReference?.isNotEmpty == true)
                  Text(
                    context.tr("Record reference: {record}", {
                      'record': property.recordReference,
                    }),
                  ),
              ],
              if (metal != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${FixedDecimal.format(metal.weightMg, scale: 3)} g ${context.tr(metal.metal)}\n${metal.purityPpm == null ? context.tr('Purity unrecorded') : '${FixedDecimal.format(metal.purityPpm!, scale: 4)}% · ${context.tr(metal.purityKind)}${metal.karat == null ? '' : ' ${metal.karat}K'}'}',
                ),
                Text(
                  context.tr("Purchase rate: {rate}\nMaking charges: {charge}", {
                    'rate': metal.purchaseRateMinorPerGram == null
                        ? context.tr('Unrecorded')
                        : '${formatInr(BigInt.from(metal.purchaseRateMinorPerGram!))}/g',
                    'charge': metal.makingChargesMinor == null
                        ? context.tr('Unrecorded')
                        : formatInr(BigInt.from(metal.makingChargesMinor!)),
                  }),
                ),
              ],
              if (investment != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${investment.instrument}${investment.symbol == null ? '' : ' · ${investment.symbol}'}',
                ),
                if (investment.quantityScaled != null)
                  Text(
                    context.tr("Units: {quantity}", {
                      'quantity': FixedDecimal.format(
                        investment.quantityScaled!,
                        scale: investment.quantityScale!,
                      ),
                    }),
                  ),
              ],
              if (a.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(a.notes),
              ],
              const SizedBox(height: 24),
              SectionHeading(context.tr('Who owns it')),
              if (owners.isEmpty)
                Text(
                  context.tr(
                    'Individual shares haven’t been added. Everyone approved for this family can see this item.',
                  ),
                ),
              for (final o in owners)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(o.ownerLabel),
                  subtitle: Text(
                    context.tr("{share}% of the whole holding", {
                      'share': FixedDecimal.format(o.shareBps, scale: 2),
                    }),
                  ),
                ),
              const SizedBox(height: 24),
              SectionHeading(context.tr('Value over time')),
              if (history.isEmpty)
                Text(
                  context.tr(
                    'No valuation recorded. A missing value is excluded from recorded net worth.',
                  ),
                ),
              for (final v in history)
                Card.outlined(
                  child: ListTile(
                    title: Text(
                      '${v.valuedOn} · ${v.source.replaceAll('_', ' ')}',
                    ),
                    subtitle: Text(
                      context.tr("Whole: {whole}\nFamily: {share}\n{note}", {
                        'whole': formatInr(BigInt.from(v.totalValueMinor)),
                        'share': formatInr(BigInt.from(v.familyValueMinor)),
                        'note': v.notes,
                      }),
                    ),
                    trailing: v.journalId == null
                        ? null
                        : const Icon(Icons.chevron_right),
                    onTap: v.journalId == null
                        ? null
                        : () => context.push('/transaction/${v.journalId}'),
                  ),
                ),
              const SizedBox(height: 24),
              LinkedDocuments(assetId: a.id),
              SectionHeading(context.tr('Linked accounting history')),
              for (final j in journals)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(j.description),
                  subtitle: Text(
                    '${j.occurredOn} · ${j.kind}${j.deletedAtUs == null ? '' : ' · Reversed'}',
                  ),
                  trailing:
                      finance.journalLinks[j.id]?.purpose == 'rent' &&
                          j.deletedAtUs == null
                      ? IconButton(
                          tooltip: context.tr('Reverse rent'),
                          icon: const Icon(Icons.undo),
                          onPressed: _busy ? null : () => _reverseRent(a, j.id),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () => context.push('/transaction/${j.id}'),
                ),
              const SizedBox(height: 24),
              RecordAudit(entityId: a.id),
            ],
          );
        },
      ),
    ),
  );
  Future<void> _reverseRent(WealthAsset a, String journalId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => ReasonDialog(
        title: context.tr('Reverse this rent entry?'),
        message: context.tr(
          'Its original entry stays in the accounting history.',
        ),
        confirmLabel: context.tr('Reverse rent'),
      ),
    );
    if (reason == null || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = ref.read(vaultProvider).session!;
      await AssetRepository(session.ledger)
          .reverseRent(a.id, a.revision, journalId, reason);
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
