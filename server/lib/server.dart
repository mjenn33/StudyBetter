import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'routes/health.dart';

/// Base path of every API route.
const apiBasePath = '/api/v1';

/// Builds the request handler for the whole API.
///
/// Pass [enableLogging] `false` in tests to keep their output quiet.
Handler buildHandler(Config config, {bool enableLogging = true}) {
  final api = Router()..get('/health', health);
  final root = Router()..mount('$apiBasePath/', api.call);

  var pipeline = const Pipeline();
  if (enableLogging) {
    pipeline = pipeline.addMiddleware(logRequests());
  }
  return pipeline.addHandler(root.call);
}
