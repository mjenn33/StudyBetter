import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/data/database/app_database.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  testWidgets('narrow screens use a bottom navigation bar', (tester) async {
    await pumpApp(tester, db: db, size: const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('wide screens use a navigation rail', (tester) async {
    await pumpApp(tester, db: db, size: const Size(1200, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('the app opens on the quiz library', (tester) async {
    await pumpApp(tester, db: db);

    expect(find.text('No quizzes yet'), findsOneWidget);
  });

  testWidgets('selecting a destination opens its section', (tester) async {
    await pumpApp(tester, db: db);

    for (final label in ['Flashcards', 'Stats', 'Catalog', 'Settings']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(label == 'Stats' ? 'Statistics' : '$label — coming soon'),
        findsOneWidget,
      );
    }
  });
}
