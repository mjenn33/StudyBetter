import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/auth_service.dart';
import '../json_response.dart';
import 'catalog.dart';

class QuizRoutes {
  QuizRoutes(this.connection, this.auth);

  final Connection connection;
  final AuthService auth;

  Future<Response> catalog(Request request) =>
      catalogResponse(connection, 'quizzes', request);

  Future<Response> get(Request request) async {
    final id = request.params['id']!;
    final rows = await connection.execute(
      Sql.named(
        'SELECT owner_id, visibility::text, document::text FROM quizzes WHERE id = @id',
      ),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return Response.notFound('Quiz not found');

    final row = rows.first;
    final ownerId = row[0] as String;
    final visibility = row[1] as String;
    final userId = authenticatedUserId(request, auth);
    if (visibility == 'private' && userId != ownerId) {
      return Response.notFound('Quiz not found');
    }
    final updated = await connection.execute(
      Sql.named(
        'UPDATE quizzes SET download_count = download_count + 1 WHERE id = @id RETURNING version',
      ),
      parameters: {'id': id},
    );
    return jsonResponse(
      jsonDecode(row[2] as String),
      headers: {'etag': '${updated.first[0]}'},
    );
  }

  Future<Response> create(Request request) async {
    final uploaded = await _uploadedQuiz(request);
    if (uploaded is _InvalidQuiz) return uploaded.response;
    final valid = uploaded as _ValidQuiz;
    final quiz = valid.quiz.copyWith(version: 1);

    try {
      await _insert(
        quiz,
        request.context[currentUserIdKey] as String,
        valid.visibility,
      );
    } on ServerException {
      return jsonResponse({
        'error': 'a quiz with this id already exists',
      }, statusCode: 409);
    }
    return jsonResponse(quiz.toJson(), statusCode: 201);
  }

  Future<Response> update(Request request) async {
    final id = request.params['id']!;
    final expectedVersion = int.tryParse(request.headers['if-match'] ?? '');
    if (expectedVersion == null) {
      return jsonResponse({
        'error': 'If-Match: <version> is required',
      }, statusCode: 400);
    }
    final uploaded = await _uploadedQuiz(request);
    if (uploaded is _InvalidQuiz) return uploaded.response;
    final valid = uploaded as _ValidQuiz;

    final userId = request.context[currentUserIdKey] as String;
    final rows = await connection.execute(
      Sql.named('SELECT owner_id, version FROM quizzes WHERE id = @id'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return Response.notFound('Quiz not found');
    if (rows.first[0] as String != userId) {
      return jsonResponse({
        'error': 'only the owner can update this quiz',
      }, statusCode: 403);
    }
    final version = rows.first[1] as int;
    if (version != expectedVersion) {
      return jsonResponse({
        'error': 'version conflict',
        'version': version,
      }, statusCode: 409);
    }

    final quiz = valid.quiz.copyWith(id: id, version: version + 1);
    final result = await connection.execute(
      Sql.named('''
        UPDATE quizzes
        SET title = @title, description = @description, tags = @tags,
            language = @language, visibility = @visibility, version = @version,
            item_count = @itemCount, document = CAST(@document AS jsonb),
            search_vector = to_tsvector('simple', @searchText), updated_at = now()
        WHERE id = @id AND owner_id = @owner AND version = @expectedVersion
      '''),
      parameters: _parameters(quiz, userId, valid.visibility)
        ..['id'] = id
        ..['expectedVersion'] = expectedVersion,
    );
    if (result.affectedRows == 0) {
      return jsonResponse({'error': 'version conflict'}, statusCode: 409);
    }
    return jsonResponse(quiz.toJson());
  }

  Future<Response> delete(Request request) async {
    final id = request.params['id']!;
    final userId = request.context[currentUserIdKey] as String;
    final rows = await connection.execute(
      Sql.named('SELECT owner_id FROM quizzes WHERE id = @id'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return Response.notFound('Quiz not found');
    if (rows.first[0] as String != userId) {
      return jsonResponse({
        'error': 'only the owner can delete this quiz',
      }, statusCode: 403);
    }
    await connection.execute(
      Sql.named('DELETE FROM quizzes WHERE id = @id AND owner_id = @owner'),
      parameters: {'id': id, 'owner': userId},
    );
    return Response(204);
  }

  Future<Response> mine(Request request) async {
    final rows = await connection.execute(
      Sql.named('''
        SELECT id, title, description, tags, language, visibility::text, version,
               item_count, download_count, created_at, updated_at
        FROM quizzes WHERE owner_id = @owner ORDER BY updated_at DESC
      '''),
      parameters: {'owner': request.context[currentUserIdKey]},
    );
    return jsonResponse([for (final row in rows) _summary(row)]);
  }

  Future<void> _insert(Quiz quiz, String ownerId, String visibility) async {
    await connection.execute(
      Sql.named('''
      INSERT INTO quizzes (
        id, owner_id, title, description, tags, language, visibility, version,
        item_count, document, search_vector
      ) VALUES (
        @id, @owner, @title, @description, @tags, @language, @visibility,
        @version, @itemCount, CAST(@document AS jsonb),
        to_tsvector('simple', @searchText)
      )
    '''),
      parameters: _parameters(quiz, ownerId, visibility),
    );
  }

  Future<_UploadedQuiz> _uploadedQuiz(Request request) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(await request.readAsString());
    } on FormatException catch (error) {
      return _InvalidQuiz(
        _validationResponse([
          {'path': '', 'code': 'invalidJson', 'message': error.message},
        ]),
      );
    }
    if (decoded is! Map<String, dynamic>) {
      return _InvalidQuiz(
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
      if (document is! QuizDocument) {
        return _InvalidQuiz(
          _validationResponse([
            {
              'path': 'kind',
              'code': 'wrongKind',
              'message': 'Expected a quiz document.',
            },
          ]),
        );
      }
      final issues = validateQuiz(document.quiz);
      if (issues.isNotEmpty) {
        return _InvalidQuiz(
          _validationResponse([for (final issue in issues) issue.toJson()]),
        );
      }
      final visibility = decoded['visibility'] ?? 'private';
      if (visibility is! String ||
          !{'public', 'unlisted', 'private'}.contains(visibility)) {
        return _InvalidQuiz(
          _validationResponse([
            {
              'path': 'visibility',
              'code': 'invalidVisibility',
              'message': 'Visibility must be public, unlisted, or private.',
            },
          ]),
        );
      }
      return _ValidQuiz(document.quiz, visibility);
    } on DocumentFormatException catch (error) {
      return _InvalidQuiz(
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
    Quiz quiz,
    String ownerId,
    String visibility,
  ) => {
    'id': quiz.id,
    'owner': ownerId,
    'title': quiz.title,
    'description': quiz.description,
    'tags': quiz.tags,
    'language': quiz.language,
    'visibility': visibility,
    'version': quiz.version,
    'itemCount': quiz.questions.length,
    'document': jsonEncode(quiz.toJson()),
    'searchText': '${quiz.title} ${quiz.description} ${quiz.tags.join(' ')}',
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

sealed class _UploadedQuiz {
  const _UploadedQuiz();
}

class _ValidQuiz extends _UploadedQuiz {
  const _ValidQuiz(this.quiz, this.visibility);
  final Quiz quiz;
  final String visibility;
}

class _InvalidQuiz extends _UploadedQuiz {
  const _InvalidQuiz(this.response);
  final Response response;
}
