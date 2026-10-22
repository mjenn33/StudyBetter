import '../schema.dart';
import 'document_format_exception.dart';

/// Upgrades a raw JSON document from schema version N to N + 1.
///
/// Receives a copy it may modify and returns the upgraded document; it does
/// not need to update `schemaVersion`, which [migrateDocument] sets.
typedef Migration = Map<String, dynamic> Function(Map<String, dynamic> json);

/// Migrations keyed by the version they upgrade *from*. A version can be read
/// exactly when there is a chain of migrations from it to
/// [currentSchemaVersion]; dropping old entries drops support for them.
///
/// When the format changes: bump [currentSchemaVersion], add an entry here
/// that turns a `currentSchemaVersion - 1` document into the new shape, and
/// add an old sample under `test/fixtures/` with a test that parses it.
const Map<int, Migration> documentMigrations = {};

/// Returns [json] upgraded to [targetVersion] by applying [migrations] one
/// version at a time. [json] itself is not modified.
///
/// Throws [DocumentFormatException] if `schemaVersion` is missing, newer than
/// [targetVersion], or too old (a migration step is missing).
Map<String, dynamic> migrateDocument(
  Map<String, dynamic> json, {
  Map<int, Migration> migrations = documentMigrations,
  int targetVersion = currentSchemaVersion,
}) {
  final version = json['schemaVersion'];
  if (version is! int) {
    throw const DocumentFormatException(
      'Missing or invalid "schemaVersion".',
      path: 'schemaVersion',
    );
  }
  if (version > targetVersion) {
    throw DocumentFormatException(
      'This document uses format version $version, but this version of '
      'StudyBetter only reads up to $targetVersion. Update the app to open it.',
      path: 'schemaVersion',
    );
  }

  var current = Map<String, dynamic>.of(json);
  for (var from = version; from < targetVersion; from++) {
    final migration = migrations[from];
    if (migration == null) {
      throw DocumentFormatException(
        'Format version $version is not supported '
        '(no migration from version $from to ${from + 1}).',
        path: 'schemaVersion',
      );
    }
    current = migration(current)..['schemaVersion'] = from + 1;
  }
  return current;
}
