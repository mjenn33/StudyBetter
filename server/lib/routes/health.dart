import 'package:shelf/shelf.dart';

import '../json_response.dart';

/// `GET /health` — liveness check.
Response health(Request request) => jsonResponse({'status': 'ok'});
