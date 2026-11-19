import 'dart:io';

import 'package:familyvault/app/app.dart';
import 'package:familyvault/app/vault_providers.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/backup/backup_archive.dart';
import 'package:familyvault/features/backup/backup_file_io.dart';
import 'package:familyvault/features/backup/vault_backup.dart';
import 'package:familyvault/shared/widgets/vault_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show FilledButton, Text;

import '../support/security_fakes.dart';
import '../support/widget_io.dart';

final class _Picker implements BackupFilePicker {
  const _Picker(this.file);
  final File file;
  @override
  Future<BackupInput?> pick() async =>
      (length: file.length, openRead: file.openRead);
}

void main() {
  testWidgets(
    'restore flow verifies a selected file before creating a new vault',
    (tester) async {
      final fixture = (await tester.runAsync(() async {
        final parent = await Directory('.cache/test-vaults')
            .create(recursive: true);
        final root = await parent.createTemp('backup-widget-');
        final source = VaultLifecycle(
          store: MemorySecureStore(),
          gate: FakeDeviceGate(),
          root: () async => Directory('${root.path}/source'),
        );
        final key = BackupRecoveryKey.generate();
        try {
          await source.initialize();
          await source.createOffline(
            familyName: 'Synthetic restored family',
            ownerName: 'Synthetic owner',
          );
          final artifact = await VaultBackup(Directory('${root.path}/staging'))
              .capture(
                session: source.status.session!,
                destination: Directory('${root.path}/out'),
                recovery: key,
              );
          return (
            root: root,
            artifact: artifact,
            code: key.code,
            family: source.status.session!.identity.familyId,
          );
        } finally {
          key.destroy();
          await source.dispose();
        }
      }))!;
      final gate = FakeDeviceGate();
      final target = VaultLifecycle(
        store: MemorySecureStore(),
        gate: gate,
        root: () async => Directory('${fixture.root.path}/target'),
      );
      final container = ProviderContainer(
        overrides: [
          vaultLifecycleProvider.overrideWithValue(target),
          backupFilePickerProvider.overrideWithValue(
            _Picker(fixture.artifact.file),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await target.dispose();
        await fixture.root.delete(recursive: true);
      });
      await tester.runAsync(target.initialize);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FamilyVaultApp(),
        ),
      );
      await ready(tester, find.text('Family access'));
      await tapVisible(tester, find.text('Family access'));
      await ready(tester, find.text('Restore an encrypted backup'));
      await tapVisible(tester, find.text('Restore an encrypted backup'));
      await tapVisible(tester, find.text('Choose a backup file'));
      await ready(tester, field('Recovery key'));
      await tester.enterText(field('Recovery key'), fixture.code);
      Future<void> activate(String label) async {
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, label),
        );
        // The native snapshot opens a new SQLite isolate. Run that callback
        // outside the widget harness's simulated clock.
        await tester.runAsync(button.onPressed! as Future<void> Function());
        await tester.pump();
      }

      await activate('Verify backup');
      await ready(
        tester,
        find.byWidgetPredicate(
          (w) => w is FailureNotice || w is Text && w.data == 'Restore vault',
        ),
      );
      final notices = tester.widgetList<FailureNotice>(
        find.byType(FailureNotice),
      );
      expect(
        notices.map(
          (w) => w.error is AppFailure
              ? (w.error as AppFailure).message
              : w.error.runtimeType.toString(),
        ),
        isEmpty,
      );
      expect(target.status.phase, VaultPhase.setup);
      expect(gate.calls, 0);
      await activate('Restore vault');
      expect(target.status.phase, VaultPhase.open);
      await ready(tester, find.text('On this device'));
      expect(target.status.session!.identity.familyId, fixture.family);
      expect(gate.calls, 1);
    },
  );
}
