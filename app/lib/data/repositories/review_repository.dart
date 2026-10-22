import 'package:drift/drift.dart';
import 'package:quiz_core/quiz_core.dart' show Grade;

import '../database/app_database.dart';

/// Spaced repetition state of one card. Personal data: stored only on the
/// device, never in the deck document.
class CardReviewState {
  const CardReviewState({
    required this.deckId,
    required this.cardId,
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.dueAt,
    this.lastReviewedAt,
    this.lapses = 0,
  });

  final String deckId;
  final String cardId;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime dueAt;
  final DateTime? lastReviewedAt;
  final int lapses;
}

/// One entry of the review history.
class ReviewLogEntry {
  const ReviewLogEntry({
    required this.deckId,
    required this.cardId,
    required this.reviewedAt,
    required this.grade,
  });

  final String deckId;
  final String cardId;
  final DateTime reviewedAt;
  final Grade grade;
}

/// Stores flashcard review state and the review history.
class ReviewRepository {
  ReviewRepository(this._db);

  final AppDatabase _db;

  /// State of one card, or `null` if it was never reviewed (a new card).
  Future<CardReviewState?> getState(String deckId, String cardId) async {
    final row =
        await (_db.select(_db.cardReviews)
              ..where((r) => r.deckId.equals(deckId) & r.cardId.equals(cardId)))
            .getSingleOrNull();
    return row == null ? null : _toState(row);
  }

  /// States of every reviewed card in [deckId], keyed by card id.
  Future<Map<String, CardReviewState>> statesForDeck(String deckId) async {
    final rows = await (_db.select(
      _db.cardReviews,
    )..where((r) => r.deckId.equals(deckId))).get();
    return {for (final r in rows) r.cardId: _toState(r)};
  }

  /// Stores [state] without logging a review (e.g. to reset a card).
  Future<void> writeState(CardReviewState state) =>
      _db.into(_db.cardReviews).insertOnConflictUpdate(_toCompanion(state));

  /// Stores the card's new [state] after a review and appends the review to
  /// the log, in one transaction.
  Future<void> recordReview({
    required CardReviewState state,
    required Grade grade,
    required DateTime reviewedAt,
  }) {
    return _db.transaction(() async {
      await writeState(state);
      await _db
          .into(_db.reviewLog)
          .insert(
            ReviewLogCompanion.insert(
              deckId: state.deckId,
              cardId: state.cardId,
              reviewedAt: reviewedAt.toUtc(),
              grade: grade,
            ),
          );
    });
  }

  /// Review history, oldest first, optionally for one deck and/or since a
  /// time (for streaks and retention).
  Future<List<ReviewLogEntry>> reviewLog({
    String? deckId,
    DateTime? since,
  }) async {
    final query = _db.select(_db.reviewLog)
      ..where((r) {
        Expression<bool> condition = const Constant(true);
        if (deckId != null) condition &= r.deckId.equals(deckId);
        if (since != null) {
          condition &= r.reviewedAt.isBiggerOrEqualValue(since.toUtc());
        }
        return condition;
      })
      ..orderBy([
        (r) => OrderingTerm.asc(r.reviewedAt),
        (r) => OrderingTerm.asc(r.id),
      ]);
    return [
      for (final r in await query.get())
        ReviewLogEntry(
          deckId: r.deckId,
          cardId: r.cardId,
          reviewedAt: r.reviewedAt,
          grade: r.grade,
        ),
    ];
  }

  CardReviewState _toState(CardReview r) => CardReviewState(
    deckId: r.deckId,
    cardId: r.cardId,
    easeFactor: r.easeFactor,
    intervalDays: r.intervalDays,
    repetitions: r.repetitions,
    dueAt: r.dueAt,
    lastReviewedAt: r.lastReviewedAt,
    lapses: r.lapses,
  );

  CardReviewsCompanion _toCompanion(CardReviewState s) =>
      CardReviewsCompanion.insert(
        deckId: s.deckId,
        cardId: s.cardId,
        easeFactor: s.easeFactor,
        intervalDays: s.intervalDays,
        repetitions: s.repetitions,
        dueAt: s.dueAt.toUtc(),
        lastReviewedAt: Value(s.lastReviewedAt?.toUtc()),
        lapses: Value(s.lapses),
      );
}
