import 'tables.dart';

/// A row of `quizzes` or `decks`. Both tables share [LibraryItemColumns], so
/// they share this row class and the repositories can be generic.
class LibraryItemRow {
  const LibraryItemRow({
    required this.id,
    required this.title,
    required this.tags,
    required this.document,
    required this.version,
    required this.origin,
    this.remoteId,
    this.remoteVersion,
    this.ownerName,
    this.downloadedAt,
    required this.isOwnedByMe,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final List<String> tags;
  final String document;
  final int version;
  final LibraryOrigin origin;
  final String? remoteId;
  final int? remoteVersion;
  final String? ownerName;
  final DateTime? downloadedAt;
  final bool isOwnedByMe;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}
