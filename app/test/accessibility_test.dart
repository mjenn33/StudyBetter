import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/app/preferences.dart';
import 'package:study_better/app/router.dart';
import 'package:study_better/app/theme.dart';
import 'package:study_better/data/repositories/providers.dart';
import 'helpers.dart';

void main() {
  for (final brightness in Brightness.values) {
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
