import 'dart:convert';

import 'package:quiz_core/quiz_core.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

Matcher throwsFormat(String messagePart, {String? path}) => throwsA(
  isA<DocumentFormatException>()
      .having((e) => e.message, 'message', contains(messagePart))
      .having((e) => e.path, 'path', path),
);

void main() {
  final quizJson = readFixture('quiz_v1.json');
  final deckJson = readFixture('deck_v1.json');

  group('parseDocument', () {
    test('dispatches a quiz', () {
      final doc = parseDocument(quizJson);

      expect(doc, isA<QuizDocument>());
      expect(doc.kind, DocumentKind.quiz);
      expect((doc as QuizDocument).quiz, Quiz.fromJson(quizJson));
    });

    test('dispatches a flashcard deck', () {
      final doc = parseDocument(deckJson);

      expect(doc, isA<DeckDocument>());
      expect((doc as DeckDocument).deck, FlashcardDeck.fromJson(deckJson));
    });

    test('toJson writes the current schema', () {
      expect(parseDocument(quizJson).toJson()['kind'], 'quiz');
      expect(parseDocument(deckJson).toJson()['kind'], 'flashcardDeck');
    });

    test('rejects a missing kind', () {
      expect(
        () => parseDocument({...quizJson}..remove('kind')),
        throwsFormat('Missing "kind"', path: 'kind'),
      );
    });

    test('rejects an unknown kind', () {
      expect(
        () => parseDocument({...quizJson, 'kind': 'poll'}),
        throwsFormat('Unknown kind "poll"', path: 'kind'),
      );
    });

    test('rejects a newer schema version', () {
      expect(
        () => parseDocument({...quizJson, 'schemaVersion': 2}),
        throwsFormat('Update the app', path: 'schemaVersion'),
      );
    });

    test('rejects a missing schema version', () {
      expect(
        () => parseDocument({...quizJson}..remove('schemaVersion')),
        throwsFormat('schemaVersion', path: 'schemaVersion'),
      );
    });

    test('reports missing or mistyped fields as DocumentFormatException', () {
      expect(
        () => parseDocument({...quizJson}..remove('title')),
        throwsFormat('missing or invalid fields'),
      );
      expect(
        () => parseDocument({...deckJson, 'cards': 'nope'}),
        throwsFormat('missing or invalid fields'),
      );
      expect(
        () => parseDocument({
          ...quizJson,
          'questions': [
            {'id': 'q1', 'prompt': 'P', 'type': 'essay'},
          ],
        }),
        throwsFormat('missing or invalid fields'),
      );
    });

    test('upgrades an older document with the migration pipeline', () {
      // A fake v0 format that called the questions "items".
      final v0 = {...quizJson, 'schemaVersion': 0}..remove('questions');
      v0['items'] = quizJson['questions'];

      final doc = parseDocument(
        v0,
        migrations: {0: (json) => json..['questions'] = json.remove('items')},
      );

      expect((doc as QuizDocument).quiz, Quiz.fromJson(quizJson));
    });
  });

  group('migrateDocument', () {
    test('leaves a current document unchanged', () {
      expect(migrateDocument(quizJson), quizJson);
    });

    test('applies each step in order and sets schemaVersion', () {
      final steps = <int>[];
      final result = migrateDocument(
        {'schemaVersion': 0, 'log': <int>[]},
        targetVersion: 3,
        migrations: {
          for (final from in [0, 1, 2])
            from: (json) {
              steps.add(json['schemaVersion'] as int);
              return json;
            },
        },
      );

      expect(steps, [0, 1, 2]);
      expect(result['schemaVersion'], 3);
    });

    test('does not modify its input', () {
      final input = {'schemaVersion': 0, 'a': 1};
      migrateDocument(input, migrations: {0: (json) => json..['a'] = 2});

      expect(input, {'schemaVersion': 0, 'a': 1});
    });

    test('fails when a step in the chain is missing', () {
      expect(
        () => migrateDocument(
          {'schemaVersion': 0},
          targetVersion: 3,
          migrations: {0: (json) => json, 2: (json) => json},
        ),
        throwsFormat('no migration from version 1 to 2', path: 'schemaVersion'),
      );
    });

    test('fails for versions older than any migration', () {
      expect(
        () => migrateDocument({'schemaVersion': 0}),
        throwsFormat(
          'Format version 0 is not supported',
          path: 'schemaVersion',
        ),
      );
    });
  });

  group('parseDocumentString', () {
    test('parses a JSON file', () {
      final doc = parseDocumentString(jsonEncode(quizJson));

      expect(doc, isA<QuizDocument>());
    });

    test('rejects text that is not JSON', () {
      expect(
        () => parseDocumentString('{oops'),
        throwsFormat('Not valid JSON'),
      );
    });

    test('rejects JSON that is not an object', () {
      expect(() => parseDocumentString('[1, 2]'), throwsFormat('JSON object'));
    });
  });
}
