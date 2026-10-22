import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/features/quizzes/transfer/quiz_transfer.dart';

import '../../../helpers.dart';

void main() {
  final quiz = testQuiz(
    id: '8f6c2a7e-1c1b-4c55-9a0e-4b7e6b0d2f11',
    title: 'World Capitals',
    tags: ['geo'],
    questions: 2,
  ).copyWith(version: 4, description: 'Easy', language: 'en');

  group('export', () {
    test('writes the current-schema document, indented', () {
      final json = exportQuizJson(quiz);

      expect(json, contains('\n  "schemaVersion": 1,'));
      expect(json, endsWith('}\n'));
      expect(jsonDecode(json), jsonDecode(jsonEncode(quiz.toJson())));
    });

    test('file names are slugs of the title', () {
      expect(exportFileName(quiz), 'world-capitals.json');
      expect(
        exportFileName(quiz.copyWith(title: '  ¡Verbos 2026!  ')),
        'verbos-2026.json',
      );
      expect(exportFileName(quiz.copyWith(title: '???')), 'quiz.json');
    });
  });

  group('readQuizFile', () {
    test('exported files read back identically', () {
      final (read, problems) = readQuizFile(exportQuizJson(quiz));

      expect(read, quiz);
      expect(problems, isEmpty);
    });

    test('returns the problems of an invalid quiz', () {
      final invalid = quiz.copyWith(title: '');
      final (_, problems) = readQuizFile(exportQuizJson(invalid));

      expect(problems.map((p) => p.path), ['title']);
    });

    test('rejects files that are not quizzes', () {
      Matcher fails(String text) => throwsA(
        isA<QuizImportException>().having(
          (e) => e.message,
          'message',
          contains(text),
        ),
      );
      expect(() => readQuizFile('{oops'), fails('Not valid JSON'));
      expect(
        () => readQuizFile(jsonEncode({...quiz.toJson(), 'schemaVersion': 9})),
        fails('Update the app'),
      );
      final deck = FlashcardDeck(
        id: 'c3d1b7a2-5e4f-4a3b-9c8d-1e2f3a4b5c6d',
        title: 'Deck',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(
        () => readQuizFile(jsonEncode(deck.toJson())),
        fails('flashcard deck'),
      );
    });
  });

  group('QuizImporter', () {
    late AppDatabase db;
    late QuizRepository quizzes;
    late QuizImporter importer;

    setUp(() {
      db = testDatabase();
      quizzes = QuizRepository(db);
      importer = QuizImporter(
        quizzes,
        newId: () => '11111111-1111-4111-8111-111111111111',
      );
    });
    tearDown(() => db.close());

    test('a new quiz is stored exactly as in the file', () async {
      expect(await importer.existing(quiz), isNull);

      await importer.import(quiz);

      expect((await quizzes.getById(quiz.id))!.document, quiz);
    });

    test('replace overwrites the existing quiz as its next version', () async {
      await quizzes.import(quiz.copyWith(title: 'Old title'));
      final existing = await importer.existing(quiz);
      expect(existing!.title, 'Old title');
      expect(existing.canReplace, isTrue);

      final stored = await importer.import(
        quiz,
        choice: ImportConflictChoice.replace,
      );

      expect(stored.title, 'World Capitals');
      expect(stored.version, quiz.version + 1);
      expect((await quizzes.watchAll().first), hasLength(1));
    });

    test('copy keeps both under different ids', () async {
      await quizzes.import(quiz);

      final copy = await importer.import(
        quiz,
        choice: ImportConflictChoice.copy,
      );

      expect(copy.id, '11111111-1111-4111-8111-111111111111');
      expect(copy.copyWith(id: quiz.id), quiz);
      expect(await quizzes.watchAll().first, hasLength(2));
    });

    test('read-only quizzes can only be copied', () async {
      await quizzes.import(quiz);
      await (db.update(db.quizzes)..where((q) => q.id.equals(quiz.id))).write(
        const QuizzesCompanion(isOwnedByMe: Value(false)),
      );

      expect((await importer.existing(quiz))!.canReplace, isFalse);
    });

    test(
      'a deleted quiz with the same id is replaced without asking',
      () async {
        await quizzes.import(quiz.copyWith(title: 'Deleted'));
        await quizzes.delete(quiz.id);

        expect(await importer.existing(quiz), isNull);
        await importer.import(quiz);

        final entry = await quizzes.getById(quiz.id);
        expect(entry!.document, quiz);
        expect(entry.deletedAt, isNull);
      },
    );

    test('repository import refuses existing ids', () async {
      await quizzes.import(quiz);

      await expectLater(quizzes.import(quiz), throwsStateError);
    });
  });
}
