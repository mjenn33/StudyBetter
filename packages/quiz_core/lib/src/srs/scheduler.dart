import 'grade.dart';
import 'review_state.dart';

/// Maps a UI [Grade] to the original SM-2 quality scale.
int qualityFor(Grade grade) => switch (grade) {
  Grade.again => 0,
  Grade.hard => 3,
  Grade.good => 4,
  Grade.easy => 5,
};

/// Advances a card's SM-2 [current] state after [grade] at [now].
///
/// A lapse starts the card over at one day and increases [ReviewState.lapses].
/// Passing grades use the canonical first (1 day), second (6 days), and later
/// ease-factor-multiplied intervals. All persisted timestamps are UTC.
ReviewState next(ReviewState current, Grade grade, DateTime now) {
  final reviewedAt = now.toUtc();
  final quality = qualityFor(grade);
  final nextEase = _nextEase(current.easeFactor, quality);
  final failed = quality < 3;
  final repetitions = failed ? 0 : current.repetitions + 1;
  final intervalDays = failed
      ? 1
      : switch (repetitions) {
          1 => 1,
          2 => 6,
          _ => (current.intervalDays * nextEase).round().clamp(1, 36500),
        };
  return ReviewState(
    easeFactor: nextEase,
    intervalDays: intervalDays,
    repetitions: repetitions,
    dueAt: reviewedAt.add(Duration(days: intervalDays)),
    lastReviewedAt: reviewedAt,
    lapses: current.lapses + (failed ? 1 : 0),
  );
}

double _nextEase(double current, int quality) {
  final difference = 5 - quality;
  return (current + 0.1 - difference * (0.08 + difference * 0.02)).clamp(
    1.3,
    double.infinity,
  );
}
