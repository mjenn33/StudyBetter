import 'dart:convert';

import 'package:quiz_core/quiz_core.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  final json = readFixture('quiz_v1.json');

  group('Quiz.fromJson', () {
    final quiz = Quiz.fromJson(json);

    test('reads metadata', () {
      expect(quiz.id, '8f6c2a7e-1c1b-4c55-9a0e-4b7e6b0d2f11');
      expect(quiz.title, 'World Capitals');
      expect(quiz.description, 'Capitals of the world, easy level');
      expect(quiz.language, 'en');
      expect(quiz.tags, ['geography', 'capitals']);
      expect(quiz.version, 3);
      expect(quiz.createdAt, DateTime.utc(2026, 10, 21, 10));
      expect(quiz.updatedAt, DateTime.utc(2026, 10, 21, 12, 30));
      expect(quiz.schemaVersion, currentSchemaVersion);
      expect(quiz.kind, DocumentKind.quiz);
    });

    test('reads settings', () {
      expect(
        quiz.settings,
        const QuizSettings(
          shuffleQuestions: true,
          shuffleOptions: true,
          passingScorePercent: 70,
        ),
      );
    });

    test('reads single and multiple questions', () {
      final [single, multiple] = quiz.questions;

      expect(single.type, QuestionType.single);
      expect(single.options.map((o) => o.text), [
        'Sydney',
        'Canberra',
        'Melbourne',
      ]);
      expect(single.correctOptionIds, ['b']);
      expect(single.explanation, startsWith('Canberra'));
      expect(single.points, 1);

      expect(multiple.type, QuestionType.multiple);
      expect(multiple.correctOptionIds, ['a', 'c']);
      expect(multiple.explanation, isNull);
      expect(multiple.points, 2);
    });

    test('applies defaults for optional fields', () {
      final minimal = Quiz.fromJson({
        'id': 'x',
        'title': 'Minimal',
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
        'questions': [
          {'id': 'q1', 'prompt': 'P'},
        ],
      });

      expect(minimal.description, '');
      expect(minimal.language, isNull);
      expect(minimal.tags, isEmpty);
      expect(minimal.version, 1);
      expect(minimal.settings, const QuizSettings());
      expect(minimal.questions.single.type, QuestionType.single);
      expect(minimal.questions.single.points, 1);
    });
  });

  group('Quiz.toJson', () {
    test('round-trips the sample document', () {
      final quiz = Quiz.fromJson(json);
      final encoded = jsonDecode(jsonEncode(quiz.toJson()));

      expect(Quiz.fromJson(encoded as Map<String, dynamic>), quiz);
    });

    test('writes every field of the sample document', () {
      final written = Quiz.fromJson(json).toJson();

      expect(written.keys, unorderedEquals(json.keys));
      expect(written['schemaVersion'], currentSchemaVersion);
      expect(written['kind'], 'quiz');
      expect(jsonDecode(jsonEncode(written))['settings'], json['settings']);
      expect(jsonDecode(jsonEncode(written))['questions'], json['questions']);
    });

    test('writes timestamps in UTC', () {
      final quiz = Quiz.fromJson(
        json,
      ).copyWith(createdAt: DateTime.parse('2026-10-21T12:00:00+02:00'));

      expect(quiz.toJson()['createdAt'], '2026-10-21T10:00:00.000Z');
    });
  });

  test('fromJson ignores schemaVersion and kind in the input', () {
    final quiz = Quiz.fromJson({...json, 'schemaVersion': 99, 'kind': 'x'});

    expect(quiz.schemaVersion, currentSchemaVersion);
    expect(quiz.kind, DocumentKind.quiz);
  });
}
