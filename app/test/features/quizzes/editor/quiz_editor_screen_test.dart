import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/features/quizzes/library/quiz_library_screen.dart';

import '../../../helpers.dart';

void main() {
  late AppDatabase db;
  late QuizRepository quizzes;

  setUp(() {
    db = testDatabase();
    quizzes = QuizRepository(db);
  });
  tearDown(() => db.close());

  Finder field(String label) => find.widgetWithText(TextField, label);
  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');

  testWidgets('creates a quiz from the empty library', (tester) async {
    await pumpApp(tester, db: db, size: const Size(800, 1400));
    await tester.tap(find.text('Create quiz'));
    await tester.pumpAndSettle();

    expect(find.text('New quiz'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

    await tester.enterText(field('Title'), 'World Capitals');
    await tester.enterText(field('Add tag'), 'geo');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.text('Shuffle questions'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'geo'), findsOneWidget);

    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Quiz saved'), findsOneWidget);
    expect(find.text('Edit quiz'), findsOneWidget);
    final saved = await onlyQuiz(db);
    expect(saved.title, 'World Capitals');
    expect(saved.tags, ['geo']);
    expect(saved.settings.shuffleQuestions, isTrue);
  });

  testWidgets('warns before leaving with unsaved changes', (tester) async {
    final quiz = await quizzes.save(testQuiz(title: 'World Capitals'));
    await pumpApp(tester, db: db, size: const Size(800, 1400));
    await tester.tap(find.text('World Capitals'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Title'), 'Changed');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Edit quiz'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Edit quiz'), findsNothing);
    expect((await quizzes.getById(quiz.id))!.document.title, 'World Capitals');
  });

  testWidgets('leaves without asking when nothing changed', (tester) async {
    await quizzes.save(testQuiz(title: 'World Capitals'));
    await pumpApp(tester, db: db, size: const Size(800, 1400));
    await tester.tap(find.text('World Capitals'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Edit quiz'), findsNothing);
  });

  testWidgets('adds and deletes questions, with undo', (tester) async {
    final quiz = await quizzes.save(testQuiz(title: 'World Capitals'));
    await pumpApp(tester, db: db, size: const Size(800, 1400));
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Questions (1)'), findsOneWidget);
    await tester.tap(find.text('Add question'));
    await tester.pumpAndSettle();
    expect(find.text('Questions (2)'), findsOneWidget);
    expect(find.text('Untitled question'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete question').first);
    await tester.pumpAndSettle();
    expect(find.text('Questions (1)'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Questions (2)'), findsOneWidget);

    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    final saved = (await quizzes.getById(quiz.id))!.document;
    expect(saved.questions.map((q) => q.id), ['q0', 'q1']);
  });

  testWidgets('time limit and passing score settings', (tester) async {
    await pumpApp(tester, db: db, size: const Size(800, 1400));
    await tester.tap(find.text('Create quiz'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Title'), 'Timed');

    await tester.tap(find.text('Time limit'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Minutes'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Minutes'), '5');
    await tester.pumpAndSettle();
    expect(find.text('70%'), findsWidgets);

    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    final saved = await onlyQuiz(db);
    expect(saved.settings.timeLimitSeconds, 300);
    expect(saved.settings.passingScorePercent, 70);
  });

  testWidgets('the library shows the edited title after saving', (
    tester,
  ) async {
    await quizzes.save(testQuiz(title: 'Before'));
    await pumpApp(tester, db: db, size: const Size(800, 1400));
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Title'), 'After');
    await tester.pumpAndSettle();
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(QuizListTile), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
  });
}

/// The single stored quiz. Uses a one-off query: Drift watch streams need
/// real timers, which never fire inside `testWidgets`.
Future<Quiz> onlyQuiz(AppDatabase db) async {
  final row = await db.select(db.quizzes).getSingle();
  return Quiz.fromJson(jsonDecode(row.document) as Map<String, dynamic>);
}
