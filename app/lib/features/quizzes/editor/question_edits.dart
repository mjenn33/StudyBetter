import 'package:quiz_core/quiz_core.dart';

import 'editor_ids.dart';

/// Pure edits on a [Question], used by the question editor.
extension QuestionEdits on Question {
  bool get canAddOption => options.length < maxOptions;
  bool get canRemoveOption => options.length > minOptions;

  /// Whether switching to [QuestionType.single] needs the user to pick which
  /// of several correct options to keep.
  bool get needsCorrectChoiceForSingle => correctOptionIds.toSet().length > 1;

  /// This question with [type]. When switching to `single` with several
  /// correct options, [keepCorrectId] says which one stays correct.
  Question withType(QuestionType type, {String? keepCorrectId}) {
    if (type == QuestionType.multiple || !needsCorrectChoiceForSingle) {
      return copyWith(type: type);
    }
    if (keepCorrectId == null || !correctOptionIds.contains(keepCorrectId)) {
      throw ArgumentError.value(
        keepCorrectId,
        'keepCorrectId',
        'must be one of the correct options',
      );
    }
    return copyWith(type: type, correctOptionIds: [keepCorrectId]);
  }

  /// Appends an empty option with the next free id, up to [maxOptions].
  Question withOptionAdded() {
    if (!canAddOption) return this;
    final id = nextOptionId(options.map((o) => o.id));
    return copyWith(
      options: [
        ...options,
        Option(id: id, text: ''),
      ],
    );
  }

  /// Removes option [id] (and its correct mark), keeping at least
  /// [minOptions].
  Question withOptionRemoved(String id) {
    if (!canRemoveOption) return this;
    return copyWith(
      options: options.where((o) => o.id != id).toList(),
      correctOptionIds: correctOptionIds.where((c) => c != id).toList(),
    );
  }

  Question withOptionText(String id, String text) => copyWith(
    options: [for (final o in options) o.id == id ? o.copyWith(text: text) : o],
  );

  bool isCorrect(String optionId) => correctOptionIds.contains(optionId);

  /// Marks option [id] correct. For `single` it becomes the only correct
  /// option; for `multiple` it toggles. Correct ids keep the options' order.
  Question withCorrectToggled(String id) {
    if (type == QuestionType.single) {
      return copyWith(correctOptionIds: [id]);
    }
    final selected = isCorrect(id)
        ? correctOptionIds.where((c) => c != id).toSet()
        : {...correctOptionIds, id};
    return copyWith(
      correctOptionIds: [
        for (final o in options)
          if (selected.contains(o.id)) o.id,
      ],
    );
  }
}
