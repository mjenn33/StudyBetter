import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/features/quizzes/editor/question_edits.dart';

void main() {
  const single = Question(
    id: 'q1',
    prompt: 'Capital of Australia?',
    options: [
      Option(id: 'a', text: 'Sydney'),
      Option(id: 'b', text: 'Canberra'),
      Option(id: 'c', text: 'Melbourne'),
    ],
    correctOptionIds: ['b'],
  );
  final multiple = single.copyWith(
    type: QuestionType.multiple,
    correctOptionIds: ['a', 'c'],
  );

  group('type', () {
    test('switching to multiple keeps the correct options', () {
      final q = single.withType(QuestionType.multiple);
      expect(q.type, QuestionType.multiple);
      expect(q.correctOptionIds, ['b']);
    });

    test('switching to single with one correct option needs no choice', () {
      final q = multiple.copyWith(correctOptionIds: ['c']);
      expect(q.needsCorrectChoiceForSingle, isFalse);
      expect(q.withType(QuestionType.single).correctOptionIds, ['c']);
    });

    test('switching to single with several correct keeps the chosen one', () {
      expect(multiple.needsCorrectChoiceForSingle, isTrue);
      final q = multiple.withType(QuestionType.single, keepCorrectId: 'c');
      expect(q.type, QuestionType.single);
      expect(q.correctOptionIds, ['c']);
      expect(validateQuiz(_quizWith(q)), isEmpty);
    });

    test('the kept id must be one of the correct options', () {
      expect(() => multiple.withType(QuestionType.single), throwsArgumentError);
      expect(
        () => multiple.withType(QuestionType.single, keepCorrectId: 'b'),
        throwsArgumentError,
      );
    });
  });

  group('options', () {
    test('adding uses the next free letter', () {
      final q = single.withOptionAdded();
      expect(q.options.map((o) => o.id), ['a', 'b', 'c', 'd']);
      expect(q.options.last.text, '');
      expect(
        single
            .withOptionRemoved('b')
            .withOptionAdded()
            .options
            .map((o) => o.id),
        ['a', 'c', 'b'],
      );
    });

    test('no more than 10 options', () {
      var q = single;
      for (var i = 0; i < 20; i++) {
        q = q.withOptionAdded();
      }
      expect(q.options, hasLength(maxOptions));
      expect(q.canAddOption, isFalse);
    });

    test('removing drops the option and its correct mark', () {
      final q = single.withOptionRemoved('b');
      expect(q.options.map((o) => o.id), ['a', 'c']);
      expect(q.correctOptionIds, isEmpty);
    });

    test('no fewer than 2 options', () {
      final q = single.withOptionRemoved('a').withOptionRemoved('c');
      expect(q.options.map((o) => o.id), ['b', 'c']);
      expect(q.canRemoveOption, isFalse);
    });

    test('setting option text', () {
      expect(single.withOptionText('a', 'Perth').options.first.text, 'Perth');
    });
  });

  group('correct options', () {
    test('single: marking an option makes it the only correct one', () {
      expect(single.withCorrectToggled('a').correctOptionIds, ['a']);
      expect(single.withCorrectToggled('b').correctOptionIds, ['b']);
    });

    test('multiple: toggles, keeping option order', () {
      expect(multiple.withCorrectToggled('b').correctOptionIds, [
        'a',
        'b',
        'c',
      ]);
      expect(multiple.withCorrectToggled('a').correctOptionIds, ['c']);
    });
  });
}

Quiz _quizWith(Question q) => Quiz(
  id: '8f6c2a7e-1c1b-4c55-9a0e-4b7e6b0d2f11',
  title: 'T',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  questions: [q],
);
