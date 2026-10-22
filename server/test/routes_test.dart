import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:study_better_server/config.dart';
import 'package:study_better_server/db/database.dart';
import 'package:study_better_server/server.dart';

void main() {
  final url = Platform.environment['TEST_DATABASE_URL'];
  group(
    'PostgreSQL route integration',
    () {
      late Database db;
      late Handler handler;
      Future<Response> call(
        String method,
        String path, {
        Object? body,
        String? token,
        int? version,
      }) async => handler(
        Request(
          method,
          Uri.parse('http://localhost/api/v1$path'),
          headers: {
            if (body != null) 'content-type': 'application/json',
            if (token != null) 'authorization': 'Bearer $token',
            if (version != null) 'if-match': '$version',
          },
          body: body == null ? null : jsonEncode(body),
        ),
      );
      Future<Map<String, dynamic>> object(Response response) async =>
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      Future<String> register(String name) async =>
          (await object(
                await call(
                  'POST',
                  '/auth/register',
                  body: {
                    'email': '$name@example.com',
                    'username': name,
                    'password': 'password123',
                  },
                ),
              ))['accessToken']
              as String;
      Map<String, dynamic> document(
        String kind,
        String id,
        String visibility,
      ) => {
        'schemaVersion': 1,
        'kind': kind == 'quizzes' ? 'quiz' : 'flashcardDeck',
        'id': id,
        'title': 'Biology cells',
        'description': 'Cell science',
        'version': 1,
        'createdAt': '2026-10-01T00:00:00.000Z',
        'updatedAt': '2026-10-01T00:00:00.000Z',
        'tags': ['biology'],
        'visibility': visibility,
        if (kind == 'quizzes')
          'questions': [
            {
              'id': 'q1',
              'prompt': 'Cell?',
              'type': 'single',
              'options': [
                {'id': 'a', 'text': 'Yes'},
                {'id': 'b', 'text': 'No'},
              ],
              'correctOptionIds': ['a'],
            },
          ],
        if (kind == 'decks')
          'cards': [
            {'id': 'c1', 'front': 'Cell', 'back': 'Unit of life'},
          ],
      };
      setUpAll(() async {
        final config = Config(
          port: 0,
          databaseUrl: url!,
          jwtSecret: 'test-secret-only',
          jwtSecretIsGenerated: false,
        );
        db = await Database.open(config);
        handler = buildHandler(config, database: db, enableLogging: false);
      });
      setUp(() async {
        await db.connection.execute(
          'TRUNCATE refresh_tokens, quizzes, decks, users CASCADE',
        );
        // Every test gets a fresh limiter as well as an empty database.
        handler = buildHandler(
          Config(
            port: 0,
            databaseUrl: url!,
            jwtSecret: 'test-secret-only',
            jwtSecretIsGenerated: false,
          ),
          database: db,
          enableLogging: false,
        );
      });
      tearDownAll(() async => db.close());
      test('register, login, profile and rotating refresh', () async {
        final token = await register('alice');
        expect((await call('GET', '/me', token: token)).statusCode, 200);
        expect((await call('GET', '/me')).statusCode, 401);
        expect(
          (await call(
            'POST',
            '/auth/login',
            body: {'email': 'alice@example.com', 'password': 'bad'},
          )).statusCode,
          401,
        );
        final login = await object(
          await call(
            'POST',
            '/auth/login',
            body: {'email': 'alice@example.com', 'password': 'password123'},
          ),
        );
        final refresh = {'refreshToken': login['refreshToken']};
        expect(
          (await call('POST', '/auth/refresh', body: refresh)).statusCode,
          200,
        );
        expect(
          (await call('POST', '/auth/refresh', body: refresh)).statusCode,
          401,
        );
      });
      for (final kind in ['quizzes', 'decks']) {
        test(
          '$kind ownership, validation, versions, public search and download counts',
          () async {
            final alice = await register('alice');
            final bob = await register('bob');
            const id = '00000000-0000-4000-8000-000000000001';
            final data = document(kind, id, 'public');
            expect((await call('POST', '/$kind', body: data)).statusCode, 401);
            expect(
              (await call(
                'POST',
                '/$kind',
                body: {'kind': 'invalid'},
                token: alice,
              )).statusCode,
              422,
            );
            expect(
              (await call(
                'POST',
                '/$kind',
                body: data,
                token: alice,
              )).statusCode,
              201,
            );
            expect(
              (await call(
                'PUT',
                '/$kind/$id',
                body: data,
                token: bob,
                version: 1,
              )).statusCode,
              403,
            );
            expect(
              (await call('DELETE', '/$kind/$id', token: bob)).statusCode,
              403,
            );
            expect(
              (await call(
                'PUT',
                '/$kind/$id',
                body: data,
                token: alice,
                version: 2,
              )).statusCode,
              409,
            );
            expect(
              (await call(
                'PUT',
                '/$kind/$id',
                body: data,
                token: alice,
                version: 1,
              )).statusCode,
              200,
            );
            final downloaded = await call('GET', '/$kind/$id');
            expect(downloaded.statusCode, 200);
            expect(downloaded.headers['etag'], '2');
            final catalog = await object(
              await call(
                'GET',
                '/$kind?q=Biology&tag=biology&sort=downloads&page=1',
              ),
            );
            final summary =
                (catalog['items'] as List).single as Map<String, dynamic>;
            expect(summary['downloadCount'], 1);
            expect(summary['ownerName'], 'alice');
            expect(summary.containsKey('document'), false);
            expect(
              (await object(await call('GET', '/$kind?q=unmatched')))['items'],
              isEmpty,
            );
            expect((await call('GET', '/$kind?page=0')).statusCode, 400);
            expect(
              (await call(
                'PUT',
                '/$kind/$id',
                body: {...data, 'visibility': 'private'},
                token: alice,
                version: 2,
              )).statusCode,
              200,
            );
            expect(
              (await call('GET', '/$kind/$id', token: bob)).statusCode,
              404,
            );
            expect(
              (await object(await call('GET', '/$kind')))['items'],
              isEmpty,
            );
            expect(
              (await call('GET', '/$kind/$id', token: alice)).statusCode,
              200,
            );
          },
        );
      }
    },
    skip: url == null
        ? 'Run scripts/test/server.sh for disposable PostgreSQL tests.'
        : false,
  );
}
