import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/features/quizzes/editor/question_editor_screen.dart';

import '../../../helpers.dart';

/// Opens the editor on [question] from a host page and records the result.
class _Harness {
  Question? result;
  bool closed = false;

  Future<void> open(WidgetTester tester, Question question) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await editQuestion(context, question);
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

const blank = Question(
  id: 'q1',
  prompt: '',
  options: [
    Option(id: 'a', text: ''),
    Option(id: 'b', text: ''),
  ],
);

Finder optionField(int n) => find.widgetWithText(TextField, 'Option $n');

void main() {
  testWidgets('edits prompt, options, correct answer and returns them', (
    tester,
  ) async {
    final h = _Harness();
    await h.open(tester, blank);

    await enter(
      tester,
      find.widgetWithText(TextField, 'Question'),
      'Capital of Australia?',
    );
    await enter(tester, optionField(1), 'Sydney');
    await enter(tester, optionField(2), 'Canberra');
    await tester.tap(find.text('Add option'));
    await tester.pumpAndSettle();
    await enter(tester, optionField(3), 'Melbourne');
    await tester.tap(find.byType(Radio<String>).at(1));
    await enter(
      tester,
      find.widgetWithText(TextField, 'Explanation (optional)'),
      'Purpose-built capital.',
    );
    await enter(tester, find.widgetWithText(TextField, 'Points'), '2');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final q = h.result!;
    expect(q.id, 'q1');
    expect(q.prompt, 'Capital of Australia?');
    expect(q.options.map((o) => (o.id, o.text)), [
      ('a', 'Sydney'),
      ('b', 'Canberra'),
      ('c', 'Melbourne'),
    ]);
    expect(q.correctOptionIds, ['b']);
    expect(q.explanation, 'Purpose-built capital.');
    expect(q.points, 2);
  });

  testWidgets('multiple answers use checkboxes', (tester) async {
    final h = _Harness();
    await h.open(tester, blank);

    await tester.tap(find.text('Multiple answers'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(h.result!.type, QuestionType.multiple);
    expect(h.result!.correctOptionIds, ['a', 'b']);
  });

  testWidgets('keeps between 2 and 10 options', (tester) async {
    final h = _Harness();
    await h.open(tester, blank);

    IconButton remove(int n) => tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.close).at(n),
    );
    expect(remove(0).onPressed, isNull);

    for (var i = 0; i < 8; i++) {
      await tester.tap(find.text('Add option'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Add option (max 10)'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Add option (max 10)'),
          )
          .onPressed,
      isNull,
    );
    expect(remove(0).onPressed, isNotNull);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.close).first);
    await tester.pumpAndSettle();
    expect(optionField(10), findsNothing);
    expect(find.text('Add option'), findsOneWidget);
  });

  group('switching to single with several correct options', () {
    final multiple = blank.copyWith(
      type: QuestionType.multiple,
      options: const [
        Option(id: 'a', text: 'Ottawa'),
        Option(id: 'b', text: 'Toronto'),
        Option(id: 'c', text: 'Nairobi'),
      ],
      correctOptionIds: ['a', 'c'],
    );

    testWidgets('asks which one to keep', (tester) async {
      final h = _Harness();
      await h.open(tester, multiple);

      await tester.tap(find.text('Single answer'));
      await tester.pumpAndSettle();
      expect(find.text('Keep which answer?'), findsOneWidget);

      await tester.tap(find.widgetWithText(RadioListTile<String>, 'Nairobi'));
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(h.result!.type, QuestionType.single);
      expect(h.result!.correctOptionIds, ['c']);
    });

    testWidgets('cancel keeps it multiple', (tester) async {
      final h = _Harness();
      await h.open(tester, multiple);

      await tester.tap(find.text('Single answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNWidgets(3));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(h.result!.type, QuestionType.multiple);
      expect(h.result!.correctOptionIds, ['a', 'c']);
    });

    testWidgets('no question when at most one option is correct', (
      tester,
    ) async {
      final h = _Harness();
      await h.open(tester, multiple.copyWith(correctOptionIds: ['a']));

      await tester.tap(find.text('Single answer'));
      await tester.pumpAndSettle();

      expect(find.text('Keep which answer?'), findsNothing);
      expect(find.byType(Radio<String>), findsNWidgets(3));
    });
  });

  testWidgets('closing with changes asks before discarding them', (
    tester,
  ) async {
    final h = _Harness();
    await h.open(tester, blank);

    await enter(tester, find.widgetWithText(TextField, 'Question'), 'Q');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(h.closed, isTrue);
    expect(h.result, isNull);
  });

  testWidgets('closing without changes returns nothing', (tester) async {
    final h = _Harness();
    await h.open(tester, blank);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(h.closed, isTrue);
    expect(h.result, isNull);
  });
}
