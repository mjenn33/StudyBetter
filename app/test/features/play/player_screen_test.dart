import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';

import '../../helpers.dart';
import 'player_controller_test.dart' show playQuiz;

void main() {
  late AppDatabase db;
  late QuizRepository quizzes;

  setUp(() {
    db = testDatabase();
    quizzes = QuizRepository(db);
  });
  tearDown(() => db.close());

  Future<void> startPlaying(WidgetTester tester) async {
    await quizzes.import(playQuiz());
    await pumpApp(tester, db: db, size: const Size(800, 1000));
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();
  }

  Finder next() => find.widgetWithText(FilledButton, 'Next');
  Finder finish() => find.widgetWithText(FilledButton, 'Finish');

  testWidgets('one question at a time with progress', (tester) async {
    await startPlaying(tester);

    expect(find.text('Question 1 of 3 · 0 answered'), findsOneWidget);
    expect(find.text('One?'), findsOneWidget);
    expect(find.text('Choose one answer'), findsOneWidget);
    expect(find.byType(RadioListTile<String>), findsNWidgets(3));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Previous'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('2. B'));
    await tester.tap(next());
    await tester.pumpAndSettle();

    expect(find.text('Question 2 of 3 · 1 answered'), findsOneWidget);
    expect(find.text('Choose all that apply'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(4));
  });

  testWidgets('play through and see the score', (tester) async {
    await startPlaying(tester);

    await tester.tap(find.text('2. B'));
    await tester.tap(next());
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. A'));
    await tester.tap(find.text('3. C'));
    await tester.tap(next());
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. A'));
    await tester.pumpAndSettle();
    await tester.tap(finish());
    await tester.pumpAndSettle();

    expect(find.text('Passed'), findsOneWidget);
    expect(find.textContaining('4 / 4 points (100%)'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 3 · 0 answered'), findsNothing);
  });

  testWidgets('finishing with unanswered questions asks first', (tester) async {
    await startPlaying(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(finish());
    await tester.pumpAndSettle();

    expect(find.text('Finish quiz?'), findsOneWidget);
    expect(find.textContaining("haven't answered 3 questions"), findsOneWidget);
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(find.text('Three?'), findsOneWidget);

    await tester.tap(finish());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish').last);
    await tester.pumpAndSettle();
    expect(find.text('Not passed'), findsOneWidget);
    expect(find.textContaining('3 skipped'), findsOneWidget);
  });

  testWidgets('keyboard: number keys select, Enter goes on', (tester) async {
    await startPlaying(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 3 · 1 answered'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Many?'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad3);
    await tester.pumpAndSettle();
    final checked = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .map((t) => t.value)
        .toList();
    expect(checked, [true, false, true, false]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('One?'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Many?'), findsOneWidget);
  });

  testWidgets('leaving mid-quiz asks first', (tester) async {
    await startPlaying(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Leave quiz?'), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(find.text('One?'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('One?'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
  });
}
