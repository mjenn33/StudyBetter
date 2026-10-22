import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart' show Grade;
import 'package:study_better/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final t0 = DateTime.utc(2026, 10, 21, 10, 0, 0, 123);

  QuizzesCompanion quiz(String id) => QuizzesCompanion.insert(
    id: id,
    title: 'Quiz $id',
    document: '{}',
    version: 1,
    origin: LibraryOrigin.local,
    updatedAt: t0,
  );

  DecksCompanion deck(String id) => DecksCompanion.insert(
    id: id,
    title: 'Deck $id',
    document: '{}',
    version: 1,
    origin: LibraryOrigin.local,
    updatedAt: t0,
  );

  AttemptsCompanion attempt(String id, String quizId) =>
      AttemptsCompanion.insert(
        id: id,
        quizId: quizId,
        quizVersion: 1,
        startedAt: t0,
        finishedAt: t0.add(const Duration(minutes: 2)),
        score: 3,
        maxScore: 4,
        durationMs: 120000,
      );

  test('creates every table', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();

    expect(
      rows.map((r) => r.read<String>('name')),
      unorderedEquals([
        'quizzes',
        'attempts',
        'attempt_answers',
        'decks',
        'card_reviews',
        'review_log',
        'settings',
      ]),
    );
  });

  test('schema version is 1', () {
    expect(db.schemaVersion, 1);
  });

  test('stores quizzes with tags, origin and exact timestamps', () async {
    await db
        .into(db.quizzes)
        .insert(
          quiz('q1').copyWith(
            tags: const Value(['geo', 'capitals']),
            origin: const Value(LibraryOrigin.downloaded),
            remoteId: const Value('r1'),
            remoteVersion: const Value(4),
            isOwnedByMe: const Value(false),
          ),
        );

    final row = await db.select(db.quizzes).getSingle();
    expect(row.tags, ['geo', 'capitals']);
    expect(row.origin, LibraryOrigin.downloaded);
    expect(row.remoteVersion, 4);
    expect(row.isOwnedByMe, isFalse);
    expect(row.updatedAt.isAtSameMomentAs(t0), isTrue);
    expect(row.updatedAt.millisecond, 123);
    expect(row.deletedAt, isNull);
  });

  test('library items default to no tags and owned by me', () async {
    await db.into(db.decks).insert(deck('d1'));

    final row = await db.select(db.decks).getSingle();
    expect(row.tags, isEmpty);
    expect(row.isOwnedByMe, isTrue);
  });

  test('attempts must reference an existing quiz', () async {
    await expectLater(
      db.into(db.attempts).insert(attempt('a1', 'missing')),
      throwsA(isA<SqliteException>()),
    );
  });

  test('stores answers per attempt and deletes them with it', () async {
    await db.into(db.quizzes).insert(quiz('q1'));
    await db.into(db.attempts).insert(attempt('a1', 'q1'));
    await db.batch((b) {
      b.insertAll(db.attemptAnswers, [
        AttemptAnswersCompanion.insert(
          attemptId: 'a1',
          questionId: 'q1',
          selectedOptionIds: ['b'],
          isCorrect: true,
          timeMs: 1500,
        ),
        AttemptAnswersCompanion.insert(
          attemptId: 'a1',
          questionId: 'q2',
          selectedOptionIds: [],
          isCorrect: false,
          timeMs: 900,
        ),
      ]);
    });

    final answers = await db.select(db.attemptAnswers).get();
    expect(answers.map((a) => a.selectedOptionIds), [
      ['b'],
      <String>[],
    ]);
    expect((await db.select(db.attempts).getSingle()).isPractice, isFalse);

    await db.delete(db.attempts).go();
    expect(await db.select(db.attemptAnswers).get(), isEmpty);
  });

  test('one answer per question and attempt', () async {
    await db.into(db.quizzes).insert(quiz('q1'));
    await db.into(db.attempts).insert(attempt('a1', 'q1'));
    final answer = AttemptAnswersCompanion.insert(
      attemptId: 'a1',
      questionId: 'q1',
      selectedOptionIds: ['a'],
      isCorrect: false,
      timeMs: 1,
    );
    await db.into(db.attemptAnswers).insert(answer);

    await expectLater(
      db.into(db.attemptAnswers).insert(answer),
      throwsA(isA<SqliteException>()),
    );
  });

  test('card review state is keyed by deck and card', () async {
    await db.into(db.decks).insert(deck('d1'));
    CardReviewsCompanion review(int interval) => CardReviewsCompanion.insert(
      deckId: 'd1',
      cardId: 'k1',
      easeFactor: 2.5,
      intervalDays: interval,
      repetitions: 1,
      dueAt: t0,
    );

    await db.into(db.cardReviews).insertOnConflictUpdate(review(1));
    await db.into(db.cardReviews).insertOnConflictUpdate(review(6));

    final row = await db.select(db.cardReviews).getSingle();
    expect(row.intervalDays, 6);
    expect(row.lapses, 0);
  });

  test('review log appends entries with increasing ids', () async {
    await db.into(db.decks).insert(deck('d1'));
    for (final grade in [Grade.good, Grade.again]) {
      await db
          .into(db.reviewLog)
          .insert(
            ReviewLogCompanion.insert(
              deckId: 'd1',
              cardId: 'k1',
              reviewedAt: t0,
              grade: grade,
            ),
          );
    }

    final rows = await (db.select(
      db.reviewLog,
    )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
    expect(rows.map((r) => r.grade), [Grade.good, Grade.again]);
    expect(rows.last.id, greaterThan(rows.first.id));
  });

  test('settings are key/value pairs', () async {
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: 'theme', value: 'dark'),
        );
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: 'theme', value: 'light'),
        );

    final row = await db.select(db.settings).getSingle();
    expect(row.value, 'light');
  });
}
