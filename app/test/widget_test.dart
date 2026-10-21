import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/app/app.dart';

Future<void> pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: StudyBetterApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('narrow screens use a bottom navigation bar', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Quizzes — coming soon'), findsOneWidget);
  });

  testWidgets('wide screens use a navigation rail', (tester) async {
    await pumpApp(tester, const Size(1200, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('selecting a destination opens its section', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    for (final label in ['Flashcards', 'Stats', 'Catalog', 'Settings']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('$label — coming soon'), findsOneWidget);
    }
  });
}
