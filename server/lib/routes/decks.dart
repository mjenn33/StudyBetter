import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/auth_service.dart';
import '../json_response.dart';
import 'catalog.dart';

class DeckRoutes {
  DeckRoutes(this.connection, this.auth);

  final Connection connection;
  final AuthService auth;

  Future<Response> catalog(Request request) =>
      catalogResponse(connection, 'decks', request);

  Future<Response> get(Request request) async {
    final id = request.params['id']!;
    final rows = await connection.execute(
      Sql.named(
        'SELECT owner_id, visibility::text, document::text FROM decks WHERE id = @id',
      ),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return Response.notFound('Deck not found');

    final row = rows.first;
    final userId = authenticatedUserId(request, auth);
    if (row[1] as String == 'private' && userId != row[0] as String) {
      return Response.notFound('Deck not found');
    }
    final updated = await connection.execute(
      Sql.named(
        'UPDATE decks SET download_count = download_count + 1 WHERE id = @id RETURNING version',
      ),
      parameters: {'id': id},
    );
    return jsonResponse(
      jsonDecode(row[2] as String),
      headers: {'etag': '${updated.first[0]}'},
    );
  }

  Future<Response> create(Request request) async {
    final uploaded = await _uploadedDeck(request);
    if (uploaded is _InvalidDeck) return uploaded.response;
    final valid = uploaded as _ValidDeck;
    final deck = valid.deck.copyWith(version: 1);
    try {
      await _insert(
        deck,
        request.context[currentUserIdKey] as String,
        valid.visibility,
      );
    } on ServerException {
      return jsonResponse({
        'error': 'a deck with this id already exists',
      }, statusCode: 409);
    }
    return jsonResponse(deck.toJson(), statusCode: 201);
  }

  Future<Response> update(Request request) async {
    final id = request.params['id']!;
    final expectedVersion = int.tryParse(request.headers['if-match'] ?? '');
    if (expectedVersion == null) {
      return jsonResponse({
        'error': 'If-Match: <version> is required',
      }, statusCode: 400);
    }
    final uploaded = await _uploadedDeck(request);
    if (uploaded is _InvalidDeck) return uploaded.response;
    final valid = uploaded as _ValidDeck;
    final userId = request.context[currentUserIdKey] as String;
    final rows = await connection.execute(
      Sql.named('SELECT owner_id, version FROM decks WHERE id = @id'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return Response.notFound('Deck not found');
    if (rows.first[0] as String != userId) {
      return jsonResponse({
        'error': 'only the owner can update this deck',
      }, statusCode: 403);
    }
    final version = rows.first[1] as int;
    if (version != expectedVersion) {
      return jsonResponse({
        'error': 'version conflict',
        'version': version,
      }, statusCode: 409);
    }

    final deck = valid.deck.copyWith(id: id, version: version + 1);
    final result = await connection.execute(
      Sql.named('''
        UPDATE decks
        SET title = @title, description = @description, tags = @tags,
            language = @language, visibility = @visibility, version = @version,
            item_count = @itemCount, document = CAST(@document AS jsonb),
            search_vector = to_tsvector('simple', @searchText), updated_at = now()
        WHERE id = @id AND owner_id = @owner AND version = @expectedVersion
      '''),
      parameters: _parameters(deck, userId, valid.visibility)
        ..['id'] = id
        ..['expectedVersion'] = expectedVersion,
    );
    if (result.affectedRows == 0) {
      return jsonResponse({'error': 'version conflict'}, statusCode: 409);
    }
    return jsonResponse(deck.toJson());
  }

  Future<Response> delete(Request request) async {
    final id = request.params['id']!;
    final userId = request.context[currentUserIdKey] as String;
    final rows = await connection.execute(
      Sql.named('SELECT owner_id FROM decks WHERE id = @id'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return Response.notFound('Deck not found');
    if (rows.first[0] as String != userId) {
      return jsonResponse({
        'error': 'only the owner can delete this deck',
      }, statusCode: 403);
    }
    await connection.execute(
      Sql.named('DELETE FROM decks WHERE id = @id AND owner_id = @owner'),
      parameters: {'id': id, 'owner': userId},
    );
    return Response(204);
  }

  Future<Response> mine(Request request) async {
    final rows = await connection.execute(
      Sql.named('''
        SELECT id, title, description, tags, language, visibility::text, version,
               item_count, download_count, created_at, updated_at
        FROM decks WHERE owner_id = @owner ORDER BY updated_at DESC
      '''),
      parameters: {'owner': request.context[currentUserIdKey]},
    );
    return jsonResponse([for (final row in rows) _summary(row)]);
  }

  Future<void> _insert(
    FlashcardDeck deck,
    String ownerId,
    String visibility,
  ) async {
    await connection.execute(
      Sql.named('''
        INSERT INTO decks (
          id, owner_id, title, description, tags, language, visibility, version,
          item_count, document, search_vector
        ) VALUES (
          @id, @owner, @title, @description, @tags, @language, @visibility,
          @version, @itemCount, CAST(@document AS jsonb),
          to_tsvector('simple', @searchText)
        )
      '''),
      parameters: _parameters(deck, ownerId, visibility),
    );
  }

  Future<_UploadedDeck> _uploadedDeck(Request request) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(await request.readAsString());
    } on FormatException catch (error) {
      return _InvalidDeck(
        _validationResponse([
          {'path': '', 'code': 'invalidJson', 'message': error.message},
        ]),
      );
    }
    if (decoded is! Map<String, dynamic>) {
      return _InvalidDeck(
        _validationResponse([
          {
            'path': '',
            'code': 'invalidDocument',
            'message': 'Expected a JSON object.',
          },
        ]),
      );
    }
    try {
      final document = parseDocument(decoded);
      if (document is! DeckDocument) {
        return _InvalidDeck(
          _validationResponse([
            {
              'path': 'kind',
              'code': 'wrongKind',
              'message': 'Expected a flashcard deck document.',
            },
          ]),
        );
      }
      final issues = validateDeck(document.deck);
      if (issues.isNotEmpty) {
        return _InvalidDeck(
          _validationResponse([for (final issue in issues) issue.toJson()]),
        );
      }
      final visibility = decoded['visibility'] ?? 'private';
      if (visibility is! String ||
          !{'public', 'unlisted', 'private'}.contains(visibility)) {
        return _InvalidDeck(
          _validationResponse([
            {
              'path': 'visibility',
              'code': 'invalidVisibility',
              'message': 'Visibility must be public, unlisted, or private.',
            },
          ]),
        );
      }
      return _ValidDeck(document.deck, visibility);
    } on DocumentFormatException catch (error) {
      return _InvalidDeck(
        _validationResponse([
          {
            'path': error.path ?? '',
            'code': 'invalidDocument',
            'message': error.message,
          },
        ]),
      );
    }
  }

  Map<String, Object?> _parameters(
    FlashcardDeck deck,
    String ownerId,
    String visibility,
  ) => {
    'id': deck.id,
    'owner': ownerId,
    'title': deck.title,
    'description': deck.description,
    'tags': deck.tags,
    'language': deck.language,
    'visibility': visibility,
    'version': deck.version,
    'itemCount': deck.cards.length,
    'document': jsonEncode(deck.toJson()),
    'searchText': '${deck.title} ${deck.description} ${deck.tags.join(' ')}',
  };

  Response _validationResponse(List<Map<String, Object>> errors) =>
      jsonResponse({'errors': errors}, statusCode: 422);

  Map<String, Object?> _summary(ResultRow row) => {
    'id': row[0],
    'title': row[1],
    'description': row[2],
    'tags': row[3],
    'language': row[4],
    'visibility': row[5],
    'version': row[6],
    'itemCount': row[7],
    'downloadCount': row[8],
    'createdAt': (row[9] as DateTime).toIso8601String(),
    'updatedAt': (row[10] as DateTime).toIso8601String(),
  };
}

sealed class _UploadedDeck {
  const _UploadedDeck();
}

class _ValidDeck extends _UploadedDeck {
  const _ValidDeck(this.deck, this.visibility);
  final FlashcardDeck deck;
  final String visibility;
}

class _InvalidDeck extends _UploadedDeck {
  const _InvalidDeck(this.response);
  final Response response;
}
