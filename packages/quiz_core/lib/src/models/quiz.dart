import 'package:freezed_annotation/freezed_annotation.dart';

import '../schema.dart';
import 'utc_date_time_converter.dart';

part 'quiz.freezed.dart';
part 'quiz.g.dart';

/// Whether a question has exactly one or possibly several correct options.
enum QuestionType { single, multiple }

/// A quiz document (`kind: quiz`), as exported, uploaded and downloaded.
///
/// The model always represents the current [currentSchemaVersion]:
/// `schemaVersion` and `kind` are written by [toJson] but not read by
/// [Quiz.fromJson]. Use `parseDocument` to read documents of any supported
/// version.
@freezed
abstract class Quiz with _$Quiz {
  const factory Quiz({
    @JsonKey(includeFromJson: false, includeToJson: true)
    @Default(currentSchemaVersion)
    int schemaVersion,
    @JsonKey(includeFromJson: false, includeToJson: true)
    @Default(DocumentKind.quiz)
    DocumentKind kind,

    /// UUID, stable across versions and devices.
    required String id,
    required String title,
    @Default('') String description,

    /// BCP 47 language tag such as `en` or `es`, if known.
    String? language,
    @Default(<String>[]) List<String> tags,

    /// Incremented on every saved change; used for optimistic concurrency.
    @Default(1) int version,
    @UtcDateTimeConverter() required DateTime createdAt,
    @UtcDateTimeConverter() required DateTime updatedAt,
    @Default(QuizSettings()) QuizSettings settings,
    @Default(<Question>[]) List<Question> questions,
  }) = _Quiz;

  factory Quiz.fromJson(Map<String, dynamic> json) => _$QuizFromJson(json);
}

/// How a quiz is played.
@freezed
abstract class QuizSettings with _$QuizSettings {
  const factory QuizSettings({
    @Default(false) bool shuffleQuestions,
    @Default(false) bool shuffleOptions,

    /// Time limit for the whole quiz, or `null` for no limit.
    int? timeLimitSeconds,
    @Default(70) int passingScorePercent,
  }) = _QuizSettings;

  factory QuizSettings.fromJson(Map<String, dynamic> json) =>
      _$QuizSettingsFromJson(json);
}

/// A multiple-choice question.
@freezed
abstract class Question with _$Question {
  const factory Question({
    /// Unique within the quiz.
    required String id,
    required String prompt,
    @Default(QuestionType.single) QuestionType type,
    @Default(<Option>[]) List<Option> options,

    /// Ids of the correct [options].
    @Default(<String>[]) List<String> correctOptionIds,

    /// Shown after answering, if set.
    String? explanation,
    @Default(1) int points,
  }) = _Question;

  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);
}

/// One answer option of a [Question].
@freezed
abstract class Option with _$Option {
  const factory Option({
    /// Unique within the question.
    required String id,
    required String text,
  }) = _Option;

  factory Option.fromJson(Map<String, dynamic> json) => _$OptionFromJson(json);
}
