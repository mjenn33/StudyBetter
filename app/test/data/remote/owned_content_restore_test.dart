import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/data/remote/api_client.dart';
import 'package:study_better/data/remote/owned_content_restore.dart';
import 'package:study_better/data/repositories/deck_repository.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';

import '../../helpers.dart';

class _RestoreApi extends ApiClient {
  _RestoreApi(this.respond) : super('https://example.test/api/v1');

  final Future<Object?> Function(String path) respond;

  @override
  Future<bool> get isSignedIn async => true;

  @override
  Future<Object?> request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    int? version,
    bool authenticated = true,
  }) {
    expect(method, 'GET');
    return respond(path);
  }
}

Map<String, dynamic> _json(Object document) =>
    jsonDecode(jsonEncode(document)) as Map<String, dynamic>;

void main() {
  test('restores owned quizzes and decks from the account library', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final quiz = testQuiz().copyWith(version: 2, title: 'From cloud');
    final deck = FlashcardDeck(
      id: 'deck',
      title: 'From cloud deck',
      version: 3,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      cards: const [Flashcard(id: 'card', front: 'Front', back: 'Back')],
    );
    final api = _RestoreApi(
      (path) async => switch (path) {
        '/me' => {'username': 'sam'},
        '/me/quizzes' => [
          {'id': quiz.id},
        ],
        '/me/decks' => [
          {'id': deck.id},
        ],
        _ when path == '/quizzes/${quiz.id}' => _json(quiz.toJson()),
        _ when path == '/decks/${deck.id}' => _json(deck.toJson()),
        _ => throw StateError('Unexpected path: $path'),
      },
    );
    addTearDown(api.close);

    final result = await restoreOwnedContent(
      api: api,
      quizzes: QuizRepository(db),
      decks: DeckRepository(db),
    );

    expect(result.restored, 2);
    expect(result.skipped, 0);
    expect((await QuizRepository(db).getById(quiz.id))!.isOwnedByMe, true);
    expect((await DeckRepository(db).getById(deck.id))!.remoteVersion, 3);
  });

  test('keeps an owned quiz with newer local edits', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repository = QuizRepository(db);
    final base = testQuiz();
    await repository.storeRemote(
      base,
      remoteId: base.id,
      remoteVersion: 1,
      ownerName: 'sam',
      owned: true,
    );
    await repository.save(base.copyWith(title: 'Local edits'));
    final server = base.copyWith(version: 2, title: 'Server edits');
    final api = _RestoreApi(
      (path) async => switch (path) {
        '/me' => {'username': 'sam'},
        '/me/quizzes' => [
          {'id': base.id},
        ],
        '/me/decks' => <Map<String, dynamic>>[],
        _ when path == '/quizzes/${base.id}' => _json(server.toJson()),
        _ => throw StateError('Unexpected path: $path'),
      },
    );
    addTearDown(api.close);

    final result = await restoreOwnedContent(
      api: api,
      quizzes: repository,
      decks: DeckRepository(db),
    );

    expect(result.restored, 0);
    expect(result.skipped, 1);
    expect((await repository.getById(base.id))!.document.title, 'Local edits');
  });
}
