import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/database/database_provider.dart';
import 'package:study_better/data/repositories/library_repository.dart';
import 'package:study_better/data/repositories/providers.dart';
import 'package:study_better/features/quizzes/editor/editor_ids.dart';
import 'package:study_better/features/quizzes/editor/quiz_editor_controller.dart';

import '../../../helpers.dart';

void main() {
  group('editor ids', () {
    test('nextQuestionId takes the first free q<n>', () {
      expect(nextQuestionId([]), 'q1');
      expect(nextQuestionId(['q1', 'q2']), 'q3');
      expect(nextQuestionId(['q1', 'q3']), 'q2');
      expect(nextQuestionId(['x', 'q1']), 'q2');
    });

    test('nextOptionId takes the first free letter', () {
      expect(nextOptionId([]), 'a');
      expect(nextOptionId(['a', 'b']), 'c');
      expect(nextOptionId(['a', 'c']), 'b');
      final all = [for (var i = 0; i < 26; i++) String.fromCharCode(97 + i)];
      expect(nextOptionId(all), 'aa');
      expect(nextOptionId([...all, 'aa']), 'ab');
    });
  });

  group('QuizEditorController', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = testDatabase();
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<QuizEditorController> open(String? id) async {
      final provider = quizEditorProvider(id);
      container.listen(provider, (_, _) {});
      await container.read(provider.future);
      return container.read(provider.notifier);
    }

    QuizEditorState stateOf(String? id) =>
        container.read(quizEditorProvider(id)).requireValue;

    test('a new quiz starts empty, clean and unsaveable', () async {
      await open(null);
      final state = stateOf(null);

      expect(state.isNew, isTrue);
      expect(state.draft.title, '');
      expect(state.draft.questions, isEmpty);
      expect(state.isDirty, isFalse);
      expect(state.canSave, isFalse);
    });

    test('edits make the draft dirty and saveable as a draft', () async {
      final editor = await open(null);

      editor.setDescription('About capitals');
      expect(stateOf(null).isDirty, isTrue);
      expect(stateOf(null).canSave, isTrue);

      editor.setTitle('  World Capitals ');
      expect(stateOf(null).canSave, isTrue);
    });

    test('saves an incomplete quiz as a draft', () async {
      final editor = await open(null);
      editor.setDescription('Questions will be added later.');

      final saved = await editor.save();

      expect(saved.title, isEmpty);
      expect(saved.questions, isEmpty);
      expect(validateQuiz(saved), isNotEmpty);
      expect(stateOf(null).isDirty, isFalse);
    });

    test('save stores the quiz and makes the editor clean', () async {
      final editor = await open(null);
      editor
        ..setTitle('  World Capitals ')
        ..setLanguage(' en ')
        ..addTag('geo')
        ..addTag('geo')
        ..addTag('  ')
        ..setSettings(const QuizSettings(shuffleQuestions: true));

      final saved = await editor.save();

      expect(saved.title, 'World Capitals');
      expect(saved.language, 'en');
      expect(saved.tags, ['geo']);
      expect(saved.settings.shuffleQuestions, isTrue);
      expect(stateOf(null).isDirty, isFalse);
      expect(stateOf(null).isNew, isFalse);
      final entry = await container
          .read(quizRepositoryProvider)
          .getById(saved.id);
      expect(entry!.document, saved);
    });

    test('blank language clears it; tags can be removed', () async {
      final editor = await open(null);
      editor
        ..setLanguage('es')
        ..setLanguage('  ')
        ..addTag('a')
        ..addTag('b')
        ..removeTag('a');

      expect(stateOf(null).draft.language, isNull);
      expect(stateOf(null).draft.tags, ['b']);
    });

    test('opens an existing quiz and bumps its version on save', () async {
      final quiz = await container
          .read(quizRepositoryProvider)
          .save(testQuiz(title: 'Old'));
      final editor = await open(quiz.id);
      expect(stateOf(quiz.id).draft, quiz);
      expect(stateOf(quiz.id).isNew, isFalse);

      editor.setTitle('New');
      final saved = await editor.save();

      expect(saved.version, quiz.version + 1);
      expect(saved.title, 'New');
    });

    test('refuses read-only and missing quizzes', () async {
      Future<QuizEditorState> load(String id) {
        final provider = quizEditorProvider(id);
        container.listen(provider, (_, _) {});
        return container.read(provider.future);
      }

      await expectLater(load('missing'), throwsA(isA<ItemNotFoundException>()));

      final quiz = await container
          .read(quizRepositoryProvider)
          .save(testQuiz());
      await (db.update(db.quizzes)..where((q) => q.id.equals(quiz.id))).write(
        const QuizzesCompanion(isOwnedByMe: Value(false)),
      );
      await expectLater(load(quiz.id), throwsA(isA<ReadOnlyItemException>()));
    });

    test('adds, updates, removes, restores and reorders questions', () async {
      final editor = await open(null);
      Question add() {
        final question = editor.newQuestion();
        editor.addQuestion(question);
        return question;
      }

      editor.newQuestion();
      expect(stateOf(null).draft.questions, isEmpty);

      final q1 = add();
      final q2 = add();
      final q3 = add();

      expect([q1.id, q2.id, q3.id], ['q1', 'q2', 'q3']);
      expect(q1.options.map((o) => o.id), ['a', 'b']);
      expect(q1.type, QuestionType.single);

      editor.updateQuestion(q2.copyWith(prompt: 'Second'));
      expect(stateOf(null).draft.questions[1].prompt, 'Second');

      editor.moveQuestion(0, 2);
      List<String> ids() =>
          stateOf(null).draft.questions.map((q) => q.id).toList();
      expect(ids(), ['q2', 'q3', 'q1']);
      editor.moveQuestion(2, 0);
      expect(ids(), ['q1', 'q2', 'q3']);

      editor.removeQuestion('q2');
      expect(ids(), ['q1', 'q3']);
      editor.insertQuestion(1, q2);
      expect(ids(), ['q1', 'q2', 'q3']);

      editor.removeQuestion('q1');
      expect(editor.newQuestion().id, 'q1');
    });
  });
}
