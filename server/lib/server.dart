import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'auth/auth_middleware.dart';
import 'auth/auth_service.dart';
import 'db/database.dart';
import 'routes/health.dart';
import 'routes/auth.dart';
import 'routes/decks.dart';
import 'routes/quizzes.dart';

/// Base path of every API route.
const apiBasePath = '/api/v1';

/// Builds the request handler for the whole API.
///
/// Pass [enableLogging] `false` in tests to keep their output quiet.
Handler buildHandler(
  Config config, {
  Database? database,
  bool enableLogging = true,
}) {
  if (database == null) {
    final api = Router()..get('/health', health);
    return const Pipeline().addHandler(
      (Router()..mount('$apiBasePath/', api.call)).call,
    );
  }
  final auth = AuthService(database.connection, config);
  final routes = AuthRoutes(database.connection, auth);
  final decks = DeckRoutes(database.connection, auth);
  final quizzes = QuizRoutes(database.connection, auth);
  final api = Router()
    ..get('/health', health)
    ..post('/auth/register', routes.register)
    ..post('/auth/login', routes.login)
    ..post('/auth/refresh', routes.refresh)
    ..get('/me', requireAuth(auth)(routes.me))
    ..get('/decks/<id>', decks.get)
    ..post('/decks', requireAuth(auth)(decks.create))
    ..put('/decks/<id>', requireAuth(auth)(decks.update))
    ..delete('/decks/<id>', requireAuth(auth)(decks.delete))
    ..get('/me/decks', requireAuth(auth)(decks.mine))
    ..get('/quizzes/<id>', quizzes.get)
    ..post('/quizzes', requireAuth(auth)(quizzes.create))
    ..put('/quizzes/<id>', requireAuth(auth)(quizzes.update))
    ..delete('/quizzes/<id>', requireAuth(auth)(quizzes.delete))
    ..get('/me/quizzes', requireAuth(auth)(quizzes.mine));
  final root = Router()..mount('$apiBasePath/', api.call);

  var pipeline = const Pipeline();
  if (enableLogging) {
    pipeline = pipeline.addMiddleware(logRequests());
  }
  return pipeline.addHandler(root.call);
}
