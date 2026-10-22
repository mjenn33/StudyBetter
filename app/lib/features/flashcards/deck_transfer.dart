import 'dart:convert';

import 'package:quiz_core/quiz_core.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/deck_repository.dart';

String exportDeckJson(FlashcardDeck deck) =>
    '${const JsonEncoder.withIndent('  ').convert(deck.toJson())}\n';

String deckExportFileName(FlashcardDeck deck) {
  final slug = deck.title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${slug.isEmpty ? 'deck' : slug}.json';
}

class DeckImportException implements Exception {
  const DeckImportException(this.message);
  final String message;
}

(FlashcardDeck, List<ValidationIssue>) readDeckFile(String contents) {
  try {
    final document = parseDocumentString(contents);
    return switch (document) {
      DeckDocument(:final deck) => (deck, validateDeck(deck)),
      QuizDocument() => throw const DeckImportException(
        'This file contains a quiz, not a flashcard deck.',
      ),
    };
  } on DocumentFormatException catch (error) {
    throw DeckImportException(error.message);
  }
}

enum DeckImportChoice { replace, copy }

class DeckImporter {
  DeckImporter(this._decks, {String Function()? newId})
    : _newId = newId ?? const Uuid().v4;
  final DeckRepository _decks;
  final String Function() _newId;

  Future<({String title, bool canReplace})?> existing(
    FlashcardDeck deck,
  ) async {
    final entry = await _decks.getById(deck.id);
    return entry == null
        ? null
        : (title: entry.document.title, canReplace: !entry.isReadOnly);
  }

  Future<FlashcardDeck> import(
    FlashcardDeck deck, {
    DeckImportChoice? choice,
  }) => switch (choice) {
    null => _decks.import(deck),
    DeckImportChoice.replace => _decks.save(deck),
    DeckImportChoice.copy => _decks.import(deck.copyWith(id: _newId())),
  };
}
