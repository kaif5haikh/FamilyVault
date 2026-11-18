import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/vault_providers.dart';
import '../../../shared/widgets/record_fields.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../data/business_repository.dart';
import 'business_pages.dart';

enum BusinessRecordKind {
  business('Business', 'business'),
  stock('Stock item', 'stock'),
  worker('Worker', 'worker');

  const BusinessRecordKind(this.label, this.route);
  final String label, route;
}

class BusinessRecordEditor extends ConsumerStatefulWidget {
  const BusinessRecordEditor({
    required this.kind,
    super.key,
    this.id,
    this.businessId,
  });
  final BusinessRecordKind kind;
  final String? id, businessId;
  @override
  ConsumerState<BusinessRecordEditor> createState() =>
      _BusinessRecordEditorState();
}

class _BusinessRecordEditorState extends ConsumerState<BusinessRecordEditor> {
  final _name = TextEditingController(), _sku = TextEditingController();
  final _notes = TextEditingController(), _salary = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _operationId, _businessId;
  int? _revision;
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    for (final controller in [_name, _sku, _notes, _salary]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _load(BusinessSnapshot data) {
    if (_revision != null) {
      return true;
    }
    if (widget.id == null) {
      _businessId = widget.businessId;
      return widget.kind == BusinessRecordKind.business ||
          data.businesses.any(
            (b) => b.id == _businessId && b.deletedAtUs == null,
          );
    }
    switch (widget.kind) {
      case BusinessRecordKind.business:
        final row = data.businesses
            .where((v) => v.id == widget.id && v.deletedAtUs == null)
            .firstOrNull;
        if (row == null) {
          return false;
        }
        _name.text = row.name;
        _notes.text = row.notes;
        _revision = row.revision;
      case BusinessRecordKind.stock:
        final row = data.items
            .where((v) => v.id == widget.id && v.deletedAtUs == null)
            .firstOrNull;
        if (row == null) {
          return false;
        }
        _name.text = row.name;
        _sku.text = row.sku ?? '';
        _businessId = row.businessId;
        _revision = row.revision;
      case BusinessRecordKind.worker:
        final row = data.workers
            .where((v) => v.id == widget.id && v.deletedAtUs == null)
            .firstOrNull;
        if (row == null) {
          return false;
        }
        _name.text = row.name;
        _notes.text = row.notes;
        _salary.text = row.monthlySalaryMinor == null
            ? ''
            : minorInput(row.monthlySalaryMinor!);
        _businessId = row.businessId;
        _revision = row.revision;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.id == null ? 'Add' : 'Edit'} ${widget.kind.label.toLowerCase()}',
      ),
    ),
    body: BusinessView(
      builder: (data, _) {
        if (!_load(data)) {
          return const VaultContent(
            children: [Text('This record is unavailable for editing.')],
          );
        }
        return VaultContent(
          maxWidth: 680,
          children: [
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RecordField(
                    '${widget.kind.label} name',
                    _name,
                    required: true,
                    maxLength: widget.kind == BusinessRecordKind.business
                        ? 96
                        : 120,
                    enabled: !_busy,
                  ),
                  if (widget.kind == BusinessRecordKind.stock)
                    RecordField(
                      'SKU or product code (optional)',
                      _sku,
                      maxLength: 80,
                      enabled: !_busy,
                    ),
                  if (widget.kind == BusinessRecordKind.worker)
                    RecordField(
                      'Agreed monthly wages (optional)',
                      _salary,
                      money: true,
                      enabled: !_busy,
                      hint: 'Record the actual amounts paid from the worker’s history.',
                    ),
                  if (widget.kind != BusinessRecordKind.stock)
                    RecordField(
                      'Notes (optional)',
                      _notes,
                      lines: 3,
                      maxLength: 4000,
                      enabled: !_busy,
                    ),
                  if (_error != null) FailureNotice(_error!),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _busy
                          ? 'Saving…'
                          : 'Save ${widget.kind.label.toLowerCase()}',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = ref.read(vaultProvider).session!,
          repo = BusinessRepository(session.ledger);
      _operationId ??= session.ledger.operationId();
      final id = widget.id;
      final result = await switch (widget.kind) {
        BusinessRecordKind.business =>
          id == null
              ? repo.create(
                  name: _name.text,
                  notes: _notes.text,
                  operationId: _operationId,
                )
              : repo.edit(
                  id,
                  _revision!,
                  name: _name.text,
                  notes: _notes.text,
                  operationId: _operationId,
                ),
        BusinessRecordKind.stock => repo.saveItem(
          businessId: _businessId!,
          name: _name.text,
          sku: optionalText(_sku),
          id: id,
          revision: _revision ?? 0,
          operationId: _operationId,
        ),
        BusinessRecordKind.worker => repo.saveWorker(
          businessId: _businessId!,
          name: _name.text,
          notes: _notes.text,
          expectedMonthlyMinor: optionalMinor(_salary),
          id: id,
          revision: _revision ?? 0,
          operationId: _operationId,
        ),
      };
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
        if (id != null && context.canPop()) {
          context.pop();
        } else {
          context.pushReplacement('/${widget.kind.route}/$result');
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
