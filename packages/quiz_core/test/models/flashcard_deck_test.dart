import 'dart:convert';

import 'package:quiz_core/quiz_core.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  final json = readFixture('deck_v1.json');

  group('FlashcardDeck.fromJson', () {
    final deck = FlashcardDeck.fromJson(json);

    test('reads metadata', () {
      expect(deck.id, 'c3d1b7a2-5e4f-4a3b-9c8d-1e2f3a4b5c6d');
      expect(deck.title, 'Spanish verbs');
      expect(deck.description, '');
      expect(deck.language, 'es');
      expect(deck.tags, ['spanish']);
      expect(deck.version, 1);
      expect(deck.createdAt, DateTime.utc(2026, 10, 21, 10));
      expect(deck.updatedAt, DateTime.utc(2026, 10, 21, 10));
      expect(deck.schemaVersion, currentSchemaVersion);
      expect(deck.kind, DocumentKind.flashcardDeck);
    });

    test('reads cards', () {
      expect(deck.cards, const [
        Flashcard(id: 'k1', front: 'tener', back: 'to have'),
        Flashcard(
          id: 'k2',
          front: 'hacer',
          back: 'to do / to make',
          hint: 'irregular',
        ),
      ]);
    });

    test('applies defaults for optional fields', () {
      final minimal = FlashcardDeck.fromJson({
        'id': 'x',
        'title': 'Minimal',
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
      });

      expect(minimal.description, '');
      expect(minimal.language, isNull);
      expect(minimal.tags, isEmpty);
      expect(minimal.version, 1);
      expect(minimal.cards, isEmpty);
    });
  });

  group('FlashcardDeck.toJson', () {
    test('round-trips the sample document', () {
      final deck = FlashcardDeck.fromJson(json);
      final encoded = jsonDecode(jsonEncode(deck.toJson()));

      expect(FlashcardDeck.fromJson(encoded as Map<String, dynamic>), deck);
    });

    test('writes every field of the sample document', () {
      final written = jsonDecode(
        jsonEncode(FlashcardDeck.fromJson(json).toJson()),
      );

      expect((written as Map).keys, unorderedEquals(json.keys));
      expect(written['schemaVersion'], currentSchemaVersion);
      expect(written['kind'], 'flashcardDeck');
      expect(written['cards'], json['cards']);
    });
  });

  test('fromJson ignores schemaVersion and kind in the input', () {
    final deck = FlashcardDeck.fromJson({
      ...json,
      'schemaVersion': 99,
      'kind': 'quiz',
    });

    expect(deck.schemaVersion, currentSchemaVersion);
    expect(deck.kind, DocumentKind.flashcardDeck);
  });
}
