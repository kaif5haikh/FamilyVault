import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/vault_providers.dart';
import '../../core/localization/vault_strings.dart';
import 'guided_help.dart';

const _introKey = 'ui.intro.v1';

final introSeenProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.watch(secureStoreProvider).read(_introKey) == 'done';
  } catch (_) {
    return false;
  }
});

Future<void> finishIntro(WidgetRef ref) async {
  try {
    await ref.read(secureStoreProvider).write(_introKey, 'done');
  } catch (_) {
    // The tour is optional. Device verification still gates all records.
  }
}

class WelcomeTourPage extends ConsumerStatefulWidget {
  const WelcomeTourPage({super.key});

  @override
  ConsumerState<WelcomeTourPage> createState() => _WelcomeTourPageState();
}

class _WelcomeTourPageState extends ConsumerState<WelcomeTourPage> {
  static const _steps = [
    ('money', Icons.account_balance_wallet_outlined),
    ('papers', Icons.folder_outlined),
    ('family', Icons.group_outlined),
    ('copies', Icons.shield_outlined),
  ];
  int _step = 0;
  bool _finishing = false;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await finishIntro(ref);
    if (!mounted) return;
    ref.invalidate(introSeenProvider);
    final session = ref.read(vaultProvider).session;
    if (session != null && !session.closed) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else {
      context.pushReplacement('/access');
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    final (name, icon) = _steps[_step];
    final last = _step == _steps.length - 1;
    return GuideFrame(
      title: strings.text('seeGuide'),
      heading: strings.text('tour.$name.title'),
      explanation: strings.text('tour.$name.body'),
      icon: icon,
      step: _step,
      count: _steps.length,
      onBack: _step == 0 ? null : () => setState(() => _step--),
      onClose: _finish,
      closeLabel: strings.text('skip'),
      primaryLabel: strings.text(last ? 'start' : 'next'),
      onNext: _finishing
          ? null
          : last
          ? _finish
          : () => setState(() => _step++),
    );
  }
}
