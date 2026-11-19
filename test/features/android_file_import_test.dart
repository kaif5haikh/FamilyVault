import 'package:familyvault/core/files/android_picked_file.dart';
import 'package:familyvault/features/document_vault/document_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.familyvault/file-imports');
  const uri = 'content://app.familyvault.validation.files/synthetic';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final payload = Uint8List.fromList('%PDF-1.7\nSynthetic'.codeUnits);
  const mimeTypes = ['application/pdf', 'image/jpeg', 'image/png'];
  late Map<int, int> readers;
  late int opened, reads;
  late bool cancelled, readFails;
  int? reportedLength;

  setUp(() {
    readers = {};
    opened = reads = 0;
    cancelled = readFails = false;
    reportedLength = payload.length;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'pick':
          expect(call.arguments, mimeTypes);
          return cancelled
              ? null
              : {'uri': uri, 'name': 'Synthetic.pdf', 'length': reportedLength};
        case 'open':
          expect(call.arguments, uri);
          readers[++opened] = 0;
          return opened;
        case 'read':
          final id = call.arguments as int;
          final start = readers[id]!;
          reads++;
          if (readFails) throw PlatformException(code: 'file_unavailable');
          if (start == payload.length) return null;
          final end = (start + 8).clamp(0, payload.length);
          readers[id] = end;
          return payload.sublist(start, end);
        case 'close':
          readers.remove(call.arguments);
          return null;
        default:
          fail('Unexpected file import call ${call.method}');
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    expect(readers, isEmpty);
  });

  test('closes the header reader and reopens the URI for encryption', () async {
    final selected = (await AndroidPickedFile.pick(mimeTypes))!;
    expect(selected.name, 'Synthetic.pdf');
    final input = DocumentInput(
      length: selected.length,
      openRead: selected.openRead,
    );
    final checked = await DocumentFormat.inspect(input);
    expect(checked, (format: DocumentFormat.pdf, bytes: payload.length));
    expect(readers, isEmpty);
    expect(opened, 1);
    expect(reads, 1);
    expect(await input.openRead().expand((chunk) => chunk).toList(), payload);
    expect(opened, 2);
  });

  test(
    'stops the missing-length probe as soon as the limit is exceeded',
    () async {
      reportedLength = null;
      final selected = (await AndroidPickedFile.pick(mimeTypes))!;
      expect(await selected.length(probeLimit: 10), 16);
      expect(reads, 2);
      expect(readers, isEmpty);
      expect(await selected.length(), payload.length);
    },
  );

  test('closes an interrupted file stream', () async {
    final selected = (await AndroidPickedFile.pick(mimeTypes))!;
    readFails = true;
    await expectLater(
      selected.openRead(),
      emitsError(isA<PlatformException>()),
    );
  });

  test('cancelling the picker opens no file stream', () async {
    cancelled = true;
    expect(await AndroidPickedFile.pick(mimeTypes), isNull);
    expect(opened, 0);
  });
}
