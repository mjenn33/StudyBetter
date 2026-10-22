import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/app/preferences.dart';
import 'package:study_better/app/router.dart';
import 'package:study_better/app/theme.dart';
import 'package:study_better/data/repositories/providers.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/features/quizzes/quiz_routes.dart';
import 'helpers.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 400.0]) {
      testWidgets('quiz flow at 200% text, $width wide, ${brightness.name}', (
        tester,
      ) async {
        final db = testDatabase();
        addTearDown(db.close);
        final quiz = testQuiz(questions: 2);
        await QuizRepository(db).import(quiz);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = await pumpApp(
          tester,
          db: db,
          size: Size(width, 800),
          overrides: [
            themeModeProvider.overrideWith(
              (ref) async => brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
            ),
          ],
        );
        final router = container.read(routerProvider);
        Future<void> checkPage(String path) async {
          expect(tester.takeException(), isNull, reason: path);
          // Inspect scrolled content too, including lazily built list children.
          final scrollable = find.byType(Scrollable).first;
          for (var step = 0; step < 20; step++) {
            final position = tester.state<ScrollableState>(scrollable).position;
            if (position.pixels >= position.maxScrollExtent) break;
            await tester.drag(scrollable, const Offset(0, -400));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: path);
          }
        }

        for (final path in [
          QuizPaths.detail(quiz.id),
          QuizPaths.edit(quiz.id),
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          await checkPage(path);
        }
        await tester.tap(find.text('Add question'));
        await tester.pumpAndSettle();
        await checkPage('Question editor');
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
        router.go(QuizPaths.play(quiz.id));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Player actions must fit.',
        );
        final next = find.widgetWithText(FilledButton, 'Next');
        final previous = find.widgetWithText(TextButton, 'Previous');
        expect(next.hitTestable(), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, 'Skip').hitTestable(),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(previous.hitTestable(), findsOneWidget);
        await tester.tap(previous);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Passed'), findsOneWidget);
        await checkPage('Results');
        final attempt = await db.select(db.attempts).getSingle();
        for (final path in [
          QuizPaths.review(quiz.id, attempt.id),
          QuizPaths.stats(quiz.id),
          '/stats',
          '/settings',
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          await checkPage(path);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testWidgets('large text and keyboard focus in ${brightness.name}', (
      tester,
    ) async {
      final db = testDatabase();
      addTearDown(db.close);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await pumpApp(
        tester,
        db: db,
        size: const Size(400, 800),
        overrides: [
          themeModeProvider.overrideWith(
            (ref) async => brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      final deck = FlashcardDeck(
        id: '00000000-0000-4000-8000-000000000090',
        title: 'Accessible deck',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        cards: [
          Flashcard(
            id: 'c1',
            front: List.filled(25, 'Long question').join(' '),
            back: List.filled(25, 'Long answer').join(' '),
          ),
        ],
      );
      await container.read(deckRepositoryProvider).import(deck);
      container.read(routerProvider).go('/flashcards/${deck.id}/study');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Flashcard question'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Flashcard answer'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    test(
      'readable Material text and status contrast in ${brightness.name}',
      () {
        final scheme = buildTheme(brightness).colorScheme;
        double contrast(Color a, Color b) {
          final values = [a.computeLuminance(), b.computeLuminance()]..sort();
          return (values.last + .05) / (values.first + .05);
        }

        expect(
          contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.primary, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.error, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }
}
