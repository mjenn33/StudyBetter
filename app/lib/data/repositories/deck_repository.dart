import 'package:quiz_core/quiz_core.dart';

import '../database/app_database.dart';
import 'library_repository.dart';

/// Flashcard decks in the local library.
class DeckRepository extends LibraryRepository<$DecksTable, FlashcardDeck> {
  DeckRepository(AppDatabase db, {super.clock, super.newId})
    : super(db, db.decks);

  @override
  FlashcardDeck decode(Map<String, dynamic> json) =>
      FlashcardDeck.fromJson(json);

  @override
  Map<String, dynamic> encode(FlashcardDeck document) => document.toJson();

  @override
  String idOf(FlashcardDeck document) => document.id;

  @override
  String titleOf(FlashcardDeck document) => document.title;

  @override
  List<String> tagsOf(FlashcardDeck document) => document.tags;

  @override
  int versionOf(FlashcardDeck document) => document.version;

  @override
  DateTime updatedAtOf(FlashcardDeck document) => document.updatedAt;

  @override
  FlashcardDeck withRevision(
    FlashcardDeck document, {
    required int version,
    required DateTime at,
  }) => document.copyWith(version: version, updatedAt: at);

  @override
  FlashcardDeck asCopy(
    FlashcardDeck document, {
    required String id,
    required String title,
    required DateTime at,
  }) => document.copyWith(
    id: id,
    title: title,
    version: 1,
    createdAt: at,
    updatedAt: at,
  );
}
