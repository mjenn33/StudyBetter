import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/providers.dart';
import '../issue_index.dart';
import 'editor_ids.dart';

/// The quiz being edited: the last saved version and the working draft.
class QuizEditorState {
  QuizEditorState({
    required this.saved,
    required this.draft,
    required this.isNew,
  });

  /// The quiz as last saved (or as first created, for a new quiz).
  final Quiz saved;
  final Quiz draft;

  /// True until a new quiz is saved for the first time.
  final bool isNew;

  bool get isDirty => draft != saved;

  /// A quiz needs a title before it can be saved. Other problems don't block
  /// saving: an invalid quiz is kept as a draft that can't be played yet.
  bool get canSave => isDirty && draft.title.trim().isNotEmpty;

  /// Validation problems of the draft, by path.
  late final IssueIndex issues = IssueIndex(validateQuiz(draft));

  /// Problems are shown once there is something to judge: for an existing
  /// quiz right away, for a new one after the first change.
  bool get showIssues => !isNew || isDirty;

  QuizEditorState copyWith({Quiz? saved, Quiz? draft, bool? isNew}) =>
      QuizEditorState(
        saved: saved ?? this.saved,
        draft: draft ?? this.draft,
        isNew: isNew ?? this.isNew,
      );
}

/// Edits the quiz with the given id, or a new quiz when the id is `null`.
///
/// Changes stay in memory until [save]; leaving the editor discards them.
final quizEditorProvider = AsyncNotifierProvider.autoDispose
    .family<QuizEditorController, QuizEditorState, String?>(
      QuizEditorController.new,
      // A missing or read-only quiz won't fix itself; show the error at once
      // instead of Riverpod's default retries.
      retry: (_, _) => null,
    );

class QuizEditorController extends AsyncNotifier<QuizEditorState> {
  QuizEditorController(this.quizId);

  /// `null` for a new quiz.
  final String? quizId;

  @override
  Future<QuizEditorState> build() async {
    final id = quizId;
    if (id == null) {
      final now = DateTime.now().toUtc();
      final quiz = Quiz(
        id: const Uuid().v4(),
        title: '',
        createdAt: now,
        updatedAt: now,
      );
      return QuizEditorState(saved: quiz, draft: quiz, isNew: true);
    }

    final entry = await ref.read(quizRepositoryProvider).getById(id);
    if (entry == null) throw ItemNotFoundException(id);
    if (entry.isReadOnly) throw ReadOnlyItemException(id);
    return QuizEditorState(
      saved: entry.document,
      draft: entry.document,
      isNew: false,
    );
  }

  QuizEditorState get _current => state.requireValue;

  void _update(Quiz Function(Quiz draft) change) {
    state = AsyncData(_current.copyWith(draft: change(_current.draft)));
  }

  void setTitle(String title) => _update((q) => q.copyWith(title: title));

  void setDescription(String description) =>
      _update((q) => q.copyWith(description: description));

  /// Sets the language tag; blank clears it.
  void setLanguage(String language) => _update(
    (q) =>
        q.copyWith(language: language.trim().isEmpty ? null : language.trim()),
  );

  /// Adds [tag] (trimmed) unless it is blank or already present.
  void addTag(String tag) {
    final value = tag.trim();
    if (value.isEmpty || _current.draft.tags.contains(value)) return;
    _update((q) => q.copyWith(tags: [...q.tags, value]));
  }

  void removeTag(String tag) =>
      _update((q) => q.copyWith(tags: q.tags.where((t) => t != tag).toList()));

  void setSettings(QuizSettings settings) =>
      _update((q) => q.copyWith(settings: settings));

  /// A blank single-answer question with two empty options and the next free
  /// id. It isn't part of the quiz until passed to [addQuestion].
  Question newQuestion() => Question(
    id: nextQuestionId(_current.draft.questions.map((q) => q.id)),
    prompt: '',
    options: const [
      Option(id: 'a', text: ''),
      Option(id: 'b', text: ''),
    ],
  );

  /// Appends [question] to the quiz.
  void addQuestion(Question question) =>
      _update((q) => q.copyWith(questions: [...q.questions, question]));

  /// Replaces the question with the same id as [question].
  void updateQuestion(Question question) => _update(
    (q) => q.copyWith(
      questions: [
        for (final existing in q.questions)
          existing.id == question.id ? question : existing,
      ],
    ),
  );

  void removeQuestion(String id) => _update(
    (q) => q.copyWith(questions: q.questions.where((x) => x.id != id).toList()),
  );

  /// Inserts [question] at [index] (used to undo [removeQuestion]).
  void insertQuestion(int index, Question question) => _update(
    (q) => q.copyWith(
      questions: [...q.questions]
        ..insert(index.clamp(0, q.questions.length), question),
    ),
  );

  /// Moves the question at [oldIndex] so it ends up at [newIndex] (the
  /// indexes `ReorderableList.onReorderItem` reports).
  void moveQuestion(int oldIndex, int newIndex) => _update((q) {
    final questions = [...q.questions];
    questions.insert(newIndex, questions.removeAt(oldIndex));
    return q.copyWith(questions: questions);
  });

  /// Saves the draft and returns the saved quiz.
  Future<Quiz> save() async {
    final current = _current;
    if (!current.canSave) return current.saved;
    final saved = await ref
        .read(quizRepositoryProvider)
        .save(current.draft.copyWith(title: current.draft.title.trim()));
    state = AsyncData(
      QuizEditorState(saved: saved, draft: saved, isNew: false),
    );
    return saved;
  }
}
