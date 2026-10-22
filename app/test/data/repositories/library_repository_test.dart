import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/deck_repository.dart';
import 'package:study_better/data/repositories/library_repository.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';

const quizId = '8f6c2a7e-1c1b-4c55-9a0e-4b7e6b0d2f11';
const deckId = 'c3d1b7a2-5e4f-4a3b-9c8d-1e2f3a4b5c6d';
final created = DateTime.utc(2026, 10, 1);

Quiz sampleQuiz({String id = quizId, String title = 'World Capitals'}) => Quiz(
  id: id,
  title: title,
  tags: const ['geo'],
  createdAt: created,
  updatedAt: created,
  questions: const [
    Question(
      id: 'q1',
      prompt: 'Capital of Australia?',
      options: [
        Option(id: 'a', text: 'Sydney'),
        Option(id: 'b', text: 'Canberra'),
      ],
      correctOptionIds: ['b'],
    ),
  ],
);

void main() {
  late AppDatabase db;
  late DateTime now;
  late int nextId;
  late QuizRepository quizzes;
  late DeckRepository decks;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 21, 12);
    nextId = 0;
    quizzes = QuizRepository(
      db,
      clock: () => now,
      newId: () =>
          '00000000-0000-4000-8000-${(nextId++).toString().padLeft(12, '0')}',
    );
    decks = DeckRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  group('save', () {
    test('stores a new quiz with its version and the current time', () async {
      final saved = await quizzes.save(sampleQuiz());

      expect(saved.version, 1);
      expect(saved.updatedAt, now);
      expect(saved.createdAt, created);

      final entry = await quizzes.getById(quizId);
      expect(entry!.document, saved);
      expect(entry.origin, LibraryOrigin.local);
      expect(entry.isOwnedByMe, isTrue);
      expect(entry.isReadOnly, isFalse);
    });

    test('bumps version and updatedAt on every change', () async {
      await quizzes.save(sampleQuiz());
      now = now.add(const Duration(hours: 1));

      final saved = await quizzes.save(sampleQuiz(title: 'Capitals II'));

      expect(saved.version, 2);
      expect(saved.updatedAt, now);
      expect((await quizzes.getById(quizId))!.document.title, 'Capitals II');
    });

    test('keeps the denormalized columns in sync', () async {
      await quizzes.save(sampleQuiz());

      final row = await db.select(db.quizzes).getSingle();
      expect(row.title, 'World Capitals');
      expect(row.tags, ['geo']);
      expect(row.version, 1);
      expect(row.updatedAt, now);
      expect(Quiz.fromJson(_decode(row.document)).id, quizId);
    });

    test('refuses changes to items the user does not own', () async {
      await quizzes.save(sampleQuiz());
      await _markDownloaded(db, quizId);

      await expectLater(
        quizzes.save(sampleQuiz(title: 'Mine now')),
        throwsA(isA<ReadOnlyItemException>()),
      );
    });

    test('keeps origin and remote fields of existing items', () async {
      await quizzes.save(sampleQuiz());
      await (db.update(db.quizzes)..where((q) => q.id.equals(quizId))).write(
        const QuizzesCompanion(remoteId: Value('r1'), remoteVersion: Value(7)),
      );

      await quizzes.save(sampleQuiz(title: 'Edited'));

      final entry = await quizzes.getById(quizId);
      expect(entry!.remoteId, 'r1');
      expect(entry.remoteVersion, 7);
    });
  });

  group('watchAll', () {
    test(
      'lists items most recently updated first, without deleted ones',
      () async {
        const otherId = '11111111-1111-4111-8111-111111111111';
        const deletedId = '22222222-2222-4222-8222-222222222222';
        await quizzes.save(sampleQuiz());
        now = now.add(const Duration(minutes: 1));
        await quizzes.save(sampleQuiz(id: otherId, title: 'Newer'));
        await quizzes.save(sampleQuiz(id: deletedId, title: 'Gone'));
        await quizzes.delete(deletedId);

        final list = await quizzes.watchAll().first;
        expect(list.map((e) => e.document.id), [otherId, quizId]);
      },
    );

    test('emits again when the library changes', () async {
      final emissions = quizzes.watchAll().map((l) => l.length);
      final expectation = expectLater(emissions, emitsInOrder([0, 1]));
      await pumpEventQueue();

      await quizzes.save(sampleQuiz());
      await expectation;
    });
  });

  group('duplicate', () {
    test('creates a local copy with a new id and version 1', () async {
      await quizzes.save(sampleQuiz());
      await quizzes.save(sampleQuiz(title: 'World Capitals'));
      now = now.add(const Duration(days: 1));

      final copy = await quizzes.duplicate(quizId);

      expect(copy.id, '00000000-0000-4000-8000-000000000000');
      expect(copy.title, 'World Capitals (copy)');
      expect(copy.version, 1);
      expect(copy.createdAt, now);
      expect(copy.updatedAt, now);
      expect(copy.questions, sampleQuiz().questions);
      expect(validateQuiz(copy), isEmpty);
      expect(await quizzes.getById(copy.id), isNotNull);
    });

    test('makes downloaded read-only items editable', () async {
      await quizzes.save(sampleQuiz());
      await _markDownloaded(db, quizId);

      final copy = await quizzes.duplicate(quizId);
      final entry = await quizzes.getById(copy.id);

      expect(entry!.isOwnedByMe, isTrue);
      expect(entry.origin, LibraryOrigin.local);
      expect(entry.remoteId, isNull);
      await quizzes.save(copy.copyWith(title: 'Edited copy'));
    });

    test('fails for unknown ids', () async {
      await expectLater(
        quizzes.duplicate('missing'),
        throwsA(isA<ItemNotFoundException>()),
      );
    });
  });

  group('delete', () {
    test('soft-deletes and can be undone', () async {
      await quizzes.save(sampleQuiz());

      await quizzes.delete(quizId);
      expect(await quizzes.getById(quizId), isNull);
      final hidden = await quizzes.getById(quizId, includeDeleted: true);
      expect(hidden!.deletedAt, now);

      await quizzes.restore(quizId);
      expect(await quizzes.getById(quizId), isNotNull);
    });

    test('keeps the row so attempt history stays valid', () async {
      await quizzes.save(sampleQuiz());
      await quizzes.delete(quizId);

      expect(await db.select(db.quizzes).get(), hasLength(1));
    });

    test('saving a deleted item restores it', () async {
      await quizzes.save(sampleQuiz());
      await quizzes.delete(quizId);

      await quizzes.save(sampleQuiz());
      expect(await quizzes.getById(quizId), isNotNull);
    });

    test('fails for unknown ids', () async {
      await expectLater(
        quizzes.delete('missing'),
        throwsA(isA<ItemNotFoundException>()),
      );
    });
  });

  group('DeckRepository', () {
    final deck = FlashcardDeck(
      id: deckId,
      title: 'Spanish verbs',
      createdAt: created,
      updatedAt: created,
      cards: const [Flashcard(id: 'k1', front: 'tener', back: 'to have')],
    );

    test('saves, lists, duplicates and deletes decks', () async {
      final saved = await decks.save(deck);
      expect(saved.version, 1);
      expect((await decks.getById(deckId))!.document, saved);

      final copy = await decks.duplicate(deckId);
      expect(copy.title, 'Spanish verbs (copy)');
      expect(copy.cards, deck.cards);

      await decks.delete(deckId);
      final list = await decks.watchAll().first;
      expect(list.map((e) => e.document.id), [copy.id]);
    });

    test('decks and quizzes are stored separately', () async {
      await decks.save(deck);

      expect(await quizzes.watchAll().first, isEmpty);
    });
  });
}

Map<String, dynamic> _decode(String json) =>
    jsonDecode(json) as Map<String, dynamic>;

Future<void> _markDownloaded(AppDatabase db, String id) =>
    (db.update(db.quizzes)..where((q) => q.id.equals(id))).write(
      const QuizzesCompanion(
        origin: Value(LibraryOrigin.downloaded),
        isOwnedByMe: Value(false),
        remoteId: Value('remote-1'),
        ownerName: Value('alice'),
      ),
    );
