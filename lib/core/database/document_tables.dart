import 'package:drift/drift.dart';

import 'finance_tables.dart';
// Drift resolves the SQL foreign key through this import.
// ignore: unused_import
import 'wealth_tables.dart';

const documentByteLimit = 24 * 1024 * 1024;

enum DocumentCategory {
  aadhaar,
  pan,
  passport,
  drivingLicence,
  voterId,
  property,
  utilities,
  education,
  medical,
  insurance,
  general,
}

@DataClassName('VaultDocument')
class VaultDocuments extends Table with FamilyProvenance {
  TextColumn get title => text()();
  TextColumn get category => text()();
  TextColumn get ownerId => text()();
  TextColumn get expiryOn => text().nullable()();

  @override
  List<String> get customConstraints => [
    'UNIQUE (family_id, id)',
    'CHECK (revision > 0 AND created_at_us >= 0 AND updated_at_us >= created_at_us)',
    'CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)',
    'CHECK (length(trim(title)) BETWEEN 1 AND 120)',
    "CHECK (category IN ('aadhaar', 'pan', 'passport', 'drivingLicence', 'voterId', 'property', 'utilities', 'education', 'medical', 'insurance', 'general'))",
    "CHECK (expiry_on IS NULL OR (length(expiry_on) = 10 AND date(expiry_on) IS NOT NULL AND date(expiry_on) = expiry_on AND expiry_on BETWEEN '1900-01-01' AND '2200-12-31'))",
    'FOREIGN KEY (family_id, owner_id) REFERENCES family_members(family_id, id)',
    'FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)',
    'FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)',
  ];
}

@DataClassName('VaultDocumentVersion')
class VaultDocumentVersions extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text()();
  TextColumn get documentId => text()();
  IntColumn get version => integer()();
  TextColumn get mimeType => text()();
  IntColumn get plaintextBytes => integer()();
  TextColumn get ciphertextDigest => text()();
  BlobColumn get wrappedKey => blob()();
  TextColumn get createdBy => text()();
  TextColumn get deviceId => text()();
  IntColumn get createdAtUs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => [
    'UNIQUE (family_id, document_id, version)',
    'CHECK (version > 0 AND created_at_us >= 0)',
    "CHECK (mime_type IN ('application/pdf', 'image/jpeg', 'image/png'))",
    'CHECK (plaintext_bytes BETWEEN 1 AND 25165824)',
    "CHECK (length(ciphertext_digest) = 64 AND ciphertext_digest NOT GLOB '*[^a-f0-9]*')",
    'CHECK (length(wrapped_key) = 72)',
    'FOREIGN KEY (family_id, document_id) REFERENCES vault_documents(family_id, id)',
    'FOREIGN KEY (family_id, device_id, created_by) REFERENCES vault_devices(family_id, id, member_id)',
  ];
}

@DataClassName('VaultDocumentLink')
class VaultDocumentLinks extends Table with FamilyProvenance {
  TextColumn get documentId => text()();
  TextColumn get journalId => text().nullable()();
  TextColumn get assetId => text().nullable()();

  @override
  List<String> get customConstraints => [
    'CHECK ((journal_id IS NULL) <> (asset_id IS NULL))',
    'CHECK (revision > 0 AND created_at_us >= 0 AND updated_at_us >= created_at_us)',
    'CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)',
    'FOREIGN KEY (family_id, document_id) REFERENCES vault_documents(family_id, id)',
    'FOREIGN KEY (family_id, journal_id) REFERENCES ledger_journals(family_id, id)',
    'FOREIGN KEY (family_id, asset_id) REFERENCES wealth_assets(family_id, id)',
    'FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)',
    'FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)',
  ];
}

const documentGuards = <String>[
  '''CREATE TRIGGER IF NOT EXISTS vault_document_version_sequence BEFORE INSERT ON vault_document_versions
     WHEN NEW.version <> (SELECT coalesce(max(version), 0) + 1 FROM vault_document_versions
       WHERE family_id = NEW.family_id AND document_id = NEW.document_id)
       OR NOT EXISTS (SELECT 1 FROM vault_documents WHERE family_id = NEW.family_id AND id = NEW.document_id AND deleted_at_us IS NULL)
     BEGIN SELECT RAISE(ABORT, 'The document version needs an active document and consecutive version number'); END''',
  '''CREATE TRIGGER IF NOT EXISTS vault_document_version_no_update BEFORE UPDATE ON vault_document_versions
     BEGIN SELECT RAISE(ABORT, 'Document versions are immutable'); END''',
  '''CREATE TRIGGER IF NOT EXISTS vault_document_version_no_delete BEFORE DELETE ON vault_document_versions
     BEGIN SELECT RAISE(ABORT, 'Document versions are retained'); END''',
  '''CREATE TRIGGER IF NOT EXISTS vault_document_no_delete BEFORE DELETE ON vault_documents
     BEGIN SELECT RAISE(ABORT, 'Archive documents to keep their history'); END''',
  '''CREATE TRIGGER IF NOT EXISTS vault_document_identity BEFORE UPDATE ON vault_documents
     WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
       OR NEW.created_at_us IS NOT OLD.created_at_us OR NEW.revision <> OLD.revision + 1
     BEGIN SELECT RAISE(ABORT, 'Document identity and origin are immutable'); END''',
  '''CREATE UNIQUE INDEX IF NOT EXISTS active_document_journal ON vault_document_links(family_id, document_id, journal_id)
     WHERE deleted_at_us IS NULL AND journal_id IS NOT NULL''',
  '''CREATE UNIQUE INDEX IF NOT EXISTS active_document_asset ON vault_document_links(family_id, document_id, asset_id)
     WHERE deleted_at_us IS NULL AND asset_id IS NOT NULL''',
  '''CREATE TRIGGER IF NOT EXISTS vault_document_link_retain BEFORE DELETE ON vault_document_links
     BEGIN SELECT RAISE(ABORT, 'Document link history is retained'); END''',
  '''CREATE TRIGGER IF NOT EXISTS vault_document_link_identity BEFORE UPDATE ON vault_document_links
     WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
       OR NEW.created_at_us IS NOT OLD.created_at_us OR NEW.document_id IS NOT OLD.document_id
       OR NEW.journal_id IS NOT OLD.journal_id OR NEW.asset_id IS NOT OLD.asset_id
       OR NEW.revision <> OLD.revision + 1 OR OLD.deleted_at_us IS NOT NULL OR NEW.deleted_at_us IS NULL
     BEGIN SELECT RAISE(ABORT, 'A document link can be unlinked once'); END''',
];
