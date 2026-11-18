import 'package:drift/drift.dart';

import '../errors/app_failure.dart';
import 'canonical_json.dart';

/// Stable SQL field names in aggregate envelopes, independent of Dart casing.
Map<String, Object?> databaseRecord(DataClass row) => {
  for (final entry in row.toJson().entries)
    entry.key.replaceAllMapped(
      RegExp('[A-Z]'),
      (m) => '_${m[0]!.toLowerCase()}',
    ): entry.value,
};

/// Decode a complete SQL-shaped record using a generated Drift JSON reader.
T readDatabaseRecord<T extends DataClass>(
  Map<String, Object?> value,
  T Function(Map<String, Object?>) decode,
) {
  try {
    final row = decode({
      for (final entry in value.entries)
        entry.key.replaceAllMapped(
          RegExp('_[a-z]'),
          (match) => match[0]![1].toUpperCase(),
        ): entry.value,
    });
    if (canonicalJson(databaseRecord(row)) == canonicalJson(value)) {
      return row;
    }
  } catch (_) {
    // Do not expose row values in decoding errors.
  }
  throw const AppFailure(
    FailureCode.integrity,
    'The family service sent an invalid record.',
  );
}
