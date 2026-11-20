import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/vault_providers.dart';
import '../../app/theme.dart';
import '../../core/errors/app_failure.dart';
import '../../core/localization/vault_strings.dart';
import '../../features/finance/data/ledger_repository.dart';

class VaultContent extends StatelessWidget {
  const VaultContent({
    required this.children,
    super.key,
    this.maxWidth = 1120,
    this.scrollKey,
  });
  final List<Widget> children;
  final double maxWidth;
  final Key? scrollKey;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          key: scrollKey,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? VaultTheme.gutter : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class VaultIcon extends StatelessWidget {
  const VaultIcon({required this.icon, this.size = 20, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: size, color: colors.onSecondaryContainer),
      ),
    );
  }
}

class VaultLink extends StatelessWidget {
  const VaultLink({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                VaultIcon(icon: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle case final detail?)
                        Text(
                          detail,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class FinanceView extends ConsumerWidget {
  const FinanceView({required this.builder, super.key});
  final Widget Function(FinanceSnapshot) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(financeProvider)
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => VaultContent(
          children: [
            FailureNotice(error),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(financeProvider),
              icon: const Icon(Icons.refresh),
              label: Text(VaultStrings.of(context).text('tryAgain')),
            ),
          ],
        ),
        data: builder,
      );
}

class FailureNotice extends StatelessWidget {
  const FailureNotice(this.error, {super.key});
  final Object error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card.filled(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          error is AppFailure
              ? (error as AppFailure).message
              : VaultStrings.of(context).text('unknownError'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    ),
  );
}

class EmptyNotice extends StatelessWidget {
  const EmptyNotice({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(VaultTheme.space),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(message),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: VaultTheme.gap),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 12,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    ),
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    super.key,
    this.detail,
    this.emphasis = false,
  });
  final String title, value;
  final String? detail;
  final IconData icon;
  final bool emphasis;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.filled(
      color: emphasis ? colors.primaryContainer : colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(VaultTheme.space),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(title)),
              ],
            ),
            const SizedBox(height: VaultTheme.gap),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(detail!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class ResponsiveCards extends StatelessWidget {
  const ResponsiveCards({
    required this.children,
    super.key,
    this.minimumWidth = 260,
  });
  final List<Widget> children;
  final double minimumWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final count = (constraints.maxWidth / (minimumWidth * scale))
          .floor()
          .clamp(1, 4);
      final width = (constraints.maxWidth - 16 * (count - 1)) / count;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

void savedNotice(BuildContext context, {bool cloud = false, String? message}) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Semantics(
          liveRegion: true,
          child: Text(
            cloud
                ? VaultStrings.of(context).text('savedWaiting')
                : message ?? VaultStrings.of(context).text('savedLocal'),
          ),
        ),
      ),
    );

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

class ReasonDialog extends StatefulWidget {
  const ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    super.key,
  });
  final String title, message, confirmLabel;
  @override
  State<ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<ReasonDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reason,
              maxLength: 400,
              decoration: const InputDecoration(labelText: 'Reason'),
              validator: requiredText,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _reason.text.trim());
          }
        },
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
