import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart' show Grade;
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/attempt_repository.dart';
import 'package:study_better/data/repositories/review_repository.dart';

final t0 = DateTime.utc(2026, 10, 21, 9);

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    for (final id in ['quiz-1', 'quiz-2']) {
      await db
          .into(db.quizzes)
          .insert(
            QuizzesCompanion.insert(
              id: id,
              title: id,
              document: '{}',
              version: 1,
              origin: LibraryOrigin.local,
              updatedAt: t0,
            ),
          );
    }
    await db
        .into(db.decks)
        .insert(
          DecksCompanion.insert(
            id: 'deck-1',
            title: 'Deck',
            document: '{}',
            version: 1,
            origin: LibraryOrigin.local,
            updatedAt: t0,
          ),
        );
  });
  tearDown(() => db.close());

  group('AttemptRepository', () {
    late AttemptRepository attempts;
    setUp(() => attempts = AttemptRepository(db));

    AttemptRecord attempt(
      String id, {
      String quizId = 'quiz-1',
      int minutes = 0,
      bool isPractice = false,
    }) => AttemptRecord(
      id: id,
      quizId: quizId,
      quizVersion: 3,
      startedAt: t0.add(Duration(minutes: minutes)),
      finishedAt: t0.add(Duration(minutes: minutes + 2)),
      score: 1,
      maxScore: 3,
      durationMs: 120000,
      isPractice: isPractice,
      answers: const [
        AnswerRecord(
          questionId: 'q1',
          selectedOptionIds: ['b'],
          isCorrect: true,
          timeMs: 4000,
        ),
        AnswerRecord(
          questionId: 'q2',
          selectedOptionIds: ['a', 'c'],
          isCorrect: false,
          timeMs: 6000,
        ),
        AnswerRecord(
          questionId: 'q3',
          selectedOptionIds: [],
          isCorrect: false,
          timeMs: 1000,
        ),
      ],
    );

    test('saves an attempt with every answer', () async {
      await attempts.save(attempt('a1'));

      final saved = await attempts.getById('a1');
      expect(saved!.quizVersion, 3);
      expect(saved.score, 1);
      expect(saved.maxScore, 3);
      expect(saved.startedAt, t0);
      expect(saved.isPractice, isFalse);
      expect(saved.answers.map((a) => a.questionId), ['q1', 'q2', 'q3']);
      expect(saved.answers[1].selectedOptionIds, ['a', 'c']);
      expect(saved.answers[2].isSkipped, isTrue);
    });

    test('a failed save stores nothing', () async {
      final broken = AttemptRecord(
        id: 'a1',
        quizId: 'quiz-1',
        quizVersion: 1,
        startedAt: t0,
        finishedAt: t0,
        score: 0,
        maxScore: 1,
        durationMs: 0,
        answers: const [
          AnswerRecord(
            questionId: 'q1',
            selectedOptionIds: [],
            isCorrect: false,
            timeMs: 0,
          ),
          AnswerRecord(
            questionId: 'q1',
            selectedOptionIds: [],
            isCorrect: false,
            timeMs: 0,
          ),
        ],
      );

      await expectLater(attempts.save(broken), throwsA(anything));
      expect(await attempts.getById('a1'), isNull);
    });

    test('lists attempts per quiz, most recent first', () async {
      await attempts.save(attempt('old'));
      await attempts.save(attempt('new', minutes: 30));
      await attempts.save(attempt('other', quizId: 'quiz-2'));

      final list = await attempts.listForQuiz('quiz-1');
      expect(list.map((a) => a.id), ['new', 'old']);
      expect(list.every((a) => a.answers.length == 3), isTrue);
      expect(await attempts.listForQuiz('missing'), isEmpty);
    });

    test('can leave out practice attempts', () async {
      await attempts.save(attempt('real'));
      await attempts.save(attempt('practice', minutes: 5, isPractice: true));

      final all = await attempts.listForQuiz('quiz-1');
      final real = await attempts.listForQuiz('quiz-1', includePractice: false);
      expect(all.map((a) => a.id), ['practice', 'real']);
      expect(real.map((a) => a.id), ['real']);
    });

    test('watchForQuiz emits when an attempt is added', () async {
      final ids = attempts
          .watchForQuiz('quiz-1')
          .map((l) => l.map((a) => a.id).toList());
      final expectation = expectLater(
        ids,
        emitsInOrder([
          <String>[],
          ['a1'],
        ]),
      );
      await pumpEventQueue();

      await attempts.save(attempt('a1'));
      await expectation;
    });
  });

  group('ReviewRepository', () {
    late ReviewRepository reviews;
    setUp(() => reviews = ReviewRepository(db));

    CardReviewState state(String cardId, {int interval = 1, int days = 1}) =>
        CardReviewState(
          deckId: 'deck-1',
          cardId: cardId,
          easeFactor: 2.5,
          intervalDays: interval,
          repetitions: 1,
          dueAt: t0.add(Duration(days: days)),
          lastReviewedAt: t0,
        );

    test('new cards have no state', () async {
      expect(await reviews.getState('deck-1', 'k1'), isNull);
    });

    test('recordReview stores the state and logs the review', () async {
      await reviews.recordReview(
        state: state('k1'),
        grade: Grade.good,
        reviewedAt: t0,
      );

      final saved = await reviews.getState('deck-1', 'k1');
      expect(saved!.intervalDays, 1);
      expect(saved.dueAt, t0.add(const Duration(days: 1)));
      expect(saved.lapses, 0);

      final log = await reviews.reviewLog();
      expect(log.single.cardId, 'k1');
      expect(log.single.grade, Grade.good);
      expect(log.single.reviewedAt, t0);
    });

    test('a later review replaces the state and appends to the log', () async {
      await reviews.recordReview(
        state: state('k1'),
        grade: Grade.good,
        reviewedAt: t0,
      );
      await reviews.recordReview(
        state: state('k1', interval: 6, days: 6),
        grade: Grade.easy,
        reviewedAt: t0.add(const Duration(days: 1)),
      );

      expect((await reviews.getState('deck-1', 'k1'))!.intervalDays, 6);
      expect((await reviews.reviewLog()).map((e) => e.grade), [
        Grade.good,
        Grade.easy,
      ]);
    });

    test('statesForDeck returns every reviewed card by id', () async {
      await reviews.writeState(state('k1'));
      await reviews.writeState(state('k2', interval: 3));

      final states = await reviews.statesForDeck('deck-1');
      expect(states.keys, unorderedEquals(['k1', 'k2']));
      expect(states['k2']!.intervalDays, 3);
      expect(await reviews.reviewLog(), isEmpty);
    });

    test(
      'dueCount only includes cards due at or before the requested time',
      () async {
        await reviews.writeState(state('overdue', days: -1));
        await reviews.writeState(state('today', days: 0));
        await reviews.writeState(state('later', days: 1));

        expect(await reviews.dueCount('deck-1', now: t0), 2);
        expect(
          await reviews.dueCount(
            'deck-1',
            now: t0.add(const Duration(days: 1)),
          ),
          3,
        );
      },
    );

    test('reviewLog filters by deck and time', () async {
      await db
          .into(db.decks)
          .insert(
            DecksCompanion.insert(
              id: 'deck-2',
              title: 'Other',
              document: '{}',
              version: 1,
              origin: LibraryOrigin.local,
              updatedAt: t0,
            ),
          );
      for (final (deck, day) in [('deck-1', 0), ('deck-1', 2), ('deck-2', 2)]) {
        await reviews.recordReview(
          state: CardReviewState(
            deckId: deck,
            cardId: 'k1',
            easeFactor: 2.5,
            intervalDays: 1,
            repetitions: 1,
            dueAt: t0,
          ),
          grade: Grade.hard,
          reviewedAt: t0.add(Duration(days: day)),
        );
      }

      expect(await reviews.reviewLog(), hasLength(3));
      expect(await reviews.reviewLog(deckId: 'deck-1'), hasLength(2));
      final recent = await reviews.reviewLog(
        deckId: 'deck-1',
        since: t0.add(const Duration(days: 1)),
      );
      expect(recent.single.reviewedAt, t0.add(const Duration(days: 2)));
    });
  });
}
