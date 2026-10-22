import 'package:freezed_annotation/freezed_annotation.dart';

import '../schema.dart';
import 'utc_date_time_converter.dart';

part 'flashcard_deck.freezed.dart';
part 'flashcard_deck.g.dart';

/// A flashcard deck document (`kind: flashcardDeck`), as exported, uploaded
/// and downloaded.
///
/// Like [Quiz], the model always represents the current
/// [currentSchemaVersion]: `schemaVersion` and `kind` are written by [toJson]
/// but not read by [FlashcardDeck.fromJson]. Review progress is personal and
/// never part of the document.
@freezed
abstract class FlashcardDeck with _$FlashcardDeck {
  const factory FlashcardDeck({
    @JsonKey(includeFromJson: false, includeToJson: true)
    @Default(currentSchemaVersion)
    int schemaVersion,
    @JsonKey(includeFromJson: false, includeToJson: true)
    @Default(DocumentKind.flashcardDeck)
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
    @Default(<Flashcard>[]) List<Flashcard> cards,
  }) = _FlashcardDeck;

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) =>
      _$FlashcardDeckFromJson(json);
}

/// One card of a [FlashcardDeck].
@freezed
abstract class Flashcard with _$Flashcard {
  const factory Flashcard({
    /// Unique within the deck; review progress is stored per card id.
    required String id,
    required String front,
    required String back,

    /// Optional hint shown before flipping the card.
    String? hint,
  }) = _Flashcard;

  factory Flashcard.fromJson(Map<String, dynamic> json) =>
      _$FlashcardFromJson(json);
}
