import 'package:quiz_core/quiz_core.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  final valid = Quiz.fromJson(readFixture('quiz_v1.json'));
  final first = valid.questions.first;

  /// Replaces the first question with [question].
  Quiz withFirst(Question question) =>
      valid.copyWith(questions: [question, ...valid.questions.skip(1)]);

  List<(String, ValidationCode)> check(Quiz quiz) => [
    for (final issue in validateQuiz(quiz)) (issue.path, issue.code),
  ];

  test('the sample quiz is valid', () {
    expect(validateQuiz(valid), isEmpty);
  });

  group('metadata', () {
    test('id must be a UUID', () {
      expect(check(valid.copyWith(id: 'not-a-uuid')), [
        ('id', ValidationCode.invalidId),
      ]);
    });

    test('title must not be blank', () {
      expect(check(valid.copyWith(title: '  ')), [
        ('title', ValidationCode.emptyText),
      ]);
    });

    test('version must be at least 1', () {
      expect(check(valid.copyWith(version: 0)), [
        ('version', ValidationCode.outOfRange),
      ]);
    });
  });

  group('settings', () {
    test('time limit must be positive when set', () {
      final quiz = valid.copyWith(
        settings: const QuizSettings(timeLimitSeconds: 0),
      );
      expect(check(quiz), [
        ('settings.timeLimitSeconds', ValidationCode.outOfRange),
      ]);
    });

    test('passing score must be 0-100', () {
      for (final percent in [-1, 101]) {
        final quiz = valid.copyWith(
          settings: QuizSettings(passingScorePercent: percent),
        );
        expect(check(quiz), [
          ('settings.passingScorePercent', ValidationCode.outOfRange),
        ]);
      }
    });
  });

  group('questions', () {
    test('at least one question', () {
      expect(check(valid.copyWith(questions: [])), [
        ('questions', ValidationCode.noQuestions),
      ]);
    });

    test('question ids must be unique and non-empty', () {
      final quiz = valid.copyWith(
        questions: [
          first,
          first,
          first.copyWith(id: ''),
        ],
      );
      expect(check(quiz), [
        ('questions[1].id', ValidationCode.duplicateId),
        ('questions[2].id', ValidationCode.emptyId),
      ]);
    });

    test('prompt must not be blank', () {
      expect(check(withFirst(first.copyWith(prompt: ''))), [
        ('questions[0].prompt', ValidationCode.emptyText),
      ]);
    });

    test('points must be at least 1', () {
      expect(check(withFirst(first.copyWith(points: 0))), [
        ('questions[0].points', ValidationCode.outOfRange),
      ]);
    });
  });

  group('options', () {
    List<Option> options(int count) => [
      for (var i = 0; i < count; i++) Option(id: 'o$i', text: 'Option $i'),
    ];

    test('2 to 10 options are allowed', () {
      for (final count in [2, 10]) {
        final q = first.copyWith(
          options: options(count),
          correctOptionIds: ['o0'],
        );
        expect(check(withFirst(q)), isEmpty, reason: '$count options');
      }
    });

    test('fewer than 2 options', () {
      final q = first.copyWith(options: options(1), correctOptionIds: ['o0']);
      expect(check(withFirst(q)), [
        ('questions[0].options', ValidationCode.tooFewOptions),
      ]);
    });

    test('more than 10 options', () {
      final q = first.copyWith(options: options(11), correctOptionIds: ['o0']);
      expect(check(withFirst(q)), [
        ('questions[0].options', ValidationCode.tooManyOptions),
      ]);
    });

    test('option ids must be unique and non-empty', () {
      final q = first.copyWith(
        options: const [
          Option(id: 'a', text: 'A'),
          Option(id: 'a', text: 'B'),
          Option(id: ' ', text: 'C'),
        ],
        correctOptionIds: ['a'],
      );
      expect(check(withFirst(q)), [
        ('questions[0].options[1].id', ValidationCode.duplicateId),
        ('questions[0].options[2].id', ValidationCode.emptyId),
      ]);
    });

    test('option text must not be blank', () {
      final q = first.copyWith(
        options: [
          first.options[0],
          first.options[1].copyWith(text: ''),
        ],
      );
      expect(check(withFirst(q)), [
        ('questions[0].options[1].text', ValidationCode.emptyText),
      ]);
    });
  });

  group('correct options', () {
    test('at least one correct option', () {
      expect(check(withFirst(first.copyWith(correctOptionIds: []))), [
        ('questions[0].correctOptionIds', ValidationCode.noCorrectOption),
      ]);
    });

    test('single questions need exactly one correct option', () {
      final q = first.copyWith(correctOptionIds: ['a', 'b']);
      expect(check(withFirst(q)), [
        (
          'questions[0].correctOptionIds',
          ValidationCode.multipleCorrectInSingle,
        ),
      ]);
    });

    test('multiple questions may have several correct options', () {
      final q = first.copyWith(
        type: QuestionType.multiple,
        correctOptionIds: ['a', 'b'],
      );
      expect(check(withFirst(q)), isEmpty);
    });

    test('correct ids must refer to existing options', () {
      final q = first.copyWith(correctOptionIds: ['z']);
      expect(check(withFirst(q)), [
        ('questions[0].correctOptionIds[0]', ValidationCode.unknownOptionId),
      ]);
    });

    test('correct ids must not repeat', () {
      final q = first.copyWith(
        type: QuestionType.multiple,
        correctOptionIds: ['a', 'a'],
      );
      expect(check(withFirst(q)), [
        ('questions[0].correctOptionIds[1]', ValidationCode.duplicateId),
      ]);
    });
  });

  test('reports every problem at once instead of throwing', () {
    final quiz = valid.copyWith(
      id: '',
      title: '',
      questions: [Question(id: 'q1', prompt: '')],
    );
    expect(check(quiz), [
      ('id', ValidationCode.invalidId),
      ('title', ValidationCode.emptyText),
      ('questions[0].prompt', ValidationCode.emptyText),
      ('questions[0].options', ValidationCode.tooFewOptions),
      ('questions[0].correctOptionIds', ValidationCode.noCorrectOption),
    ]);
  });

  test('issues serialize to JSON for API responses', () {
    final issue = validateQuiz(valid.copyWith(title: '')).single;
    expect(issue.toJson(), {
      'path': 'title',
      'code': 'emptyText',
      'message': 'Title is empty.',
    });
  });

  group('validateQuestion', () {
    test('a valid question has no issues', () {
      expect(validateQuestion(first), isEmpty);
    });

    test('uses paths relative to the question', () {
      final q = first.copyWith(
        prompt: '',
        options: [first.options[0].copyWith(text: '')],
        correctOptionIds: [],
        points: 0,
      );
      expect(
        [for (final i in validateQuestion(q)) (i.path, i.code)],
        [
          ('prompt', ValidationCode.emptyText),
          ('options', ValidationCode.tooFewOptions),
          ('options[0].text', ValidationCode.emptyText),
          ('correctOptionIds', ValidationCode.noCorrectOption),
          ('points', ValidationCode.outOfRange),
        ],
      );
    });

    test('matches validateQuiz for the same question', () {
      final q = first.copyWith(correctOptionIds: ['a', 'b']);
      final inQuiz = validateQuiz(withFirst(q)).map((i) => i.code);
      expect(validateQuestion(q).map((i) => i.code), inQuiz);
    });
  });
}
