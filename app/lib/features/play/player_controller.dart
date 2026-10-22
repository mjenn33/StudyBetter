import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../data/repositories/library_repository.dart';
import '../../data/repositories/providers.dart';
import '../quizzes/quiz_readiness.dart';

/// Thrown when the quiz to play has validation problems.
class QuizNotPlayableException implements Exception {
  const QuizNotPlayableException(this.problems);

  final int problems;

  @override
  String toString() => 'QuizNotPlayableException: $problems problems';
}

/// Source of randomness for shuffling; tests override it with a seeded one.
final playerRandomProvider = Provider<Random>((ref) => Random());

/// One play-through in progress.
class PlayerState {
  PlayerState({
    required this.quiz,
    required this.questions,
    required this.optionOrder,
    required this.index,
    required this.selections,
  });

  final Quiz quiz;

  /// The questions in the order they are asked (shuffled if the quiz says so).
  final List<Question> questions;

  /// Display order of each question's options, by question id.
  final Map<String, List<Option>> optionOrder;

  /// Position of the current question in [questions].
  final int index;

  /// Selected option ids by question id; missing or empty = unanswered.
  final Map<String, Set<String>> selections;

  Question get current => questions[index];
  List<Option> get currentOptions => optionOrder[current.id]!;
  Set<String> get currentSelection => selectionFor(current.id);

  Set<String> selectionFor(String questionId) =>
      selections[questionId] ?? const {};

  bool get isFirst => index == 0;
  bool get isLast => index == questions.length - 1;

  bool isAnswered(String questionId) => selectionFor(questionId).isNotEmpty;

  int get answeredCount => questions.where((q) => isAnswered(q.id)).length;
  int get unansweredCount => questions.length - answeredCount;

  /// Scores the selections made so far.
  late final AttemptScore score = scoreAttempt(
    quiz,
    selections,
    questions: questions,
  );

  PlayerState copyWith({int? index, Map<String, Set<String>>? selections}) =>
      PlayerState(
        quiz: quiz,
        questions: questions,
        optionOrder: optionOrder,
        index: index ?? this.index,
        selections: selections ?? this.selections,
      );
}

/// Plays the quiz with the given id. The order is fixed when the player
/// opens; leaving the screen discards the play-through.
final playerProvider = AsyncNotifierProvider.autoDispose
    .family<PlayerController, PlayerState, String>(
      PlayerController.new,
      // Missing or unplayable quizzes won't fix themselves.
      retry: (_, _) => null,
    );

class PlayerController extends AsyncNotifier<PlayerState> {
  PlayerController(this.quizId);

  final String quizId;

  @override
  Future<PlayerState> build() async {
    final entry = await ref.read(quizRepositoryProvider).getById(quizId);
    if (entry == null) throw ItemNotFoundException(quizId);
    final quiz = entry.document;
    final problems = quiz.problems;
    if (problems.isNotEmpty) throw QuizNotPlayableException(problems.length);

    final random = ref.read(playerRandomProvider);
    final settings = quiz.settings;
    final questions = [...quiz.questions];
    if (settings.shuffleQuestions) questions.shuffle(random);
    return PlayerState(
      quiz: quiz,
      questions: questions,
      optionOrder: {
        for (final q in questions)
          q.id: [...q.options]..shuffleIf(settings.shuffleOptions, random),
      },
      index: 0,
      selections: const {},
    );
  }

  PlayerState get _state => state.requireValue;

  void _set(PlayerState next) => state = AsyncData(next);

  /// Selects the option shown at [position] (0-based) of the current
  /// question, as typed with the number keys. Ignored when out of range.
  void selectAt(int position) {
    final options = _state.currentOptions;
    if (position >= 0 && position < options.length) {
      select(options[position].id);
    }
  }

  /// Selects [optionId] for the current question: replaces the answer of a
  /// single-answer question, toggles it for a multiple-answer one.
  void select(String optionId) {
    final s = _state;
    final question = s.current;
    final selected = question.type == QuestionType.single
        ? {optionId}
        : (s.currentSelection.contains(optionId)
              ? ({...s.currentSelection}..remove(optionId))
              : {...s.currentSelection, optionId});
    _set(s.copyWith(selections: {...s.selections, question.id: selected}));
  }

  void next() {
    if (!_state.isLast) _set(_state.copyWith(index: _state.index + 1));
  }

  void previous() {
    if (!_state.isFirst) _set(_state.copyWith(index: _state.index - 1));
  }

  void goTo(int index) {
    if (index >= 0 && index < _state.questions.length) {
      _set(_state.copyWith(index: index));
    }
  }

  /// Leaves the current question unanswered and moves on.
  void skip() {
    final s = _state;
    final selections = {...s.selections}..remove(s.current.id);
    _set(
      s.copyWith(
        selections: selections,
        index: s.isLast ? s.index : s.index + 1,
      ),
    );
  }
}

extension on List<Option> {
  void shuffleIf(bool condition, Random random) {
    if (condition) shuffle(random);
  }
}
