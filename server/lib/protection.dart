import 'dart:io';

import 'package:shelf/shelf.dart';

import 'json_response.dart';

const maxRequestBytes = 1024 * 1024;

/// Bounds uploads before route parsing and throttles auth by socket peer.
/// Forwarded headers are deliberately ignored unless a trusted proxy is added.
Middleware protection({
  int authRequestsPerMinute = 20,
  DateTime Function()? clock,
}) {
  final now = clock ?? DateTime.now;
  final requests = <String, List<DateTime>>{};
  const cors = {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'access-control-allow-headers': 'Authorization, Content-Type, If-Match',
    'access-control-expose-headers': 'ETag, Retry-After',
  };
  return (inner) => (request) async {
    Response response;
    try {
      if (request.method == 'OPTIONS') return Response(204, headers: cors);
      if (request.url.path.startsWith('api/v1/auth/')) {
        final time = now();
        requests.removeWhere(
          (_, times) =>
              times.isEmpty || time.difference(times.last).inSeconds >= 60,
        );
        final peer =
            request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
        final key = peer?.remoteAddress.address ?? 'unknown';
        final times = requests.putIfAbsent(key, () => []);
        times.removeWhere((at) => time.difference(at).inSeconds >= 60);
        if (times.length >= authRequestsPerMinute) {
          return jsonResponse(
            {'error': 'Too many authentication requests.'},
            statusCode: 429,
            headers: {...cors, 'retry-after': '60'},
          );
        }
        times.add(time);
      }
      final declared = int.tryParse(request.headers['content-length'] ?? '');
      if (declared != null && declared > maxRequestBytes) {
        return jsonResponse(
          {'error': 'Request body exceeds 1 MB.'},
          statusCode: 413,
          headers: cors,
        );
      }
      final body = <int>[];
      await for (final chunk in request.read()) {
        if (body.length + chunk.length > maxRequestBytes) {
          return jsonResponse(
            {'error': 'Request body exceeds 1 MB.'},
            statusCode: 413,
            headers: cors,
          );
        }
        body.addAll(chunk);
      }
      response = await inner(request.change(body: body));
      if (response.statusCode >= 400 &&
          !(response.headers['content-type'] ?? '').contains(
            'application/json',
          )) {
        response = jsonResponse({
          'error': response.statusCode == 404
              ? 'Not found.'
              : 'Request failed.',
        }, statusCode: response.statusCode);
      }
    } on FormatException {
      response = jsonResponse({
        'error': 'Invalid request format.',
      }, statusCode: 400);
    } on TypeError {
      response = jsonResponse({
        'error': 'Invalid request fields.',
      }, statusCode: 400);
    } catch (_) {
      response = jsonResponse({
        'error': 'Internal server error.',
      }, statusCode: 500);
    }
    return response.change(headers: cors);
  };
}
