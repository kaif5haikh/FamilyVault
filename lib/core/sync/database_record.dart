import 'package:drift/drift.dart';

/// Stable SQL field names in aggregate envelopes, independent of Dart casing.
Map<String, Object?> databaseRecord(DataClass row) => {
  for (final entry in row.toJson().entries)
    entry.key.replaceAllMapped(
      RegExp('[A-Z]'),
      (m) => '_${m[0]!.toLowerCase()}',
    ): entry.value,
};
