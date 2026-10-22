import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/features/quizzes/editor/question_editor_screen.dart';

import '../../../helpers.dart';

/// A quiz whose only question has no correct option: one problem.
Quiz draftQuiz() {
  final quiz = testQuiz(title: 'Draft quiz');
  return quiz.copyWith(
    questions: [quiz.questions.single.copyWith(correctOptionIds: const [])],
  );
}

void main() {
  late AppDatabase db;
  late QuizRepository quizzes;

  setUp(() {
    db = testDatabase();
    quizzes = QuizRepository(db);
  });
  tearDown(() => db.close());

  const size = Size(800, 1600);

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }

  group('quiz editor', () {
    testWidgets('a new quiz shows no problems until edited', (tester) async {
      await pumpApp(tester, db: db, size: size);
      await tester.tap(find.text('Create quiz'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsNothing);

      await enter(tester, find.widgetWithText(TextField, 'Description'), 'x');
      await tester.pumpAndSettle();
      expect(find.text('Title is empty.'), findsWidgets);
      expect(find.text('A quiz needs at least one question.'), findsWidgets);
    });

    testWidgets('shows problems next to the question and in a summary', (
      tester,
    ) async {
      await quizzes.save(draftQuiz());
      await pumpApp(tester, db: db, size: size);
      await openEditor(tester);

      expect(find.textContaining('1 problem.'), findsOneWidget);
      expect(find.text('Mark at least one option as correct.'), findsWidgets);
    });

    testWidgets('a blank title is flagged and blocks saving', (tester) async {
      await quizzes.save(testQuiz(title: 'Valid'));
      await pumpApp(tester, db: db, size: size);
      await openEditor(tester);
      expect(find.byIcon(Icons.error_outline), findsNothing);

      await enter(tester, find.widgetWithText(TextField, 'Title'), '');
      await tester.pumpAndSettle();

      expect(find.text('Title is empty.'), findsWidgets);
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
    });

    testWidgets('an invalid quiz can still be saved as a draft', (
      tester,
    ) async {
      final quiz = await quizzes.save(draftQuiz());
      await pumpApp(tester, db: db, size: size);
      await openEditor(tester);

      await enter(tester, find.widgetWithText(TextField, 'Title'), 'Renamed');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Quiz saved'), findsOneWidget);
      final saved = (await quizzes.getById(quiz.id))!.document;
      expect(saved.title, 'Renamed');
      expect(validateQuiz(saved), isNotEmpty);
    });
  });

  group('question editor', () {
    Future<void> open(
      WidgetTester tester,
      Question q, {
      bool isNew = false,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: QuestionEditorScreen(question: q, isNew: isNew),
        ),
      );
      await tester.pumpAndSettle();
    }

    const blank = Question(
      id: 'q1',
      prompt: '',
      options: [
        Option(id: 'a', text: ''),
        Option(id: 'b', text: ''),
      ],
    );

    testWidgets('a new question shows problems once edited', (tester) async {
      await open(tester, blank, isNew: true);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.text('Option text is empty.'), findsNothing);

      await enter(tester, find.widgetWithText(TextField, 'Question'), 'Q?');
      await tester.pumpAndSettle();

      expect(find.text('Option text is empty.'), findsNWidgets(2));
      expect(find.text('Mark at least one option as correct.'), findsOneWidget);
      expect(find.text('Question prompt is empty.'), findsNothing);
    });

    testWidgets('an existing question shows its problems right away', (
      tester,
    ) async {
      await open(tester, blank);

      expect(find.text('Question prompt is empty.'), findsOneWidget);
      expect(find.text('Option text is empty.'), findsNWidgets(2));
    });

    testWidgets('problems disappear once fixed', (tester) async {
      await open(
        tester,
        blank.copyWith(
          prompt: 'Q?',
          options: const [
            Option(id: 'a', text: 'A'),
            Option(id: 'b', text: 'B'),
          ],
        ),
      );
      expect(find.text('Mark at least one option as correct.'), findsOneWidget);

      await tester.tap(find.byType(Radio<String>).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });

  group('playing a draft', () {
    testWidgets('the library marks drafts and refuses to play them', (
      tester,
    ) async {
      await quizzes.save(draftQuiz());
      await pumpApp(tester, db: db, size: size);

      expect(find.text('Draft · 1 problem'), findsOneWidget);
      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This quiz has 1 problem. Fix them in the editor to play it.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Question 1 of'), findsNothing);
    });

    testWidgets('the detail page lists problems and disables Play', (
      tester,
    ) async {
      await quizzes.save(draftQuiz());
      await pumpApp(tester, db: db, size: size);
      await tester.tap(find.text('Draft quiz'));
      await tester.pumpAndSettle();

      expect(find.textContaining('a draft with 1 problem'), findsOneWidget);
      expect(
        find.text('• Mark at least one option as correct.'),
        findsOneWidget,
      );
      final play = find.widgetWithText(FilledButton, 'Play');
      expect(tester.widget<FilledButton>(play).onPressed, isNull);
    });

    testWidgets('valid quizzes can be played', (tester) async {
      await quizzes.save(testQuiz(title: 'Valid'));
      await pumpApp(tester, db: db, size: size);

      expect(find.textContaining('Draft'), findsNothing);
      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Question 1 of'), findsOneWidget);
    });
  });
}
