import 'package:material_ui/material_ui.dart';

import '../../core/errors/app_failure.dart';
import '../../core/finance/fixed_decimal.dart';
import '../../core/finance/money.dart';
import '../../core/localization/vault_strings.dart';
import '../../features/finance/data/ledger_repository.dart';
import 'vault_widgets.dart';

class RecordField extends StatelessWidget {
  const RecordField(
    this.label,
    this.controller, {
    super.key,
    this.required = false,
    this.money = false,
    this.scale,
    this.enabled = true,
    this.hint,
    this.lines = 1,
    this.maxLength = 120,
    this.allowNegative = false,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final bool required, money, enabled, allowNegative;
  final int? scale;
  final String? hint;
  final int lines, maxLength;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: lines,
      onChanged: onChanged,
      maxLength: money || scale != null ? 40 : maxLength,
      keyboardType: money || scale != null
          ? TextInputType.numberWithOptions(
              decimal: true,
              signed: allowNegative,
            )
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      textCapitalization: money || scale != null
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 5,
        prefixText: money ? '₹ ' : null,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return required ? context.tr(requiredText(v)!) : null;
        }
        try {
          final value = money
              ? Money.parseInr(v).minor
              : scale != null
              ? FixedDecimal.parse(v, scale: scale!, signed: allowNegative)
              : null;
          if (value != null && !allowNegative && value < 0) {
            return context.tr('Enter zero or a positive amount.');
          }
        } on AppFailure catch (e) {
          return VaultStrings.of(context).failure(e);
        }
        return null;
      },
    ),
  );
}

class RecordDate extends StatelessWidget {
  const RecordDate(
    this.label,
    this.value,
    this.onChanged, {
    super.key,
    this.enabled = true,
  });
  final String label, value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: OutlinedButton.icon(
      onPressed: !enabled
          ? null
          : () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(value),
                firstDate: DateTime(1900),
                lastDate: DateTime(2200, 12, 31),
              );
              if (date != null && context.mounted) {
                onChanged(LedgerRepository.dateOnly(date));
              }
            },
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text('$label: $value'),
    ),
  );
}

class RecordChoice<T> extends StatelessWidget {
  const RecordChoice(
    this.label,
    this.value,
    this.items,
    this.onChanged, {
    super.key,
    this.enabled = true,
  });
  final String label;
  final T? value;
  final List<(T, String)> items;
  final bool enabled;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: DropdownButtonFormField<T>(
      key: ValueKey('$label/$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item.$1,
            child: Text(item.$2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: !enabled
          ? null
          : (v) {
              if (v != null) {
                onChanged(v);
              }
            },
      validator: (v) => v == null ? context.tr('Choose an option.') : null,
    ),
  );
}

String? optionalText(TextEditingController controller) =>
    controller.text.trim().isEmpty ? null : controller.text.trim();
int? optionalMinor(TextEditingController controller) =>
    optionalText(controller) == null
    ? null
    : Money.parseInr(controller.text).minor;
String minorInput(int value) {
  final digits = BigInt.from(value).abs().toString().padLeft(3, '0');
  return '${value < 0 ? '-' : ''}${digits.substring(0, digits.length - 2)}.${digits.substring(digits.length - 2)}';
}
