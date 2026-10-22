import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:study_better_server/protection.dart';

void main() {
  test('limits streamed and declared bodies and adds CORS', () async {
    final handler = protection()((_) => Response.ok('ok'));
    for (final headers in [
      <String, String>{},
      {'content-length': '${maxRequestBytes + 1}'},
    ]) {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/v1/quizzes'),
          headers: headers,
          body: List.filled(maxRequestBytes + 1, 0),
        ),
      );
      expect(response.statusCode, 413);
      expect(response.headers['access-control-allow-origin'], '*');
    }
  });
  test('auth throttling expires and does not affect local catalog', () async {
    var time = DateTime.utc(2026);
    final handler = protection(authRequestsPerMinute: 1, clock: () => time)(
      (_) => Response.ok('ok'),
    );
    Request request(String path) =>
        Request('POST', Uri.parse('http://localhost/api/v1/$path'));
    expect((await handler(request('auth/login'))).statusCode, 200);
    expect((await handler(request('auth/login'))).statusCode, 429);
    expect((await handler(request('quizzes'))).statusCode, 200);
    time = time.add(const Duration(minutes: 1));
    expect((await handler(request('auth/login'))).statusCode, 200);
  });
  test(
    'unexpected failures and missing routes return JSON without details',
    () async {
      final handler = protection()((_) => throw StateError('database secret'));
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/')),
      );
      expect(response.statusCode, 500);
      expect(jsonDecode(await response.readAsString()), {
        'error': 'Internal server error.',
      });
    },
  );
}
