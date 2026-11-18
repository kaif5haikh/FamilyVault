import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:familyvault/app/app.dart';
import 'package:familyvault/app/router.dart';
import 'package:familyvault/app/vault_providers.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/document_vault/document_inputs.dart';
import 'package:familyvault/features/document_vault/document_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../support/security_fakes.dart';
import '../support/widget_io.dart';

class _Picker implements DocumentIo {
  final picked = Completer<SelectedDocument?>();
  DocumentPicker? mode;
  Digest? written;
  String? mimeType;

  @override
  Future<SelectedDocument?> pick(DocumentPicker picker) {
    mode = picker;
    return picked.future;
  }

  @override
  Future<bool> save({
    required String name,
    required String mime,
    required Uint8List bytes,
  }) async {
    written = sha256.convert(bytes);
    mimeType = mime;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PDFium renders a generated sample from bytes', () async {
    final root = await Directory('.cache/test-vaults').create(recursive: true);
    final scratch = await root.createTemp('pdf-preview-');
    addTearDown(() => scratch.delete(recursive: true));
    Pdfrx.cacheDirectoryPath = scratch.path;
    await pdfrxFlutterInitialize();
    final file = await PdfDocument.openData(
      _samplePdf(),
      sourceName: 'synthetic-preview',
    );
    try {
      expect(file.pages, hasLength(1));
      final page = await file.pages.single.render(width: 64, height: 64);
      expect(page, isNotNull);
      page!.dispose();
    } finally {
      await file.dispose();
    }
  });
  testWidgets(
    'document picker can pause and lock, then resume the encrypted import after unlock',
    (tester) async {
      final storage = (await tester.runAsync(() async {
        final parent = await Directory('.cache/test-vaults')
            .create(recursive: true);
        return parent.createTemp('documents-ui-');
      }))!;
      final gate = FakeDeviceGate();
      final lifecycle = VaultLifecycle(
        store: MemorySecureStore(),
        gate: gate,
        root: () async => storage,
      );
      final io = _Picker();
      final image = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAD0lEQVR4nGNg+M8AQhAKABvyA/1tVLjHAAAAAElFTkSuQmCC',
      );
      final container = ProviderContainer(
        overrides: [
          vaultLifecycleProvider.overrideWithValue(lifecycle),
          documentIoProvider.overrideWithValue(io),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await lifecycle.dispose();
        await storage.delete(recursive: true);
      });
      await tester.runAsync(() async {
        await lifecycle.initialize();
        await lifecycle.createOffline(
          familyName: 'Synthetic vault',
          ownerName: 'Synthetic owner',
        );
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FamilyVaultApp(),
        ),
      );
      await tester.pump();
      container.read(routerProvider).go('/documents');
      await ready(tester, find.text('Add'));
      await tapVisible(tester, find.text('Add'));
      await tapVisible(tester, find.text('Choose a file'));
      expect(io.mode, DocumentPicker.files);

      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      expect(lifecycle.status.phase, VaultPhase.locked);
      io.picked.complete(
        SelectedDocument(
          'Synthetic scan',
          DocumentInput(
            length: () async => image.length,
            openRead: () =>
                Stream.fromIterable([image.sublist(0, 4), image.sublist(4)]),
          ),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tapVisible(tester, find.text('Unlock vault'));
      await ready(tester, field('Document title'));
      expect(gate.calls, greaterThanOrEqualTo(2));
      await tapVisible(tester, find.text('Save document'));
      final saved = find.widgetWithText(ListTile, 'Synthetic scan');
      await ready(tester, saved);
      expect(container.read(documentIntakeProvider), isNull);

      await tapVisible(tester, saved);
      await ready(tester, find.text('Version 1'));
      await tapVisible(tester, find.text('Version 1'));
      await ready(tester, find.byType(InteractiveViewer));
      expect(find.text('This image could not be opened.'), findsNothing);
      await tapVisible(tester, find.byTooltip('Save a copy'));
      await ready(tester, find.text('Document saved.'));
      expect(io.mimeType, 'image/png');
      expect(io.written, sha256.convert(image));
      final vault = lifecycle.status.session!.db;
      final audits = await databaseIO(
        tester,
        () => vault.select(vault.localAuditEvents).get(),
      );
      expect(
        audits
            .where((row) => row.entityType == 'document_access')
            .map((row) => row.action),
        unorderedEquals(['preview', 'download']),
      );
      expect(tester.takeException(), isNull);
      await databaseIO(tester, lifecycle.lock);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Uint8List _samplePdf() {
  const paint = '0 1 0 rg\n0 0 64 64 re f\n';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Count 1 /Kids [3 0 R] >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 64 64] /Resources << >> /Contents 4 0 R >>',
    '<< /Length ${paint.length} >>\nstream\n$paint'
        'endstream',
  ];
  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var index = 0; index < objects.length; index++) {
    offsets.add(pdf.length);
    pdf.write('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
  }
  final xref = pdf.length;
  pdf.write('xref\n0 5\n0000000000 65535 f \n');
  for (final offset in offsets) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write('trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return Uint8List.fromList(ascii.encode(pdf.toString()));
}
