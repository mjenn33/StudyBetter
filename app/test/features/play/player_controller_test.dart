import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/database/database_provider.dart';
import 'package:study_better/data/repositories/library_repository.dart';
import 'package:study_better/data/repositories/providers.dart';
import 'package:study_better/features/play/player_controller.dart';

import '../../helpers.dart';

/// Single q1 (correct b), multiple q2 (correct a + c, 2 points), single q3.
Quiz playQuiz({QuizSettings settings = const QuizSettings()}) {
  final base = testQuiz(title: 'Play');
  return base.copyWith(
    settings: settings,
    questions: const [
      Question(
        id: 'q1',
        prompt: 'One?',
        options: [
          Option(id: 'a', text: 'A'),
          Option(id: 'b', text: 'B'),
          Option(id: 'c', text: 'C'),
        ],
        correctOptionIds: ['b'],
      ),
      Question(
        id: 'q2',
        prompt: 'Many?',
        type: QuestionType.multiple,
        options: [
          Option(id: 'a', text: 'A'),
          Option(id: 'b', text: 'B'),
          Option(id: 'c', text: 'C'),
          Option(id: 'd', text: 'D'),
        ],
        correctOptionIds: ['a', 'c'],
        points: 2,
      ),
      Question(
        id: 'q3',
        prompt: 'Three?',
        options: [
          Option(id: 'a', text: 'A'),
          Option(id: 'b', text: 'B'),
        ],
        correctOptionIds: ['a'],
      ),
    ],
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = testDatabase();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        playerRandomProvider.overrideWithValue(Random(1)),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<(PlayerController, PlayerState Function())> start(Quiz quiz) async {
    await container.read(quizRepositoryProvider).import(quiz);
    final provider = playerProvider(quiz.id);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    return (
      container.read(provider.notifier),
      () => container.read(provider).requireValue,
    );
  }

  test('asks questions and options in quiz order without shuffling', () async {
    final (_, state) = await start(playQuiz());

    expect(state().questions.map((q) => q.id), ['q1', 'q2', 'q3']);
    expect(state().currentOptions.map((o) => o.id), ['a', 'b', 'c']);
    expect(state().index, 0);
    expect(state().isFirst, isTrue);
    expect(state().unansweredCount, 3);
  });

  test('shuffles questions and options when the quiz says so', () async {
    final quiz = playQuiz(
      settings: const QuizSettings(
        shuffleQuestions: true,
        shuffleOptions: true,
      ),
    );
    final (_, state) = await start(quiz);
    final s = state();

    expect(s.questions.map((q) => q.id), unorderedEquals(['q1', 'q2', 'q3']));
    for (final q in quiz.questions) {
      expect(
        s.optionOrder[q.id]!.map((o) => o.id),
        unorderedEquals(q.options.map((o) => o.id)),
      );
    }
    // With this seed the order differs from the original somewhere.
    final shuffled =
        s.questions.map((q) => q.id).join() != 'q1q2q3' ||
        quiz.questions.any(
          (q) =>
              s.optionOrder[q.id]!.map((o) => o.id).join() !=
              q.options.map((o) => o.id).join(),
        );
    expect(shuffled, isTrue);
  });

  test('single-answer selection replaces the previous one', () async {
    final (player, state) = await start(playQuiz());

    player.select('a');
    player.select('b');

    expect(state().currentSelection, {'b'});
    expect(state().answeredCount, 1);
  });

  test('multiple-answer selection toggles', () async {
    final (player, state) = await start(playQuiz());
    player.next();

    player
      ..select('a')
      ..select('c')
      ..select('d')
      ..select('d');

    expect(state().currentSelection, {'a', 'c'});
  });

  test('selectAt picks the option shown at a position', () async {
    final quiz = playQuiz(settings: const QuizSettings(shuffleOptions: true));
    final (player, state) = await start(quiz);
    final shown = state().currentOptions;

    player.selectAt(2);
    expect(state().currentSelection, {shown[2].id});

    player.selectAt(8);
    expect(state().currentSelection, {shown[2].id});
  });

  test('next and previous stay within the quiz; answers are kept', () async {
    final (player, state) = await start(playQuiz());

    player.previous();
    expect(state().index, 0);
    player.select('b');
    player
      ..next()
      ..next()
      ..next();
    expect(state().index, 2);
    expect(state().isLast, isTrue);

    player.goTo(0);
    expect(state().currentSelection, {'b'});
  });

  test('skip clears the answer and moves on', () async {
    final (player, state) = await start(playQuiz());

    player.select('a');
    player.skip();

    expect(state().index, 1);
    expect(state().isAnswered('q1'), isFalse);

    player
      ..goTo(2)
      ..select('a')
      ..skip();
    expect(state().index, 2);
    expect(state().isAnswered('q3'), isFalse);
  });

  test('scores the selections', () async {
    final (player, state) = await start(playQuiz());

    player.select('b');
    player.next();
    player
      ..select('a')
      ..select('c');
    player.next();
    player.select('b');

    final score = state().score;
    expect(score.points, 3);
    expect(score.maxPoints, 4);
    expect((score.correct, score.incorrect, score.skipped), (2, 1, 0));
  });

  test('refuses drafts and missing quizzes', () async {
    final draft = playQuiz().copyWith(questions: const []);
    await container.read(quizRepositoryProvider).import(draft);

    Future<PlayerState> load(String id) {
      final provider = playerProvider(id);
      container.listen(provider, (_, _) {});
      return container.read(provider.future);
    }

    await expectLater(load(draft.id), throwsA(isA<QuizNotPlayableException>()));
    await expectLater(load('missing'), throwsA(isA<ItemNotFoundException>()));
  });
}
