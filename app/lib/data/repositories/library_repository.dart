import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// A document stored in the local library, with where it came from.
class LibraryEntry<D> {
  const LibraryEntry({
    required this.document,
    required this.origin,
    required this.isOwnedByMe,
    this.remoteId,
    this.remoteVersion,
    this.ownerName,
    this.downloadedAt,
    this.deletedAt,
  });

  final D document;
  final LibraryOrigin origin;
  final bool isOwnedByMe;
  final String? remoteId;
  final int? remoteVersion;
  final String? ownerName;
  final DateTime? downloadedAt;
  final DateTime? deletedAt;

  /// Downloaded items by other users can't be edited, only copied.
  bool get isReadOnly => !isOwnedByMe;
}

/// Thrown when saving changes to an item the user doesn't own.
class ReadOnlyItemException implements Exception {
  const ReadOnlyItemException(this.id);

  final String id;

  @override
  String toString() =>
      'ReadOnlyItemException: $id is read-only; make a copy to edit it.';
}

/// Thrown when an operation needs an item that doesn't exist.
class ItemNotFoundException implements Exception {
  const ItemNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'ItemNotFoundException: no item with id $id';
}

/// Shared storage logic for quizzes and decks.
///
/// Each item is stored as its full JSON document plus denormalized columns
/// for listing and syncing ([LibraryItemColumns]). Subclasses say how to
/// read, write and copy their document type [D].
abstract class LibraryRepository<T extends Table, D> {
  LibraryRepository(
    this.db,
    this.table, {
    DateTime Function()? clock,
    String Function()? newId,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? const Uuid().v4;

  final AppDatabase db;
  final TableInfo<T, LibraryItemRow> table;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Builds the document from its JSON.
  D decode(Map<String, dynamic> json);
  Map<String, dynamic> encode(D document);
  String idOf(D document);
  String titleOf(D document);
  List<String> tagsOf(D document);
  int versionOf(D document);
  DateTime updatedAtOf(D document);

  /// [document] with a new content [version] and `updatedAt`.
  D withRevision(D document, {required int version, required DateTime at});

  /// [document] as a fresh copy: new [id] and [title], version 1, created now.
  D asCopy(
    D document, {
    required String id,
    required String title,
    required DateTime at,
  });

  LibraryItemColumns get _columns => table as LibraryItemColumns;

  /// Items that aren't deleted, most recently updated first.
  Stream<List<LibraryEntry<D>>> watchAll() {
    final query = db.select(table)
      ..where((_) => _columns.deletedAt.isNull())
      ..orderBy([(_) => OrderingTerm.desc(_columns.updatedAt)]);
    return query.watch().map((rows) => rows.map(_toEntry).toList());
  }

  /// The item with [id], or `null`. Deleted items are only returned with
  /// [includeDeleted].
  Future<LibraryEntry<D>?> getById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final row = await _row(id);
    if (row == null || (row.deletedAt != null && !includeDeleted)) return null;
    return _toEntry(row);
  }

  /// Stores [document] and returns it as saved.
  ///
  /// New items keep their `version`; changes to an existing item get the
  /// next version. `updatedAt` is set to now either way. Saving a deleted
  /// item restores it. Throws [ReadOnlyItemException] for items the user
  /// doesn't own.
  Future<D> save(D document) {
    return db.transaction(() async {
      final id = idOf(document);
      final existing = await _row(id);
      if (existing != null && !existing.isOwnedByMe) {
        throw ReadOnlyItemException(id);
      }

      final saved = withRevision(
        document,
        version: existing == null ? versionOf(document) : existing.version + 1,
        at: _now(),
      );
      await _write(
        saved,
        origin: existing?.origin ?? LibraryOrigin.local,
        isOwnedByMe: true,
        remoteId: existing?.remoteId,
        remoteVersion: existing?.remoteVersion,
        ownerName: existing?.ownerName,
        downloadedAt: existing?.downloadedAt,
      );
      return saved;
    });
  }

  /// Stores an imported [document] exactly as it is (version and timestamps
  /// unchanged), as a local item the user owns. A deleted item with the same
  /// id is overwritten. Throws [StateError] if a live item with its id
  /// exists; use [save] to replace one.
  Future<D> import(D document) {
    return db.transaction(() async {
      final id = idOf(document);
      final existing = await _row(id);
      if (existing != null && existing.deletedAt == null) {
        throw StateError('An item with id $id already exists.');
      }
      await _write(document, origin: LibraryOrigin.local, isOwnedByMe: true);
      return document;
    });
  }

  /// Creates an editable local copy of item [id] (including read-only
  /// downloaded items) and returns it.
  Future<D> duplicate(String id) {
    return db.transaction(() async {
      final row = await _row(id);
      if (row == null) throw ItemNotFoundException(id);

      final original = _decode(row);
      final copy = asCopy(
        original,
        id: _newId(),
        title: '${titleOf(original)} (copy)',
        at: _now(),
      );
      await _write(copy, origin: LibraryOrigin.local, isOwnedByMe: true);
      return copy;
    });
  }

  /// Hides item [id] from the library. History (attempts, reviews) is kept
  /// and [restore] undoes it.
  Future<void> delete(String id) => _setDeletedAt(id, _now());

  /// Undoes [delete].
  Future<void> restore(String id) => _setDeletedAt(id, null);

  Future<void> _setDeletedAt(String id, DateTime? value) async {
    final updated =
        await (db.update(table)..where((_) => _columns.id.equals(id))).write(
          RawValuesInsertable({'deleted_at': Variable<DateTime>(value)}),
        );
    if (updated == 0) throw ItemNotFoundException(id);
  }

  DateTime _now() => _clock().toUtc();

  Future<LibraryItemRow?> _row(String id) => (db.select(
    table,
  )..where((_) => _columns.id.equals(id))).getSingleOrNull();

  D _decode(LibraryItemRow row) =>
      decode(jsonDecode(row.document) as Map<String, dynamic>);

  LibraryEntry<D> _toEntry(LibraryItemRow row) => LibraryEntry(
    document: _decode(row),
    origin: row.origin,
    isOwnedByMe: row.isOwnedByMe,
    remoteId: row.remoteId,
    remoteVersion: row.remoteVersion,
    ownerName: row.ownerName,
    downloadedAt: row.downloadedAt,
    deletedAt: row.deletedAt,
  );

  Future<void> _write(
    D document, {
    required LibraryOrigin origin,
    required bool isOwnedByMe,
    String? remoteId,
    int? remoteVersion,
    String? ownerName,
    DateTime? downloadedAt,
  }) {
    final json = encode(document);
    return db
        .into(table)
        .insertOnConflictUpdate(
          RawValuesInsertable({
            'id': Variable(idOf(document)),
            'title': Variable(titleOf(document)),
            'tags': Variable(jsonEncode(tagsOf(document))),
            'document': Variable(jsonEncode(json)),
            'version': Variable(versionOf(document)),
            'origin': Variable(origin.name),
            'remote_id': Variable<String>(remoteId),
            'remote_version': Variable<int>(remoteVersion),
            'owner_name': Variable<String>(ownerName),
            'downloaded_at': Variable<DateTime>(downloadedAt),
            'is_owned_by_me': Variable(isOwnedByMe),
            'updated_at': Variable(updatedAtOf(document)),
            'deleted_at': const Variable<DateTime>(null),
          }),
        );
  }
}
