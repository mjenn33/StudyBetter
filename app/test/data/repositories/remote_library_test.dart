import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/data/repositories/deck_repository.dart';
import 'package:study_better/data/repositories/library_repository.dart';
import '../../helpers.dart';

void main() {
  test(
    'downloaded quiz updates keep attempts and copy removes remote identity',
    () async {
      final db = testDatabase();
      addTearDown(db.close);
      final repository = QuizRepository(db);
      final quiz = testQuiz();
      await repository.storeRemote(
        quiz,
        remoteId: quiz.id,
        remoteVersion: 1,
        ownerName: 'sam',
      );
      final at = DateTime.utc(2026);
      await db
          .into(db.attempts)
          .insert(
            AttemptsCompanion.insert(
              id: 'attempt',
              quizId: quiz.id,
              quizVersion: 1,
              startedAt: at,
              finishedAt: at,
              score: 1,
              maxScore: 1,
              durationMs: 100,
            ),
          );
      await repository.storeRemote(
        quiz.copyWith(version: 2, title: 'Updated'),
        remoteId: quiz.id,
        remoteVersion: 2,
        ownerName: 'sam',
      );
      final downloaded = (await repository.getById(quiz.id))!;
      expect(downloaded.document.title, 'Updated');
      expect(downloaded.remoteVersion, 2);
      expect(downloaded.isReadOnly, true);
      expect((await db.select(db.attempts).get()).single.quizVersion, 1);
      await expectLater(
        repository.save(quiz),
        throwsA(isA<ReadOnlyItemException>()),
      );
      await expectLater(
        repository.markPublished(quiz.id, quiz.id, 2),
        throwsA(isA<ReadOnlyItemException>()),
      );
      final copy = await repository.duplicate(quiz.id);
      final entry = (await repository.getById(copy.id))!;
      expect(copy.id, isNot(quiz.id));
      expect(entry.remoteId, isNull);
      expect(entry.isReadOnly, false);
      expect(entry.origin, LibraryOrigin.local);
    },
  );
  test('deck updates preserve spaced repetition state', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repository = DeckRepository(db);
    final at = DateTime.utc(2026);
    final deck = FlashcardDeck(
      id: 'deck',
      title: 'Deck',
      createdAt: at,
      updatedAt: at,
      cards: const [Flashcard(id: 'card', front: 'Front', back: 'Back')],
    );
    await repository.storeRemote(
      deck,
      remoteId: 'deck',
      remoteVersion: 1,
      ownerName: 'sam',
    );
    await db
        .into(db.cardReviews)
        .insert(
          CardReviewsCompanion.insert(
            deckId: 'deck',
            cardId: 'card',
            easeFactor: 2.5,
            intervalDays: 6,
            repetitions: 2,
            dueAt: at,
          ),
        );
    await repository.storeRemote(
      deck.copyWith(version: 2),
      remoteId: 'deck',
      remoteVersion: 2,
      ownerName: 'sam',
    );
    expect((await db.select(db.cardReviews).get()).single.repetitions, 2);
  });
  test('publishing metadata does not bump the local content version', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repository = QuizRepository(db);
    final quiz = await repository.save(testQuiz());
    await repository.markPublished(quiz.id, quiz.id, 3);
    final entry = (await repository.getById(quiz.id))!;
    expect(entry.remoteVersion, 3);
    expect(entry.document.version, quiz.version);
    expect(entry.isReadOnly, false);
  });
}
