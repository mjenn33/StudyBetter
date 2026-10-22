import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/features/quizzes/library/quiz_library_screen.dart';
import 'package:study_better/features/quizzes/transfer/quiz_files.dart';
import 'package:study_better/features/quizzes/transfer/quiz_transfer.dart';

import '../../../helpers.dart';

/// Replaces the platform dialogs: returns [next] when asked to pick a file
/// and records saved files.
class FakeQuizFiles implements QuizFiles {
  PickedFile? next;
  final saved = <(String, String)>[];

  @override
  Future<PickedFile?> pickJson() async => next;

  @override
  Future<bool> saveJson(String fileName, String contents) async {
    saved.add((fileName, contents));
    return true;
  }
}

void main() {
  late AppDatabase db;
  late QuizRepository quizzes;
  late FakeQuizFiles files;

  setUp(() {
    db = testDatabase();
    quizzes = QuizRepository(db);
    files = FakeQuizFiles();
  });
  tearDown(() => db.close());

  final quiz = testQuiz(
    id: '8f6c2a7e-1c1b-4c55-9a0e-4b7e6b0d2f11',
    title: 'World Capitals',
    questions: 2,
  ).copyWith(version: 3);

  Future<void> pump(WidgetTester tester) => pumpApp(
    tester,
    db: db,
    size: const Size(800, 1200),
    overrides: [quizFilesProvider.overrideWithValue(files)],
  );

  Future<void> tapMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('Actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  Future<Quiz> stored(String id) async => (await quizzes.getById(id))!.document;

  testWidgets('imports a quiz into the empty library', (tester) async {
    files.next = PickedFile(
      name: 'capitals.json',
      contents: exportQuizJson(quiz),
    );
    await pump(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Import'));
    await tester.pumpAndSettle();

    expect(find.text('Imported "World Capitals"'), findsOneWidget);
    expect(find.byType(QuizListTile), findsOneWidget);
    expect(await stored(quiz.id), quiz);
  });

  testWidgets('shows why a file cannot be imported', (tester) async {
    files.next = const PickedFile(name: 'broken.json', contents: '{oops');
    await pump(tester);

    await tester.tap(find.byTooltip('Import'));
    await tester.pumpAndSettle();

    expect(find.text("Can't import broken.json"), findsOneWidget);
    expect(find.textContaining('Not valid JSON'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(QuizListTile), findsNothing);
  });

  testWidgets('an invalid quiz can be imported as a draft', (tester) async {
    final invalid = quiz.copyWith(
      questions: [quiz.questions.first.copyWith(correctOptionIds: const [])],
    );
    files.next = PickedFile(name: 'q.json', contents: exportQuizJson(invalid));
    await pump(tester);

    await tester.tap(find.byTooltip('Import'));
    await tester.pumpAndSettle();
    expect(find.text('"World Capitals" has 1 problem'), findsOneWidget);
    expect(find.text('• Mark at least one option as correct.'), findsOneWidget);

    await tester.tap(find.text('Import as draft'));
    await tester.pumpAndSettle();
    expect(find.text('Draft · 1 problem'), findsOneWidget);
  });

  testWidgets('cancelling the draft prompt imports nothing', (tester) async {
    final invalid = quiz.copyWith(title: '');
    files.next = PickedFile(name: 'q.json', contents: exportQuizJson(invalid));
    await pump(tester);

    await tester.tap(find.byTooltip('Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await quizzes.getById(quiz.id), isNull);
  });

  group('when the quiz is already in the library', () {
    setUp(() async {
      await quizzes.import(quiz.copyWith(title: 'Old title'));
      files.next = PickedFile(name: 'q.json', contents: exportQuizJson(quiz));
    });

    testWidgets('replace overwrites it', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Import'));
      await tester.pumpAndSettle();
      expect(find.text('Quiz already in your library'), findsOneWidget);
      expect(find.textContaining('a version of "Old title"'), findsOneWidget);

      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      expect(find.byType(QuizListTile), findsOneWidget);
      expect((await stored(quiz.id)).title, 'World Capitals');
    });

    testWidgets('import as copy keeps both', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Import'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import as copy'));
      await tester.pumpAndSettle();

      expect(find.byType(QuizListTile), findsNWidgets(2));
      expect((await stored(quiz.id)).title, 'Old title');
    });

    testWidgets('cancel leaves the library unchanged', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Import'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(QuizListTile), findsOneWidget);
      expect((await stored(quiz.id)).title, 'Old title');
    });
  });

  testWidgets('exports a quiz and the file re-imports identically', (
    tester,
  ) async {
    await quizzes.import(quiz);
    await pump(tester);

    await tapMenu(tester, 'Export');
    expect(find.text('Exported "World Capitals"'), findsOneWidget);
    final (name, contents) = files.saved.single;
    expect(name, 'world-capitals.json');
    expect(jsonDecode(contents)['kind'], 'quiz');

    // Delete it, then import the exported file again.
    await quizzes.delete(quiz.id);
    files.next = PickedFile(name: name, contents: contents);
    await tester.tap(find.byTooltip('Import'));
    await tester.pumpAndSettle();

    expect(await stored(quiz.id), quiz);
  });

  testWidgets('drafts cannot be exported', (tester) async {
    await quizzes.import(quiz.copyWith(title: 'Draft', questions: const []));
    await pump(tester);

    await tapMenu(tester, 'Export');

    expect(files.saved, isEmpty);
    expect(
      find.text(
        'This quiz has 1 problem. Fix them in the editor to export it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('export is also on the detail page', (tester) async {
    await quizzes.import(quiz);
    await pump(tester);
    await tester.tap(find.text('World Capitals'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(files.saved.single.$1, 'world-capitals.json');
  });
}
