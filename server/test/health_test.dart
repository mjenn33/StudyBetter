import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:study_better_server/config.dart';
import 'package:study_better_server/server.dart';
import 'package:test/test.dart';

void main() {
  final handler = buildHandler(
    Config.fromEnvironment(const {}),
    enableLogging: false,
  );

  Future<Response> get(String path) =>
      Future.value(handler(Request('GET', Uri.parse('http://localhost$path'))));

  test('GET /api/v1/health returns ok', () async {
    final response = await get('/api/v1/health');

    expect(response.statusCode, 200);
    expect(response.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(await response.readAsString()), {'status': 'ok'});
  });

  test('unknown routes return 404', () async {
    final response = await get('/api/v1/nope');

    expect(response.statusCode, 404);
  });
}
