import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../auth/auth_middleware.dart';
import '../auth/auth_service.dart';

class AuthRoutes {
  AuthRoutes(this.connection, this.auth);
  final Connection connection;
  final AuthService auth;

  Future<Response> register(Request request) async {
    final body = await _body(request);
    final email = body['email'] as String?;
    final username = body['username'] as String?;
    final password = body['password'] as String?;
    if (email == null ||
        username == null ||
        password == null ||
        password.length < 8) {
      return _json(400, {
        'error': 'email, username, and an 8-character password are required',
      });
    }
    try {
      final rows = await connection.execute(
        Sql.named(
          'INSERT INTO users (email, username, password_hash) VALUES (@email, @username, @hash) RETURNING id',
        ),
        parameters: {
          'email': email,
          'username': username,
          'hash': auth.hashPassword(password),
        },
      );
      return await _tokens(rows.first[0] as String);
    } on ServerException {
      return _json(409, {'error': 'email or username already exists'});
    }
  }

  Future<Response> login(Request request) async {
    final body = await _body(request);
    final rows = await connection.execute(
      Sql.named('SELECT id, password_hash FROM users WHERE email = @email'),
      parameters: {'email': body['email']},
    );
    if (rows.isEmpty ||
        !auth.verifyPassword(
          body['password'] as String? ?? '',
          rows.first[1] as String,
        )) {
      return _json(401, {'error': 'invalid credentials'});
    }
    return _tokens(rows.first[0] as String);
  }

  Future<Response> refresh(Request request) async {
    final body = await _body(request);
    final token = body['refreshToken'] as String?;
    if (token == null) {
      return _json(401, {'error': 'invalid refresh token'});
    }
    final rows = await connection.execute(
      'SELECT id, user_id, token_hash FROM refresh_tokens WHERE revoked_at IS NULL AND expires_at > now()',
    );
    for (final row in rows) {
      if (auth.verifyRefresh(token, row[2] as String)) {
        await connection.execute(
          Sql.named(
            'UPDATE refresh_tokens SET revoked_at = now() WHERE id = @id',
          ),
          parameters: {'id': row[0]},
        );
        return _tokens(row[1] as String);
      }
    }
    return _json(401, {'error': 'invalid refresh token'});
  }

  Future<Response> me(Request request) async {
    final id = request.context[currentUserIdKey] as String;
    final rows = await connection.execute(
      Sql.named('SELECT id, email, username FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
    return rows.isEmpty
        ? Response(401)
        : _json(200, {
            'id': rows.first[0],
            'email': rows.first[1],
            'username': rows.first[2],
          });
  }

  Future<Response> _tokens(String userId) async {
    final refresh = auth.refreshToken();
    await connection.execute(
      Sql.named(
        'INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES (@user, @hash, now() + interval \'30 days\')',
      ),
      parameters: {'user': userId, 'hash': auth.hashToken(refresh)},
    );
    return _json(200, {
      'accessToken': auth.accessToken(userId),
      'refreshToken': refresh,
    });
  }

  Future<Map<String, dynamic>> _body(Request request) async =>
      jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  Response _json(int status, Object body) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json'},
  );
}
