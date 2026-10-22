import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/library_repository.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/features/quizzes/library/quiz_library_filter.dart';
import 'package:study_better/features/quizzes/library/quiz_library_screen.dart';

import '../../helpers.dart';

LibraryEntry<T> _entry<T>(T document) => LibraryEntry(
  document: document,
  origin: LibraryOrigin.local,
  isOwnedByMe: true,
);

void main() {
  group('filterQuizzes', () {
    final entries = [
      _entry(testQuiz(title: 'World Capitals', tags: ['geo'])),
      _entry(testQuiz(title: 'Rivers of Europe', tags: ['geo', 'europe'])),
      _entry(testQuiz(title: 'Spanish verbs', tags: ['spanish'])),
    ];
    List<String> titles(QuizLibraryFilter filter) =>
        filterQuizzes(entries, filter).map((e) => e.document.title).toList();

    test('no filter keeps everything in order', () {
      expect(titles(const QuizLibraryFilter()), [
        'World Capitals',
        'Rivers of Europe',
        'Spanish verbs',
      ]);
    });

    test('search matches the title ignoring case and spaces', () {
      expect(titles(const QuizLibraryFilter(query: '  CAPIT ')), [
        'World Capitals',
      ]);
      expect(titles(const QuizLibraryFilter(query: 'xyz')), isEmpty);
    });

    test('tag filter', () {
      expect(titles(const QuizLibraryFilter(tag: 'geo')), [
        'World Capitals',
        'Rivers of Europe',
      ]);
    });

    test('search and tag combine', () {
      expect(titles(const QuizLibraryFilter(query: 'rivers', tag: 'geo')), [
        'Rivers of Europe',
      ]);
      expect(
        titles(const QuizLibraryFilter(query: 'spanish', tag: 'geo')),
        isEmpty,
      );
    });

    test('tagsOf lists each tag once, sorted', () {
      expect(tagsOf(entries), ['europe', 'geo', 'spanish']);
    });
  });

  group('QuizLibraryScreen', () {
    late AppDatabase db;
    late QuizRepository quizzes;

    setUp(() {
      db = testDatabase();
      quizzes = QuizRepository(db);
    });
    tearDown(() => db.close());

    testWidgets('empty library offers to create or import', (tester) async {
      await pumpApp(tester, db: db);

      expect(find.text('No quizzes yet'), findsOneWidget);
      expect(find.text('Create quiz'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Import'), findsOneWidget);

      await tester.tap(find.text('Create quiz'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'New quiz'), findsOneWidget);
    });

    testWidgets('lists quizzes with question count and tags', (tester) async {
      await quizzes.save(
        testQuiz(title: 'World Capitals', questions: 3, tags: ['geo']),
      );
      await quizzes.save(testQuiz(title: 'Single', questions: 1));
      await pumpApp(tester, db: db);

      expect(find.byType(QuizListTile), findsNWidgets(2));
      expect(find.textContaining('3 questions'), findsOneWidget);
      expect(find.textContaining('1 question ·'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'geo'), findsOneWidget);
      expect(find.text('New quiz'), findsOneWidget);
    });

    testWidgets('search and tag chips filter the list', (tester) async {
      await quizzes.save(testQuiz(title: 'World Capitals', tags: ['geo']));
      await quizzes.save(testQuiz(title: 'Spanish verbs', tags: ['spanish']));
      await pumpApp(tester, db: db);

      await tester.enterText(find.byType(SearchBar), 'world');
      await tester.pumpAndSettle();
      expect(find.byType(QuizListTile), findsOneWidget);
      expect(find.text('World Capitals'), findsOneWidget);

      await tester.enterText(find.byType(SearchBar), '');
      await tester.tap(find.widgetWithText(FilterChip, 'spanish'));
      await tester.pumpAndSettle();
      expect(find.byType(QuizListTile), findsOneWidget);
      expect(find.text('Spanish verbs'), findsOneWidget);

      await tester.enterText(find.byType(SearchBar), 'world');
      await tester.pumpAndSettle();
      expect(find.text('No quizzes match your search.'), findsOneWidget);
    });

    testWidgets('delete can be undone', (tester) async {
      await quizzes.save(testQuiz(title: 'World Capitals'));
      await pumpApp(tester, db: db);

      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(QuizListTile), findsNothing);
      expect(find.text('Deleted "World Capitals"'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('World Capitals'), findsOneWidget);
    });

    testWidgets('duplicate adds a copy', (tester) async {
      await quizzes.save(testQuiz(title: 'World Capitals'));
      await pumpApp(tester, db: db);

      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      expect(find.byType(QuizListTile), findsNWidgets(2));
      expect(find.text('World Capitals (copy)'), findsOneWidget);
    });

    testWidgets('read-only quizzes cannot be edited from the menu', (
      tester,
    ) async {
      final quiz = await quizzes.save(testQuiz(title: 'Downloaded'));
      await (db.update(db.quizzes)..where((q) => q.id.equals(quiz.id))).write(
        const QuizzesCompanion(isOwnedByMe: Value(false)),
      );
      await pumpApp(tester, db: db);

      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Duplicate'), findsOneWidget);
    });

    testWidgets('tapping a quiz opens its details', (tester) async {
      await quizzes.save(
        testQuiz(title: 'World Capitals', questions: 2, tags: ['geo']),
      );
      await pumpApp(tester, db: db);

      await tester.tap(find.text('World Capitals'));
      await tester.pumpAndSettle();

      expect(find.text('2 questions'), findsOneWidget);
      expect(find.text('Pass at 70%'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Edit'), findsOneWidget);
    });
  });
}
