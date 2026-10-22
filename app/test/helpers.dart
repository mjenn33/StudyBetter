import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/app/app.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/database/database_provider.dart';

/// An empty in-memory database. Streams close synchronously so widget tests
/// don't end with pending timers.
AppDatabase testDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

/// Pumps the whole app on [db] at the given window [size] and returns the
/// provider container.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required AppDatabase db,
  Size size = const Size(400, 800),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db), ...overrides],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const StudyBetterApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

int _ids = 0;

/// A valid quiz for tests; ids are unique UUIDs unless given.
Quiz testQuiz({
  String? id,
  String title = 'World Capitals',
  List<String> tags = const [],
  int questions = 1,
  DateTime? updatedAt,
}) {
  final at = updatedAt ?? DateTime.utc(2026, 10, 1);
  return Quiz(
    id: id ?? '00000000-0000-4000-8000-${(++_ids).toString().padLeft(12, '0')}',
    title: title,
    tags: tags,
    createdAt: at,
    updatedAt: at,
    questions: [
      for (var i = 0; i < questions; i++)
        Question(
          id: 'q$i',
          prompt: 'Question $i',
          options: const [
            Option(id: 'a', text: 'A'),
            Option(id: 'b', text: 'B'),
          ],
          correctOptionIds: const ['a'],
        ),
    ],
  );
}

/// Scrolls [finder] into view, then types [text] into it. `enterText` alone
/// taps the field to focus it, which misses fields scrolled off screen and
/// then types into whatever was focused before.
Future<void> enter(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, text);
}
