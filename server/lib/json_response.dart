import 'dart:convert';

import 'package:shelf/shelf.dart';

/// A response with a JSON-encoded [body].
Response jsonResponse(
  Object? body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
  );
}
