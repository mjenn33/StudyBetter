import 'package:drift/drift.dart';
import 'package:quiz_core/quiz_core.dart' show Grade;

import 'converters.dart';
import 'library_item_row.dart';

/// Where a library item came from.
enum LibraryOrigin {
  /// Created on this device (or imported from a file).
  local,

  /// Downloaded from the server catalog.
  downloaded,
}

/// Columns shared by [Quizzes] and [Decks]: the full document as JSON plus
/// denormalized copies of the fields needed to list, search and sync.
mixin LibraryItemColumns on Table {
  /// Document UUID (`id` in the JSON).
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get tags => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();

  /// The full quiz or deck document as JSON (current schema version).
  TextColumn get document => text()();

  /// Content `version` of the document.
  IntColumn get version => integer()();
  TextColumn get origin => textEnum<LibraryOrigin>()();

  /// Id and version on the server, once published or downloaded.
  TextColumn get remoteId => text().nullable()();
  IntColumn get remoteVersion => integer().nullable()();

  /// Owner's username for downloaded items.
  TextColumn get ownerName => text().nullable()();
  DateTimeColumn get downloadedAt => dateTime().nullable()();

  /// False for downloaded items by other users: they are read-only.
  BoolColumn get isOwnedByMe => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();

  /// Set when the user deletes the item; rows are kept so attempts and review
  /// history stay intact and deletes can be undone.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'quizzes_updated_at', columns: {#updatedAt})
@UseRowClass(LibraryItemRow)
class Quizzes extends Table with LibraryItemColumns {}

@TableIndex(name: 'decks_updated_at', columns: {#updatedAt})
@UseRowClass(LibraryItemRow)
class Decks extends Table with LibraryItemColumns {}

/// One finished play-through of a quiz.
@TableIndex(name: 'attempts_quiz_started', columns: {#quizId, #startedAt})
class Attempts extends Table {
  /// UUID.
  TextColumn get id => text()();
  TextColumn get quizId => text().references(Quizzes, #id)();

  /// Quiz `version` that was played; questions may differ between versions.
  IntColumn get quizVersion => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime()();
  IntColumn get score => integer()();
  IntColumn get maxScore => integer()();
  IntColumn get durationMs => integer()();

  /// "Practice weakest questions" runs, kept out of the main score trend.
  BoolColumn get isPractice => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The user's answer to one question within an [Attempts] row.
class AttemptAnswers extends Table {
  TextColumn get attemptId =>
      text().references(Attempts, #id, onDelete: KeyAction.cascade)();
  TextColumn get questionId => text()();

  /// Selected option ids; empty when the question was skipped.
  TextColumn get selectedOptionIds => text().map(const StringListConverter())();
  BoolColumn get isCorrect => boolean()();
  IntColumn get timeMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {attemptId, questionId};
}

/// Spaced repetition state of one flashcard (SM-2).
@TableIndex(name: 'card_reviews_due', columns: {#dueAt})
class CardReviews extends Table {
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get cardId => text()();
  RealColumn get easeFactor => real()();
  IntColumn get intervalDays => integer()();
  IntColumn get repetitions => integer()();
  DateTimeColumn get dueAt => dateTime()();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();
  IntColumn get lapses => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {deckId, cardId};
}

/// Append-only history of flashcard reviews (streaks, retention).
@TableIndex(name: 'review_log_reviewed_at', columns: {#reviewedAt})
class ReviewLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get cardId => text()();
  DateTimeColumn get reviewedAt => dateTime()();

  TextColumn get grade => textEnum<Grade>()();
}

/// App settings as key/value pairs.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
