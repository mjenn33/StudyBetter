import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/data/repositories/providers.dart';
import 'package:study_better/app/router.dart';
import 'package:study_better/features/quizzes/quiz_routes.dart';

import 'helpers.dart';

void registerStudyFlowTests() {
  testWidgets('create quiz, play it, and see saved statistics', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final container = await pumpApp(
      tester,
      db: db,
      size: const Size(1000, 1200),
    );
    await tester.tap(find.text('Create quiz'));
    await tester.pumpAndSettle();
    await enter(
      tester,
      find.widgetWithText(TextField, 'Title'),
      'Integration quiz',
    );
    await tester.tap(find.text('Add question'));
    await tester.pumpAndSettle();
    await enter(
      tester,
      find.widgetWithText(TextField, 'Question'),
      'What is two plus two?',
    );
    await enter(tester, find.widgetWithText(TextField, 'Option 1'), 'Four');
    await enter(tester, find.widgetWithText(TextField, 'Option 2'), 'Five');
    await tester.tap(find.byType(Radio<String>).first);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).last),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    final quiz = await db.select(db.quizzes).getSingle();
    container.read(routerProvider).go(QuizPaths.detail(quiz.id));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. Four'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);
    expect(find.text('Passed'), findsOneWidget);
    container.read(routerProvider).go(QuizPaths.stats(quiz.id));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);
    final attempts = await db.select(db.attempts).get();
    expect(attempts.single.score, attempts.single.maxScore);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('create deck and complete a scheduled flashcard session', (
    tester,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    final container = await pumpApp(
      tester,
      db: db,
      size: const Size(1000, 1200),
    );
    container.read(routerProvider).go('/flashcards/new');
    await tester.pumpAndSettle();
    await enter(
      tester,
      find.widgetWithText(TextField, 'Title'),
      'Integration deck',
    );
    await tester.tap(find.text('Add card'));
    await tester.pumpAndSettle();
    await enter(
      tester,
      find.widgetWithText(TextField, 'Front'),
      'Capital of France?',
    );
    await enter(tester, find.widgetWithText(TextField, 'Back'), 'Paris');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).last),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    final deck =
        (await container
                .read(deckRepositoryProvider)
                .getById((await db.select(db.decks).getSingle()).id))!
            .document;
    container.read(routerProvider).go('/flashcards/${deck.id}/study');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capital of France?'));
    await tester.pumpAndSettle();
    expect(find.text('Paris'), findsOneWidget);
    await tester.tap(find.text('Good (3)'));
    await tester.pumpAndSettle();
    expect(find.text('1 cards reviewed.'), findsOneWidget);
    expect(
      (await container
              .read(reviewRepositoryProvider)
              .getState(deck.id, deck.cards.single.id))!
          .repetitions,
      1,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
