import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/database/database_provider.dart';
import 'package:study_better/data/repositories/providers.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/features/play/player_controller.dart';

import '../../helpers.dart';
import 'player_controller_test.dart' show playQuiz;

/// A clock the test moves by hand.
class _Time {
  DateTime now = DateTime.utc(2026, 10, 22, 9);
  void advance(int ms) => now = now.add(Duration(milliseconds: ms));
  late final clock = Clock(() => now);
}

void main() {
  group('PlayerController timing', () {
    late AppDatabase db;
    late ProviderContainer container;
    late _Time time;

    setUp(() {
      db = testDatabase();
      time = _Time();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          playerRandomProvider.overrideWithValue(Random(1)),
          playerClockProvider.overrideWith((ref) => time.clock),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    /// Runs [body] with the controller of a started player; the player's
    /// clock is [time].
    Future<void> play(
      Quiz quiz,
      void Function(PlayerController player, PlayerState Function() state) body,
    ) async {
      await container.read(quizRepositoryProvider).import(quiz);
      final provider = playerProvider(quiz.id);
      container.listen(provider, (_, _) {});
      await container.read(provider.future);
      body(
        container.read(provider.notifier),
        () => container.read(provider).requireValue,
      );
    }

    test('records time per question in milliseconds', () async {
      await play(playQuiz(), (player, state) {
        time.advance(4200);
        player.next();
        time.advance(1500);
        player.previous();
        time.advance(300);
        player.goTo(2);
        time.advance(1000);

        final attempt = player.finish();
        expect(attempt.questionTimeMs, {'q1': 4500, 'q2': 1500, 'q3': 1000});
        expect(attempt.durationMs, 7000);
        expect(attempt.startedAt, DateTime.utc(2026, 10, 22, 9));
        expect(attempt.finishedAt, time.now);
        expect(state().isFinished, isTrue);
      });
    });

    test('time while paused is not counted', () async {
      await play(playQuiz(), (player, state) {
        time.advance(1000);
        player.pause();
        expect(state().isPaused, isTrue);
        time.advance(60000);
        expect(state().activeMs(time.now), 1000);
        player.resume();
        time.advance(500);

        final attempt = player.finish();
        expect(attempt.questionTimeMs['q1'], 1500);
        expect(attempt.durationMs, 1500);
      });
    });

    test('pause and resume are idempotent', () async {
      await play(playQuiz(), (player, state) {
        time.advance(1000);
        player
          ..pause()
          ..pause();
        time.advance(1000);
        player
          ..resume()
          ..resume();
        time.advance(1000);
        expect(state().activeMs(time.now), 2000);
      });
    });

    test('counts down the time limit and reports when it is up', () async {
      final quiz = playQuiz(settings: const QuizSettings(timeLimitSeconds: 10));
      await play(quiz, (player, state) {
        expect(state().remainingMs(time.now), 10000);
        time.advance(4000);
        expect(state().remainingMs(time.now), 6000);
        player.pause();
        time.advance(30000);
        expect(state().remainingMs(time.now), 6000);
        player.resume();
        time.advance(7000);
        expect(state().remainingMs(time.now), 0);
        expect(state().isTimeUp(time.now), isTrue);

        // Finishing a moment late doesn't count past the limit.
        final attempt = player.finish();
        expect(attempt.durationMs, 10000);
      });
    });

    test('no time limit means no countdown', () async {
      await play(playQuiz(), (player, state) {
        time.advance(999999);
        expect(state().remainingMs(time.now), isNull);
        expect(state().isTimeUp(time.now), isFalse);
      });
    });

    test('a finished attempt ignores further input', () async {
      await play(playQuiz(), (player, state) {
        player.select('b');
        player.finish();
        player
          ..next()
          ..select('a')
          ..skip()
          ..resume();
        expect(state().index, 0);
        expect(state().currentSelection, {'b'});
        expect(state().segmentStart, isNull);
      });
    });
  });

  group('PlayerScreen timing', () {
    late AppDatabase db;
    late QuizRepository quizzes;

    setUp(() {
      db = testDatabase();
      quizzes = QuizRepository(db);
    });
    tearDown(() => db.close());

    Future<void> start(WidgetTester tester, Quiz quiz) async {
      await quizzes.import(quiz);
      await pumpApp(tester, db: db, size: const Size(800, 1000));
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Play'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the countdown and finishes when time is up', (
      tester,
    ) async {
      await start(
        tester,
        playQuiz(settings: const QuizSettings(timeLimitSeconds: 90)),
      );
      expect(find.text('1:30'), findsOneWidget);

      await tester.tap(find.text('2. B'));
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('0:59'), findsOneWidget);

      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(find.text("Time's up · Not passed"), findsOneWidget);
      expect(find.textContaining('1 / 4 points'), findsOneWidget);
    });

    testWidgets('time up closes an open confirmation first', (tester) async {
      await start(
        tester,
        playQuiz(settings: const QuizSettings(timeLimitSeconds: 5)),
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Leave quiz?'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.text('Leave quiz?'), findsNothing);
      expect(find.textContaining("Time's up"), findsOneWidget);
    });

    testWidgets('the countdown stops while the app is in the background', (
      tester,
    ) async {
      await start(
        tester,
        playQuiz(settings: const QuizSettings(timeLimitSeconds: 120)),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('1:59'), findsOneWidget);
      expect(find.textContaining("Time's up"), findsNothing);
    });

    testWidgets('quizzes without a limit show no countdown', (tester) async {
      await start(tester, playQuiz());

      expect(find.byIcon(Icons.timer_outlined), findsNothing);
    });
  });
}
