import 'dart:math';

import 'package:clock/clock.dart';
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

/// The clock used to time attempts. Widget tests get Flutter's fake clock
/// automatically; unit tests override it.
final playerClockProvider = Provider<Clock>((ref) => clock);

const _keep = Object();

/// One play-through in progress.
///
/// Time is counted per question while it is on screen and the app is in the
/// foreground: [questionTimeMs] holds finished stretches and [segmentStart]
/// when the current one began (`null` while paused or finished).
class PlayerState {
  PlayerState({
    required this.quiz,
    required this.questions,
    required this.optionOrder,
    required this.index,
    required this.selections,
    required this.startedAt,
    required this.questionTimeMs,
    required this.segmentStart,
    this.isFinished = false,
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

  /// When the attempt started (UTC).
  final DateTime startedAt;

  /// Milliseconds spent on each question in finished stretches.
  final Map<String, int> questionTimeMs;

  /// Start of the stretch on the current question, or `null` while paused.
  final DateTime? segmentStart;

  final bool isFinished;

  Question get current => questions[index];
  List<Option> get currentOptions => optionOrder[current.id]!;
  Set<String> get currentSelection => selectionFor(current.id);

  Set<String> selectionFor(String questionId) =>
      selections[questionId] ?? const {};

  bool get isFirst => index == 0;
  bool get isLast => index == questions.length - 1;
  bool get isPaused => segmentStart == null && !isFinished;

  bool isAnswered(String questionId) => selectionFor(questionId).isNotEmpty;

  int get answeredCount => questions.where((q) => isAnswered(q.id)).length;
  int get unansweredCount => questions.length - answeredCount;

  /// Scores the selections made so far.
  late final AttemptScore score = scoreAttempt(
    quiz,
    selections,
    questions: questions,
  );

  /// Active time spent in the attempt at [now], excluding pauses.
  int activeMs(DateTime now) {
    final finished = questionTimeMs.values.fold(0, (a, b) => a + b);
    final start = segmentStart;
    return start == null ? finished : finished + _msBetween(start, now);
  }

  /// Time left at [now] when the quiz has a time limit, never below zero;
  /// `null` without a limit.
  int? remainingMs(DateTime now) {
    final limit = quiz.settings.timeLimitSeconds;
    if (limit == null) return null;
    return max(0, limit * 1000 - activeMs(now));
  }

  bool isTimeUp(DateTime now) => remainingMs(now) == 0;

  PlayerState copyWith({
    int? index,
    Map<String, Set<String>>? selections,
    Map<String, int>? questionTimeMs,
    Object? segmentStart = _keep,
    bool? isFinished,
  }) => PlayerState(
    quiz: quiz,
    questions: questions,
    optionOrder: optionOrder,
    index: index ?? this.index,
    selections: selections ?? this.selections,
    startedAt: startedAt,
    questionTimeMs: questionTimeMs ?? this.questionTimeMs,
    segmentStart: identical(segmentStart, _keep)
        ? this.segmentStart
        : segmentStart as DateTime?,
    isFinished: isFinished ?? this.isFinished,
  );
}

/// A completed attempt, ready to be saved and shown.
class FinishedAttempt {
  const FinishedAttempt({
    required this.quiz,
    required this.questions,
    required this.selections,
    required this.score,
    required this.startedAt,
    required this.finishedAt,
    required this.durationMs,
    required this.questionTimeMs,
  });

  final Quiz quiz;

  /// The questions in the order they were asked.
  final List<Question> questions;
  final Map<String, Set<String>> selections;
  final AttemptScore score;
  final DateTime startedAt;
  final DateTime finishedAt;

  /// Active time, excluding pauses.
  final int durationMs;

  /// Time spent on each asked question (0 if never shown).
  final Map<String, int> questionTimeMs;
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
    final now = _now();
    return PlayerState(
      quiz: quiz,
      questions: questions,
      optionOrder: {
        for (final q in questions)
          q.id: [...q.options]..shuffleIf(settings.shuffleOptions, random),
      },
      index: 0,
      selections: const {},
      startedAt: now,
      questionTimeMs: const {},
      segmentStart: now,
    );
  }

  PlayerState get _state => state.requireValue;

  void _set(PlayerState next) => state = AsyncData(next);

  DateTime _now() => ref.read(playerClockProvider).now().toUtc();

  /// [s] with the current stretch added to the current question's time and
  /// a new stretch starting now (if not paused).
  PlayerState _closeStretch(PlayerState s, DateTime now) {
    final start = s.segmentStart;
    if (start == null) return s;
    final id = s.current.id;
    return s.copyWith(
      questionTimeMs: {
        ...s.questionTimeMs,
        id: (s.questionTimeMs[id] ?? 0) + _msBetween(start, now),
      },
      segmentStart: now,
    );
  }

  void _moveTo(int index) {
    final s = _state;
    if (s.isFinished || index == s.index) return;
    if (index < 0 || index >= s.questions.length) return;
    _set(_closeStretch(s, _now()).copyWith(index: index));
  }

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
    if (s.isFinished) return;
    final question = s.current;
    final selected = question.type == QuestionType.single
        ? {optionId}
        : (s.currentSelection.contains(optionId)
              ? ({...s.currentSelection}..remove(optionId))
              : {...s.currentSelection, optionId});
    _set(s.copyWith(selections: {...s.selections, question.id: selected}));
  }

  void next() => _moveTo(_state.index + 1);

  void previous() => _moveTo(_state.index - 1);

  void goTo(int index) => _moveTo(index);

  /// Leaves the current question unanswered and moves on.
  void skip() {
    final s = _state;
    if (s.isFinished) return;
    _set(s.copyWith(selections: {...s.selections}..remove(s.current.id)));
    if (!s.isLast) next();
  }

  /// Stops the clock, e.g. while the app is in the background.
  void pause() {
    final s = _state;
    if (s.isFinished || s.segmentStart == null) return;
    _set(_closeStretch(s, _now()).copyWith(segmentStart: null));
  }

  /// Restarts the clock after [pause].
  void resume() {
    final s = _state;
    if (s.isFinished || s.segmentStart != null) return;
    _set(s.copyWith(segmentStart: _now()));
  }

  /// Ends the attempt and returns it. The time on the current question is
  /// counted up to now (capped at the time limit, if any).
  FinishedAttempt finish() {
    final now = _now();
    var s = _closeStretch(
      _state,
      now,
    ).copyWith(segmentStart: null, isFinished: true);
    final limit = s.quiz.settings.timeLimitSeconds;
    final overrun = limit == null ? 0 : s.activeMs(now) - limit * 1000;
    if (overrun > 0) {
      // Ticks can fire a little after the deadline; don't count that.
      final id = s.current.id;
      s = s.copyWith(
        questionTimeMs: {
          ...s.questionTimeMs,
          id: max(0, (s.questionTimeMs[id] ?? 0) - overrun),
        },
      );
    }
    _set(s);
    return FinishedAttempt(
      quiz: s.quiz,
      questions: s.questions,
      selections: s.selections,
      score: s.score,
      startedAt: s.startedAt,
      finishedAt: now,
      durationMs: s.activeMs(now),
      questionTimeMs: {
        for (final q in s.questions) q.id: s.questionTimeMs[q.id] ?? 0,
      },
    );
  }
}

int _msBetween(DateTime from, DateTime to) =>
    max(0, to.difference(from).inMilliseconds);

extension on List<Option> {
  void shuffleIf(bool condition, Random random) {
    if (condition) shuffle(random);
  }
}
