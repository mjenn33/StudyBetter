/// Persistent SM-2 state for a flashcard.
class ReviewState {
  const ReviewState({
    this.easeFactor = 2.5,
    this.intervalDays = 0,
    this.repetitions = 0,
    this.dueAt,
    this.lastReviewedAt,
    this.lapses = 0,
  });

  /// How quickly the card's interval grows. Never below 1.3.
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime? dueAt;
  final DateTime? lastReviewedAt;
  final int lapses;
}
