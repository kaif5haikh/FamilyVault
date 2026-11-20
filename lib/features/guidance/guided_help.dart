import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/vault_providers.dart';
import '../../core/localization/vault_strings.dart';
import '../../shared/widgets/vault_widgets.dart';
import '../foundation/foundation_pages.dart' show VaultPage;

enum HelpTopic {
  received(
    Icons.south_west_rounded,
    '/transaction/new?kind=income&guide=1',
    'income salary deposit add money आमदनी तनख़्वाह पगार आय',
  ),
  spent(
    Icons.north_east_rounded,
    '/transaction/new?kind=expense&guide=1',
    'expense bill spending add money ख़र्च भुगतान बिल राशन',
  ),
  move(
    Icons.swap_horiz_rounded,
    '/transaction/new?kind=transfer&guide=1',
    'transfer move money ट्रांसफ़र जमा',
  ),
  available(
    Icons.account_balance_wallet_outlined,
    '/accounts',
    'balance cash available savings money नकद बचत बाकी बैलेंस',
  ),
  bank(
    Icons.account_balance_outlined,
    '/account/new?subtype=bank',
    'bank cash account add money बैंक खाता अकाउंट',
  ),
  gold(
    Icons.diamond_outlined,
    '/asset/new?kind=gold',
    'gold jewellery jewelry metal सोने सोना गहने',
  ),
  property(
    Icons.home_work_outlined,
    '/asset/new?kind=property',
    'property house home land मालमत्ता',
  ),
  vehicle(
    Icons.directions_car_outlined,
    '/asset/new?kind=vehicle',
    'car bike vehicle वाहन',
  ),
  loan(
    Icons.request_quote_outlined,
    '/loan/new',
    'loan lending borrowing debt emi कर्ज',
  ),
  addPaper(
    Icons.note_add_outlined,
    '/documents?guide=add',
    'document paper upload scan photo file add डॉक्यूमेंट फ़ाइल कागज़ जोड़ें',
  ),
  findPaper(
    Icons.folder_open_outlined,
    '/documents?guide=find',
    'document paper find locate file search डॉक्यूमेंट फ़ाइल कागज़ ढूँढें',
  ),
  copy(
    Icons.cloud_upload_outlined,
    '/backups',
    'backup safe copy drive export recovery बैकअप कॉपी',
  ),
  recover(
    Icons.settings_backup_restore,
    '/restore',
    'backup safe copy restore recovery bring back बैकअप रिस्टोर फ़ाइल',
  ),
  invite(
    Icons.person_add_alt_outlined,
    '/family',
    'family member invite sign in add access न्योता बुलाएँ इजाज़त',
  ),
  own(
    Icons.inventory_2_outlined,
    '/assets',
    'own asset gold property belongings worth value',
  ),
  owe(
    Icons.payments_outlined,
    '/loans',
    'owe liability debt repayment unpaid amount loan',
  );

  const HelpTopic(this.icon, this.location, this.keywords);

  final IconData icon;
  final String location, keywords;

  String title(VaultStrings strings) => strings.text('help.$name.title');
  String first(VaultStrings strings) => strings.text('help.$name.first');
  String second(VaultStrings strings) => strings.text('help.$name.second');

  static Iterable<HelpTopic> search(String query, VaultStrings strings) {
    final words = _searchText(query)
        .split(RegExp(r'[\s,.?!]+'))
        .where((part) => part.isNotEmpty);
    return values.where((topic) {
      final terms = _searchText('${topic.title(strings)} ${topic.keywords}');
      return words.every(terms.contains);
    });
  }

  static String _searchText(String value) => value
      .toLowerCase()
      .replaceAll('\u093c', '')
      .replaceAllMapped(
        RegExp(r'[क़ख़ग़ज़ड़ढ़फ़य़]'),
        (match) => 'कखगजडढफय'['क़ख़ग़ज़ड़ढ़फ़य़'.indexOf(match[0]!)],
      );
}

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    final topics = HelpTopic.search(_query.trim(), strings).toList();
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('help'))),
      body: VaultContent(
        maxWidth: 680,
        children: [
          TextField(
            key: const ValueKey('help-search'),
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              labelText: strings.text('helpSearch'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (topics.isEmpty)
            EmptyNotice(
              icon: Icons.search_off_outlined,
              title: strings.text('helpSearch'),
              message: strings.text('helpEmpty'),
            ),
          for (final topic in topics)
            VaultLink(
              icon: topic.icon,
              title: topic.title(strings),
              onTap: () => context.push('/help/${topic.name}'),
            ),
        ],
      ),
    );
  }
}

class TopicGuidePage extends ConsumerStatefulWidget {
  const TopicGuidePage(this.topic, {super.key});
  final HelpTopic topic;

  @override
  ConsumerState<TopicGuidePage> createState() => _TopicGuidePageState();
}

class _TopicGuidePageState extends ConsumerState<TopicGuidePage> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    final topic = widget.topic;
    final status = ref.watch(vaultProvider);
    final session = status.session;
    final open = session != null && !session.closed;
    final canGo = topic == HelpTopic.recover ? !status.hasVault : open;
    return GuideFrame(
      title: strings.text('help'),
      heading: _step == 0 ? topic.title(strings) : strings.text('guideReady'),
      explanation: _step == 0 ? topic.first(strings) : topic.second(strings),
      icon: topic.icon,
      step: _step,
      count: 2,
      onBack: _step == 0 ? null : () => setState(() => _step--),
      closeLabel: strings.text('exitGuide'),
      onClose: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/help');
        }
      },
      primaryLabel: strings.text(_step == 0 ? 'next' : 'openScreen'),
      onNext: _step == 0
          ? () => setState(() => _step++)
          : canGo
          ? () {
              if (topic == HelpTopic.addPaper ||
                  topic == HelpTopic.findPaper ||
                  topic == HelpTopic.invite) {
                context.go(topic.location);
              } else {
                context.push(topic.location);
              }
            }
          : null,
      note: _step == 1 && !canGo
          ? topic == HelpTopic.recover
                ? strings.text('help.recover.first')
                : strings.text('guideNeedsUnlock')
          : null,
    );
  }
}

class GuideFrame extends StatelessWidget {
  const GuideFrame({
    required this.title,
    required this.heading,
    required this.explanation,
    required this.icon,
    required this.step,
    required this.count,
    required this.primaryLabel,
    required this.onNext,
    required this.closeLabel,
    required this.onClose,
    this.onBack,
    this.note,
    super.key,
  });

  final String title, heading, explanation, primaryLabel, closeLabel;
  final IconData icon;
  final int step, count;
  final VoidCallback? onNext, onBack;
  final VoidCallback onClose;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    final theme = Theme.of(context);
    final progress = strings
        .text('step')
        .replaceAll('{current}', '${step + 1}')
        .replaceAll('{total}', '$count');
    return VaultPage(
      title: title,
      children: [
        Semantics(
          label: progress,
          child: ExcludeSemantics(
            child: LinearProgressIndicator(value: (step + 1) / count),
          ),
        ),
        const SizedBox(height: 12),
        Text(progress, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: VaultIcon(icon: icon, size: 32),
        ),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(heading, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: 10),
        Text(explanation, style: theme.textTheme.bodyLarge),
        if (note case final message?) ...[
          const SizedBox(height: 12),
          Text(message),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: onNext, child: Text(primaryLabel)),
        ),
        Wrap(
          spacing: 8,
          children: [
            if (onBack != null)
              TextButton(onPressed: onBack, child: Text(strings.text('back'))),
            TextButton(onPressed: onClose, child: Text(closeLabel)),
          ],
        ),
      ],
    );
  }
}
