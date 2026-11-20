import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/appearance.dart';
import '../../core/localization/vault_strings.dart';

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appearanceProvider).locale;
    return DropdownButtonFormField<Locale>(
      key: ValueKey('language-${locale.languageCode}'),
      initialValue: locale,
      isExpanded: true,
      decoration: InputDecoration(labelText: context.tr('Language')),
      items: [
        for (final (choice, name) in languageChoices)
          DropdownMenuItem(value: choice, child: Text(name)),
      ],
      onChanged: (choice) =>
          ref.read(appearanceProvider.notifier).change(locale: choice),
    );
  }
}
