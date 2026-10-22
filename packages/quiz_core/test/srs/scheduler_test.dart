import 'package:quiz_core/quiz_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 22, 9);

  test('maps grades to the SM-2 quality scale', () {
    expect(qualityFor(Grade.again), 0);
    expect(qualityFor(Grade.hard), 3);
    expect(qualityFor(Grade.good), 4);
    expect(qualityFor(Grade.easy), 5);
  });

  test('starts successful cards at one day and then six days', () {
    final first = next(const ReviewState(), Grade.good, now);
    final second = next(first, Grade.good, now.add(const Duration(days: 1)));

    expect((first.repetitions, first.intervalDays, first.lapses), (1, 1, 0));
    expect(first.dueAt, now.add(const Duration(days: 1)));
    expect((second.repetitions, second.intervalDays), (2, 6));
    expect(second.dueAt, DateTime.utc(2026, 10, 29, 9));
  });

  test('uses the adjusted ease factor for later successful intervals', () {
    final state = ReviewState(easeFactor: 2.5, intervalDays: 6, repetitions: 2);

    final afterHard = next(state, Grade.hard, now);
    final afterEasy = next(state, Grade.easy, now);

    expect(afterHard.easeFactor, closeTo(2.36, 0.0001));
    expect(afterHard.intervalDays, 14);
    expect(afterEasy.easeFactor, closeTo(2.6, 0.0001));
    expect(afterEasy.intervalDays, 16);
  });

  test(
    'again records a lapse, resets repetitions, and enforces ease floor',
    () {
      final result = next(
        const ReviewState(
          easeFactor: 1.31,
          intervalDays: 20,
          repetitions: 4,
          lapses: 2,
        ),
        Grade.again,
        now,
      );

      expect(result.easeFactor, 1.3);
      expect(result.repetitions, 0);
      expect(result.intervalDays, 1);
      expect(result.lapses, 3);
      expect(result.lastReviewedAt, now);
      expect(result.dueAt, now.add(const Duration(days: 1)));
    },
  );
}
