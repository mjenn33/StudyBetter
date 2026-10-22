import 'package:quiz_core/quiz_core.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  // q1: single, correct b, 1 point. q2: multiple, correct a + c, 2 points.
  final quiz = Quiz.fromJson(readFixture('quiz_v1.json'));
  final [single, multiple] = quiz.questions;

  group('scoreAnswer', () {
    test('single: the correct option is correct, others are not', () {
      expect(scoreAnswer(single, ['b']), AnswerOutcome.correct);
      expect(scoreAnswer(single, ['a']), AnswerOutcome.incorrect);
    });

    test('nothing selected is skipped', () {
      expect(scoreAnswer(single, []), AnswerOutcome.skipped);
      expect(scoreAnswer(multiple, const <String>{}), AnswerOutcome.skipped);
    });

    test('multiple: only the exact set of correct options is correct', () {
      expect(scoreAnswer(multiple, ['a', 'c']), AnswerOutcome.correct);
      expect(scoreAnswer(multiple, ['c', 'a']), AnswerOutcome.correct);
      expect(scoreAnswer(multiple, ['a']), AnswerOutcome.incorrect);
      expect(scoreAnswer(multiple, ['a', 'c', 'd']), AnswerOutcome.incorrect);
      expect(scoreAnswer(multiple, ['b', 'd']), AnswerOutcome.incorrect);
    });

    test('duplicates in the selection are ignored', () {
      expect(scoreAnswer(multiple, ['a', 'a', 'c']), AnswerOutcome.correct);
      expect(scoreAnswer(single, ['b', 'b']), AnswerOutcome.correct);
    });

    test('unknown option ids are incorrect', () {
      expect(scoreAnswer(single, ['z']), AnswerOutcome.incorrect);
    });
  });

  group('scoreAttempt', () {
    test('all correct', () {
      final score = scoreAttempt(quiz, {
        'q1': ['b'],
        'q2': ['a', 'c'],
      });

      expect(score.points, 3);
      expect(score.maxPoints, 3);
      expect(score.percent, 100);
      expect(score.passed, isTrue);
      expect((score.correct, score.incorrect, score.skipped), (2, 0, 0));
    });

    test('points follow each question, partial multi answers score 0', () {
      final score = scoreAttempt(quiz, {
        'q1': ['b'],
        'q2': ['a'],
      });

      expect(score.points, 1);
      expect(score.maxPoints, 3);
      expect(score.percent, closeTo(33.33, 0.01));
      expect(score.passed, isFalse);
      expect((score.correct, score.incorrect, score.skipped), (1, 1, 0));
      expect(
        score.questions.map((q) => (q.questionId, q.points, q.maxPoints)),
        [('q1', 1, 1), ('q2', 0, 2)],
      );
    });

    test('unanswered questions are skipped', () {
      final score = scoreAttempt(quiz, {
        'q2': ['a', 'c'],
      });

      expect(score.points, 2);
      expect((score.correct, score.incorrect, score.skipped), (1, 0, 1));
      expect(score.questions.first.outcome, AnswerOutcome.skipped);
    });

    test('nothing answered scores 0 and fails', () {
      final score = scoreAttempt(quiz, {});

      expect(score.points, 0);
      expect(score.percent, 0);
      expect(score.passed, isFalse);
      expect(score.skipped, 2);
    });

    test('pass/fail compares exactly at the passing score', () {
      // 7 of 10 one-point questions against a 70 % pass mark.
      final questions = [
        for (var i = 0; i < 10; i++) single.copyWith(id: 'q$i'),
      ];
      final ten = quiz.copyWith(questions: questions);
      Map<String, List<String>> correctFor(int n) => {
        for (var i = 0; i < n; i++) 'q$i': ['b'],
      };

      expect(scoreAttempt(ten, correctFor(7)).passed, isTrue);
      expect(scoreAttempt(ten, correctFor(6)).passed, isFalse);

      final strict = ten.copyWith(
        settings: const QuizSettings(passingScorePercent: 100),
      );
      expect(scoreAttempt(strict, correctFor(10)).passed, isTrue);
      expect(scoreAttempt(strict, correctFor(9)).passed, isFalse);

      final anything = ten.copyWith(
        settings: const QuizSettings(passingScorePercent: 0),
      );
      expect(scoreAttempt(anything, {}).passed, isTrue);
    });

    test('pass/fail is exact where percent would round', () {
      // 2 of 3 points = 66.666…%; a 67 % pass mark must fail.
      final three = quiz.copyWith(
        questions: [
          single.copyWith(id: 'x', points: 2),
          single.copyWith(id: 'y'),
        ],
        settings: const QuizSettings(passingScorePercent: 67),
      );
      final score = scoreAttempt(three, {
        'x': ['b'],
      });

      expect(score.percent.round(), 67);
      expect(score.passed, isFalse);
    });

    test('can score only the questions that were asked', () {
      final score = scoreAttempt(
        quiz,
        {
          'q2': ['a', 'c'],
        },
        questions: [multiple],
      );

      expect(score.maxPoints, 2);
      expect(score.percent, 100);
      expect(score.questions.single.questionId, 'q2');
    });

    test('a quiz without questions scores 0', () {
      final score = scoreAttempt(quiz.copyWith(questions: const []), {});

      expect(score.maxPoints, 0);
      expect(score.percent, 0);
      expect(score.passed, isFalse);
    });
  });
}
